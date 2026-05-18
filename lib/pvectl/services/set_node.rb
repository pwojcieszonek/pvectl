# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates non-interactive node configuration updates.
    #
    # Takes key-value pairs directly (no editor), computes diff against
    # current config, and applies changes via the API.
    # Supports dry-run mode and optimistic locking via digest.
    #
    # The `timezone` key is special: it lives at `PUT /nodes/{node}/time`
    # rather than `PUT /nodes/{node}/config`, so the service splits it off
    # and routes it to a separate `time_repository`.
    #
    # @example Basic usage
    #   service = SetNode.new(node_repository: repo)
    #   result = service.execute(node_name: "pve1", params: { description: "updated" })
    #
    # @example Setting timezone
    #   service = SetNode.new(node_repository: node_repo, time_repository: time_repo)
    #   result = service.execute(node_name: "pve1", params: { timezone: "Europe/Warsaw" })
    #
    # @example Dry run
    #   service = SetNode.new(node_repository: repo, options: { dry_run: true })
    #   result = service.execute(node_name: "pve1", params: { description: "updated" })
    #
    class SetNode
      # Key recognized by this service as the node timezone (handled by the
      # `/time` endpoint rather than `/config`). Accepted as Symbol or String.
      TIMEZONE_KEY = :timezone

      # Creates a new SetNode service.
      #
      # @param node_repository [Repositories::Node] Node repository
      # @param time_repository [Repositories::TimeConfig, nil] Time repository (optional;
      #   required only when `params` includes `:timezone`)
      # @param options [Hash] options (dry_run)
      def initialize(node_repository:, time_repository: nil, options: {})
        @node_repository = node_repository
        @time_repository = time_repository
        @options = options
      end

      # Executes the non-interactive node config update.
      #
      # Fetches current config and (if timezone is requested) current timezone,
      # computes diffs against the requested params, and applies changes via
      # the appropriate API endpoint (unless dry-run).
      #
      # @param node_name [String] Node name
      # @param params [Hash] key-value pairs to set
      # @return [Models::NodeOperationResult, nil] result, or nil if no changes
      def execute(node_name:, params:)
        node = @node_repository.get(node_name)
        return not_found_result(node_name) unless node

        config = @node_repository.fetch_config(node_name)
        config_params, requested_tz = split_timezone(params)
        current_tz = requested_tz ? current_timezone(node_name) : nil

        changes = compute_diff(config, config_params)
        tz_change = compute_timezone_change(current_tz, requested_tz)
        merge_timezone_into_diff(changes, tz_change) if tz_change

        return nil if no_changes?(changes)

        resource_info = { node_name: node_name, status: node.status, diff: changes }
        return build_result(resource_info, success: true) if @options[:dry_run]

        apply_config_changes(node_name, changes, config) unless config_changes_empty?(changes, tz_change)
        @time_repository.set_timezone(node_name, tz_change[:to]) if tz_change

        build_result(resource_info, success: true)
      rescue StandardError => e
        build_result({ node_name: node_name }, success: false, error: e.message)
      end

      private

      # Separates the `:timezone` key (accepted as Symbol or String) from
      # other config params.
      #
      # @param params [Hash] requested params
      # @return [Array(Hash, String?)] pair of [remaining_params, requested_timezone_or_nil]
      def split_timezone(params)
        remaining = {}
        requested_tz = nil

        params.each do |key, value|
          if key.to_sym == TIMEZONE_KEY
            requested_tz = value.to_s
          else
            remaining[key] = value
          end
        end

        [remaining, requested_tz]
      end

      # Fetches the current timezone for the node.
      #
      # @param node_name [String]
      # @return [String, nil]
      def current_timezone(node_name)
        return nil unless @time_repository

        @time_repository.fetch(node_name).timezone
      end

      # Builds a timezone-change descriptor when requested != current.
      #
      # @param current [String, nil]
      # @param requested [String, nil]
      # @return [Hash{from: String, to: String}, nil] descriptor or nil when unchanged/missing
      def compute_timezone_change(current, requested)
        return nil if requested.nil?
        return nil if current.to_s == requested.to_s

        { from: current.to_s, to: requested.to_s }
      end

      # Folds a timezone change into the diff structure so it shows up in
      # the operation result alongside config-key changes.
      #
      # @param changes [Hash] diff hash (mutated in place)
      # @param tz_change [Hash] `{from:, to:}`
      # @return [void]
      def merge_timezone_into_diff(changes, tz_change)
        if tz_change[:from].nil? || tz_change[:from].empty?
          changes[:added][TIMEZONE_KEY] = tz_change[:to]
        else
          changes[:changed][TIMEZONE_KEY] = [tz_change[:from], tz_change[:to]]
        end
      end

      # Computes diff between current config and requested params.
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

      # Returns true when the diff contains no actionable change.
      #
      # @param changes [Hash] diff hash
      # @return [Boolean]
      def no_changes?(changes)
        changes[:changed].empty? && changes[:added].empty? && changes[:removed].empty?
      end

      # Applies non-timezone diff entries via the node config endpoint.
      #
      # @param node_name [String]
      # @param changes [Hash] diff hash
      # @param original_config [Hash] for digest
      # @return [void]
      def apply_config_changes(node_name, changes, original_config)
        update_params = build_update_params(changes, original_config)
        return if update_params.empty? || update_params.keys == [:digest]

        @node_repository.update(node_name, update_params)
      end

      # True when the only changes in the diff are timezone-related.
      #
      # @param changes [Hash] diff hash
      # @param tz_change [Hash, nil]
      # @return [Boolean]
      def config_changes_empty?(changes, tz_change)
        return false if tz_change.nil?

        non_tz_changed = changes[:changed].keys - [TIMEZONE_KEY]
        non_tz_added = changes[:added].keys - [TIMEZONE_KEY]
        non_tz_changed.empty? && non_tz_added.empty?
      end

      # Builds API update parameters from diff (excluding timezone, which is
      # routed elsewhere).
      #
      # @param changes [Hash] diff hash with :changed, :added
      # @param original_config [Hash] original config (for digest)
      # @return [Hash] API parameters
      def build_update_params(changes, original_config)
        params = {}
        changes[:changed].each do |key, (_old, new_val)|
          next if key == TIMEZONE_KEY

          params[key] = new_val
        end
        changes[:added].each do |key, val|
          next if key == TIMEZONE_KEY

          params[key] = val
        end
        params[:digest] = original_config[:digest] if original_config[:digest] && !params.empty?
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
