# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates the interactive container configuration editing flow.
    #
    # Fetches current config, opens it in an editor as structured YAML,
    # validates changes, computes a diff, and applies updates via the API.
    # Supports dry-run mode and optimistic locking via digest.
    #
    # @example Basic usage
    #   service = EditContainer.new(container_repository: repo)
    #   result = service.execute(ctid: 200)
    #
    # @example Dry run with injected editor session
    #   service = EditContainer.new(container_repository: repo, editor_session: session,
    #                               options: { dry_run: true })
    #   result = service.execute(ctid: 200)
    #
    class EditContainer
      # Creates a new EditContainer service.
      #
      # @param container_repository [Repositories::Container] Container repository
      # @param editor_session [EditorSession, nil] optional injected editor session
      # @param options [Hash] options (dry_run)
      def initialize(container_repository:, editor_session: nil, options: {})
        @container_repository = container_repository
        @editor_session = editor_session
        @options = options
      end

      # Executes the interactive container edit flow.
      #
      # @param ctid [Integer] Container identifier
      # @return [Models::ContainerOperationResult, nil] operation result, or nil if cancelled/no changes
      def execute(ctid:)
        container = @container_repository.get(ctid)
        return not_found_result(ctid) unless container

        config = @container_repository.fetch_config(container.node, ctid)
        resource_info = { ctid: ctid, node: container.node, status: container.status }

        yaml_content = ConfigSerializer.to_yaml(config, type: :container, resource: resource_info)

        validator = ->(content) { ConfigSerializer.validate(content, type: :container) }
        session = @editor_session || EditorSession.new(validator: validator)
        edited = session.edit(yaml_content)

        return nil unless edited

        original_roundtrip = ConfigSerializer.from_yaml(yaml_content, type: :container)
        edited_flat = ConfigSerializer.from_yaml(edited, type: :container)

        violations = ConfigSerializer.readonly_violations(original_roundtrip, edited_flat, type: :container)
        unless violations.empty?
          return build_result(resource_info, success: false,
                              error: "Read-only fields cannot be changed: #{violations.join(', ')}")
        end

        changes = ConfigSerializer.diff(original_roundtrip, edited_flat)

        if changes[:changed].empty? && changes[:added].empty? && changes[:removed].empty?
          return nil
        end

        params = build_update_params(changes, config)

        resource_info[:diff] = changes

        if @options[:dry_run]
          return build_result(resource_info, success: true)
        end

        @container_repository.update(ctid, container.node, params)
        build_result(resource_info, success: true)
      rescue StandardError => e
        build_result({ ctid: ctid }, success: false, error: e.message)
      end

      private

      # Builds API update parameters from a diff hash.
      #
      # Maps changed/added keys to their new values, removed keys to the
      # Proxmox `delete` parameter, and includes digest for optimistic locking.
      #
      # @param changes [Hash] diff hash with :changed, :added, :removed
      # @param original_config [Hash] original flat config (for digest)
      # @return [Hash] Proxmox API parameters
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

      # Builds a ContainerOperationResult with the :edit operation.
      #
      # @param resource_info [Hash] resource info (ctid, node, status)
      # @param attrs [Hash] additional result attributes
      # @return [Models::ContainerOperationResult]
      def build_result(resource_info, **attrs)
        container = Models::Container.new(
          vmid: resource_info[:ctid],
          node: resource_info[:node]
        )
        Models::ContainerOperationResult.new(
          operation: :edit, container: container, resource: resource_info, **attrs
        )
      end

      # Builds a not-found error result.
      #
      # @param ctid [Integer] Container identifier
      # @return [Models::ContainerOperationResult]
      def not_found_result(ctid)
        build_result({ ctid: ctid }, success: false, error: "Container #{ctid} not found")
      end
    end
  end
end
