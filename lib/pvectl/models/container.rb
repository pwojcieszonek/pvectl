# frozen_string_literal: true

module Pvectl
  module Models
    # Represents an LXC container in the Proxmox cluster.
    #
    # Immutable domain model containing container attributes and status predicates.
    # Created by Repositories::Container from API data.
    # Display/formatting methods are in Presenters::Container.
    #
    # @example Creating a Container model
    #   ct = Container.new(vmid: 100, name: "web", status: "running", node: "pve1")
    #   ct.running? #=> true
    #   ct.template? #=> false
    #
    # @example From API response
    #   data = { "vmid" => 100, "name" => "web", "status" => "running" }
    #   ct = Container.new(data)
    #
    # @see Pvectl::Repositories::Container Repository that creates Container instances
    # @see Pvectl::Presenters::Container Presenter for formatting Container data
    #
    class Container < Base
      # @!group Identifier Attributes

      # @return [Integer] unique container identifier (CTID: 100-999999999)
      attr_reader :vmid

      # @return [String, nil] container name (hostname)
      attr_reader :name

      # @return [String] node name where container runs
      attr_reader :node

      # @return [String] container status (running, stopped)
      attr_reader :status

      # @!endgroup

      # @!group Resource Attributes

      # @return [Float, nil] current CPU usage (0.0-1.0 scale)
      attr_reader :cpu

      # @return [Integer, nil] allocated CPU cores
      attr_reader :maxcpu

      # @return [Integer, nil] current memory usage in bytes
      attr_reader :mem

      # @return [Integer, nil] memory limit in bytes
      attr_reader :maxmem

      # @return [Integer, nil] current swap usage in bytes
      attr_reader :swap

      # @return [Integer, nil] swap limit in bytes
      attr_reader :maxswap

      # @return [Integer, nil] current rootfs disk usage in bytes
      attr_reader :disk

      # @return [Integer, nil] rootfs disk limit in bytes
      attr_reader :maxdisk

      # @!endgroup

      # @!group Metadata Attributes

      # @return [Integer, nil] uptime in seconds
      attr_reader :uptime

      # @return [Integer, nil] template flag (1 if template, 0 otherwise)
      attr_reader :template

      # @return [String, nil] semicolon-separated tags
      attr_reader :tags

      # @return [String, nil] resource pool name
      attr_reader :pool

      # @return [String, nil] lock status (backup, migrate, etc.)
      attr_reader :lock

      # @!endgroup

      # @!group Network I/O Attributes

      # @return [Integer, nil] network input bytes
      attr_reader :netin

      # @return [Integer, nil] network output bytes
      attr_reader :netout

      # @!endgroup

      # @!group Describe-Only Attributes

      # @return [String, nil] OS type (debian, ubuntu, alpine, etc.)
      attr_reader :ostype

      # @return [String, nil] architecture (amd64, arm64)
      attr_reader :arch

      # @return [Integer, nil] unprivileged flag (1 if unprivileged, 0 otherwise)
      attr_reader :unprivileged

      # @return [String, nil] features configuration (nesting, keyctl, etc.)
      attr_reader :features

      # @return [String, nil] rootfs configuration string
      attr_reader :rootfs

      # @return [Array<Hash>] network interface configurations
      attr_reader :network_interfaces

      # @return [String, nil] container description
      attr_reader :description

      # @return [String, nil] container hostname (FQDN)
      attr_reader :hostname

      # @return [Integer, nil] runtime PID
      attr_reader :pid

      # @return [Hash, nil] HA state information
      attr_reader :ha

      # @return [String, nil] resource type from API ("lxc")
      attr_reader :type

      # @!endgroup

      # Creates a new Container model from attributes.
      #
      # @param attrs [Hash] Container attributes from API (string or symbol keys)
      def initialize(attrs = {})
        super(attrs)
        # Use @attributes which has normalized symbol keys from Base
        @vmid = @attributes[:vmid]
        @name = @attributes[:name]
        @node = @attributes[:node]
        @status = @attributes[:status]
        @cpu = @attributes[:cpu]
        @maxcpu = @attributes[:maxcpu]
        @mem = @attributes[:mem]
        @maxmem = @attributes[:maxmem]
        @swap = @attributes[:swap]
        @maxswap = @attributes[:maxswap]
        @disk = @attributes[:disk]
        @maxdisk = @attributes[:maxdisk]
        @uptime = @attributes[:uptime]
        @template = @attributes[:template]
        @tags = @attributes[:tags]
        @pool = @attributes[:pool]
        @lock = @attributes[:lock]
        @netin = @attributes[:netin]
        @netout = @attributes[:netout]
        @ostype = @attributes[:ostype]
        @arch = @attributes[:arch]
        @unprivileged = @attributes[:unprivileged]
        @features = @attributes[:features]
        @rootfs = @attributes[:rootfs]
        @network_interfaces = @attributes[:network_interfaces] || []
        @description = @attributes[:description]
        @hostname = @attributes[:hostname]
        @pid = @attributes[:pid]
        @ha = @attributes[:ha]
        @type = @attributes[:type]
      end

      # Checks if the container is running.
      #
      # @return [Boolean] true if status is "running"
      def running?
        status == "running"
      end

      # Checks if the container is stopped.
      #
      # @return [Boolean] true if status is "stopped"
      def stopped?
        status == "stopped"
      end

      # Checks if the container is a template.
      #
      # @return [Boolean] true if template flag is 1
      def template?
        template == 1
      end

      # Checks if the container is unprivileged.
      #
      # @return [Boolean] true if unprivileged flag is 1
      def unprivileged?
        unprivileged == 1
      end
    end
  end
end
