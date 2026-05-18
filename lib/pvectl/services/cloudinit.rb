# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates cloud-init operations on VMs.
    #
    # Provides three operations:
    # - +regenerate+ — rebuild the cloud-init ISO from current config
    # - +pending+    — list configuration changes not yet applied
    # - +dump+       — retrieve the auto-generated cloud-init YAML
    #
    # Operations are VM-only — LXC containers do not expose cloud-init
    # endpoints. When the +vmid+ resolves to a non-QEMU resource, the
    # service raises +Pvectl::ResourceNotFoundError+.
    #
    # @example Regenerate ISO for a VM
    #   service = Cloudinit.new(vm_repository: vm_repo, resource_resolver: resolver)
    #   service.regenerate(100)
    #
    # @example Dump generated user-data YAML
    #   yaml = service.dump(100, "user")
    #
    class Cloudinit
      # Cloud-init config types supported by the +dump+ operation.
      VALID_DUMP_TYPES = %w[user network meta].freeze

      # Creates a new Cloudinit service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param resource_resolver [Utils::ResourceResolver] resolver for VMID -> node
      def initialize(vm_repository:, resource_resolver:)
        @vm_repository = vm_repository
        @resolver = resource_resolver
      end

      # Regenerates the cloud-init ISO for the given VM.
      #
      # @param vmid [Integer] VM identifier
      # @param node [String, nil] explicit node name (skips resolver)
      # @return [Hash{Symbol => untyped}] +{ vmid: Integer, node: String }+
      # @raise [Pvectl::ResourceNotFoundError] when VM does not exist or is not QEMU
      def regenerate(vmid, node: nil)
        node ||= resolve_node!(vmid)
        @vm_repository.cloudinit_regenerate(node, vmid)
        { vmid: vmid, node: node }
      end

      # Returns pending cloud-init configuration changes.
      #
      # @param vmid [Integer] VM identifier
      # @param node [String, nil] explicit node name (skips resolver)
      # @return [Array<Hash{Symbol => untyped}>] pending entries
      # @raise [Pvectl::ResourceNotFoundError] when VM does not exist or is not QEMU
      def pending(vmid, node: nil)
        node ||= resolve_node!(vmid)
        @vm_repository.cloudinit_pending(node, vmid)
      end

      # Dumps the auto-generated cloud-init configuration.
      #
      # @param vmid [Integer] VM identifier
      # @param type [String] one of +"user"+, +"network"+, +"meta"+
      # @param node [String, nil] explicit node name (skips resolver)
      # @return [String] raw cloud-init YAML/text
      # @raise [ArgumentError] when +type+ is not a valid dump type
      # @raise [Pvectl::ResourceNotFoundError] when VM does not exist or is not QEMU
      def dump(vmid, type, node: nil)
        unless VALID_DUMP_TYPES.include?(type)
          raise ArgumentError, "Invalid cloud-init dump type: #{type.inspect} " \
                               "(valid: #{VALID_DUMP_TYPES.join(', ')})"
        end

        node ||= resolve_node!(vmid)
        @vm_repository.cloudinit_dump(node, vmid, type)
      end

      private

      # Resolves a VMID to its node, ensuring the resource is a QEMU VM.
      #
      # @param vmid [Integer] VM identifier
      # @return [String] node name
      # @raise [Pvectl::ResourceNotFoundError] when not found or not a VM
      def resolve_node!(vmid)
        resolved = @resolver.resolve(vmid)
        raise Pvectl::ResourceNotFoundError, "VM #{vmid} not found" if resolved.nil?

        unless resolved[:type] == :qemu
          raise Pvectl::ResourceNotFoundError, "Resource #{vmid} is not a VM (cloud-init is VM-only)"
        end

        resolved[:node]
      end
    end
  end
end
