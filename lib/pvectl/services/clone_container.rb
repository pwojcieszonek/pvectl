# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates container clone operations.
    #
    # Handles validation, auto-generation of CTID/hostname, and sync/async modes.
    # Supports both full clones and linked clones (templates only).
    #
    # @example Full clone with auto-generated CTID
    #   service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
    #   result = service.execute(ctid: 100)
    #
    # @example Linked clone to specific node
    #   service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
    #   result = service.execute(ctid: 100, linked: true, target_node: "pve2")
    #
    # @example Async clone with custom timeout
    #   service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo, options: { async: true })
    #   result = service.execute(ctid: 100, new_ctid: 200, hostname: "web-clone")
    #
    class CloneContainer
      DEFAULT_TIMEOUT = 300

      # Creates a new CloneContainer service.
      #
      # @param container_repository [Repositories::Container] Container repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (timeout, async)
      def initialize(container_repository:, task_repository:, options: {})
        @container_repository = container_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes clone operation.
      #
      # @param ctid [Integer] Source container identifier
      # @param node [String, nil] Source node (auto-detected from container if nil)
      # @param new_ctid [Integer, nil] New CTID (auto-selected if nil)
      # @param hostname [String, nil] Hostname for clone (auto-generated if nil)
      # @param target_node [String, nil] Target node for clone
      # @param storage [String, nil] Target storage
      # @param linked [Boolean] Linked clone (default: false, requires template)
      # @param pool [String, nil] Resource pool
      # @param description [String, nil] Description
      # @return [Models::ContainerOperationResult] Clone result
      def execute(ctid:, node: nil, new_ctid: nil, hostname: nil, target_node: nil,
                  storage: nil, linked: false, pool: nil, description: nil)
        source_ct = @container_repository.get(ctid)
        return container_not_found_error(ctid) unless source_ct

        if linked && !source_ct.template?
          return linked_clone_error(source_ct)
        end

        node ||= source_ct.node
        new_ctid ||= @container_repository.next_available_ctid
        hostname ||= generate_hostname(source_ct)

        clone_options = build_clone_options(
          hostname: hostname, target_node: target_node, storage: storage,
          linked: linked, pool: pool, description: description
        )

        upid = @container_repository.clone(ctid, node, new_ctid, clone_options)
        resource_info = { new_ctid: new_ctid, hostname: hostname, node: target_node || node }

        if @options[:async]
          Models::ContainerOperationResult.new(
            container: source_ct, operation: :clone,
            task_upid: upid, success: :pending,
            resource: resource_info
          )
        else
          task = @task_repository.wait(upid, timeout: timeout)
          Models::ContainerOperationResult.new(
            container: source_ct, operation: :clone,
            task: task, success: task.successful?,
            resource: resource_info
          )
        end
      rescue StandardError => e
        Models::ContainerOperationResult.new(
          container: source_ct, operation: :clone,
          success: false, error: e.message
        )
      end

      private

      # Generates clone hostname from source container.
      #
      # @param source_ct [Models::Container] Source container
      # @return [String] Generated hostname
      def generate_hostname(source_ct)
        if source_ct.name && !source_ct.name.empty?
          "#{source_ct.name}-clone"
        else
          "ct-#{source_ct.vmid}-clone"
        end
      end

      # Builds clone options hash for repository call.
      #
      # @param hostname [String] Clone hostname
      # @param target_node [String, nil] Target node
      # @param storage [String, nil] Target storage
      # @param linked [Boolean] Linked clone flag
      # @param pool [String, nil] Resource pool
      # @param description [String, nil] Description
      # @return [Hash] Clone options
      def build_clone_options(hostname:, target_node:, storage:, linked:, pool:, description:)
        opts = { hostname: hostname, full: !linked }
        opts[:target] = target_node if target_node
        opts[:storage] = storage if storage
        opts[:pool] = pool if pool
        opts[:description] = description if description
        opts
      end

      # Returns configured timeout.
      #
      # @return [Integer] Timeout in seconds
      def timeout
        @options[:timeout] || DEFAULT_TIMEOUT
      end

      # Returns error for container not found.
      #
      # @param ctid [Integer] Container identifier
      # @return [Models::ContainerOperationResult] Failed result
      def container_not_found_error(ctid)
        Models::ContainerOperationResult.new(
          operation: :clone,
          success: false,
          error: "Container #{ctid} not found"
        )
      end

      # Returns error for linked clone of non-template container.
      #
      # @param source_ct [Models::Container] Source container
      # @return [Models::ContainerOperationResult] Failed result
      def linked_clone_error(source_ct)
        Models::ContainerOperationResult.new(
          container: source_ct, operation: :clone,
          success: false,
          error: "Linked clone requires container to be a template. Container #{source_ct.vmid} is not a template"
        )
      end
    end
  end
end
