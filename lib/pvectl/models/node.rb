# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a node in the Proxmox cluster.
    #
    # Immutable domain model containing node attributes and domain predicates.
    # Display formatting is handled by Presenters::Node.
    # Created by Repositories::Node from API data.
    #
    # @example Creating a Node model
    #   node = Node.new(name: "pve1", status: "online", cpu: 0.23)
    #   node.online? #=> true
    #   node.guests_total #=> 42
    #
    # @example From API response
    #   data = { "node" => "pve1", "status" => "online", "cpu" => 0.23 }
    #   node = Node.new(data)
    #
    # @see Pvectl::Repositories::Node Repository that creates Node instances
    # @see Pvectl::Presenters::Node Presenter for formatting Node data
    #
    class Node < Base
      # @return [String] node name
      attr_reader :name

      # @return [String] node status (online/offline)
      attr_reader :status

      # @return [Float, nil] CPU usage (0-1 scale)
      attr_reader :cpu

      # @return [Integer, nil] total CPU cores
      attr_reader :maxcpu

      # @return [Integer, nil] memory used in bytes
      attr_reader :mem

      # @return [Integer, nil] total memory in bytes
      attr_reader :maxmem

      # @return [Integer, nil] local disk used in bytes
      attr_reader :disk

      # @return [Integer, nil] total local disk in bytes
      attr_reader :maxdisk

      # @return [Integer, nil] uptime in seconds
      attr_reader :uptime

      # @return [String, nil] subscription level (c=community, b=basic, etc.)
      attr_reader :level

      # @return [String, nil] Proxmox version (e.g., "8.3.2")
      attr_reader :version

      # @return [String, nil] kernel version (e.g., "6.8.12-1-pve")
      attr_reader :kernel

      # @return [Array<Float>, nil] load averages [1min, 5min, 15min]
      attr_reader :loadavg

      # @return [Integer, nil] swap used in bytes
      attr_reader :swap_used

      # @return [Integer, nil] total swap in bytes
      attr_reader :swap_total

      # @return [Integer] number of VMs on this node
      attr_reader :guests_vms

      # @return [Integer] number of containers on this node
      attr_reader :guests_cts

      # @return [String, nil] node IP address (from interface with gateway)
      attr_reader :ip

      # Extended attributes for describe command
      # @return [Hash, nil] CPU info (model, cores, sockets)
      attr_reader :cpuinfo

      # @return [Hash, nil] boot info (mode: efi/bios)
      attr_reader :boot_info

      # @return [Hash, nil] root filesystem (used, total, free)
      attr_reader :rootfs

      # @return [Hash, nil] subscription info (status, level, productname)
      attr_reader :subscription

      # @return [Hash, nil] DNS configuration (search, dns1, dns2, dns3)
      attr_reader :dns

      # @return [Hash, nil] time configuration (timezone, localtime, time)
      attr_reader :time_info

      # @return [Array<Hash>] network interfaces
      attr_reader :network_interfaces

      # @return [Array<Hash>] system services
      attr_reader :services

      # @return [Array<Models::Storage>] storage pools
      attr_reader :storage_pools

      # @return [Array<Hash>] physical disks
      attr_reader :physical_disks

      # @return [Array<Hash>] QEMU CPU models
      attr_reader :qemu_cpu_models

      # @return [Array<Hash>] QEMU machine types
      attr_reader :qemu_machines

      # @return [Integer] number of available updates
      attr_reader :updates_available

      # @return [Array<Hash>] available updates
      attr_reader :updates

      # @return [String, nil] offline note message
      attr_reader :offline_note

      # Creates a new Node model from attributes.
      #
      # @param attrs [Hash] Node attributes from API (string or symbol keys)
      def initialize(attrs = {})
        super(attrs)
        @name = @attributes[:name] || @attributes[:node]
        @status = @attributes[:status]
        @cpu = @attributes[:cpu]
        @maxcpu = @attributes[:maxcpu]
        @mem = @attributes[:mem]
        @maxmem = @attributes[:maxmem]
        @disk = @attributes[:disk]
        @maxdisk = @attributes[:maxdisk]
        @uptime = @attributes[:uptime]
        @level = @attributes[:level]
        @version = @attributes[:version]
        @kernel = @attributes[:kernel]
        @loadavg = @attributes[:loadavg]
        @swap_used = @attributes[:swap_used]
        @swap_total = @attributes[:swap_total]
        @guests_vms = @attributes[:guests_vms] || 0
        @guests_cts = @attributes[:guests_cts] || 0
        @ip = @attributes[:ip]
        # Extended attributes for describe
        @cpuinfo = @attributes[:cpuinfo]
        @boot_info = @attributes[:boot_info]
        @rootfs = @attributes[:rootfs]
        @subscription = @attributes[:subscription]
        @dns = @attributes[:dns]
        @time_info = @attributes[:time_info]
        @network_interfaces = @attributes[:network_interfaces] || []
        @services = @attributes[:services] || []
        @storage_pools = @attributes[:storage_pools] || []
        @physical_disks = @attributes[:physical_disks] || []
        @qemu_cpu_models = @attributes[:qemu_cpu_models] || []
        @qemu_machines = @attributes[:qemu_machines] || []
        @updates_available = @attributes[:updates_available] || 0
        @updates = @attributes[:updates] || []
        @offline_note = @attributes[:offline_note]
      end

      # Checks if the node is online.
      #
      # @return [Boolean] true if status is "online"
      def online?
        status == "online"
      end

      # Checks if the node is offline.
      #
      # @return [Boolean] true if status is not "online"
      def offline?
        !online?
      end

      # Returns total guest count (VMs + containers).
      #
      # @return [Integer] total guests
      def guests_total
        guests_vms + guests_cts
      end
    end
  end
end
