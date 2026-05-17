# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    # Tests for the `pvectl unlink disk vm` command.
    #
    # Verifies argument validation, confirmation prompting, --force/--yes flag
    # handling, and propagation to the underlying service.
    class UnlinkDiskVmTest < Minitest::Test
      def setup
        @original_stdin = $stdin
        @original_stderr = $stderr
        @original_stdout = $stdout
        $stderr = StringIO.new
        $stdout = StringIO.new
      end

      def teardown
        $stdin = @original_stdin
        $stderr = @original_stderr
        $stdout = @original_stdout
      end

      def test_returns_usage_error_when_no_vmid
        exit_code = UnlinkDiskVm.execute([], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "VMID required"
      end

      def test_returns_usage_error_when_no_disk_list
        exit_code = UnlinkDiskVm.execute(["100"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "Disk list required"
      end

      def test_returns_usage_error_when_vmid_is_not_numeric
        exit_code = UnlinkDiskVm.execute(["abc", "scsi1"], { yes: true }, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "Invalid VMID"
      end

      def test_unlinks_single_disk_with_yes_flag
        cmd = build_command(["100", "scsi1"], { yes: true })
        repo = StubRepo.new(vm: build_vm)
        cmd.instance_variable_set(:@repository, repo)

        exit_code = cmd.execute

        assert_equal ExitCodes::SUCCESS, exit_code
        assert_equal [["pve1", 100, "scsi1", { force: false }]], repo.calls
      end

      def test_unlinks_multiple_disks_comma_separated
        cmd = build_command(["100", "scsi1,virtio0"], { yes: true })
        repo = StubRepo.new(vm: build_vm)
        cmd.instance_variable_set(:@repository, repo)

        exit_code = cmd.execute

        assert_equal ExitCodes::SUCCESS, exit_code
        assert_equal [["pve1", 100, "scsi1,virtio0", { force: false }]], repo.calls
      end

      def test_propagates_force_flag_to_service
        cmd = build_command(["100", "scsi1"], { yes: true, force: true })
        repo = StubRepo.new(vm: build_vm)
        cmd.instance_variable_set(:@repository, repo)

        cmd.execute

        assert_equal [["pve1", 100, "scsi1", { force: true }]], repo.calls
      end

      def test_returns_not_found_when_vmid_not_resolved
        cmd = build_command(["999", "scsi1"], { yes: true })
        repo = StubRepo.new(vm: nil)
        cmd.instance_variable_set(:@repository, repo)

        exit_code = cmd.execute

        assert_equal ExitCodes::NOT_FOUND, exit_code
        assert_includes $stderr.string, "VM 999 not found"
        assert_empty repo.calls
      end

      def test_confirmation_declined_skips_unlink_and_returns_success
        cmd = build_command(["100", "scsi1"], {})
        repo = StubRepo.new(vm: build_vm)
        cmd.instance_variable_set(:@repository, repo)

        $stdin = StringIO.new("n\n")
        exit_code = cmd.execute

        assert_equal ExitCodes::SUCCESS, exit_code
        assert_empty repo.calls
        assert_includes $stdout.string, "About to unlink"
      end

      def test_confirmation_accepted_with_y_proceeds
        cmd = build_command(["100", "scsi1"], {})
        repo = StubRepo.new(vm: build_vm)
        cmd.instance_variable_set(:@repository, repo)

        $stdin = StringIO.new("y\n")
        exit_code = cmd.execute

        assert_equal ExitCodes::SUCCESS, exit_code
        assert_equal 1, repo.calls.size
      end

      def test_force_flag_shows_extra_warning_in_prompt
        cmd = build_command(["100", "scsi1"], { force: true })
        repo = StubRepo.new(vm: build_vm)
        cmd.instance_variable_set(:@repository, repo)

        $stdin = StringIO.new("n\n")
        cmd.execute

        assert_includes $stdout.string, "WARNING"
        assert_includes $stdout.string, "--force"
      end

      def test_yes_flag_skips_prompt
        cmd = build_command(["100", "scsi1"], { yes: true })
        repo = StubRepo.new(vm: build_vm)
        cmd.instance_variable_set(:@repository, repo)

        $stdin = StringIO.new("") # nothing on stdin
        exit_code = cmd.execute

        assert_equal ExitCodes::SUCCESS, exit_code
        refute_includes $stdout.string, "About to unlink"
      end

      private

      # Builds a stub command instance with stubbed config/resolver/output.
      def build_command(args, options)
        cmd = UnlinkDiskVm.new(args, options, {})
        cmd.define_singleton_method(:load_config) { nil }
        cmd.define_singleton_method(:resolve_node) { |_vmid| "pve1" }
        cmd.define_singleton_method(:output_result) { |_result| nil }
        cmd.define_singleton_method(:build_repository) { @repository }
        cmd
      end

      # Builds a VM model for tests.
      def build_vm
        Pvectl::Models::Vm.new(vmid: 100, name: "test-vm", status: "running", node: "pve1")
      end

      # Stub repository recording unlink_disks calls.
      class StubRepo
        attr_reader :calls

        def initialize(vm:)
          @vm = vm
          @calls = []
        end

        def get(_vmid)
          @vm
        end

        def unlink_disks(node, vmid, disk_ids, **opts)
          @calls << [node, vmid, disk_ids, opts]
          nil
        end
      end
    end
  end
end
