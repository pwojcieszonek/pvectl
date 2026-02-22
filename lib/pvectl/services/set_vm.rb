# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates non-interactive VM configuration updates.
    #
    # Takes key-value pairs directly (no editor), computes diff against
    # current config, and applies changes via the API.
    # Supports dry-run mode and optimistic locking via digest.
    #
    # @example Basic usage
    #   service = SetVm.new(vm_repository: repo)
    #   result = service.execute(vmid: 100, params: { memory: "8192", cores: "4" })
    #
    # @example Dry run
    #   service = SetVm.new(vm_repository: repo, options: { dry_run: true })
    #   result = service.execute(vmid: 100, params: { memory: "8192" })
    #
    class SetVm
      # Creates a new SetVm service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param options [Hash] options (dry_run)
      def initialize(vm_repository:, options: {})
        @vm_repository = vm_repository
        @options = options
      end

      # Executes the non-interactive VM config update.
      #
      # Fetches current config, computes diff against requested params,
      # and applies changes via the API (unless dry-run).
      #
      # @param vmid [Integer] VM identifier
      # @param params [Hash] key-value pairs to set
      # @return [Models::VmOperationResult, nil] result, or nil if no changes
      def execute(vmid:, params:)
        vm = @vm_repository.get(vmid)
        return not_found_result(vmid) unless vm

        config = @vm_repository.fetch_config(vm.node, vmid)
        resource_info = { vmid: vmid, node: vm.node, status: vm.status }

        changes = compute_diff(config, params)

        if changes[:changed].empty? && changes[:added].empty? && changes[:removed].empty?
          return nil
        end

        resource_info[:diff] = changes

        if @options[:dry_run]
          return build_result(resource_info, success: true)
        end

        update_params = build_update_params(changes, config)
        @vm_repository.update(vmid, vm.node, update_params)
        build_result(resource_info, success: true)
      rescue StandardError => e
        build_result({ vmid: vmid }, success: false, error: e.message)
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

      # Builds a VmOperationResult with the :set operation.
      #
      # @param resource_info [Hash] resource info (vmid, node, status)
      # @param attrs [Hash] additional result attributes
      # @return [Models::VmOperationResult]
      def build_result(resource_info, **attrs)
        vm = Models::Vm.new(vmid: resource_info[:vmid], node: resource_info[:node])
        Models::VmOperationResult.new(
          operation: :set, vm: vm, resource: resource_info, **attrs
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
