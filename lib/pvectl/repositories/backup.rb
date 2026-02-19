# frozen_string_literal: true

require "erb"

module Pvectl
  module Repositories
    # Repository for backup operations in Proxmox.
    #
    # Handles listing, creating, deleting, and restoring backups
    # via the Proxmox API (vzdump).
    #
    # @example Listing backups
    #   repo = Backup.new(connection)
    #   backups = repo.list(node: "pve1", storage: "local")
    #
    # @example Creating a backup
    #   upid = repo.create(100, "pve1", storage: "local", mode: "snapshot")
    #
    # @example Restoring a backup
    #   upid = repo.restore("local:backup/vzdump-qemu-100.vma.zst", "pve1", vmid: 200)
    #
    # @see Pvectl::Models::Backup Backup model
    # @see Pvectl::Connection API connection
    #
    class Backup < Base
      # Lists backups from storage.
      #
      # When node and storage are not specified, discovers all nodes and
      # backup-capable storages automatically.
      #
      # @param vmid [Integer, nil] filter by VM ID
      # @param storage [String, nil] storage name (default: all backup storages)
      # @param node [String, nil] node name (default: all nodes)
      # @return [Array<Models::Backup>] backup models
      def list(vmid: nil, storage: nil, node: nil)
        nodes = node ? [node] : list_nodes
        storages_by_node = storage ? Hash[nodes.map { |n| [n, [storage]] }] : nil

        backups = []
        nodes.each do |n|
          backup_storages = storages_by_node ? storages_by_node[n] : list_backup_storages(n)
          backup_storages.each do |s|
            backups.concat(list_from_storage(n, s, vmid: vmid))
          end
        end
        backups
      end

      # Creates a backup using vzdump.
      #
      # @param vmid [Integer] VM/container ID
      # @param node [String] node name
      # @param storage [String] target storage
      # @param mode [String] backup mode (snapshot, suspend, stop)
      # @param compress [String] compression (zstd, gzip, lzo, 0)
      # @param notes [String, nil] backup notes
      # @param protected [Boolean] protect from deletion
      # @return [String] task UPID
      def create(vmid, node, storage:, mode: "snapshot", compress: "zstd", notes: nil, protected: false)
        params = {
          vmid: vmid,
          storage: storage,
          mode: mode,
          compress: compress
        }
        params[:notes] = notes if notes
        params[:protected] = 1 if protected

        connection.client["nodes/#{node}/vzdump"].post(params)
      end

      # Deletes a backup.
      #
      # @param volid [String] full volume ID
      # @param node [String] node name
      # @return [String, nil] task UPID or nil
      def delete(volid, node)
        storage = parse_storage(volid)
        encoded_volid = ERB::Util.url_encode(volid)
        connection.client["nodes/#{node}/storage/#{storage}/content/#{encoded_volid}"].delete
      end

      # Restores a backup to a new or existing VM/container.
      #
      # @param volid [String] backup volume ID
      # @param node [String] node name
      # @param vmid [Integer] target VM ID
      # @param storage [String, nil] target storage
      # @param force [Boolean] overwrite existing VM
      # @param start [Boolean] start after restore
      # @param unique [Boolean] regenerate unique properties
      # @return [String] task UPID
      def restore(volid, node, vmid:, storage: nil, force: false, start: false, unique: false)
        resource_type = detect_type_from_volid(volid)
        endpoint = resource_type == :lxc ? "lxc" : "qemu"

        params = {
          archive: volid,
          vmid: vmid
        }
        params[:storage] = storage if storage
        params[:force] = 1 if force
        params[:start] = 1 if start
        params[:unique] = 1 if unique

        connection.client["nodes/#{node}/#{endpoint}"].post(params)
      end

      private

      # Lists all nodes in the cluster.
      #
      # @return [Array<String>] node names
      def list_nodes
        response = connection.client["nodes"].get
        response.map { |n| n[:node] || n["node"] }
      end

      # Lists storages that support backup content on a node.
      #
      # @param node [String] node name
      # @return [Array<String>] storage names with backup capability
      def list_backup_storages(node)
        response = connection.client["nodes/#{node}/storage"].get
        response.select do |s|
          content = s[:content] || s["content"] || ""
          content.include?("backup")
        end.map { |s| s[:storage] || s["storage"] }
      end

      # Lists backups from a specific storage on a node.
      #
      # @param node [String] node name
      # @param storage [String] storage name
      # @param vmid [Integer, nil] optional VM ID filter
      # @return [Array<Models::Backup>] backup models
      def list_from_storage(node, storage, vmid: nil)
        response = connection.client["nodes/#{node}/storage/#{storage}/content"].get(params: { content: "backup" })

        backups = response.map do |data|
          build_backup_model(data, node, storage)
        end

        vmid ? backups.select { |b| b.vmid == vmid } : backups
      end

      # Builds a Backup model from API response data.
      #
      # @param data [Hash] API response hash
      # @param node [String] node name
      # @param storage [String] storage name
      # @return [Models::Backup] backup model instance
      def build_backup_model(data, node, storage)
        Models::Backup.new(
          volid: data[:volid] || data["volid"],
          vmid: data[:vmid] || data["vmid"],
          node: node,
          storage: storage,
          size: data[:size] || data["size"],
          ctime: data[:ctime] || data["ctime"],
          format: data[:format] || data["format"],
          notes: data[:notes] || data["notes"],
          protected: (data[:protected] || data["protected"]) == 1
        )
      end

      # Extracts storage name from volid.
      #
      # @param volid [String] full volume identifier
      # @return [String] storage name
      def parse_storage(volid)
        volid.split(":").first
      end

      # Detects resource type from volid pattern.
      #
      # @param volid [String] backup volume identifier
      # @return [Symbol] :qemu or :lxc
      def detect_type_from_volid(volid)
        return :lxc if volid.include?("vzdump-lxc")

        :qemu
      end
    end
  end
end
