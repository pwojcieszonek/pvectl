# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates migration of VMs and containers between cluster nodes.
    #
    # Single service for both resource types, parameterized by resource_type.
    # Async mode (default): returns UPID immediately, no blocking.
    # Sync mode (--wait): polls Task until completion or timeout.
    #
    # @example Migrate VMs async (default)
    #   service = ResourceMigration.new(vm_repository: vm_repo, container_repository: ct_repo, task_repository: task_repo)
    #   results = service.execute(:vm, [vm1, vm2], target: "pve2")
    #
    # @example Migrate with sync wait
    #   service = ResourceMigration.new(..., options: { wait: true })
    #   results = service.execute(:vm, [vm], target: "pve2")
    #
    class ResourceMigration
      DEFAULT_TIMEOUT = 600

      # Creates a new ResourceMigration service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param container_repository [Repositories::Container] Container repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (online, restart, target_storage, timeout, wait, fail_fast)
      def initialize(vm_repository:, container_repository:, task_repository:, options: {})
        @vm_repository = vm_repository
        @container_repository = container_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes migration operation on resources.
      #
      # @param resource_type [Symbol] :vm or :container
      # @param resources [Array<Models::Vm, Models::Container>] Resources to migrate
      # @param target [String] Target node name
      # @return [Array<Models::OperationResult>] Results for each resource
      def execute(resource_type, resources, target:)
        @resource_type = resource_type

        migratable, skipped = partition_by_target(resources, target)
        report_skipped(skipped, target)
        return all_on_target_results(target) if migratable.empty?

        results = []
        migratable.each do |resource|
          result = migrate_single(resource, target)
          results << result

          break if @options[:fail_fast] && result.failed?
        end

        results
      end

      private

      # Partitions resources into migratable and already-on-target groups.
      #
      # @param resources [Array] Resources to partition
      # @param target [String] Target node name
      # @return [Array<Array, Array>] [migratable, skipped]
      def partition_by_target(resources, target)
        resources.partition { |r| r.node != target }
      end

      # Reports skipped resources to stderr.
      #
      # @param skipped [Array] Resources already on target
      # @param target [String] Target node name
      # @return [void]
      def report_skipped(skipped, target)
        type_name = @resource_type == :vm ? "VM" : "container"
        skipped.each do |r|
          $stderr.puts "Skipping #{type_name} #{r.vmid} (already on #{target})"
        end
      end

      # Handles case when all resources are already on target.
      #
      # @param target [String] Target node name
      # @return [Array] Empty results array
      def all_on_target_results(target)
        $stderr.puts "All resources are already on target node #{target}"
        []
      end

      # Migrates a single resource.
      #
      # @param resource [Models::Vm, Models::Container] Resource to migrate
      # @param target [String] Target node name
      # @return [Models::OperationResult] Result
      def migrate_single(resource, target)
        repo = repository_for(@resource_type)
        params = build_migrate_params(target)
        upid = repo.migrate(resource.vmid, resource.node, params)

        if @options[:wait]
          task = @task_repository.wait(upid, timeout: timeout)
          build_result(resource,
            operation: :migrate,
            task: task,
            success: task.successful?
          )
        else
          build_result(resource,
            operation: :migrate,
            task_upid: upid,
            success: :pending
          )
        end
      rescue StandardError => e
        build_result(resource,
          operation: :migrate,
          success: false,
          error: e.message
        )
      end

      # Builds migration parameters for the API call.
      #
      # @param target [String] Target node name
      # @return [Hash] Migration parameters
      def build_migrate_params(target)
        params = { target: target }

        if @options[:online]
          params[:online] = 1
          params[:"with-local-disks"] = 1 if @resource_type == :vm
        end

        params[:restart] = 1 if @options[:restart] && @resource_type == :container
        params[:targetstorage] = @options[:target_storage] if @options[:target_storage]

        params
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
