# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl edit volume` command.
    #
    # Does NOT use EditResourceCommand template — has custom flow due to
    # different argument structure (resource_type + id + disk).
    #
    # @example Edit volume properties
    #   pvectl edit volume vm 100 scsi0
    #
    # @example With custom editor
    #   pvectl edit volume vm 100 scsi0 --editor nano
    #
    # @example Dry-run mode
    #   pvectl edit volume vm 100 scsi0 --dry-run
    #
    class EditVolume
      # Class methods for command execution.
      module ClassMethods
        # Executes the edit volume command.
        #
        # @param args [Array<String>] command arguments
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def execute(args, options, global_options)
          new(args, options, global_options).execute
        end
      end

      extend ClassMethods

      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the edit volume command.
      #
      # @return [Integer] exit code
      def execute
        resource_type = @args[0]
        resource_id = @args[1]
        disk = @args[2]

        return usage_error("Resource type required (vm, container)") unless resource_type
        return usage_error("Resource ID is required") unless resource_id
        return usage_error("Volume name is required (e.g., scsi0, rootfs)") unless disk

        load_config
        connection = Pvectl::Connection.new(@config)

        node = resolve_node(resource_id.to_i, connection, resource_type)
        return ExitCodes::NOT_FOUND unless node

        repo = build_repository(connection, resource_type)
        service = Pvectl::Services::EditVolume.new(
          repository: repo,
          resource_type: resource_type_symbol(resource_type),
          editor_session: build_editor_session,
          options: service_options
        )
        result = service.execute(id: resource_id.to_i, disk: disk, node: node)

        if result.nil?
          $stdout.puts "Edit cancelled, no changes made."
          return ExitCodes::SUCCESS
        end

        if result.successful?
          if @options[:"dry-run"]
            $stdout.puts "(dry-run mode — no changes applied)"
          else
            $stdout.puts "Volume #{disk} on #{resource_type} #{resource_id} updated successfully."
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

      # Resolves node for a resource.
      #
      # @param resource_id [Integer] resource ID
      # @param connection [Connection] API connection
      # @param resource_type [String] resource type
      # @return [String, nil] node name or nil
      def resolve_node(resource_id, connection, resource_type)
        return @options[:node] if @options[:node]

        resolver = Pvectl::Utils::ResourceResolver.new(connection)
        resolved = resolver.resolve(resource_id)

        unless resolved
          label = resource_type == "vm" ? "VM" : "container"
          $stderr.puts "Error: #{label} #{resource_id} not found"
          return nil
        end

        resolved[:node]
      end

      # Builds repository for resource type.
      #
      # @param connection [Connection] API connection
      # @param resource_type [String] resource type
      # @return [Repositories::Vm, Repositories::Container] repository
      def build_repository(connection, resource_type)
        case resource_type
        when "vm"
          Pvectl::Repositories::Vm.new(connection)
        when "container", "ct"
          Pvectl::Repositories::Container.new(connection)
        else
          raise ArgumentError, "Unknown resource type: #{resource_type}"
        end
      end

      # Converts string resource type to symbol.
      #
      # @param resource_type [String] resource type
      # @return [Symbol] :vm or :container
      def resource_type_symbol(resource_type)
        case resource_type
        when "vm" then :vm
        when "container", "ct" then :container
        else :vm
        end
      end

      # Builds an editor session from the --editor option.
      #
      # @return [EditorSession, nil] editor session or nil
      def build_editor_session
        editor_cmd = @options[:editor]
        return nil unless editor_cmd

        Pvectl::EditorSession.new(
          editor: ->(path) { system(editor_cmd, path) }
        )
      end

      # Builds service options from command options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:dry_run] = true if @options[:"dry-run"]
        opts
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
    end
  end
end
