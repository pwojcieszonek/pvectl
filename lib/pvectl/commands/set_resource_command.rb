# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared functionality for resource set commands.
    #
    # Template method pattern: provides common set workflow
    # (config loading, key-value parsing, diff display, dry-run)
    # while specialization classes define resource-specific hooks.
    #
    # @abstract Include this module and implement template methods.
    #
    # @example Specialization
    #   class SetVm
    #     include SetResourceCommand
    #     private
    #     def resource_label = "VM"
    #     def resource_id_label = "VMID"
    #     # ...
    #   end
    #
    module SetResourceCommand
      # Class methods added when the module is included.
      module ClassMethods
        # Executes the set command.
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

      # Initializes a set command.
      #
      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the set command.
      #
      # @return [Integer] exit code
      def execute
        resource_id = @args.first
        return usage_error("#{resource_id_label} is required") unless resource_id

        key_values = parse_key_values(@args[1..])
        return usage_error("At least one key=value pair is required") if key_values.empty?

        load_config
        connection = Pvectl::Connection.new(@config)
        service = build_set_service(connection)
        result = service.execute(**execute_params(resource_id, key_values))

        if result.nil?
          $stdout.puts "No changes detected."
          return ExitCodes::SUCCESS
        end

        if result.successful?
          display_diff(result)
          if @options[:"dry-run"]
            $stdout.puts "(dry-run mode — no changes applied)"
          else
            $stdout.puts "#{resource_label} #{resource_id} updated successfully."
          end
          ExitCodes::SUCCESS
        else
          $stderr.puts "Error: #{result.error}"
          ExitCodes::GENERAL_ERROR
        end
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

      private

      # @return [String] human label for resource
      def resource_label
        raise NotImplementedError, "#{self.class} must implement #resource_label"
      end

      # @return [String] human label for resource ID
      def resource_id_label
        raise NotImplementedError, "#{self.class} must implement #resource_id_label"
      end

      # Builds execution parameters.
      #
      # @param resource_id [String] resource identifier
      # @param key_values [Hash] parsed key-value pairs
      # @return [Hash] parameters for the service
      def execute_params(resource_id, key_values)
        raise NotImplementedError, "#{self.class} must implement #execute_params"
      end

      # Builds the set service.
      #
      # @param connection [Connection] API connection
      # @return [Object] set service instance
      def build_set_service(connection)
        raise NotImplementedError, "#{self.class} must implement #build_set_service"
      end

      # Parses key=value pairs from argument list.
      #
      # @param args [Array<String>] arguments like ["memory=4096", "cores=2"]
      # @return [Hash] parsed pairs { "memory" => "4096", "cores" => "2" }
      def parse_key_values(args)
        pairs = {}
        (args || []).each do |arg|
          unless arg.include?("=")
            $stderr.puts "Warning: Ignoring argument without '=': #{arg}"
            next
          end
          key, value = arg.split("=", 2)
          pairs[key] = value
        end
        pairs
      end

      # Displays a formatted diff from the operation result.
      #
      # @param result [Models::OperationResult] operation result
      # @return [void]
      def display_diff(result)
        diff = result.resource&.dig(:diff)
        return unless diff
        return if diff[:changed].empty? && diff[:added].empty? && diff[:removed].empty?

        $stdout.puts "\nChanges:"
        $stdout.puts Pvectl::ConfigSerializer.format_diff(diff)
        $stdout.puts ""
      end

      # Loads configuration.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Outputs usage error.
      #
      # @param message [String] error message
      # @return [Integer] exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end

      # Returns service options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:dry_run] = true if @options[:"dry-run"]
        opts
      end
    end
  end
end
