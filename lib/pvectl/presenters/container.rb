# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for LXC containers.
    #
    # Defines column layout and formatting for table output.
    # Used by formatters to render container data in various formats.
    #
    # Standard columns: CTID, NAME, STATUS, CPU, MEMORY, NODE, UPTIME, TEMPLATE, TAGS
    # Wide columns add: SWAP, DISK, NETIN, NETOUT, POOL
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
        %w[CTID NAME STATUS CPU MEMORY NODE UPTIME TEMPLATE TAGS]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[SWAP DISK NETIN NETOUT POOL]
      end

      # Converts Container model to table row values.
      #
      # @param model [Models::Container] Container model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @container = model
        [
          container.vmid.to_s,
          display_name,
          container.status,
          cpu_percent,
          memory_display,
          container.node,
          uptime_human,
          template_display,
          tags_display
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

        {
          "Name" => display_name,
          "CTID" => container.vmid,
          "Status" => container.status,
          "Node" => container.node,
          "Template" => container.template? ? "yes" : "no",
          "System" => format_system,
          "CPU" => format_cpu,
          "Memory" => format_memory,
          "Swap" => format_swap,
          "Root Filesystem" => format_rootfs,
          "Network" => format_network_interfaces,
          "Features" => format_features,
          "Runtime" => format_runtime,
          "Tags" => tags_display,
          "Description" => container.description || "-"
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

      # Returns uptime in human-readable format.
      #
      # @return [String] formatted uptime (e.g., "15d 3h") or "-" if unavailable
      def uptime_human
        return "-" if container.uptime.nil? || container.uptime.zero?

        days = container.uptime / 86_400
        hours = (container.uptime % 86_400) / 3600
        minutes = (container.uptime % 3600) / 60

        if days.positive?
          "#{days}d #{hours}h"
        elsif hours.positive?
          "#{hours}h #{minutes}m"
        else
          "#{minutes}m"
        end
      end

      # Returns tags as array.
      #
      # @return [Array<String>] array of tags, or empty array if no tags
      def tags_array
        return [] if container.tags.nil? || container.tags.empty?

        container.tags.split(";").map(&:strip)
      end

      # Returns tags as comma-separated string.
      #
      # @return [String] formatted tags (e.g., "prod, web") or "-" if no tags
      def tags_display
        arr = tags_array
        arr.empty? ? "-" : arr.join(", ")
      end

      # Returns template display string.
      #
      # @return [String] "yes" if template, "-" otherwise
      def template_display
        container.template? ? "yes" : "-"
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

      # Formats system section.
      #
      # @return [Hash] system info
      def format_system
        {
          "OS Type" => container.ostype || "-",
          "Architecture" => container.arch || "-",
          "Unprivileged" => container.unprivileged? ? "yes" : "no"
        }
      end

      # Formats CPU section.
      #
      # @return [Hash] CPU info
      def format_cpu
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
      # @return [Hash] rootfs info
      def format_rootfs
        size_gib = disk_total_gib ? "#{disk_total_gib} GiB" : "-"
        used_gib = disk_used_gib ? "#{disk_used_gib} GiB" : "-"

        {
          "Size" => size_gib,
          "Used" => used_gib
        }
      end

      # Formats network interfaces for table display.
      #
      # @return [Array<Hash>, String] network interfaces or "-"
      def format_network_interfaces
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
      # @return [String] formatted features or "-"
      def format_features
        return "-" if container.features.nil? || container.features.empty?

        # Parse "nesting=1,keyctl=1" to "nesting, keyctl"
        container.features.split(",").map do |f|
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

      # Formats bytes to human readable string.
      #
      # @param bytes [Integer, nil] bytes
      # @return [String] formatted size
      def format_bytes(bytes)
        return "-" if bytes.nil? || bytes.zero?

        if bytes >= 1024 * 1024 * 1024
          "#{(bytes.to_f / 1024 / 1024 / 1024).round(1)} GiB"
        elsif bytes >= 1024 * 1024
          "#{(bytes.to_f / 1024 / 1024).round(1)} MiB"
        elsif bytes >= 1024
          "#{(bytes.to_f / 1024).round(1)} KiB"
        else
          "#{bytes} B"
        end
      end
    end
  end
end
