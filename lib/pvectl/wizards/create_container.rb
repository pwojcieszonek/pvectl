# frozen_string_literal: true

module Pvectl
  module Wizards
    # Interactive wizard for creating an LXC container step by step.
    #
    # Uses TTY::Prompt (when available) or a fallback prompt to guide the user
    # through container configuration. Returns a normalized params hash compatible
    # with Services::CreateContainer, or nil if the user cancels.
    #
    # @example Running the wizard
    #   wizard = CreateContainer.new(options, global_options)
    #   params = wizard.run
    #   #=> { hostname: "web-ct", node: "pve1", ... } or nil
    #
    class CreateContainer
      # Creates a new CreateContainer wizard.
      #
      # @param options [Hash] command options (may contain pre-filled values)
      # @param global_options [Hash] global CLI options
      # @param prompt [Object] prompt instance (injectable for testing)
      def initialize(options, global_options, prompt: nil)
        @options = options
        @global_options = global_options
        @prompt = prompt || create_default_prompt
      end

      # Runs the wizard and returns params or nil if cancelled.
      #
      # @return [Hash, nil] creation params or nil if user cancels
      def run
        params = collect_params
        return nil unless @prompt.yes?("Create this container?")

        params
      end

      private

      # Creates a default prompt, preferring TTY::Prompt with SimplePrompt fallback.
      #
      # @return [Object] prompt object
      def create_default_prompt
        require "tty-prompt"
        TTY::Prompt.new
      rescue LoadError
        Config::SimplePrompt.new
      end

      # Collects all parameters interactively.
      #
      # @return [Hash] collected parameters
      def collect_params
        params = {}
        params[:hostname] = @prompt.ask("Container hostname:", required: true)
        params[:ostemplate] = @prompt.ask("OS template path:", required: true)
        params[:node] = @prompt.ask("Node:", default: @options[:node])
        params[:cores] = @prompt.ask("CPU cores:", default: 1, convert: :int)
        params[:memory] = @prompt.ask("Memory (MB):", default: 512, convert: :int)
        params[:swap] = @prompt.ask("Swap (MB):", default: 512, convert: :int)
        params[:rootfs] = collect_rootfs
        params[:mountpoints] = collect_mountpoints
        params[:nets] = collect_nets
        params[:privileged] = true unless @prompt.yes?("Unprivileged container?", default: true)
        params[:start] = true if @prompt.yes?("Start container after creation?")
        params.compact
      end

      # Collects root filesystem configuration.
      #
      # @return [Hash] parsed rootfs config
      def collect_rootfs
        input = @prompt.ask("Root FS (storage=X,size=Y):", required: true)
        Parsers::LxcMountConfig.parse(input)
      end

      # Collects mountpoint configurations interactively.
      #
      # @return [Array<Hash>, nil] mountpoint configs or nil if none added
      def collect_mountpoints
        mps = []
        loop do
          input = @prompt.ask("Mountpoint (mp=/path,storage=X,size=Y) or empty to skip:")
          break if input.nil? || input.empty?

          mps << Parsers::LxcMountConfig.parse(input)
          break unless @prompt.yes?("Add another mountpoint?")
        end
        mps.empty? ? nil : mps
      end

      # Collects network configurations interactively.
      #
      # @return [Array<Hash>, nil] net configs or nil if none added
      def collect_nets
        nets = []
        loop do
          input = @prompt.ask("Network config (bridge=X[,ip=Y]) or empty to skip:")
          break if input.nil? || input.empty?

          nets << Parsers::LxcNetConfig.parse(input)
          break unless @prompt.yes?("Add another network?")
        end
        nets.empty? ? nil : nets
      end
    end
  end
end
