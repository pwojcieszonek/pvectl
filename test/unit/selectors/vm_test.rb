# frozen_string_literal: true

require "test_helper"

class SelectorsVmTest < Minitest::Test
  def setup
    @vm1 = Pvectl::Models::Vm.new(
      vmid: 100, name: "web-prod-1", status: "running",
      node: "pve1", tags: "prod;web", pool: "production"
    )
    @vm2 = Pvectl::Models::Vm.new(
      vmid: 101, name: "web-prod-2", status: "running",
      node: "pve1", tags: "prod;web", pool: "production"
    )
    @vm3 = Pvectl::Models::Vm.new(
      vmid: 102, name: "db-dev", status: "stopped",
      node: "pve2", tags: "dev;database", pool: "development"
    )
    @vm4 = Pvectl::Models::Vm.new(
      vmid: 103, name: "cache-staging", status: "paused",
      node: "pve2", tags: nil, pool: nil
    )
    @all_vms = [@vm1, @vm2, @vm3, @vm4]
  end

  # Class structure
  def test_class_exists
    assert_kind_of Class, Pvectl::Selectors::Vm
  end

  def test_inherits_from_base
    assert Pvectl::Selectors::Vm < Pvectl::Selectors::Base
  end

  def test_supported_fields_constant
    assert_equal %w[status tags pool name], Pvectl::Selectors::Vm::SUPPORTED_FIELDS
  end

  # Status filtering
  def test_filter_by_status_running
    selector = Pvectl::Selectors::Vm.parse("status=running")
    result = selector.apply(@all_vms)
    assert_equal 2, result.size
    assert_equal [100, 101], result.map(&:vmid)
  end

  def test_filter_by_status_stopped
    selector = Pvectl::Selectors::Vm.parse("status=stopped")
    result = selector.apply(@all_vms)
    assert_equal 1, result.size
    assert_equal 102, result.first.vmid
  end

  def test_filter_by_status_not_equal
    selector = Pvectl::Selectors::Vm.parse("status!=running")
    result = selector.apply(@all_vms)
    assert_equal 2, result.size
    assert_equal [102, 103], result.map(&:vmid)
  end

  def test_filter_by_status_in
    selector = Pvectl::Selectors::Vm.parse("status in (running,paused)")
    result = selector.apply(@all_vms)
    assert_equal 3, result.size
  end

  # Tags filtering
  def test_filter_by_tag
    selector = Pvectl::Selectors::Vm.parse("tags=prod")
    result = selector.apply(@all_vms)
    assert_equal 2, result.size
    assert_equal [100, 101], result.map(&:vmid)
  end

  def test_filter_by_tag_not_equal
    selector = Pvectl::Selectors::Vm.parse("tags!=prod")
    result = selector.apply(@all_vms)
    assert_equal 2, result.size
    assert_equal [102, 103], result.map(&:vmid)
  end

  def test_filter_by_tag_pattern
    selector = Pvectl::Selectors::Vm.parse("tags=~*base")
    result = selector.apply(@all_vms)
    assert_equal 1, result.size
    assert_equal 102, result.first.vmid
  end

  def test_filter_by_tag_in
    selector = Pvectl::Selectors::Vm.parse("tags in (web,database)")
    result = selector.apply(@all_vms)
    assert_equal 3, result.size
  end

  def test_filter_handles_nil_tags
    selector = Pvectl::Selectors::Vm.parse("tags=prod")
    # vm4 has nil tags - should not match
    result = selector.apply([@vm4])
    assert_empty result
  end

  # Pool filtering
  def test_filter_by_pool
    selector = Pvectl::Selectors::Vm.parse("pool=production")
    result = selector.apply(@all_vms)
    assert_equal 2, result.size
    assert_equal [100, 101], result.map(&:vmid)
  end

  def test_filter_by_pool_not_equal
    selector = Pvectl::Selectors::Vm.parse("pool!=production")
    result = selector.apply(@all_vms)
    assert_equal 2, result.size
  end

  # Name filtering
  def test_filter_by_name_exact
    selector = Pvectl::Selectors::Vm.parse("name=web-prod-1")
    result = selector.apply(@all_vms)
    assert_equal 1, result.size
    assert_equal 100, result.first.vmid
  end

  def test_filter_by_name_pattern
    selector = Pvectl::Selectors::Vm.parse("name=~web-*")
    result = selector.apply(@all_vms)
    assert_equal 2, result.size
    assert_equal [100, 101], result.map(&:vmid)
  end

  def test_filter_by_name_not_equal
    selector = Pvectl::Selectors::Vm.parse("name!=db-dev")
    result = selector.apply(@all_vms)
    assert_equal 3, result.size
  end

  # Multiple conditions (AND)
  def test_filter_multiple_conditions
    selector = Pvectl::Selectors::Vm.parse("status=running,tags=prod")
    result = selector.apply(@all_vms)
    assert_equal 2, result.size
  end

  def test_filter_multiple_conditions_no_match
    selector = Pvectl::Selectors::Vm.parse("status=stopped,tags=prod")
    result = selector.apply(@all_vms)
    assert_empty result
  end

  # Empty selector
  def test_empty_selector_returns_all
    selector = Pvectl::Selectors::Vm.parse("")
    result = selector.apply(@all_vms)
    assert_equal 4, result.size
  end

  # Unknown field
  def test_unknown_field_raises_error
    selector = Pvectl::Selectors::Vm.parse("unknown=value")
    assert_raises(ArgumentError) do
      selector.apply(@all_vms)
    end
  end
end
