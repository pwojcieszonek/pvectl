# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates pulling resource configurations from the cluster
    # and converting them to YAML manifests.
    #
    # @example Pull a single VM
    #   service = PullConfig.new(vm_repository: vm_repo, container_repository: ct_repo)
    #   result = service.execute(type: :vm, ids: [100])
    #   result[:manifests].each { |m| puts m[:yaml] }
    class PullConfig
      # @param vm_repository [Repositories::Vm] VM repository
      # @param container_repository [Repositories::Container] container repository
      def initialize(vm_repository:, container_repository:)
        @vm_repository = vm_repository
        @container_repository = container_repository
      end

      # Executes the pull operation.
      #
      # @param type [Symbol] :vm or :container
      # @param ids [Array<Integer>] specific resource IDs (optional)
      # @param all [Boolean] pull all resources
      # @param node [String, nil] limit to specific node
      # @param selector [Object, nil] selector for filtering
      # @return [Hash] { manifests: Array<Hash>, errors: Array<String> }
      def execute(type:, ids: [], all: false, node: nil, selector: nil)
        repo = repository_for(type)
        manifests = []
        errors = []

        if all || selector
          resources = repo.list(node: node)
          resources = selector.apply(resources) if selector
          resources.reject!(&:template?)
        else
          resources = ids.filter_map do |id|
            resource = repo.get(id.to_i)
            unless resource
              errors << "#{type_label(type)} #{id} not found"
              nil
            else
              resource
            end
          end
        end

        resources.each do |resource|
          result = pull_single(repo, resource, type)
          if result[:error]
            errors << result[:error]
          else
            manifests << result
          end
        end

        { manifests: manifests, errors: errors }
      end

      private

      def repository_for(type)
        type == :container ? @container_repository : @vm_repository
      end

      def pull_single(repo, resource, type)
        config = repo.fetch_config(resource.node, resource.vmid)
        nested = ConfigSerializer.to_nested(config, type: type)
        metadata = build_metadata(resource, type)
        yaml = ManifestSerializer.to_yaml(nested, type: type, metadata: metadata)

        { metadata: metadata, yaml: yaml, vmid: resource.vmid }
      rescue StandardError => e
        { error: "Error pulling #{type_label(type)} #{resource.vmid}: #{e.message}" }
      end

      def build_metadata(resource, type)
        name = type == :container ? resource.hostname : resource.name
        {
          vmid: resource.vmid,
          name: name,
          node: resource.node,
          status: resource.status,
          tags: resource.tags
        }.compact
      end

      def type_label(type)
        type == :container ? "Container" : "VM"
      end
    end
  end
end
