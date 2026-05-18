# frozen_string_literal: true

require "test_helper"

class ModelsDnsConfigTest < Minitest::Test
  def test_exposes_all_attributes_from_hash
    dns = Pvectl::Models::DnsConfig.new(
      node: "pve1",
      search: "example.com",
      dns1: "8.8.8.8",
      dns2: "1.1.1.1",
      dns3: "9.9.9.9"
    )

    assert_equal "pve1", dns.node
    assert_equal "example.com", dns.search
    assert_equal "8.8.8.8", dns.dns1
    assert_equal "1.1.1.1", dns.dns2
    assert_equal "9.9.9.9", dns.dns3
  end

  def test_optional_dns2_and_dns3_default_to_nil
    dns = Pvectl::Models::DnsConfig.new(node: "pve1", search: "example.com", dns1: "8.8.8.8")

    assert_equal "8.8.8.8", dns.dns1
    assert_nil dns.dns2
    assert_nil dns.dns3
  end

  def test_optional_search_can_be_nil
    dns = Pvectl::Models::DnsConfig.new(node: "pve1", dns1: "8.8.8.8")

    assert_nil dns.search
    assert_equal "8.8.8.8", dns.dns1
  end

  def test_servers_returns_compact_list_of_dns_servers
    dns = Pvectl::Models::DnsConfig.new(node: "pve1", dns1: "8.8.8.8", dns3: "9.9.9.9")

    assert_equal ["8.8.8.8", "9.9.9.9"], dns.servers
  end

  def test_servers_empty_when_no_dns_set
    dns = Pvectl::Models::DnsConfig.new(node: "pve1")

    assert_empty dns.servers
  end
end
