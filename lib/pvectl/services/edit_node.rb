# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates the interactive node configuration editing flow.
    #
    # Fetches current config, presents it as YAML in an editor,
    # computes diff, and applies changes. Uses plain YAML (not
    # ConfigSerializer) since node config is flat key-value.
    #
    # @example Basic usage
    #   service = EditNode.new(node_repository: repo)
    #   result = service.execute(node_name: "pve1")
    #
    # @example Dry run with injected editor session
    #   service = EditNode.new(node_repository: repo, editor_session: session,
    #                          options: { dry_run: true })
    #   result = service.execute(node_name: "pve1")
    #
    class EditNode
      # Read-only keys that should not be sent back to the API.
      READONLY_KEYS = %i[digest].freeze

      # Creates a new EditNode service.
      #
      # @param node_repository [Repositories::Node] Node repository
      # @param editor_session [EditorSession, nil] optional injected editor session
      # @param options [Hash] options (dry_run)
      def initialize(node_repository:, editor_session: nil, options: {})
        @node_repository = node_repository
        @editor_session = editor_session
        @options = options
      end

      # Executes the interactive node edit flow.
      #
      # @param node_name [String] node name
      # @return [Models::NodeOperationResult, nil] result, or nil if cancelled/no changes
      def execute(node_name:)
        node = @node_repository.get(node_name)
        return not_found_result(node_name) unless node

        config = @node_repository.fetch_config(node_name)
        resource_info = { node_name: node_name, status: node.status }

        # Build editable YAML (exclude digest — it's for optimistic locking only)
        editable = config.reject { |k, _| READONLY_KEYS.include?(k) }
        # Convert symbol keys to strings for clean YAML output (avoids :key: format)
        string_keyed = editable.transform_keys(&:to_s)
        yaml_content = "# Node: #{node_name}\n# Edit configuration below. Save and close to apply.\n" +
                        string_keyed.to_yaml

        session = @editor_session || EditorSession.new
        edited = session.edit(yaml_content)

        return nil unless edited

        # Parse edited YAML (strip comment lines)
        cleaned = edited.lines.reject { |l| l.strip.start_with?("#") }.join
        edited_config = YAML.safe_load(cleaned, symbolize_names: true) || {}

        # Compute diff against original editable config (with symbol keys)
        changes = compute_diff(editable, edited_config)

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

      # Computes diff between original and edited config.
      #
      # @param original [Hash] original config (without readonly keys)
      # @param edited [Hash] edited config
      # @return [Hash] diff with :changed, :added, :removed
      def compute_diff(original, edited)
        changed = {}
        added = {}
        removed = []

        edited.each do |key, value|
          orig_value = original[key]
          if orig_value.nil?
            added[key] = value
          elsif orig_value.to_s != value.to_s
            changed[key] = [orig_value.to_s, value.to_s]
          end
        end

        original.each_key do |key|
          removed << key unless edited.key?(key)
        end

        { changed: changed, added: added, removed: removed }
      end

      # Builds API update parameters from diff.
      #
      # @param changes [Hash] diff hash with :changed, :added, :removed
      # @param original_config [Hash] original config (for digest)
      # @return [Hash] API parameters
      def build_update_params(changes, original_config)
        params = {}
        changes[:changed].each { |key, (_old, new_val)| params[key] = new_val }
        changes[:added].each { |key, val| params[key] = val }
        unless changes[:removed].empty?
          params[:delete] = changes[:removed].map(&:to_s).join(",")
        end
        params[:digest] = original_config[:digest] if original_config[:digest]
        params
      end

      # Builds a NodeOperationResult with the :edit operation.
      #
      # @param resource_info [Hash] resource info (node_name, status)
      # @param attrs [Hash] additional result attributes
      # @return [Models::NodeOperationResult]
      def build_result(resource_info, **attrs)
        node_model = Models::Node.new(name: resource_info[:node_name])
        Models::NodeOperationResult.new(
          operation: :edit, node_model: node_model, resource: resource_info, **attrs
        )
      end

      # Builds a not-found error result.
      #
      # @param node_name [String] node name
      # @return [Models::NodeOperationResult]
      def not_found_result(node_name)
        build_result({ node_name: node_name }, success: false, error: "Node #{node_name} not found")
      end
    end
  end
end
