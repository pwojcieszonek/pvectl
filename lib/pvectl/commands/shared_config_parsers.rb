# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared parser methods for CLI flag values.
    #
    # Provides reusable methods that parse --disk, --net, --cloud-init,
    # --mp flags through their respective Parsers. Included by create
    # and clone commands to avoid parser logic duplication.
    #
    # Expects +@options+ (a Hash of CLI flag values) to be available
    # in the including class.
    #
    # @example Including in a command class
    #   class CreateVm
    #     include SharedConfigParsers
    #     # ...
    #   end
    #
    module SharedConfigParsers
      # Parses VM disk configuration strings through the DiskConfig parser.
      #
      # @return [Array<Hash<Symbol, String>>] parsed disk configurations
      # @raise [ArgumentError] if any disk string is invalid
      def parse_vm_disks
        Array(@options[:disk]).map { |d| Parsers::DiskConfig.parse(d) }
      end

      # Parses VM network configuration strings through the NetConfig parser.
      #
      # @return [Array<Hash<Symbol, String>>] parsed network configurations
      # @raise [ArgumentError] if any net string is invalid
      def parse_vm_nets
        Array(@options[:net]).map { |n| Parsers::NetConfig.parse(n) }
      end

      # Parses cloud-init configuration string and converts to Proxmox params.
      #
      # @return [Hash<Symbol, untyped>] Proxmox-compatible cloud-init parameters
      # @raise [ArgumentError] if the cloud-init string is invalid
      def parse_vm_cloud_init
        config = Parsers::CloudInitConfig.parse(@options[:"cloud-init"])
        Parsers::CloudInitConfig.to_proxmox_params(config)
      end

      # Parses LXC mountpoint configuration strings through the LxcMountConfig parser.
      #
      # @return [Array<Hash<Symbol, String>>] parsed mountpoint configurations
      # @raise [ArgumentError] if any mountpoint string is invalid
      def parse_ct_mountpoints
        Array(@options[:mp]).map { |m| Parsers::LxcMountConfig.parse(m) }
      end

      # Parses LXC network configuration strings through the LxcNetConfig parser.
      #
      # @return [Array<Hash<Symbol, String>>] parsed network configurations
      # @raise [ArgumentError] if any net string is invalid
      def parse_ct_nets
        Array(@options[:net]).map { |n| Parsers::LxcNetConfig.parse(n) }
      end

      # Builds a VM config parameters hash from CLI options.
      #
      # Extracts VM-specific configuration keys from @options, parsing
      # disk, network, and cloud-init flags through their respective parsers.
      # Nil values are compacted out.
      #
      # @return [Hash<Symbol, untyped>] VM configuration parameters
      # @raise [ArgumentError] if any parser validation fails
      def build_vm_config_params
        params = {
          cores: @options[:cores],
          sockets: @options[:sockets],
          cpu_type: @options[:"cpu-type"],
          numa: @options[:numa],
          memory: @options[:memory],
          balloon: @options[:balloon],
          scsihw: @options[:scsihw],
          cdrom: @options[:cdrom],
          bios: @options[:bios],
          boot_order: @options[:"boot-order"],
          machine: @options[:machine],
          efidisk: @options[:efidisk],
          agent: @options[:agent],
          ostype: @options[:ostype],
          tags: @options[:tags]
        }

        params[:disks] = parse_vm_disks if @options[:disk]
        params[:nets] = parse_vm_nets if @options[:net]
        params[:cloud_init] = parse_vm_cloud_init if @options[:"cloud-init"]

        params.compact
      end

      # Builds a container config parameters hash from CLI options.
      #
      # Extracts container-specific configuration keys from @options, parsing
      # rootfs, mountpoint, and network flags through their respective parsers.
      # Nil values are compacted out.
      #
      # @return [Hash<Symbol, untyped>] container configuration parameters
      # @raise [ArgumentError] if any parser validation fails
      def build_ct_config_params
        params = {
          cores: @options[:cores],
          memory: @options[:memory],
          swap: @options[:swap],
          tags: @options[:tags],
          features: @options[:features],
          password: @options[:password],
          ssh_public_keys: @options[:"ssh-public-keys"],
          onboot: @options[:onboot],
          startup: @options[:startup]
        }

        params[:rootfs] = Parsers::LxcMountConfig.parse(@options[:rootfs]) if @options[:rootfs]
        params[:mountpoints] = parse_ct_mountpoints if @options[:mp]
        params[:nets] = parse_ct_nets if @options[:net]
        params[:privileged] = @options[:privileged]

        params.compact
      end
    end
  end
end
