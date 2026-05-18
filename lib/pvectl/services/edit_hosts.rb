# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates the interactive editing flow for /etc/hosts on a node.
    #
    # Fetches current /etc/hosts content + digest, opens it in an editor,
    # and POSTs the new content back with the original digest for optimistic
    # locking. If Proxmox returns a digest collision (concurrent modification)
    # or any other error, the message is surfaced verbatim to the user.
    #
    # Unlike DNS (structured YAML), /etc/hosts is edited as raw text —
    # there is no parsing or validation pvectl-side.
    #
    # @example Basic usage
    #   service = EditHosts.new(hosts_repository: repo)
    #   result = service.execute(node_name: "pve1")
    #
    # @example Dry run
    #   service = EditHosts.new(hosts_repository: repo, options: { dry_run: true })
    #   result = service.execute(node_name: "pve1")
    #
    class EditHosts
      # Creates a new EditHosts service.
      #
      # @param hosts_repository [Repositories::Hosts] Hosts repository
      # @param editor_session [EditorSession, nil] optional injected editor session
      # @param options [Hash] options (dry_run)
      def initialize(hosts_repository:, editor_session: nil, options: {})
        @hosts_repository = hosts_repository
        @editor_session = editor_session
        @options = options
      end

      # Executes the interactive /etc/hosts edit flow.
      #
      # @param node_name [String] node name
      # @return [Models::NodeOperationResult, nil] result, or nil if cancelled/no changes
      def execute(node_name:)
        hosts = @hosts_repository.fetch(node_name)
        original = hosts.data || ""
        digest = hosts.digest

        session = @editor_session || EditorSession.new
        edited = session.edit(original)

        return nil if edited.nil?
        return nil if edited == original

        resource_info = {
          node_name: node_name,
          diff: { original: original, edited: edited }
        }

        return build_result(resource_info, success: true) if @options[:dry_run]

        @hosts_repository.update(node_name, edited, digest)
        build_result(resource_info, success: true)
      rescue StandardError => e
        build_result({ node_name: node_name }, success: false, error: e.message)
      end

      private

      # Builds a NodeOperationResult with the :edit operation.
      #
      # @param resource_info [Hash] resource info (node_name, optional diff)
      # @param attrs [Hash] additional result attributes
      # @return [Models::NodeOperationResult]
      def build_result(resource_info, **attrs)
        node_model = Models::Node.new(name: resource_info[:node_name])
        Models::NodeOperationResult.new(
          operation: :edit, node_model: node_model, resource: resource_info, **attrs
        )
      end
    end
  end
end
