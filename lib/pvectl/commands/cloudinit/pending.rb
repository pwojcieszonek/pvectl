# frozen_string_literal: true

module Pvectl
  module Commands
    module Cloudinit
      # Handler for the `pvectl cloudinit pending vm <id>` subcommand.
      #
      # Lists cloud-init configuration entries currently differing from
      # the values used to build the active ISO. Each entry contains a
      # key, the current value, the pending value, and a delete flag.
      #
      # @example Usage
      #   pvectl cloudinit pending vm 100
      #   pvectl cloudinit pending vm 100 -o json
      #
      class Pending
        # Registers the pending subcommand under the cloudinit parent.
        #
        # @param parent [GLI::Command] parent cloudinit command
        # @return [void]
        def self.register_subcommand(parent)
          parent.desc "List pending cloud-init configuration changes"
          parent.long_desc <<~HELP
            DESCRIPTION
              Show cloud-init configuration entries that differ from the
              values currently embedded in the active cloud-init ISO. Use
              this to preview what will change on the next regeneration.

            EXAMPLES
              Show pending changes for VM 100:
                $ pvectl cloudinit pending vm 100

              JSON output for scripting:
                $ pvectl cloudinit pending vm 100 -o json

            NOTES
              An empty list means the active ISO is in sync with the
              current Proxmox configuration.

              Entries with the +action+ column set to +delete+ are about
              to be removed from the ISO.

            SEE ALSO
              pvectl help cloudinit regenerate   Apply pending changes
              pvectl help cloudinit dump         Inspect generated YAML
          HELP
          parent.arg_name "RESOURCE_TYPE ID"
          parent.command :pending do |c|
            c.action do |global_options, options, args|
              exit_code = execute(args, options, global_options)
              exit exit_code if exit_code != 0
            end
          end
        end

        # Executes the pending subcommand.
        #
        # @param args [Array<String>] command arguments
        # @param options [Hash] command-local options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def self.execute(args, options, global_options)
          resource_type = args[0]
          vmid_arg = args[1]

          return Cloudinit.usage_error("Resource type required (vm)") unless resource_type
          return Cloudinit.usage_error("VMID is required") unless vmid_arg
          return Cloudinit.unknown_resource_type(resource_type) unless resource_type == "vm"

          Cloudinit.with_service(global_options) do |service|
            entries = service.pending(vmid_arg.to_i, node: options[:node])
            render(entries, global_options)
          end
        end

        # Renders pending entries via the configured output formatter.
        #
        # For +table+ output, prints a flat 4-column table (key, current,
        # pending, action) or a friendly "no pending changes" notice when
        # the list is empty. For +json+/+yaml+ output, emits the raw
        # collection so it can be parsed downstream.
        #
        # @param entries [Array<Hash>] pending entries from the service
        # @param global_options [Hash] global CLI options
        # @return [void]
        def self.render(entries, global_options)
          format = global_options[:output] || "table"

          case format
          when "json"
            require "json"
            $stdout.puts JSON.pretty_generate(entries)
          when "yaml"
            require "yaml"
            $stdout.puts entries.map { |e| stringify_keys(e) }.to_yaml
          else
            render_table(entries)
          end
        end

        # Renders pending entries as a plain text table.
        #
        # @param entries [Array<Hash>] pending entries
        # @return [void]
        def self.render_table(entries)
          if entries.empty?
            $stdout.puts "No pending cloud-init changes."
            return
          end

          rows = entries.map do |e|
            action = e[:delete].to_i.positive? ? "delete" : (e[:pending] ? "update" : "-")
            [e[:key].to_s, (e[:value] || "-").to_s, (e[:pending] || "-").to_s, action]
          end

          headers = %w[KEY CURRENT PENDING ACTION]
          widths = headers.each_with_index.map do |h, i|
            [h.length, *rows.map { |r| r[i].length }].max
          end

          $stdout.puts headers.each_with_index.map { |h, i| h.ljust(widths[i]) }.join("  ")
          rows.each do |row|
            $stdout.puts row.each_with_index.map { |v, i| v.ljust(widths[i]) }.join("  ")
          end
        end

        # Stringifies hash keys for YAML output consistency.
        #
        # @param hash [Hash] hash with symbol or string keys
        # @return [Hash] hash with string keys
        def self.stringify_keys(hash)
          hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
        end
      end
    end
  end
end
