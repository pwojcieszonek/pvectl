# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates backup operations.
    #
    # Handles creating, listing, deleting, and restoring backups
    # for VMs and containers with multi-ID support and error handling.
    #
    # @example Basic usage
    #   service = Backup.new(
    #     backup_repo: backup_repo,
    #     resource_resolver: resolver,
    #     task_repo: task_repo
    #   )
    #   backups = service.list(vmid: 100)
    #
    class Backup
      DEFAULT_TIMEOUT = 300 # 5 minutes for backups

      # Creates a new Backup service.
      #
      # @param backup_repo [Repositories::Backup] Backup repository
      # @param resource_resolver [Utils::ResourceResolver] Resource resolver
      # @param task_repo [Repositories::Task] Task repository
      # @param options [Hash] Options (timeout, async, fail_fast)
      def initialize(backup_repo:, resource_resolver:, task_repo:, options: {})
        @backup_repo = backup_repo
        @resolver = resource_resolver
        @task_repo = task_repo
        @options = options
      end

      # Lists backups with optional filtering.
      #
      # @param vmid [Integer, nil] filter by VM ID
      # @param storage [String, nil] filter by storage
      # @return [Array<Models::Backup>]
      def list(vmid: nil, storage: nil)
        @backup_repo.list(vmid: vmid, storage: storage)
      end

      # Creates backups for multiple VMs.
      #
      # @param vmids [Array<Integer>] VM IDs
      # @param storage [String] target storage
      # @param mode [String] backup mode (snapshot/suspend/stop)
      # @param compress [String] compression (zstd/gzip/lzo/0)
      # @param notes [String, nil] backup notes
      # @param protected [Boolean] protect backup
      # @return [Array<Models::OperationResult>]
      def create(vmids, storage:, mode: "snapshot", compress: "zstd", notes: nil, protected: false)
        resources = @resolver.resolve_multiple(vmids)
        return [] if resources.empty?

        execute_multi(resources, :create) do |resource|
          @backup_repo.create(
            resource[:vmid],
            resource[:node],
            storage: storage,
            mode: mode,
            compress: compress,
            notes: notes,
            protected: protected
          )
        end
      end

      # Deletes a backup.
      #
      # @param volid [String] backup volume ID
      # @return [Models::OperationResult]
      def delete(volid)
        node = find_node_for_volid(volid)

        upid = @backup_repo.delete(volid, node)

        if @options[:async]
          Models::OperationResult.new(
            resource: { volid: volid, node: node },
            operation: :delete,
            task_upid: upid,
            success: :pending
          )
        else
          task = @task_repo.wait(upid, timeout: timeout)
          Models::OperationResult.new(
            resource: { volid: volid, node: node },
            operation: :delete,
            task: task,
            success: task.successful?
          )
        end
      rescue StandardError => e
        Models::OperationResult.new(
          resource: { volid: volid },
          operation: :delete,
          success: false,
          error: e.message
        )
      end

      # Restores a backup to a VM/container.
      #
      # @param volid [String] backup volume ID
      # @param vmid [Integer] target VM ID
      # @param storage [String, nil] target storage
      # @param force [Boolean] overwrite existing
      # @param start [Boolean] start after restore
      # @param unique [Boolean] regenerate unique properties
      # @return [Models::OperationResult]
      def restore(volid, vmid:, storage: nil, force: false, start: false, unique: false)
        node = find_node_for_volid(volid)

        upid = @backup_repo.restore(
          volid,
          node,
          vmid: vmid,
          storage: storage,
          force: force,
          start: start,
          unique: unique
        )

        if @options[:async]
          Models::OperationResult.new(
            resource: { volid: volid, vmid: vmid, node: node },
            operation: :restore,
            task_upid: upid,
            success: :pending
          )
        else
          task = @task_repo.wait(upid, timeout: timeout)
          Models::OperationResult.new(
            resource: { volid: volid, vmid: vmid, node: node },
            operation: :restore,
            task: task,
            success: task.successful?
          )
        end
      rescue StandardError => e
        Models::OperationResult.new(
          resource: { volid: volid, vmid: vmid },
          operation: :restore,
          success: false,
          error: e.message
        )
      end

      private

      def execute_multi(resources, operation)
        results = []

        resources.each do |resource|
          result = execute_single(resource, operation) { yield(resource) }
          results << result

          break if @options[:fail_fast] && result.failed?
        end

        results
      end

      def execute_single(resource, operation)
        upid = yield

        if @options[:async]
          Models::OperationResult.new(
            resource: resource,
            operation: operation,
            task_upid: upid,
            success: :pending
          )
        else
          task = @task_repo.wait(upid, timeout: timeout)
          Models::OperationResult.new(
            resource: resource,
            operation: operation,
            task: task,
            success: task.successful?
          )
        end
      rescue StandardError => e
        Models::OperationResult.new(
          resource: resource,
          operation: operation,
          success: false,
          error: e.message
        )
      end

      def timeout
        @options[:timeout] || DEFAULT_TIMEOUT
      end

      # Finds the node for a backup by searching all backups.
      #
      # @param volid [String] backup volume ID
      # @return [String] node name
      # @raise [StandardError] if backup not found
      def find_node_for_volid(volid)
        backups = @backup_repo.list
        backup = backups.find { |b| b.volid == volid }
        backup&.node || raise("Backup not found: #{volid}")
      end
    end
  end
end
