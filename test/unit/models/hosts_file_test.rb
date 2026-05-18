# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Models
    class HostsFileTest < Minitest::Test
      def test_default_data_is_empty_string
        hf = HostsFile.new(node: "pve1")
        assert_equal "", hf.data
        assert_nil hf.digest
        assert_equal 0, hf.line_count
      end

      def test_line_count_counts_lines
        hf = HostsFile.new(data: "a\nb\nc\n")
        assert_equal 3, hf.line_count
      end

      def test_accepts_string_keys
        hf = HostsFile.new("node" => "pve1", "data" => "x\n", "digest" => "d1")
        assert_equal "pve1", hf.node
        assert_equal "x\n", hf.data
        assert_equal "d1", hf.digest
      end
    end
  end
end
