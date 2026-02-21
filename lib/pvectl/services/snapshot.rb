# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates snapshot operations.
    #
    # Handles listing, creating, deleting and rolling back snapshots
    # for VMs and containers with unified interface.
    #
    # @example Basic usage
    #   service = Snapshot.new(
    #     snapshot_repo: snapshot_repo,
    #     resource_resolver: resolver,
    #     task_repo: task_repo
    #   )
    #   snapshots = service.list([100, 101])
    #
    class Snapshot
      DEFAULT_TIMEOUT = 60

      # Creates a new Snapshot service.
      #
      # @param snapshot_repo [Repositories::Snapshot] Snapshot repository
      # @param resource_resolver [Utils::ResourceResolver] Resource resolver
      # @param task_repo [Repositories::Task] Task repository
      # @param options [Hash] Options (timeout, async, fail_fast)
      def initialize(snapshot_repo:, resource_resolver:, task_repo:, options: {})
        @snapshot_repo = snapshot_repo
        @resolver = resource_resolver
        @task_repo = task_repo
        @options = options
      end

      # Lists snapshots for given VMIDs.
      #
      # @param vmids [Array<Integer>] VM/container IDs
      # @return [Array<Models::Snapshot>] all snapshots
      def list(vmids)
        resources = vmids.empty? ? @resolver.resolve_all : @resolver.resolve_multiple(vmids)
        return [] if resources.empty?

        resources.flat_map do |r|
          @snapshot_repo.list(r[:vmid], r[:node], r[:type])
        end
      end

      # Describes a snapshot by name across given VMIDs.
      #
      # When vmids is empty, searches all resources in the cluster.
      # Returns a SnapshotDescription with entries for each VM/CT that has the snapshot.
      #
      # @param vmids [Array<Integer>] VM/container IDs (empty = search all)
      # @param name [String] snapshot name to find
      # @return [Models::SnapshotDescription] description with entries per VM
      # @raise [ResourceNotFoundError] when snapshot not found
      def describe(vmids, name)
        resources = vmids.empty? ? @resolver.resolve_all : @resolver.resolve_multiple(vmids)

        if resources.empty?
          message = vmids.empty? ? "no resources found in cluster" : "resource #{vmids.first} not found"
          raise ResourceNotFoundError, message
        end

        entries = build_describe_entries(resources, name)

        if entries.empty?
          message = vmids.empty? ? "snapshot '#{name}' not found in cluster" : "snapshot '#{name}' not found on VM #{vmids.join(', ')}"
          raise ResourceNotFoundError, message
        end

        Models::SnapshotDescription.new(entries: entries)
      end

      # Creates snapshots for given VMIDs.
      #
      # @param vmids [Array<Integer>] VM/container IDs
      # @param name [String] snapshot name
      # @param description [String, nil] optional description
      # @param vmstate [Boolean] save VM memory state
      # @return [Array<Models::OperationResult>] results for each resource
      def create(vmids, name:, description: nil, vmstate: false)
        resources = @resolver.resolve_multiple(vmids)
        return [] if resources.empty?

        execute_multi(resources, :create) do |r|
          @snapshot_repo.create(r[:vmid], r[:node], r[:type], name: name, description: description, vmstate: vmstate)
        end
      end

      # Deletes snapshots from given VMIDs.
      #
      # @param vmids [Array<Integer>] VM/container IDs
      # @param snapname [String] snapshot name to delete
      # @param force [Boolean] force removal even if disk snapshot fails
      # @return [Array<Models::OperationResult>] results for each resource
      def delete(vmids, snapname, force: false)
        resources = @resolver.resolve_multiple(vmids)
        return [] if resources.empty?

        execute_multi(resources, :delete) do |r|
          @snapshot_repo.delete(r[:vmid], r[:node], r[:type], snapname, force: force)
        end
      end

      # Rolls back to a snapshot.
      #
      # @param vmid [Integer] VM/container ID
      # @param snapname [String] snapshot name to rollback to
      # @param start [Boolean] start after rollback (LXC only)
      # @return [Models::OperationResult] result
      def rollback(vmid, snapname, start: false)
        resource = @resolver.resolve(vmid)

        if resource.nil?
          return Models::OperationResult.new(
            resource: { vmid: vmid },
            operation: :rollback,
            success: false,
            error: "Resource #{vmid} not found"
          )
        end

        execute_single(resource, :rollback) do
          @snapshot_repo.rollback(resource[:vmid], resource[:node], resource[:type], snapname, start: start)
        end
      end

      private

      def build_describe_entries(resources, name)
        entries = []

        resources.each do |r|
          siblings = @snapshot_repo.list(r[:vmid], r[:node], r[:type])
          target = siblings.find { |s| s.name == name }
          next unless target

          entries << Models::SnapshotDescription::Entry.new(
            snapshot: target,
            siblings: siblings
          )
        end

        entries
      end

      def execute_multi(resources, operation)
        results = []

        resources.each do |r|
          result = execute_single(r, operation) { yield(r) }
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
    end
  end
end
