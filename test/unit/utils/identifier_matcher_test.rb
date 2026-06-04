# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Utils
    class IdentifierMatcherTest < Minitest::Test
      # Minimal stand-in responding to #vmid and #name.
      Resource = Struct.new(:vmid, :name)

      def setup
        @resources = [
          Resource.new(100, "web"),
          Resource.new(101, "cache"),
          Resource.new(105, "web"),   # duplicate name (created outside pvectl)
          Resource.new(200, "100")    # name that looks like a VMID
        ]
      end

      def test_numeric_matches_vmid
        result = IdentifierMatcher.match("101", @resources)

        assert_equal [101], result.map(&:vmid)
      end

      def test_numeric_without_vmid_falls_back_to_name
        # No VMID 100? There IS vmid 100, so use a number with no VMID match.
        result = IdentifierMatcher.match("999", @resources)

        assert_empty result
      end

      def test_numeric_vmid_takes_precedence_over_name
        # "100" matches VMID 100 AND the name of vmid 200 — VMID wins.
        result = IdentifierMatcher.match("100", @resources)

        assert_equal [100], result.map(&:vmid)
      end

      def test_numeric_name_reachable_only_without_matching_vmid
        # Remove vmid 100 → "100" should now match the resource NAMED "100".
        resources = @resources.reject { |r| r.vmid == 100 }

        result = IdentifierMatcher.match("100", resources)

        assert_equal [200], result.map(&:vmid)
      end

      def test_non_numeric_matches_name
        result = IdentifierMatcher.match("cache", @resources)

        assert_equal [101], result.map(&:vmid)
      end

      def test_name_can_match_multiple
        result = IdentifierMatcher.match("web", @resources)

        assert_equal [100, 105], result.map(&:vmid).sort
      end

      def test_no_match_returns_empty
        result = IdentifierMatcher.match("nope", @resources)

        assert_empty result
      end

      def test_custom_extractors_for_hashes
        hashes = [{ vmid: 100, name: "web" }, { vmid: 101, name: "cache" }]

        result = IdentifierMatcher.match(
          "cache", hashes,
          id: ->(r) { r[:vmid] }, name: ->(r) { r[:name] }
        )

        assert_equal [101], result.map { |r| r[:vmid] }
      end

      def test_accepts_integer_identifier
        result = IdentifierMatcher.match(101, @resources)

        assert_equal [101], result.map(&:vmid)
      end
    end
  end
end
