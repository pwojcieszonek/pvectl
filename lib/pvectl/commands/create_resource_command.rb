# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared functionality for resource creation commands.
    #
    # Template method pattern: provides common create workflow
    # (interactive detection, confirmation, dry-run, config loading)
    # while specialization classes define resource-specific hooks.
    #
    # @abstract Include this module and implement template methods.
    #
    # @example Specialization
    #   class CreateVm
    #     include CreateResourceCommand
    #     private
    #     def resource_label = "VM"
    #     def resource_id_label = "VMID"
    #     # ...
    #   end
    #
    module CreateResourceCommand
      # Class methods added when the module is included.
      module ClassMethods
        # Executes the create command.
        #
        # @param args [Array<String>] command arguments
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def execute(args, options, global_options)
          new(args, options, global_options).execute
        end
      end

      # Hook called when module is included.
      #
      # @param base [Class] the class including this module
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Initializes a create command.
      #
      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the create command.
      #
      # @return [Integer] exit code
      def execute
        if interactive_mode?
          perform_interactive
        else
          perform_create
        end
      end

      private

      # --- Template methods (override in specialization) ---

      # @return [String] human label for resource ("VM" or "container")
      def resource_label
        raise NotImplementedError, "#{self.class} must implement #resource_label"
      end

      # @return [String] human label for resource ID ("VMID" or "CTID")
      def resource_id_label
        raise NotImplementedError, "#{self.class} must implement #resource_id_label"
      end

      # @return [Boolean] true if required params for non-interactive mode are missing
      def required_params_missing?
        raise NotImplementedError, "#{self.class} must implement #required_params_missing?"
      end

      # @return [Hash] parameters built from CLI flags
      def build_params_from_flags
        raise NotImplementedError, "#{self.class} must implement #build_params_from_flags"
      end

      # @return [Object] wizard instance for interactive mode
      def build_wizard
        raise NotImplementedError, "#{self.class} must implement #build_wizard"
      end

      # @param connection [Connection] API connection
      # @param task_repo [Repositories::Task] task repository
      # @return [Object] create service instance
      def build_create_service(connection, task_repo)
        raise NotImplementedError, "#{self.class} must implement #build_create_service"
      end

      # @param result [Models::OperationResult] operation result
      # @return [void]
      def output_result(result)
        raise NotImplementedError, "#{self.class} must implement #output_result"
      end

      # @param params [Hash] creation parameters
      # @return [void]
      def display_resource_summary(params)
        raise NotImplementedError, "#{self.class} must implement #display_resource_summary"
      end

      # --- Shared implementation ---

      # Determines whether to use interactive mode.
      #
      # @return [Boolean] true if interactive mode should be used
      def interactive_mode?
        return true if @options[:interactive]
        return false if @options[:"no-interactive"]

        $stdin.tty? && required_params_missing?
      end

      # Runs the interactive wizard flow.
      #
      # @return [Integer] exit code
      def perform_interactive
        wizard = build_wizard
        wizard_params = wizard.run
        return ExitCodes::SUCCESS unless wizard_params

        @options[:start] = wizard_params.delete(:start) if wizard_params.key?(:start)
        perform_create_with_params(wizard_params)
      end

      # Validates flags and performs flag-based creation.
      #
      # @return [Integer] exit code
      def perform_create
        params = build_params_from_flags
        perform_create_with_params(params)
      rescue ArgumentError => e
        usage_error(e.message)
      end

      # Creates a resource with the given parameters.
      #
      # @param params [Hash] creation parameters
      # @return [Integer] exit code
      def perform_create_with_params(params)
        return ExitCodes::SUCCESS if display_summary_and_confirm(params) == :cancelled
        return ExitCodes::SUCCESS if @options[:"dry-run"]

        load_config
        connection = Pvectl::Connection.new(@config)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = build_create_service(connection, task_repo)
        result = service.execute(**params)
        output_result(result)
        result.failed? ? ExitCodes::GENERAL_ERROR : ExitCodes::SUCCESS
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError
        raise
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      # Displays a creation summary and prompts for confirmation.
      #
      # @param params [Hash] creation parameters
      # @return [Symbol, nil] +:cancelled+ if user declines, +nil+ otherwise
      def display_summary_and_confirm(params)
        display_summary(params)

        return nil if @options[:yes]

        $stdout.print "Create this #{resource_label}? [y/N] "
        $stdout.flush
        answer = $stdin.gets&.strip&.downcase
        answer == "y" ? nil : :cancelled
      end

      # Displays the creation summary.
      #
      # @param params [Hash] creation parameters
      # @return [void]
      def display_summary(params)
        $stdout.puts ""
        $stdout.puts "  Create #{resource_label} - Summary"
        $stdout.puts "  #{'─' * 40}"
        $stdout.puts "  #{resource_id_label}:#{' ' * (10 - resource_id_label.length)}#{params[:vmid] || params[:ctid] || '(auto)'}"
        display_resource_summary(params)
        $stdout.puts "  #{'─' * 40}"
        $stdout.puts "  (dry-run mode -- no #{resource_label} will be created)" if @options[:"dry-run"]
        $stdout.puts ""
      end

      # Resolves the default node from configuration.
      #
      # @return [String, nil] default node name or nil
      def resolve_default_node
        load_config unless @config
        @config&.default_node
      rescue StandardError
        nil
      end

      # Loads configuration from file or environment.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Builds service options from command options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:timeout] = @options[:timeout] if @options[:timeout]
        opts[:async] = true if @options[:async]
        opts[:start] = true if @options[:start]
        opts
      end

      # Outputs usage error and returns exit code.
      #
      # @param message [String] error message
      # @return [Integer] exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
