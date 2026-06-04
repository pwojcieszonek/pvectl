# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    # Tests for Services::Cloudinit — orchestrates cloud-init operations
    # (regenerate ISO, pending changes, dump generated config) on VMs.
    class CloudinitTest < Minitest::Test
      VALID_TYPES = %w[user network meta].freeze

      def setup
        @vm_repo = Minitest::Mock.new
        @resolver = Minitest::Mock.new
        @service = Cloudinit.new(vm_repository: @vm_repo, resource_resolver: @resolver)
      end

      # ---------------------------
      # regenerate()
      # ---------------------------

      def test_regenerate_resolves_vmid_and_calls_repo
        @resolver.expect(:resolve_identifiers, [{ vmid: 100, node: "pve1", type: :qemu, name: "web" }], [[100]], type: :qemu)
        @vm_repo.expect(:cloudinit_regenerate, nil, ["pve1", 100])

        result = @service.regenerate(100)

        assert_equal({ vmid: 100, node: "pve1" }, result)
        @resolver.verify
        @vm_repo.verify
      end

      def test_regenerate_uses_explicit_node_when_provided
        @vm_repo.expect(:cloudinit_regenerate, nil, ["pve2", 100])

        result = @service.regenerate(100, node: "pve2")

        assert_equal({ vmid: 100, node: "pve2" }, result)
        @vm_repo.verify
      end

      def test_regenerate_raises_resource_not_found_when_vm_missing
        @resolver.expect(:resolve_identifiers, [], [[999]], type: :qemu)

        assert_raises(Pvectl::ResourceNotFoundError) do
          @service.regenerate(999)
        end
        @resolver.verify
      end

      def test_regenerate_raises_when_resolved_is_not_qemu
        @resolver.expect(:resolve_identifiers, [{ vmid: 200, node: "pve1", type: :lxc, name: "ct" }], [[200]], type: :qemu)

        assert_raises(Pvectl::ResourceNotFoundError) do
          @service.regenerate(200)
        end
      end

      # ---------------------------
      # pending()
      # ---------------------------

      def test_pending_resolves_vmid_and_returns_repo_result
        @resolver.expect(:resolve_identifiers, [{ vmid: 100, node: "pve1", type: :qemu, name: "web" }], [[100]], type: :qemu)
        entries = [
          { key: "user", value: "old", pending: "new" },
          { key: "ipconfig0", delete: 1 }
        ]
        @vm_repo.expect(:cloudinit_pending, entries, ["pve1", 100])

        result = @service.pending(100)

        assert_equal entries, result
        @resolver.verify
        @vm_repo.verify
      end

      def test_pending_uses_explicit_node
        @vm_repo.expect(:cloudinit_pending, [], ["pve2", 100])

        result = @service.pending(100, node: "pve2")

        assert_equal [], result
        @vm_repo.verify
      end

      def test_pending_raises_when_vm_missing
        @resolver.expect(:resolve_identifiers, [], [[999]], type: :qemu)

        assert_raises(Pvectl::ResourceNotFoundError) do
          @service.pending(999)
        end
      end

      # ---------------------------
      # dump()
      # ---------------------------

      def test_dump_returns_yaml_for_user_type
        @resolver.expect(:resolve_identifiers, [{ vmid: 100, node: "pve1", type: :qemu, name: "web" }], [[100]], type: :qemu)
        @vm_repo.expect(:cloudinit_dump, "#cloud-config\nuser: ubuntu\n", ["pve1", 100, "user"])

        assert_equal "#cloud-config\nuser: ubuntu\n", @service.dump(100, "user")

        @resolver.verify
        @vm_repo.verify
      end

      def test_dump_supports_all_valid_types
        VALID_TYPES.each do |type|
          @resolver.expect(:resolve_identifiers, [{ vmid: 100, node: "pve1", type: :qemu, name: "x" }], [[100]], type: :qemu)
          @vm_repo.expect(:cloudinit_dump, "data-#{type}", ["pve1", 100, type])

          assert_equal "data-#{type}", @service.dump(100, type)
        end
        @resolver.verify
        @vm_repo.verify
      end

      def test_dump_raises_on_invalid_type
        assert_raises(ArgumentError) do
          @service.dump(100, "invalid")
        end
      end

      def test_dump_raises_when_vm_missing
        @resolver.expect(:resolve_identifiers, [], [[999]], type: :qemu)

        assert_raises(Pvectl::ResourceNotFoundError) do
          @service.dump(999, "user")
        end
      end

      def test_dump_uses_explicit_node
        @vm_repo.expect(:cloudinit_dump, "yaml", ["pve9", 100, "network"])

        result = @service.dump(100, "network", node: "pve9")

        assert_equal "yaml", result
        @vm_repo.verify
      end
    end
  end
end
