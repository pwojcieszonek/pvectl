# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Presenters
    class TemplateTest < Minitest::Test
      def setup
        @presenter = Template.new
        @vm_template = Models::Vm.new(
          vmid: 100,
          name: "base-ubuntu",
          type: "qemu",
          node: "pve1",
          maxdisk: 32_212_254_720,
          template: 1,
          tags: "base;linux"
        )
        @ct_template = Models::Container.new(
          vmid: 200,
          name: "base-debian",
          type: "lxc",
          node: "pve2",
          maxdisk: 8_589_934_592,
          template: 1,
          tags: "base"
        )
      end

      def test_columns
        assert_equal %w[ID NAME TYPE NODE DISK TAGS], @presenter.columns
      end

      def test_to_row_for_vm_template
        row = @presenter.to_row(@vm_template)

        assert_equal "100", row[0]
        assert_equal "base-ubuntu", row[1]
        assert_equal "qemu", row[2]
        assert_equal "pve1", row[3]
        assert_equal "base;linux", row[5]
      end

      def test_to_row_for_ct_template
        row = @presenter.to_row(@ct_template)

        assert_equal "200", row[0]
        assert_equal "base-debian", row[1]
        assert_equal "lxc", row[2]
        assert_equal "pve2", row[3]
        assert_equal "base", row[5]
      end

      def test_to_hash_for_vm_template
        hash = @presenter.to_hash(@vm_template)

        assert_equal 100, hash["id"]
        assert_equal "base-ubuntu", hash["name"]
        assert_equal "qemu", hash["type"]
        assert_equal "pve1", hash["node"]
        assert_equal "base;linux", hash["tags"]
      end

      def test_to_row_handles_nil_name
        vm = Models::Vm.new(vmid: 100, type: "qemu", node: "pve1", template: 1)
        row = @presenter.to_row(vm)

        assert_equal "-", row[1]
      end

      def test_to_row_handles_nil_tags
        vm = Models::Vm.new(vmid: 100, name: "test", type: "qemu", node: "pve1", template: 1)
        row = @presenter.to_row(vm)

        assert_equal "-", row[5]
      end

      def test_to_row_formats_disk_in_gigabytes
        row = @presenter.to_row(@vm_template)

        # 32_212_254_720 bytes = 30.0G
        assert_equal "30.0G", row[4]
      end

      def test_to_row_formats_disk_in_megabytes
        vm = Models::Vm.new(vmid: 100, type: "qemu", node: "pve1", template: 1, maxdisk: 524_288_000)
        row = @presenter.to_row(vm)

        assert_equal "500.0M", row[4]
      end

      def test_to_row_handles_nil_disk
        vm = Models::Vm.new(vmid: 100, type: "qemu", node: "pve1", template: 1)
        row = @presenter.to_row(vm)

        assert_equal "-", row[4]
      end
    end
  end
end
