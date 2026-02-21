# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates LXC container creation operations.
    #
    # Handles auto-CTID allocation, parameter building (mapping rootfs/mountpoints/net
    # configs to Proxmox API format), sync/async modes, and optional auto-start.
    #
    # @example Basic container creation
    #   service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
    #   result = service.execute(hostname: "web-ct", node: "pve1",
    #                            ostemplate: "local:vztmpl/debian-12.tar.zst",
    #                            cores: 2, memory: 2048)
    #
    # @example Async creation with auto-start
    #   service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo,
    #                                 options: { async: true, start: true })
    #   result = service.execute(ctid: 200, hostname: "db-ct", node: "pve1",
    #                            ostemplate: "local:vztmpl/debian-12.tar.zst")
    #
    class CreateContainer
      # @return [Integer] Default timeout for create operations (seconds)
      DEFAULT_TIMEOUT = 300

      # @return [Integer] Default timeout for start operations (seconds)
      START_TIMEOUT = 60

      # Creates a new CreateContainer service.
      #
      # @param container_repository [Repositories::Container] Container repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (timeout, async, start)
      def initialize(container_repository:, task_repository:, options: {})
        @container_repository = container_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes container creation operation.
      #
      # @param ctid [Integer, nil] Container identifier (auto-allocated if nil)
      # @param hostname [String] Container hostname
      # @param node [String] Target node
      # @param ostemplate [String] OS template path
      # @param cores [Integer, nil] Number of CPU cores
      # @param memory [Integer, nil] Memory in MB
      # @param swap [Integer, nil] Swap in MB
      # @param rootfs [Hash, nil] Root filesystem config
      # @param mountpoints [Array<Hash>, nil] Mountpoint configurations
      # @param nets [Array<Hash>, nil] Network configurations
      # @param privileged [Boolean, nil] Create privileged container
      # @param features [String, nil] LXC features string
      # @param password [String, nil] Root password
      # @param ssh_public_keys [String, nil] SSH public keys
      # @param onboot [Boolean, nil] Start on boot
      # @param startup [String, nil] Startup order spec
      # @param description [String, nil] Container description
      # @param tags [String, nil] Tags (comma-separated)
      # @param pool [String, nil] Resource pool
      # @return [Models::ContainerOperationResult] Creation result
      def execute(ctid: nil, hostname:, node:, ostemplate:, cores: nil, memory: nil,
                  swap: nil, rootfs: nil, mountpoints: nil, nets: nil, privileged: nil,
                  features: nil, password: nil, ssh_public_keys: nil, onboot: nil,
                  startup: nil, description: nil, tags: nil, pool: nil)
        ctid ||= @container_repository.next_available_ctid

        params = build_params(
          hostname: hostname, ostemplate: ostemplate, cores: cores, memory: memory,
          swap: swap, rootfs: rootfs, mountpoints: mountpoints, nets: nets,
          privileged: privileged, features: features, password: password,
          ssh_public_keys: ssh_public_keys, onboot: onboot, startup: startup,
          description: description, tags: tags, pool: pool
        )

        upid = @container_repository.create(node, ctid, params)
        resource_info = { ctid: ctid, hostname: hostname, node: node }

        if @options[:async]
          build_result(resource_info, task_upid: upid, success: :pending)
        else
          task = @task_repository.wait(upid, timeout: timeout)
          start_container(ctid, node) if task.successful? && @options[:start]
          build_result(resource_info, task: task, success: task.successful?)
        end
      rescue StandardError => e
        build_result({ ctid: ctid, hostname: hostname, node: node },
                     success: false, error: e.message)
      end

      private

      # Builds Proxmox API parameters from user-friendly options.
      #
      # Maps rootfs/mountpoint configs through {Parsers::LxcMountConfig.to_proxmox} and
      # network configs through {Parsers::LxcNetConfig.to_proxmox}.
      #
      # @return [Hash] Proxmox API parameters
      def build_params(hostname:, ostemplate:, cores:, memory:, swap:, rootfs:,
                       mountpoints:, nets:, privileged:, features:, password:,
                       ssh_public_keys:, onboot:, startup:, description:, tags:, pool:)
        params = { hostname: hostname, ostemplate: ostemplate }
        params[:cores] = cores if cores
        params[:memory] = memory if memory
        params[:swap] = swap if swap
        params[:unprivileged] = privileged ? 0 : 1 unless privileged.nil?
        params[:rootfs] = Parsers::LxcMountConfig.to_proxmox(rootfs) if rootfs
        add_mountpoint_params(params, mountpoints) if mountpoints
        add_net_params(params, nets) if nets
        params[:features] = features if features
        params[:password] = password if password
        params[:"ssh-public-keys"] = ssh_public_keys if ssh_public_keys
        params[:onboot] = onboot ? 1 : 0 unless onboot.nil?
        params[:startup] = startup if startup
        params[:description] = description if description
        params[:tags] = tags if tags
        params[:pool] = pool if pool
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

      # Starts a container after successful creation.
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

      # Builds a ContainerOperationResult with the :create operation.
      #
      # Creates a minimal Container model for presenter compatibility.
      #
      # @param resource_info [Hash] Resource info (ctid, hostname, node)
      # @param attrs [Hash] Additional result attributes
      # @return [Models::ContainerOperationResult] Operation result
      def build_result(resource_info, **attrs)
        container = Models::Container.new(
          vmid: resource_info[:ctid],
          name: resource_info[:hostname],
          node: resource_info[:node]
        )
        Models::ContainerOperationResult.new(
          operation: :create, container: container, resource: resource_info, **attrs
        )
      end
    end
  end
end
