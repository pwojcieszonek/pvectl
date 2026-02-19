# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates deletion of VMs and containers.
    #
    # Handles validation, force-stop of running resources, and async/sync modes.
    #
    # @example Delete stopped VMs
    #   service = ResourceDelete.new(vm_repository: vm_repo, container_repository: ct_repo, task_repository: task_repo)
    #   results = service.execute(:vm, [vm1, vm2])
    #
    # @example Delete with force (stops running VMs first)
    #   service = ResourceDelete.new(..., options: { force: true })
    #   results = service.execute(:vm, [running_vm])
    #
    class ResourceDelete
      DEFAULT_TIMEOUT = 60

      # Creates a new ResourceDelete service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param container_repository [Repositories::Container] Container repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (force, keep_disks, purge, timeout, async, fail_fast)
      def initialize(vm_repository:, container_repository:, task_repository:, options: {})
        @vm_repository = vm_repository
        @container_repository = container_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes delete operation on resources.
      #
      # @param resource_type [Symbol] :vm or :container
      # @param resources [Array<Models::Vm, Models::Container>] Resources to delete
      # @return [Array<Models::OperationResult>] Results for each resource
      def execute(resource_type, resources)
        @resource_type = resource_type
        results = []

        resources.each do |resource|
          result = delete_single(resource)
          results << result

          break if @options[:fail_fast] && result.failed?
        end

        results
      end

      private

      # Deletes a single resource.
      #
      # @param resource [Models::Vm, Models::Container] Resource to delete
      # @return [Models::OperationResult] Result
      def delete_single(resource)
        # Check if running
        if resource.status == "running"
          return running_error(resource) unless @options[:force]

          stop_result = stop_resource(resource)
          return stop_result if stop_result.failed?
        end

        # Perform delete
        perform_delete(resource)
      rescue StandardError => e
        build_result(resource,
          operation: :delete,
          success: false,
          error: e.message
        )
      end

      # Returns error for running resource.
      #
      # @param resource [Models::Vm, Models::Container] Resource
      # @return [Models::OperationResult] Failed result
      def running_error(resource)
        type_name = @resource_type == :vm ? "VM" : "Container"
        build_result(resource,
          operation: :delete,
          success: false,
          error: "#{type_name} #{resource.vmid} is running. Stop it first or use --force"
        )
      end

      # Stops a running resource.
      #
      # @param resource [Models::Vm, Models::Container] Resource
      # @return [Models::OperationResult] Result
      def stop_resource(resource)
        repo = repository_for(@resource_type)
        upid = repo.stop(resource.vmid, resource.node)
        task = @task_repository.wait(upid, timeout: timeout)

        if task.successful?
          build_result(resource, operation: :stop, task: task, success: true)
        else
          build_result(resource,
            operation: :delete,
            success: false,
            error: "Failed to stop: #{task.exitstatus}"
          )
        end
      end

      # Performs the actual delete operation.
      #
      # @param resource [Models::Vm, Models::Container] Resource
      # @return [Models::OperationResult] Result
      def perform_delete(resource)
        repo = repository_for(@resource_type)
        delete_opts = {
          destroy_disks: !@options[:keep_disks],
          purge: @options[:purge] || false,
          force: false
        }

        upid = repo.delete(resource.vmid, resource.node, **delete_opts)

        if @options[:async]
          build_result(resource,
            operation: :delete,
            task_upid: upid,
            success: :pending
          )
        else
          task = @task_repository.wait(upid, timeout: timeout)
          build_result(resource,
            operation: :delete,
            task: task,
            success: task.successful?
          )
        end
      end

      # Builds typed OperationResult for the current resource type.
      #
      # @param resource [Models::Vm, Models::Container] Resource
      # @param attrs [Hash] Result attributes
      # @return [Models::VmOperationResult, Models::ContainerOperationResult] Typed result
      def build_result(resource, **attrs)
        if @resource_type == :vm
          Models::VmOperationResult.new(vm: resource, **attrs)
        else
          Models::ContainerOperationResult.new(container: resource, **attrs)
        end
      end

      # Returns the appropriate repository for resource type.
      #
      # @param type [Symbol] :vm or :container
      # @return [Repositories::Vm, Repositories::Container] Repository
      def repository_for(type)
        type == :vm ? @vm_repository : @container_repository
      end

      # Returns configured timeout.
      #
      # @return [Integer] Timeout in seconds
      def timeout
        @options[:timeout] || DEFAULT_TIMEOUT
      end
    end
  end
end
