# frozen_string_literal: true

require "uri"
require "socket"
require "openssl"
require "websocket/driver"
require "io/console"

module Pvectl
  module Console
    # Manages an interactive terminal session over a Proxmox VNC WebSocket.
    #
    # TerminalSession handles the full lifecycle of a console connection:
    # 1. Opens a raw TCP/SSL socket to the Proxmox host
    # 2. Performs a WebSocket handshake with authentication
    # 3. Bridges local stdin/stdout with the remote terminal via the xtermjs wire protocol
    # 4. Manages raw terminal mode and signal handling (SIGWINCH for resize)
    #
    # The xtermjs protocol uses numbered message types:
    # - Type 0: input data — +0:<bytesize>:<data>+
    # - Type 1: terminal resize — +1:<cols>:<rows>:+
    # - Type 2: ping — +2+
    #
    # @example Basic usage (called by Console::Command)
    #   session = Pvectl::Console::TerminalSession.new(
    #     url: "wss://pve1:8006/api2/json/nodes/pve1/qemu/100/vncwebsocket?port=5900&vncticket=TICKET",
    #     cookie: "PVEAuthCookie=PVE:root@pam:abc",
    #     user: "root@pam",
    #     ticket: "PVEVNC:abc123",
    #     verify_ssl: true
    #   )
    #   session.run
    #
    # @see https://pve.proxmox.com/wiki/VNC_Proxy Proxmox VNC Proxy documentation
    #
    class TerminalSession
      # Ctrl+] — standard disconnect key (same as telnet/SSH escape)
      CTRL_CLOSE_BRACKET = "\x1d"

      # Seconds between keepalive pings sent to the server
      PING_INTERVAL = 120

      # Bytes to read per socket read call
      READ_CHUNK_SIZE = 4096

      # Creates a new terminal session.
      #
      # @param url [String] WebSocket URL for the VNC proxy endpoint
      # @param cookie [String] PVEAuthCookie header value for authentication
      # @param user [String] Proxmox user identifier (e.g., "root@pam")
      # @param ticket [String] VNC ticket for the handshake (e.g., "PVEVNC:abc123")
      # @param verify_ssl [Boolean] whether to verify the server's SSL certificate
      #
      def initialize(url:, cookie:, user:, ticket:, verify_ssl:)
        @url = url
        @cookie = cookie
        @user = user
        @ticket = ticket
        @verify_ssl = verify_ssl
        @running = false
        @saved_stty = nil
      end

      # Runs the interactive terminal session.
      #
      # Opens the WebSocket connection, performs the handshake, and enters
      # the I/O loop bridging stdin to the remote terminal. Restores the
      # local terminal state on exit (even on error).
      #
      # @return [void]
      # @raise [RuntimeError] if the WebSocket handshake fails
      #
      def run
        uri = URI.parse(@url)
        socket = open_socket(uri)
        driver = create_driver(uri, socket)
        perform_websocket_handshake(driver, socket)
        run_io_loop(driver, socket)
      ensure
        restore_terminal
        socket&.close
      end

      private

      # --- Protocol encoding (xtermjs wire format) ---

      # Encodes user input for the xtermjs protocol.
      #
      # @param data [String] raw input bytes from stdin
      # @return [String] encoded message in format "0:<bytesize>:<data>"
      #
      def encode_input(data)
        "0:#{data.bytesize}:#{data}"
      end

      # Encodes a terminal resize notification.
      #
      # @param cols [Integer] new terminal width in columns
      # @param rows [Integer] new terminal height in rows
      # @return [String] encoded message in format "1:<cols>:<rows>:"
      #
      def encode_resize(cols, rows)
        "1:#{cols}:#{rows}:"
      end

      # Encodes a keepalive ping message.
      #
      # @return [String] the ping message "2"
      #
      def encode_ping
        "2"
      end

      # Checks if the given byte is the disconnect key (Ctrl+]).
      #
      # @param byte [String] a single byte of input
      # @return [Boolean] true if the byte is the disconnect sequence
      #
      def disconnect_key?(byte)
        byte == CTRL_CLOSE_BRACKET
      end

      # Builds the authentication handshake message.
      #
      # @return [String] handshake in format "<user>:<ticket>\n"
      #
      def handshake_message
        "#{@user}:#{@ticket}\n"
      end

      # --- Networking ---

      # Opens a TCP socket with optional SSL wrapping.
      #
      # @param uri [URI] parsed WebSocket URL
      # @return [TCPSocket, OpenSSL::SSL::SSLSocket] the connected socket
      #
      def open_socket(uri)
        tcp = TCPSocket.new(uri.host, uri.port)

        if uri.scheme == "wss"
          wrap_ssl(tcp, uri.host)
        else
          tcp
        end
      end

      # Wraps a TCP socket in SSL.
      #
      # @param tcp [TCPSocket] raw TCP socket
      # @param hostname [String] server hostname for SNI
      # @return [OpenSSL::SSL::SSLSocket] SSL-wrapped socket
      #
      def wrap_ssl(tcp, hostname)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = @verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE

        ssl = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
        ssl.hostname = hostname
        ssl.connect
        ssl
      end

      # Creates a WebSocket protocol driver for the given socket.
      #
      # Uses {SocketAdapter} to satisfy websocket-driver's interface requirements
      # (the adapter must respond to +#url+ and +#write+).
      #
      # Sets required headers for Proxmox xtermjs:
      # - +Cookie+ — PVEAuthCookie for session authentication
      # - +Referer+ — must include +xtermjs=1+ query param so the server
      #   uses text-based xtermjs protocol instead of binary VNC (RFB)
      #
      # @param uri [URI] parsed WebSocket URL
      # @param socket [TCPSocket, OpenSSL::SSL::SSLSocket] the underlying socket
      # @return [WebSocket::Driver::Client] configured WebSocket driver
      #
      def create_driver(uri, socket)
        adapter = SocketAdapter.new(uri.to_s, socket)
        driver = WebSocket::Driver.client(adapter, protocols: ["binary"])
        driver.set_header("Cookie", @cookie)
        driver.set_header("Referer", build_referer(uri))
        driver
      end

      # Builds a Referer header that signals xtermjs mode to Proxmox.
      #
      # Proxmox checks the Referer header's query parameters to decide
      # whether to use xtermjs (text) or noVNC (binary RFB) protocol.
      #
      # @param uri [URI] parsed WebSocket URL
      # @return [String] referer URL with xtermjs=1 query param
      #
      def build_referer(uri)
        "https://#{uri.host}:#{uri.port}/?console=shell&xtermjs=1&vmid=0&vmname=&node=localhost&cmd="
      end

      # Reads available data from a socket with a timeout.
      #
      # For SSL sockets, checks +pending+ first to handle buffered data that
      # IO.select cannot detect.
      #
      # @param socket [TCPSocket, OpenSSL::SSL::SSLSocket] socket to read from
      # @param timeout [Numeric] maximum seconds to wait for data
      # @return [String, nil] raw data or nil on timeout/EOF
      #
      def read_from_socket(socket, timeout:)
        # SSL sockets may have buffered data not visible to IO.select
        if socket.respond_to?(:pending) && socket.pending > 0
          return socket.readpartial(READ_CHUNK_SIZE)
        end

        ready = IO.select([socket], nil, nil, timeout)
        return nil unless ready

        socket.readpartial(READ_CHUNK_SIZE)
      rescue EOFError, Errno::ECONNRESET, IO::WaitReadable
        nil
      end

      # --- WebSocket handshake ---

      # Performs the WebSocket handshake and Proxmox authentication.
      #
      # Starts the WebSocket driver, waits for the +:open+ event, sends
      # the authentication message, and waits for an "OK" response.
      #
      # @param driver [WebSocket::Driver::Client] WebSocket protocol driver
      # @param socket [TCPSocket, OpenSSL::SSL::SSLSocket] underlying socket
      # @return [void]
      # @raise [RuntimeError] if the handshake times out or authentication fails
      #
      def perform_websocket_handshake(driver, socket)
        open = false
        authenticated = false

        driver.on(:open) { open = true }
        driver.on(:message) do |msg|
          authenticated = true if msg.data == "OK"
        end

        driver.start

        # Wait for WebSocket open
        until open
          data = read_from_socket(socket, timeout: 10)
          raise "WebSocket handshake timed out" unless data

          driver.parse(data)
        end

        # Send auth and wait for OK
        driver.text(handshake_message)

        until authenticated
          data = read_from_socket(socket, timeout: 10)
          raise "Authentication timed out" unless data

          driver.parse(data)
        end
      end

      # --- I/O loop ---

      # Main I/O loop bridging local terminal and remote WebSocket.
      #
      # Puts the terminal in raw mode, then multiplexes between stdin and the
      # remote socket using IO.select. Sends keepalive pings every {PING_INTERVAL}
      # seconds. Exits on disconnect key (Ctrl+]) or connection close.
      #
      # @param driver [WebSocket::Driver::Client] WebSocket protocol driver
      # @param socket [TCPSocket, OpenSSL::SSL::SSLSocket] underlying socket
      # @return [void]
      #
      def run_io_loop(driver, socket)
        @running = true

        enable_raw_terminal
        send_initial_resize(driver)
        # Send an initial empty input to wake the remote terminal prompt
        driver.text(encode_input("\n"))
        trap_resize(driver)

        driver.on(:message) do |msg|
          $stdout.write(msg.data)
          $stdout.flush
        end

        driver.on(:close) { @running = false }

        last_ping = Time.now

        while @running
          # SSL sockets may have buffered data
          if socket.respond_to?(:pending) && socket.pending > 0
            driver.parse(socket.readpartial(READ_CHUNK_SIZE))
            next
          end

          timeout = [PING_INTERVAL - (Time.now - last_ping), 1].max
          ready = IO.select([$stdin, socket], nil, nil, timeout)

          # Send ping on timeout
          if ready.nil?
            driver.text(encode_ping)
            last_ping = Time.now
            next
          end

          ready[0].each do |io|
            if io == $stdin
              handle_stdin(driver)
            else
              handle_socket(driver, socket)
            end
          end

          # Periodic ping
          if Time.now - last_ping >= PING_INTERVAL
            driver.text(encode_ping)
            last_ping = Time.now
          end
        end
      end

      # Reads from stdin and sends encoded input to the WebSocket.
      #
      # @param driver [WebSocket::Driver::Client] WebSocket protocol driver
      # @return [void]
      #
      def handle_stdin(driver)
        data = $stdin.readpartial(READ_CHUNK_SIZE)

        if disconnect_key?(data)
          @running = false
          return
        end

        driver.text(encode_input(data))
      rescue EOFError, IO::WaitReadable
        @running = false
      end

      # Reads from the socket and feeds data to the WebSocket driver.
      #
      # @param driver [WebSocket::Driver::Client] WebSocket protocol driver
      # @param socket [TCPSocket, OpenSSL::SSL::SSLSocket] underlying socket
      # @return [void]
      #
      def handle_socket(driver, socket)
        data = socket.readpartial(READ_CHUNK_SIZE)
        driver.parse(data)
      rescue EOFError, Errno::ECONNRESET
        @running = false
      end

      # --- Terminal management ---

      # Enables raw terminal mode for direct character input.
      #
      # Saves the current terminal state so it can be restored later.
      # Uses stty for portability.
      #
      # @return [void]
      #
      def enable_raw_terminal
        @saved_stty = `stty -g`.chomp
        system("stty raw -echo -icanon -isig")
      end

      # Restores the terminal to its saved state.
      #
      # Called in an ensure block to guarantee cleanup even on errors.
      #
      # @return [void]
      #
      def restore_terminal
        system("stty #{@saved_stty}") if @saved_stty
        @saved_stty = nil
      end

      # Sends the initial terminal size to the remote server.
      #
      # @param driver [WebSocket::Driver::Client] WebSocket protocol driver
      # @return [void]
      #
      def send_initial_resize(driver)
        cols, rows = detect_terminal_size
        driver.text(encode_resize(cols, rows))
      end

      # Installs a SIGWINCH handler to send resize events on terminal size changes.
      #
      # @param driver [WebSocket::Driver::Client] WebSocket protocol driver
      # @return [void]
      #
      def trap_resize(driver)
        Signal.trap("WINCH") do
          cols, rows = detect_terminal_size
          driver.text(encode_resize(cols, rows))
        end
      end

      # Detects the current terminal dimensions.
      #
      # @return [Array<Integer>] columns and rows as +[cols, rows]+
      #
      def detect_terminal_size
        io = IO.console
        return [80, 24] unless io

        rows, cols = io.winsize
        [cols, rows]
      end

      # Minimal adapter satisfying websocket-driver's socket interface.
      #
      # The driver calls +#url+ to build the HTTP upgrade request and +#write+
      # to send framed data over the wire.
      #
      # @api private
      #
      class SocketAdapter
        # @return [String] the WebSocket URL
        attr_reader :url

        # Creates a new socket adapter.
        #
        # @param url [String] WebSocket URL
        # @param socket [TCPSocket, OpenSSL::SSL::SSLSocket] underlying socket
        #
        def initialize(url, socket)
          @url = url
          @socket = socket
        end

        # Writes data to the underlying socket.
        #
        # @param data [String] raw bytes to send
        # @return [Integer] number of bytes written
        #
        def write(data)
          @socket.write(data)
        end
      end
    end
  end
end
