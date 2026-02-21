# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Vm Tests
# =============================================================================

class RepositoriesVmTest < Minitest::Test
  # Tests for the VM repository

  def setup
    # NOTE: proxmox-api gem returns Hashes with symbol keys, not string keys
    @mock_api_response = [
      {
        vmid: 100,
        name: "web-frontend-1",
        status: "running",
        node: "pve-node1",
        type: "qemu",
        cpu: 0.12,
        maxcpu: 4,
        mem: 2_254_857_830,
        maxmem: 4_294_967_296,
        disk: 16_106_127_360,
        maxdisk: 53_687_091_200,
        uptime: 1_314_000,
        template: 0,
        tags: "prod;web",
        hastate: "ignored",
        netin: 123_456_789,
        netout: 987_654_321
      },
      {
        vmid: 101,
        name: "web-frontend-2",
        status: "running",
        node: "pve-node2",
        type: "qemu",
        cpu: 0.08,
        maxcpu: 4,
        mem: 1_932_735_284,
        maxmem: 4_294_967_296,
        disk: 12_884_901_888,
        maxdisk: 53_687_091_200,
        uptime: 1_314_000,
        template: 0,
        tags: "prod;web",
        hastate: "ignored",
        netin: 111_111_111,
        netout: 222_222_222
      },
      {
        vmid: 200,
        name: "dev-env-alice",
        status: "stopped",
        node: "pve-node3",
        type: "qemu",
        cpu: 0,
        maxcpu: 4,
        mem: 0,
        maxmem: 8_589_934_592,
        disk: 19_327_352_832,
        maxdisk: 53_687_091_200,
        uptime: 0,
        template: 0,
        tags: "dev;personal",
        hastate: nil,
        netin: 0,
        netout: 0
      },
      {
        vmid: 1000,
        name: "test-lxc",
        status: "running",
        node: "pve-node1",
        type: "lxc", # This is a container, not a VM
        cpu: 0.05,
        maxcpu: 2,
        mem: 536_870_912,
        maxmem: 1_073_741_824,
        disk: 2_147_483_648,
        maxdisk: 10_737_418_240,
        uptime: 86400,
        template: 0
      }
    ]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_vm_repository_class_exists
    assert_kind_of Class, Pvectl::Repositories::Vm
  end

  def test_vm_repository_inherits_from_base
    assert Pvectl::Repositories::Vm < Pvectl::Repositories::Base
  end

  # ---------------------------
  # list() Method
  # ---------------------------

  def test_list_returns_array_of_vm_models
    repo = create_repo_with_mock_response(@mock_api_response)

    vms = repo.list

    assert_kind_of Array, vms
    assert vms.all? { |vm| vm.is_a?(Pvectl::Models::Vm) }
  end

  def test_list_filters_out_lxc_containers
    repo = create_repo_with_mock_response(@mock_api_response)

    vms = repo.list

    # Should have 3 VMs (qemu), not 4 (includes lxc)
    assert_equal 3, vms.length
    refute vms.any? { |vm| vm.vmid == 1000 }
  end

  def test_list_with_node_filter
    repo = create_repo_with_mock_response(@mock_api_response)

    vms = repo.list(node: "pve-node1")

    assert_equal 1, vms.length
    assert_equal "pve-node1", vms.first.node
  end

  def test_list_with_node_filter_returns_empty_when_no_match
    repo = create_repo_with_mock_response(@mock_api_response)

    vms = repo.list(node: "nonexistent-node")

    assert_empty vms
  end

  def test_list_returns_empty_array_when_api_returns_empty
    repo = create_repo_with_mock_response([])

    vms = repo.list

    assert_empty vms
  end

  def test_list_maps_all_vm_attributes_correctly
    repo = create_repo_with_mock_response(@mock_api_response)

    vm = repo.list.find { |v| v.vmid == 100 }

    assert_equal 100, vm.vmid
    assert_equal "web-frontend-1", vm.name
    assert_equal "running", vm.status
    assert_equal "pve-node1", vm.node
    assert_equal 0.12, vm.cpu
    assert_equal 4, vm.maxcpu
    assert_equal 2_254_857_830, vm.mem
    assert_equal 4_294_967_296, vm.maxmem
    assert_equal 16_106_127_360, vm.disk
    assert_equal 53_687_091_200, vm.maxdisk
    assert_equal 1_314_000, vm.uptime
    assert_equal 0, vm.template
    assert_equal "prod;web", vm.tags
    assert_equal "ignored", vm.hastate
    assert_equal 123_456_789, vm.netin
    assert_equal 987_654_321, vm.netout
  end

  # ---------------------------
  # get() Method
  # ---------------------------

  def test_get_returns_vm_by_vmid
    repo = create_repo_with_mock_response(@mock_api_response)

    vm = repo.get(100)

    assert_instance_of Pvectl::Models::Vm, vm
    assert_equal 100, vm.vmid
  end

  def test_get_returns_nil_when_vmid_not_found
    repo = create_repo_with_mock_response(@mock_api_response)

    vm = repo.get(9999)

    assert_nil vm
  end

  def test_get_accepts_string_vmid
    repo = create_repo_with_mock_response(@mock_api_response)

    vm = repo.get("100")

    assert_instance_of Pvectl::Models::Vm, vm
    assert_equal 100, vm.vmid
  end

  def test_get_does_not_return_lxc_container
    repo = create_repo_with_mock_response(@mock_api_response)

    vm = repo.get(1000)

    assert_nil vm
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_returns_vm_model_with_describe_data
    repo = create_describe_repo_with_mock_responses

    vm = repo.describe(100)

    assert_instance_of Pvectl::Models::Vm, vm
    assert_equal 100, vm.vmid
    refute_nil vm.describe_data
  end

  def test_describe_returns_nil_for_nonexistent_vmid
    repo = create_describe_repo_with_mock_responses

    vm = repo.describe(99999)

    assert_nil vm
  end

  def test_describe_accepts_string_vmid
    repo = create_describe_repo_with_mock_responses

    vm = repo.describe("100")

    assert_instance_of Pvectl::Models::Vm, vm
    assert_equal 100, vm.vmid
  end

  def test_describe_includes_config_data
    repo = create_describe_repo_with_mock_responses

    vm = repo.describe(100)

    assert_kind_of Hash, vm.describe_data[:config]
    assert_equal "ovmf", vm.describe_data[:config][:bios]
    assert_equal 4, vm.describe_data[:config][:cores]
  end

  def test_describe_includes_status_data
    repo = create_describe_repo_with_mock_responses

    vm = repo.describe(100)

    assert_kind_of Hash, vm.describe_data[:status]
    assert_equal 12345, vm.describe_data[:status][:pid]
    assert_equal "8.1.5", vm.describe_data[:status][:"running-qemu"]
  end

  def test_describe_includes_snapshots_data
    repo = create_describe_repo_with_mock_responses

    vm = repo.describe(100)

    assert_kind_of Array, vm.describe_data[:snapshots]
    # Should filter out "current" snapshot
    refute vm.describe_data[:snapshots].any? { |s| s[:name] == "current" }
    assert vm.describe_data[:snapshots].any? { |s| s[:name] == "before-update" }
  end

  def test_describe_includes_agent_ips_when_available
    repo = create_describe_repo_with_mock_responses

    vm = repo.describe(100)

    assert_kind_of Array, vm.describe_data[:agent_ips]
    assert vm.describe_data[:agent_ips].any? { |i| i[:name] == "eth0" }
  end

  def test_describe_handles_agent_endpoint_failure_gracefully
    repo = create_describe_repo_with_agent_error

    vm = repo.describe(100)

    # Should return VM with nil agent_ips, not raise error
    assert_instance_of Pvectl::Models::Vm, vm
    assert_nil vm.describe_data[:agent_ips]
    # Other data should still be present
    assert_equal "ovmf", vm.describe_data[:config][:bios]
  end

  def test_describe_for_stopped_vm_returns_config_data
    repo = create_describe_repo_for_stopped_vm

    vm = repo.describe(200)

    assert_instance_of Pvectl::Models::Vm, vm
    assert_equal "stopped", vm.status
    # Config should still be available
    assert_kind_of Hash, vm.describe_data[:config]
    # Agent IPs should be nil (no agent on stopped VM)
    assert_nil vm.describe_data[:agent_ips]
  end

  def test_describe_does_not_return_lxc_container
    repo = create_describe_repo_with_mock_responses

    vm = repo.describe(1000)

    assert_nil vm
  end

  # ---------------------------
  # Lifecycle Operations
  # ---------------------------

  def test_start_calls_correct_api_endpoint
    mock_connection = LifecycleMockConnection.new(
      expected_path: "nodes/pve1/qemu/100/status/start",
      response: "UPID:pve1:000ABC:..."
    )
    repo = Pvectl::Repositories::Vm.new(mock_connection)

    result = repo.start(100, "pve1")

    assert_equal "UPID:pve1:000ABC:...", result
    assert mock_connection.post_called?
  end

  def test_stop_calls_correct_api_endpoint
    mock_connection = LifecycleMockConnection.new(
      expected_path: "nodes/pve1/qemu/100/status/stop",
      response: "UPID:pve1:000DEF:..."
    )
    repo = Pvectl::Repositories::Vm.new(mock_connection)

    result = repo.stop(100, "pve1")

    assert_equal "UPID:pve1:000DEF:...", result
  end

  def test_shutdown_calls_correct_api_endpoint
    mock_connection = LifecycleMockConnection.new(
      expected_path: "nodes/pve1/qemu/100/status/shutdown",
      response: "UPID:pve1:000GHI:..."
    )
    repo = Pvectl::Repositories::Vm.new(mock_connection)

    result = repo.shutdown(100, "pve1")

    assert_equal "UPID:pve1:000GHI:...", result
  end

  def test_restart_calls_reboot_api_endpoint
    mock_connection = LifecycleMockConnection.new(
      expected_path: "nodes/pve1/qemu/100/status/reboot",
      response: "UPID:pve1:000JKL:..."
    )
    repo = Pvectl::Repositories::Vm.new(mock_connection)

    result = repo.restart(100, "pve1")

    assert_equal "UPID:pve1:000JKL:...", result
  end

  def test_reset_calls_correct_api_endpoint
    mock_connection = LifecycleMockConnection.new(
      expected_path: "nodes/pve1/qemu/100/status/reset",
      response: "UPID:pve1:000MNO:..."
    )
    repo = Pvectl::Repositories::Vm.new(mock_connection)

    result = repo.reset(100, "pve1")

    assert_equal "UPID:pve1:000MNO:...", result
  end

  def test_suspend_calls_correct_api_endpoint
    mock_connection = LifecycleMockConnection.new(
      expected_path: "nodes/pve1/qemu/100/status/suspend",
      response: "UPID:pve1:000PQR:..."
    )
    repo = Pvectl::Repositories::Vm.new(mock_connection)

    result = repo.suspend(100, "pve1")

    assert_equal "UPID:pve1:000PQR:...", result
  end

  def test_resume_calls_correct_api_endpoint
    mock_connection = LifecycleMockConnection.new(
      expected_path: "nodes/pve1/qemu/100/status/resume",
      response: "UPID:pve1:000STU:..."
    )
    repo = Pvectl::Repositories::Vm.new(mock_connection)

    result = repo.resume(100, "pve1")

    assert_equal "UPID:pve1:000STU:...", result
  end

  # ---------------------------
  # delete() Method
  # ---------------------------

  def test_delete_calls_delete_on_qemu_endpoint_with_default_options
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100"])
    mock_endpoint.expect(:delete, "UPID:pve1:abc123", [{ "destroy-unreferenced-disks" => 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.delete(100, "pve1")

    assert_equal "UPID:pve1:abc123", result
    mock_client.verify
    mock_endpoint.verify
  end

  def test_delete_includes_purge_parameter_when_purge_true
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100"])
    mock_endpoint.expect(:delete, "UPID:pve1:abc123", [{ "destroy-unreferenced-disks" => 1, purge: 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.delete(100, "pve1", purge: true)

    mock_endpoint.verify
  end

  def test_delete_includes_skiplock_parameter_when_force_true
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100"])
    mock_endpoint.expect(:delete, "UPID:pve1:abc123", [{ "destroy-unreferenced-disks" => 1, skiplock: 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.delete(100, "pve1", force: true)

    mock_endpoint.verify
  end

  def test_delete_excludes_destroy_unreferenced_disks_when_destroy_disks_false
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100"])
    mock_endpoint.expect(:delete, "UPID:pve1:abc123", [{}])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.delete(100, "pve1", destroy_disks: false)

    mock_endpoint.verify
  end

  # ---------------------------
  # clone() Method
  # ---------------------------

  def test_clone_calls_correct_api_endpoint
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 200 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.clone(100, "pve1", 200)

    assert_equal "UPID:pve1:clone123", result
    mock_client.verify
    mock_endpoint.verify
  end

  def test_clone_passes_newid_parameter
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 999 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.clone(100, "pve1", 999)

    mock_endpoint.verify
  end

  def test_clone_passes_name_when_provided
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 200, name: "my-clone" }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.clone(100, "pve1", 200, name: "my-clone")

    mock_endpoint.verify
  end

  def test_clone_passes_target_when_provided
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 200, target: "pve2" }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.clone(100, "pve1", 200, target: "pve2")

    mock_endpoint.verify
  end

  def test_clone_passes_storage_when_provided
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 200, storage: "local-lvm" }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.clone(100, "pve1", 200, storage: "local-lvm")

    mock_endpoint.verify
  end

  def test_clone_passes_full_as_1_for_true
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 200, full: 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.clone(100, "pve1", 200, full: true)

    mock_endpoint.verify
  end

  def test_clone_passes_full_as_0_for_false
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 200, full: 0 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.clone(100, "pve1", 200, full: false)

    mock_endpoint.verify
  end

  def test_clone_passes_description_when_provided
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 200, description: "Cloned VM" }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.clone(100, "pve1", 200, description: "Cloned VM")

    mock_endpoint.verify
  end

  def test_clone_passes_pool_when_provided
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/clone"])
    mock_endpoint.expect(:post, "UPID:pve1:clone123", [{ newid: 200, pool: "dev-pool" }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.clone(100, "pve1", 200, pool: "dev-pool")

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
      raise "Wrong path: #{path}" unless path == "nodes/pve1/qemu/100/template"
      mock_endpoint
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }

    repo = Pvectl::Repositories::Vm.new(mock_connection)
    repo.convert_to_template(100, "pve1")

    mock_endpoint.verify
  end

  def test_convert_to_template_passes_disk_param_when_given
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :post, nil, [{ disk: "scsi0" }]

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      raise "Wrong path: #{path}" unless path == "nodes/pve1/qemu/100/template"
      mock_endpoint
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }

    repo = Pvectl::Repositories::Vm.new(mock_connection)
    repo.convert_to_template(100, "pve1", disk: "scsi0")

    mock_endpoint.verify
  end

  # ---------------------------
  # update() Method
  # ---------------------------

  def test_update_puts_config_to_api
    mock_resource = Minitest::Mock.new
    mock_resource.expect(:put, nil, [{ cores: 8, memory: 8192 }])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/config"])

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(mock_connection)
    repo.update(100, "pve1", cores: 8, memory: 8192)

    mock_resource.verify
  end

  # ---------------------------
  # resize() Method
  # ---------------------------

  def test_resize_puts_to_correct_endpoint
    mock_resource = Minitest::Mock.new
    mock_resource.expect(:put, nil, [{ disk: "scsi0", size: "+10G" }])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/resize"])

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(mock_connection)
    result = repo.resize(100, "pve1", disk: "scsi0", size: "+10G")

    assert_nil result
    mock_resource.verify
    mock_client.verify
  end

  def test_resize_passes_disk_and_size_params
    mock_resource = Minitest::Mock.new
    mock_resource.expect(:put, nil, [{ disk: "virtio0", size: "50G" }])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_resource, ["nodes/pve2/qemu/200/resize"])

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(mock_connection)
    repo.resize(200, "pve2", disk: "virtio0", size: "50G")

    mock_resource.verify
  end

  # ---------------------------
  # fetch_config() Public Access
  # ---------------------------

  def test_fetch_config_is_publicly_accessible
    assert Pvectl::Repositories::Vm.public_method_defined?(:fetch_config)
  end

  # ---------------------------
  # next_available_vmid() Method
  # ---------------------------

  def test_next_available_vmid_returns_min_when_no_vms_exist
    repo = create_repo_with_mock_response([])

    assert_equal 100, repo.next_available_vmid
  end

  def test_next_available_vmid_returns_next_after_existing
    vms = [
      { vmid: 100, name: "vm1", status: "running", node: "pve1", type: "qemu" },
      { vmid: 101, name: "vm2", status: "running", node: "pve1", type: "qemu" }
    ]
    repo = create_repo_with_mock_response(vms)

    assert_equal 102, repo.next_available_vmid
  end

  def test_next_available_vmid_skips_used_ids
    vms = [
      { vmid: 100, name: "vm1", status: "running", node: "pve1", type: "qemu" },
      { vmid: 102, name: "vm3", status: "running", node: "pve1", type: "qemu" }
    ]
    repo = create_repo_with_mock_response(vms)

    assert_equal 101, repo.next_available_vmid
  end

  def test_next_available_vmid_respects_min_parameter
    vms = [
      { vmid: 100, name: "vm1", status: "running", node: "pve1", type: "qemu" },
      { vmid: 200, name: "vm2", status: "running", node: "pve1", type: "qemu" }
    ]
    repo = create_repo_with_mock_response(vms)

    assert_equal 201, repo.next_available_vmid(min: 200)
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

    Pvectl::Repositories::Vm.new(mock_connection)
  end

  # Creates a repository with mock responses for describe tests
  def create_describe_repo_with_mock_responses
    mock_connection = DescribeVmMockConnection.new(
      resources: @mock_api_response,
      config: {
        bios: "ovmf",
        machine: "q35",
        ostype: "l26",
        sockets: 1,
        cores: 4,
        cpu: "host",
        memory: 8192,
        balloon: 2048,
        scsi0: "local-lvm:vm-100-disk-0,size=50G,format=raw",
        net0: "virtio=BC:24:11:AA:BB:CC,bridge=vmbr0,firewall=1",
        description: "Main production web server"
      },
      status: {
        status: "running",
        qmpstatus: "running",
        pid: 12345,
        "running-qemu": "8.1.5",
        "running-machine": "pc-q35-8.1"
      },
      snapshots: [
        { name: "current", snaptime: 1705326765, vmstate: 0 },
        { name: "before-update", snaptime: 1705240365, vmstate: 1, description: "Before system update" },
        { name: "initial-setup", snaptime: 1704635565, vmstate: 0 }
      ],
      agent_ips: {
        result: [
          { name: "lo", "hardware-address": "00:00:00:00:00:00", "ip-addresses": [{ "ip-address": "127.0.0.1", "ip-address-type": "ipv4" }] },
          { name: "eth0", "hardware-address": "bc:24:11:aa:bb:cc", "ip-addresses": [{ "ip-address": "192.168.1.100", "ip-address-type": "ipv4" }] }
        ]
      }
    )
    Pvectl::Repositories::Vm.new(mock_connection)
  end

  # Creates repository that simulates agent error
  def create_describe_repo_with_agent_error
    DescribeVmMockConnection.new(
      resources: @mock_api_response,
      config: { bios: "ovmf", cores: 4 },
      status: { status: "running", pid: 12345 },
      snapshots: [],
      agent_error: true
    ).tap { |conn| return Pvectl::Repositories::Vm.new(conn) }
  end

  # Creates repository for stopped VM test
  def create_describe_repo_for_stopped_vm
    stopped_vm = [
      {
        vmid: 200,
        name: "dev-env-alice",
        status: "stopped",
        node: "pve-node3",
        type: "qemu"
      }
    ]
    mock_connection = DescribeVmMockConnection.new(
      resources: stopped_vm,
      config: { bios: "seabios", cores: 4, memory: 8192 },
      status: { status: "stopped", qmpstatus: "stopped" },
      snapshots: [],
      agent_error: true  # Agent not available on stopped VM
    )
    Pvectl::Repositories::Vm.new(mock_connection)
  end

  # Mock connection for describe tests
  class DescribeVmMockConnection
    def initialize(resources:, config:, status:, snapshots:, agent_ips: nil, agent_error: false)
      @resources = resources
      @config = config
      @status = status
      @snapshots = snapshots
      @agent_ips = agent_ips
      @agent_error = agent_error
    end

    def client
      @client ||= DescribeVmMockClient.new(@resources, @config, @status, @snapshots, @agent_ips, @agent_error)
    end
  end

  class DescribeVmMockClient
    def initialize(resources, config, status, snapshots, agent_ips, agent_error)
      @resources = resources
      @config = config
      @status = status
      @snapshots = snapshots
      @agent_ips = agent_ips
      @agent_error = agent_error
    end

    def [](path)
      case path
      when "cluster/resources"
        DescribeVmMockResource.new(@resources)
      when /^nodes\/(.+)\/qemu\/(\d+)\/config$/
        DescribeVmMockResource.new(@config)
      when /^nodes\/(.+)\/qemu\/(\d+)\/status\/current$/
        DescribeVmMockResource.new(@status)
      when /^nodes\/(.+)\/qemu\/(\d+)\/snapshot$/
        DescribeVmMockResource.new(@snapshots)
      when /^nodes\/(.+)\/qemu\/(\d+)\/agent\/network-get-interfaces$/
        raise StandardError, "Agent not available" if @agent_error

        DescribeVmMockResource.new(@agent_ips)
      else
        DescribeVmMockResource.new([])
      end
    end
  end

  class DescribeVmMockResource
    def initialize(response)
      @response = response
    end

    def get(**_kwargs)
      @response
    end
  end

  # Mock connection for lifecycle tests
  class LifecycleMockConnection
    def initialize(expected_path:, response:)
      @expected_path = expected_path
      @response = response
      @post_called = false
    end

    def client
      @client ||= LifecycleMockClient.new(self, @expected_path, @response)
    end

    def post_called?
      @post_called
    end

    def mark_post_called
      @post_called = true
    end
  end

  class LifecycleMockClient
    def initialize(connection, expected_path, response)
      @connection = connection
      @expected_path = expected_path
      @response = response
    end

    def [](path)
      LifecycleMockResource.new(@connection, path == @expected_path, @response)
    end
  end

  class LifecycleMockResource
    def initialize(connection, path_matches, response)
      @connection = connection
      @path_matches = path_matches
      @response = response
    end

    def get(**_kwargs)
      []
    end

    def post(**_kwargs)
      @connection.mark_post_called
      @path_matches ? @response : raise("Wrong path")
    end
  end
end
