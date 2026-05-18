# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    module Get
      module Handlers
        class HostsTest < Minitest::Test
          def test_list_requires_node
            handler = Hosts.new
            assert_raises(ArgumentError) { handler.list }
            assert_raises(ArgumentError) { handler.list(node: "") }
          end

          def test_list_returns_array_with_single_hosts_file
            repo = Minitest::Mock.new
            hf = Pvectl::Models::HostsFile.new(node: "pve1", data: "x\n", digest: "d1")
            repo.expect(:fetch, hf, ["pve1"])

            handler = Hosts.new(repository: repo)
            result = handler.list(node: "pve1")

            assert_kind_of Array, result
            assert_equal 1, result.length
            assert_same hf, result.first
            repo.verify
          end

          def test_presenter_returns_hosts_file_presenter
            handler = Hosts.new
            assert_kind_of Pvectl::Presenters::HostsFile, handler.presenter
          end

          def test_describe_with_positional_name
            repo = Minitest::Mock.new
            hf = Pvectl::Models::HostsFile.new(node: "pve1")
            repo.expect(:fetch, hf, ["pve1"])

            handler = Hosts.new(repository: repo)
            assert_same hf, handler.describe(name: "pve1")
            repo.verify
          end

          def test_describe_with_node_fallback
            repo = Minitest::Mock.new
            hf = Pvectl::Models::HostsFile.new(node: "pve1")
            repo.expect(:fetch, hf, ["pve1"])

            handler = Hosts.new(repository: repo)
            assert_same hf, handler.describe(name: nil, node: "pve1")
            repo.verify
          end

          def test_describe_requires_node
            handler = Hosts.new
            assert_raises(ArgumentError) { handler.describe(name: nil) }
          end
        end
      end
    end
  end
end
