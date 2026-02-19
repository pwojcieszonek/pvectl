# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a VM/container snapshot in Proxmox.
    #
    # A snapshot captures the state of a VM or container at a specific point in time,
    # including optionally the VM memory state (vmstate).
    #
    # @example Creating a snapshot model
    #   snapshot = Snapshot.new(
    #     name: "before-upgrade",
    #     snaptime: 1706800000,
    #     description: "Snapshot before upgrade",
    #     vmstate: 1
    #   )
    #   snapshot.has_vmstate?  # => true
    #   snapshot.created_at    # => 2024-02-01 12:26:40 +0000
    #
    # @see Pvectl::Models::Base Base model class
    #
    class Snapshot < Base
      # @return [String] snapshot name/identifier
      attr_reader :name

      # @return [Integer, nil] Unix timestamp when snapshot was created
      attr_reader :snaptime

      # @return [String, nil] optional description of the snapshot
      attr_reader :description

      # @return [Integer, nil] 1 if VM memory state was saved, 0 or nil otherwise
      attr_reader :vmstate

      # @return [String, nil] parent snapshot name for snapshot trees
      attr_reader :parent

      # @return [Integer, nil] VM/container ID this snapshot belongs to
      attr_reader :vmid

      # @return [String, nil] node name where the VM/container resides
      attr_reader :node

      # @return [Symbol, nil] resource type (:qemu for VM, :lxc for container)
      attr_reader :resource_type

      # Creates a new Snapshot instance.
      #
      # @param attrs [Hash] snapshot attributes
      # @option attrs [String] :name snapshot name
      # @option attrs [Integer] :snaptime Unix timestamp of creation
      # @option attrs [String] :description snapshot description
      # @option attrs [Integer] :vmstate 1 if VM state saved, 0 otherwise
      # @option attrs [String] :parent parent snapshot name
      # @option attrs [Integer] :vmid VM/container ID
      # @option attrs [String] :node node name
      # @option attrs [Symbol] :resource_type :qemu or :lxc
      def initialize(attrs = {})
        super
        @name = attributes[:name]
        @snaptime = attributes[:snaptime]
        @description = attributes[:description]
        @vmstate = attributes[:vmstate]
        @parent = attributes[:parent]
        @vmid = attributes[:vmid]
        @node = attributes[:node]
        @resource_type = attributes[:resource_type]
      end

      # Checks if the snapshot includes VM memory state.
      #
      # @return [Boolean] true if vmstate equals 1
      def has_vmstate?
        vmstate == 1
      end

      # Returns the snapshot creation time as a Time object.
      #
      # @return [Time, nil] creation time or nil if snaptime is not set
      def created_at
        return nil if snaptime.nil?

        Time.at(snaptime)
      end

      # Checks if the snapshot belongs to a VM (QEMU).
      #
      # @return [Boolean] true if resource_type is :qemu
      def vm?
        resource_type == :qemu
      end

      # Checks if the snapshot belongs to a container (LXC).
      #
      # @return [Boolean] true if resource_type is :lxc
      def container?
        resource_type == :lxc
      end
    end
  end
end
