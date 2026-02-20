# frozen_string_literal: true

require "test_helper"

class GetHandlersTemplatesTest < Minitest::Test
  def setup
    @vm_template = Pvectl::Models::Vm.new(
      vmid: 100, name: "base-ubuntu", status: "stopped",
      node: "pve1", type: "qemu", template: 1, maxdisk: 32_212_254_720
    )
    @vm_regular = Pvectl::Models::Vm.new(
      vmid: 101, name: "web-server", status: "running",
      node: "pve1", type: "qemu", template: 0
    )
    @ct_template = Pvectl::Models::Container.new(
      vmid: 200, name: "base-debian", status: "stopped",
      node: "pve2", type: "lxc", template: 1, maxdisk: 8_589_934_592
    )
    @ct_regular = Pvectl::Models::Container.new(
      vmid: 201, name: "app-ct", status: "running",
      node: "pve2", type: "lxc", template: 0
    )
  end

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Templates
  end

  def test_list_returns_only_templates
    handler = create_handler(
      vms: [@vm_template, @vm_regular],
      containers: [@ct_template, @ct_regular]
    )

    templates = handler.list

    assert_equal 2, templates.length
    assert templates.all?(&:template?)
  end

  def test_list_filters_by_type_vm
    handler = create_handler(
      vms: [@vm_template, @vm_regular],
      containers: [@ct_template, @ct_regular]
    )

    templates = handler.list(type_filter: "vm")

    assert_equal 1, templates.length
    assert_equal "qemu", templates.first.type
  end

  def test_list_filters_by_type_ct
    handler = create_handler(
      vms: [@vm_template, @vm_regular],
      containers: [@ct_template, @ct_regular]
    )

    templates = handler.list(type_filter: "ct")

    assert_equal 1, templates.length
    assert_equal "lxc", templates.first.type
  end

  def test_list_filters_by_node
    handler = create_handler(
      vms: [@vm_template],
      containers: [@ct_template]
    )

    templates = handler.list(node: "pve1")

    assert_equal 1, templates.length
    assert_equal "pve1", templates.first.node
  end

  def test_list_returns_empty_when_no_templates
    handler = create_handler(
      vms: [@vm_regular],
      containers: [@ct_regular]
    )

    templates = handler.list

    assert_empty templates
  end

  def test_presenter_returns_template_presenter
    handler = create_handler(vms: [], containers: [])

    assert_instance_of Pvectl::Presenters::Template, handler.presenter
  end

  def test_handler_is_registered_for_templates
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/templates.rb", __FILE__)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("templates")
  end

  def test_handler_is_registered_with_template_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/templates.rb", __FILE__)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("template")
  end

  def test_list_type_filter_accepts_qemu
    handler = create_handler(
      vms: [@vm_template],
      containers: [@ct_template]
    )

    templates = handler.list(type_filter: "qemu")

    assert_equal 1, templates.length
    assert_equal "qemu", templates.first.type
  end

  def test_list_type_filter_accepts_lxc
    handler = create_handler(
      vms: [@vm_template],
      containers: [@ct_template]
    )

    templates = handler.list(type_filter: "lxc")

    assert_equal 1, templates.length
    assert_equal "lxc", templates.first.type
  end

  def test_list_raises_on_unknown_type_filter
    handler = create_handler(
      vms: [@vm_template],
      containers: [@ct_template]
    )

    error = assert_raises(ArgumentError) { handler.list(type_filter: "bogus") }
    assert_match(/Unknown type: bogus/, error.message)
    assert_match(/Valid types:/, error.message)
  end

  def test_list_with_sort_by_name
    vm_t1 = Pvectl::Models::Vm.new(vmid: 100, name: "zebra", type: "qemu", node: "pve1", template: 1)
    vm_t2 = Pvectl::Models::Vm.new(vmid: 101, name: "alpha", type: "qemu", node: "pve1", template: 1)
    handler = create_handler(vms: [vm_t1, vm_t2], containers: [])

    templates = handler.list(sort: "name")

    assert_equal %w[alpha zebra], templates.map(&:name)
  end

  private

  def create_handler(vms:, containers:)
    vm_repo = MockVmRepo.new(vms)
    ct_repo = MockContainerRepo.new(containers)
    Pvectl::Commands::Get::Handlers::Templates.new(
      vm_repository: vm_repo,
      container_repository: ct_repo
    )
  end

  class MockVmRepo
    def initialize(vms)
      @vms = vms
    end

    def list(node: nil)
      result = @vms.dup
      result = result.select { |v| v.node == node } if node
      result
    end
  end

  class MockContainerRepo
    def initialize(containers)
      @containers = containers
    end

    def list(node: nil)
      result = @containers.dup
      result = result.select { |c| c.node == node } if node
      result
    end
  end
end
