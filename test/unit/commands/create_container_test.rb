# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class CreateContainerTest < Minitest::Test
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
        assert_respond_to CreateContainer, :execute
      end

      def test_returns_usage_error_when_hostname_is_missing
        exit_code = CreateContainer.execute([], { "no-interactive": true, ostemplate: "t", rootfs: "storage=local-lvm,size=8G" }, { output: "table" })

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "--hostname is required"
      end

      def test_returns_usage_error_when_ostemplate_is_missing
        exit_code = CreateContainer.execute([], { "no-interactive": true, hostname: "ct", rootfs: "storage=local-lvm,size=8G" }, { output: "table" })

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "--ostemplate is required"
      end

      def test_returns_usage_error_when_rootfs_is_missing
        exit_code = CreateContainer.execute([], { "no-interactive": true, hostname: "ct", ostemplate: "t" }, { output: "table" })

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "--rootfs is required"
      end

      def test_returns_usage_error_when_net_config_is_invalid
        options = { "no-interactive": true, hostname: "ct", ostemplate: "t", rootfs: "storage=local-lvm,size=8G", net: ["bad_format"] }
        exit_code = CreateContainer.execute([], options, { output: "table" })

        assert_equal ExitCodes::USAGE_ERROR, exit_code
      end

      # --- #interactive_mode? ---

      def test_interactive_mode_returns_true_when_interactive_flag_is_set
        cmd = CreateContainer.new([], { interactive: true }, {})
        assert cmd.send(:interactive_mode?)
      end

      def test_interactive_mode_returns_false_when_no_interactive_flag_is_set
        cmd = CreateContainer.new([], { "no-interactive": true }, {})
        refute cmd.send(:interactive_mode?)
      end

      def test_interactive_mode_returns_false_when_hostname_is_provided
        cmd = CreateContainer.new([], { hostname: "ct" }, {})
        refute cmd.send(:interactive_mode?)
      end

      # --- #build_params_from_flags ---

      def test_builds_params_with_basic_options
        options = {
          hostname: "web-ct", node: "pve1",
          ostemplate: "local:vztmpl/debian-12.tar.zst",
          rootfs: "storage=local-lvm,size=8G",
          cores: 2, memory: 2048, swap: 512,
          "no-interactive": true
        }
        cmd = CreateContainer.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal "web-ct", params[:hostname]
        assert_equal "pve1", params[:node]
        assert_equal "local:vztmpl/debian-12.tar.zst", params[:ostemplate]
        assert_equal 2, params[:cores]
        assert_equal 2048, params[:memory]
        assert_equal 512, params[:swap]
      end

      def test_parses_ctid_from_args
        options = { hostname: "ct", ostemplate: "t", rootfs: "storage=local-lvm,size=8G", "no-interactive": true }
        cmd = CreateContainer.new(["200"], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal 200, params[:ctid]
      end

      def test_parses_rootfs_into_structured_config
        options = {
          hostname: "ct", ostemplate: "t",
          rootfs: "storage=local-lvm,size=8G",
          "no-interactive": true
        }
        cmd = CreateContainer.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal "local-lvm", params[:rootfs][:storage]
        assert_equal "8G", params[:rootfs][:size]
      end

      def test_parses_mountpoint_flags
        options = {
          hostname: "ct", ostemplate: "t",
          rootfs: "storage=local-lvm,size=8G",
          mp: ["mp=/mnt/data,storage=local-lvm,size=32G"],
          "no-interactive": true
        }
        cmd = CreateContainer.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal 1, params[:mountpoints].length
        assert_equal "/mnt/data", params[:mountpoints][0][:mp]
        assert_equal "local-lvm", params[:mountpoints][0][:storage]
      end

      def test_parses_net_flags
        options = {
          hostname: "ct", ostemplate: "t",
          rootfs: "storage=local-lvm,size=8G",
          net: ["bridge=vmbr0,name=eth0,ip=dhcp"],
          "no-interactive": true
        }
        cmd = CreateContainer.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal 1, params[:nets].length
        assert_equal "vmbr0", params[:nets][0][:bridge]
      end

      def test_includes_privileged_flag
        options = {
          hostname: "ct", ostemplate: "t",
          rootfs: "storage=local-lvm,size=8G",
          privileged: true,
          "no-interactive": true
        }
        cmd = CreateContainer.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal true, params[:privileged]
      end

      def test_includes_features
        options = {
          hostname: "ct", ostemplate: "t",
          rootfs: "storage=local-lvm,size=8G",
          features: "nesting=1,keyctl=1",
          "no-interactive": true
        }
        cmd = CreateContainer.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        assert_equal "nesting=1,keyctl=1", params[:features]
      end

      def test_compacts_nil_values
        options = {
          hostname: "ct", ostemplate: "t",
          rootfs: "storage=local-lvm,size=8G",
          "no-interactive": true
        }
        cmd = CreateContainer.new([], options, {})
        params = cmd.send(:build_params_from_flags)

        refute params.key?(:cores)
        refute params.key?(:mountpoints)
        refute params.key?(:nets)
      end

      # --- #service_options ---

      def test_service_options_includes_start_when_set
        cmd = CreateContainer.new([], { start: true }, {})
        assert_equal true, cmd.send(:service_options)[:start]
      end

      # --- #display_summary_and_confirm ---

      def test_display_summary_shows_container_info
        options = { yes: true, "no-interactive": true }
        cmd = CreateContainer.new([], options, {})
        params = {
          hostname: "web-ct", node: "pve1",
          ostemplate: "local:vztmpl/debian-12.tar.zst",
          rootfs: { storage: "local-lvm", size: "8G" }
        }

        cmd.send(:display_summary_and_confirm, params)

        assert_includes $stdout.string, "Create container"
        assert_includes $stdout.string, "web-ct"
        assert_includes $stdout.string, "debian-12"
      end

      def test_display_summary_shows_unprivileged_default
        options = { yes: true, "no-interactive": true }
        cmd = CreateContainer.new([], options, {})
        params = { hostname: "ct", node: "pve1", ostemplate: "t" }

        cmd.send(:display_summary_and_confirm, params)

        assert_includes $stdout.string, "Unpriv"
      end
    end
  end
end
