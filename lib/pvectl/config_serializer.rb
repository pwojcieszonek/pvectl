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
    VM_SECTIONS = {
      general: {
        static: %i[vmid name description tags template lock digest],
        dynamic: [],
        readonly: %i[vmid template lock digest]
      },
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
      boot: {
        static: %i[boot bootdisk bios machine arch startup onboot],
        dynamic: [],
        readonly: []
      },
      cloud_init: {
        static: %i[citype cicustom ciuser cipassword ciupgrade nameserver searchdomain sshkeys],
        dynamic: [/\Aipconfig\d+\z/],
        readonly: []
      },
      display: {
        static: %i[vga spice_enhancements keyboard],
        dynamic: [],
        readonly: []
      },
      devices: {
        static: %i[audio0 tablet rng0 ivshmem],
        dynamic: [/\Aserial\d+\z/, /\Aparallel\d+\z/, /\Ausb\d+\z/, /\Ahostpci\d+\z/],
        readonly: []
      },
      system: {
        static: %i[ostype scsihw kvm agent hotplug args hookscript smbios1 localtime reboot freeze protection],
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
    CONTAINER_SECTIONS = {
      general: {
        static: %i[vmid hostname description tags template lock digest],
        dynamic: [],
        readonly: %i[vmid template lock digest]
      },
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
      },
      network: {
        static: %i[nameserver searchdomain],
        dynamic: [/\Anet\d+\z/],
        readonly: []
      },
      boot: {
        static: %i[startup onboot],
        dynamic: [],
        readonly: []
      },
      console: {
        static: %i[console cmode tty],
        dynamic: [],
        readonly: []
      },
      system: {
        static: %i[ostype arch unprivileged features hookscript protection debug timezone entrypoint env],
        dynamic: [],
        readonly: %i[arch]
      }
    }.freeze

    # Characters that require quoting in YAML output.
    YAML_SPECIAL_CHARS = %w[: # [ ] { } > | * & ! % @ ` , ? -].freeze

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
          section_keys = keys_for_section(flat_config, section_def)
          next if section_keys.empty?

          lines << "#{section_name}:"
          section_keys.each do |key|
            value = flat_config[key]
            formatted_value = format_yaml_value(value)
            readonly = readonly_key?(key, section_def) ? "  # read-only" : ""
            lines << "  #{key}: #{formatted_value}#{readonly}"
          end
          lines << ""
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
          section_values.each_key do |key|
            unless key_in_section?(key.to_sym, section_def)
              errors << "Unknown key '#{key}' in section '#{section_name}'"
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
      #
      # @param keys [Array<Symbol>] all keys to check
      # @param sections [Hash] section mapping
      # @return [Array<Symbol>] read-only keys
      def collect_readonly_keys(keys, sections)
        keys.select do |key|
          sections.any? do |_name, section_def|
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

      # Flattens a nested section hash to a flat symbol-keyed hash.
      #
      # @param parsed [Hash] nested hash from YAML.safe_load
      # @return [Hash{Symbol => Object}] flat hash
      def flatten_sections(parsed)
        result = {}
        parsed.each_value do |section_values|
          next unless section_values.is_a?(Hash)

          section_values.each do |key, value|
            result[key.to_sym] = value
          end
        end
        result
      end
    end
  end
end
