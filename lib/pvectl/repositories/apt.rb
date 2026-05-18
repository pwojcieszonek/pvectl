# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for Proxmox APT package management on cluster nodes.
    #
    # Wraps the `/nodes/{node}/apt/*` API endpoints. Provides:
    # - listing pending package updates (GET /apt/update)
    # - refreshing the package index (POST /apt/update — apt-get update)
    # - reading per-package changelogs (GET /apt/changelog)
    # - listing important Proxmox package versions (GET /apt/versions)
    #
    # @example Listing pending updates on a node
    #   repo = Apt.new(connection)
    #   updates = repo.pending("pve1")
    #   updates.each { |p| puts "#{p.package}: #{p.old_version} -> #{p.version}" }
    #
    # @example Triggering a package index refresh
    #   upid = repo.refresh("pve1", notify: false, quiet: true)
    #
    # @see Pvectl::Models::AptPackage AptPackage model
    # @see Pvectl::Connection API connection
    #
    class Apt < Base
      # Lists pending APT updates available on a node.
      #
      # @param node [String] node name
      # @return [Array<Models::AptPackage>] pending package updates
      def pending(node)
        response = connection.client["nodes/#{node}/apt/update"].get
        packages = unwrap(response)
        packages.map { |data| build_model(data.merge(node: node)) }
      rescue StandardError
        []
      end

      # Refreshes the package index on a node (equivalent to apt-get update).
      #
      # Returns the Proxmox task UPID — the operation runs asynchronously.
      #
      # @param node [String] node name
      # @param notify [Boolean] whether to send a notification about new packages
      # @param quiet [Boolean] whether to suppress progress output
      # @return [String] task UPID
      def refresh(node, notify: false, quiet: false)
        params = {}
        params[:notify] = 1 if notify
        params[:quiet] = 1 if quiet
        response = connection.client["nodes/#{node}/apt/update"].post(params)
        data = extract_data(response)
        data.is_a?(String) ? data : data.to_s
      end

      # Fetches the changelog for a package on a node.
      #
      # @param node [String] node name
      # @param package [String] package name
      # @param version [String, nil] specific package version (optional)
      # @return [String] changelog text (empty string on error)
      def changelog(node, package, version: nil)
        params = { name: package }
        params[:version] = version if version
        response = connection.client["nodes/#{node}/apt/changelog"].get(params: params)
        data = extract_data(response)
        data.is_a?(String) ? data : data.to_s
      rescue StandardError
        ""
      end

      # Lists important Proxmox package versions installed on a node.
      #
      # @param node [String] node name
      # @return [Array<Models::AptPackage>] installed package versions
      def versions(node)
        response = connection.client["nodes/#{node}/apt/versions"].get
        packages = unwrap(response)
        packages.map { |data| build_model(data.merge(node: node)) }
      rescue StandardError
        []
      end

      protected

      # Builds AptPackage model from API response data.
      #
      # @param data [Hash] API response hash
      # @return [Models::AptPackage] AptPackage model instance
      def build_model(data)
        Models::AptPackage.new(data)
      end
    end
  end
end
