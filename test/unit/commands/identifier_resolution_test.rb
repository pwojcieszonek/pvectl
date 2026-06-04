# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class IdentifierResolutionTest < Minitest::Test
      Model = Struct.new(:vmid, :name, :node)

      class FakeRepo
        def initialize(models) = @models = models
        def list(node: nil)
          node ? @models.select { |m| m.node == node } : @models
        end
      end

      # Host object mixing in the concern, exposing @resource_ids/@options.
      class Host
        include IdentifierResolution
        def initialize(ids, options) = (@resource_ids = ids; @options = options)
        def resolve(repo) = resolve_identifiers_against(repo)
      end

      def setup
        @repo = FakeRepo.new([
          Model.new(100, "web", "pve1"),
          Model.new(101, "cache", "pve2"),
          Model.new(105, "web", "pve2")
        ])
      end

      def test_resolves_mixed_ids_and_names_deduped
        host = Host.new(%w[100 web], {})
        result = host.resolve(@repo)
        assert_equal [100, 105], result.map(&:vmid).sort
      end

      def test_respects_node_filter
        host = Host.new(%w[web], { node: "pve2" })
        result = host.resolve(@repo)
        assert_equal [105], result.map(&:vmid)
      end
    end
  end
end
