# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Container Tests
# =============================================================================

class RepositoriesContainerTest < Minitest::Test
  # Tests for the Container (LXC) repository

  def setup
    # NOTE: proxmox-api gem returns Hashes with symbol keys, not string keys
    @mock_api_response = [
      {
        vmid: 100,
        name: "web-frontend",
        status: "running",
        node: "pve-node1",
        type: "lxc",
        cpu: 0.05,
        maxcpu: 2,
        mem: 536_870_912,
        maxmem: 1_073_741_824,
        disk: 2_147_483_648,
        maxdisk: 8_589_934_592,
        uptime: 864_000,
        template: 0,
        tags: "prod;web",
        netin: 123_456_789,
        netout: 987_654_321
      },
      {
        vmid: 101,
        name: "db-backend",
        status: "running",
        node: "pve-node2",
        type: "lxc",
        cpu: 0.08,
        maxcpu: 4,
        mem: 2_147_483_648,
        maxmem: 4_294_967_296,
        disk: 16_106_127_360,
        maxdisk: 53_687_091_200,
        uptime: 1_314_000,
        template: 0,
        tags: "prod;db",
        netin: 111_111_111,
        netout: 222_222_222
      },
      {
        vmid: 200,
        name: "dev-container",
        status: "stopped",
        node: "pve-node3",
        type: "lxc",
        cpu: 0,
        maxcpu: 1,
        mem: 0,
        maxmem: 536_870_912,
        disk: 1_073_741_824,
        maxdisk: 4_294_967_296,
        uptime: 0,
        template: 0,
        tags: "dev",
        netin: 0,
        netout: 0
      },
      {
        vmid: 1000,
        name: "test-vm",
        status: "running",
        node: "pve-node1",
        type: "qemu", # This is a VM, not a container
        cpu: 0.12,
        maxcpu: 4,
        mem: 2_254_857_830,
        maxmem: 4_294_967_296,
        disk: 16_106_127_360,
        maxdisk: 53_687_091_200,
        uptime: 86400,
        template: 0
      }
    ]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_container_repository_class_exists
    assert_kind_of Class, Pvectl::Repositories::Container
  end

  def test_container_repository_inherits_from_base
    assert Pvectl::Repositories::Container < Pvectl::Repositories::Base
  end

  # ---------------------------
  # list() Method
  # ---------------------------

  def test_list_returns_array_of_container_models
    repo = create_repo_with_mock_response(@mock_api_response)

    containers = repo.list

    assert_kind_of Array, containers
    assert containers.all? { |ct| ct.is_a?(Pvectl::Models::Container) }
  end

  def test_list_filters_out_qemu_vms
    repo = create_repo_with_mock_response(@mock_api_response)

    containers = repo.list

    # Should have 3 containers (lxc), not 4 (includes qemu)
    assert_equal 3, containers.length
    refute containers.any? { |ct| ct.vmid == 1000 }
  end

  def test_list_with_node_filter
    repo = create_repo_with_mock_response(@mock_api_response)

    containers = repo.list(node: "pve-node1")

    assert_equal 1, containers.length
    assert_equal "pve-node1", containers.first.node
  end

  def test_list_with_node_filter_returns_empty_when_no_match
    repo = create_repo_with_mock_response(@mock_api_response)

    containers = repo.list(node: "nonexistent-node")

    assert_empty containers
  end

  def test_list_returns_empty_array_when_api_returns_empty
    repo = create_repo_with_mock_response([])

    containers = repo.list

    assert_empty containers
  end

  def test_list_maps_all_container_attributes_correctly
    repo = create_repo_with_mock_response(@mock_api_response)

    ct = repo.list.find { |c| c.vmid == 100 }

    assert_equal 100, ct.vmid
    assert_equal "web-frontend", ct.name
    assert_equal "running", ct.status
    assert_equal "pve-node1", ct.node
    assert_equal 0.05, ct.cpu
    assert_equal 2, ct.maxcpu
    assert_equal 536_870_912, ct.mem
    assert_equal 1_073_741_824, ct.maxmem
    assert_equal 2_147_483_648, ct.disk
    assert_equal 8_589_934_592, ct.maxdisk
    assert_equal 864_000, ct.uptime
    assert_equal 0, ct.template
    assert_equal "prod;web", ct.tags
    assert_equal 123_456_789, ct.netin
    assert_equal 987_654_321, ct.netout
  end

  # ---------------------------
  # get() Method
  # ---------------------------

  def test_get_returns_container_by_ctid
    repo = create_repo_with_mock_response(@mock_api_response)

    ct = repo.get(100)

    assert_instance_of Pvectl::Models::Container, ct
    assert_equal 100, ct.vmid
  end

  def test_get_returns_nil_when_ctid_not_found
    repo = create_repo_with_mock_response(@mock_api_response)

    ct = repo.get(9999)

    assert_nil ct
  end

  def test_get_accepts_string_ctid
    repo = create_repo_with_mock_response(@mock_api_response)

    ct = repo.get("100")

    assert_instance_of Pvectl::Models::Container, ct
    assert_equal 100, ct.vmid
  end

  def test_get_does_not_return_qemu_vm
    repo = create_repo_with_mock_response(@mock_api_response)

    ct = repo.get(1000)

    assert_nil ct
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_returns_container_model_with_enriched_data
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(100)

    assert_instance_of Pvectl::Models::Container, ct
    assert_equal 100, ct.vmid
  end

  def test_describe_returns_nil_for_nonexistent_ctid
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(99999)

    assert_nil ct
  end

  def test_describe_accepts_string_ctid
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe("100")

    assert_instance_of Pvectl::Models::Container, ct
    assert_equal 100, ct.vmid
  end

  def test_describe_includes_config_data
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(100)

    assert_equal "debian", ct.ostype
    assert_equal "amd64", ct.arch
    assert_equal 1, ct.unprivileged
  end

  def test_describe_includes_status_data
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(100)

    assert_equal 12345, ct.pid
  end

  def test_describe_includes_network_interfaces
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(100)

    assert_kind_of Array, ct.network_interfaces
    refute_empty ct.network_interfaces
    assert ct.network_interfaces.any? { |iface| iface[:name] == "eth0" }
  end

  def test_describe_includes_rootfs
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(100)

    assert_equal "local-lvm:vm-100-disk-0,size=8G", ct.rootfs
  end

  def test_describe_includes_features
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(100)

    assert_equal "nesting=1,keyctl=1", ct.features
  end

  def test_describe_includes_hostname
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(100)

    assert_equal "web-frontend.example.com", ct.hostname
  end

  def test_describe_includes_description
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(100)

    assert_equal "Production web frontend container", ct.description
  end

  def test_describe_does_not_return_qemu_vm
    repo = create_describe_repo_with_mock_responses

    ct = repo.describe(1000)

    assert_nil ct
  end

  def test_describe_for_stopped_container_returns_config_data
    repo = create_describe_repo_for_stopped_container

    ct = repo.describe(200)

    assert_instance_of Pvectl::Models::Container, ct
    assert_equal "stopped", ct.status
    # Config should still be available
    assert_equal "debian", ct.ostype
    # PID should be nil for stopped container
    assert_nil ct.pid
  end

  # ---------------------------
  # delete() Method
  # ---------------------------

  def test_delete_calls_delete_on_lxc_endpoint_with_default_options
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200"])
    mock_endpoint.expect(:delete, "UPID:pve1:abc123", [{ "destroy-unreferenced-disks" => 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    result = repo.delete(200, "pve1")

    assert_equal "UPID:pve1:abc123", result
    mock_client.verify
    mock_endpoint.verify
  end

  def test_delete_includes_purge_parameter_when_purge_true
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200"])
    mock_endpoint.expect(:delete, "UPID:pve1:abc123", [{ "destroy-unreferenced-disks" => 1, purge: 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    repo.delete(200, "pve1", purge: true)

    mock_endpoint.verify
  end

  def test_delete_includes_force_parameter_when_force_true
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200"])
    mock_endpoint.expect(:delete, "UPID:pve1:abc123", [{ "destroy-unreferenced-disks" => 1, force: 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    repo.delete(200, "pve1", force: true)

    mock_endpoint.verify
  end

  def test_delete_excludes_destroy_unreferenced_disks_when_destroy_disks_false
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200"])
    mock_endpoint.expect(:delete, "UPID:pve1:abc123", [{}])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    repo.delete(200, "pve1", destroy_disks: false)

    mock_endpoint.verify
  end

  # ---------------------------
  # stop() Method
  # ---------------------------

  def test_stop_calls_post_on_lxc_stop_endpoint
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200/status/stop"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    result = repo.stop(200, "pve1")

    assert_equal "UPID:pve1:abc123", result
    mock_client.verify
    mock_endpoint.verify
  end

  # ---------------------------
  # start() Method
  # ---------------------------

  def test_start_calls_post_on_lxc_start_endpoint
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200/status/start"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    result = repo.start(200, "pve1")

    assert_equal "UPID:pve1:abc123", result
    mock_client.verify
    mock_endpoint.verify
  end

  # ---------------------------
  # shutdown() Method
  # ---------------------------

  def test_shutdown_calls_post_on_lxc_shutdown_endpoint
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200/status/shutdown"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    result = repo.shutdown(200, "pve1")

    assert_equal "UPID:pve1:abc123", result
    mock_client.verify
    mock_endpoint.verify
  end

  # ---------------------------
  # restart() Method
  # ---------------------------

  def test_restart_calls_post_on_lxc_reboot_endpoint
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200/status/reboot"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    result = repo.restart(200, "pve1")

    assert_equal "UPID:pve1:abc123", result
    mock_client.verify
    mock_endpoint.verify
  end

  # ---------------------------
  # clone() Method
  # ---------------------------

  def test_clone_posts_to_lxc_clone_endpoint
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [{ newid: 200 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    result = repo.clone(100, "pve1", 200)

    assert_equal "UPID:pve1:abc123", result
    mock_client.verify
    mock_endpoint.verify
  end

  def test_clone_passes_hostname_parameter
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [{ newid: 200, hostname: "web-clone" }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    repo.clone(100, "pve1", 200, hostname: "web-clone")

    mock_endpoint.verify
  end

  def test_clone_passes_full_1_for_full_clone
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [{ newid: 200, full: 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    repo.clone(100, "pve1", 200, full: true)

    mock_endpoint.verify
  end

  def test_clone_passes_full_0_for_linked_clone
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [{ newid: 200, full: 0 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    repo.clone(100, "pve1", 200, full: false)

    mock_endpoint.verify
  end

  def test_clone_passes_all_optional_parameters
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    expected_params = {
      newid: 200,
      hostname: "web-clone",
      target: "pve2",
      storage: "local-lvm",
      full: 1,
      description: "Cloned container",
      pool: "production"
    }

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [expected_params])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    repo.clone(100, "pve1", 200,
               hostname: "web-clone",
               target: "pve2",
               storage: "local-lvm",
               full: true,
               description: "Cloned container",
               pool: "production")

    mock_endpoint.verify
  end

  def test_clone_omits_nil_optional_parameters
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:abc123", [{ newid: 200 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(connection)
    repo.clone(100, "pve1", 200)

    mock_endpoint.verify
  end

  # ---------------------------
  # convert_to_template() Method
  # ---------------------------

  def test_convert_to_template_posts_to_correct_endpoint
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :post, nil, [{}]

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      raise "Wrong path: #{path}" unless path == "nodes/pve1/lxc/200/template"
      mock_endpoint
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }

    repo = Pvectl::Repositories::Container.new(mock_connection)
    repo.convert_to_template(200, "pve1")

    mock_endpoint.verify
  end

  # ---------------------------
  # update() Method
  # ---------------------------

  def test_update_puts_config_to_api
    mock_resource = Minitest::Mock.new
    mock_resource.expect(:put, nil, [{ memory: 4096, swap: 2048 }])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_resource, ["nodes/pve1/lxc/200/config"])

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(mock_connection)
    repo.update(200, "pve1", memory: 4096, swap: 2048)

    mock_resource.verify
  end

  # ---------------------------
  # fetch_config() Public Access
  # ---------------------------

  def test_fetch_config_is_publicly_accessible
    assert Pvectl::Repositories::Container.public_method_defined?(:fetch_config)
  end

  # ---------------------------
  # next_available_ctid() Method
  # ---------------------------

  def test_next_available_ctid_returns_first_unused_id
    repo = create_repo_with_mock_response(@mock_api_response)

    ctid = repo.next_available_ctid

    # Used IDs: 100, 101, 200 (lxc only, 1000 is qemu and filtered out by list)
    assert_equal 102, ctid
  end

  def test_next_available_ctid_with_custom_min
    repo = create_repo_with_mock_response(@mock_api_response)

    ctid = repo.next_available_ctid(min: 200)

    # 200 is used, so should return 201
    assert_equal 201, ctid
  end

  def test_next_available_ctid_returns_min_when_no_containers_exist
    repo = create_repo_with_mock_response([])

    ctid = repo.next_available_ctid

    assert_equal 100, ctid
  end

  # ---------------------------
  # Edge Cases
  # ---------------------------

  def test_list_handles_hash_response_with_data_key
    # Some API responses wrap data in :data key
    wrapped_response = { data: @mock_api_response }
    repo = create_repo_with_wrapped_response(wrapped_response)

    containers = repo.list

    assert_kind_of Array, containers
    # Should filter out qemu VMs
    assert_equal 3, containers.length
  end

  private

  # Creates a repository with a mock connection that returns the given response
  def create_repo_with_mock_response(response)
    mock_resource = Object.new
    mock_resource.define_singleton_method(:get) do |**_kwargs|
      response
    end

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |_path|
      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) do
      mock_client
    end

    Pvectl::Repositories::Container.new(mock_connection)
  end

  # Creates a repository with a mock that returns wrapped response
  def create_repo_with_wrapped_response(response)
    mock_resource = Object.new
    mock_resource.define_singleton_method(:get) do |**_kwargs|
      if response.is_a?(Hash)
        response[:data] || response
      else
        response
      end
    end

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |_path|
      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) do
      mock_client
    end

    Pvectl::Repositories::Container.new(mock_connection)
  end

  # Creates a repository with mock responses for describe tests
  def create_describe_repo_with_mock_responses
    mock_connection = DescribeContainerMockConnection.new(
      resources: @mock_api_response,
      config: {
        ostype: "debian",
        arch: "amd64",
        unprivileged: 1,
        hostname: "web-frontend.example.com",
        memory: 1024,
        swap: 512,
        cores: 2,
        rootfs: "local-lvm:vm-100-disk-0,size=8G",
        net0: "name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1",
        net1: "name=eth1,bridge=vmbr1,ip=10.0.0.100/24",
        features: "nesting=1,keyctl=1",
        description: "Production web frontend container"
      },
      status: {
        status: "running",
        pid: 12345,
        ha: { managed: 0 }
      }
    )
    Pvectl::Repositories::Container.new(mock_connection)
  end

  # Creates repository for stopped container test
  def create_describe_repo_for_stopped_container
    stopped_container = [
      {
        vmid: 200,
        name: "dev-container",
        status: "stopped",
        node: "pve-node3",
        type: "lxc"
      }
    ]
    mock_connection = DescribeContainerMockConnection.new(
      resources: stopped_container,
      config: {
        ostype: "debian",
        arch: "amd64",
        unprivileged: 1,
        hostname: "dev-container",
        memory: 512,
        swap: 256,
        cores: 1,
        rootfs: "local-lvm:vm-200-disk-0,size=4G",
        net0: "name=eth0,bridge=vmbr0,ip=dhcp"
      },
      status: {
        status: "stopped",
        pid: nil,
        ha: { managed: 0 }
      }
    )
    Pvectl::Repositories::Container.new(mock_connection)
  end

  # Mock connection for describe tests
  class DescribeContainerMockConnection
    def initialize(resources:, config:, status:)
      @resources = resources
      @config = config
      @status = status
    end

    def client
      @client ||= DescribeContainerMockClient.new(@resources, @config, @status)
    end
  end

  class DescribeContainerMockClient
    def initialize(resources, config, status)
      @resources = resources
      @config = config
      @status = status
    end

    def [](path)
      case path
      when "cluster/resources"
        DescribeContainerMockResource.new(@resources)
      when /^nodes\/(.+)\/lxc\/(\d+)\/config$/
        DescribeContainerMockResource.new(@config)
      when /^nodes\/(.+)\/lxc\/(\d+)\/status\/current$/
        DescribeContainerMockResource.new(@status)
      else
        DescribeContainerMockResource.new([])
      end
    end
  end

  class DescribeContainerMockResource
    def initialize(response)
      @response = response
    end

    def get(**_kwargs)
      @response
    end
  end
end
