# frozen_string_literal: true

require "set"

module Pvectl
  module Presenters
    # Presenter for QEMU virtual machines.
    #
    # Defines column layout and formatting for table output.
    # Used by formatters to render VM data in various formats.
    #
    # Standard columns: NAME, VMID, STATUS, NODE, CPU, MEMORY
    # Wide columns add: UPTIME, TEMPLATE, TAGS, DISK, IP, AGENT, HA, BACKUP
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
        %w[NAME VMID STATUS NODE CPU MEMORY]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[UPTIME TEMPLATE TAGS DISK IP AGENT HA BACKUP]
      end

      # Converts VM model to table row values.
      #
      # @param model [Models::Vm] VM model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @vm = model
        [
          display_name,
          vm.vmid.to_s,
          vm.status,
          vm.node,
          cpu_percent,
          memory_display
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
          uptime_human,
          template_display,
          tags_display,
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
      # Returns a structured Hash organized by Proxmox VE web UI tabs:
      # Summary, Hardware, Cloud-Init, Options, Task History, Snapshots,
      # Pending Changes. Nested Hashes create indented subsections.
      # Arrays of Hashes render as inline tables.
      #
      # @param model [Models::Vm] VM model with describe details
      # @return [Hash] structured hash for describe formatter
      def to_description(model)
        @vm = model
        @consumed_keys = Set.new
        data = vm.describe_data || {}
        config = data[:config] || {}
        status = data[:status] || {}

        consume(:name, :description, :tags, :pool, :template)

        {
          "Name" => display_name,
          "VMID" => vm.vmid,
          "Status" => vm.status,
          "Node" => vm.node,
          "Tags" => tags_display,
          "Description" => config[:description] || "-",
          "Summary" => format_summary(config, status),
          "Hardware" => format_hardware(config, data),
          "Cloud-Init" => format_cloud_init(config),
          "Options" => format_options(config),
          "Firewall" => format_firewall(data[:firewall]),
          "Task History" => format_task_history(data[:tasks]),
          "Snapshots" => format_snapshots(data[:snapshots]),
          "Pending Changes" => format_pending_changes(data[:pending]),
          "Additional Configuration" => format_remaining(config)
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

      private

      # @return [Models::Vm] current VM model
      attr_reader :vm

      alias resource vm

      # Formats Summary section (PVE Summary tab).
      #
      # Shows HA state, resource usage, and (for running VMs) runtime info
      # including uptime, PID, QEMU version, machine type, and I/O statistics.
      #
      # @param config [Hash] VM config
      # @param status [Hash] VM status
      # @return [Hash] summary info
      def format_summary(config, status)
        sockets = config[:sockets] || 1
        cores = config[:cores] || 1
        total_cpus = sockets * cores
        cpu_usage = vm.running? && vm.cpu ? "#{(vm.cpu * 100).round(2)}% of #{total_cpus} CPU(s)" : "-"

        mem_usage = if vm.running? && vm.mem && vm.maxmem && vm.maxmem > 0
                      pct = ((vm.mem.to_f / vm.maxmem) * 100).round(2)
                      "#{pct}% (#{format_bytes(vm.mem)} of #{format_bytes(vm.maxmem)})"
                    else
                      "-"
                    end

        bootdisk_size = find_bootdisk_size(config)

        result = { "HA State" => vm.hastate || "-", "CPU Usage" => cpu_usage,
                   "Memory Usage" => mem_usage, "Bootdisk Size" => bootdisk_size }
        if vm.running?
          result["Uptime"] = uptime_human
          result["PID"] = (status[:pid] || "-").to_s
          result["QEMU Version"] = status[:"running-qemu"] || "-"
          result["Machine Type"] = status[:"running-machine"] || "-"
          result["Network In"] = format_bytes(vm.netin)
          result["Network Out"] = format_bytes(vm.netout)
          result["Disk Read"] = format_bytes(status[:diskread])
          result["Disk Written"] = format_bytes(status[:diskwrite])
        end
        result
      end

      # Finds the bootdisk size from boot order config.
      #
      # Parses the boot order to find the first device, then extracts its
      # size from the disk config string. Falls back to maxdisk from model.
      #
      # @param config [Hash] VM config
      # @return [String] bootdisk size or "-"
      def find_bootdisk_size(config)
        boot = config[:boot]
        if boot
          first_dev = boot.to_s.sub(/^order=/, "").split(";").first
          if first_dev && config[first_dev.to_sym]
            disk_str = config[first_dev.to_sym].to_s
            size_part = disk_str.split(",").find { |p| p.start_with?("size=") }
            return size_part.sub("size=", "") if size_part
          end
        end
        vm.maxdisk ? format_bytes(vm.maxdisk) : "-"
      end

      # Formats Hardware section (PVE Hardware tab).
      #
      # Shows memory, balloon, processors, BIOS, machine type, display,
      # SCSI controller, disks, network, and peripheral devices.
      #
      # @param config [Hash] VM config
      # @param data [Hash] full describe data (for agent_ips)
      # @return [Hash] hardware info with mixed String values and Array sub-tables
      def format_hardware(config, data)
        consume(:bios, :machine, :scsihw, :memory, :balloon, :shares,
                :sockets, :cores, :cpu, :vcpus, :cpulimit, :cpuunits, :vga)

        # Memory line
        total_mb = config[:memory] || (vm.maxmem ? vm.maxmem / 1024 / 1024 : nil)
        memory_str = total_mb ? "#{(total_mb.to_f / 1024).round(2)} GiB" : "-"

        # Balloon line
        balloon = config[:balloon]
        balloon_str = if balloon && balloon > 0
                        "enabled (min: #{(balloon.to_f / 1024).round(1)} GiB)"
                      else
                        "disabled"
                      end

        # Processors line: "4 (2 sockets, 2 cores) [host]"
        sockets = config[:sockets] || 1
        cores = config[:cores] || 1
        cpu_type = config[:cpu] || "kvm64"
        total = sockets * cores
        processors_str = "#{total} (#{sockets} sockets, #{cores} cores) [#{cpu_type}]"

        # BIOS
        bios = config[:bios] || "seabios"
        bios_display = bios == "ovmf" ? "UEFI (OVMF)" : "SeaBIOS"

        # Machine
        machine_str = config[:machine] || "i440fx"

        {
          "Memory" => memory_str,
          "Balloon" => balloon_str,
          "Processors" => processors_str,
          "BIOS" => bios_display,
          "Machine" => machine_str,
          "Display" => config[:vga] || "Default",
          "SCSI Controller" => config[:scsihw] || "lsi",
          "EFI Disk" => format_efi_disk(config),
          "TPM" => format_tpm(config),
          "Disks" => parse_disks(config),
          "Network" => format_network(config, data[:agent_ips]),
          "USB Devices" => format_usb_devices(config),
          "PCI Passthrough" => format_pci_passthrough(config),
          "Serial Ports" => format_serial_ports(config),
          "Audio" => format_audio(config)
        }
      end

      # Formats Options section (PVE Options tab).
      #
      # Shows boot, startup, OS type, agent, security, and other VM options.
      #
      # @param config [Hash] VM config
      # @return [Hash] options info
      def format_options(config)
        consume(:onboot, :startup, :ostype, :boot, :tablet, :hotplug,
                :acpi, :kvm, :freeze, :localtime, :numa, :agent,
                :protection, :firewall, :lock, :hookscript,
                :args, :vmgenid, :meta, :ha)
        consume_matching(config, /^numa\d+$/)
        consume_matching(config, /^unused\d+$/)

        on_boot = config[:onboot] == 1 ? "Yes" : "No"

        startup = config[:startup]
        startup_display = startup ? startup.to_s : "-"

        ostype_display = format_ostype(config[:ostype])

        boot = config[:boot]
        boot_display = if boot
                         order = boot.to_s.sub(/^order=/, "").split(";").join(", ")
                         order.empty? ? "-" : order
                       else
                         "-"
                       end

        tablet = config[:tablet] == 0 ? "No" : "Yes"
        hotplug_raw = config[:hotplug]
        hotplug = if hotplug_raw
                    hotplug_raw.to_s == "0" ? "Disabled" : hotplug_raw.to_s.split(",").join(", ")
                  else
                    "disk, network, usb"
                  end
        acpi = config[:acpi] == 0 ? "No" : "Yes"
        kvm = config[:kvm] == 0 ? "No" : "Yes"
        freeze_cpu = config[:freeze] == 1 ? "Yes" : "No"
        localtime = config[:localtime] == 1 ? "Yes" : "Default"
        numa = config[:numa] == 1 ? "Yes" : "No"

        agent_display = format_agent_options(config)
        protection = config[:protection] == 1 ? "Yes" : "No"
        firewall = config[:firewall] == 1 ? "Yes" : "No"
        hookscript = config[:hookscript] || "-"

        {
          "Start at Boot" => on_boot,
          "Start/Shutdown Order" => startup_display,
          "OS Type" => ostype_display,
          "Boot Order" => boot_display,
          "Use Tablet for Pointer" => tablet,
          "Hotplug" => hotplug,
          "ACPI Support" => acpi,
          "KVM Hardware Virtualization" => kvm,
          "Freeze CPU at Startup" => freeze_cpu,
          "Use Local Time for RTC" => localtime,
          "NUMA" => numa,
          "QEMU Guest Agent" => agent_display,
          "Protection" => protection,
          "Firewall" => firewall,
          "Hookscript" => hookscript
        }
      end

      # Formats QEMU guest agent as sub-section Hash for Options.
      #
      # Matches PVE Options tab layout with separate fields for
      # enable/disable, guest-trim, and freeze-fs-on-backup.
      #
      # @param config [Hash] VM config
      # @return [Hash] agent options sub-section
      def format_agent_options(config)
        agent = config[:agent]
        unless agent
          return {
            "Use QEMU Guest Agent" => "No",
            "Run guest-trim after a disk move or VM migration" => "No",
            "Freeze/thaw guest filesystems on backup for consistency" => "No"
          }
        end

        parts = agent.to_s.split(",")
        enabled = parts.first == "1"

        opts = {}
        parts[1..].each { |p| k, v = p.split("=", 2); opts[k] = v }

        result = {
          "Use QEMU Guest Agent" => enabled ? "Yes" : "No",
          "Run guest-trim after a disk move or VM migration" => opts["fstrim_cloned_disks"] == "1" ? "Yes" : "No",
          "Freeze/thaw guest filesystems on backup for consistency" => opts["freeze-fs-on-backup"] == "1" ? "Yes" : "No"
        }
        result["Type"] = opts["type"] if opts["type"]
        result
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

      # Parses disk configuration strings from VM config.
      #
      # Disk keys: scsi0-30, ide0-3, virtio0-15, sata0-5
      # Format: "storage:volume,size=X,format=Y,..."
      # Example: "local-lvm:vm-100-disk-0,size=50G,format=raw"
      #
      # @param config [Hash] VM config
      # @return [Array<Hash>, String] parsed disks or "-"
      def parse_disks(config)
        consume_matching(config, /^(scsi|ide|virtio|sata)\d+$/)
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
        consume_matching(config, /^net\d+$/)
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

        parts = value.to_s.split(",")
        model = nil
        mac = nil
        bridge = nil
        firewall = "no"

        parts.each do |part|
          key, val = part.split("=", 2)
          case key
          when "bridge" then bridge = val
          when "firewall" then firewall = val == "1" ? "yes" : "no"
          when "virtio", "e1000", "rtl8139", "vmxnet3"
            model = key
            mac = val&.upcase
          when "model" then model = val
          when "macaddr" then mac = val&.upcase
          end
        end

        ip = mac ? mac_to_ip[mac.downcase] : nil

        {
          "NAME" => name,
          "MODEL" => model || "-",
          "BRIDGE" => bridge || "-",
          "FIREWALL" => firewall,
          "MAC" => mac || "-",
          "IP" => ip || "-"
        }
      end

      # Formats Cloud-Init section.
      #
      # Detects cloud-init presence by checking for CI config keys (ciuser,
      # sshkeys, etc.) OR a cloud-init drive (any disk with "cloudinit" in
      # the volume name). This matches PVE behavior where the Cloud-Init
      # tab appears when the drive exists, even without configuration.
      #
      # @param config [Hash] VM config
      # @return [Hash, String] cloud-init info or "-"
      def format_cloud_init(config)
        ci_keys = %i[citype ciuser cipassword cicustom ciupgrade searchdomain nameserver sshkeys]
        ipconfig_keys = config.keys.select { |k| k.to_s.match?(/^ipconfig\d+$/) }
        consume(*ci_keys)
        consume_matching(config, /^ipconfig\d+$/)

        ci_drive = config.keys.any? do |k|
          k.to_s.match?(/^(scsi|ide|virtio|sata)\d+$/) && config[k].to_s.include?("cloudinit")
        end
        has_ci = ci_keys.any? { |k| config[k] } || ipconfig_keys.any? || ci_drive
        return "-" unless has_ci

        result = {
          "User" => config[:ciuser] || "-",
          "Password" => config[:cipassword] ? "set" : "-",
          "DNS Server" => config[:nameserver] || "-",
          "Search Domain" => config[:searchdomain] || "-",
          "SSH Keys" => config[:sshkeys] ? "configured" : "-",
          "Upgrade Packages" => config[:ciupgrade] == 0 ? "No" : "Yes",
          "CI Type" => config[:citype] || "nocloud",
          "CI Custom" => config[:cicustom] || "-"
        }

        if ipconfig_keys.any?
          result["IP Config"] = ipconfig_keys.sort.map do |key|
            { "INTERFACE" => key.to_s.sub("ipconfig", "net"), "CONFIG" => config[key].to_s }
          end
        end

        result
      end

      # Formats USB devices section.
      #
      # @param config [Hash] VM config
      # @return [Array<Hash>, String] USB devices table or "-"
      def format_usb_devices(config)
        usb_keys = config.keys.select { |k| k.to_s.match?(/^usb\d+$/) }
        consume_matching(config, /^usb\d+$/)
        return "-" if usb_keys.empty?

        usb_keys.sort.map do |key|
          { "NAME" => key.to_s, "CONFIG" => config[key].to_s }
        end
      end

      # Formats PCI passthrough section.
      #
      # @param config [Hash] VM config
      # @return [Array<Hash>, String] PCI devices table or "-"
      def format_pci_passthrough(config)
        pci_keys = config.keys.select { |k| k.to_s.match?(/^hostpci\d+$/) }
        consume_matching(config, /^hostpci\d+$/)
        return "-" if pci_keys.empty?

        pci_keys.sort.map do |key|
          { "NAME" => key.to_s, "CONFIG" => config[key].to_s }
        end
      end

      # Formats serial ports section.
      #
      # @param config [Hash] VM config
      # @return [Array<Hash>, String] serial ports table or "-"
      def format_serial_ports(config)
        serial_keys = config.keys.select { |k| k.to_s.match?(/^serial\d+$/) }
        consume_matching(config, /^serial\d+$/)
        return "-" if serial_keys.empty?

        serial_keys.sort.map do |key|
          { "NAME" => key.to_s, "TYPE" => config[key].to_s }
        end
      end

      # Formats audio device section.
      #
      # @param config [Hash] VM config
      # @return [String] audio config or "-"
      def format_audio(config)
        consume(:audio0)
        config[:audio0]&.to_s || "-"
      end

      # Formats EFI disk section.
      #
      # @param config [Hash] VM config
      # @return [String] EFI disk info or "-"
      def format_efi_disk(config)
        consume(:efidisk0)
        config[:efidisk0]&.to_s || "-"
      end

      # Formats TPM section.
      #
      # @param config [Hash] VM config
      # @return [String] TPM info or "-"
      def format_tpm(config)
        consume(:tpmstate0)
        config[:tpmstate0]&.to_s || "-"
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

      # Formats pending configuration changes.
      #
      # @param pending [Array<Hash>, nil] pending changes from API
      # @return [Array<Hash>, String] pending changes table or "-"
      def format_pending_changes(pending)
        return "No pending changes" if pending.nil? || pending.empty?

        # Only show entries with actual pending changes (new value or deletion)
        changes = pending.select { |c| c.key?(:pending) || c[:delete] }
        return "No pending changes" if changes.empty?

        changes.map do |change|
          row = { "KEY" => change[:key].to_s, "CURRENT" => change[:value].to_s }
          row["PENDING"] = change[:pending].to_s if change.key?(:pending)
          row["DELETE"] = "yes" if change[:delete]
          row
        end
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
