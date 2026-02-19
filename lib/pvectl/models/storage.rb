# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a storage pool in the Proxmox cluster.
    #
    # Immutable domain model containing storage attributes and predicate methods.
    # Created by Repositories::Storage from API data.
    # Display formatting is handled by Presenters::Storage.
    #
    # @example Creating a Storage model
    #   storage = Storage.new(name: "local", plugintype: "dir", status: "available")
    #   storage.active? #=> true
    #   storage.shared? #=> false
    #
    # @example From API response
    #   data = { "storage" => "local", "plugintype" => "dir", "status" => "available" }
    #   storage = Storage.new(data)
    #
    # @see Pvectl::Repositories::Storage Repository that creates Storage instances
    # @see Pvectl::Presenters::Storage Presenter for formatting Storage data
    #
    class Storage < Base
      # @return [String] storage pool name
      attr_reader :name

      # @return [String] storage plugin type (dir, lvmthin, rbd, nfs, zfspool, etc.)
      attr_reader :plugintype

      # @return [String] storage status (available, unavailable)
      attr_reader :status

      # @return [String, nil] node name (nil for shared storage)
      attr_reader :node

      # @return [Integer, nil] disk used in bytes
      attr_reader :disk

      # @return [Integer, nil] total disk in bytes
      attr_reader :maxdisk

      # @return [String, nil] comma-separated content types (images, iso, vztmpl, backup, rootdir)
      attr_reader :content

      # @return [Integer] shared flag (1 = shared, 0 = local)
      attr_reader :shared

      # @return [Integer, nil] available bytes (from /nodes/{node}/storage)
      attr_reader :avail

      # @return [Integer, nil] enabled flag (0/1) (from /nodes/{node}/storage)
      attr_reader :enabled

      # @return [Integer, nil] active flag (0/1) (from /nodes/{node}/storage)
      attr_reader :active_flag

      # Configuration fields (from /storage/{storage} API endpoint)
      # @return [String, nil] path for dir, nfs storage types
      attr_reader :path

      # @return [String, nil] server for nfs, iscsi, ceph
      attr_reader :server

      # @return [String, nil] export path (nfs)
      attr_reader :export

      # @return [String, nil] pool name (zfs, ceph)
      attr_reader :pool

      # @return [String, nil] volume group (lvm)
      attr_reader :vgname

      # @return [String, nil] thin pool name (lvmthin)
      attr_reader :thinpool

      # @return [String, nil] allowed nodes (nil = all)
      attr_reader :nodes_allowed

      # @return [Hash, nil] retention policy hash
      attr_reader :prune_backups

      # @return [Integer, nil] max backups (deprecated)
      attr_reader :max_files

      # Content summary
      # @return [Array<Hash>] volumes from /content endpoint
      attr_reader :volumes

      # Creates a new Storage model from attributes.
      #
      # Handles field aliasing between different API endpoints:
      # - /cluster/resources uses: disk, maxdisk
      # - /nodes/{node}/storage uses: used, total, avail
      #
      # @param attrs [Hash] Storage attributes from API (string or symbol keys)
      def initialize(attrs = {})
        super(attrs)
        @name = @attributes[:name] || @attributes[:storage]
        @plugintype = @attributes[:plugintype] || @attributes[:type]
        @node = @attributes[:node]
        @content = @attributes[:content]
        @shared = @attributes[:shared] || 0

        # Handle field aliasing between endpoints
        # /cluster/resources uses: disk, maxdisk
        # /nodes/{node}/storage uses: used, total, avail
        @disk = @attributes[:disk] || @attributes[:used]
        @maxdisk = @attributes[:maxdisk] || @attributes[:total]
        @avail = @attributes[:avail]
        @enabled = @attributes[:enabled]
        @active_flag = @attributes[:active]

        # Status normalization: /nodes/{node}/storage has no status field
        # Derive from active flag if status not present
        @status = @attributes[:status] || derive_status_from_active

        # Configuration fields from /storage/{storage} API endpoint
        @path = @attributes[:path]
        @server = @attributes[:server]
        @export = @attributes[:export]
        @pool = @attributes[:pool]
        @vgname = @attributes[:vgname]
        @thinpool = @attributes[:thinpool]
        @nodes_allowed = @attributes[:nodes]  # API returns "nodes" not "nodes_allowed"
        @prune_backups = @attributes[:"prune-backups"]  # API uses hyphen
        @max_files = @attributes[:maxfiles]
        @volumes = @attributes[:volumes] || []
      end

      # Checks if the storage is active/available.
      #
      # @return [Boolean] true if status is "available" or "active"
      def active?
        status == "available" || status == "active"
      end

      # Returns used bytes (alias for disk).
      # Provides semantic clarity when working with /nodes/{node}/storage API.
      #
      # @return [Integer, nil] bytes used
      def used
        disk
      end

      # Returns total bytes (alias for maxdisk).
      # Provides semantic clarity when working with /nodes/{node}/storage API.
      #
      # @return [Integer, nil] total bytes
      def total
        maxdisk
      end

      # Checks if the storage is enabled.
      #
      # @return [Boolean] true if enabled flag is 1
      def enabled?
        enabled == 1
      end

      # Checks if the storage is shared across nodes.
      #
      # @return [Boolean] true if shared flag is 1
      def shared?
        shared == 1
      end

      private

      # Derives status from active flag when status not present.
      # Used for /nodes/{node}/storage API which doesn't return status field.
      #
      # @return [String, nil] derived status or nil if active_flag not set
      def derive_status_from_active
        return nil if @active_flag.nil?

        @active_flag == 1 ? "available" : "unavailable"
      end
    end
  end
end
