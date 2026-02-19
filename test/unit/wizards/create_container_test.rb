# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Wizards
    class CreateContainerTest < Minitest::Test
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
            "web-ct",                              # Hostname
            "local:vztmpl/debian-12.tar.zst",      # OS template
            "pve1",                                 # Node
            2,                                      # CPU cores
            2048,                                   # Memory
            512,                                    # Swap
            "storage=local-lvm,size=8G",            # Root FS
            nil,                                    # Mountpoint (skip)
            nil,                                    # Network (skip)
            true,                                   # Unprivileged?
            false,                                  # Start?
            true                                    # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateContainer.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal "web-ct", params[:hostname]
          assert_equal "local:vztmpl/debian-12.tar.zst", params[:ostemplate]
          assert_equal "pve1", params[:node]
          assert_equal 2, params[:cores]
          assert_equal 2048, params[:memory]
          assert_equal 512, params[:swap]
        end

        it "returns nil when user cancels" do
          responses = [
            "web-ct",                              # Hostname
            "local:vztmpl/debian-12.tar.zst",      # OS template
            "pve1",                                 # Node
            1,                                      # CPU cores
            512,                                    # Memory
            512,                                    # Swap
            "storage=local-lvm,size=8G",            # Root FS
            nil,                                    # Mountpoint (skip)
            nil,                                    # Network (skip)
            true,                                   # Unprivileged?
            false,                                  # Start?
            false                                   # Confirm? -> NO
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateContainer.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_nil params
        end

        it "collects rootfs config" do
          responses = [
            "ct",                                   # Hostname
            "t",                                    # OS template
            "pve1",                                 # Node
            1,                                      # CPU cores
            512,                                    # Memory
            512,                                    # Swap
            "storage=local-lvm,size=8G",            # Root FS
            nil,                                    # Mountpoint (skip)
            nil,                                    # Network (skip)
            true,                                   # Unprivileged?
            false,                                  # Start?
            true                                    # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateContainer.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal "local-lvm", params[:rootfs][:storage]
          assert_equal "8G", params[:rootfs][:size]
        end

        it "collects mountpoint config" do
          responses = [
            "ct",                                   # Hostname
            "t",                                    # OS template
            "pve1",                                 # Node
            1,                                      # CPU cores
            512,                                    # Memory
            512,                                    # Swap
            "storage=local-lvm,size=8G",            # Root FS
            "mp=/mnt/data,storage=local-lvm,size=32G", # Mountpoint
            false,                                  # Another mount?
            nil,                                    # Network (skip)
            true,                                   # Unprivileged?
            false,                                  # Start?
            true                                    # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateContainer.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal 1, params[:mountpoints].length
          assert_equal "/mnt/data", params[:mountpoints][0][:mp]
        end

        it "collects network config" do
          responses = [
            "ct",                                   # Hostname
            "t",                                    # OS template
            "pve1",                                 # Node
            1,                                      # CPU cores
            512,                                    # Memory
            512,                                    # Swap
            "storage=local-lvm,size=8G",            # Root FS
            nil,                                    # Mountpoint (skip)
            "bridge=vmbr0,ip=dhcp",                 # Network
            false,                                  # Another net?
            true,                                   # Unprivileged?
            false,                                  # Start?
            true                                    # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateContainer.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal 1, params[:nets].length
          assert_equal "vmbr0", params[:nets][0][:bridge]
        end

        it "includes start when selected" do
          responses = [
            "ct", "t", "pve1", 1, 512, 512,
            "storage=local-lvm,size=8G",
            nil, nil, true,
            true,   # Start? -> YES
            true    # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateContainer.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal true, params[:start]
        end

        it "sets privileged when unprivileged is declined" do
          responses = [
            "ct", "t", "pve1", 1, 512, 512,
            "storage=local-lvm,size=8G",
            nil, nil,
            false,  # Unprivileged? -> NO (meaning privileged)
            false,  # Start?
            true    # Confirm?
          ]
          prompt = PromptStub.new(responses)
          wizard = CreateContainer.new({}, {}, prompt: prompt)
          params = wizard.run

          assert_equal true, params[:privileged]
        end
      end
    end
  end
end
