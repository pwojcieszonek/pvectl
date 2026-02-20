# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared functionality for irreversible batch commands (delete, template).
    #
    # Provides the generic flow: resolve resources → confirm → execute → format results.
    # Submodules override hooks to customize behavior per operation.
    #
    # @example Including in an operation-specific module
    #   module TemplateCommand
    #     include IrreversibleCommand
    #
    #     def self.included(base)
    #       base.extend(IrreversibleCommand::ClassMethods)
    #     end
    #   end
    #
    module IrreversibleCommand
      # Class methods added when the module is included.
      module ClassMethods
        # Executes the command.
        #
        # @param resource_type [String, nil] resource type (vm, container)
        # @param resource_ids [Array<String>, String, nil] resource identifiers
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def execute(resource_type, resource_ids, options, global_options)
          new(resource_type, resource_ids, options, global_options).execute
        end
      end

      # Hook called when module is included.
      #
      # @param base [Module] the module or class including this module
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Initializes an irreversible command.
      #
      # @param resource_type [String, nil] resource type (vm, container)
      # @param resource_ids [Array<String>, String, nil] resource identifiers
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(resource_type, resource_ids, options, global_options)
        @resource_type = resource_type
        @resource_ids = Array(resource_ids).compact
        @options = options
        @global_options = global_options
      end

      # Executes the command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Resource type required (#{supported_types.join(', ')})") unless @resource_type
        return usage_error("Unsupported resource: #{@resource_type}") unless supported_resource?

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

      # Returns supported resource type strings.
      #
      # @return [Array<String>] supported types
      def supported_types
        self.class::SUPPORTED_RESOURCES
      end

      # Checks if resource type is supported.
      #
      # @return [Boolean] true if supported
      def supported_resource?
        supported_types.include?(@resource_type)
      end

      # Performs the operation. Override in submodule for custom flow.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        resources = resolve_resources(connection)
        return no_resources_found if resources.empty?
        return ExitCodes::SUCCESS unless confirm_operation(resources)

        results = perform_service_call(resources, connection)
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
        repo = build_repository(connection)

        resources = if @options[:all]
                      repo.list(node: @options[:node])
                    elsif @resource_ids.any?
                      resolved = @resource_ids.map { |id| repo.get(id.to_i) }.compact
                      resolved = resolved.select { |r| r.node == @options[:node] } if @options[:node]
                      resolved
                    else
                      return [] if selector_strings.empty?
                      repo.list(node: @options[:node])
                    end

        apply_selectors(resources)
      end

      # Builds the appropriate repository for the resource type.
      #
      # @param connection [Connection] API connection
      # @return [Repositories::Base] repository
      def build_repository(connection)
        if resource_type_symbol == :vm
          Pvectl::Repositories::Vm.new(connection)
        else
          Pvectl::Repositories::Container.new(connection)
        end
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

      # Confirms the operation with the user.
      # Override in submodule for custom confirmation logic.
      #
      # @param resources [Array] Resources to operate on
      # @return [Boolean] true if operation should proceed
      def confirm_operation(resources)
        raise NotImplementedError, "#{self.class} must implement #confirm_operation"
      end

      # Performs the actual service call for the operation.
      # Must be implemented by the including module.
      #
      # @param resources [Array] resources to operate on
      # @param connection [Connection] API connection
      # @return [Array<Models::OperationResult>] results
      def perform_service_call(resources, connection)
        raise NotImplementedError, "#{self.class} must implement #perform_service_call"
      end

      # Builds the presenter for results output.
      # Must be implemented by the including module.
      #
      # @return [Presenters::Base] presenter
      def build_presenter
        raise NotImplementedError, "#{self.class} must implement #build_presenter"
      end

      # Loads configuration from file or environment.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Builds base service options from command options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:timeout] = @options[:timeout] if @options[:timeout]
        opts[:async] = true if @options[:async]
        opts[:force] = true if @options[:force]
        opts[:fail_fast] = true if @options[:"fail-fast"]
        opts
      end

      # Outputs operation results using the configured formatter.
      #
      # @param results [Array<Models::OperationResult>] operation results
      # @return [void]
      def output_results(results)
        presenter = build_presenter
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
