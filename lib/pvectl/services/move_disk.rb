# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates moving a VM disk or container volume to a different storage
    # on the same node.
    #
    # Operates on one resource at a time (single VM or single container).
    # Async mode (default): returns UPID immediately, no blocking.
    # Sync mode (--wait): polls Task until completion or timeout.
    #
    # @example Move VM disk async (default)
    #   service = MoveDisk.new(
    #     vm_repository: vm_repo,
    #     container_repository: ct_repo,
    #     task_repository: task_repo
    #   )
    #   result = service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")
    #
    # @example Move container volume with --wait
    #   service = MoveDisk.new(..., options: { wait: true })
    #   result = service.execute(:container, ct, disk: "rootfs", target_storage: "storage2")
    #
    class MoveDisk
      DEFAULT_TIMEOUT = 600

      # Creates a new MoveDisk service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param container_repository [Repositories::Container] Container repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (format, delete_source, bandwidth, timeout, wait)
      def initialize(vm_repository:, container_repository:, task_repository:, options: {})
        @vm_repository = vm_repository
        @container_repository = container_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes the move operation on a single resource.
      #
      # @param resource_type [Symbol] :vm or :container
      # @param resource [Models::Vm, Models::Container] resource to operate on
      # @param disk [String] disk/volume identifier (e.g., "scsi0", "rootfs")
      # @param target_storage [String] destination storage ID
      # @return [Models::VmOperationResult, Models::ContainerOperationResult]
      def execute(resource_type, resource, disk:, target_storage:)
        @resource_type = resource_type
        move_single(resource, disk, target_storage)
      end

      private

      # Performs the move on a single resource and builds the result.
      #
      # @param resource [Models::Vm, Models::Container] resource
      # @param disk [String] disk/volume identifier
      # @param target_storage [String] destination storage ID
      # @return [Models::VmOperationResult, Models::ContainerOperationResult]
      def move_single(resource, disk, target_storage)
        upid = invoke_repository(resource, disk, target_storage)

        if @options[:wait]
          task = @task_repository.wait(upid, timeout: timeout)
          build_result(resource,
                       operation: :move_disk,
                       task: task,
                       success: task.successful?)
        else
          build_result(resource,
                       operation: :move_disk,
                       task_upid: upid,
                       success: :pending)
        end
      rescue StandardError => e
        build_result(resource,
                     operation: :move_disk,
                     success: false,
                     error: e.message)
      end

      # Calls the appropriate repository method based on resource type.
      #
      # @param resource [Models::Vm, Models::Container] resource
      # @param disk [String] disk/volume identifier
      # @param target_storage [String] destination storage ID
      # @return [String] Task UPID
      def invoke_repository(resource, disk, target_storage)
        if @resource_type == :vm
          @vm_repository.move_disk(
            resource.vmid,
            resource.node,
            disk,
            target_storage,
            format: @options[:format],
            delete: @options[:delete_source] ? true : false,
            bwlimit: @options[:bandwidth]
          )
        else
          @container_repository.move_volume(
            resource.vmid,
            resource.node,
            disk,
            target_storage,
            delete: @options[:delete_source] ? true : false,
            bwlimit: @options[:bandwidth]
          )
        end
      end

      # Builds typed OperationResult for the current resource type.
      #
      # @param resource [Models::Vm, Models::Container] resource
      # @param attrs [Hash] result attributes
      # @return [Models::VmOperationResult, Models::ContainerOperationResult]
      def build_result(resource, **attrs)
        if @resource_type == :vm
          Models::VmOperationResult.new(vm: resource, **attrs)
        else
          Models::ContainerOperationResult.new(container: resource, **attrs)
        end
      end

      # Returns configured timeout.
      #
      # @return [Integer] timeout in seconds
      def timeout
        @options[:timeout] || DEFAULT_TIMEOUT
      end
    end
  end
end
