# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing QEMU virtual machines.
        #
        # Implements ResourceHandler interface for the "vms" resource type.
        # Uses Repositories::Vm for data access and Presenters::Vm for formatting.
        #
        # Registered with ResourceRegistry on file load for both "vms" and "vm".
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("vms")
        #   vms = handler.list(node: "pve1")
        #   presenter = handler.presenter
        #
        # @see Pvectl::Commands::Get::ResourceHandler Handler interface
        # @see Pvectl::Repositories::Vm VM repository
        # @see Pvectl::Presenters::Vm VM presenter
        #
        class Vms
          include ResourceHandler

          # VMID validation pattern (1-999999999)
          VMID_PATTERN = /\A[1-9]\d{0,8}\z/

          # Sort field mappings.
          # Negative values for descending sort (higher values first).
          SORT_FIELDS = {
            "name" => ->(v) { v.name || "" },
            "node" => ->(v) { v.node || "" },
            "cpu" => ->(v) { -(v.cpu || 0) },
            "memory" => ->(v) { -(v.mem || 0) },
            "disk" => ->(v) { -(v.disk || 0) },
            "netin" => ->(v) { -(v.netin || 0) },
            "netout" => ->(v) { -(v.netout || 0) }
          }.freeze

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Vm, nil] repository (default: create new)
          def initialize(repository: nil)
            @repository = repository
          end

          # Lists VMs with optional filtering and sorting.
          #
          # @param node [String, nil] filter by node name
          # @param name [String, nil] filter by VM name
          # @param args [Array<String>] unused, for interface compatibility
          # @param storage [String, nil] unused, for interface compatibility
          # @param sort [String, nil] sort field (name, node, cpu, memory, disk, netin, netout)
          # @return [Array<Models::Vm>] collection of VM models
          def list(node: nil, name: nil, args: [], storage: nil, sort: nil, **_options)
            vms = repository.list(node: node)
            vms = vms.select { |vm| vm.name == name } if name
            vms = apply_sort(vms, sort) if sort
            vms
          end

          # Returns presenter for VMs.
          #
          # @return [Presenters::Vm] VM presenter instance
          def presenter
            Pvectl::Presenters::Vm.new
          end

          # Describes a single VM with comprehensive details.
          #
          # @param name [String] VMID as string (consistent with handler interface)
          # @param node [String, nil] unused, for API consistency
          # @return [Models::Vm] VM model with full details
          # @raise [ArgumentError] if VMID format is invalid
          # @raise [Pvectl::ResourceNotFoundError] if VM not found
          def describe(name:, node: nil, args: [], vmid: nil)
            raise ArgumentError, "Invalid VMID: must be positive integer (1-999999999)" unless valid_vmid?(name)

            vmid = name.to_i
            vm = repository.describe(vmid)
            raise Pvectl::ResourceNotFoundError, "VM not found: #{vmid}" if vm.nil?

            vm
          end

          private

          # Returns repository, creating it if necessary.
          #
          # @return [Repositories::Vm] VM repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Vm] configured VM repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Vm.new(connection)
          end

          # Applies sorting to VMs collection.
          #
          # @param vms [Array<Models::Vm>] VMs to sort
          # @param sort_field [String] field to sort by
          # @return [Array<Models::Vm>] sorted VMs
          def apply_sort(vms, sort_field)
            sort_proc = SORT_FIELDS[sort_field.to_s]
            return vms unless sort_proc

            vms.sort_by(&sort_proc)
          end

          # Validates VMID format.
          #
          # @param vmid [String, nil] VMID to validate
          # @return [Boolean] true if valid
          def valid_vmid?(vmid)
            return false if vmid.nil? || vmid.to_s.empty?

            vmid.to_s.match?(VMID_PATTERN)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "vms",
  Pvectl::Commands::Get::Handlers::Vms,
  aliases: ["vm"]
)
