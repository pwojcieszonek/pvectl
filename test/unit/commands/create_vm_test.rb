# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class CreateVmTest < Minitest::Test
      def setup
        @original_stderr = $stderr
        @original_stdout = $stdout
        $stderr = StringIO.new
        $stdout = StringIO.new
      end

      def teardown
        $stderr = @original_stderr
        $stdout = @original_stdout
      end

      # --- .execute ---

      def test_class_responds_to_execute
        assert_respond_to CreateVm, :execute
      end

      def test_returns_usage_error_when_name_is_missing_in_non_interactive_mode
        exit_code = CreateVm.execute([], { "no-interactive": true }, { output: "table" })

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "--name is required"
      end

      def test_returns_usage_error_when_disk_config_is_invalid
        options = { "no-interactive": true, name: "test", disk: ["bad_format"] }
        exit_code = CreateVm.execute([], options, { output: "table" })

        assert_equal ExitCodes::USAGE_ERROR, exit_code
      end

      def test_returns_usage_error_when_net_config_is_invalid
        options = { "no-interactive": true, name: "test", net: ["bad_format"] }
        exit_code = CreateVm.execute([], options, { output: "table" })

        assert_equal ExitCodes::USAGE_ERROR, exit_code
      end

      # --- #interactive_mode? ---

      def test_interactive_mode_returns_true_when_interactive_flag_is_set
        cmd = CreateVm.new([], { interactive: true }, {})
        assert cmd.send(:interactive_mode?)
      end

      def test_interactive_mode_returns_false_when_no_interactive_flag_is_set
        cmd = CreateVm.new([], { "no-interactive": true }, {})
        refute cmd.send(:interactive_mode?)
      end

      def test_interactive_mode_returns_false_when_name_is_provided
        cmd = CreateVm.new([], { name: "test" }, {})
        refute cmd.send(:interactive_mode?)
      end

      # --- #build_params_from_flags ---

      def test_builds_params_with_basic_options
        options = {
          name: "web", node: "pve1", cores: 4, memory: 4096,
          ostype: "l26", "no-interactive": true
        }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal "web", params[:name]
        assert_equal "pve1", params[:node]
        assert_equal 4, params[:cores]
        assert_equal 4096, params[:memory]
        assert_equal "l26", params[:ostype]
      end

      def test_parses_vmid_from_args
        options = { name: "web", node: "pve1", "no-interactive": true }
        cmd = CreateVm.new(["100"], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal 100, params[:vmid]
      end

      def test_parses_disk_flags_into_structured_configs
        options = {
          name: "web", node: "pve1",
          disk: ["storage=local-lvm,size=32G"],
          "no-interactive": true
        }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal 1, params[:disks].length
        assert_equal "local-lvm", params[:disks][0][:storage]
        assert_equal "32G", params[:disks][0][:size]
      end

      def test_parses_multiple_disk_flags
        options = {
          name: "web", node: "pve1",
          disk: ["storage=local-lvm,size=32G", "storage=ceph,size=100G"],
          "no-interactive": true
        }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal 2, params[:disks].length
        assert_equal "local-lvm", params[:disks][0][:storage]
        assert_equal "ceph", params[:disks][1][:storage]
      end

      def test_parses_net_flags_into_structured_configs
        options = {
          name: "web", node: "pve1",
          net: ["bridge=vmbr0,model=virtio"],
          "no-interactive": true
        }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal 1, params[:nets].length
        assert_equal "vmbr0", params[:nets][0][:bridge]
      end

      def test_parses_cloud_init_flag_into_proxmox_params
        options = {
          name: "web", node: "pve1",
          "cloud-init": "user=admin,ip=dhcp",
          "no-interactive": true
        }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal "admin", params[:cloud_init][:ciuser]
        assert_equal "ip=dhcp", params[:cloud_init][:ipconfig0]
      end

      def test_compacts_nil_values
        options = { name: "web", node: "pve1", "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        refute params.key?(:cores)
        refute params.key?(:memory)
        refute params.key?(:disks)
        refute params.key?(:nets)
        refute params.key?(:cloud_init)
      end

      def test_includes_all_cpu_and_memory_params
        options = {
          name: "web", node: "pve1",
          cores: 8, sockets: 2, "cpu-type": "host",
          numa: true, memory: 16384, balloon: 8192,
          "no-interactive": true
        }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal 8, params[:cores]
        assert_equal 2, params[:sockets]
        assert_equal "host", params[:cpu_type]
        assert_equal true, params[:numa]
        assert_equal 16384, params[:memory]
        assert_equal 8192, params[:balloon]
      end

      def test_includes_boot_and_bios_params
        options = {
          name: "web", node: "pve1",
          bios: "ovmf", "boot-order": "scsi0;net0",
          machine: "q35", efidisk: "local-lvm:1",
          "no-interactive": true
        }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal "ovmf", params[:bios]
        assert_equal "scsi0;net0", params[:boot_order]
        assert_equal "q35", params[:machine]
        assert_equal "local-lvm:1", params[:efidisk]
      end

      def test_includes_misc_params
        options = {
          name: "web", node: "pve1",
          scsihw: "virtio-scsi-pci", cdrom: "local:iso/ubuntu.iso",
          agent: true, tags: "prod;web", pool: "production",
          description: "Web server VM",
          "no-interactive": true
        }
        cmd = CreateVm.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal "virtio-scsi-pci", params[:scsihw]
        assert_equal "local:iso/ubuntu.iso", params[:cdrom]
        assert_equal true, params[:agent]
        assert_equal "prod;web", params[:tags]
        assert_equal "production", params[:pool]
        assert_equal "Web server VM", params[:description]
      end

      # --- #service_options ---

      def test_service_options_includes_timeout_when_set
        cmd = CreateVm.new([], { timeout: 600 }, {})
        assert_equal 600, cmd.send(:service_options)[:timeout]
      end

      def test_service_options_includes_async_when_set
        cmd = CreateVm.new([], { async: true }, {})
        assert_equal true, cmd.send(:service_options)[:async]
      end

      def test_service_options_includes_start_when_set
        cmd = CreateVm.new([], { start: true }, {})
        assert_equal true, cmd.send(:service_options)[:start]
      end

      def test_service_options_returns_empty_hash_when_nothing_set
        cmd = CreateVm.new([], {}, {})
        assert_equal({}, cmd.send(:service_options))
      end

      # --- #perform_interactive (start extraction) ---

      def test_perform_interactive_extracts_start_from_wizard_params
        options = { interactive: true, yes: true }
        cmd = CreateVm.new([], options, { output: "table" })

        mock_wizard = Minitest::Mock.new
        mock_wizard.expect(:run, { name: "web", node: "pve1", start: true })

        Pvectl::Wizards::CreateVm.stub(:new, mock_wizard) do
          # perform_create_with_params will fail on load_config, which is fine
          # we just need to verify start was extracted before it gets there
          cmd.send(:perform_interactive)
        rescue StandardError
          # Expected: config loading will fail in test environment
        end

        assert_equal true, options[:start]
        mock_wizard.verify
      end

      # --- #display_summary_and_confirm ---

      def test_display_summary_skips_prompt_when_yes_flag_is_set
        options = { yes: true, "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = { name: "web", node: "pve1" }

        result = cmd.send(:display_summary_and_confirm, params)

        assert_nil result
        assert_includes $stdout.string, "Create VM - Summary"
        assert_includes $stdout.string, "web"
      end

      def test_display_summary_shows_dry_run_notice
        options = { yes: true, "dry-run": true, "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = { name: "web", node: "pve1" }

        cmd.send(:display_summary_and_confirm, params)

        assert_includes $stdout.string, "dry-run"
      end

      def test_display_summary_shows_auto_vmid_when_not_set
        options = { yes: true, "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = { name: "web", node: "pve1" }

        cmd.send(:display_summary_and_confirm, params)

        assert_includes $stdout.string, "(auto)"
      end

      def test_display_summary_shows_vmid_when_set
        options = { yes: true, "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = { vmid: 100, name: "web", node: "pve1" }

        cmd.send(:display_summary_and_confirm, params)

        assert_includes $stdout.string, "100"
      end

      def test_display_summary_shows_disk_info
        options = { yes: true, "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = {
          name: "web", node: "pve1",
          disks: [{ storage: "local-lvm", size: "32G" }]
        }

        cmd.send(:display_summary_and_confirm, params)

        assert_includes $stdout.string, "local-lvm"
        assert_includes $stdout.string, "32G"
      end

      def test_display_summary_shows_net_info
        options = { yes: true, "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = {
          name: "web", node: "pve1",
          nets: [{ bridge: "vmbr0", model: "virtio" }]
        }

        cmd.send(:display_summary_and_confirm, params)

        assert_includes $stdout.string, "vmbr0"
      end

      def test_display_summary_returns_cancelled_when_user_declines
        options = { "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = { name: "web", node: "pve1" }

        $stdin = StringIO.new("n\n")
        result = cmd.send(:display_summary_and_confirm, params)
        $stdin = STDIN

        assert_equal :cancelled, result
      end

      def test_display_summary_returns_nil_when_user_confirms
        options = { "no-interactive": true }
        cmd = CreateVm.new([], options, {})
        params = { name: "web", node: "pve1" }

        $stdin = StringIO.new("y\n")
        result = cmd.send(:display_summary_and_confirm, params)
        $stdin = STDIN

        assert_nil result
      end
    end
  end
end
