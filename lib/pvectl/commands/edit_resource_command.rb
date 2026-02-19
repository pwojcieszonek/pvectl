# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared functionality for resource edit commands.
    #
    # Template method pattern: provides common edit workflow
    # (config loading, editor session, diff display, dry-run)
    # while specialization classes define resource-specific hooks.
    #
    # @abstract Include this module and implement template methods.
    #
    # @example Specialization
    #   class EditVm
    #     include EditResourceCommand
    #     private
    #     def resource_label = "VM"
    #     def resource_id_label = "VMID"
    #     # ...
    #   end
    #
    module EditResourceCommand
      # Class methods added when the module is included.
      module ClassMethods
        # Executes the edit command.
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

      # Initializes an edit command.
      #
      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the edit command.
      #
      # Loads configuration, builds the edit service, and runs it.
      # Handles cancelled edits, successful updates with diff display,
      # dry-run mode, and errors.
      #
      # @return [Integer] exit code
      def execute
        resource_id = @args.first
        return usage_error("#{resource_id_label} is required") unless resource_id

        load_config
        connection = Pvectl::Connection.new(@config)
        service = build_edit_service(connection)
        result = service.execute(**execute_params(resource_id.to_i))

        if result.nil?
          $stdout.puts "Edit cancelled, no changes made."
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

      # @return [String] human label for resource ("VM" or "container")
      def resource_label
        raise NotImplementedError, "#{self.class} must implement #resource_label"
      end

      # @return [String] human label for resource ID ("VMID" or "CTID")
      def resource_id_label
        raise NotImplementedError, "#{self.class} must implement #resource_id_label"
      end

      # Builds execution parameters from resource ID.
      #
      # @param resource_id [Integer] resource identifier
      # @return [Hash] parameters for the edit service (e.g. { vmid: 100 })
      def execute_params(resource_id)
        raise NotImplementedError, "#{self.class} must implement #execute_params"
      end

      # Builds the edit service for the given connection.
      #
      # @param connection [Connection] API connection
      # @return [Object] edit service instance
      def build_edit_service(connection)
        raise NotImplementedError, "#{self.class} must implement #build_edit_service"
      end

      # Displays a formatted diff from the operation result.
      #
      # @param result [Models::OperationResult] operation result with diff in resource
      # @return [void]
      def display_diff(result)
        diff = result.resource&.dig(:diff)
        return unless diff
        return if diff[:changed].empty? && diff[:added].empty? && diff[:removed].empty?

        $stdout.puts "\nChanges:"
        $stdout.puts Pvectl::ConfigSerializer.format_diff(diff)
        $stdout.puts ""
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
        opts[:dry_run] = true if @options[:"dry-run"]
        opts
      end

      # Builds an editor session from the --editor option.
      #
      # @return [EditorSession, nil] editor session or nil if no --editor flag
      def build_editor_session
        editor_cmd = @options[:editor]
        return nil unless editor_cmd

        Pvectl::EditorSession.new(
          editor: ->(path) { system(editor_cmd, path) }
        )
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
