# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for virtual disk volumes attached to VMs and containers.
    #
    # Aggregates volume data from two sources:
    # - VM/CT config endpoints (parsed disk keys from configuration)
    # - Storage content API (+/nodes/{node}/storage/{storage}/content+)
    #
    # Uses composition: delegates to VmRepository and ContainerRepository
    # for config fetching and node resolution.
    #
    # @example Listing volumes from VM config
    #   repo = Volume.new(connection)
    #   volumes = repo.list_from_config(resource_type: "vm", ids: [100, 101])
    #   volumes.each { |v| puts "#{v.name}: #{v.storage}:#{v.volume_id} (#{v.size})" }
    #
    # @example Finding a specific disk
    #   volume = repo.find(resource_type: "vm", id: 100, disk_name: "scsi0")
    #   puts volume.size if volume
    #
    # @see Pvectl::Models::Volume Volume model
    # @see Pvectl::Repositories::Vm VM repository
    # @see Pvectl::Repositories::Container Container repository
    #
    class Volume < Base
      # Pattern matching VM disk keys (scsi0, virtio1, ide2, sata3, efidisk0, tpmstate0)
      VM_DISK_PATTERN = /\A(?:scsi|virtio|ide|sata|efidisk|tpmstate)\d+\z/

      # Pattern matching container disk keys (rootfs, mp0, mp1, ...)
      CT_DISK_PATTERN = /\A(?:rootfs|mp\d+)\z/

      # Creates a new Volume repository.
      #
      # @param connection [Connection] API connection
      # @param vm_repo [Repositories::Vm, nil] optional VM repository for DI
      # @param container_repo [Repositories::Container, nil] optional container repository for DI
      def initialize(connection, vm_repo: nil, container_repo: nil)
        super(connection)
        @vm_repo = vm_repo
        @container_repo = container_repo
      end

      # Lists volumes from VM/CT configuration for given resource IDs.
      #
      # Fetches config from each VM/CT and extracts disk entries.
      # Excludes CD-ROM entries (containing +media=cdrom+).
      #
      # @param resource_type [String] "vm" or "ct"
      # @param ids [Array<Integer, String>] list of VMID/CTID values
      # @param node [String, nil] filter results by node name
      # @return [Array<Models::Volume>] collection of Volume models
      def list_from_config(resource_type:, ids:, node: nil)
        type = normalize_resource_type(resource_type)
        repo = repo_for(type)
        return [] unless repo

        volumes = ids.flat_map do |id|
          resource = repo.get(id)
          next [] if resource.nil?
          next [] if node && resource.node != node

          config = repo.fetch_config(resource.node, id.to_i)
          extract_volumes(config, type, id.to_i, resource.node)
        end

        volumes
      end

      # Lists volumes from storage content API.
      #
      # Queries +/nodes/{node}/storage/{storage}/content+ to list
      # all volumes in the given storage.
      #
      # @param storage [String] storage name (e.g., "local-lvm")
      # @param node [String, nil] node name (queries all online nodes if nil)
      # @return [Array<Models::Volume>] collection of Volume models
      def list_from_storage(storage:, node: nil)
        nodes = node ? [node] : online_nodes
        nodes.flat_map { |node_name| fetch_storage_volumes(node_name, storage) }
      end

      # Finds a specific volume by disk name in a VM/CT config.
      #
      # @param resource_type [String] "vm" or "ct"
      # @param id [Integer, String] VMID or CTID
      # @param disk_name [String] disk key name (e.g., "scsi0", "rootfs")
      # @param node [String, nil] optional node override
      # @return [Models::Volume, nil] Volume model or nil if not found
      def find(resource_type:, id:, disk_name:, node: nil)
        volumes = list_from_config(resource_type: resource_type, ids: [id], node: node)
        volumes.find { |v| v.name == disk_name }
      end

      private

      # Returns the appropriate repository for the given resource type.
      #
      # @param type [String] normalized resource type ("vm" or "ct")
      # @return [Repositories::Vm, Repositories::Container, nil] repository instance
      def repo_for(type)
        case type
        when "vm" then vm_repo
        when "ct" then container_repo
        end
      end

      # Returns VM repository instance.
      # Uses injected repository if provided, otherwise creates new one.
      #
      # @return [Repositories::Vm] VM repository
      def vm_repo
        @vm_repo ||= Repositories::Vm.new(connection)
      end

      # Returns container repository instance.
      # Uses injected repository if provided, otherwise creates new one.
      #
      # @return [Repositories::Container] container repository
      def container_repo
        @container_repo ||= Repositories::Container.new(connection)
      end

      # Normalizes resource type string to canonical form.
      #
      # @param type [String] resource type (e.g., "vm", "VM", "ct", "container")
      # @return [String] normalized type ("vm" or "ct")
      def normalize_resource_type(type)
        case type.to_s.downcase
        when "vm", "qemu" then "vm"
        when "ct", "container", "lxc" then "ct"
        else type.to_s.downcase
        end
      end

      # Extracts volume models from a config hash.
      #
      # Iterates over config keys, selects disk-related entries,
      # excludes CD-ROMs, and builds Volume models.
      #
      # @param config [Hash{Symbol => untyped}] VM/CT config hash
      # @param resource_type [String] "vm" or "ct"
      # @param resource_id [Integer] VMID or CTID
      # @param node [String] node name
      # @return [Array<Models::Volume>] extracted volumes
      def extract_volumes(config, resource_type, resource_id, node)
        pattern = resource_type == "vm" ? VM_DISK_PATTERN : CT_DISK_PATTERN

        config.each_with_object([]) do |(key, value), volumes|
          key_str = key.to_s
          next unless key_str.match?(pattern)

          value_str = value.to_s
          next if value_str.include?("media=cdrom")

          volumes << parse_config_value(key_str, value_str, resource_type, resource_id, node)
        end
      end

      # Parses a config value string into a Volume model.
      #
      # Config values have the format:
      #   "storage:volume-id,key1=val1,key2=val2"
      #
      # @param name [String] disk key name (e.g., "scsi0")
      # @param value [String] config value string
      # @param resource_type [String] "vm" or "ct"
      # @param resource_id [Integer] VMID or CTID
      # @param node [String] node name
      # @return [Models::Volume] parsed Volume model
      def parse_config_value(name, value, resource_type, resource_id, node)
        # Split "storage:volume-id,key=val,..." into storage_part and options
        parts = value.split(",")
        storage_spec = parts.shift || ""

        storage, volume_id = storage_spec.split(":", 2)

        # Parse key=value options
        attrs = { name: name, storage: storage, volume_id: volume_id,
                  resource_type: resource_type, resource_id: resource_id, node: node }

        parts.each do |part|
          k, v = part.split("=", 2)
          next unless k && v

          case k
          when "size"     then attrs[:size] = v
          when "format"   then attrs[:format] = v
          when "cache"    then attrs[:cache] = v
          when "discard"  then attrs[:discard] = v
          when "ssd"      then attrs[:ssd] = parse_int(v)
          when "iothread" then attrs[:iothread] = parse_int(v)
          when "backup"   then attrs[:backup] = parse_int(v)
          when "mp"       then attrs[:mp] = v
          end
        end

        Models::Volume.new(attrs)
      end

      # Fetches volumes from a storage on a specific node.
      #
      # @param node_name [String] node name
      # @param storage [String] storage name
      # @return [Array<Models::Volume>] volumes from storage
      def fetch_storage_volumes(node_name, storage)
        response = connection.client["nodes/#{node_name}/storage/#{storage}/content"].get
        data = unwrap(response)
        data.map { |item| build_storage_volume(item, node_name, storage) }
      rescue StandardError
        []
      end

      # Builds a Volume model from storage content API data.
      #
      # @param data [Hash{Symbol => untyped}] API response item
      # @param node [String] node name
      # @param storage [String] storage name
      # @return [Models::Volume] Volume model
      def build_storage_volume(data, node, storage)
        resource_type, resource_id = extract_resource_from_volume_id(data[:volid], data[:content])

        Models::Volume.new(
          volid: data[:volid],
          volume_id: data[:volid]&.split(":")&.last,
          storage: storage,
          size: format_bytes_to_size(data[:size]),
          format: data[:format],
          content: data[:content],
          resource_type: resource_type,
          resource_id: resource_id,
          node: node
        )
      end

      # Extracts resource type and ID from a volume identifier.
      #
      # Volume IDs follow patterns like:
      # - "vm-100-disk-0" => ["vm", 100]
      # - "subvol-200-disk-0" => ["ct", 200]
      # - "base-100-disk-0" => ["vm", 100]
      #
      # @param volume_id [String, nil] full volid (e.g., "local-lvm:vm-100-disk-0")
      # @param content [String, nil] content type from API
      # @return [Array(String?, Integer?)] [resource_type, resource_id]
      def extract_resource_from_volume_id(volume_id, content)
        return [nil, nil] unless volume_id

        vol_part = volume_id.split(":").last
        return [nil, nil] unless vol_part

        case vol_part
        when /\Avm-(\d+)-/
          ["vm", ::Regexp.last_match(1).to_i]
        when /\Asubvol-(\d+)-/
          ["ct", ::Regexp.last_match(1).to_i]
        when /\Abase-(\d+)-/
          type = content == "rootdir" ? "ct" : "vm"
          [type, ::Regexp.last_match(1).to_i]
        else
          [nil, nil]
        end
      end

      # Formats bytes to human-readable size string.
      #
      # @param bytes [Integer, nil] size in bytes
      # @return [String, nil] formatted size (e.g., "32G") or nil
      def format_bytes_to_size(bytes)
        return nil unless bytes.is_a?(Integer) && bytes.positive?

        gb = bytes / (1024 * 1024 * 1024)
        return "#{gb}G" if gb.positive?

        mb = bytes / (1024 * 1024)
        return "#{mb}M" if mb.positive?

        "#{bytes}B"
      end

      # Fetches list of online node names.
      #
      # @return [Array<String>] online node names
      def online_nodes
        response = connection.client["nodes"].get
        nodes_data = unwrap(response)
        nodes_data
          .select { |n| n[:status] == "online" }
          .map { |n| n[:node] || n[:name] }
      rescue StandardError
        []
      end

      # Parses a string value to integer.
      #
      # @param value [String, nil] string value
      # @return [Integer, nil] parsed integer or nil
      def parse_int(value)
        return nil unless value

        value.to_i
      end
    end
  end
end
