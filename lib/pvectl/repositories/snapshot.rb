# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for VM/container snapshots.
    #
    # Handles listing snapshots for both QEMU VMs and LXC containers.
    # Filters out the "current" snapshot which represents the live state.
    #
    # @example Listing snapshots for a VM
    #   repo = Snapshot.new(connection)
    #   snapshots = repo.list(100, "pve1", :qemu)
    #   snapshots.each { |s| puts "#{s.name}: #{s.description}" }
    #
    # @example Listing snapshots for a container
    #   snapshots = repo.list(101, "pve1", :lxc)
    #
    # @see Pvectl::Models::Snapshot Snapshot model
    # @see Pvectl::Connection API connection
    #
    class Snapshot < Base
      # Lists all snapshots for a VM or container.
      #
      # Uses `/nodes/{node}/qemu/{vmid}/snapshot` for VMs or
      # `/nodes/{node}/lxc/{vmid}/snapshot` for containers.
      # Filters out the "current" snapshot which represents live state.
      #
      # @param vmid [Integer, String] VM or container identifier
      # @param node [String] node name where the resource resides
      # @param resource_type [Symbol] :qemu for VMs, :lxc for containers
      # @return [Array<Models::Snapshot>] collection of snapshot models
      def list(vmid, node, resource_type)
        endpoint = resource_endpoint(resource_type)
        response = connection.client["nodes/#{node}/#{endpoint}/#{vmid}/snapshot"].get

        response
          .reject { |s| s[:name] == "current" }
          .map { |data| build_model(data, vmid, node, resource_type) }
      rescue StandardError
        []
      end

      # Creates a snapshot for a VM or container.
      #
      # Uses `POST /nodes/{node}/qemu|lxc/{vmid}/snapshot` with parameters:
      # - snapname: Name of the snapshot
      # - description: Optional description
      # - vmstate: Include VM RAM state (QEMU only, ignored for LXC)
      #
      # @param vmid [Integer, String] VM or container identifier
      # @param node [String] node name where the resource resides
      # @param resource_type [Symbol] :qemu for VMs, :lxc for containers
      # @param name [String] name for the snapshot
      # @param description [String, nil] optional description
      # @param vmstate [Boolean] include RAM state (QEMU only)
      # @return [String] UPID of the snapshot creation task
      def create(vmid, node, resource_type, name:, description: nil, vmstate: false)
        endpoint = resource_endpoint(resource_type)
        params = { snapname: name }
        params[:description] = description if description
        params[:vmstate] = vmstate if vmstate && resource_type == :qemu

        connection.client["nodes/#{node}/#{endpoint}/#{vmid}/snapshot"].post(params)
      end

      # Deletes a snapshot.
      #
      # Uses `DELETE /nodes/{node}/qemu|lxc/{vmid}/snapshot/{snapname}`.
      #
      # @param vmid [Integer, String] VM or container identifier
      # @param node [String] node name where the resource resides
      # @param resource_type [Symbol] :qemu for VMs, :lxc for containers
      # @param snapname [String] name of the snapshot to delete
      # @param force [Boolean] force deletion even if snapshot is referenced
      # @return [String] UPID of the delete task
      def delete(vmid, node, resource_type, snapname, force: false)
        endpoint = resource_endpoint(resource_type)
        params = {}
        params[:force] = true if force

        connection.client["nodes/#{node}/#{endpoint}/#{vmid}/snapshot/#{snapname}"].delete(params)
      end

      # Rolls back to a snapshot.
      #
      # Uses `POST /nodes/{node}/qemu|lxc/{vmid}/snapshot/{snapname}/rollback`.
      #
      # @param vmid [Integer, String] VM or container identifier
      # @param node [String] node name where the resource resides
      # @param resource_type [Symbol] :qemu for VMs, :lxc for containers
      # @param snapname [String] name of the snapshot to rollback to
      # @param start [Boolean] start VM/container after rollback
      # @return [String] UPID of the rollback task
      def rollback(vmid, node, resource_type, snapname, start: false)
        endpoint = resource_endpoint(resource_type)
        params = {}
        params[:start] = true if start

        connection.client["nodes/#{node}/#{endpoint}/#{vmid}/snapshot/#{snapname}/rollback"].post(params)
      end

      private

      # Returns the API endpoint prefix for the resource type.
      #
      # @param resource_type [Symbol] :qemu or :lxc
      # @return [String] "qemu" or "lxc"
      def resource_endpoint(resource_type)
        resource_type == :lxc ? "lxc" : "qemu"
      end

      # Builds Snapshot model from API response data.
      #
      # @param data [Hash] API response hash
      # @param vmid [Integer, String] VM/container ID
      # @param node [String] node name
      # @param resource_type [Symbol] :qemu or :lxc
      # @return [Models::Snapshot] snapshot model instance
      def build_model(data, vmid, node, resource_type)
        Models::Snapshot.new(
          name: data[:name],
          snaptime: data[:snaptime],
          description: data[:description],
          vmstate: data[:vmstate],
          parent: data[:parent],
          vmid: vmid,
          node: node,
          resource_type: resource_type
        )
      end
    end
  end
end
