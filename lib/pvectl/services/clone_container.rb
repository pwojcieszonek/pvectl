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

      # @return [Integer] Default timeout for start operations (seconds)
      START_TIMEOUT = 60

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
      # Performs a two-step flow: clone the container first, then optionally apply
      # config updates via PUT /nodes/{node}/lxc/{ctid}/config.
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
      # @param config_params [Hash] Container config parameters to apply after clone
      # @return [Models::ContainerOperationResult] Clone result
      def execute(ctid:, node: nil, new_ctid: nil, hostname: nil, target_node: nil,
                  storage: nil, linked: false, pool: nil, description: nil,
                  config_params: {})
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

          unless task.successful?
            return Models::ContainerOperationResult.new(
              container: source_ct, operation: :clone,
              task: task, success: task.successful?,
              resource: resource_info
            )
          end

          if config_params.any?
            apply_config_update(source_ct, new_ctid, resource_info[:node], config_params, resource_info)
          else
            start_container(new_ctid, resource_info[:node]) if @options[:start]
            Models::ContainerOperationResult.new(
              container: source_ct, operation: :clone,
              task: task, success: true,
              resource: resource_info
            )
          end
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

      # Applies config update to the cloned container.
      #
      # Converts user-friendly params to Proxmox API format and calls
      # the repository update method. Returns partial result on failure.
      #
      # @param source_ct [Models::Container] Source container
      # @param new_ctid [Integer] Cloned container identifier
      # @param node [String] Target node for the cloned container
      # @param config_params [Hash] Config parameters to apply
      # @param resource_info [Hash] Resource info for result
      # @return [Models::ContainerOperationResult] Operation result
      def apply_config_update(source_ct, new_ctid, node, config_params, resource_info)
        api_params = build_ct_config_api_params(config_params)
        @container_repository.update(new_ctid, node, api_params)
        start_container(new_ctid, node) if @options[:start]
        Models::ContainerOperationResult.new(
          container: source_ct, operation: :clone,
          success: true, resource: resource_info
        )
      rescue StandardError => e
        Models::ContainerOperationResult.new(
          container: source_ct, operation: :clone,
          success: :partial, resource: resource_info,
          error: "Cloned successfully, but config update failed: #{e.message}"
        )
      end

      # Builds Proxmox API parameters from user-friendly container config options.
      #
      # Maps config keys to their Proxmox API equivalents. Does not include
      # hostname, ostemplate, description, or pool (those belong to the clone step).
      #
      # @param config_params [Hash] User-friendly config parameters
      # @return [Hash] Proxmox API parameters
      def build_ct_config_api_params(config_params)
        params = {}
        params[:cores] = config_params[:cores] if config_params[:cores]
        params[:memory] = config_params[:memory] if config_params[:memory]
        params[:swap] = config_params[:swap] if config_params[:swap]
        params[:unprivileged] = config_params[:privileged] ? 0 : 1 unless config_params[:privileged].nil?
        params[:rootfs] = Parsers::LxcMountConfig.to_proxmox(config_params[:rootfs]) if config_params[:rootfs]
        add_mountpoint_params(params, config_params[:mountpoints]) if config_params[:mountpoints]
        add_net_params(params, config_params[:nets]) if config_params[:nets]
        params[:features] = config_params[:features] if config_params[:features]
        params[:password] = config_params[:password] if config_params[:password]
        params[:"ssh-public-keys"] = config_params[:ssh_public_keys] if config_params[:ssh_public_keys]
        params[:onboot] = 1 if config_params[:onboot]
        params[:startup] = config_params[:startup] if config_params[:startup]
        params[:tags] = config_params[:tags] if config_params[:tags]
        params
      end

      # Adds mountpoint parameters mapped to mp0, mp1, etc.
      #
      # @param params [Hash] Parameters hash to modify
      # @param mountpoints [Array<Hash>] Mountpoint configurations
      # @return [void]
      def add_mountpoint_params(params, mountpoints)
        mountpoints.each_with_index do |mp, index|
          params[:"mp#{index}"] = Parsers::LxcMountConfig.to_proxmox(mp)
        end
      end

      # Adds network parameters mapped to net0, net1, etc.
      #
      # @param params [Hash] Parameters hash to modify
      # @param nets [Array<Hash>] Network configurations
      # @return [void]
      def add_net_params(params, nets)
        nets.each_with_index do |net, index|
          params[:"net#{index}"] = Parsers::LxcNetConfig.to_proxmox(net)
        end
      end

      # Starts a container after successful clone and config update.
      #
      # @param ctid [Integer] Container identifier
      # @param node [String] Node name
      # @return [void]
      def start_container(ctid, node)
        upid = @container_repository.start(ctid, node)
        @task_repository.wait(upid, timeout: START_TIMEOUT)
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
