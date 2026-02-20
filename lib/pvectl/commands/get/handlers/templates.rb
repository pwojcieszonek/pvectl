# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing templates (both VM and container).
        #
        # Queries both VM and Container repositories, filters by template? == true,
        # and merges into a single list. Supports --type flag for filtering by
        # resource type (vm/ct/qemu/lxc).
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("templates")
        #   templates = handler.list(type_filter: "vm")
        #
        # @see Pvectl::Repositories::Vm VM repository
        # @see Pvectl::Repositories::Container Container repository
        # @see Pvectl::Presenters::Template Template presenter
        #
        class Templates
          include ResourceHandler

          # Type filter mapping — normalizes user input to API type values.
          TYPE_MAP = {
            "vm" => "qemu",
            "qemu" => "qemu",
            "ct" => "lxc",
            "container" => "lxc",
            "lxc" => "lxc"
          }.freeze

          # Sort field mappings for template listing.
          SORT_FIELDS = {
            "name" => ->(t) { t.name || "" },
            "node" => ->(t) { t.node || "" },
            "type" => ->(t) { t.type || "" },
            "disk" => ->(t) { -(t.maxdisk || 0) }
          }.freeze

          # Creates handler with optional repositories for dependency injection.
          #
          # @param vm_repository [Repositories::Vm, nil] VM repository
          # @param container_repository [Repositories::Container, nil] Container repository
          def initialize(vm_repository: nil, container_repository: nil)
            @vm_repository = vm_repository
            @container_repository = container_repository
          end

          # Lists templates with optional filtering.
          #
          # @param node [String, nil] filter by node name
          # @param type_filter [String, nil] filter by type (vm, ct, qemu, lxc)
          # @param sort [String, nil] sort field
          # @param name [String, nil] unused, interface compatibility
          # @raise [ArgumentError] if type_filter is not a recognized type
          # @return [Array<Models::Vm, Models::Container>] template models
          def list(node: nil, name: nil, type_filter: nil, sort: nil, **_options)
            validate_type_filter!(type_filter)

            templates = []

            unless skip_vms?(type_filter)
              vms = vm_repository.list(node: node)
              templates.concat(vms.select(&:template?))
            end

            unless skip_containers?(type_filter)
              containers = container_repository.list(node: node)
              templates.concat(containers.select(&:template?))
            end

            templates = apply_sort(templates, sort) if sort
            templates
          end

          # Returns presenter for templates.
          #
          # @return [Presenters::Template] template presenter
          def presenter
            Pvectl::Presenters::Template.new
          end

          private

          # Validates type_filter value against known types.
          #
          # @param type_filter [String, nil] type filter value
          # @raise [ArgumentError] if type_filter is not a recognized type
          # @return [void]
          def validate_type_filter!(type_filter)
            return if type_filter.nil?
            return if TYPE_MAP.key?(type_filter)

            valid_types = TYPE_MAP.keys.join(", ")
            raise ArgumentError, "Unknown type: #{type_filter}. Valid types: #{valid_types}"
          end

          # Returns VM repository, creating it if necessary.
          #
          # @return [Repositories::Vm]
          def vm_repository
            @vm_repository ||= build_vm_repository
          end

          # Returns Container repository, creating it if necessary.
          #
          # @return [Repositories::Container]
          def container_repository
            @container_repository ||= build_container_repository
          end

          # Builds VM repository with connection from config.
          #
          # @return [Repositories::Vm]
          def build_vm_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Vm.new(connection)
          end

          # Builds Container repository with connection from config.
          #
          # @return [Repositories::Container]
          def build_container_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Container.new(connection)
          end

          # Checks if VMs should be skipped based on type filter.
          #
          # @param type_filter [String, nil] type filter value
          # @return [Boolean]
          def skip_vms?(type_filter)
            return false if type_filter.nil?

            TYPE_MAP[type_filter] == "lxc"
          end

          # Checks if containers should be skipped based on type filter.
          #
          # @param type_filter [String, nil] type filter value
          # @return [Boolean]
          def skip_containers?(type_filter)
            return false if type_filter.nil?

            TYPE_MAP[type_filter] == "qemu"
          end

          # Applies sorting to templates collection.
          #
          # @param templates [Array] templates to sort
          # @param sort_field [String] field to sort by
          # @return [Array] sorted templates
          def apply_sort(templates, sort_field)
            sort_proc = SORT_FIELDS[sort_field.to_s]
            return templates unless sort_proc

            templates.sort_by(&sort_proc)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "templates",
  Pvectl::Commands::Get::Handlers::Templates,
  aliases: ["template"]
)
