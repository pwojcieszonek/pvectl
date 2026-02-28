# frozen_string_literal: true

require "set"

module Pvectl
  module Presenters
    # Presenter for LXC containers.
    #
    # Defines column layout and formatting for table output.
    # Used by formatters to render container data in various formats.
    #
    # Standard columns: NAME, CTID, STATUS, NODE, CPU, MEMORY
    # Wide columns add: UPTIME, TEMPLATE, TAGS, SWAP, DISK, NETIN, NETOUT, POOL
    #
    # @example Using with formatter
    #   presenter = Container.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(containers, presenter)
    #
    # @see Pvectl::Models::Container Container model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Container < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NAME CTID STATUS NODE CPU MEMORY]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[UPTIME TEMPLATE TAGS SWAP DISK NETIN NETOUT POOL]
      end

      # Converts Container model to table row values.
      #
      # @param model [Models::Container] Container model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @container = model
        [
          display_name,
          container.vmid.to_s,
          container.status,
          container.node,
          cpu_percent,
          memory_display
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Container] Container model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @container = model
        [
          uptime_human,
          template_display,
          tags_display,
          swap_display,
          disk_display,
          netin_display,
          netout_display,
          pool_display
        ]
      end

      # Converts Container model to hash for JSON/YAML output.
      #
      # Returns a structured hash with nested objects for complex data
      # like CPU, memory, swap, disk, uptime, and network.
      #
      # @param model [Models::Container] Container model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        @container = model
        {
          "ctid" => container.vmid,
          "name" => container.name,
          "status" => container.status,
          "node" => container.node,
          "template" => container.template?,
          "pool" => container.pool,
          "cpu" => {
            "usage_percent" => container.cpu.nil? ? nil : (container.cpu * 100).round,
            "cores" => container.maxcpu
          },
          "memory" => {
            "used_gib" => memory_used_gib,
            "total_gib" => memory_total_gib,
            "used_bytes" => container.mem,
            "total_bytes" => container.maxmem
          },
          "swap" => {
            "used_mib" => swap_used_mib,
            "total_mib" => swap_total_mib,
            "used_bytes" => container.swap,
            "total_bytes" => container.maxswap
          },
          "disk" => {
            "used_gib" => disk_used_gib,
            "total_gib" => disk_total_gib,
            "used_bytes" => container.disk,
            "total_bytes" => container.maxdisk
          },
          "uptime" => {
            "seconds" => container.uptime,
            "human" => uptime_human
          },
          "network" => {
            "in_bytes" => container.netin,
            "out_bytes" => container.netout
          },
          "tags" => tags_array
        }
      end

      # Converts Container model to description format for describe command.
      #
      # Returns a structured Hash with sections for kubectl-style vertical output.
      # Nested Hashes create indented subsections.
      # Arrays of Hashes render as inline tables.
      #
      # @param model [Models::Container] Container model with describe details
      # @return [Hash] structured hash for describe formatter
      def to_description(model)
        @container = model
        @consumed_keys = Set.new
        data = container.describe_data || {}
        config = data[:config] || {}

        consume(:hostname, :description, :tags, :pool, :template)
        consume_misc_keys(config)

        {
          "Name" => display_name,
          "CTID" => container.vmid,
          "Status" => container.status,
          "Node" => container.node,
          "Template" => container.template? ? "yes" : "no",
          "Pool" => container.pool || "-",
          "System" => format_system(config),
          "CPU" => format_cpu(config),
          "Memory" => format_memory,
          "Swap" => format_swap,
          "Root Filesystem" => format_rootfs(config),
          "Mountpoints" => format_mountpoints(config),
          "Network" => format_network_interfaces(config),
          "DNS" => format_dns(config),
          "Features" => format_features(config),
          "Console" => format_console(config),
          "Snapshots" => format_snapshots(data[:snapshots]),
          "Runtime" => format_runtime,
          "Tags" => tags_display,
          "Description" => container.description || config[:description] || "-",
          "Additional Configuration" => format_remaining(config)
        }
      end

      # ---------------------------
      # Display Methods
      # ---------------------------

      # Returns display name, falling back to "CT-{ctid}" if name is nil.
      #
      # @return [String] display name
      def display_name
        container.name || "CT-#{container.vmid}"
      end

      # Returns CPU usage as percentage string.
      #
      # For running containers, shows actual usage percentage.
      # For stopped containers, shows "-" for usage but includes core count if available.
      #
      # @return [String] CPU percentage (e.g., "12%/4") or "-/4" for stopped containers
      def cpu_percent
        return "-" if container.maxcpu.nil?
        return "-/#{container.maxcpu}" unless container.running?
        return "-/#{container.maxcpu}" if container.cpu.nil?

        "#{(container.cpu * 100).round}%/#{container.maxcpu}"
      end

      # Returns memory used in GiB.
      #
      # @return [Float, nil] memory used in GiB, or nil if unavailable
      def memory_used_gib
        return nil if container.mem.nil?

        (container.mem.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns total memory in GiB.
      #
      # @return [Float, nil] total memory in GiB, or nil if unavailable
      def memory_total_gib
        return nil if container.maxmem.nil?

        (container.maxmem.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns memory formatted as "used/total GiB".
      #
      # For running containers, shows actual usage and total.
      # For stopped containers, shows "-" for usage but includes total if available.
      #
      # @return [String] formatted memory (e.g., "2.1/4.0 GiB") or "-/4.0 GiB" for stopped
      def memory_display
        return "-" if memory_total_gib.nil?
        return "-/#{memory_total_gib} GiB" unless container.running?
        return "-/#{memory_total_gib} GiB" if memory_used_gib.nil?

        "#{memory_used_gib}/#{memory_total_gib} GiB"
      end

      # Returns swap used in MiB.
      #
      # @return [Float, nil] swap used in MiB, or nil if unavailable
      def swap_used_mib
        return nil if container.swap.nil?

        (container.swap.to_f / 1024 / 1024).round(1)
      end

      # Returns total swap in MiB.
      #
      # @return [Float, nil] total swap in MiB, or nil if unavailable
      def swap_total_mib
        return nil if container.maxswap.nil?

        (container.maxswap.to_f / 1024 / 1024).round(1)
      end

      # Returns swap formatted as "used/total MiB".
      #
      # @return [String] formatted swap (e.g., "128/512 MiB") or "-" if unavailable
      def swap_display
        return "-" if swap_total_mib.nil? || swap_total_mib.zero?
        return "-/#{swap_total_mib.round} MiB" unless container.running?
        return "-/#{swap_total_mib.round} MiB" if swap_used_mib.nil?

        "#{swap_used_mib.round}/#{swap_total_mib.round} MiB"
      end

      # Returns disk used in GiB.
      #
      # @return [Float, nil] disk used in GiB, or nil if unavailable
      def disk_used_gib
        return nil if container.disk.nil?

        (container.disk.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns total disk in GiB.
      #
      # @return [Float, nil] total disk in GiB, or nil if unavailable
      def disk_total_gib
        return nil if container.maxdisk.nil?

        (container.maxdisk.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns disk formatted as "used/total GiB".
      #
      # @return [String] formatted disk (e.g., "15.0/50.0 GiB") or "-" if unavailable
      def disk_display
        return "-" if disk_used_gib.nil?

        "#{disk_used_gib}/#{disk_total_gib} GiB"
      end

      # Returns pool display string.
      #
      # @return [String] pool name or "-" if no pool
      def pool_display
        container.pool || "-"
      end

      # Returns network in bytes formatted.
      #
      # @return [String] formatted network in (e.g., "117.7 MiB") or "-"
      def netin_display
        format_bytes(container.netin)
      end

      # Returns network out bytes formatted.
      #
      # @return [String] formatted network out (e.g., "941.9 MiB") or "-"
      def netout_display
        format_bytes(container.netout)
      end

      private

      # @return [Models::Container] current container model
      attr_reader :container
      alias resource container

      # Formats system section.
      #
      # @param config [Hash] raw config hash for key consumption
      # @return [Hash] system info
      def format_system(config = {})
        consume(:ostype, :arch, :unprivileged)
        {
          "OS Type" => container.ostype || config[:ostype] || "-",
          "Architecture" => container.arch || config[:arch] || "-",
          "Unprivileged" => container.unprivileged? ? "yes" : "no"
        }
      end

      # Formats CPU section.
      #
      # @param config [Hash] raw config hash for key consumption
      # @return [Hash] CPU info
      def format_cpu(config = {})
        consume(:cores)
        usage = container.running? && container.cpu ? "#{(container.cpu * 100).round}%" : "-"

        {
          "Cores" => container.maxcpu || "-",
          "Usage" => usage
        }
      end

      # Formats memory section.
      #
      # @return [Hash] memory info
      def format_memory
        total_gib = memory_total_gib ? "#{memory_total_gib} GiB" : "-"
        used_gib = container.running? && memory_used_gib ? "#{memory_used_gib} GiB" : "-"

        usage = if container.running? && container.mem && container.maxmem && container.maxmem > 0
                  "#{((container.mem.to_f / container.maxmem) * 100).round}%"
                else
                  "-"
                end

        {
          "Total" => total_gib,
          "Used" => used_gib,
          "Usage" => usage
        }
      end

      # Formats swap section.
      #
      # @return [Hash] swap info
      def format_swap
        total_mib = swap_total_mib ? "#{swap_total_mib.round} MiB" : "-"
        used_mib = container.running? && swap_used_mib ? "#{swap_used_mib.round} MiB" : "-"

        {
          "Total" => total_mib,
          "Used" => used_mib
        }
      end

      # Formats rootfs section.
      #
      # @param config [Hash] raw config hash for key consumption
      # @return [Hash] rootfs info
      def format_rootfs(config = {})
        consume(:rootfs)
        size_gib = disk_total_gib ? "#{disk_total_gib} GiB" : "-"
        used_gib = disk_used_gib ? "#{disk_used_gib} GiB" : "-"

        {
          "Size" => size_gib,
          "Used" => used_gib
        }
      end

      # Formats network interfaces for table display.
      #
      # @param config [Hash] raw config hash for key consumption
      # @return [Array<Hash>, String] network interfaces or "-"
      def format_network_interfaces(config = {})
        consume_matching(config, /^net\d+$/)
        interfaces = container.network_interfaces
        return "-" if interfaces.nil? || interfaces.empty?

        interfaces.map do |iface|
          {
            "NAME" => iface[:name] || "-",
            "BRIDGE" => iface[:bridge] || "-",
            "IP" => iface[:ip] || "-",
            "MAC" => iface[:hwaddr] || "-"
          }
        end
      end

      # Formats features for display.
      #
      # @param config [Hash] raw config hash for key consumption
      # @return [String] formatted features or "-"
      def format_features(config = {})
        consume(:features)
        features_str = container.features || config[:features]
        return "-" if features_str.nil? || features_str.empty?

        # Parse "nesting=1,keyctl=1" to "nesting, keyctl"
        features_str.split(",").map do |f|
          key, value = f.split("=")
          value == "1" ? key : nil
        end.compact.join(", ")
      end

      # Formats runtime section.
      #
      # @return [Hash, String] runtime info or "-"
      def format_runtime
        return "-" unless container.running?

        {
          "Uptime" => uptime_human,
          "PID" => container.pid || "-"
        }
      end

      # Formats mountpoints section (mp0-mp255).
      #
      # @param config [Hash] container config
      # @return [Array<Hash>, String] mountpoints table or "-"
      def format_mountpoints(config)
        mp_keys = config.keys.select { |k| k.to_s.match?(/^mp\d+$/) }
        consume_matching(config, /^mp\d+$/)
        consume_matching(config, /^unused\d+$/)
        return "-" if mp_keys.empty?

        mp_keys.sort.map do |key|
          parts = config[key].to_s.split(",")
          storage_part = parts.first
          storage = storage_part.include?(":") ? storage_part.split(":").first : storage_part
          mp_path = nil
          size = nil
          parts[1..].each do |part|
            k, v = part.split("=", 2)
            case k
            when "mp" then mp_path = v
            when "size" then size = v
            end
          end
          { "NAME" => key.to_s, "PATH" => mp_path || "-", "STORAGE" => storage, "SIZE" => size || "-" }
        end
      end

      # Formats DNS section.
      #
      # @param config [Hash] container config
      # @return [Hash, String] DNS info or "-"
      def format_dns(config)
        consume(:nameserver, :searchdomain)
        ns = config[:nameserver]
        sd = config[:searchdomain]
        return "-" if ns.nil? && sd.nil?

        { "Nameserver" => ns || "-", "Search Domain" => sd || "-" }
      end

      # Formats console section.
      #
      # @param config [Hash] container config
      # @return [Hash, String] console info or "-"
      def format_console(config)
        consume(:cmode, :tty)
        cmode = config[:cmode]
        tty = config[:tty]
        return "-" if cmode.nil? && tty.nil?

        { "Mode" => cmode || "tty", "TTY" => tty || 2 }
      end

      # Formats snapshots section.
      #
      # @param snapshots [Array<Hash>, nil] snapshots from API
      # @return [Array<Hash>, String] snapshots table or "No snapshots"
      def format_snapshots(snapshots)
        return "No snapshots" if snapshots.nil? || snapshots.empty?

        snapshots.map do |snap|
          snaptime = snap[:snaptime]
          date = snaptime ? Time.at(snaptime).strftime("%Y-%m-%d %H:%M:%S") : "-"
          {
            "NAME" => snap[:name],
            "DATE" => date,
            "DESCRIPTION" => snap[:description] || "-"
          }
        end
      end

      # Consumes miscellaneous config keys not handled by format methods.
      #
      # @param config [Hash] raw config hash
      # @return [void]
      def consume_misc_keys(config)
        consume(:memory, :swap, :cores, :lxc)
      end

      # Registers config keys as consumed by a format method.
      #
      # @param keys [Array<Symbol>] config keys to mark as consumed
      # @return [void]
      def consume(*keys)
        @consumed_keys.merge(keys.map(&:to_sym))
      end

      # Consumes all config keys matching a pattern.
      #
      # @param config [Hash] config hash
      # @param pattern [Regexp] pattern to match key names
      # @return [void]
      def consume_matching(config, pattern)
        config.keys.select { |k| k.to_s.match?(pattern) }.each { |k| consume(k) }
      end

      # Formats remaining unconsumed config keys as catch-all table.
      #
      # @param config [Hash] full config hash
      # @return [Array<Hash>, String] remaining keys table or "-"
      def format_remaining(config)
        excluded = %i[digest]
        remaining = config.keys.map(&:to_sym) - @consumed_keys.to_a - excluded
        return "-" if remaining.empty?

        remaining.sort.map { |k| { "KEY" => k.to_s, "VALUE" => config[k].to_s } }
      end

    end
  end
end
