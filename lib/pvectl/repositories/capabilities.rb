# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for Proxmox node capabilities.
    #
    # Aggregates feature information from the two most useful capability
    # endpoints — QEMU CPU models and QEMU machine types — into a flat
    # collection of Capability models. The cpu-flags and migration
    # capability endpoints are intentionally out of scope for the initial
    # implementation (YAGNI); they can be added when there is a concrete
    # consumer need.
    #
    # @example List capabilities for a node
    #   repo = Capabilities.new(connection)
    #   caps = repo.list(node: "pve1")
    #   caps.each { |c| puts "#{c.kind}: #{c.name}" }
    #
    # @see Pvectl::Models::Capability
    #
    class Capabilities < Base
      # CPU capability endpoint path (without leading slash).
      CPU_ENDPOINT = "capabilities/qemu/cpu"

      # Machine type capability endpoint path (without leading slash).
      MACHINES_ENDPOINT = "capabilities/qemu/machines"

      # Lists capabilities for a node.
      #
      # Combines `GET /nodes/{node}/capabilities/qemu/cpu` and
      # `GET /nodes/{node}/capabilities/qemu/machines`. Each entry becomes
      # a Capability instance — CPU models first, then machine types.
      #
      # @param node [String] cluster node name (required)
      # @return [Array<Models::Capability>]
      # @raise [ArgumentError] when `node` is nil/empty
      # @raise [StandardError] propagated from the API on auth/connection failure
      def list(node:)
        raise ArgumentError, "node is required" if node.nil? || node.to_s.empty?

        cpus(node) + machines(node)
      end

      private

      # Fetches CPU model capabilities.
      #
      # @param node [String]
      # @return [Array<Models::Capability>]
      def cpus(node)
        response = connection.client["nodes/#{node}/#{CPU_ENDPOINT}"].get
        unwrap(response).map { |data| build_cpu(data, node) }
      end

      # Fetches machine type capabilities.
      #
      # @param node [String]
      # @return [Array<Models::Capability>]
      def machines(node)
        response = connection.client["nodes/#{node}/#{MACHINES_ENDPOINT}"].get
        unwrap(response).map { |data| build_machine(data, node) }
      end

      # Builds a CPU capability model.
      #
      # @param data [Hash] one entry from the CPU endpoint
      # @param node [String]
      # @return [Models::Capability]
      def build_cpu(data, node)
        Models::Capability.new(
          node_name: node,
          kind: :cpu,
          name: data[:name],
          vendor: data[:vendor],
          custom: data[:custom] || false
        )
      end

      # Builds a machine type capability model.
      #
      # @param data [Hash] one entry from the machines endpoint
      # @param node [String]
      # @return [Models::Capability]
      def build_machine(data, node)
        Models::Capability.new(
          node_name: node,
          kind: :machine,
          name: data[:id],
          machine_type: data[:type],
          version: data[:version],
          changes: data[:changes]
        )
      end
    end
  end
end
