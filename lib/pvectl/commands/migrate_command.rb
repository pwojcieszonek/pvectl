# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared functionality for migrate commands (migrate vm, migrate container).
    #
    # This module extracts common code used by MigrateVm and MigrateContainer.
    # Pattern: identical to DeleteCommand module but with migrate-specific behavior:
    # - Requires --target flag (no default)
    # - Validates --restart only for containers
    # - Async is default (no --async flag), --wait for sync
    # - partition_by_target logic is in Service layer
    #
    # @example Including in a command class
    #   class MigrateVm
    #     include MigrateCommand
    #     RESOURCE_TYPE = :vm
    #     SUPPORTED_RESOURCES = %w[vm].freeze
    #   end
    #
    module MigrateCommand
      # Valid Proxmox node name format: lowercase alphanumeric, starting with letter, hyphens allowed.
      NODE_NAME_FORMAT = /\A[a-z][a-z0-9-]*\z/

      # Class methods added when the module is included.
      module ClassMethods
        # Executes the migrate command.
        #
        # @param args [Array<String>] resource identifiers
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

      # Initializes a migrate command.
      #
      # @param args [Array<String>] resource identifiers
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @resource_ids = Array(args).compact
        @options = options
        @global_options = global_options
      end

      # Executes the migrate command.
      #
      # @return [Integer] exit code
      def execute
        target = @options[:target]
        return usage_error("--target is required") if target.nil? || target.empty?

        unless target.match?(NODE_NAME_FORMAT)
          return usage_error("Invalid target node name: #{target}")
        end

        return usage_error("--restart is only supported for containers") if restart_not_allowed?

        if @resource_ids.empty? && !@options[:all] && selector_strings.empty?
          return usage_error("VMID, --all, or -l selector required")
        end

        perform_operation
      end

      private

      # Returns the resource type symbol (:vm or :container).
      #
      # @return [Symbol] resource type
      def resource_type_symbol
        self.class::RESOURCE_TYPE
      end

      # Checks if --restart is used for a non-container resource.
      #
      # @return [Boolean] true if restart flag is invalid
      def restart_not_allowed?
        @options[:restart] && resource_type_symbol == :vm
      end

      # Performs the migrate operation.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        resources = resolve_resources(connection)
        return no_resources_found if resources.empty?

        target = @options[:target]
        return ExitCodes::SUCCESS unless confirm_operation(resources, target)

        vm_repo = Pvectl::Repositories::Vm.new(connection)
        container_repo = Pvectl::Repositories::Container.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::ResourceMigration.new(
          vm_repository: vm_repo,
          container_repository: container_repo,
          task_repository: task_repo,
          options: service_options
        )

        results = service.execute(resource_type_symbol, resources, target: target)
        return ExitCodes::SUCCESS if results.empty?

        output_results(results)
        determine_exit_code(results)
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

      # Resolves resources based on IDs, --all flag, or selectors.
      #
      # @param connection [Connection] API connection
      # @return [Array<Models::Vm, Models::Container>] resolved resources
      def resolve_resources(connection)
        repo = resource_type_symbol == :vm ?
          Pvectl::Repositories::Vm.new(connection) :
          Pvectl::Repositories::Container.new(connection)

        resources = if @options[:all]
                      repo.list(node: @options[:node])
                    elsif @resource_ids.any?
                      @resource_ids.each do |id|
                        unless id.match?(/\A\d+\z/)
                          raise ArgumentError, "Invalid VMID/CTID: #{id}"
                        end
                      end
                      resolved = @resource_ids.map { |id| repo.get(id.to_i) }.compact
                      resolved = resolved.select { |r| r.node == @options[:node] } if @options[:node]
                      resolved
                    else
                      return [] if selector_strings.empty?
                      repo.list(node: @options[:node])
                    end

        apply_selectors(resources)
      end

      # Returns selector strings from options.
      #
      # @return [Array<String>] selector strings
      def selector_strings
        Array(@options[:selector] || @options[:l])
      end

      # Applies selectors to resource collection.
      #
      # @param resources [Array] Resources to filter
      # @return [Array] Filtered resources
      def apply_selectors(resources)
        return resources if selector_strings.empty?

        selector_class = resource_type_symbol == :vm ? Selectors::Vm : Selectors::Container
        selector = selector_class.parse_all(selector_strings)
        selector.apply(resources)
      end

      # Confirms migrate operation with user.
      #
      # @param resources [Array] Resources to migrate
      # @param target [String] Target node name
      # @return [Boolean] true if operation should proceed
      def confirm_operation(resources, target)
        return true if @options[:yes]

        type_name = resource_type_symbol == :vm ? "VM" : "container"
        type_plural = resource_type_symbol == :vm ? "VMs" : "containers"

        if resources.size == 1
          r = resources.first
          $stdout.puts "You are about to migrate #{type_name} #{r.vmid} (#{r.name || 'unnamed'}) from #{r.node} to #{target}."
        else
          $stdout.puts "You are about to migrate #{resources.size} #{type_plural} to #{target}:"
          resources.each { |r| $stdout.puts "  - #{r.vmid} (#{r.name || 'unnamed'}) on #{r.node}" }
        end

        $stdout.puts ""
        $stdout.puts "This will migrate the #{type_plural} to node #{target}."
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
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
        opts[:wait] = true if @options[:wait]
        opts[:online] = true if @options[:online]
        opts[:restart] = true if @options[:restart]
        opts[:target_storage] = @options[:"target-storage"] if @options[:"target-storage"]
        opts[:fail_fast] = true if @options[:"fail-fast"]
        opts
      end

      # Outputs operation results using the configured formatter.
      #
      # @param results [Array<Models::OperationResult>] operation results
      # @return [void]
      def output_results(results)
        presenter = if resource_type_symbol == :vm
                      Pvectl::Presenters::VmOperationResult.new
                    else
                      Pvectl::Presenters::ContainerOperationResult.new
                    end
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format(results, presenter, color: color_flag)
        puts output
      end

      # Determines exit code based on results.
      #
      # @param results [Array<Models::OperationResult>] operation results
      # @return [Integer] exit code
      def determine_exit_code(results)
        return ExitCodes::SUCCESS if results.all?(&:successful?)
        return ExitCodes::SUCCESS if results.all?(&:pending?)

        ExitCodes::GENERAL_ERROR
      end

      # Outputs usage error and returns exit code.
      #
      # @param message [String] error message
      # @return [Integer] exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end

      # Outputs no resources found error and returns exit code.
      #
      # @return [Integer] exit code
      def no_resources_found
        type_plural = resource_type_symbol == :vm ? "VMs" : "containers"
        msg = if @options[:all] || selector_strings.any?
                @options[:node] ? "No #{type_plural} found on node #{@options[:node]}" : "No #{type_plural} found matching criteria"
              else
                "No #{type_plural} found for given IDs"
              end
        $stderr.puts "Error: #{msg}"
        ExitCodes::NOT_FOUND
      end
    end
  end
end
