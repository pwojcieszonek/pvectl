# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates non-interactive node configuration updates.
    #
    # Takes key-value pairs directly (no editor), computes diff against
    # current config, and applies changes via the API.
    # Supports dry-run mode and optimistic locking via digest.
    #
    # @example Basic usage
    #   service = SetNode.new(node_repository: repo)
    #   result = service.execute(node_name: "pve1", params: { description: "updated" })
    #
    # @example Dry run
    #   service = SetNode.new(node_repository: repo, options: { dry_run: true })
    #   result = service.execute(node_name: "pve1", params: { description: "updated" })
    #
    class SetNode
      # Creates a new SetNode service.
      #
      # @param node_repository [Repositories::Node] Node repository
      # @param options [Hash] options (dry_run)
      def initialize(node_repository:, options: {})
        @node_repository = node_repository
        @options = options
      end

      # Executes the non-interactive node config update.
      #
      # Fetches current config, computes diff against requested params,
      # and applies changes via the API (unless dry-run).
      #
      # @param node_name [String] Node name
      # @param params [Hash] key-value pairs to set
      # @return [Models::NodeOperationResult, nil] result, or nil if no changes
      def execute(node_name:, params:)
        node = @node_repository.get(node_name)
        return not_found_result(node_name) unless node

        config = @node_repository.fetch_config(node_name)
        resource_info = { node_name: node_name, status: node.status }

        changes = compute_diff(config, params)

        if changes[:changed].empty? && changes[:added].empty? && changes[:removed].empty?
          return nil
        end

        resource_info[:diff] = changes

        if @options[:dry_run]
          return build_result(resource_info, success: true)
        end

        update_params = build_update_params(changes, config)
        @node_repository.update(node_name, update_params)
        build_result(resource_info, success: true)
      rescue StandardError => e
        build_result({ node_name: node_name }, success: false, error: e.message)
      end

      private

      # Computes diff between current config and requested params.
      #
      # Categorizes each requested param as :changed (value differs),
      # :added (key not in current config), or unchanged (skipped).
      #
      # @param config [Hash] current configuration
      # @param params [Hash] requested key-value changes
      # @return [Hash] diff with :changed, :added, :removed keys
      def compute_diff(config, params)
        changed = {}
        added = {}

        params.each do |key, value|
          sym_key = key.to_sym
          current = config[sym_key]

          if current.nil?
            added[sym_key] = value
          elsif current.to_s != value.to_s
            changed[sym_key] = [current.to_s, value.to_s]
          end
        end

        { changed: changed, added: added, removed: [] }
      end

      # Builds API update parameters from diff.
      #
      # Maps changed/added keys to their new values and includes
      # digest from original config for optimistic locking.
      #
      # @param changes [Hash] diff hash with :changed, :added
      # @param original_config [Hash] original config (for digest)
      # @return [Hash] API parameters
      def build_update_params(changes, original_config)
        params = {}
        changes[:changed].each { |key, (_old, new_val)| params[key] = new_val }
        changes[:added].each { |key, val| params[key] = val }
        params[:digest] = original_config[:digest] if original_config[:digest]
        params
      end

      # Builds a NodeOperationResult with the :set operation.
      #
      # @param resource_info [Hash] resource info (node_name, status)
      # @param attrs [Hash] additional result attributes
      # @return [Models::NodeOperationResult]
      def build_result(resource_info, **attrs)
        node_model = Models::Node.new(name: resource_info[:node_name])
        Models::NodeOperationResult.new(
          operation: :set, node_model: node_model, resource: resource_info, **attrs
        )
      end

      # Builds a not-found error result.
      #
      # @param node_name [String] Node name
      # @return [Models::NodeOperationResult]
      def not_found_result(node_name)
        build_result({ node_name: node_name }, success: false, error: "Node #{node_name} not found")
      end
    end
  end
end
