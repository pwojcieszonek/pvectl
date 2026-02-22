# frozen_string_literal: true

module Pvectl
  module Commands
    module Resize
      # Shared functionality for resize volume commands.
      #
      # Template Method pattern: provides common resize flow
      # (argument validation, config loading, preflight, confirmation, resize)
      # while specialization classes define resource-specific hooks.
      #
      # @abstract Include this module and implement template methods:
      #   - #resource_label ("VM" or "container")
      #   - #resource_id_label ("VMID" or "CTID")
      #   - #build_resize_service(connection)
      #   - #build_presenter
      #
      module ResizeVolumeCommand
        # Class methods added when the module is included.
        module ClassMethods
          # Executes the resize volume command.
          #
          # @param args [Array<String>] command arguments [id, disk, size]
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

        # Initializes a resize volume command.
        #
        # @param args [Array<String>] command arguments
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        def initialize(args, options, global_options)
          @args = args
          @options = options
          @global_options = global_options
        end

        # Executes the resize volume command.
        #
        # @return [Integer] exit code
        def execute
          resource_id = @args[0]
          disk = @args[1]
          size_str = @args[2]

          return usage_error("#{resource_id_label} is required") unless resource_id
          return usage_error("VOLUME name is required (e.g., scsi0, virtio0, rootfs)") unless disk
          return usage_error("SIZE is required (e.g., +10G, 50G)") unless size_str

          parsed_size = Services::ResizeVolume.parse_size(size_str)
          perform_resize(resource_id.to_i, disk, parsed_size)
        rescue ArgumentError => e
          usage_error(e.message)
        rescue Services::ResizeVolume::VolumeNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::NOT_FOUND
        rescue Services::ResizeVolume::SizeTooSmallError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::GENERAL_ERROR
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

        # Builds the resize service for the given connection.
        #
        # @param connection [Connection] API connection
        # @return [Services::ResizeVolume] resize service
        def build_resize_service(connection)
          raise NotImplementedError, "#{self.class} must implement #build_resize_service"
        end

        # Builds presenter for resize results.
        #
        # @return [Presenters::Base] presenter
        def build_presenter
          raise NotImplementedError, "#{self.class} must implement #build_presenter"
        end

        # Performs the full resize flow.
        #
        # @param resource_id [Integer] VM or container ID
        # @param disk [String] disk name
        # @param parsed_size [Services::ResizeVolume::ParsedSize] parsed size
        # @return [Integer] exit code
        def perform_resize(resource_id, disk, parsed_size)
          load_config
          connection = Pvectl::Connection.new(@config)

          node = resolve_node(resource_id, connection)
          return ExitCodes::NOT_FOUND unless node

          service = build_resize_service(connection)
          info = service.preflight(resource_id, disk, parsed_size, node: node)

          return ExitCodes::SUCCESS unless confirm_operation(resource_id, info, node)

          result = service.perform(resource_id, disk, parsed_size.raw, node: node)
          output_result(result)

          result.successful? ? ExitCodes::SUCCESS : ExitCodes::GENERAL_ERROR
        end

        # Resolves node for a resource.
        #
        # @param resource_id [Integer] resource ID
        # @param connection [Connection] API connection
        # @return [String, nil] node name or nil if not found
        def resolve_node(resource_id, connection)
          return @options[:node] if @options[:node]

          resolver = Pvectl::Utils::ResourceResolver.new(connection)
          resolved = resolver.resolve(resource_id)

          unless resolved
            $stderr.puts "Error: #{resource_label} #{resource_id} not found"
            return nil
          end

          resolved[:node]
        end

        # Confirms the resize operation.
        #
        # @param resource_id [Integer] resource ID
        # @param info [Hash] preflight info (:disk, :current_size, :new_size)
        # @param node [String] node name
        # @return [Boolean] true if operation should proceed
        def confirm_operation(resource_id, info, node)
          return true if @options[:yes]

          $stdout.puts "Resize volume #{info[:disk]} on #{resource_label} #{resource_id} on node #{node}:"
          $stdout.puts "  Current size: #{info[:current_size]}"
          $stdout.puts "  New size:     #{info[:new_size]}"
          $stdout.puts ""
          $stdout.puts "This action is IRREVERSIBLE — volumes cannot be shrunk via API."
          $stdout.print "Proceed? [y/N]: "

          response = $stdin.gets&.strip&.downcase
          %w[y yes].include?(response)
        end

        # Outputs operation result.
        #
        # @param result [Models::OperationResult] operation result
        # @return [void]
        def output_result(result)
          presenter = build_presenter
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
end
