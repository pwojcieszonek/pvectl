# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl set volume` command.
    #
    # Does NOT use SetResourceCommand template — has custom flow due to
    # different argument structure (resource_type + id + disk + key=value).
    #
    # @example Resize volume
    #   pvectl set volume vm 100 scsi0 size=+10G
    #
    # @example Set cache mode
    #   pvectl set volume vm 100 scsi0 cache=writeback
    #
    # @example Mixed operations
    #   pvectl set volume vm 100 scsi0 size=+10G cache=writeback --yes
    #
    class SetVolume
      # Class methods for command execution.
      module ClassMethods
        # Executes the set volume command.
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

      # Initializes a set volume command.
      #
      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the set volume command.
      #
      # @return [Integer] exit code
      def execute
        resource_type = @args[0]
        resource_id = @args[1]
        disk = @args[2]
        key_value_args = @args[3..] || []

        return usage_error("Resource type required (vm, container)") unless resource_type
        return usage_error("Resource ID is required") unless resource_id
        return usage_error("Volume name is required (e.g., scsi0, rootfs)") unless disk

        key_values = parse_key_values(key_value_args)
        return usage_error("At least one key=value pair is required") if key_values.empty?

        load_config
        connection = Pvectl::Connection.new(@config)

        node = resolve_node(resource_id.to_i, connection, resource_type)
        return ExitCodes::NOT_FOUND unless node

        # Confirmation for resize operations
        if key_values.key?("size") && !@options[:yes]
          return ExitCodes::SUCCESS unless confirm_resize(resource_id, disk, key_values["size"])
        end

        repo = build_repository(connection, resource_type)
        service = Pvectl::Services::SetVolume.new(
          repository: repo,
          resource_type: resource_type_symbol(resource_type)
        )
        result = service.execute(id: resource_id.to_i, disk: disk, params: key_values, node: node)

        output_result(result)

        result.successful? ? ExitCodes::SUCCESS : ExitCodes::GENERAL_ERROR
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

      # Parses key=value pairs from argument list.
      #
      # @param args [Array<String>] arguments
      # @return [Hash] parsed pairs
      def parse_key_values(args)
        pairs = {}
        args.each do |arg|
          unless arg.include?("=")
            $stderr.puts "Warning: Ignoring argument without '=': #{arg}"
            next
          end
          key, value = arg.split("=", 2)
          pairs[key] = value
        end
        pairs
      end

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

      # Confirms resize operation.
      #
      # @param resource_id [String] resource ID
      # @param disk [String] disk name
      # @param size [String] size value
      # @return [Boolean] true if should proceed
      def confirm_resize(resource_id, disk, size)
        $stdout.puts "Resize volume #{disk} on resource #{resource_id}:"
        $stdout.puts "  New size: #{size}"
        $stdout.puts ""
        $stdout.puts "This action is IRREVERSIBLE — volumes cannot be shrunk via API."
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
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

      # Outputs operation result.
      #
      # @param result [Models::VolumeOperationResult] operation result
      # @return [void]
      def output_result(result)
        presenter = Pvectl::Presenters::VolumeOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format([result], presenter, color: color_flag)
        puts output
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
