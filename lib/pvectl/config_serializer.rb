# frozen_string_literal: true

require "yaml"

module Pvectl
  # Converts flat Proxmox config hashes into nested, section-grouped YAML
  # and back. Used by the `edit` command to present VM/container configuration
  # in a human-friendly, structured format.
  #
  # All methods are class-level; no instance state is needed.
  #
  # @example Round-trip conversion
  #   yaml = ConfigSerializer.to_yaml(flat_config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })
  #   flat  = ConfigSerializer.from_yaml(yaml, type: :vm)
  #
  module ConfigSerializer
    # Section mappings for QEMU VMs.
    # Each section maps to an array of static keys and an array of dynamic key patterns.
    # Keys marked as read-only are listed separately.
    # Sections without a :static key are "wrapper" sections containing named subsections.
    VM_SECTIONS = {
      general: {
        static: %i[vmid name description tags template lock digest],
        dynamic: [],
        readonly: %i[vmid template lock digest]
      },
      hardware: {
        cpu: {
          static: %i[cores sockets cpu cpulimit cpuunits numa affinity],
          dynamic: [/\Anuma\d+\z/],
          readonly: []
        },
        memory: {
          static: %i[memory balloon shares hugepages keephugepages],
          dynamic: [],
          readonly: []
        },
        disks: {
          static: %i[efidisk0 tpmstate0],
          dynamic: [/\Ascsi\d+\z/, /\Aide\d+\z/, /\Avirtio\d+\z/, /\Asata\d+\z/, /\Aunused\d+\z/],
          readonly: [/\Aunused\d+\z/]
        },
        network: {
          static: [],
          dynamic: [/\Anet\d+\z/],
          readonly: []
        },
        display: {
          static: %i[vga spice_enhancements keyboard],
          dynamic: [],
          readonly: []
        },
        devices: {
          static: %i[audio0 rng0 ivshmem],
          dynamic: [/\Aserial\d+\z/, /\Aparallel\d+\z/, /\Ausb\d+\z/, /\Ahostpci\d+\z/],
          readonly: []
        }
      },
      cloud_init: {
        static: %i[citype cicustom ciuser cipassword ciupgrade nameserver searchdomain sshkeys],
        dynamic: [/\Aipconfig\d+\z/],
        readonly: []
      },
      options: {
        static: %i[onboot startup boot bootdisk bios machine arch ostype scsihw kvm agent hotplug
                   tablet args hookscript smbios1 localtime reboot freeze protection],
        dynamic: [],
        readonly: []
      },
      migration: {
        static: %i[migrate_downtime migrate_speed],
        dynamic: [],
        readonly: []
      },
      security: {
        static: %i[amd_sev intel_tdx],
        dynamic: [],
        readonly: []
      }
    }.freeze

    # Section mappings for LXC containers.
    # Sections without a :static key are "wrapper" sections containing named subsections.
    CONTAINER_SECTIONS = {
      general: {
        static: %i[vmid hostname description tags template lock digest],
        dynamic: [],
        readonly: %i[vmid template lock digest]
      },
      resources: {
        cpu: {
          static: %i[cores cpulimit cpuunits],
          dynamic: [],
          readonly: []
        },
        memory: {
          static: %i[memory swap],
          dynamic: [],
          readonly: []
        },
        disks: {
          static: %i[rootfs],
          dynamic: [/\Amp\d+\z/, /\Adev\d+\z/, /\Aunused\d+\z/],
          readonly: [/\Aunused\d+\z/]
        }
      },
      network: {
        static: [],
        dynamic: [/\Anet\d+\z/],
        readonly: []
      },
      dns: {
        static: %i[nameserver searchdomain],
        dynamic: [],
        readonly: []
      },
      options: {
        static: %i[onboot startup ostype arch unprivileged features hookscript protection
                   debug timezone entrypoint env],
        dynamic: [],
        readonly: %i[arch]
      },
      console: {
        static: %i[console cmode tty],
        dynamic: [],
        readonly: []
      }
    }.freeze

    # Characters that require quoting in YAML output.
    YAML_SPECIAL_CHARS = %w[: # [ ] { } > | * & ! % @ ` , ? -].freeze

    # Default values for QEMU Guest Agent properties (from Proxmox API docs).
    # Used to fill in missing sub-properties when parsing agent config strings.
    AGENT_DEFAULTS = {
      enabled: "0",
      fstrim_cloned_disks: "0",
      :"freeze-fs-on-backup" => "1",
      type: "virtio"
    }.freeze

    # Default values for VM config keys that Proxmox API omits when using defaults.
    # These are injected by to_nested to produce complete manifests.
    # Values sourced from Proxmox API docs (nodes-qemu-config.json).
    VM_DEFAULTS = {
      hotplug: "network,disk,usb"
    }.freeze

    # Top-level VM config keys that are boolean (0/1 in Proxmox API).
    VM_BOOLEAN_KEYS = %i[onboot kvm tablet reboot freeze localtime protection numa keephugepages].freeze

    # Top-level container config keys that are boolean (0/1 in Proxmox API).
    CT_BOOLEAN_KEYS = %i[onboot unprivileged protection debug console].freeze

    # All possible hotplug capabilities for QEMU VMs.
    HOTPLUG_CAPABILITIES = %i[network disk usb cpu memory cloudinit].freeze

    # Sub-keys within agent config that are boolean (0/1 strings).
    AGENT_BOOLEAN_SUBKEYS = [:enabled, :fstrim_cloned_disks, :"freeze-fs-on-backup"].freeze

    # Sub-keys within VM network config that are boolean (0/1 strings).
    NET_BOOLEAN_SUBKEYS = %i[firewall link_down].freeze

    # Sub-keys within disk config that are boolean (0/1 strings).
    DISK_BOOLEAN_SUBKEYS = %i[iothread backup replicate ssd ro].freeze

    # Complex key mappings for QEMU VMs.
    # Each entry maps a category to a regex pattern and parser/serializer method names.
    # Used by to_nested/from_nested for bidirectional conversion of Proxmox config strings.
    VM_COMPLEX_KEYS = {
      net: { pattern: /\Anet\d+\z/, parser: :parse_vm_net_value, serializer: :serialize_vm_net_value },
      disk: { pattern: /\A(?:scsi|ide|virtio|sata|efidisk|tpmstate)\d*\z/, parser: :parse_disk_value,
              serializer: :serialize_disk_value },
      unused: { pattern: /\Aunused\d+\z/, parser: :parse_disk_value, serializer: :serialize_disk_value },
      boot: { pattern: /\Aboot\z/, parser: :parse_boot_value, serializer: :serialize_boot_value },
      agent: { pattern: /\Aagent\z/, parser: :parse_agent_value, serializer: :serialize_agent_value },
      hotplug: { pattern: /\Ahotplug\z/, parser: :parse_hotplug_value, serializer: :serialize_hotplug_value },
      startup: { pattern: /\Astartup\z/, parser: :parse_kv_value, serializer: :serialize_kv_value },
      ipconfig: { pattern: /\Aipconfig\d+\z/, parser: :parse_kv_value, serializer: :serialize_kv_value },
      smbios1: { pattern: /\Asmbios1\z/, parser: :parse_kv_value, serializer: :serialize_kv_value },
      numa_dev: { pattern: /\Anuma\d+\z/, parser: :parse_kv_value, serializer: :serialize_kv_value }
    }.freeze

    # Complex key mappings for LXC containers.
    CT_COMPLEX_KEYS = {
      net: { pattern: /\Anet\d+\z/, parser: :parse_kv_value, serializer: :serialize_kv_value },
      rootfs: { pattern: /\Arootfs\z/, parser: :parse_disk_value, serializer: :serialize_disk_value },
      mp: { pattern: /\Amp\d+\z/, parser: :parse_disk_value, serializer: :serialize_disk_value },
      dev: { pattern: /\Adev\d+\z/, parser: :parse_disk_value, serializer: :serialize_disk_value },
      unused: { pattern: /\Aunused\d+\z/, parser: :parse_disk_value, serializer: :serialize_disk_value },
      startup: { pattern: /\Astartup\z/, parser: :parse_kv_value, serializer: :serialize_kv_value },
      features: { pattern: /\Afeatures\z/, parser: :parse_kv_value, serializer: :serialize_kv_value }
    }.freeze

    class << self
      # Converts a flat Proxmox config hash into a nested, section-grouped YAML string
      # with header comments and read-only markers.
      #
      # @param flat_config [Hash] flat config hash with symbol keys
      # @param type [Symbol] resource type (:vm or :container)
      # @param resource [Hash] resource metadata (vmid, node, status) for header
      # @return [String] formatted YAML string with comments
      #
      # @example
      #   ConfigSerializer.to_yaml({ vmid: 100, cores: 4 }, type: :vm,
      #     resource: { vmid: 100, node: "pve1", status: "running" })
      def to_yaml(flat_config, type:, resource: {})
        sections = sections_for(type)
        lines = []

        lines << header_comment(type, resource)
        lines << ""

        sections.each do |section_name, section_def|
          if wrapper_section?(section_def)
            render_wrapper_section(lines, section_name, section_def, flat_config)
          else
            render_leaf_section(lines, section_name, section_def, flat_config)
          end
        end

        lines.join("\n")
      end

      # Parses a YAML string back into a flat config hash with symbol keys.
      # Strips comment lines before parsing, then flattens nested sections.
      #
      # @param yaml_string [String] YAML string (potentially with comments)
      # @param type [Symbol] resource type (:vm or :container) - reserved for future use
      # @return [Hash{Symbol => Object}] flat config hash
      #
      # @example
      #   ConfigSerializer.from_yaml("general:\n  name: web\ncpu:\n  cores: 4", type: :vm)
      #   #=> { name: "web", cores: 4 }
      def from_yaml(yaml_string, type:)
        cleaned = strip_comments(yaml_string)
        return {} if cleaned.strip.empty?

        begin
          parsed = YAML.safe_load(cleaned)
        rescue Psych::SyntaxError
          return {}
        end
        return {} unless parsed.is_a?(Hash)

        flatten_sections(parsed)
      end

      # Validates a YAML string against known section/key mappings.
      #
      # @param yaml_string [String] YAML string to validate
      # @param type [Symbol] resource type (:vm or :container)
      # @return [Array<String>] list of error messages (empty if valid)
      #
      # @example
      #   ConfigSerializer.validate("foo:\n  bar: 1", type: :vm)
      #   #=> ["Unknown section 'foo'"]
      def validate(yaml_string, type:)
        errors = []
        cleaned = strip_comments(yaml_string)

        begin
          parsed = YAML.safe_load(cleaned)
        rescue Psych::SyntaxError => e
          return ["YAML syntax error: #{e.message}"]
        end

        return errors unless parsed.is_a?(Hash)

        sections = sections_for(type)

        parsed.each do |section_name, section_values|
          unless sections.key?(section_name.to_sym)
            errors << "Unknown section '#{section_name}'"
            next
          end

          next unless section_values.is_a?(Hash)

          section_def = sections[section_name.to_sym]

          if wrapper_section?(section_def)
            validate_wrapper_section(errors, section_name, section_def, section_values)
          else
            section_values.each_key do |key|
              unless key_in_section?(key.to_sym, section_def)
                errors << "Unknown key '#{key}' in section '#{section_name}'"
              end
            end
          end
        end

        errors
      end

      # Checks if any read-only fields were modified between original and edited configs.
      #
      # @param original_flat [Hash{Symbol => Object}] original flat config
      # @param edited_flat [Hash{Symbol => Object}] edited flat config
      # @param type [Symbol] resource type (:vm or :container)
      # @return [Array<String>] list of read-only field names that were changed
      #
      # @example
      #   ConfigSerializer.readonly_violations({ vmid: 100 }, { vmid: 999 }, type: :vm)
      #   #=> ["vmid"]
      def readonly_violations(original_flat, edited_flat, type:)
        sections = sections_for(type)
        readonly_keys = collect_readonly_keys(original_flat.keys | edited_flat.keys, sections)

        readonly_keys.select { |key| original_flat[key] != edited_flat[key] }
                     .map(&:to_s)
      end

      # Computes the diff between two flat config hashes.
      #
      # @param original [Hash{Symbol => Object}] original config
      # @param edited [Hash{Symbol => Object}] edited config
      # @return [Hash{Symbol => Hash, Array}] diff with :changed, :added, :removed
      #
      # @example
      #   ConfigSerializer.diff({ cores: 4 }, { cores: 8, balloon: 2048 })
      #   #=> { changed: { cores: [4, 8] }, added: { balloon: 2048 }, removed: [] }
      def diff(original, edited)
        changed = {}
        added = {}
        removed = []

        all_keys = original.keys | edited.keys

        all_keys.each do |key|
          if original.key?(key) && edited.key?(key)
            changed[key] = [original[key], edited[key]] if original[key] != edited[key]
          elsif edited.key?(key)
            added[key] = edited[key]
          else
            removed << key
          end
        end

        { changed: changed, added: added, removed: removed }
      end

      # Formats a diff hash for colored terminal display.
      #
      # @param diff_hash [Hash] diff hash from {.diff}
      # @return [String] ANSI-colored diff output
      #
      # @example
      #   ConfigSerializer.format_diff(changed: { cores: [4, 8] }, added: {}, removed: [])
      #   #=> "  ~ cores: 4 -> 8"  (yellow)
      def format_diff(diff_hash)
        lines = []

        diff_hash[:changed].each do |key, (old_val, new_val)|
          lines << "\e[33m  ~ #{key}: #{old_val} -> #{new_val}\e[0m"
        end

        diff_hash[:added].each do |key, value|
          lines << "\e[32m  + #{key}: #{value}\e[0m"
        end

        diff_hash[:removed].each do |key|
          lines << "\e[31m  - #{key}\e[0m"
        end

        lines.join("\n")
      end

      # Converts a flat Proxmox config hash into a nested Hash with parsed complex values.
      # Used by ManifestSerializer to build the spec section of YAML manifests.
      #
      # @param flat_config [Hash{Symbol => Object}] flat config hash with symbol keys
      # @param type [Symbol] resource type (:vm or :container)
      # @return [Hash{Symbol => Hash}] nested hash matching section structure
      #
      # @example
      #   ConfigSerializer.to_nested({ cores: 4, net0: "virtio=AA:BB,bridge=vmbr0" }, type: :vm)
      #   #=> { hardware: { cpu: { cores: 4 }, network: { net0: { model: "virtio", mac: "AA:BB", bridge: "vmbr0" } } } }
      def to_nested(flat_config, type:)
        sections = sections_for(type)
        config_with_defaults = inject_defaults(flat_config, type)
        result = {}

        sections.each do |section_name, section_def|
          if wrapper_section?(section_def)
            wrapper = {}
            section_def.each do |sub_name, sub_def|
              sub_hash = build_nested_section(config_with_defaults, sub_def, type)
              wrapper[sub_name] = sub_hash unless sub_hash.empty?
            end
            result[section_name] = wrapper unless wrapper.empty?
          else
            section_hash = build_nested_section(config_with_defaults, section_def, type)
            result[section_name] = section_hash unless section_hash.empty?
          end
        end

        result
      end

      # Converts a nested Hash (from manifest spec) back into a flat Proxmox config hash.
      # Serializes parsed complex values back to Proxmox string format.
      #
      # @param nested [Hash{Symbol => Hash}] nested hash from to_nested
      # @param type [Symbol] resource type (:vm or :container)
      # @return [Hash{Symbol => Object}] flat config hash
      #
      # @example
      #   nested = { hardware: { cpu: { cores: 4 } } }
      #   ConfigSerializer.from_nested(nested, type: :vm)
      #   #=> { cores: 4 }
      def from_nested(nested, type:)
        sections = sections_for(type)
        result = {}

        nested.each do |section_name, section_value|
          next unless section_value.is_a?(Hash)

          section_def = sections[section_name]
          next unless section_def

          if wrapper_section?(section_def)
            section_value.each do |_sub_name, sub_values|
              next unless sub_values.is_a?(Hash)

              flatten_nested_section(sub_values, type, result)
            end
          else
            flatten_nested_section(section_value, type, result)
          end
        end

        inject_defaults(result, type)
      end

      private

      # Returns the section mappings for the given resource type.
      #
      # @param type [Symbol] :vm or :container
      # @return [Hash] section mapping hash
      def sections_for(type)
        type == :container ? CONTAINER_SECTIONS : VM_SECTIONS
      end

      # Generates the YAML header comment block.
      #
      # @param type [Symbol] :vm or :container
      # @param resource [Hash] resource metadata
      # @return [String] multi-line comment string
      def header_comment(type, resource)
        label = type == :container ? "Container" : "VM"
        vmid = resource[:vmid] || resource[:ctid]
        node = resource[:node]
        status = resource[:status]

        <<~COMMENT.chomp
          # Editing #{label} #{vmid} on node #{node} (status: #{status})
          # Fields marked "# read-only" cannot be changed.
          # Save and close to apply changes. Empty file to cancel.
        COMMENT
      end

      # Collects config keys that belong to a given section definition.
      #
      # @param config [Hash] flat config hash
      # @param section_def [Hash] section definition with :static and :dynamic
      # @return [Array<Symbol>] matching keys in stable order
      def keys_for_section(config, section_def)
        config.keys.select { |key| key_in_section?(key, section_def) }
      end

      # Checks if a key matches a section definition (static or dynamic).
      #
      # @param key [Symbol] config key
      # @param section_def [Hash] section definition
      # @return [Boolean]
      def key_in_section?(key, section_def)
        return true if section_def[:static].include?(key.to_sym)

        key_str = key.to_s
        section_def[:dynamic].any? { |pattern| pattern.match?(key_str) }
      end

      # Checks if a key is read-only within its section definition.
      #
      # @param key [Symbol] config key
      # @param section_def [Hash] section definition
      # @return [Boolean]
      def readonly_key?(key, section_def)
        readonly = section_def[:readonly]
        return true if readonly.include?(key.to_sym)

        key_str = key.to_s
        readonly.select { |r| r.is_a?(Regexp) }.any? { |pattern| pattern.match?(key_str) }
      end

      # Collects all read-only keys from the given key set.
      # Recurses into wrapper sections to check subsection definitions.
      #
      # @param keys [Array<Symbol>] all keys to check
      # @param sections [Hash] section mapping
      # @return [Array<Symbol>] read-only keys
      def collect_readonly_keys(keys, sections)
        leaf_defs = each_leaf_section(sections)
        keys.select do |key|
          leaf_defs.any? do |section_def|
            key_in_section?(key, section_def) && readonly_key?(key, section_def)
          end
        end
      end

      # Formats a value for YAML output, quoting strings with special characters.
      #
      # @param value [Object] value to format
      # @return [String] formatted value
      def format_yaml_value(value)
        return value.inspect if value.nil?

        case value
        when String
          needs_quoting?(value) ? value.inspect : value
        when TrueClass, FalseClass, Numeric
          value.to_s
        else
          value.to_s
        end
      end

      # Checks if a string value requires YAML quoting.
      #
      # @param value [String] value to check
      # @return [Boolean]
      def needs_quoting?(value)
        return true if value.empty?

        YAML_SPECIAL_CHARS.any? { |char| value.include?(char) }
      end

      # Strips comment lines (lines starting with #) from YAML.
      # Preserves inline content but removes full-line comments.
      #
      # @param yaml_string [String] YAML with comments
      # @return [String] YAML without comment lines
      def strip_comments(yaml_string)
        yaml_string.lines.reject { |line| line.strip.start_with?("#") }.join
      end

      # Checks if a section definition is a wrapper (contains named subsections)
      # rather than a leaf section (contains :static/:dynamic/:readonly arrays).
      #
      # @param section_def [Hash] section definition
      # @return [Boolean] true if wrapper section
      def wrapper_section?(section_def)
        !section_def.key?(:static)
      end

      # Merges default values for keys that Proxmox API omits when using defaults.
      # Explicit values from the API response take precedence.
      #
      # @param flat_config [Hash] flat config from API
      # @param type [Symbol] :vm or :container
      # @return [Hash] config with defaults injected
      def inject_defaults(flat_config, type)
        defaults = type == :vm ? VM_DEFAULTS : {}
        return flat_config if defaults.empty?

        defaults.merge(flat_config)
      end

      # Converts a Proxmox 0/1 value to a Ruby boolean.
      #
      # @param value [Object] value to convert
      # @return [Boolean, Object] true/false for 0/1 values, original otherwise
      def to_boolean(value)
        case value
        when true, 1, "1" then true
        when false, 0, "0" then false
        else value
        end
      end

      # Converts a Ruby boolean back to a Proxmox integer (0/1).
      #
      # @param value [Object] value to convert
      # @return [Integer, Object] 0/1 for booleans, original otherwise
      def from_boolean(value)
        case value
        when true then 1
        when false then 0
        else value
        end
      end

      # Returns the set of boolean keys for the given resource type.
      #
      # @param type [Symbol] :vm or :container
      # @return [Array<Symbol>] boolean key names
      def boolean_keys_for(type)
        type == :container ? CT_BOOLEAN_KEYS : VM_BOOLEAN_KEYS
      end

      # Renders a leaf section (non-wrapper) into YAML output lines.
      #
      # @param lines [Array<String>] accumulator for output lines
      # @param section_name [Symbol] section name
      # @param section_def [Hash] leaf section definition
      # @param flat_config [Hash] flat config hash
      # @return [void]
      def render_leaf_section(lines, section_name, section_def, flat_config)
        section_keys = keys_for_section(flat_config, section_def)
        return if section_keys.empty?

        lines << "#{section_name}:"
        section_keys.each do |key|
          value = flat_config[key]
          formatted_value = format_yaml_value(value)
          readonly = readonly_key?(key, section_def) ? "  # read-only" : ""
          lines << "  #{key}: #{formatted_value}#{readonly}"
        end
        lines << ""
      end

      # Renders a wrapper section with subsections into YAML output lines.
      # Produces 3-level indentation: wrapper -> subsection -> key: value.
      #
      # @param lines [Array<String>] accumulator for output lines
      # @param wrapper_name [Symbol] wrapper section name
      # @param wrapper_def [Hash] wrapper definition containing subsection definitions
      # @param flat_config [Hash] flat config hash
      # @return [void]
      def render_wrapper_section(lines, wrapper_name, wrapper_def, flat_config)
        has_any_keys = wrapper_def.any? do |_sub_name, sub_def|
          keys_for_section(flat_config, sub_def).any?
        end
        return unless has_any_keys

        lines << "#{wrapper_name}:"
        wrapper_def.each do |sub_name, sub_def|
          sub_keys = keys_for_section(flat_config, sub_def)
          next if sub_keys.empty?

          lines << "  #{sub_name}:"
          sub_keys.each do |key|
            value = flat_config[key]
            formatted_value = format_yaml_value(value)
            readonly = readonly_key?(key, sub_def) ? "  # read-only" : ""
            lines << "    #{key}: #{formatted_value}#{readonly}"
          end
        end
        lines << ""
      end

      # Validates keys within a wrapper section's subsections.
      #
      # @param errors [Array<String>] accumulator for error messages
      # @param wrapper_name [String] wrapper section name
      # @param wrapper_def [Hash] wrapper definition with subsection definitions
      # @param wrapper_values [Hash] parsed YAML values for this wrapper
      # @return [void]
      def validate_wrapper_section(errors, wrapper_name, wrapper_def, wrapper_values)
        wrapper_values.each do |sub_name, sub_values|
          unless wrapper_def.key?(sub_name.to_sym)
            errors << "Unknown subsection '#{sub_name}' in section '#{wrapper_name}'"
            next
          end

          next unless sub_values.is_a?(Hash)

          sub_def = wrapper_def[sub_name.to_sym]
          sub_values.each_key do |key|
            unless key_in_section?(key.to_sym, sub_def)
              errors << "Unknown key '#{key}' in section '#{wrapper_name}/#{sub_name}'"
            end
          end
        end
      end

      # Yields all leaf section definitions from the sections hash,
      # recursing into wrapper sections.
      #
      # @param sections [Hash] section mapping (may contain wrappers)
      # @return [Array<Hash>] array of leaf section definitions
      def each_leaf_section(sections)
        result = []
        sections.each_value do |section_def|
          if wrapper_section?(section_def)
            section_def.each_value { |sub_def| result << sub_def }
          else
            result << section_def
          end
        end
        result
      end

      # Flattens a nested section hash to a flat symbol-keyed hash.
      # Handles both 2-level (section -> keys) and 3-level (wrapper -> subsection -> keys) nesting.
      #
      # @param parsed [Hash] nested hash from YAML.safe_load
      # @return [Hash{Symbol => Object}] flat hash
      def flatten_sections(parsed)
        result = {}
        parsed.each_value do |section_values|
          next unless section_values.is_a?(Hash)

          section_values.each do |key, value|
            if value.is_a?(Hash)
              # 3-level nesting: wrapper -> subsection -> key/value pairs
              value.each do |inner_key, inner_value|
                result[inner_key.to_sym] = inner_value
              end
            else
              result[key.to_sym] = value
            end
          end
        end
        result
      end

      # Returns the complex key mappings for the given resource type.
      #
      # @param type [Symbol] :vm or :container
      # @return [Hash] complex key mapping hash
      def complex_keys_for(type)
        type == :container ? CT_COMPLEX_KEYS : VM_COMPLEX_KEYS
      end

      # Finds the complex key spec (parser/serializer) for a given config key.
      # Returns nil if the key is a simple value (not a complex Proxmox string).
      #
      # @param key [Symbol] config key to look up
      # @param type [Symbol] :vm or :container
      # @return [Hash, nil] spec hash with :pattern, :parser, :serializer, or nil
      def find_complex_key(key, type)
        complex_keys_for(type).each_value do |spec|
          return spec if spec[:pattern].match?(key.to_s)
        end
        nil
      end

      # Builds a nested section hash from flat config, parsing complex values
      # and converting known boolean keys to Ruby booleans.
      #
      # @param flat_config [Hash] flat config hash
      # @param section_def [Hash] section definition with :static and :dynamic
      # @param type [Symbol] :vm or :container
      # @return [Hash{Symbol => Object}] section hash with parsed complex values
      def build_nested_section(flat_config, section_def, type)
        bool_keys = boolean_keys_for(type)
        result = {}
        keys_for_section(flat_config, section_def).each do |key|
          value = flat_config[key]
          complex = find_complex_key(key, type)
          result[key] = if complex && value.is_a?(String)
                          parsed = if complex[:default_key]
                                     send(complex[:parser], value, default_key: complex[:default_key])
                                   else
                                     send(complex[:parser], value)
                                   end
                          normalize_cloudinit_volume(parsed)
                        elsif bool_keys.include?(key)
                          to_boolean(value)
                        else
                          value
                        end
        end
        result
      end

      # Flattens a nested section hash back to flat config, serializing complex values
      # and converting Ruby booleans back to Proxmox integers (0/1).
      #
      # @param section_hash [Hash] nested section with potentially parsed complex values
      # @param type [Symbol] :vm or :container
      # @param result [Hash] accumulator for flat config
      # @return [void]
      def flatten_nested_section(section_hash, type, result)
        bool_keys = boolean_keys_for(type)
        section_hash.each do |key, value|
          complex = find_complex_key(key, type)
          result[key] = if complex && value.is_a?(Hash)
                          send(complex[:serializer], value)
                        elsif bool_keys.include?(key) && (value.is_a?(TrueClass) || value.is_a?(FalseClass))
                          from_boolean(value)
                        else
                          value
                        end
        end
      end

      # Parses a VM network config string into a structured hash.
      # Format: "model=MAC,key=value,..."  (e.g., "virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0,firewall=1")
      # Boolean sub-keys (firewall, link_down) are converted to Ruby booleans.
      #
      # @param string [String] Proxmox VM network config value
      # @return [Hash{Symbol => Object}] parsed network config
      def parse_vm_net_value(string)
        parts = string.split(",")
        first = parts.shift.strip
        model, mac = first.split("=", 2)
        result = { model: model }
        result[:mac] = mac if mac
        parts.each do |part|
          k, v = part.strip.split("=", 2)
          sym = k.to_sym
          result[sym] = NET_BOOLEAN_SUBKEYS.include?(sym) ? to_boolean(v) : v
        end
        result
      end

      # Serializes a VM network hash back to Proxmox config string format.
      # Converts Ruby booleans back to 0/1 strings.
      #
      # @param hash [Hash{Symbol => Object}] parsed network config
      # @return [String] Proxmox VM network config string
      def serialize_vm_net_value(hash)
        parts = []
        model = hash[:model] || "virtio"
        mac = hash[:mac]
        parts << (mac ? "#{model}=#{mac}" : model)
        hash.except(:model, :mac).each do |k, v|
          v = from_boolean(v) if NET_BOOLEAN_SUBKEYS.include?(k)
          parts << "#{k}=#{v}"
        end
        parts.join(",")
      end

      # Normalizes cloud-init volume names for manifest portability.
      # Strips the VM-specific prefix (e.g., "vm-100-cloudinit" → "cloudinit")
      # so that pulled manifests can be reused for creating new VMs.
      #
      # @param parsed [Hash, Object] parsed value from a complex key parser
      # @return [Hash, Object] value with normalized cloud-init volume (if applicable)
      def normalize_cloudinit_volume(parsed)
        if parsed.is_a?(Hash) && parsed[:volume]&.include?("cloudinit")
          parsed[:volume] = "cloudinit"
        end
        parsed
      end

      # Parses a disk config string into a structured hash.
      # Format: "storage:volume,key=value,..."  (e.g., "local-lvm:vm-100-disk-0,size=32G,iothread=1")
      # Boolean sub-keys (iothread, backup, replicate, ssd, ro) are converted to Ruby booleans.
      #
      # @param string [String] Proxmox disk config value
      # @return [Hash{Symbol => Object}] parsed disk config
      def parse_disk_value(string)
        parts = string.split(",")
        first = parts.shift.strip
        storage, volume = first.split(":", 2)
        result = { storage: storage }
        result[:volume] = volume if volume
        parts.each do |part|
          k, v = part.strip.split("=", 2)
          sym = k.to_sym
          result[sym] = DISK_BOOLEAN_SUBKEYS.include?(sym) ? to_boolean(v) : v
        end
        result
      end

      # Serializes a disk hash back to Proxmox config string format.
      # Converts Ruby booleans back to 0/1 strings.
      #
      # @param hash [Hash{Symbol => Object}] parsed disk config
      # @return [String] Proxmox disk config string
      def serialize_disk_value(hash)
        parts = []
        storage = hash[:storage]
        volume = hash[:volume]
        parts << [storage, volume].compact.join(":")
        hash.except(:storage, :volume).each do |k, v|
          v = from_boolean(v) if DISK_BOOLEAN_SUBKEYS.include?(k)
          parts << "#{k}=#{v}"
        end
        parts.join(",")
      end

      # Parses a generic key=value config string into a hash.
      # Format: "key=value,key=value,..."  (e.g., "enabled=1,fstrim_cloned_disks=1")
      #
      # @param string [String] comma-separated key=value string
      # @return [Hash{Symbol => String}] parsed key-value pairs
      def parse_kv_value(string, default_key: nil)
        string.split(",").to_h do |pair|
          pair = pair.strip
          if pair.include?("=")
            k, v = pair.split("=", 2)
            [k.to_sym, v]
          elsif default_key
            [default_key, pair]
          else
            [pair.to_sym, nil]
          end
        end
      end

      # Serializes a hash back to comma-separated key=value string.
      #
      # @param hash [Hash{Symbol => String}] key-value pairs
      # @return [String] comma-separated key=value string
      def serialize_kv_value(hash)
        hash.map { |k, v| "#{k}=#{v}" }.join(",")
      end

      # Parses a QEMU Guest Agent config string and fills in default values.
      # Proxmox returns bare "1" for enabled-only, but the full format includes
      # fstrim_cloned_disks, freeze-fs-on-backup, and type.
      # Boolean sub-keys are converted to Ruby booleans.
      #
      # @param string [String] agent config value (e.g., "1" or "enabled=1,fstrim_cloned_disks=1")
      # @return [Hash{Symbol => Object}] parsed agent config with all properties
      def parse_agent_value(string)
        parsed = parse_kv_value(string, default_key: :enabled)
        merged = AGENT_DEFAULTS.merge(parsed)
        merged.each_with_object({}) do |(k, v), h|
          h[k] = AGENT_BOOLEAN_SUBKEYS.include?(k) ? to_boolean(v) : v
        end
      end

      # Serializes an agent config hash back to Proxmox string, omitting default values.
      # Only includes properties that differ from AGENT_DEFAULTS for a clean config string.
      # Handles both boolean and string input values.
      #
      # @param hash [Hash{Symbol => Object}] agent config hash
      # @return [String] agent config string
      def serialize_agent_value(hash)
        # Normalize booleans back to "0"/"1" strings for comparison with AGENT_DEFAULTS
        string_hash = hash.each_with_object({}) do |(k, v), h|
          h[k] = case v
                 when true then "1"
                 when false then "0"
                 else v.to_s
                 end
        end
        non_defaults = string_hash.reject { |k, v| AGENT_DEFAULTS[k] == v }
        return "0" if non_defaults.empty?

        # Ensure enabled is always first
        parts = []
        parts << "enabled=#{string_hash[:enabled]}" if non_defaults.key?(:enabled)
        non_defaults.each do |k, v|
          next if k == :enabled
          parts << "#{k}=#{v}"
        end
        parts.join(",")
      end

      # Parses a boot order config string. The order value uses semicolons as separators.
      # Format: "order=scsi0;net0"
      #
      # @param string [String] boot config value
      # @return [Hash{Symbol => Object}] parsed boot config with :order as Array
      def parse_boot_value(string)
        kv = parse_kv_value(string)
        kv[:order] = kv[:order].split(";") if kv[:order].is_a?(String)
        kv
      end

      # Serializes a boot order hash back to Proxmox config string format.
      # Joins the :order array with semicolons.
      #
      # @param hash [Hash{Symbol => Object}] parsed boot config
      # @return [String] boot config string
      def serialize_boot_value(hash)
        result = hash.transform_values do |v|
          v.is_a?(Array) ? v.join(";") : v
        end
        serialize_kv_value(result)
      end

      # Parses a hotplug config string into a capability map with boolean values.
      # Proxmox hotplug is a CSV of enabled capabilities (e.g., "network,disk,usb").
      # Special values: "0" = all disabled, "1" = default (network,disk,usb).
      #
      # @param string [String] hotplug config value
      # @return [Hash{Symbol => Boolean}] map of all capabilities with true/false
      def parse_hotplug_value(string)
        if string == "0"
          HOTPLUG_CAPABILITIES.to_h { |cap| [cap, false] }
        elsif string == "1"
          parse_hotplug_value("network,disk,usb")
        else
          enabled = string.split(",").map { |s| s.strip.to_sym }
          HOTPLUG_CAPABILITIES.to_h { |cap| [cap, enabled.include?(cap)] }
        end
      end

      # Serializes a hotplug capability map back to Proxmox CSV format.
      # Only enabled capabilities are included. Returns "0" if all disabled.
      #
      # @param hash [Hash{Symbol => Boolean}] capability map
      # @return [String] hotplug config string
      def serialize_hotplug_value(hash)
        enabled = HOTPLUG_CAPABILITIES.select { |cap| hash[cap] == true }
        return "0" if enabled.empty?

        enabled.map(&:to_s).join(",")
      end
    end
  end
end
