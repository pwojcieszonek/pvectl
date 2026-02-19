# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared functionality for lifecycle commands across resource types.
    #
    # Template method pattern: provides common flow (validate, resolve,
    # confirm, execute, output) while specialization modules define
    # resource-specific hooks.
    #
    # @abstract Include a specialization module (VmLifecycleCommand,
    #   ContainerLifecycleCommand) instead of this one directly.
    #
    # @example Specialization module pattern
    #   module VmLifecycleCommand
    #     def self.included(base)
    #       base.include(ResourceLifecycleCommand)
    #     end
    #
    #     private
    #     def supported_resources = %w[vm]
    #     def resource_label = "VM"
    #     # ...
    #   end
    #
    module ResourceLifecycleCommand
      # Class methods added when the module is included.
      module ClassMethods
        # Executes the lifecycle command.
        #
        # @param resource_type [String, nil] resource type (vm, ct)
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
      # @param base [Class] the class including this module
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Initializes a lifecycle command.
      #
      # @param resource_type [String, nil] resource type
      # @param resource_ids [Array<String>, String, nil] resource identifiers
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(resource_type, resource_ids, options, global_options)
        @resource_type = resource_type
        @resource_ids = Array(resource_ids).compact
        @options = options
        @global_options = global_options
      end

      # Executes the lifecycle command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Resource type required (#{supported_resources.join(', ')})") unless @resource_type
        return usage_error("Unsupported resource: #{@resource_type}") unless supported_resources.include?(@resource_type)

        if @resource_ids.empty? && !@options[:all] && selector_strings.empty?
          return usage_error("#{resource_id_label}, --all, or -l selector required")
        end

        perform_operation
      end

      private

      # --- Template methods (override in specialization) ---

      # @return [Array<String>] supported resource type strings
      def supported_resources
        raise NotImplementedError, "#{self.class} must implement #supported_resources"
      end

      # @return [String] human label for resource ("VM", "container")
      def resource_label
        raise NotImplementedError, "#{self.class} must implement #resource_label"
      end

      # @return [String] human label for resource ID ("VMID", "CTID")
      def resource_id_label
        raise NotImplementedError, "#{self.class} must implement #resource_id_label"
      end

      # @return [Object] repository for this resource type
      def build_repository(connection)
        raise NotImplementedError, "#{self.class} must implement #build_repository"
      end

      # @return [Object] lifecycle service
      def build_service(repo, task_repo, options)
        raise NotImplementedError, "#{self.class} must implement #build_service"
      end

      # @return [Object] presenter for results
      def build_presenter
        raise NotImplementedError, "#{self.class} must implement #build_presenter"
      end

      # @return [Object] selector for filtering
      def build_selector(strings)
        raise NotImplementedError, "#{self.class} must implement #build_selector"
      end

      # --- Shared implementation ---

      # Performs the lifecycle operation.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        repo = build_repository(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        resources = resolve_resources(repo)
        return no_resources_found if resources.empty?
        return Pvectl::ExitCodes::SUCCESS unless confirm_operation(resources)

        service = build_service(repo, task_repo, service_options)
        results = service.execute(operation_name, resources)

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
        Pvectl::ExitCodes::GENERAL_ERROR
      end

      # Resolves resources based on resource_ids, --all flag, or selectors.
      #
      # @param repo [Object] resource repository
      # @return [Array<Object>] resolved resources
      def resolve_resources(repo)
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

      # Returns selector strings from options.
      #
      # @return [Array<String>] selector strings
      def selector_strings
        Array(@options[:selector] || @options[:l])
      end

      # Applies selectors to resource collection.
      #
      # @param resources [Array<Object>] resources to filter
      # @return [Array<Object>] filtered resources
      def apply_selectors(resources)
        return resources if selector_strings.empty?

        selector = build_selector(selector_strings)
        selector.apply(resources)
      end

      # Confirms multi-resource operation with user.
      #
      # @param resources [Array<Object>] resources to operate on
      # @return [Boolean] true if operation should proceed
      def confirm_operation(resources)
        return true if resources.size == 1
        return true if @options[:yes]

        $stdout.puts "You are about to #{operation_name} #{resources.size} #{resource_label}s:"
        resources.each { |r| $stdout.puts "  - #{r.vmid} (#{r.name || 'unnamed'}) on #{r.node}" }
        $stdout.puts ""
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
      end

      # Returns the operation name for this command.
      #
      # @return [Symbol] operation name
      def operation_name
        self.class::OPERATION
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
        opts[:wait] = true if @options[:wait]
        opts[:fail_fast] = true if @options[:"fail-fast"]
        opts
      end

      # Outputs operation results using the configured formatter.
      #
      # @param results [Array<Object>] operation results
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
      # @param results [Array<Object>] operation results
      # @return [Integer] exit code
      def determine_exit_code(results)
        return Pvectl::ExitCodes::SUCCESS if results.all?(&:successful?)
        return Pvectl::ExitCodes::SUCCESS if results.all?(&:pending?)

        Pvectl::ExitCodes::GENERAL_ERROR
      end

      # Outputs usage error and returns exit code.
      #
      # @param message [String] error message
      # @return [Integer] exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        Pvectl::ExitCodes::USAGE_ERROR
      end

      # Outputs no resources found error and returns exit code.
      #
      # @return [Integer] exit code
      def no_resources_found
        msg = if @options[:all] || selector_strings.any?
                @options[:node] ? "No #{resource_label}s found on node #{@options[:node]}" : "No #{resource_label}s found matching criteria"
              else
                "No #{resource_label}s found for given #{resource_id_label}s"
              end
        $stderr.puts "Error: #{msg}"
        Pvectl::ExitCodes::NOT_FOUND
      end
    end
  end
end
