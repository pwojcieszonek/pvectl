# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Presenters
    class NodeOperationResultTest < Minitest::Test
      def setup
        @presenter = NodeOperationResult.new
      end

      def test_columns
        assert_equal %w[NODE OPERATION STATUS MESSAGE], @presenter.columns
      end

      def test_to_row_success
        node = Models::Node.new(name: "pve1")
        result = Models::NodeOperationResult.new(
          node_model: node, operation: :set, success: true
        )
        row = @presenter.to_row(result)
        assert_equal "pve1", row[0]
        assert_equal "set", row[1]
        assert_includes row[2], "Success"
        assert_equal "Success", row[3]
      end

      def test_to_row_failed
        node = Models::Node.new(name: "pve1")
        result = Models::NodeOperationResult.new(
          node_model: node, operation: :edit, success: false, error: "denied"
        )
        row = @presenter.to_row(result)
        assert_equal "edit", row[1]
        assert_equal "denied", row[3]
      end

      def test_to_hash
        node = Models::Node.new(name: "pve1")
        result = Models::NodeOperationResult.new(
          node_model: node, operation: :set, success: true
        )
        hash = @presenter.to_hash(result)
        assert_equal "pve1", hash["node"]
        assert_equal "set", hash["operation"]
        assert_equal "Success", hash["status"]
        assert_equal "Success", hash["message"]
      end

      def test_to_row_nil_node
        result = Models::NodeOperationResult.new(
          operation: :set, success: false, error: "not found"
        )
        row = @presenter.to_row(result)
        assert_equal "-", row[0]
      end
    end
  end
end
