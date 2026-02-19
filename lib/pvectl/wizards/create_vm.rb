# frozen_string_literal: true

module Pvectl
  module Wizards
    # Interactive wizard for creating a VM step by step.
    #
    # Uses TTY::Prompt (when available) or a fallback prompt to guide the user
    # through VM configuration. Returns a normalized params hash compatible
    # with Services::CreateVm, or nil if the user cancels.
    #
    # @example Running the wizard
    #   wizard = CreateVm.new(options, global_options)
    #   params = wizard.run
    #   #=> { name: "web", node: "pve1", cores: 4, ... } or nil
    #
    class CreateVm
      OS_TYPES = %w[l26 l24 win11 win10 win2k22 win2k19 win2k16 win8 win7 other].freeze

      # Creates a new CreateVm wizard.
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
        return nil unless @prompt.yes?("Create this VM?")

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
        params[:name] = @prompt.ask("VM name:", required: true)
        params[:node] = @prompt.ask("Node:", default: @options[:node])
        params[:cores] = @prompt.ask("CPU cores:", default: 1, convert: :int)
        params[:sockets] = @prompt.ask("CPU sockets:", default: 1, convert: :int)
        params[:memory] = @prompt.ask("Memory (MB):", default: 2048, convert: :int)
        params[:disks] = collect_disks
        params[:nets] = collect_nets
        params[:ostype] = @prompt.select("OS type:", OS_TYPES)
        params[:agent] = true if @prompt.yes?("Enable QEMU guest agent?")
        params[:start] = true if @prompt.yes?("Start VM after creation?")
        params.compact
      end

      # Collects disk configurations interactively.
      #
      # @return [Array<Hash>, nil] disk configs or nil if none added
      def collect_disks
        disks = []
        loop do
          input = @prompt.ask("Disk config (storage=X,size=Y) or empty to skip:")
          break if input.nil? || input.empty?

          disks << Parsers::DiskConfig.parse(input)
          break unless @prompt.yes?("Add another disk?")
        end
        disks.empty? ? nil : disks
      end

      # Collects network configurations interactively.
      #
      # @return [Array<Hash>, nil] net configs or nil if none added
      def collect_nets
        nets = []
        loop do
          input = @prompt.ask("Network config (bridge=X) or empty to skip:")
          break if input.nil? || input.empty?

          nets << Parsers::NetConfig.parse(input)
          break unless @prompt.yes?("Add another network?")
        end
        nets.empty? ? nil : nets
      end
    end
  end
end
