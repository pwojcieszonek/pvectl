# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a QEMU virtual machine in the Proxmox cluster.
    #
    # Immutable domain model containing VM attributes and status predicates.
    # Created by Repositories::Vm from API data.
    # Display/formatting methods are in Presenters::Vm.
    #
    # @example Creating a VM model
    #   vm = Vm.new(vmid: 100, name: "web", status: "running", node: "pve1")
    #   vm.running? #=> true
    #   vm.template? #=> false
    #
    # @example From API response
    #   data = { "vmid" => 100, "name" => "web", "status" => "running" }
    #   vm = Vm.new(data)
    #
    # @see Pvectl::Repositories::Vm Repository that creates VM instances
    # @see Pvectl::Presenters::Vm Presenter for formatting VM data
    #
    class Vm < Base
      # @return [Integer] unique VM identifier
      attr_reader :vmid

      # @return [String, nil] VM name
      attr_reader :name

      # @return [String] VM status (running, stopped, paused)
      attr_reader :status

      # @return [String] node name where VM runs
      attr_reader :node

      # @return [Float, nil] current CPU usage (0-1 scale)
      attr_reader :cpu

      # @return [Integer, nil] maximum CPU cores
      attr_reader :maxcpu

      # @return [Integer, nil] current memory usage in bytes
      attr_reader :mem

      # @return [Integer, nil] maximum memory in bytes
      attr_reader :maxmem

      # @return [Integer, nil] current disk usage in bytes
      attr_reader :disk

      # @return [Integer, nil] maximum disk size in bytes
      attr_reader :maxdisk

      # @return [Integer, nil] uptime in seconds
      attr_reader :uptime

      # @return [Integer, nil] template flag (1 if template, 0 otherwise)
      attr_reader :template

      # @return [String, nil] semicolon-separated tags
      attr_reader :tags

      # @return [String, nil] HA state
      attr_reader :hastate

      # @return [Integer, nil] network input bytes
      attr_reader :netin

      # @return [Integer, nil] network output bytes
      attr_reader :netout

      # @return [Hash, nil] raw API responses for describe command
      attr_reader :describe_data

      # @return [String, nil] resource pool name
      attr_reader :pool

      # Creates a new VM model from attributes.
      #
      # @param attrs [Hash] VM attributes from API (string or symbol keys)
      def initialize(attrs = {})
        super(attrs)
        # Use @attributes which has normalized symbol keys from Base
        @vmid = @attributes[:vmid]
        @name = @attributes[:name]
        @status = @attributes[:status]
        @node = @attributes[:node]
        @cpu = @attributes[:cpu]
        @maxcpu = @attributes[:maxcpu]
        @mem = @attributes[:mem]
        @maxmem = @attributes[:maxmem]
        @disk = @attributes[:disk]
        @maxdisk = @attributes[:maxdisk]
        @uptime = @attributes[:uptime]
        @template = @attributes[:template]
        @tags = @attributes[:tags]
        @hastate = @attributes[:hastate]
        @netin = @attributes[:netin]
        @netout = @attributes[:netout]
        @describe_data = @attributes[:describe_data]
        @pool = @attributes[:pool]
      end

      # Checks if the VM is running.
      #
      # @return [Boolean] true if status is "running"
      def running?
        status == "running"
      end

      # Checks if the VM is stopped.
      #
      # @return [Boolean] true if status is "stopped"
      def stopped?
        status == "stopped"
      end

      # Checks if the VM is paused.
      #
      # @return [Boolean] true if status is "paused"
      def paused?
        status == "paused"
      end

      # Checks if the VM is a template.
      #
      # @return [Boolean] true if template flag is 1
      def template?
        template == 1
      end
    end
  end
end
