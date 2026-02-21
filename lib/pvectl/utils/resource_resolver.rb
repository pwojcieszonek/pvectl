# frozen_string_literal: true

module Pvectl
  module Utils
    # Utility for resolving VMID to VM/container type and node.
    #
    # ResourceResolver auto-detects whether a given VMID belongs to a
    # QEMU virtual machine or LXC container and retrieves its node location.
    # Results are cached for efficiency when resolving multiple VMIDs.
    #
    # @example Resolving a single VMID
    #   resolver = ResourceResolver.new(connection)
    #   info = resolver.resolve(100)
    #   puts "VM #{info[:vmid]} is a #{info[:type]} on #{info[:node]}"
    #
    # @example Resolving multiple VMIDs
    #   resolver = ResourceResolver.new(connection)
    #   infos = resolver.resolve_multiple([100, 101, 102])
    #   infos.each { |i| puts "#{i[:vmid]}: #{i[:type]}" }
    #
    class ResourceResolver
      # Creates a new ResourceResolver.
      #
      # @param connection [Connection] Proxmox API connection
      def initialize(connection)
        @connection = connection
        @cache = nil
      end

      # Resolves a VMID to its resource information.
      #
      # @param vmid [Integer, String] VM or container identifier
      # @return [Hash, nil] hash with :vmid, :node, :type (:qemu or :lxc), :name
      #   or nil if not found
      def resolve(vmid)
        vmid = vmid.to_i
        load_resources
        @cache[vmid]
      end

      # Resolves multiple VMIDs to their resource information.
      #
      # @param vmids [Array<Integer, String>] array of VM/container identifiers
      # @return [Array<Hash>] array of resolved resources (unknown VMIDs are skipped)
      def resolve_multiple(vmids)
        load_resources
        vmids.map { |id| @cache[id.to_i] }.compact
      end

      # Returns all resources in the cluster.
      #
      # @return [Array<Hash>] array of all VM/container resources
      def resolve_all
        load_resources
        @cache.values
      end

      private

      # Loads and caches cluster resources.
      #
      # @return [void]
      def load_resources
        return if @cache

        response = @connection.client["cluster/resources"].get(type: "vm")
        @cache = {}

        response.each do |r|
          @cache[r[:vmid]] = {
            vmid: r[:vmid],
            node: r[:node],
            type: r[:type] == "lxc" ? :lxc : :qemu,
            name: r[:name]
          }
        end
      end
    end
  end
end
