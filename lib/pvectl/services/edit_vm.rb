# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates the interactive VM configuration editing flow.
    #
    # Fetches current config, opens it in an editor as structured YAML,
    # validates changes, computes a diff, and applies updates via the API.
    # Supports dry-run mode and optimistic locking via digest.
    #
    # @example Basic usage
    #   service = EditVm.new(vm_repository: repo)
    #   result = service.execute(vmid: 100)
    #
    # @example Dry run with injected editor session
    #   service = EditVm.new(vm_repository: repo, editor_session: session,
    #                        options: { dry_run: true })
    #   result = service.execute(vmid: 100)
    #
    class EditVm
      # Creates a new EditVm service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param editor_session [EditorSession, nil] optional injected editor session
      # @param options [Hash] options (dry_run)
      def initialize(vm_repository:, editor_session: nil, options: {})
        @vm_repository = vm_repository
        @editor_session = editor_session
        @options = options
      end

      # Executes the interactive VM edit flow.
      #
      # @param vmid [Integer] VM identifier
      # @return [Models::VmOperationResult, nil] operation result, or nil if cancelled/no changes
      def execute(vmid:)
        vm = @vm_repository.get(vmid)
        return not_found_result(vmid) unless vm

        config = @vm_repository.fetch_config(vm.node, vmid)
        resource_info = { vmid: vmid, node: vm.node, status: vm.status }

        yaml_content = ConfigSerializer.to_yaml(config, type: :vm, resource: resource_info)

        validator = ->(content) { ConfigSerializer.validate(content, type: :vm) }
        session = @editor_session || EditorSession.new(validator: validator)
        edited = session.edit(yaml_content)

        return nil unless edited

        original_roundtrip = ConfigSerializer.from_yaml(yaml_content, type: :vm)
        edited_flat = ConfigSerializer.from_yaml(edited, type: :vm)

        violations = ConfigSerializer.readonly_violations(original_roundtrip, edited_flat, type: :vm)
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

        @vm_repository.update(vmid, vm.node, params)
        build_result(resource_info, success: true)
      rescue StandardError => e
        build_result({ vmid: vmid }, success: false, error: e.message)
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

      # Builds a VmOperationResult with the :edit operation.
      #
      # @param resource_info [Hash] resource info (vmid, node, status)
      # @param attrs [Hash] additional result attributes
      # @return [Models::VmOperationResult]
      def build_result(resource_info, **attrs)
        vm = Models::Vm.new(
          vmid: resource_info[:vmid],
          node: resource_info[:node]
        )
        Models::VmOperationResult.new(
          operation: :edit, vm: vm, resource: resource_info, **attrs
        )
      end

      # Builds a not-found error result.
      #
      # @param vmid [Integer] VM identifier
      # @return [Models::VmOperationResult]
      def not_found_result(vmid)
        build_result({ vmid: vmid }, success: false, error: "VM #{vmid} not found")
      end
    end
  end
end
