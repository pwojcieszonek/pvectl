# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates the interactive editing flow for node DNS settings.
    #
    # Fetches current DNS config, presents it as YAML in an editor, computes
    # a diff, and applies changes via the Proxmox API. The Proxmox PUT endpoint
    # requires the `search` field — the service validates this before calling.
    #
    # @example Basic usage
    #   service = EditDns.new(dns_repository: repo)
    #   result = service.execute(node_name: "pve1")
    #
    # @example Dry run
    #   service = EditDns.new(dns_repository: repo, options: { dry_run: true })
    #   result = service.execute(node_name: "pve1")
    #
    class EditDns
      # Editable keys exposed in the YAML editor (in order).
      EDITABLE_KEYS = %i[search dns1 dns2 dns3].freeze

      # Creates a new EditDns service.
      #
      # @param dns_repository [Repositories::Dns] DNS repository
      # @param editor_session [EditorSession, nil] optional injected editor session
      # @param options [Hash] options (dry_run)
      def initialize(dns_repository:, editor_session: nil, options: {})
        @dns_repository = dns_repository
        @editor_session = editor_session
        @options = options
      end

      # Executes the interactive DNS edit flow.
      #
      # @param node_name [String] node name
      # @return [Models::NodeOperationResult, nil] result, or nil if cancelled/no changes
      def execute(node_name:)
        dns = @dns_repository.fetch(node_name)
        resource_info = { node_name: node_name }

        editable = build_editable(dns)
        yaml_content = "# Node: #{node_name} — DNS configuration\n" \
                       "# 'search' is required by Proxmox. dns1/dns2/dns3 are optional.\n" +
                       editable.to_yaml

        session = @editor_session || EditorSession.new
        edited = session.edit(yaml_content)

        return nil unless edited

        cleaned = edited.lines.reject { |l| l.strip.start_with?("#") }.join
        edited_config = YAML.safe_load(cleaned, symbolize_names: true) || {}

        original_symbolized = editable.transform_keys(&:to_sym)
        changes = compute_diff(original_symbolized, edited_config)

        if changes[:changed].empty? && changes[:added].empty? && changes[:removed].empty?
          return nil
        end

        validate!(edited_config)

        resource_info[:diff] = changes

        return build_result(resource_info, success: true) if @options[:dry_run]

        @dns_repository.update(node_name, build_update_params(edited_config))
        build_result(resource_info, success: true)
      rescue StandardError => e
        build_result({ node_name: node_name }, success: false, error: e.message)
      end

      private

      # Builds editable hash (string-keyed) from a DnsConfig model.
      #
      # @param dns [Models::DnsConfig] current config
      # @return [Hash{String=>String}] editable values
      def build_editable(dns)
        {
          "search" => dns.search,
          "dns1" => dns.dns1,
          "dns2" => dns.dns2,
          "dns3" => dns.dns3
        }.compact
      end

      # Validates the edited config satisfies API requirements.
      #
      # @param edited [Hash] edited config with symbol keys
      # @return [void]
      # @raise [ArgumentError] if `search` is missing or empty
      def validate!(edited)
        search = edited[:search]
        if search.nil? || search.to_s.strip.empty?
          raise ArgumentError, "search field is required by Proxmox API"
        end
      end

      # Computes diff between original and edited configs.
      #
      # @param original [Hash] original config (symbol keys)
      # @param edited [Hash] edited config (symbol keys)
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

      # Builds API update parameters from edited config.
      #
      # The PUT endpoint requires `search` and accepts optional dns1-3.
      # Removed keys are sent as empty strings to clear the field
      # (Proxmox accepts empty strings as "unset" for optional dns* fields).
      #
      # @param edited [Hash] edited config (symbol keys)
      # @return [Hash] API parameters with all editable keys present
      def build_update_params(edited)
        params = {}
        EDITABLE_KEYS.each do |key|
          value = edited[key]
          params[key] = value.nil? ? "" : value
        end
        # search must always have a real value (validated above)
        params[:search] = edited[:search]
        params
      end

      # Builds a NodeOperationResult with the :edit operation.
      #
      # @param resource_info [Hash] resource info (node_name)
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
