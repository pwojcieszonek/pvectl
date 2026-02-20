# frozen_string_literal: true

module Pvectl
  module Commands
    # Template-specific functionality built on IrreversibleCommand.
    #
    # Converts VMs/containers to Proxmox templates (irreversible operation).
    # Filters out resources that are already templates with a warning.
    # Calls the repository's convert_to_template method for each resource.
    #
    # @example Including in a command class
    #   class TemplateVm
    #     include TemplateCommand
    #     RESOURCE_TYPE = :vm
    #     SUPPORTED_RESOURCES = %w[vm].freeze
    #   end
    #
    module TemplateCommand
      include IrreversibleCommand

      # Hook called when module is included.
      #
      # @param base [Class] the class including this module
      def self.included(base)
        base.extend(IrreversibleCommand::ClassMethods)
      end

      private

      # Overrides perform_operation to filter already-template resources.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        resources = resolve_resources(connection)
        return no_resources_found if resources.empty?

        # Filter out already-template resources with warning
        convertible, already_templates = resources.partition { |r| !r.template? }

        already_templates.each do |r|
          type_name = resource_type_symbol == :vm ? "VM" : "Container"
          $stderr.puts "Warning: #{type_name} #{r.vmid} is already a template, skipping"
        end

        return ExitCodes::SUCCESS if convertible.empty?
        return ExitCodes::SUCCESS unless confirm_operation(convertible)

        results = perform_service_call(convertible, connection)
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

      # Confirms template operation — uses --force flag.
      #
      # @param resources [Array] Resources to convert
      # @return [Boolean] true if operation should proceed
      def confirm_operation(resources)
        return true if @options[:force]

        $stdout.puts confirm_message(resources)
        $stdout.puts ""
        $stdout.puts irreversibility_warning
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
      end

      # Returns confirmation message for template conversion.
      #
      # @param resources [Array] resources to convert
      # @return [String] confirmation message
      def confirm_message(resources)
        type_name = resource_type_symbol == :vm ? "VM" : "container"
        type_plural = resource_type_symbol == :vm ? "VMs" : "containers"

        if resources.size == 1
          r = resources.first
          "You are about to convert #{type_name} #{r.vmid} (#{r.name || 'unnamed'}) on #{r.node} to a template."
        else
          lines = ["You are about to convert #{resources.size} #{type_plural} to templates:"]
          resources.each { |r| lines << "  - #{r.vmid} (#{r.name || 'unnamed'}) on #{r.node}" }
          lines.join("\n")
        end
      end

      # Returns irreversibility warning for template conversion.
      #
      # @return [String] warning text
      def irreversibility_warning
        "This action is IRREVERSIBLE. Templates cannot be converted back and cannot be started."
      end

      # Performs template conversion for each resource.
      #
      # @param resources [Array] resources to convert
      # @param connection [Connection] API connection
      # @return [Array<Models::OperationResult>] results
      def perform_service_call(resources, connection)
        repo = build_repository(connection)
        resources.map do |resource|
          convert_single(repo, resource)
        end
      end

      # Converts a single resource to template.
      #
      # @param repo [Repositories::Base] repository
      # @param resource [Models::Vm, Models::Container] resource to convert
      # @return [Models::OperationResult] result
      def convert_single(repo, resource)
        if resource_type_symbol == :vm
          repo.convert_to_template(resource.vmid, resource.node, disk: @options[:disk])
        else
          repo.convert_to_template(resource.vmid, resource.node)
        end

        build_success_result(resource)
      rescue StandardError => e
        build_error_result(resource, e.message)
      end

      # Builds a successful operation result.
      #
      # @param resource [Models::Vm, Models::Container] resource
      # @return [Models::OperationResult] success result
      def build_success_result(resource)
        result_class = resource_type_symbol == :vm ? Models::VmOperationResult : Models::ContainerOperationResult
        attrs = { operation: :template, success: true }
        attrs[resource_type_symbol == :vm ? :vm : :container] = resource
        result_class.new(attrs)
      end

      # Builds an error operation result.
      #
      # @param resource [Models::Vm, Models::Container] resource
      # @param error_message [String] error message
      # @return [Models::OperationResult] error result
      def build_error_result(resource, error_message)
        result_class = resource_type_symbol == :vm ? Models::VmOperationResult : Models::ContainerOperationResult
        attrs = { operation: :template, success: false, error: error_message }
        attrs[resource_type_symbol == :vm ? :vm : :container] = resource
        result_class.new(attrs)
      end

      # Builds presenter for template results.
      #
      # @return [Presenters::Base] presenter
      def build_presenter
        if resource_type_symbol == :vm
          Pvectl::Presenters::VmOperationResult.new
        else
          Pvectl::Presenters::ContainerOperationResult.new
        end
      end
    end
  end
end
