# frozen_string_literal: true

require "test_helper"

class SelectorsContainerTest < Minitest::Test
  def setup
    @ct1 = Pvectl::Models::Container.new(
      vmid: 200, name: "web-prod-1", status: "running",
      node: "pve1", tags: "prod;web", pool: "production"
    )
    @ct2 = Pvectl::Models::Container.new(
      vmid: 201, name: "web-prod-2", status: "running",
      node: "pve1", tags: "prod;web", pool: "production"
    )
    @ct3 = Pvectl::Models::Container.new(
      vmid: 202, name: "db-dev", status: "stopped",
      node: "pve2", tags: "dev;database", pool: "development"
    )
    @ct4 = Pvectl::Models::Container.new(
      vmid: 203, name: "cache-staging", status: "stopped",
      node: "pve2", tags: nil, pool: nil
    )
    @ct5 = Pvectl::Models::Container.new(
      vmid: 9000, name: "debian-template", status: "stopped",
      node: "pve1", tags: "template", pool: nil, template: 1
    )
    @all_containers = [@ct1, @ct2, @ct3, @ct4, @ct5]
  end

  # Class structure
  def test_class_exists
    assert_kind_of Class, Pvectl::Selectors::Container
  end

  def test_inherits_from_base
    assert Pvectl::Selectors::Container < Pvectl::Selectors::Base
  end

  def test_supported_fields_constant
    assert_equal %w[status tags pool name template], Pvectl::Selectors::Container::SUPPORTED_FIELDS
  end

  # Status filtering
  def test_filter_by_status_running
    selector = Pvectl::Selectors::Container.parse("status=running")
    result = selector.apply(@all_containers)
    assert_equal 2, result.size
    assert_equal [200, 201], result.map(&:vmid)
  end

  def test_filter_by_status_stopped
    selector = Pvectl::Selectors::Container.parse("status=stopped")
    result = selector.apply(@all_containers)
    assert_equal 3, result.size
    assert_equal [202, 203, 9000], result.map(&:vmid)
  end

  def test_filter_by_status_not_equal
    selector = Pvectl::Selectors::Container.parse("status!=running")
    result = selector.apply(@all_containers)
    assert_equal 3, result.size
    assert_equal [202, 203, 9000], result.map(&:vmid)
  end

  def test_filter_by_status_in
    selector = Pvectl::Selectors::Container.parse("status in (running,stopped)")
    result = selector.apply(@all_containers)
    assert_equal 5, result.size
  end

  # Tags filtering
  def test_filter_by_tag
    selector = Pvectl::Selectors::Container.parse("tags=prod")
    result = selector.apply(@all_containers)
    assert_equal 2, result.size
    assert_equal [200, 201], result.map(&:vmid)
  end

  def test_filter_by_tag_not_equal
    selector = Pvectl::Selectors::Container.parse("tags!=prod")
    result = selector.apply(@all_containers)
    assert_equal 3, result.size
    assert_equal [202, 203, 9000], result.map(&:vmid)
  end

  def test_filter_by_tag_pattern
    selector = Pvectl::Selectors::Container.parse("tags=~*base")
    result = selector.apply(@all_containers)
    assert_equal 1, result.size
    assert_equal 202, result.first.vmid
  end

  def test_filter_by_tag_in
    selector = Pvectl::Selectors::Container.parse("tags in (web,database)")
    result = selector.apply(@all_containers)
    assert_equal 3, result.size
  end

  def test_filter_handles_nil_tags
    selector = Pvectl::Selectors::Container.parse("tags=prod")
    # ct4 has nil tags - should not match
    result = selector.apply([@ct4])
    assert_empty result
  end

  # Pool filtering
  def test_filter_by_pool
    selector = Pvectl::Selectors::Container.parse("pool=production")
    result = selector.apply(@all_containers)
    assert_equal 2, result.size
    assert_equal [200, 201], result.map(&:vmid)
  end

  def test_filter_by_pool_not_equal
    selector = Pvectl::Selectors::Container.parse("pool!=production")
    result = selector.apply(@all_containers)
    assert_equal 3, result.size
  end

  # Name filtering
  def test_filter_by_name_exact
    selector = Pvectl::Selectors::Container.parse("name=web-prod-1")
    result = selector.apply(@all_containers)
    assert_equal 1, result.size
    assert_equal 200, result.first.vmid
  end

  def test_filter_by_name_pattern
    selector = Pvectl::Selectors::Container.parse("name=~web-*")
    result = selector.apply(@all_containers)
    assert_equal 2, result.size
    assert_equal [200, 201], result.map(&:vmid)
  end

  def test_filter_by_name_not_equal
    selector = Pvectl::Selectors::Container.parse("name!=db-dev")
    result = selector.apply(@all_containers)
    assert_equal 4, result.size
  end

  # Multiple conditions (AND)
  def test_filter_multiple_conditions
    selector = Pvectl::Selectors::Container.parse("status=running,tags=prod")
    result = selector.apply(@all_containers)
    assert_equal 2, result.size
  end

  def test_filter_multiple_conditions_no_match
    selector = Pvectl::Selectors::Container.parse("status=stopped,tags=prod")
    result = selector.apply(@all_containers)
    assert_empty result
  end

  # Empty selector
  def test_empty_selector_returns_all
    selector = Pvectl::Selectors::Container.parse("")
    result = selector.apply(@all_containers)
    assert_equal 5, result.size
  end

  # parse_all
  def test_parse_all_combines_selector_strings
    selector = Pvectl::Selectors::Container.parse_all(["status=running", "tags=prod"])
    result = selector.apply(@all_containers)
    assert_equal 2, result.size
    assert_equal [200, 201], result.map(&:vmid)
  end

  # Template filtering
  def test_filter_by_template_yes
    selector = Pvectl::Selectors::Container.parse("template=yes")
    result = selector.apply(@all_containers)
    assert_equal 1, result.size
    assert_equal 9000, result.first.vmid
  end

  def test_filter_by_template_no
    selector = Pvectl::Selectors::Container.parse("template=no")
    result = selector.apply(@all_containers)
    assert_equal 4, result.size
    assert_equal [200, 201, 202, 203], result.map(&:vmid)
  end

  def test_filter_by_template_not_equal
    selector = Pvectl::Selectors::Container.parse("template!=yes")
    result = selector.apply(@all_containers)
    assert_equal 4, result.size
  end

  def test_filter_combined_template_and_status
    selector = Pvectl::Selectors::Container.parse("template=no,status=running")
    result = selector.apply(@all_containers)
    assert_equal 2, result.size
    assert_equal [200, 201], result.map(&:vmid)
  end

  # Unknown field
  def test_unknown_field_raises_error
    selector = Pvectl::Selectors::Container.parse("unknown=value")
    assert_raises(ArgumentError) do
      selector.apply(@all_containers)
    end
  end
end
