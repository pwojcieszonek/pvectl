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
    end
  end
end
