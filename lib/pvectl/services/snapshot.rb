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
      # When vmids is empty, lists snapshots for all resources in the cluster.
      #
      # @param vmids [Array<Integer>] VM/container IDs (empty = all)
      # @param node [String, nil] filter by node name
      # @return [Array<Models::Snapshot>] all snapshots
      def list(vmids, node: nil)
        resources = resolve_resources(vmids)
        resources = filter_by_node(resources, node)
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
      # @param node [String, nil] filter by node name
      # @return [Models::SnapshotDescription] description with entries per VM
      # @raise [ResourceNotFoundError] when snapshot not found
      def describe(vmids, name, node: nil)
        resources = resolve_resources(vmids)
        resources = filter_by_node(resources, node)

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

      # Creates snapshots for given VMIDs, or all cluster resources when vmids is empty.
      #
      # When vmids is empty, creates snapshots for all resources in the cluster.
      #
      # @param vmids [Array<Integer>] VM/container IDs (empty = all)
      # @param name [String] snapshot name
      # @param description [String, nil] optional description
      # @param vmstate [Boolean] save VM memory state
      # @param node [String, nil] filter by node name
      # @return [Array<Models::OperationResult>] results for each resource
      def create(vmids, name:, description: nil, vmstate: false, node: nil)
        resources = resolve_resources(vmids)
        resources = filter_by_node(resources, node)
        return [] if resources.empty?

        execute_multi(resources, :create) do |r|
          @snapshot_repo.create(r[:vmid], r[:node], r[:type], name: name, description: description, vmstate: vmstate)
        end
      end

      # Deletes snapshots from given VMIDs, or all cluster resources when vmids is empty.
      #
      # When vmids is empty, deletes snapshots from all resources in the cluster.
      #
      # @param vmids [Array<Integer>] VM/container IDs (empty = all)
      # @param snapname [String] snapshot name to delete
      # @param force [Boolean] force removal even if disk snapshot fails
      # @param node [String, nil] filter by node name
      # @return [Array<Models::OperationResult>] results for each resource
      def delete(vmids, snapname, force: false, node: nil)
        resources = resolve_resources(vmids)
        resources = filter_by_node(resources, node)
        return [] if resources.empty?

        execute_multi(resources, :delete) do |r|
          @snapshot_repo.delete(r[:vmid], r[:node], r[:type], snapname, force: force)
        end
      end

      # Deletes ALL snapshots from given VMIDs.
      #
      # When vmids is empty, deletes all snapshots from all resources in the cluster.
      # Skips the "current" pseudo-snapshot.
      #
      # @param vmids [Array<Integer>] VM/container IDs (empty = all)
      # @param node [String, nil] filter by node name
      # @param force [Boolean] force removal even if disk snapshot fails
      # @return [Array<Models::OperationResult>] results for each snapshot
      def delete_all(vmids, node: nil, force: false)
        resources = resolve_resources(vmids)
        resources = filter_by_node(resources, node)
        return [] if resources.empty?

        results = []

        resources.each do |r|
          snapshots = @snapshot_repo.list(r[:vmid], r[:node], r[:type])
          snapshots.reject! { |s| s.name == "current" }

          snapshots.each do |snap|
            result = execute_single(r, :delete) do
              @snapshot_repo.delete(r[:vmid], r[:node], r[:type], snap.name, force: force)
            end
            results << result

            break if @options[:fail_fast] && result.failed?
          end

          break if @options[:fail_fast] && results.last&.failed?
        end

        results
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

      # Resolves resources from VMIDs or returns all cluster resources.
      #
      # @param vmids [Array<Integer>] VM/container IDs (empty = resolve all)
      # @return [Array<Hash>] resolved resources
      def resolve_resources(vmids)
        vmids.empty? ? @resolver.resolve_all : @resolver.resolve_multiple(vmids)
      end

      # Filters resources by node name.
      #
      # @param resources [Array<Hash>] resolved resources
      # @param node [String, nil] node name to filter by (nil = no filter)
      # @return [Array<Hash>] filtered resources
      def filter_by_node(resources, node)
        return resources unless node

        resources.select { |r| r[:node] == node }
      end

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
