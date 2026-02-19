# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for Proxmox cluster nodes.
    #
    # Defines column layout and formatting for table output.
    # Standard columns show essential node info.
    # Wide columns add detailed metrics (load, swap, storage, kernel).
    #
    # @example Using with formatter
    #   presenter = Node.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(nodes, presenter)
    #
    # @see Pvectl::Models::Node Node model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Node < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NAME STATUS VERSION CPU MEMORY GUESTS UPTIME]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[LOAD SWAP STORAGE VMS CTS KERNEL IP]
      end

      # Converts Node model to table row values.
      #
      # @param model [Models::Node] Node model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @node = model
        [
          node.name,
          node.status,
          version_display,
          cpu_percent,
          memory_display,
          node.guests_total.to_s,
          uptime_human
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Node] Node model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @node = model
        [
          load_display,
          swap_display,
          storage_display,
          node.guests_vms.to_s,
          node.guests_cts.to_s,
          kernel_display,
          ip_display
        ]
      end

      # Converts Node model to hash for JSON/YAML output.
      #
      # Returns a structured hash with nested objects for complex data
      # like CPU, memory, disk, uptime, swap, load, and guests.
      #
      # @param model [Models::Node] Node model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        @node = model
        {
          "name" => node.name,
          "status" => node.status,
          "version" => node.version,
          "kernel" => node.kernel,
          "cpu" => {
            "usage_percent" => node.cpu.nil? ? nil : (node.cpu * 100).round,
            "cores" => node.maxcpu
          },
          "memory" => {
            "used_bytes" => node.mem,
            "total_bytes" => node.maxmem,
            "used_gb" => memory_used_gb,
            "total_gb" => memory_total_gb,
            "usage_percent" => memory_percent(node)
          },
          "swap" => {
            "used_bytes" => node.swap_used,
            "total_bytes" => node.swap_total,
            "usage_percent" => swap_percent(node)
          },
          "storage" => {
            "used_bytes" => node.disk,
            "total_bytes" => node.maxdisk,
            "usage_percent" => storage_percent(node)
          },
          "load" => {
            "avg1" => node.loadavg&.dig(0),
            "avg5" => node.loadavg&.dig(1),
            "avg15" => node.loadavg&.dig(2)
          },
          "guests" => {
            "total" => node.guests_total,
            "vms" => node.guests_vms,
            "cts" => node.guests_cts
          },
          "uptime" => {
            "seconds" => node.uptime,
            "human" => uptime_human
          },
          "alerts" => alerts,
          "network" => {
            "ip" => node.ip
          }
        }
      end

      # Converts Node model to description format for describe command.
      #
      # Returns a structured Hash with sections for kubectl-style vertical output.
      # Nested Hashes create indented subsections.
      # Arrays of Hashes render as inline tables.
      #
      # @param model [Models::Node] Node model with describe details
      # @return [Hash] structured hash for describe formatter
      def to_description(model)
        @node = model
        return offline_description if node.offline?

        {
          "Name" => node.name,
          "Status" => node.status,
          "Subscription" => subscription_display,
          "System" => {
            "Version" => version_display,
            "Kernel" => kernel_display,
            "Boot Mode" => boot_mode,
            "Uptime" => uptime_human
          },
          "CPU" => {
            "Model" => cpu_model || "-",
            "Cores" => cpu_cores || node.maxcpu || "-",
            "Sockets" => cpu_sockets || "-",
            "Usage" => cpu_percent
          },
          "Memory" => {
            "Usage" => memory_percent_display(node),
            "Used" => format_gib(node.mem),
            "Total" => format_gib(node.maxmem)
          },
          "Swap" => {
            "Usage" => swap_percent_display(node),
            "Used" => format_gib(node.swap_used),
            "Total" => format_gib(node.swap_total)
          },
          "Load Average" => {
            "1 min" => node.loadavg&.dig(0)&.round(2) || "-",
            "5 min" => node.loadavg&.dig(1)&.round(2) || "-",
            "15 min" => node.loadavg&.dig(2)&.round(2) || "-"
          },
          "Root Filesystem" => rootfs_display,
          "Network Interfaces" => format_network_interfaces(node.network_interfaces),
          "DNS" => {
            "Search" => dns_search,
            "Nameservers" => dns_nameservers
          },
          "Time" => {
            "Timezone" => timezone,
            "Local Time" => local_time
          },
          "Services" => format_services(node.services),
          "Storage Pools" => format_storage_pools(node.storage_pools),
          "Physical Disks" => format_physical_disks(node.physical_disks),
          "Capabilities" => {
            "QEMU CPU Models" => format_cpu_models(node.qemu_cpu_models),
            "QEMU Machines" => format_machines(node.qemu_machines)
          },
          "Guests" => {
            "VMs" => node.guests_vms,
            "Containers" => node.guests_cts,
            "Total" => node.guests_total
          },
          "Updates" => {
            "Available" => "#{node.updates_available} packages"
          },
          "Alerts" => alerts_display
        }
      end

      # -----------------------------------------------------------------
      # Display Methods (moved from Models::Node)
      # -----------------------------------------------------------------

      # Returns CPU usage as percentage string.
      #
      # @return [String] CPU percentage (e.g., "23%") or "-" if offline/unavailable
      def cpu_percent
        return "-" if node.offline? || node.cpu.nil?

        "#{(node.cpu * 100).round}%"
      end

      # Returns memory used in GB.
      #
      # @return [Float, nil] memory used in GB, or nil if unavailable
      def memory_used_gb
        return nil if node.mem.nil?

        (node.mem.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns total memory in GB.
      #
      # @return [Integer, nil] total memory in GB, or nil if unavailable
      def memory_total_gb
        return nil if node.maxmem.nil?

        (node.maxmem.to_f / 1024 / 1024 / 1024).round(0)
      end

      # Returns memory formatted as "used/total GB".
      #
      # @return [String] formatted memory (e.g., "45.2/128 GB") or "-" if offline
      def memory_display
        return "-" if node.offline? || memory_total_gb.nil?
        return "-/#{memory_total_gb} GB" if memory_used_gb.nil?

        "#{memory_used_gb}/#{memory_total_gb} GB"
      end

      # Returns disk used in GB.
      #
      # @return [Float, nil] disk used in GB, or nil if unavailable
      def disk_used_gb
        return nil if node.disk.nil?

        (node.disk.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns total disk in GB.
      #
      # @return [Float, nil] total disk in GB, or nil if unavailable
      def disk_total_gb
        return nil if node.maxdisk.nil?

        (node.maxdisk.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns disk formatted with appropriate unit (GB or TB).
      #
      # Uses GB for disks under 1 TB, TB for larger disks.
      # This provides better readability for smaller storage.
      #
      # @return [String] formatted disk (e.g., "85/100 GB" or "1.2/4.0 TB") or "-" if offline
      def storage_display
        return "-" if node.offline? || node.maxdisk.nil?

        total_gb = disk_total_gb
        used_gb = disk_used_gb || 0.0

        if total_gb >= 1024
          # Use TB for disks >= 1 TB
          used_tb = (used_gb / 1024).round(1)
          total_tb = (total_gb / 1024).round(1)
          "#{used_tb}/#{total_tb} TB"
        else
          # Use GB for smaller disks
          "#{used_gb.round(0).to_i}/#{total_gb.round(0).to_i} GB"
        end
      end

      # Returns swap used in GB.
      #
      # @return [Float, nil] swap used in GB, or nil if unavailable
      def swap_used_gb
        return nil if node.swap_used.nil?

        (node.swap_used.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns total swap in GB.
      #
      # @return [Integer, nil] total swap in GB, or nil if unavailable
      def swap_total_gb
        return nil if node.swap_total.nil?

        (node.swap_total.to_f / 1024 / 1024 / 1024).round(0)
      end

      # Returns swap formatted as "used/total GB".
      #
      # @return [String] formatted swap (e.g., "0.0/8 GB") or "-" if offline
      def swap_display
        return "-" if node.offline? || swap_total_gb.nil?

        "#{swap_used_gb}/#{swap_total_gb} GB"
      end

      # Returns 1-minute load average.
      #
      # @return [Float, nil] 1-minute load average, or nil if unavailable
      def load_1m
        return nil if node.loadavg.nil? || node.loadavg.empty?

        node.loadavg[0]
      end

      # Returns load average display with high-load indicator.
      #
      # @return [String] load average (e.g., "0.45" or "2.31\u2191") or "-" if offline
      def load_display
        return "-" if node.offline? || load_1m.nil?

        load = load_1m.round(2)
        load > 2.0 ? "#{load}\u2191" : load.to_s
      end

      # Returns uptime in human-readable format.
      #
      # @return [String] formatted uptime (e.g., "45d 3h") or "-" if offline
      def uptime_human
        return "-" if node.offline? || node.uptime.nil? || node.uptime.zero?

        days = node.uptime / 86_400
        hours = (node.uptime % 86_400) / 3600
        minutes = (node.uptime % 3600) / 60

        if days.positive?
          "#{days}d #{hours}h"
        elsif hours.positive?
          "#{hours}h #{minutes}m"
        else
          "#{minutes}m"
        end
      end

      # Returns version display.
      #
      # @return [String] version (e.g., "8.3.2") or "-" if unavailable
      def version_display
        node.version || "-"
      end

      # Returns kernel display.
      #
      # @return [String] kernel version or "-" if unavailable
      def kernel_display
        node.kernel || "-"
      end

      # Returns IP address for display.
      #
      # @return [String] IP address or "-" if unavailable
      def ip_display
        node.ip || "-"
      end

      # Returns array of alert messages for this node.
      #
      # Alerts are generated based on thresholds:
      # - CPU >= 90%: critical
      # - CPU >= 80%: warning
      # - Memory >= 90%: critical
      # - Memory >= 80%: warning
      # - Status offline: always alert
      #
      # @return [Array<String>] list of alert messages
      def alerts
        result = []
        result << "Node offline" if node.offline?

        if node.online?
          cpu_pct = node.cpu.nil? ? 0 : (node.cpu * 100).round
          mem_pct = (node.maxmem.nil? || node.maxmem.zero?) ? 0 : ((node.mem.to_f / node.maxmem) * 100).round

          result << "CPU critical (#{cpu_pct}%)" if cpu_pct >= 90
          result << "CPU warning (#{cpu_pct}%)" if cpu_pct >= 80 && cpu_pct < 90
          result << "Memory critical (#{mem_pct}%)" if mem_pct >= 90
          result << "Memory warning (#{mem_pct}%)" if mem_pct >= 80 && mem_pct < 90
        end

        result
      end

      # Returns alerts as comma-separated string for display.
      #
      # @return [String] alerts (e.g., "CPU critical (92%), Memory warning") or "-" if none
      def alerts_display
        alerts.empty? ? "-" : alerts.join(", ")
      end

      # Checks if node has any alerts.
      #
      # @return [Boolean] true if alerts exist
      def has_alerts?
        !alerts.empty?
      end

      # Returns CPU model name.
      #
      # @return [String, nil] CPU model
      def cpu_model
        node.cpuinfo&.dig(:model)
      end

      # Returns CPU socket count.
      #
      # @return [Integer, nil] socket count
      def cpu_sockets
        node.cpuinfo&.dig(:sockets)
      end

      # Returns CPU core count (total).
      #
      # @return [Integer, nil] core count
      def cpu_cores
        node.cpuinfo&.dig(:cores)
      end

      # Returns boot mode.
      #
      # @return [String] "UEFI" or "BIOS" or "-"
      def boot_mode
        mode = node.boot_info&.dig(:mode)
        case mode
        when "efi" then "UEFI"
        when "bios" then "BIOS"
        else "-"
        end
      end

      # Returns subscription status display.
      #
      # @return [String] e.g., "Active (Community)" or "Inactive"
      def subscription_display
        return "-" if node.subscription.nil?

        status = node.subscription[:status]
        level = node.subscription[:level]

        level_name = case level
                     when "c" then "Community"
                     when "b" then "Basic"
                     when "s" then "Standard"
                     when "p" then "Premium"
                     else level
                     end

        status == "Active" ? "Active (#{level_name})" : "Inactive"
      end

      # Returns timezone.
      #
      # @return [String] timezone or "-"
      def timezone
        node.time_info&.dig(:timezone) || "-"
      end

      # Returns local time formatted.
      #
      # @return [String] local time or "-"
      def local_time
        localtime = node.time_info&.dig(:localtime)
        return "-" if localtime.nil?

        Time.at(localtime).strftime("%Y-%m-%d %H:%M:%S")
      end

      # Returns DNS search domain.
      #
      # @return [String] search domain or "-"
      def dns_search
        node.dns&.dig(:search) || "-"
      end

      # Returns DNS nameservers.
      #
      # @return [String] comma-separated nameservers or "-"
      def dns_nameservers
        servers = [node.dns&.dig(:dns1), node.dns&.dig(:dns2), node.dns&.dig(:dns3)].compact
        servers.empty? ? "-" : servers.join(", ")
      end

      # Returns rootfs usage percentage.
      #
      # @return [Integer, nil] percentage
      def rootfs_usage_percent
        return nil if node.rootfs.nil? || node.rootfs[:total].nil? || node.rootfs[:total].zero?

        ((node.rootfs[:used].to_f / node.rootfs[:total]) * 100).round
      end

      # Returns rootfs display.
      #
      # @return [String] e.g., "30% (1.2/4.0 TiB)"
      def rootfs_display
        return "-" if node.rootfs.nil?

        used_gb = (node.rootfs[:used].to_f / 1024 / 1024 / 1024).round(1)
        total_gb = (node.rootfs[:total].to_f / 1024 / 1024 / 1024).round(1)
        pct = rootfs_usage_percent || 0

        if total_gb >= 1024
          "#{pct}% (#{(used_gb / 1024).round(1)}/#{(total_gb / 1024).round(1)} TiB)"
        else
          "#{pct}% (#{used_gb}/#{total_gb} GiB)"
        end
      end

      private

      # @return [Models::Node] the current node being presented
      attr_reader :node

      # Returns description for offline nodes.
      #
      # @return [Hash] minimal description
      def offline_description
        {
          "Name" => node.name,
          "Status" => node.status,
          "Note" => node.offline_note || "Node is offline. Detailed metrics unavailable."
        }
      end

      # Returns memory percentage for display.
      #
      # @param model [Models::Node] Node model
      # @return [String] percentage string
      def memory_percent_display(model)
        pct = memory_percent(model)
        pct ? "#{pct.round}%" : "-"
      end

      # Returns swap percentage for display.
      #
      # @param model [Models::Node] Node model
      # @return [String] percentage string
      def swap_percent_display(model)
        pct = swap_percent(model)
        pct ? "#{pct.round}%" : "-"
      end

      # Formats bytes to GiB string.
      #
      # @param bytes [Integer, nil] bytes value
      # @return [String] formatted GiB string
      def format_gib(bytes)
        return "-" if bytes.nil?

        "#{(bytes.to_f / 1024 / 1024 / 1024).round(1)} GiB"
      end

      # Formats network interfaces for table display.
      #
      # @param interfaces [Array<Hash>] network interfaces
      # @return [Array<Hash>, String] formatted interfaces or "-"
      def format_network_interfaces(interfaces)
        return "-" if interfaces.nil? || interfaces.empty?

        interfaces.map do |iface|
          {
            "Name" => iface[:iface],
            "Type" => iface[:type],
            "Address" => iface[:address] || iface[:cidr] || "-",
            "Gateway" => iface[:gateway] || "-"
          }
        end
      end

      # Formats services for table display.
      #
      # @param services [Array<Hash>] services
      # @return [Array<Hash>, String] formatted services or "-"
      def format_services(services)
        return "-" if services.nil? || services.empty?

        services.map do |svc|
          {
            "Name" => svc[:service] || svc[:name],
            "State" => svc[:state],
            "Description" => svc[:desc] || "-"
          }
        end
      end

      # Formats storage pools for table display.
      #
      # Supports both Models::Storage instances (new format) and Hash (legacy).
      #
      # @param pools [Array<Models::Storage>, Array<Hash>] storage pools
      # @return [Array<Hash>, String] formatted pools or "-"
      def format_storage_pools(pools)
        return "-" if pools.nil? || pools.empty?

        # Handle both Models::Storage and Hash formats
        pools.select { |p| storage_enabled?(p) }.map do |pool|
          format_storage_pool(pool)
        end
      end

      # Formats physical disks for table display.
      #
      # @param disks [Array<Hash>] physical disks
      # @return [Array<Hash>, String] formatted disks or "-"
      def format_physical_disks(disks)
        return "-" if disks.nil? || disks.empty?

        disks.map do |disk|
          size_gb = disk[:size] ? (disk[:size].to_f / 1024 / 1024 / 1024).round(1) : 0
          {
            "Device" => disk[:devpath],
            "Model" => disk[:model] || "-",
            "Size" => format_storage_size(size_gb),
            "Type" => disk[:type] || "-",
            "Health" => disk[:health] || "-"
          }
        end
      end

      # Formats CPU models list for display.
      #
      # @param models [Array<Hash>] CPU models
      # @return [String] formatted list
      def format_cpu_models(models)
        return "-" if models.nil? || models.empty?

        names = models.take(6).map { |m| m[:name] }
        names.size < models.size ? "#{names.join(', ')}, ..." : names.join(", ")
      end

      # Formats machine types list for display.
      #
      # @param machines [Array<Hash>] machine types
      # @return [String] formatted list
      def format_machines(machines)
        return "-" if machines.nil? || machines.empty?

        names = machines.take(4).map { |m| m[:id] }
        names.size < machines.size ? "#{names.join(', ')}, ..." : names.join(", ")
      end

      # Calculates memory usage percentage.
      #
      # @param model [Models::Node] Node model
      # @return [Float, nil] memory usage percentage or nil if unavailable
      def memory_percent(model)
        return nil if model.maxmem.nil? || model.maxmem.zero? || model.mem.nil?

        ((model.mem.to_f / model.maxmem) * 100).round(1)
      end

      # Calculates swap usage percentage.
      #
      # @param model [Models::Node] Node model
      # @return [Float, nil] swap usage percentage or nil if unavailable
      def swap_percent(model)
        return nil if model.swap_total.nil? || model.swap_total.zero? || model.swap_used.nil?

        ((model.swap_used.to_f / model.swap_total) * 100).round(1)
      end

      # Calculates storage usage percentage.
      #
      # @param model [Models::Node] Node model
      # @return [Float, nil] storage usage percentage or nil if unavailable
      def storage_percent(model)
        return nil if model.maxdisk.nil? || model.maxdisk.zero? || model.disk.nil?

        ((model.disk.to_f / model.maxdisk) * 100).round(1)
      end

      # Checks if storage pool is enabled.
      # Supports both Models::Storage and Hash formats.
      #
      # @param pool [Models::Storage, Hash] storage pool
      # @return [Boolean] true if enabled
      def storage_enabled?(pool)
        if pool.respond_to?(:enabled?)
          pool.enabled?
        else
          pool[:enabled] != 0
        end
      end

      # Formats a single storage pool for display.
      # Supports both Models::Storage and Hash formats.
      #
      # @param pool [Models::Storage, Hash] storage pool
      # @return [Hash] formatted pool data
      def format_storage_pool(pool)
        if pool.respond_to?(:name)
          # Models::Storage instance - use Storage presenter for display
          format_storage_pool_model(pool)
        else
          # Hash format (legacy)
          format_storage_pool_hash(pool)
        end
      end

      # Formats a storage pool from Models::Storage instance.
      # Uses Storage presenter for display formatting.
      #
      # @param pool [Models::Storage] storage pool model
      # @return [Hash] formatted pool data
      def format_storage_pool_model(pool)
        storage_presenter = Storage.new
        storage_presenter.to_row(pool)  # Set up @storage in presenter
        {
          "Name" => pool.name,
          "Type" => storage_presenter.type_display,
          "Total" => storage_presenter.total_display,
          "Used" => storage_presenter.used_display,
          "Available" => storage_presenter.avail_display,
          "Usage" => storage_presenter.usage_display
        }
      end

      # Formats a storage pool from Hash data (legacy format).
      #
      # @param pool [Hash] storage pool hash
      # @return [Hash] formatted pool data
      def format_storage_pool_hash(pool)
        total_gb = pool[:total] ? (pool[:total].to_f / 1024 / 1024 / 1024).round(1) : 0
        used_gb = pool[:used] ? (pool[:used].to_f / 1024 / 1024 / 1024).round(1) : 0
        avail_gb = pool[:avail] ? (pool[:avail].to_f / 1024 / 1024 / 1024).round(1) : 0
        usage_pct = pool[:total] && pool[:total] > 0 ? ((pool[:used].to_f / pool[:total]) * 100).round : 0

        {
          "Name" => pool[:storage],
          "Type" => pool[:type],
          "Total" => format_storage_size(total_gb),
          "Used" => format_storage_size(used_gb),
          "Available" => format_storage_size(avail_gb),
          "Usage" => "#{usage_pct}%"
        }
      end

      # Formats storage size with appropriate unit.
      #
      # @param gb [Float] size in GB
      # @return [String] formatted size
      def format_storage_size(gb)
        gb >= 1024 ? "#{(gb / 1024).round(1)} TiB" : "#{gb} GiB"
      end
    end
  end
end
