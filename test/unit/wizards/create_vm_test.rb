# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Wizards
    class CreateVmTest < Minitest::Test
      # Simple prompt stub that returns pre-configured responses in order.
      # Supports ask, select, and yes? methods matching TTY::Prompt interface.
      class PromptStub
        def initialize(responses)
          @responses = responses
          @call_index = 0
        end

        def ask(_question, **_opts)
          next_response
        end

        def select(_question, _choices = nil, **_opts)
          next_response
        end

        def yes?(_question, **_opts)
          next_response
        end

        private

        def next_response
          response = @responses[@call_index]
          @call_index += 1
          response
        end
      end

      describe "#run" do
        it "collects basic params and returns hash when confirmed" do
          responses = [
            "web-server",  # VM name
            "pve1",        # Node
            2,             # CPU cores
            1,             # CPU sockets
            4096,          # Memory
            nil,           # Disk config (skip)
            nil,           # Network config (skip)
            "l26",         # OS type
            false,         # Agent?
            false,         # Start?
            true           # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateVm.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal "web-server", params[:name]
          assert_equal "pve1", params[:node]
          assert_equal 2, params[:cores]
          assert_equal 1, params[:sockets]
          assert_equal 4096, params[:memory]
          assert_equal "l26", params[:ostype]
          assert_nil params[:disks]
          assert_nil params[:nets]
        end

        it "returns nil when user cancels" do
          responses = [
            "web-server",  # VM name
            "pve1",        # Node
            1,             # CPU cores
            1,             # CPU sockets
            2048,          # Memory
            nil,           # Disk config (skip)
            nil,           # Network config (skip)
            "l26",         # OS type
            false,         # Agent?
            false,         # Start?
            false          # Confirm? -> NO
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateVm.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_nil params
        end

        it "collects disk config when provided" do
          responses = [
            "web-server",                   # VM name
            "pve1",                         # Node
            1,                              # CPU cores
            1,                              # CPU sockets
            2048,                           # Memory
            "storage=local-lvm,size=32G",   # Disk config
            false,                          # Another disk?
            nil,                            # Network config (skip)
            "l26",                          # OS type
            false,                          # Agent?
            false,                          # Start?
            true                            # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateVm.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal 1, params[:disks].length
          assert_equal "local-lvm", params[:disks][0][:storage]
          assert_equal "32G", params[:disks][0][:size]
        end

        it "collects multiple disks" do
          responses = [
            "db-server",                    # VM name
            "pve1",                         # Node
            4,                              # CPU cores
            1,                              # CPU sockets
            8192,                           # Memory
            "storage=local-lvm,size=32G",   # First disk
            true,                           # Another disk?
            "storage=ceph,size=100G",       # Second disk
            false,                          # Another disk?
            nil,                            # Network config (skip)
            "l26",                          # OS type
            false,                          # Agent?
            false,                          # Start?
            true                            # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateVm.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal 2, params[:disks].length
          assert_equal "local-lvm", params[:disks][0][:storage]
          assert_equal "ceph", params[:disks][1][:storage]
        end

        it "collects network config when provided" do
          responses = [
            "web-server",        # VM name
            "pve1",              # Node
            1,                   # CPU cores
            1,                   # CPU sockets
            2048,                # Memory
            nil,                 # Disk config (skip)
            "bridge=vmbr0",      # Network config
            false,               # Another net?
            "l26",               # OS type
            false,               # Agent?
            false,               # Start?
            true                 # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateVm.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal 1, params[:nets].length
          assert_equal "vmbr0", params[:nets][0][:bridge]
        end

        it "includes agent and start when selected" do
          responses = [
            "web-server",  # VM name
            "pve1",        # Node
            1,             # CPU cores
            1,             # CPU sockets
            2048,          # Memory
            nil,           # Disk (skip)
            nil,           # Net (skip)
            "l26",         # OS type
            true,          # Agent? -> YES
            true,          # Start? -> YES
            true           # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateVm.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal true, params[:agent]
          assert_equal true, params[:start]
        end

        it "does not include agent and start keys when not selected" do
          responses = [
            "web-server",  # VM name
            "pve1",        # Node
            1,             # CPU cores
            1,             # CPU sockets
            2048,          # Memory
            nil,           # Disk (skip)
            nil,           # Net (skip)
            "l26",         # OS type
            false,         # Agent? -> NO
            false,         # Start? -> NO
            true           # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateVm.new({}, {}, prompt: prompt)
          params = wizard.run

          refute params.key?(:agent)
          refute params.key?(:start)
        end

        it "uses node from options as default" do
          responses = [
            "web-server",  # VM name
            "pve2",        # Node (returned by ask with default)
            1,             # CPU cores
            1,             # CPU sockets
            2048,          # Memory
            nil,           # Disk (skip)
            nil,           # Net (skip)
            "l26",         # OS type
            false,         # Agent?
            false,         # Start?
            true           # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateVm.new({ node: "pve2" }, {}, prompt: prompt)
          params = wizard.run

          assert_equal "pve2", params[:node]
        end
      end
    end
  end
end
