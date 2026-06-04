# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class ValidatesNameUniquenessTest < Minitest::Test
      # Host exposing @name_resolver and the private helper.
      class Host
        include ValidatesNameUniqueness
        def initialize(resolver) = @name_resolver = resolver
        def check(name, except_vmid: nil) = ensure_name_available!(name, except_vmid: except_vmid)
      end

      def resolver_with(conflicts)
        r = Object.new
        r.define_singleton_method(:name_conflicts) { |_name, except_vmid: nil| conflicts }
        r
      end

      def test_passes_when_no_conflict
        host = Host.new(resolver_with([]))
        assert_nil host.check("web")  # no raise
      end

      def test_raises_on_conflict
        host = Host.new(resolver_with([{ vmid: 100, node: "pve1" }]))
        error = assert_raises(Pvectl::DuplicateNameError) { host.check("web") }
        assert_match(/already exists \(VMID 100 on pve1\)/, error.message)
      end

      def test_skips_when_no_resolver
        host = Host.new(nil)
        assert_nil host.check("web")  # backward-compatible: no resolver → no check
      end

      def test_skips_blank_name
        host = Host.new(resolver_with([{ vmid: 100, node: "pve1" }]))
        assert_nil host.check(nil)
        assert_nil host.check("")
      end
    end
  end
end
