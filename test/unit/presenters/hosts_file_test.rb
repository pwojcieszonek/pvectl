# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Presenters
    class HostsFileTest < Minitest::Test
      def setup
        @presenter = HostsFile.new
        @model = Pvectl::Models::HostsFile.new(
          node: "pve1",
          data: "127.0.0.1 localhost\n192.168.1.1 pve1\n",
          digest: "abc123"
        )
      end

      def test_columns
        assert_equal %w[NODE LINES DIGEST], @presenter.columns
      end

      def test_to_row
        row = @presenter.to_row(@model)
        assert_equal ["pve1", "2", "abc123"], row
      end

      def test_to_hash_exposes_raw_data
        h = @presenter.to_hash(@model)
        assert_equal "pve1", h["node"]
        assert_match(/127\.0\.0\.1 localhost/, h["data"])
        assert_equal "abc123", h["digest"]
      end

      def test_to_description_includes_content
        d = @presenter.to_description(@model)
        assert_equal "pve1", d["Node"]
        assert_equal "abc123", d["Digest"]
        assert_equal "2", d["Lines"]
        assert_match(/127\.0\.0\.1 localhost/, d["Content"])
      end

      def test_to_description_empty_content
        empty = Pvectl::Models::HostsFile.new(node: "pve1")
        d = @presenter.to_description(empty)
        assert_equal "(empty)", d["Content"]
      end
    end
  end
end
