# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for QEMU virtual machines.
    #
    # Defines column layout and formatting for table output.
    # Used by formatters to render VM data in various formats.
    #
    # Standard columns: VMID, NAME, STATUS, CPU, MEMORY, NODE, UPTIME, TEMPLATE, TAGS
    # Wide columns add: DISK, IP, AGENT, HA, BACKUP
    #
    # @example Using with formatter
    #   presenter = Vm.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(vms, presenter)
    #
    # @see Pvectl::Models::Vm VM model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Vm < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[VMID NAME STATUS CPU MEMORY NODE UPTIME TEMPLATE TAGS]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[DISK IP AGENT HA BACKUP]
      end

      # Converts VM model to table row values.
      #
      # @param model [Models::Vm] VM model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @vm = model
        [
          vm.vmid.to_s,
          display_name,
          vm.status,
          cpu_percent,
          memory_display,
          vm.node,
          uptime_human,
          template_display,
          tags_display
        ]
      end

      # Returns additional values for wide output.
      #
      # Note: IP, AGENT, and BACKUP are placeholders for future implementation
      # that would require additional API calls to the QEMU guest agent.
      #
      # @param model [Models::Vm] VM model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @vm = model
        [
          disk_display,
          "-",              # IP - requires QEMU agent (future enhancement)
          "-",              # AGENT status (future enhancement)
          vm.hastate || "-",
          "-"               # BACKUP schedule (future enhancement)
        ]
      end

      # Converts VM model to hash for JSON/YAML output.
      #
      # Returns a structured hash with nested objects for complex data
      # like CPU, memory, disk, uptime, and network.
      #
      # @param model [Models::Vm] VM model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        @vm = model
        {
          "vmid" => vm.vmid,
          "name" => vm.name,
          "status" => vm.status,
          "node" => vm.node,
          "template" => vm.template?,
          "cpu" => {
            "usage_percent" => vm.cpu.nil? ? nil : (vm.cpu * 100).round,
            "cores" => vm.maxcpu
          },
          "memory" => {
            "used_gb" => memory_used_gb,
            "total_gb" => memory_total_gb,
            "used_bytes" => vm.mem,
            "total_bytes" => vm.maxmem
          },
          "disk" => {
            "used_gb" => disk_used_gb,
            "total_gb" => disk_total_gb,
            "used_bytes" => vm.disk,
            "total_bytes" => vm.maxdisk
          },
          "uptime" => {
            "seconds" => vm.uptime,
            "human" => uptime_human
          },
          "network" => {
            "in_bytes" => vm.netin,
            "out_bytes" => vm.netout
          },
          "ha" => {
            "state" => vm.hastate
          },
          "tags" => tags_array
        }
      end

      # Converts VM model to description format for describe command.
      #
      # Returns a structured Hash with sections for kubectl-style vertical output.
      # Nested Hashes create indented subsections.
      # Arrays of Hashes render as inline tables.
      #
      # @param model [Models::Vm] VM model with describe details
      # @return [Hash] structured hash for describe formatter
      def to_description(model)
        @vm = model
        data = vm.describe_data || {}
        config = data[:config] || {}
        status = data[:status] || {}

        {
          "Name" => display_name,
          "VMID" => vm.vmid,
          "Status" => vm.status,
          "Node" => vm.node,
          "Template" => vm.template? ? "yes" : "no",
          "System" => format_system(config),
          "CPU" => format_cpu(config, status),
          "Memory" => format_memory(config, status),
          "Disks" => parse_disks(config),
          "Network" => format_network(config, data[:agent_ips]),
          "Snapshots" => format_snapshots(data[:snapshots]),
          "Runtime" => format_runtime(status),
          "Network I/O" => format_network_io,
          "High Availability" => format_ha(config),
          "Tags" => tags_display,
          "Description" => config[:description] || "-"
        }
      end

      # ---------------------------
      # Display Methods (from Model)
      # ---------------------------

      # Returns display name, falling back to "VM-{vmid}" if name is nil.
      #
      # @return [String] display name
      def display_name
        vm.name || "VM-#{vm.vmid}"
      end

      # Returns CPU usage as percentage string.
      #
      # For running VMs, shows actual usage percentage.
      # For stopped VMs, shows "-" for usage but includes core count if available.
      #
      # @return [String] CPU percentage (e.g., "12%") or "-/4" for stopped VMs
      def cpu_percent
        return "-" if vm.maxcpu.nil?
        return "-/#{vm.maxcpu}" unless vm.running?
        return "-/#{vm.maxcpu}" if vm.cpu.nil?

        "#{(vm.cpu * 100).round}%/#{vm.maxcpu}"
      end

      # Returns memory used in GB.
      #
      # @return [Float, nil] memory used in GB, or nil if unavailable
      def memory_used_gb
        return nil if vm.mem.nil?

        (vm.mem.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns total memory in GB.
      #
      # @return [Float, nil] total memory in GB, or nil if unavailable
      def memory_total_gb
        return nil if vm.maxmem.nil?

        (vm.maxmem.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns memory formatted as "used/total GB".
      #
      # For running VMs, shows actual usage and total.
      # For stopped VMs, shows "-" for usage but includes total if available.
      #
      # @return [String] formatted memory (e.g., "2.1/4.0 GB") or "-/4.0 GB" for stopped VMs
      def memory_display
        return "-" if memory_total_gb.nil?
        return "-/#{memory_total_gb} GB" unless vm.running?
        return "-/#{memory_total_gb} GB" if memory_used_gb.nil?

        "#{memory_used_gb}/#{memory_total_gb} GB"
      end

      # Returns disk used in GB.
      #
      # @return [Integer, nil] disk used in GB, or nil if unavailable
      def disk_used_gb
        return nil if vm.disk.nil?

        (vm.disk.to_f / 1024 / 1024 / 1024).round
      end

      # Returns total disk in GB.
      #
      # @return [Integer, nil] total disk in GB, or nil if unavailable
      def disk_total_gb
        return nil if vm.maxdisk.nil?

        (vm.maxdisk.to_f / 1024 / 1024 / 1024).round
      end

      # Returns disk formatted as "used/total GB".
      #
      # @return [String] formatted disk (e.g., "15/50 GB") or "-" if unavailable
      def disk_display
        return "-" if disk_used_gb.nil?

        "#{disk_used_gb}/#{disk_total_gb} GB"
      end

      # Returns uptime in human-readable format.
      #
      # @return [String] formatted uptime (e.g., "15d 3h") or "-" if unavailable
      def uptime_human
        return "-" if vm.uptime.nil? || vm.uptime.zero?

        days = vm.uptime / 86_400
        hours = (vm.uptime % 86_400) / 3600
        minutes = (vm.uptime % 3600) / 60

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
        return [] if vm.tags.nil? || vm.tags.empty?

        vm.tags.split(";").map(&:strip)
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
        vm.template? ? "yes" : "-"
      end

      private

      # @return [Models::Vm] current VM model
      attr_reader :vm

      # Formats system section.
      #
      # @param config [Hash] VM config
      # @return [Hash] system info
      def format_system(config)
        bios = config[:bios] || "seabios"
        bios_display = bios == "ovmf" ? "UEFI (OVMF)" : "SeaBIOS"

        ostype = config[:ostype]
        ostype_display = format_ostype(ostype)

        {
          "BIOS" => bios_display,
          "Machine" => config[:machine] || "i440fx",
          "OS Type" => ostype_display
        }
      end

      # Formats OS type for display.
      #
      # @param ostype [String, nil] OS type from config
      # @return [String] formatted OS type
      def format_ostype(ostype)
        case ostype
        when "l26" then "l26 (Linux 2.6+)"
        when "l24" then "l24 (Linux 2.4)"
        when "win11" then "win11 (Windows 11)"
        when "win10" then "win10 (Windows 10)"
        when "win8" then "win8 (Windows 8)"
        when "win7" then "win7 (Windows 7)"
        when "wxp" then "wxp (Windows XP)"
        when "other" then "other"
        else ostype || "-"
        end
      end

      # Formats CPU section.
      #
      # @param config [Hash] VM config
      # @param status [Hash] VM status
      # @return [Hash] CPU info
      def format_cpu(config, status)
        usage = vm.running? && vm.cpu ? "#{(vm.cpu * 100).round}%" : "-"

        {
          "Sockets" => config[:sockets] || 1,
          "Cores" => config[:cores] || 1,
          "Type" => config[:cpu] || "kvm64",
          "Usage" => usage
        }
      end

      # Formats memory section.
      #
      # @param config [Hash] VM config
      # @param status [Hash] VM status
      # @return [Hash] memory info
      def format_memory(config, status)
        total_mb = config[:memory] || (vm.maxmem ? vm.maxmem / 1024 / 1024 : nil)
        total_gib = total_mb ? "#{(total_mb.to_f / 1024).round(1)} GiB" : "-"

        used_gib = vm.running? && vm.mem ? "#{(vm.mem.to_f / 1024 / 1024 / 1024).round(1)} GiB" : "-"

        usage = if vm.running? && vm.mem && vm.maxmem && vm.maxmem > 0
                  "#{((vm.mem.to_f / vm.maxmem) * 100).round}%"
                else
                  "-"
                end

        balloon = config[:balloon]
        balloon_display = if balloon && balloon > 0
                            "enabled (min: #{(balloon.to_f / 1024).round(1)} GiB)"
                          else
                            "disabled"
                          end

        {
          "Total" => total_gib,
          "Used" => used_gib,
          "Usage" => usage,
          "Balloon" => balloon_display
        }
      end

      # Parses disk configuration strings from VM config.
      #
      # Disk keys: scsi0-30, ide0-3, virtio0-15, sata0-5
      # Format: "storage:volume,size=X,format=Y,..."
      # Example: "local-lvm:vm-100-disk-0,size=50G,format=raw"
      #
      # @param config [Hash] VM config
      # @return [Array<Hash>, String] parsed disks or "-"
      def parse_disks(config)
        disk_keys = config.keys.select { |k| k.to_s.match?(/^(scsi|ide|virtio|sata)\d+$/) }
        return "-" if disk_keys.empty?

        disks = disk_keys.sort.map do |key|
          parse_disk_string(key.to_s, config[key])
        end.compact

        disks.empty? ? "-" : disks
      end

      # Parses a single disk config string.
      #
      # @param name [String] disk name (e.g., "scsi0")
      # @param value [String] disk config string
      # @return [Hash, nil] parsed disk info
      def parse_disk_string(name, value)
        return nil if value.nil? || value.to_s.empty?
        return nil if value.to_s == "none"

        # Format: "storage:volume,key=value,..."
        parts = value.to_s.split(",")
        storage_part = parts.first

        # Extract storage name (before colon)
        storage = storage_part.include?(":") ? storage_part.split(":").first : storage_part

        # Extract size and format from key=value pairs
        size = nil
        format = nil
        parts[1..].each do |part|
          key, val = part.split("=", 2)
          case key
          when "size" then size = val
          when "format" then format = val
          end
        end

        {
          "NAME" => name,
          "SIZE" => size || "-",
          "STORAGE" => storage,
          "FORMAT" => format || "-"
        }
      end

      # Formats network section with IP addresses from agent.
      #
      # Network keys: net0-31
      # Format: "model=X,bridge=Y,macaddr=Z,..."
      # Example: "virtio=BC:24:11:AA:BB:CC,bridge=vmbr0"
      #
      # @param config [Hash] VM config
      # @param agent_ips [Array<Hash>, nil] agent network interfaces
      # @return [Array<Hash>, String] parsed networks or "-"
      def format_network(config, agent_ips)
        net_keys = config.keys.select { |k| k.to_s.match?(/^net\d+$/) }
        return "-" if net_keys.empty?

        # Build MAC -> IP mapping from agent data
        mac_to_ip = build_mac_ip_map(agent_ips)

        networks = net_keys.sort.map do |key|
          parse_network_string(key.to_s, config[key], mac_to_ip)
        end.compact

        networks.empty? ? "-" : networks
      end

      # Builds MAC address to IP mapping from agent interfaces.
      #
      # @param agent_ips [Array<Hash>, nil] agent interfaces
      # @return [Hash] MAC -> IP mapping
      def build_mac_ip_map(agent_ips)
        return {} if agent_ips.nil?

        map = {}
        agent_ips.each do |iface|
          mac = iface[:"hardware-address"]&.downcase
          next if mac.nil?

          # Find first non-loopback IPv4 address
          ip_addrs = iface[:"ip-addresses"] || []
          ipv4 = ip_addrs.find { |a| a[:"ip-address-type"] == "ipv4" && a[:"ip-address"] != "127.0.0.1" }
          map[mac] = ipv4[:"ip-address"] if ipv4
        end
        map
      end

      # Parses a single network config string.
      #
      # @param name [String] net name (e.g., "net0")
      # @param value [String] network config string
      # @param mac_to_ip [Hash] MAC -> IP mapping
      # @return [Hash, nil] parsed network info
      def parse_network_string(name, value, mac_to_ip)
        return nil if value.nil? || value.to_s.empty?

        # Format: "model=MAC,bridge=X,..." or "virtio=MAC,bridge=X,..."
        parts = value.to_s.split(",")

        model = nil
        mac = nil
        bridge = nil

        parts.each do |part|
          key, val = part.split("=", 2)
          case key
          when "bridge" then bridge = val
          when "virtio", "e1000", "rtl8139", "vmxnet3"
            model = key
            mac = val&.upcase
          when "model" then model = val
          when "macaddr" then mac = val&.upcase
          end
        end

        # Look up IP from agent data
        ip = mac ? mac_to_ip[mac.downcase] : nil

        {
          "NAME" => name,
          "MODEL" => model || "-",
          "BRIDGE" => bridge || "-",
          "MAC" => mac || "-",
          "IP" => ip || "-"
        }
      end

      # Formats snapshots for table display.
      #
      # @param snapshots [Array<Hash>, nil] snapshots
      # @return [Array<Hash>, String] formatted snapshots or message
      def format_snapshots(snapshots)
        return "No snapshots" if snapshots.nil? || snapshots.empty?

        snapshots.map do |snap|
          snaptime = snap[:snaptime]
          date = snaptime ? Time.at(snaptime).strftime("%Y-%m-%d %H:%M:%S") : "-"

          {
            "NAME" => snap[:name],
            "DATE" => date,
            "VMSTATE" => snap[:vmstate] ? "yes" : "no",
            "DESCRIPTION" => snap[:description] || "-"
          }
        end
      end

      # Formats runtime section (only for running VMs).
      #
      # @param status [Hash] VM status
      # @return [Hash, String] runtime info or "-"
      def format_runtime(status)
        return "-" unless vm.running?

        {
          "Uptime" => uptime_human,
          "PID" => status[:pid] || "-",
          "QEMU Version" => status[:"running-qemu"] || "-",
          "Machine Type" => status[:"running-machine"] || "-"
        }
      end

      # Formats network I/O section (only for running VMs).
      #
      # @return [Hash, String] network I/O or "-"
      def format_network_io
        return "-" unless vm.running?

        {
          "Received" => format_bytes(vm.netin),
          "Transmitted" => format_bytes(vm.netout)
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

      # Formats HA section.
      #
      # @param config [Hash] VM config
      # @return [Hash] HA info
      def format_ha(config)
        {
          "State" => vm.hastate || "-",
          "Group" => config[:ha] || "-"
        }
      end
    end
  end
end
