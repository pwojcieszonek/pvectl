# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Models
    class ServiceTest < Minitest::Test
      def test_initializes_with_attributes
        svc = Service.new(
          service: "pveproxy",
          name: "pveproxy",
          state: "running",
          desc: "PVE API Proxy Server"
        )

        assert_equal "pveproxy", svc.service
        assert_equal "pveproxy", svc.name
        assert_equal "running", svc.state
        assert_equal "PVE API Proxy Server", svc.desc
      end

      def test_running_predicate
        running = Service.new(state: "running")
        stopped = Service.new(state: "stopped")

        assert running.running?
        refute stopped.running?
      end

      def test_name_falls_back_to_service
        svc = Service.new(service: "pvedaemon", name: nil)
        assert_equal "pvedaemon", svc.display_name
      end

      def test_active_state_and_unit_state
        svc = Service.new(
          service: "pveproxy",
          active_state: "active",
          unit_state: "enabled"
        )

        assert_equal "active", svc.active_state
        assert_equal "enabled", svc.unit_state
      end

      def test_dasherized_keys_from_api_are_accepted
        svc = Service.new(
          service: "pveproxy",
          :"active-state" => "active",
          :"unit-state" => "enabled"
        )

        assert_equal "active", svc.active_state
        assert_equal "enabled", svc.unit_state
      end

      def test_node_attribute
        svc = Service.new(service: "pveproxy", node: "pve1")
        assert_equal "pve1", svc.node
      end
    end
  end
end
