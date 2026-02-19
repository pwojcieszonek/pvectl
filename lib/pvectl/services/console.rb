# frozen_string_literal: true

require "uri"
require "rest_client"
require "json"

module Pvectl
  module Services
    # Orchestrates an interactive console session to a VM or container.
    #
    # Handles: authentication (session ticket), termproxy setup,
    # WebSocket URL construction, and terminal session lifecycle.
    #
    # @example Basic usage
    #   service = Console.new
    #   service.run(resource: vm, resource_path: "qemu/100", server: "https://pve1:8006",
    #               username: "root@pam", password: "secret", verify_ssl: true)
    #
    class Console
      # Raised when the target resource is not in a running state.
      class ResourceNotRunningError < Pvectl::Error; end

      # Raised when authentication fails.
      class AuthenticationError < Pvectl::Error; end

      # Builds the WebSocket URL for vncwebsocket endpoint.
      #
      # @param server [String] Proxmox server URL (e.g. "https://pve1:8006")
      # @param node [String] node name
      # @param resource_path [String] resource path (e.g. "qemu/100" or "lxc/200")
      # @param port [Integer] termproxy port
      # @param ticket [String] PVEVNC ticket
      # @return [String] full WebSocket URL
      def build_websocket_url(server:, node:, resource_path:, port:, ticket:)
        uri = URI.parse(server)
        scheme = uri.scheme == "https" ? "wss" : "ws"
        host = uri.host
        ws_port = uri.port || 8006
        encoded_ticket = URI.encode_www_form_component(ticket)

        "#{scheme}://#{host}:#{ws_port}/api2/json/nodes/#{node}/#{resource_path}/vncwebsocket" \
          "?port=#{port}&vncticket=#{encoded_ticket}"
      end

      # Validates that the resource is in a running state.
      #
      # @param resource [Models::Vm, Models::Container] resource to check
      # @return [void]
      # @raise [ResourceNotRunningError] if resource is not running
      def validate_resource_running!(resource)
        return if resource.status == "running"

        raise ResourceNotRunningError,
              "Resource #{resource.vmid} is not running (status: #{resource.status})"
      end

      # Runs a console session end-to-end.
      #
      # All API calls (authenticate, termproxy) use the same session-based
      # REST client to ensure PVEVNC ticket and PVEAuthCookie share the
      # same identity. Using a token-based connection for termproxy would
      # generate a ticket bound to the token identity (e.g., "root@pam!pvectl"),
      # which is rejected by the WebSocket endpoint expecting a session cookie
      # for "root@pam".
      #
      # @param resource [Models::Vm, Models::Container] target resource
      # @param resource_path [String] API path segment ("qemu/{vmid}" or "lxc/{ctid}")
      # @param server [String] Proxmox server URL
      # @param username [String] username for auth
      # @param password [String] password for auth
      # @param verify_ssl [Boolean] SSL verification flag
      # @return [void]
      def run(resource:, resource_path:, server:, username:, password:, verify_ssl:)
        validate_resource_running!(resource)

        # All operations use one session-authenticated REST client
        api_url = "#{server}/api2/json/"
        session_client = RestClient::Resource.new(api_url, verify_ssl: verify_ssl)

        # 1. Authenticate
        auth = authenticate_with_client(session_client, username, password)

        # 2. Open termproxy (using session ticket, not API token)
        termproxy_data = open_termproxy(
          session_client, auth,
          node: resource.node, resource_path: resource_path
        )

        # 3. Build websocket URL
        url = build_websocket_url(
          server: server,
          node: resource.node,
          resource_path: resource_path,
          port: termproxy_data[:port],
          ticket: termproxy_data[:ticket]
        )

        # 4. Run terminal session
        session = Pvectl::Console::TerminalSession.new(
          url: url,
          cookie: "PVEAuthCookie=#{auth[:ticket]}",
          user: termproxy_data[:user],
          ticket: termproxy_data[:ticket],
          verify_ssl: verify_ssl
        )
        session.run
      end

      private

      # Authenticates using a provided REST client and returns session data.
      #
      # @param client [RestClient::Resource] clean REST client
      # @param username [String] Proxmox username
      # @param password [String] password
      # @return [Hash] { ticket:, csrf_token: }
      # @raise [AuthenticationError] on failure
      def authenticate_with_client(client, username, password)
        response = client["access/ticket"].post(username: username, password: password)
        data = JSON.parse(response.body, symbolize_names: true)[:data]

        {
          ticket: data[:ticket],
          csrf_token: data[:CSRFPreventionToken]
        }
      rescue StandardError => e
        raise AuthenticationError, "Authentication failed: #{e.message}"
      end

      # Opens a termproxy session using session auth credentials.
      #
      # @param client [RestClient::Resource] REST client
      # @param auth [Hash] session auth with :ticket and :csrf_token
      # @param node [String] Proxmox node name
      # @param resource_path [String] e.g. "qemu/100" or "lxc/200"
      # @return [Hash] { port:, ticket:, user: }
      def open_termproxy(client, auth, node:, resource_path:)
        endpoint = "nodes/#{node}/#{resource_path}/termproxy"
        response = client[endpoint].post(
          {},
          cookies: { PVEAuthCookie: auth[:ticket] },
          CSRFPreventionToken: auth[:csrf_token]
        )
        data = JSON.parse(response.body, symbolize_names: true)[:data]

        { port: data[:port], ticket: data[:ticket], user: data[:user] }
      rescue StandardError => e
        raise AuthenticationError, "Termproxy failed: #{e.message}"
      end
    end
  end
end
