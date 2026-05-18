# frozen_string_literal: true

require "test_helper"

class PresentersDnsConfigTest < Minitest::Test
  def setup
    @dns = Pvectl::Models::DnsConfig.new(
      node: "pve1",
      search: "example.com",
      dns1: "8.8.8.8",
      dns2: "1.1.1.1",
      dns3: "9.9.9.9"
    )
    @presenter = Pvectl::Presenters::DnsConfig.new
  end

  def test_columns_returns_expected_headers
    assert_equal %w[NODE SEARCH DNS1 DNS2 DNS3], @presenter.columns
  end

  def test_to_row_returns_values_matching_columns
    row = @presenter.to_row(@dns)
    assert_equal ["pve1", "example.com", "8.8.8.8", "1.1.1.1", "9.9.9.9"], row
  end

  def test_to_row_handles_missing_optional_fields
    dns = Pvectl::Models::DnsConfig.new(node: "pve1", dns1: "8.8.8.8")
    row = @presenter.to_row(dns)
    assert_equal ["pve1", "-", "8.8.8.8", "-", "-"], row
  end

  def test_to_hash_returns_string_keyed_hash
    hash = @presenter.to_hash(@dns)
    assert_equal "pve1", hash["node"]
    assert_equal "example.com", hash["search"]
    assert_equal "8.8.8.8", hash["dns1"]
    assert_equal "1.1.1.1", hash["dns2"]
    assert_equal "9.9.9.9", hash["dns3"]
  end

  def test_to_description_returns_structured_hash
    desc = @presenter.to_description(@dns)
    assert_equal "pve1", desc["Node"]
    assert_equal "example.com", desc["Search Domain"]
    assert_equal ["8.8.8.8", "1.1.1.1", "9.9.9.9"], desc["Nameservers"]
  end

  def test_to_description_with_no_servers_shows_placeholder
    dns = Pvectl::Models::DnsConfig.new(node: "pve1")
    desc = @presenter.to_description(dns)
    assert_equal "-", desc["Nameservers"]
  end
end
