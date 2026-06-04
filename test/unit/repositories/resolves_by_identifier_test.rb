# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Repositories
    class ResolvesByIdentifierTest < Minitest::Test
      Model = Struct.new(:vmid, :name)

      # Minimal repo exposing #list and the module under test.
      class FakeRepo
        include ResolvesByIdentifier
        def initialize(models) = @models = models
        def list(node: nil) = @models
      end

      def setup
        @repo = FakeRepo.new([
          Model.new(100, "web"),
          Model.new(101, "cache"),
          Model.new(105, "web")
        ])
      end

      def test_resolve_identifier_by_name_returns_all
        result = @repo.resolve_identifier("web")
        assert_equal [100, 105], result.map(&:vmid).sort
      end

      def test_resolve_identifier_by_vmid
        result = @repo.resolve_identifier("101")
        assert_equal [101], result.map(&:vmid)
      end

      def test_resolve_one_returns_single_match
        assert_equal 101, @repo.resolve_one("cache").vmid
      end

      def test_resolve_one_returns_nil_when_none
        assert_nil @repo.resolve_one("ghost")
      end

      def test_resolve_one_raises_on_ambiguity
        error = assert_raises(Pvectl::AmbiguousIdentifierError) do
          @repo.resolve_one("web")
        end
        assert_match(/matches multiple resources/, error.message)
        assert_match(/100, 105/, error.message)
      end
    end
  end
end
