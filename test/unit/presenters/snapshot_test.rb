# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Presenters
    class SnapshotTest < Minitest::Test
      def setup
        @presenter = Snapshot.new
        @snapshot = Models::Snapshot.new(
          name: "before-upgrade",
          vmid: 100,
          node: "pve1",
          resource_type: :qemu,
          snaptime: 1706800000,
          description: "Snapshot before system upgrade",
          vmstate: 1,
          parent: "base"
        )
      end

      def test_columns_returns_default_headers
        expected = %w[VMID NAME CREATED DESCRIPTION]
        assert_equal expected, @presenter.columns
      end

      def test_wide_columns_includes_extra
        expected = %w[VMID NAME CREATED DESCRIPTION TYPE VMSTATE PARENT]
        assert_equal expected, @presenter.wide_columns
      end

      def test_to_row_returns_values
        row = @presenter.to_row(@snapshot)

        assert_equal "100", row[0]
        assert_equal "before-upgrade", row[1]
        assert_match(/2024-02-01/, row[2])
        assert_equal "Snapshot before system upgrade", row[3]
      end

      def test_to_row_handles_nil_description
        snapshot = Models::Snapshot.new(name: "snap1", vmid: 100)
        row = @presenter.to_row(snapshot)

        assert_equal "-", row[3]
      end

      def test_to_row_handles_nil_snaptime
        snapshot = Models::Snapshot.new(name: "snap1", vmid: 100)
        row = @presenter.to_row(snapshot)

        assert_equal "-", row[2]
      end

      def test_to_wide_row_includes_extra_values
        row = @presenter.to_wide_row(@snapshot)

        assert_equal 7, row.length
        assert_equal "qemu", row[4]
        assert_equal "yes", row[5]
        assert_equal "base", row[6]
      end

      def test_extra_values_shows_no_for_vmstate_0
        snapshot = Models::Snapshot.new(name: "snap1", vmid: 100, vmstate: 0, resource_type: :lxc)
        row = @presenter.to_wide_row(snapshot)

        assert_equal "lxc", row[4]
        assert_equal "no", row[5]
      end

      def test_to_hash_returns_all_attributes
        hash = @presenter.to_hash(@snapshot)

        assert_equal 100, hash["vmid"]
        assert_equal "before-upgrade", hash["name"]
        assert_equal "pve1", hash["node"]
        assert_equal "qemu", hash["type"]
        assert_equal "Snapshot before system upgrade", hash["description"]
        assert_equal true, hash["vmstate"]
        assert_equal "base", hash["parent"]
        assert_match(/2024-02-01/, hash["created"])
      end
    end
  end
end
