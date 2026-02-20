# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class TemplateCommandTest < Minitest::Test
      # Test class that includes TemplateCommand for isolated testing
      class TestTemplateVm
        include TemplateCommand

        RESOURCE_TYPE = :vm
        SUPPORTED_RESOURCES = %w[vm].freeze
      end

      def setup
        @original_stdout = $stdout
        @original_stderr = $stderr
        $stdout = StringIO.new
        $stderr = StringIO.new
      end

      def teardown
        $stdout = @original_stdout
        $stderr = @original_stderr
      end

      def test_convert_single_returns_error_for_running_vm_without_force
        repo = Object.new
        resource = build_resource(status: "running", vmid: 100, name: "test-vm", node: "pve1")

        cmd = TestTemplateVm.new("vm", ["100"], {}, {})
        result = cmd.send(:convert_single, repo, resource)

        refute result.successful?
        assert_includes result.error, "is running"
        assert_includes result.error, "--force"
      end

      def test_convert_single_stops_running_vm_with_force
        task = Models::Task.new(
          upid: "UPID:pve1:00001234:12345678:67890ABC:qmstop:100:root@pam:",
          status: "stopped",
          exitstatus: "OK"
        )

        repo = Object.new
        def repo.stop(vmid, node)
          "UPID:pve1:00001234:12345678:67890ABC:qmstop:100:root@pam:"
        end
        def repo.convert_to_template(vmid, node, disk: nil) = nil

        task_repo = Object.new
        task_repo.define_singleton_method(:wait) { |_upid, **_opts| task }

        resource = build_resource(status: "running", vmid: 100, name: "test-vm", node: "pve1")

        cmd = TestTemplateVm.new("vm", ["100"], { force: true }, {})
        cmd.instance_variable_set(:@task_repository, task_repo)
        result = cmd.send(:convert_single, repo, resource)

        assert result.successful?
      end

      def test_convert_single_returns_error_when_stop_fails
        task = Models::Task.new(
          upid: "UPID:pve1:00001234:12345678:67890ABC:qmstop:100:root@pam:",
          status: "stopped",
          exitstatus: "command failed"
        )

        repo = Object.new
        def repo.stop(vmid, node)
          "UPID:pve1:00001234:12345678:67890ABC:qmstop:100:root@pam:"
        end

        task_repo = Object.new
        task_repo.define_singleton_method(:wait) { |_upid, **_opts| task }

        resource = build_resource(status: "running", vmid: 100, name: "test-vm", node: "pve1")

        cmd = TestTemplateVm.new("vm", ["100"], { force: true }, {})
        cmd.instance_variable_set(:@task_repository, task_repo)
        result = cmd.send(:convert_single, repo, resource)

        refute result.successful?
        assert_includes result.error, "Failed to stop"
      end

      def test_convert_single_converts_stopped_vm
        repo = Object.new
        def repo.convert_to_template(vmid, node, disk: nil) = nil

        resource = build_resource(status: "stopped", vmid: 100, name: "test-vm", node: "pve1")

        cmd = TestTemplateVm.new("vm", ["100"], {}, {})
        result = cmd.send(:convert_single, repo, resource)

        assert result.successful?
      end

      private

      # Builds a mock resource with the required attributes.
      # Uses a Struct to avoid complex mock setup.
      def build_resource(status:, vmid:, name:, node:)
        resource_class = Struct.new(:status, :vmid, :name, :node, :template, keyword_init: true) do
          def template?
            template || false
          end
        end
        resource_class.new(status: status, vmid: vmid, name: name, node: node, template: false)
      end
    end
  end
end
