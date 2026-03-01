# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates pushing YAML manifests to the Proxmox cluster.
    # Implements a two-phase approach: prepare (validate + diff) then apply.
    #
    # @example Push a single manifest
    #   service = PushConfig.new(vm_repository: vm_repo, container_repository: ct_repo)
    #   result = service.prepare(yaml_string)
    #   service.apply(result[:plans]) unless result[:plans].empty?
    class PushConfig
      # @param vm_repository [Repositories::Vm] VM repository
      # @param container_repository [Repositories::Container] container repository
      def initialize(vm_repository:, container_repository:)
        @vm_repository = vm_repository
        @container_repository = container_repository
      end

      # Prepares a push plan from a single YAML manifest string.
      # Validates the manifest, determines update vs create, computes diff.
      #
      # @param yaml_string [String] YAML manifest content
      # @return [Hash] { plans: Array<Hash>, errors: Array<String> }
      def prepare(yaml_string)
        errors = ManifestSerializer.validate(yaml_string)
        return { plans: [], errors: errors } unless errors.empty?

        manifest = ManifestSerializer.from_yaml(yaml_string)
        type = manifest[:type]
        metadata = manifest[:metadata]
        spec = manifest[:spec]
        vmid = metadata[:vmid]
        repo = repository_for(type)

        # Convert nested spec to flat config
        flat_from_manifest = ConfigSerializer.from_nested(spec, type: type)

        # No VMID → always create with auto-allocated ID
        unless vmid
          return prepare_create(type, metadata, flat_from_manifest, repo, auto_id: true)
        end

        # Check if resource exists (update) or not (create)
        resource = repo.get(vmid)

        if resource
          # UPDATE path: fetch current config, compute diff
          current_config = repo.fetch_config(resource.node, vmid)
          original_flat = ConfigSerializer.from_nested(
            ConfigSerializer.to_nested(current_config, type: type), type: type
          )

          # Check readonly violations — only for keys the manifest actually sets.
          # Keys absent from the manifest are not violations (user simply omitted them).
          shared_keys = original_flat.keys & flat_from_manifest.keys
          original_for_check = original_flat.slice(*shared_keys)
          manifest_for_check = flat_from_manifest.slice(*shared_keys)
          violations = ConfigSerializer.readonly_violations(original_for_check, manifest_for_check, type: type)
          unless violations.empty?
            return { plans: [], errors: ["Read-only fields cannot be changed: #{violations.join(', ')}"] }
          end

          # Strip read-only keys from original before diff — manifests never include them,
          # so they would always appear as "removed" and generate false diffs.
          readonly_keys = collect_readonly_keys(original_flat, type)
          comparable_original = original_flat.reject { |k, _| readonly_keys.include?(k) }

          diff = ConfigSerializer.diff(comparable_original, flat_from_manifest)

          if diff[:changed].empty? && diff[:added].empty? && diff[:removed].empty?
            return { plans: [], errors: [], no_changes: true }
          end

          plan = {
            action: :update,
            type: type,
            vmid: vmid,
            node: resource.node,
            diff: diff,
            params: build_update_params(diff, current_config)
          }

          { plans: [plan], errors: [] }
        else
          prepare_create(type, metadata, flat_from_manifest, repo, vmid: vmid)
        end
      rescue StandardError => e
        { plans: [], errors: [e.message] }
      end

      # Prepares push plans from multiple YAML contents.
      #
      # @param yaml_contents [Array<Hash>] array of { filename: String, content: String }
      # @param filter_type [Symbol, nil] optional type filter (:vm or :container)
      # @return [Hash] { plans: Array<Hash>, errors: Array<String>, skipped: Array<String> }
      def prepare_batch(yaml_contents, filter_type: nil)
        plans = []
        errors = []
        skipped = []

        yaml_contents.each do |entry|
          filename = entry[:filename]
          content = entry[:content]

          # Pre-check kind filter before full prepare
          if filter_type
            begin
              parsed = YAML.safe_load(content)
              kind = ManifestSerializer::KINDS_REVERSE[parsed&.dig("kind")]
              if kind && kind != filter_type
                skipped << "#{filename}: skipped (kind #{parsed['kind']} doesn't match filter)"
                next
              end
            rescue Psych::SyntaxError
              # Will be caught by prepare
            end
          end

          result = prepare(content)

          if result[:no_changes]
            skipped << "#{filename}: no changes"
            next
          end

          result[:plans].each do |p|
            p[:filename] = filename
            p[:source_path] = entry[:path]
          end
          plans.concat(result[:plans])
          errors.concat(result[:errors].map { |e| "#{filename}: #{e}" })
        end

        { plans: plans, errors: errors, skipped: skipped }
      end

      # Applies prepared plans (executes API calls).
      #
      # @param plans [Array<Hash>] plans from prepare/prepare_batch
      # @return [Hash] { results: Array<Hash>, errors: Array<String> }
      def apply(plans)
        results = []
        errors = []

        plans.each do |plan|
          begin
            repo = repository_for(plan[:type])

            if plan[:action] == :update
              repo.update(plan[:vmid], plan[:node], plan[:params])
              results << { action: :update, vmid: plan[:vmid], type: plan[:type], success: true }
            elsif plan[:action] == :create
              repo.create(plan[:node], plan[:vmid], plan[:params])
              results << {
                action: :create, vmid: plan[:vmid], type: plan[:type], success: true,
                auto_id: plan[:auto_id], source_path: plan[:source_path]
              }
            end
          rescue StandardError => e
            errors << "Error applying #{plan[:action]} for #{type_label(plan[:type])} #{plan[:vmid]}: #{e.message}"
            results << { action: plan[:action], vmid: plan[:vmid], type: plan[:type], success: false, error: e.message }
          end
        end

        { results: results, errors: errors }
      end

      private

      # Prepares a create plan, optionally allocating a VMID.
      #
      # @param type [Symbol] :vm or :container
      # @param metadata [Hash] manifest metadata
      # @param flat_config [Hash] flat config from manifest spec
      # @param repo [Repositories::Vm, Repositories::Container] repository
      # @param vmid [Integer, nil] explicit VMID (nil when auto_id)
      # @param auto_id [Boolean] whether to auto-allocate a VMID
      # @return [Hash] { plans: Array<Hash>, errors: Array<String> }
      def prepare_create(type, metadata, flat_config, repo, vmid: nil, auto_id: false)
        node = metadata[:node]
        unless node
          label = vmid ? "VMID #{vmid}" : "new resource"
          return { plans: [], errors: ["Node is required for creating #{label}"] }
        end

        if auto_id
          vmid = allocate_vmid(repo, type)
        end

        plan = {
          action: :create,
          type: type,
          vmid: vmid,
          node: node,
          params: flat_config,
          auto_id: auto_id
        }

        { plans: [plan], errors: [] }
      end

      # Allocates the next available VMID from the repository.
      #
      # @param repo [Repositories::Vm, Repositories::Container] repository
      # @param type [Symbol] :vm or :container
      # @return [Integer] next available VMID
      def allocate_vmid(repo, type)
        if type == :container
          repo.next_available_ctid
        else
          repo.next_available_vmid
        end
      end

      # Returns the appropriate repository for the given resource type.
      #
      # @param type [Symbol] :vm or :container
      # @return [Repositories::Vm, Repositories::Container]
      def repository_for(type)
        type == :container ? @container_repository : @vm_repository
      end

      # Builds flat update params from a diff and original config.
      # Includes changed keys, added keys, and a delete list for removed keys.
      # Preserves the digest from original config for optimistic locking.
      #
      # @param diff [Hash] diff from ConfigSerializer.diff
      # @param original_config [Hash] original flat config from API
      # @return [Hash] params ready for repository update call
      def build_update_params(diff, original_config)
        params = {}
        diff[:changed].each { |key, (_old, new_val)| params[key] = new_val }
        diff[:added].each { |key, val| params[key] = val }
        unless diff[:removed].empty?
          params[:delete] = diff[:removed].map(&:to_s).join(",")
        end
        params[:digest] = original_config[:digest] if original_config[:digest]
        params
      end

      # Collects read-only keys present in the given flat config.
      # Uses ConfigSerializer section definitions to identify readonly fields.
      #
      # @param flat_config [Hash] flat config hash
      # @param type [Symbol] :vm or :container
      # @return [Array<Symbol>] read-only keys found in the config
      def collect_readonly_keys(flat_config, type)
        sections = type == :container ? ConfigSerializer::CONTAINER_SECTIONS : ConfigSerializer::VM_SECTIONS
        readonly = []

        each_leaf_section(sections) do |section_def|
          section_def[:readonly].each do |ro|
            if ro.is_a?(Regexp)
              flat_config.each_key { |k| readonly << k if ro.match?(k.to_s) }
            else
              readonly << ro if flat_config.key?(ro)
            end
          end
        end

        readonly.uniq
      end

      # Yields each leaf section definition (non-wrapper) from the sections hash.
      #
      # @param sections [Hash] section mapping
      # @yield [Hash] leaf section definition
      # @return [void]
      def each_leaf_section(sections)
        sections.each_value do |section_def|
          if section_def.key?(:static)
            yield section_def
          else
            section_def.each_value { |sub_def| yield sub_def }
          end
        end
      end

      # Returns a human-readable label for the resource type.
      #
      # @param type [Symbol] :vm or :container
      # @return [String] "VM" or "Container"
      def type_label(type)
        type == :container ? "Container" : "VM"
      end
    end
  end
end
