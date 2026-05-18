# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for per-node /etc/hosts file contents.
    #
    # Uses the `/nodes/{node}/hosts` endpoint to fetch and update
    # the raw contents of /etc/hosts on a single node.
    #
    # The Proxmox API returns a {data, digest} pair. The digest is used
    # for optimistic concurrency control — the same digest must be sent
    # back with the POST update.
    #
    # @example Fetching hosts file
    #   repo = Hosts.new(connection)
    #   hosts = repo.fetch("pve1")
    #   hosts.data   #=> "127.0.0.1 localhost\n..."
    #   hosts.digest #=> "abc123def..."
    #
    # @example Updating hosts file with digest
    #   repo.update("pve1", "127.0.0.1 localhost\n", "abc123def...")
    #
    # @see Pvectl::Models::HostsFile HostsFile model
    #
    class Hosts < Base
      # Fetches the /etc/hosts contents for a node.
      #
      # @param node_name [String] node name
      # @return [Models::HostsFile] hosts file model with data and digest
      def fetch(node_name)
        response = connection.client["nodes/#{node_name}/hosts"].get
        data = extract_data(response) || {}
        build_model(data.merge(node: node_name))
      end

      # Updates the /etc/hosts contents for a node.
      #
      # The Proxmox POST endpoint requires `data` and optionally accepts
      # `digest` for optimistic locking. If the on-server digest no longer
      # matches, Proxmox returns an error which is propagated verbatim.
      #
      # @param node_name [String] node name
      # @param data [String] new /etc/hosts content
      # @param digest [String, nil] digest from prior fetch (optional but recommended)
      # @return [void]
      def update(node_name, data, digest = nil)
        params = { data: data }
        params[:digest] = digest if digest && !digest.empty?
        connection.client["nodes/#{node_name}/hosts"].post(params)
      end

      protected

      # Builds HostsFile model from API data.
      #
      # @param data [Hash] API response hash (must include :node key for context)
      # @return [Models::HostsFile] hosts file model
      def build_model(data)
        Models::HostsFile.new(data)
      end
    end
  end
end
