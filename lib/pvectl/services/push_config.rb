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
      DEFAULT_TASK_TIMEOUT = 120

      # @param vm_repository [Repositories::Vm] VM repository
      # @param container_repository [Repositories::Container] container repository
      # @param task_repository [Repositories::Task, nil] task repository for tracking async operations
      def initialize(vm_repository:, container_repository:, task_repository: nil)
        @vm_repository = vm_repository
        @container_repository = container_repository
        @task_repository = task_repository
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

          # Collect all readonly keys from both sides and strip them.
          # Pull output may include readonly keys (digest, vmid, template, etc.)
          # which should be silently ignored by push. The API enforces readonly.
          all_flat = original_flat.merge(flat_from_manifest)
          readonly_keys = collect_readonly_keys(all_flat, type)
          comparable_original = original_flat.reject { |k, _| readonly_keys.include?(k) }
          comparable_manifest = flat_from_manifest.reject { |k, _| readonly_keys.include?(k) }

          diff = ConfigSerializer.diff(comparable_original, comparable_manifest)

          if diff[:changed].empty? && diff[:added].empty? && diff[:removed].empty?
            return { plans: [], errors: [], no_changes: true }
          end

          update_result = build_update_params(diff, current_config, type)

          plan = {
            action: :update,
            type: type,
            vmid: vmid,
            node: resource.node,
            diff: diff,
            params: update_result[:params],
            resize_ops: update_result[:resize_ops]
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
      # Tracks async task completion for resize and create operations.
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
              config_params = plan[:params].reject { |k, _| k == :digest }
              unless config_params.empty?
                repo.update(plan[:vmid], plan[:node], plan[:params])
              end

              resize_errors = apply_resize_ops(repo, plan)
              if resize_errors.any?
                resize_errors.each { |e| errors << "Error resizing #{type_label(plan[:type])} #{plan[:vmid]}: #{e}" }
                results << { action: :update, vmid: plan[:vmid], type: plan[:type], success: false, error: resize_errors.join("; ") }
              else
                results << { action: :update, vmid: plan[:vmid], type: plan[:type], success: true }
              end
            elsif plan[:action] == :create
              upid = repo.create(plan[:node], plan[:vmid], plan[:params])
              task = wait_for_task(upid)

              if task&.failed?
                error_msg = task.exitstatus
                errors << "Error creating #{type_label(plan[:type])} #{plan[:vmid]}: #{error_msg}"
                results << { action: :create, vmid: plan[:vmid], type: plan[:type], success: false, error: error_msg }
              else
                results << {
                  action: :create, vmid: plan[:vmid], type: plan[:type], success: true,
                  auto_id: plan[:auto_id], source_path: plan[:source_path]
                }
              end
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
      # Extracts disk resize operations into a separate list (Proxmox requires
      # the dedicated /resize endpoint for actual disk size changes).
      #
      # @param diff [Hash] diff from ConfigSerializer.diff
      # @param original_config [Hash] original flat config from API
      # @param type [Symbol] resource type (:vm or :container)
      # @return [Hash] { params: Hash, resize_ops: Array<Hash> }
      def build_update_params(diff, original_config, type)
        params = {}
        resize_ops = []

        diff[:changed].each do |key, (old_val, new_val)|
          if vm_disk_key?(key) && type == :vm
            old_size = extract_disk_size(old_val.to_s)
            new_size = extract_disk_size(new_val.to_s)

            if old_size && new_size && old_size != new_size
              resize_ops << { disk: key.to_s, size: new_size }
              # Check if other disk options changed besides size
              if disk_value_without_size(old_val.to_s) != disk_value_without_size(new_val.to_s)
                params[key] = replace_disk_size(new_val.to_s, old_size)
              end
              next
            end
          end
          params[key] = new_val
        end

        diff[:added].each { |key, val| params[key] = val }
        unless diff[:removed].empty?
          params[:delete] = diff[:removed].map(&:to_s).join(",")
        end
        params[:digest] = original_config[:digest] if original_config[:digest]

        { params: params, resize_ops: resize_ops }
      end

      # Applies disk resize operations from a plan.
      # Waits for each resize task to complete and returns errors.
      #
      # @param repo [Repositories::Vm, Repositories::Container] repository
      # @param plan [Hash] update plan with optional :resize_ops
      # @return [Array<String>] list of error messages (empty if all succeeded)
      def apply_resize_ops(repo, plan)
        errors = []
        return errors unless plan[:resize_ops]&.any?

        plan[:resize_ops].each do |op|
          upid = repo.resize(plan[:vmid], plan[:node], disk: op[:disk], size: op[:size])
          task = wait_for_task(upid)
          if task&.failed?
            errors << "#{op[:disk]}: #{task.exitstatus}"
          end
        end

        errors
      end

      # Waits for an async Proxmox task to complete.
      # Returns nil when task_repository is not configured (fire-and-forget mode).
      #
      # @param upid [String, nil] task UPID
      # @return [Models::Task, nil] completed task or nil
      def wait_for_task(upid)
        return nil unless @task_repository && upid

        @task_repository.wait(upid, timeout: DEFAULT_TASK_TIMEOUT)
      end

      # Checks if a key is a VM disk key (scsi, ide, virtio, sata, efidisk, tpmstate).
      #
      # @param key [Symbol, String] config key
      # @return [Boolean]
      def vm_disk_key?(key)
        ConfigSerializer::VM_COMPLEX_KEYS[:disk][:pattern].match?(key.to_s)
      end

      # Extracts the size value from a Proxmox disk config string.
      #
      # @param disk_value [String] e.g. "local-lvm:vm-100-disk-0,size=8G,iothread=1"
      # @return [String, nil] size value or nil if not found
      def extract_disk_size(disk_value)
        match = disk_value.match(/(?:^|,)size=([^,]+)/)
        match ? match[1] : nil
      end

      # Returns a disk config string with the size= part removed.
      #
      # @param value [String] disk config string
      # @return [String] string without size= component
      def disk_value_without_size(value)
        value.split(",").reject { |p| p.strip.start_with?("size=") }.join(",")
      end

      # Replaces the size value in a disk config string.
      #
      # @param value [String] disk config string
      # @param size [String] new size value
      # @return [String] string with replaced size
      def replace_disk_size(value, size)
        value.split(",").map { |p| p.strip.start_with?("size=") ? "size=#{size}" : p }.join(",")
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
