# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Presenters
    class VolumeOperationResultTest < Minitest::Test
      def setup
        @presenter = VolumeOperationResult.new
      end

      def test_columns
        assert_equal %w[NODE RESOURCE ID DISK OPERATION STATUS MESSAGE], @presenter.columns
      end

      def test_to_row_success
        volume = Models::Volume.new(
          node: "pve1", resource_type: "vm", resource_id: 100, name: "scsi0"
        )
        result = Models::VolumeOperationResult.new(
          volume: volume, operation: :set, success: true
        )
        row = @presenter.to_row(result)
        assert_equal "pve1", row[0]
        assert_equal "vm", row[1]
        assert_equal "100", row[2]
        assert_equal "scsi0", row[3]
        assert_equal "set", row[4]
        assert_includes row[5], "Success"
        assert_equal "Success", row[6]
      end

      def test_to_row_failed
        volume = Models::Volume.new(
          node: "pve1", resource_type: "vm", resource_id: 100, name: "scsi0"
        )
        result = Models::VolumeOperationResult.new(
          volume: volume, operation: :set, success: false, error: "size too small"
        )
        row = @presenter.to_row(result)
        assert_equal "size too small", row[6]
      end

      def test_to_hash
        volume = Models::Volume.new(
          node: "pve1", resource_type: "vm", resource_id: 100, name: "scsi0"
        )
        result = Models::VolumeOperationResult.new(
          volume: volume, operation: :set, success: true
        )
        hash = @presenter.to_hash(result)
        assert_equal "pve1", hash["node"]
        assert_equal "vm", hash["resource_type"]
        assert_equal 100, hash["resource_id"]
        assert_equal "scsi0", hash["disk"]
        assert_equal "set", hash["operation"]
        assert_equal "Success", hash["status"]
      end

      def test_to_row_nil_volume
        result = Models::VolumeOperationResult.new(
          operation: :set, success: false, error: "not found"
        )
        row = @presenter.to_row(result)
        assert_equal "-", row[0]
        assert_equal "-", row[1]
        assert_equal "-", row[2]
        assert_equal "-", row[3]
      end
    end
  end
end
