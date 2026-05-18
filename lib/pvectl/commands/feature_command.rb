# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared functionality for the feature query commands (feature vm, feature ct).
    #
    # Queries whether a Proxmox feature (clone, snapshot, copy) is available for
    # a given VM or container. Availability depends on storage type, snapshot
    # state, and other server-side conditions.
    #
    # Designed with the hybrid Template Method pattern (MoveDiskCommand /
    # MigrateCommand) — specializations only set RESOURCE_TYPE and
    # SUPPORTED_RESOURCES; the FeatureVm specialization additionally implements
    # +.register+ which wires the GLI command.
    #
    # @example Including in a command class
    #   class FeatureVm
    #     include FeatureCommand
    #     RESOURCE_TYPE = :vm
    #     SUPPORTED_RESOURCES = %w[vm].freeze
    #   end
    #
    module FeatureCommand
      # Valid feature names per Proxmox API (both QEMU and LXC endpoints).
      VALID_FEATURES = %w[clone snapshot copy].freeze

      # Class methods added when the module is included.
      module ClassMethods
        # Executes the feature query command.
        #
        # @param args [Array<String>] command-positional args ([id, feature])
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def execute(args, options, global_options)
          new(args, options, global_options).execute
        end
      end

      # Hook called when the module is included.
      #
      # @param base [Class] the class including this module
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Initializes a feature query command.
      #
      # @param args [Array<String>] command-positional args ([id, feature])
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = Array(args).compact
        @options = options
        @global_options = global_options
      end

      # Executes the feature query.
      #
      # @return [Integer] exit code (0 if available, 1 if unavailable, 2 on usage)
      def execute
        return usage_error("#{id_label} is required") if @args.empty?
        return usage_error("FEATURE is required") if @args.size < 2

        id_str = @args[0]
        feature = @args[1]

        unless id_str.to_s.match?(/\A\d+\z/)
          return usage_error("Invalid #{id_label}: #{id_str}")
        end

        unless VALID_FEATURES.include?(feature)
          return usage_error(
            "Invalid feature: #{feature} (allowed: #{VALID_FEATURES.join(', ')})"
          )
        end

        perform_operation(id_str.to_i, feature)
      end

      private

      # Returns the resource type symbol (:vm or :container).
      #
      # @return [Symbol]
      def resource_type_symbol
        self.class::RESOURCE_TYPE
      end

      # Returns the human label for the resource ID ("VMID" or "CTID").
      #
      # @return [String]
      def id_label
        resource_type_symbol == :vm ? "VMID" : "CTID"
      end

      # Returns the singular type name ("VM" or "container") used in error messages.
      #
      # @return [String]
      def type_name
        resource_type_symbol == :vm ? "VM" : "container"
      end

      # Performs the feature availability check.
      #
      # @param id [Integer] resource identifier
      # @param feature [String] feature name
      # @return [Integer] exit code
      def perform_operation(id, feature)
        load_config
        connection = Pvectl::Connection.new(@config)

        resource = resolve_resource(connection, id)
        return resource_not_found(id) if resource.nil?

        result = build_repository(connection)
          .feature_available?(id, resource.node, feature, snapname: @options[:snapname])

        output_result(result, feature)
        result[:available] ? ExitCodes::SUCCESS : ExitCodes::GENERAL_ERROR
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

      # Resolves the resource (VM or container) by ID using the appropriate repository.
      #
      # @param connection [Connection] API connection
      # @param id [Integer] resource ID
      # @return [Models::Vm, Models::Container, nil]
      def resolve_resource(connection, id)
        build_repository(connection).get(id)
      end

      # Builds the resource repository (VM or Container) for the current type.
      #
      # @param connection [Connection] API connection
      # @return [Repositories::Vm, Repositories::Container]
      def build_repository(connection)
        if resource_type_symbol == :vm
          Pvectl::Repositories::Vm.new(connection)
        else
          Pvectl::Repositories::Container.new(connection)
        end
      end

      # Loads configuration from file or environment.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Outputs the result in the requested format.
      #
      # Plain output: "available"/"unavailable" + optional list of capable nodes.
      # JSON/YAML output: structured hash with feature metadata.
      #
      # @param result [Hash] result from +feature_available?+ (:available, :nodes)
      # @param feature [String] feature name
      # @return [void]
      def output_result(result, feature)
        format = (@global_options[:output] || "plain").to_s

        case format
        when "json"
          require "json"
          $stdout.puts JSON.pretty_generate(payload(result, feature))
        when "yaml"
          require "yaml"
          $stdout.puts YAML.dump(stringify_keys(payload(result, feature)))
        else
          status = result[:available] ? "available" : "unavailable"
          $stdout.puts status
          if result[:available] && !result[:nodes].empty?
            $stdout.puts "nodes: #{result[:nodes].join(', ')}"
          end
        end
      end

      # Builds the structured result payload for JSON/YAML output.
      #
      # @param result [Hash] feature_available? result
      # @param feature [String] feature name
      # @return [Hash]
      def payload(result, feature)
        {
          available: result[:available],
          feature: feature,
          snapname: @options[:snapname],
          nodes: result[:nodes]
        }
      end

      # Converts symbol keys to strings for YAML output.
      #
      # @param hash [Hash]
      # @return [Hash]
      def stringify_keys(hash)
        hash.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
      end

      # Outputs usage error and returns the usage exit code.
      #
      # @param message [String]
      # @return [Integer]
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end

      # Outputs "not found" error and returns the not-found exit code.
      #
      # @param id [Integer]
      # @return [Integer]
      def resource_not_found(id)
        $stderr.puts "Error: No #{type_name} found with ID #{id}"
        ExitCodes::NOT_FOUND
      end
    end
  end
end
