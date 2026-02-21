# Unified Snapshot CLI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor all snapshot commands to use consistent argument order (name first, VMIDs as `--vmid` flag), add `--node` filtering, add `--all` delete mode.

**Architecture:** GLI sub-commands for `create snapshot`/`delete snapshot` with hybrid registration (sub-command + parent fallback). `--vmid`/`--node` flags added to `get`/`describe` at command level. Service layer gains `node:` filtering and `delete_all` method.

**Tech Stack:** Ruby 3.3.0, GLI (CLI framework), Minitest (testing), RBS (type signatures)

---

### Task 1: Service layer — add `node:` filtering and `resolve_resources` helper

Add the `node:` keyword parameter to all public service methods and extract a shared `resolve_resources` helper. This is the foundation for all subsequent tasks.

**Files:**
- Modify: `lib/pvectl/services/snapshot.rb`
- Modify: `test/unit/services/snapshot_test.rb`
- Modify: `sig/pvectl/services/snapshot.rbs`

**Step 1: Write failing tests for node filtering**

Add these tests to `test/unit/services/snapshot_test.rb` inside the `SnapshotTest` class:

```ruby
def test_list_filters_by_node
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" },
    { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
  ], [[100, 101]])

  snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)]
  @mock_snapshot_repo.expect(:list, snapshots, [100, "pve1", :qemu])

  result = @service.list([100, 101], node: "pve1")

  assert_equal 1, result.length
  assert_equal "snap1", result[0].name
  @mock_resolver.verify
  @mock_snapshot_repo.verify
end

def test_list_cluster_wide_when_vmids_empty
  @mock_resolver.expect(:resolve_all, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" }
  ])

  snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
  @mock_snapshot_repo.expect(:list, snapshots, [100, "pve1", :qemu])

  result = @service.list([])

  assert_equal 1, result.length
  @mock_resolver.verify
end

def test_create_filters_by_node
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" },
    { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
  ], [[100, 101]])

  @mock_snapshot_repo.expect(:create, "UPID:pve1:00001234:...", [100, "pve1", :qemu], name: "snap1", description: nil, vmstate: false)

  task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 60)

  results = @service.create([100, 101], name: "snap1", node: "pve1")

  assert_equal 1, results.length
  assert results[0].successful?
  @mock_resolver.verify
end

def test_delete_filters_by_node
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" },
    { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
  ], [[100, 101]])

  @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

  task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

  results = @service.delete([100, 101], "snap1", node: "pve1")

  assert_equal 1, results.length
  assert results[0].successful?
  @mock_resolver.verify
end

def test_describe_filters_by_node
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" },
    { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
  ], [[100, 101]])

  @mock_snapshot_repo.expect(:list, [
    Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
  ], [100, "pve1", :qemu])

  result = @service.describe([100, 101], "snap1", node: "pve1")

  assert result.single?
  assert_equal 100, result.entries.first.snapshot.vmid
  @mock_resolver.verify
end

def test_create_cluster_wide_when_vmids_empty
  @mock_resolver.expect(:resolve_all, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" }
  ])

  @mock_snapshot_repo.expect(:create, "UPID:pve1:00001234:...", [100, "pve1", :qemu], name: "snap1", description: nil, vmstate: false)

  task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 60)

  results = @service.create([], name: "snap1")

  assert_equal 1, results.length
  assert results[0].successful?
  @mock_resolver.verify
end

def test_delete_cluster_wide_when_vmids_empty
  @mock_resolver.expect(:resolve_all, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" }
  ])

  @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

  task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

  results = @service.delete([], "snap1")

  assert_equal 1, results.length
  assert results[0].successful?
  @mock_resolver.verify
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib:test test/unit/services/snapshot_test.rb`
Expected: Multiple failures — methods don't accept `node:` keyword

**Step 3: Implement node filtering in service**

Replace `lib/pvectl/services/snapshot.rb` methods. Key changes:

1. Extract `resolve_resources(vmids)` private method:
```ruby
def resolve_resources(vmids)
  vmids.empty? ? @resolver.resolve_all : @resolver.resolve_multiple(vmids)
end

def filter_by_node(resources, node)
  return resources unless node

  resources.select { |r| r[:node] == node }
end
```

2. Update all public methods to accept `node: nil` and use the helpers:

```ruby
def list(vmids, node: nil)
  resources = resolve_resources(vmids)
  resources = filter_by_node(resources, node)
  return [] if resources.empty?

  resources.flat_map do |r|
    @snapshot_repo.list(r[:vmid], r[:node], r[:type])
  end
end

def describe(vmids, name, node: nil)
  resources = vmids.empty? ? @resolver.resolve_all : @resolver.resolve_multiple(vmids)
  resources = filter_by_node(resources, node)

  if resources.empty?
    message = vmids.empty? ? "no resources found in cluster" : "resource #{vmids.first} not found"
    raise ResourceNotFoundError, message
  end

  entries = build_describe_entries(resources, name)

  if entries.empty?
    message = vmids.empty? ? "snapshot '#{name}' not found in cluster" : "snapshot '#{name}' not found on VM #{vmids.join(', ')}"
    raise ResourceNotFoundError, message
  end

  Models::SnapshotDescription.new(entries: entries)
end

def create(vmids, name:, description: nil, vmstate: false, node: nil)
  resources = resolve_resources(vmids)
  resources = filter_by_node(resources, node)
  return [] if resources.empty?

  execute_multi(resources, :create) do |r|
    @snapshot_repo.create(r[:vmid], r[:node], r[:type], name: name, description: description, vmstate: vmstate)
  end
end

def delete(vmids, snapname, force: false, node: nil)
  resources = resolve_resources(vmids)
  resources = filter_by_node(resources, node)
  return [] if resources.empty?

  execute_multi(resources, :delete) do |r|
    @snapshot_repo.delete(r[:vmid], r[:node], r[:type], snapname, force: force)
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec ruby -Ilib:test test/unit/services/snapshot_test.rb`
Expected: All tests pass (old + new)

**Step 5: Update RBS signature**

In `sig/pvectl/services/snapshot.rbs`, update method signatures:

```rbs
def list: (Array[Integer] vmids, ?node: String?) -> Array[Models::Snapshot]
def describe: (Array[Integer] vmids, String name, ?node: String?) -> Models::SnapshotDescription
def create: (Array[Integer] vmids, name: String, ?description: String?, ?vmstate: bool, ?node: String?) -> Array[Models::OperationResult]
def delete: (Array[Integer] vmids, String snapname, ?force: bool, ?node: String?) -> Array[Models::OperationResult]
```

Add private methods:
```rbs
def resolve_resources: (Array[Integer] vmids) -> Array[Hash[Symbol, untyped]]
def filter_by_node: (Array[Hash[Symbol, untyped]] resources, String? node) -> Array[Hash[Symbol, untyped]]
```

Run: `BUNDLE_GEMFILE="" rbs parse sig/pvectl/services/snapshot.rbs`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/pvectl/services/snapshot.rb test/unit/services/snapshot_test.rb sig/pvectl/services/snapshot.rbs
git commit -m "feat(services): add node filtering and resolve_resources to snapshot service"
```

---

### Task 2: Service layer — add `delete_all` method

Add a new method that deletes ALL snapshots from resolved VMs, supporting `node:` filtering.

**Files:**
- Modify: `lib/pvectl/services/snapshot.rb`
- Modify: `test/unit/services/snapshot_test.rb`
- Modify: `sig/pvectl/services/snapshot.rbs`

**Step 1: Write failing tests**

Add to `test/unit/services/snapshot_test.rb`:

```ruby
# --- delete_all tests ---

def test_delete_all_deletes_every_snapshot_from_vm
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" }
  ], [[100]])

  @mock_snapshot_repo.expect(:list, [
    Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu),
    Models::Snapshot.new(name: "snap2", vmid: 100, node: "pve1", resource_type: :qemu)
  ], [100, "pve1", :qemu])

  @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)
  @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001237:...", [100, "pve1", :qemu, "snap2"], force: false)

  task1 = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
  task2 = Models::Task.new(upid: "UPID:pve1:00001237:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task1, ["UPID:pve1:00001236:..."], timeout: 60)
  @mock_task_repo.expect(:wait, task2, ["UPID:pve1:00001237:..."], timeout: 60)

  results = @service.delete_all([100])

  assert_equal 1, results.length
  assert results[0].successful?
  @mock_resolver.verify
  @mock_snapshot_repo.verify
  @mock_task_repo.verify
end

def test_delete_all_skips_current_pseudo_snapshot
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" }
  ], [[100]])

  @mock_snapshot_repo.expect(:list, [
    Models::Snapshot.new(name: "current", vmid: 100, node: "pve1", resource_type: :qemu),
    Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
  ], [100, "pve1", :qemu])

  @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

  task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

  results = @service.delete_all([100])

  assert_equal 1, results.length
  @mock_snapshot_repo.verify
end

def test_delete_all_filters_by_node
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" },
    { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
  ], [[100, 101]])

  @mock_snapshot_repo.expect(:list, [
    Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
  ], [100, "pve1", :qemu])

  @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

  task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

  results = @service.delete_all([100, 101], node: "pve1")

  assert_equal 1, results.length
  @mock_resolver.verify
end

def test_delete_all_cluster_wide_when_vmids_empty
  @mock_resolver.expect(:resolve_all, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" }
  ])

  @mock_snapshot_repo.expect(:list, [
    Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
  ], [100, "pve1", :qemu])

  @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

  task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

  results = @service.delete_all([])

  assert_equal 1, results.length
  @mock_resolver.verify
end

def test_delete_all_returns_empty_when_no_snapshots
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" }
  ], [[100]])

  @mock_snapshot_repo.expect(:list, [], [100, "pve1", :qemu])

  results = @service.delete_all([100])

  assert_equal 1, results.length
  assert results[0].successful?
end

def test_delete_all_with_force_flag
  @mock_resolver.expect(:resolve_multiple, [
    { vmid: 100, node: "pve1", type: :qemu, name: "web" }
  ], [[100]])

  @mock_snapshot_repo.expect(:list, [
    Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
  ], [100, "pve1", :qemu])

  @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: true)

  task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
  @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

  results = @service.delete_all([100], force: true)

  assert_equal 1, results.length
  @mock_snapshot_repo.verify
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib:test test/unit/services/snapshot_test.rb`
Expected: `NoMethodError: undefined method 'delete_all'`

**Step 3: Implement `delete_all`**

Add to `lib/pvectl/services/snapshot.rb` after the `delete` method (before `rollback`):

```ruby
# Deletes ALL snapshots from given VMIDs.
#
# Lists all snapshots for each resource, then deletes each one
# (excluding the "current" pseudo-snapshot).
#
# @param vmids [Array<Integer>] VM/container IDs (empty = cluster-wide)
# @param node [String, nil] filter by node name
# @param force [Boolean] force removal even if disk snapshot fails
# @return [Array<Models::OperationResult>] results for each resource
def delete_all(vmids, node: nil, force: false)
  resources = resolve_resources(vmids)
  resources = filter_by_node(resources, node)
  return [] if resources.empty?

  results = []
  resources.each do |r|
    snapshots = @snapshot_repo.list(r[:vmid], r[:node], r[:type])
    snapshots.reject! { |s| s.name == "current" }

    if snapshots.empty?
      results << Models::OperationResult.new(
        resource: r,
        operation: :delete_all,
        success: true
      )
      next
    end

    snapshots.each do |snap|
      result = execute_single(r, :delete_all) do
        @snapshot_repo.delete(r[:vmid], r[:node], r[:type], snap.name, force: force)
      end
      results << result
      break if @options[:fail_fast] && result.failed?
    end
    break if @options[:fail_fast] && results.last&.failed?
  end

  results
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec ruby -Ilib:test test/unit/services/snapshot_test.rb`
Expected: All tests pass

**Step 5: Update RBS signature**

Add to `sig/pvectl/services/snapshot.rbs` (public section):

```rbs
def delete_all: (Array[Integer] vmids, ?node: String?, ?force: bool) -> Array[Models::OperationResult]
```

Run: `BUNDLE_GEMFILE="" rbs parse sig/pvectl/services/snapshot.rbs`

**Step 6: Commit**

```bash
git add lib/pvectl/services/snapshot.rb test/unit/services/snapshot_test.rb sig/pvectl/services/snapshot.rbs
git commit -m "feat(services): add delete_all method to snapshot service"
```

---

### Task 3: Snapshot handler — use `--vmid` and `--node` flags instead of positional args

Refactor the `Snapshots` handler to accept VMIDs from `options[:vmid]` (repeatable flag) and pass `node:` to the service. Remove the `ArgumentError` for empty args.

**Files:**
- Modify: `lib/pvectl/commands/get/handlers/snapshots.rb`
- Modify: `test/unit/commands/get/handlers/snapshots_test.rb`
- Modify: `sig/pvectl/commands/get/handlers/snapshots.rbs`

**Step 1: Write failing tests**

Replace the test file `test/unit/commands/get/handlers/snapshots_test.rb` completely:

```ruby
# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    module Get
      module Handlers
        class SnapshotsTest < Minitest::Test
          def setup
            @mock_service = Minitest::Mock.new
            @handler = Snapshots.new(service: @mock_service)
          end

          # --- list tests ---

          def test_list_with_vmid_option
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[100]], node: nil)

            result = @handler.list(args: [], vmid: ["100"])

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_list_with_multiple_vmids
            snapshots = [
              Models::Snapshot.new(name: "snap1", vmid: 100),
              Models::Snapshot.new(name: "snap2", vmid: 101)
            ]
            @mock_service.expect(:list, snapshots, [[100, 101]], node: nil)

            result = @handler.list(args: [], vmid: ["100", "101"])

            assert_equal 2, result.length
            @mock_service.verify
          end

          def test_list_with_node_filter
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[100]], node: "pve1")

            result = @handler.list(args: [], vmid: ["100"], node: "pve1")

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_list_cluster_wide_without_vmid
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[]], node: nil)

            result = @handler.list(args: [])

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_list_cluster_wide_with_node_filter
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[]], node: "pve1")

            result = @handler.list(args: [], node: "pve1")

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_presenter_returns_snapshot_presenter
            presenter = @handler.presenter

            assert_instance_of Presenters::Snapshot, presenter
          end

          # --- describe tests ---

          def test_describe_with_vmid_option
            description = Models::SnapshotDescription.new(entries: [
              Models::SnapshotDescription::Entry.new(
                snapshot: Models::Snapshot.new(name: "snap1", vmid: 100),
                siblings: [Models::Snapshot.new(name: "snap1", vmid: 100)]
              )
            ])
            @mock_service.expect(:describe, description, [[100], "snap1"], node: nil)

            result = @handler.describe(name: "snap1", args: [], vmid: ["100"])

            assert_instance_of Models::SnapshotDescription, result
            @mock_service.verify
          end

          def test_describe_cluster_wide_without_vmid
            description = Models::SnapshotDescription.new(entries: [
              Models::SnapshotDescription::Entry.new(
                snapshot: Models::Snapshot.new(name: "snap1", vmid: 100),
                siblings: [Models::Snapshot.new(name: "snap1", vmid: 100)]
              )
            ])
            @mock_service.expect(:describe, description, [[], "snap1"], node: nil)

            result = @handler.describe(name: "snap1", args: [])

            assert_instance_of Models::SnapshotDescription, result
            @mock_service.verify
          end

          def test_describe_with_node_filter
            description = Models::SnapshotDescription.new(entries: [
              Models::SnapshotDescription::Entry.new(
                snapshot: Models::Snapshot.new(name: "snap1", vmid: 100),
                siblings: [Models::Snapshot.new(name: "snap1", vmid: 100)]
              )
            ])
            @mock_service.expect(:describe, description, [[100], "snap1"], node: "pve1")

            result = @handler.describe(name: "snap1", args: [], vmid: ["100"], node: "pve1")

            assert_instance_of Models::SnapshotDescription, result
            @mock_service.verify
          end
        end
      end
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib:test test/unit/commands/get/handlers/snapshots_test.rb`
Expected: Failures — handler doesn't accept `vmid:` keyword

**Step 3: Implement handler changes**

Replace the handler in `lib/pvectl/commands/get/handlers/snapshots.rb`:

```ruby
# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing and describing snapshots.
        #
        # Uses --vmid flag (repeatable) for VM/CT filtering and --node for node filtering.
        # Without --vmid, operates cluster-wide.
        #
        # @example List snapshots for specific VMs
        #   handler.list(args: [], vmid: ["100", "101"])
        #
        # @example List all snapshots cluster-wide
        #   handler.list(args: [])
        #
        class Snapshots
          include ResourceHandler

          def initialize(service: nil)
            @service = service
          end

          # Lists snapshots, optionally filtered by VMIDs and/or node.
          #
          # @param vmid [Array<String>, nil] VM/CT IDs from --vmid flag
          # @param node [String, nil] node name from --node flag
          # @param args [Array<String>] unused positional args
          # @return [Array<Models::Snapshot>] collection of snapshot models
          def list(node: nil, name: nil, args: [], storage: nil, vmid: nil, **_options)
            parsed_vmids = parse_vmids(vmid)
            service.list(parsed_vmids, node: node)
          end

          # Describes a snapshot by name.
          #
          # @param name [String] snapshot name to find
          # @param vmid [Array<String>, nil] VM/CT IDs from --vmid flag
          # @param node [String, nil] node name from --node flag
          # @param args [Array<String>] unused positional args
          # @return [Models::SnapshotDescription] snapshot description
          def describe(name:, node: nil, args: [], vmid: nil, **_options)
            parsed_vmids = parse_vmids(vmid)
            service.describe(parsed_vmids, name, node: node)
          end

          # Returns presenter for snapshots.
          #
          # @return [Presenters::Snapshot] snapshot presenter instance
          def presenter
            Pvectl::Presenters::Snapshot.new
          end

          private

          # Parses --vmid flag values to integer array.
          #
          # @param vmid [Array<String>, String, nil] raw vmid values
          # @return [Array<Integer>] parsed VMIDs (empty array if nil)
          def parse_vmids(vmid)
            return [] if vmid.nil?

            Array(vmid).map(&:to_i)
          end

          def service
            @service ||= build_service
          end

          def build_service
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)

            snapshot_repo = Pvectl::Repositories::Snapshot.new(connection)
            resolver = Pvectl::Utils::ResourceResolver.new(connection)
            task_repo = Pvectl::Repositories::Task.new(connection)

            Pvectl::Services::Snapshot.new(
              snapshot_repo: snapshot_repo,
              resource_resolver: resolver,
              task_repo: task_repo
            )
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "snapshots",
  Pvectl::Commands::Get::Handlers::Snapshots,
  aliases: ["snapshot", "snap"]
)
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec ruby -Ilib:test test/unit/commands/get/handlers/snapshots_test.rb`
Expected: All tests pass

**Step 5: Update RBS signature**

Update `sig/pvectl/commands/get/handlers/snapshots.rbs`:

```rbs
module Pvectl
  module Commands
    module Get
      module Handlers
        class Snapshots
          include ResourceHandler

          def initialize: (?service: untyped) -> void

          def list: (?node: String?, ?name: String?, ?args: Array[String], ?storage: String?, ?vmid: Array[String]?) -> Array[Models::Snapshot]

          def describe: (name: String, ?node: String?, ?args: Array[String], ?vmid: Array[String]?) -> Models::SnapshotDescription

          def presenter: () -> Presenters::Snapshot

          private

          def parse_vmids: (Array[String]? vmid) -> Array[Integer]

          def service: () -> untyped

          def build_service: () -> untyped
        end
      end
    end
  end
end
```

Run: `BUNDLE_GEMFILE="" rbs parse sig/pvectl/commands/get/handlers/snapshots.rbs`

**Step 6: Commit**

```bash
git add lib/pvectl/commands/get/handlers/snapshots.rb test/unit/commands/get/handlers/snapshots_test.rb sig/pvectl/commands/get/handlers/snapshots.rbs
git commit -m "refactor(handlers): use --vmid flag instead of positional args in snapshots handler"
```

---

### Task 4: Add `--vmid` flag to `get` and `describe` commands

Register the `--vmid` repeatable flag on the `get` and `describe` CLI commands so it's available to handlers.

**Files:**
- Modify: `lib/pvectl/commands/get/command.rb:34-73`
- Modify: `lib/pvectl/commands/describe/command.rb:24-35`

**Step 1: Add `--vmid` flag to get command**

In `lib/pvectl/commands/get/command.rb`, add after line 36 (after the existing `--node` flag):

```ruby
c.desc "Filter by VM/CT ID (repeatable)"
c.flag [:vmid], arg_name: "VMID", multiple: true
```

Then modify the `run_once` method (line 191-206) to pass `vmid:` to the service:

```ruby
def run_once(handler)
  service = build_service(handler)
  output = service.list(
    node: options[:node],
    name: nil,
    args: args,
    storage: options[:storage],
    vmid: options[:vmid],
    limit: options[:limit],
    since: options[:since],
    until_time: options[:until],
    type_filter: options[:type],
    status_filter: options[:status],
    all_nodes: options[:"all-nodes"] || false
  )
  puts output
end
```

**Step 2: Add `--vmid` flag to describe command**

In `lib/pvectl/commands/describe/command.rb`, add after line 26 (after the existing `--node` flag):

```ruby
c.desc "Filter by VM/CT ID (repeatable)"
c.flag [:vmid], arg_name: "VMID", multiple: true
```

Then modify `run_describe` (line 124-132) to pass `vmid:`:

```ruby
def run_describe(handler)
  service = Services::Get::ResourceService.new(
    handler: handler,
    format: @global_options[:output] || "table",
    color_enabled: determine_color_enabled
  )
  output = service.describe(name: @resource_name, node: @options[:node], args: @extra_args, vmid: @options[:vmid])
  puts output
end
```

**Step 3: Update `ResourceService#list` and `#describe` to pass `vmid:` through**

In `lib/pvectl/services/get/resource_service.rb`, update the `list` and `describe` methods to accept and forward `vmid:`:

```ruby
def list(node: nil, name: nil, args: [], storage: nil, vmid: nil, **options)
  models = @handler.list(node: node, name: name, args: args, storage: storage, vmid: vmid, **options)
  presenter = @handler.presenter
  format_output(models, presenter)
end

def describe(name:, node: nil, args: [], vmid: nil)
  result = @handler.describe(name: name, node: node, args: args, vmid: vmid)
  presenter = @handler.presenter

  if result.is_a?(Array)
    format_output(result, presenter)
  else
    format_output_describe(result, presenter)
  end
end
```

**Step 4: Run full test suite**

Run: `bundle exec rake test`
Expected: All tests pass (no regressions — `vmid:` defaults to `nil` so other handlers are unaffected via `**_options`)

**Step 5: Commit**

```bash
git add lib/pvectl/commands/get/command.rb lib/pvectl/commands/describe/command.rb lib/pvectl/services/get/resource_service.rb
git commit -m "feat(cli): add --vmid repeatable flag to get and describe commands"
```

---

### Task 5: Refactor `CreateSnapshot` to GLI sub-command

Convert `CreateSnapshot` from case-statement dispatch to a GLI sub-command with `register_subcommand(parent)`. Snapshot name becomes the first positional argument, VMIDs move to `--vmid` flag.

**Files:**
- Modify: `lib/pvectl/commands/create_snapshot.rb`
- Modify: `lib/pvectl/commands/create_vm.rb:91-113`
- Modify: `test/unit/commands/create_snapshot_test.rb`
- Modify: `sig/pvectl/commands/create_snapshot.rbs`

**Step 1: Write failing tests**

Replace `test/unit/commands/create_snapshot_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class CreateSnapshotTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @original_stdout = $stdout
    $stderr = StringIO.new
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_usage_error_when_no_snapshot_name
    exit_code = Pvectl::Commands::CreateSnapshot.execute([], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_for_missing_snapshot_name
    Pvectl::Commands::CreateSnapshot.execute([], {}, {})
    assert_includes $stderr.string, "Snapshot name required"
  end

  def test_parses_snapshot_name_from_first_arg
    cmd = Pvectl::Commands::CreateSnapshot.new(["before-upgrade"], {}, {})
    assert_equal "before-upgrade", cmd.instance_variable_get(:@snapshot_name)
  end

  def test_parses_vmids_from_option
    cmd = Pvectl::Commands::CreateSnapshot.new(["snap1"], { vmid: ["100", "101"] }, {})
    assert_equal [100, 101], cmd.instance_variable_get(:@vmids)
  end

  def test_vmids_empty_when_no_vmid_option
    cmd = Pvectl::Commands::CreateSnapshot.new(["snap1"], {}, {})
    assert_equal [], cmd.instance_variable_get(:@vmids)
  end

  def test_parses_node_from_option
    cmd = Pvectl::Commands::CreateSnapshot.new(["snap1"], { node: "pve1" }, {})
    assert_equal "pve1", cmd.instance_variable_get(:@node)
  end

  def test_validates_vmid_is_numeric
    Pvectl::Commands::CreateSnapshot.execute(["snap1"], { vmid: ["abc"] }, {})
    assert_includes $stderr.string, "Invalid VMID"
  end

  def test_returns_usage_error_for_invalid_vmid
    exit_code = Pvectl::Commands::CreateSnapshot.execute(["snap1"], { vmid: ["abc"] }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end
end

class CreateSnapshotConfirmationTest < Minitest::Test
  class TestableCreateSnapshot < Pvectl::Commands::CreateSnapshot
    def test_confirm_operation
      confirm_operation
    end
  end

  def setup
    @original_stdin = $stdin
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stdin = @original_stdin
    $stdout = @original_stdout
    $stderr = @original_stderr
  end

  def test_skips_confirmation_for_single_vmid
    cmd = TestableCreateSnapshot.new(["snap1"], { vmid: ["100"] }, {})
    result = cmd.test_confirm_operation
    assert result, "Single VMID should not require confirmation"
  end

  def test_skips_confirmation_with_yes_flag
    cmd = TestableCreateSnapshot.new(["snap1"], { vmid: ["100", "101"], yes: true }, {})
    result = cmd.test_confirm_operation
    assert result, "--yes flag should skip confirmation"
  end

  def test_confirms_multi_vmid_operation_with_y_response
    cmd = TestableCreateSnapshot.new(["snap1"], { vmid: ["100", "101"] }, {})

    $stdin = StringIO.new("y\n")
    $stdout = StringIO.new

    result = cmd.test_confirm_operation
    assert result, "Should proceed with 'y' response"
  end

  def test_aborts_multi_vmid_operation_with_n_response
    cmd = TestableCreateSnapshot.new(["snap1"], { vmid: ["100", "101"] }, {})

    $stdin = StringIO.new("n\n")
    $stdout = StringIO.new

    result = cmd.test_confirm_operation
    refute result, "Should abort with 'n' response"
  end

  def test_cluster_wide_confirmation_prompt
    cmd = TestableCreateSnapshot.new(["before-upgrade"], {}, {})

    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd.test_confirm_operation
    output_str = output.string

    assert_includes output_str, "You are about to create snapshot"
    assert_includes output_str, "before-upgrade"
    assert_includes output_str, "ALL VMs/CTs"
    assert_includes output_str, "Proceed? [y/N]:"
  end

  def test_multi_vmid_confirmation_prompt
    cmd = TestableCreateSnapshot.new(["before-upgrade"], { vmid: ["100", "101", "102"] }, {})

    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd.test_confirm_operation
    output_str = output.string

    assert_includes output_str, "You are about to create snapshot"
    assert_includes output_str, "before-upgrade"
    assert_includes output_str, "3 VMs"
    assert_includes output_str, "100"
    assert_includes output_str, "101"
    assert_includes output_str, "102"
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib:test test/unit/commands/create_snapshot_test.rb`
Expected: Failures — constructor signature changed

**Step 3: Implement CreateSnapshot as sub-command**

Replace `lib/pvectl/commands/create_snapshot.rb`:

```ruby
# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl create snapshot` sub-command.
    #
    # Creates snapshots for VMs/containers. Snapshot name is the first
    # positional argument, VMIDs are specified via --vmid flag.
    # Without --vmid, operates on ALL VMs/CTs in the cluster.
    #
    # @example Create single snapshot
    #   pvectl create snapshot before-upgrade --vmid 100
    #
    # @example Create for multiple VMs
    #   pvectl create snapshot before-upgrade --vmid 100 --vmid 101
    #
    # @example Create cluster-wide
    #   pvectl create snapshot before-upgrade --yes
    #
    class CreateSnapshot
      VMID_PATTERN = /\A[1-9]\d{0,8}\z/

      # Registers as a sub-command under the parent create command.
      #
      # @param parent [GLI::Command] the parent create command
      # @return [void]
      def self.register_subcommand(parent)
        parent.command :snapshot do |s|
          s.desc "VM/CT ID (repeatable)"
          s.flag [:vmid], arg_name: "VMID", multiple: true

          s.desc "Filter by node"
          s.flag [:node], arg_name: "NODE"

          s.desc "Snapshot description"
          s.flag [:description], arg_name: "TEXT"

          s.desc "Save VM memory state (QEMU only)"
          s.switch [:vmstate], negatable: false

          s.desc "Skip confirmation prompt"
          s.switch [:yes, :y], negatable: false

          s.desc "Timeout in seconds for sync operations"
          s.flag [:timeout], type: Integer, arg_name: "SECONDS"

          s.desc "Force async mode (return task ID immediately)"
          s.switch [:async], negatable: false

          s.desc "Stop on first error"
          s.switch [:"fail-fast"], negatable: false

          s.action do |global_options, options, args|
            exit_code = execute(args, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the create snapshot command.
      #
      # @param args [Array<String>] positional args (snapshot name)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(args, options, global_options)
        new(args, options, global_options).execute
      end

      # Initializes a create snapshot command.
      #
      # @param args [Array<String>] positional args (snapshot name)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = Array(args)
        @options = options
        @global_options = global_options
        @snapshot_name = @args.first
        @vmids = parse_vmids(options[:vmid])
        @node = options[:node]
      end

      # Executes the create snapshot command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Snapshot name required") unless @snapshot_name
        return usage_error("Invalid VMID: #{invalid_vmid}") if invalid_vmid

        perform_operation
      end

      private

      # Parses --vmid flag values to integer array.
      #
      # @param vmid_values [Array<String>, nil] raw vmid values
      # @return [Array<Integer>] parsed VMIDs
      def parse_vmids(vmid_values)
        return [] if vmid_values.nil? || vmid_values.empty?

        Array(vmid_values).map(&:to_i)
      end

      # Finds first invalid VMID in options.
      #
      # @return [String, nil] invalid VMID value or nil
      def invalid_vmid
        return nil if @options[:vmid].nil? || @options[:vmid].empty?

        Array(@options[:vmid]).find { |v| !VMID_PATTERN.match?(v.to_s) }
      end

      # Performs the snapshot creation operation.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        snapshot_repo = Pvectl::Repositories::Snapshot.new(connection)
        resolver = Pvectl::Utils::ResourceResolver.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::Snapshot.new(
          snapshot_repo: snapshot_repo,
          resource_resolver: resolver,
          task_repo: task_repo,
          options: service_options
        )

        return ExitCodes::SUCCESS unless confirm_operation

        results = service.create(
          @vmids,
          name: @snapshot_name,
          description: @options[:description],
          vmstate: @options[:vmstate] || false,
          node: @node
        )

        output_results(results)
        determine_exit_code(results)
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError
        raise
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      # Confirms operation with user prompt.
      #
      # @return [Boolean] true if operation should proceed
      def confirm_operation
        return true if @vmids.size == 1
        return true if @options[:yes]

        if @vmids.empty?
          $stdout.puts "You are about to create snapshot '#{@snapshot_name}' for ALL VMs/CTs in the cluster."
        else
          $stdout.puts "You are about to create snapshot '#{@snapshot_name}' for #{@vmids.size} VMs:"
          @vmids.each { |vmid| $stdout.puts "  - #{vmid}" }
        end
        $stdout.puts ""
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
      end

      # Loads configuration.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Builds service options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:timeout] = @options[:timeout] if @options[:timeout]
        opts[:async] = true if @options[:async]
        opts[:fail_fast] = true if @options[:"fail-fast"]
        opts
      end

      # Outputs operation results.
      #
      # @param results [Array<Models::OperationResult>] results
      # @return [void]
      def output_results(results)
        presenter = Pvectl::Presenters::SnapshotOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format(results, presenter, color: color_flag)
        puts output
      end

      # Determines exit code.
      #
      # @param results [Array<Models::OperationResult>] results
      # @return [Integer] exit code
      def determine_exit_code(results)
        return ExitCodes::SUCCESS if results.all?(&:successful?)
        return ExitCodes::SUCCESS if results.all?(&:pending?)

        ExitCodes::GENERAL_ERROR
      end

      # Outputs usage error.
      #
      # @param message [String] error message
      # @return [Integer] exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
```

**Step 4: Update `create_vm.rb` to use hybrid sub-command pattern**

In `lib/pvectl/commands/create_vm.rb`, make these changes:

1. Remove snapshot-specific flags from the parent command (lines 32-40: `--name`, `--description`/`--notes` for snapshots, `--vmstate`). Keep `--description`/`--notes` since it's also used by backup. Keep `--vmstate` ONLY if used elsewhere — check first. If only snapshot uses it, remove it.

2. Add `CreateSnapshot.register_subcommand(c)` before the `c.action` block (before line 91).

3. Remove the `"snapshot"` case from the dispatcher (lines 100-101).

Modified registration section:

```ruby
c.action do |global_options, options, args|
  resource_type = args.shift
  resource_ids = args

  exit_code = case resource_type
  when "vm"
    Commands::CreateVm.execute(resource_ids, options, global_options)
  when "container", "ct"
    Commands::CreateContainer.execute(resource_ids, options, global_options)
  when "backup"
    options[:notes] ||= options[:description]
    Commands::CreateBackup.execute(resource_type, resource_ids, options, global_options)
  else
    $stderr.puts "Error: Unknown resource type: #{resource_type}"
    $stderr.puts "Valid types: vm, container, snapshot, backup"
    ExitCodes::USAGE_ERROR
  end

  exit exit_code if exit_code != 0
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rake test`
Expected: All tests pass

**Step 6: Update RBS signature**

Replace `sig/pvectl/commands/create_snapshot.rbs`:

```rbs
module Pvectl
  module Commands
    class CreateSnapshot
      VMID_PATTERN: Regexp

      def self.register_subcommand: (untyped parent) -> void

      def self.execute: (Array[String] args, Hash[Symbol, untyped] options, Hash[Symbol, untyped] global_options) -> Integer

      def initialize: (Array[String] args, Hash[Symbol, untyped] options, Hash[Symbol, untyped] global_options) -> void

      def execute: () -> Integer

      private

      def parse_vmids: (Array[String]? vmid_values) -> Array[Integer]

      def invalid_vmid: () -> String?

      def perform_operation: () -> Integer

      def confirm_operation: () -> bool

      def load_config: () -> void

      def service_options: () -> Hash[Symbol, untyped]

      def output_results: (Array[untyped] results) -> void

      def determine_exit_code: (Array[untyped] results) -> Integer

      def usage_error: (String message) -> Integer
    end
  end
end
```

Run: `BUNDLE_GEMFILE="" rbs parse sig/pvectl/commands/create_snapshot.rbs`

**Step 7: Commit**

```bash
git add lib/pvectl/commands/create_snapshot.rb lib/pvectl/commands/create_vm.rb test/unit/commands/create_snapshot_test.rb sig/pvectl/commands/create_snapshot.rbs
git commit -m "feat(cli): refactor create snapshot to GLI sub-command with --vmid flag"
```

---

### Task 6: Refactor `DeleteSnapshot` to GLI sub-command with `--all` mode

Convert `DeleteSnapshot` to a GLI sub-command. Snapshot name becomes positional arg. Add `--all` switch for deleting all snapshots. Add interactive confirmation prompt.

**Files:**
- Modify: `lib/pvectl/commands/delete_snapshot.rb`
- Modify: `lib/pvectl/commands/delete_vm.rb:64-83`
- Modify: `test/unit/commands/delete_snapshot_test.rb`
- Modify: `sig/pvectl/commands/delete_snapshot.rbs`

**Step 1: Write failing tests**

Replace `test/unit/commands/delete_snapshot_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class DeleteSnapshotTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @original_stdout = $stdout
    @original_stdin = $stdin
    $stderr = StringIO.new
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    $stdin = @original_stdin
  end

  def test_returns_usage_error_when_no_name_and_no_all
    exit_code = Pvectl::Commands::DeleteSnapshot.execute([], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_for_missing_name_and_all
    Pvectl::Commands::DeleteSnapshot.execute([], {}, {})
    assert_includes $stderr.string, "Snapshot name or --all required"
  end

  def test_returns_usage_error_when_name_and_all_both_provided
    exit_code = Pvectl::Commands::DeleteSnapshot.execute(["snap1"], { all: true }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_for_name_and_all_conflict
    Pvectl::Commands::DeleteSnapshot.execute(["snap1"], { all: true }, {})
    assert_includes $stderr.string, "Cannot use --all with snapshot name"
  end

  def test_parses_snapshot_name_from_first_arg
    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { yes: true }, {})
    assert_equal "snap1", cmd.instance_variable_get(:@snapshot_name)
  end

  def test_parses_vmids_from_option
    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { vmid: ["100", "101"], yes: true }, {})
    assert_equal [100, 101], cmd.instance_variable_get(:@vmids)
  end

  def test_vmids_empty_when_no_vmid_option
    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { yes: true }, {})
    assert_equal [], cmd.instance_variable_get(:@vmids)
  end

  def test_validates_vmid_is_numeric
    Pvectl::Commands::DeleteSnapshot.execute(["snap1"], { vmid: ["abc"], yes: true }, {})
    assert_includes $stderr.string, "Invalid VMID"
  end

  def test_all_mode_with_vmid
    cmd = Pvectl::Commands::DeleteSnapshot.new([], { all: true, vmid: ["100"], yes: true }, {})
    assert cmd.instance_variable_get(:@delete_all)
    assert_equal [100], cmd.instance_variable_get(:@vmids)
  end

  # --- confirmation prompt tests ---

  def test_prompts_for_confirmation_without_yes
    # Would need to connect to API, so just test it asks
    $stdin = StringIO.new("n\n")
    $stdout = StringIO.new

    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { vmid: ["100"] }, {})
    result = cmd.send(:confirm_operation)

    refute result
  end

  def test_skips_confirmation_with_yes_flag
    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { vmid: ["100"], yes: true }, {})
    result = cmd.send(:confirm_operation)

    assert result
  end

  def test_confirmation_prompt_for_named_delete
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd = Pvectl::Commands::DeleteSnapshot.new(["before-upgrade"], { vmid: ["100", "101"] }, {})
    cmd.send(:confirm_operation)

    assert_includes output.string, "delete snapshot"
    assert_includes output.string, "before-upgrade"
  end

  def test_confirmation_prompt_for_delete_all
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd = Pvectl::Commands::DeleteSnapshot.new([], { all: true, vmid: ["100"] }, {})
    cmd.send(:confirm_operation)

    assert_includes output.string, "delete ALL snapshots"
  end

  def test_cluster_wide_delete_confirmation
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], {}, {})
    cmd.send(:confirm_operation)

    assert_includes output.string, "ALL VMs/CTs"
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib:test test/unit/commands/delete_snapshot_test.rb`
Expected: Failures — constructor signature changed

**Step 3: Implement DeleteSnapshot as sub-command**

Replace `lib/pvectl/commands/delete_snapshot.rb`:

```ruby
# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl delete snapshot` sub-command.
    #
    # Deletes snapshots from VMs/containers. Snapshot name is the first
    # positional argument, or use --all to delete ALL snapshots.
    # VMIDs are specified via --vmid flag. Without --vmid, operates cluster-wide.
    #
    # @example Delete named snapshot
    #   pvectl delete snapshot before-upgrade --vmid 100 --yes
    #
    # @example Delete all snapshots from a VM
    #   pvectl delete snapshot --all --vmid 100 --yes
    #
    # @example Delete named snapshot cluster-wide
    #   pvectl delete snapshot before-upgrade --yes
    #
    class DeleteSnapshot
      VMID_PATTERN = /\A[1-9]\d{0,8}\z/

      # Registers as a sub-command under the parent delete command.
      #
      # @param parent [GLI::Command] the parent delete command
      # @return [void]
      def self.register_subcommand(parent)
        parent.command :snapshot do |s|
          s.desc "VM/CT ID (repeatable)"
          s.flag [:vmid], arg_name: "VMID", multiple: true

          s.desc "Filter by node"
          s.flag [:node], arg_name: "NODE"

          s.desc "Delete ALL snapshots"
          s.switch [:all], negatable: false

          s.desc "Force removal even if disk snapshot fails"
          s.switch [:force, :f], negatable: false

          s.desc "Skip confirmation prompt"
          s.switch [:yes, :y], negatable: false

          s.desc "Timeout in seconds for sync operations"
          s.flag [:timeout], type: Integer, arg_name: "SECONDS"

          s.desc "Force async mode"
          s.switch [:async], negatable: false

          s.desc "Stop on first error"
          s.switch [:"fail-fast"], negatable: false

          s.action do |global_options, options, args|
            exit_code = execute(args, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the delete snapshot command.
      #
      # @param args [Array<String>] positional args (snapshot name)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(args, options, global_options)
        new(args, options, global_options).execute
      end

      # Initializes a delete snapshot command.
      #
      # @param args [Array<String>] positional args (snapshot name)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = Array(args)
        @options = options
        @global_options = global_options
        @snapshot_name = @args.first
        @vmids = parse_vmids(options[:vmid])
        @node = options[:node]
        @delete_all = options[:all] || false
      end

      # Executes the delete snapshot command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Snapshot name or --all required") if @snapshot_name.nil? && !@delete_all
        return usage_error("Cannot use --all with snapshot name") if @snapshot_name && @delete_all
        return usage_error("Invalid VMID: #{invalid_vmid}") if invalid_vmid

        return ExitCodes::SUCCESS unless confirm_operation

        perform_operation
      end

      private

      # Parses --vmid flag values to integer array.
      #
      # @param vmid_values [Array<String>, nil] raw vmid values
      # @return [Array<Integer>] parsed VMIDs
      def parse_vmids(vmid_values)
        return [] if vmid_values.nil? || vmid_values.empty?

        Array(vmid_values).map(&:to_i)
      end

      # Finds first invalid VMID in options.
      #
      # @return [String, nil] invalid VMID value or nil
      def invalid_vmid
        return nil if @options[:vmid].nil? || @options[:vmid].empty?

        Array(@options[:vmid]).find { |v| !VMID_PATTERN.match?(v.to_s) }
      end

      # Confirms operation with user prompt.
      #
      # @return [Boolean] true if operation should proceed
      def confirm_operation
        return true if @options[:yes]

        if @delete_all
          if @vmids.empty?
            $stdout.puts "You are about to delete ALL snapshots from ALL VMs/CTs in the cluster."
          else
            $stdout.puts "You are about to delete ALL snapshots from #{@vmids.size} VMs:"
            @vmids.each { |vmid| $stdout.puts "  - #{vmid}" }
          end
        else
          if @vmids.empty?
            $stdout.puts "You are about to delete snapshot '#{@snapshot_name}' from ALL VMs/CTs in the cluster."
          elsif @vmids.size == 1
            $stdout.puts "You are about to delete snapshot '#{@snapshot_name}' from VM #{@vmids.first}."
          else
            $stdout.puts "You are about to delete snapshot '#{@snapshot_name}' from #{@vmids.size} VMs:"
            @vmids.each { |vmid| $stdout.puts "  - #{vmid}" }
          end
        end
        $stdout.puts ""
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
      end

      # Performs the snapshot deletion operation.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        snapshot_repo = Pvectl::Repositories::Snapshot.new(connection)
        resolver = Pvectl::Utils::ResourceResolver.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::Snapshot.new(
          snapshot_repo: snapshot_repo,
          resource_resolver: resolver,
          task_repo: task_repo,
          options: service_options
        )

        results = if @delete_all
          service.delete_all(@vmids, node: @node, force: @options[:force] || false)
        else
          service.delete(@vmids, @snapshot_name, force: @options[:force] || false, node: @node)
        end

        output_results(results)
        determine_exit_code(results)
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError
        raise
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      # Loads configuration.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Builds service options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:timeout] = @options[:timeout] if @options[:timeout]
        opts[:async] = true if @options[:async]
        opts[:fail_fast] = true if @options[:"fail-fast"]
        opts
      end

      # Outputs operation results.
      #
      # @param results [Array<Models::OperationResult>] results
      # @return [void]
      def output_results(results)
        presenter = Pvectl::Presenters::SnapshotOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format(results, presenter, color: color_flag)
        puts output
      end

      # Determines exit code.
      #
      # @param results [Array<Models::OperationResult>] results
      # @return [Integer] exit code
      def determine_exit_code(results)
        return ExitCodes::SUCCESS if results.all?(&:successful?)
        return ExitCodes::SUCCESS if results.all?(&:pending?)

        ExitCodes::GENERAL_ERROR
      end

      # Outputs usage error.
      #
      # @param message [String] error message
      # @return [Integer] exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
```

**Step 4: Update `delete_vm.rb` to use hybrid sub-command pattern**

In `lib/pvectl/commands/delete_vm.rb`:

1. Add `DeleteSnapshot.register_subcommand(c)` before the `c.action` block (before line 64).
2. Remove the `"snapshot"` case from the dispatcher (line 72-73).

The action block becomes:

```ruby
c.action do |global_options, options, args|
  resource_type = args.shift

  exit_code = case resource_type
  when "vm"
    Commands::DeleteVm.execute(resource_type, args, options, global_options)
  when "container", "ct"
    Commands::DeleteContainer.execute(resource_type, args, options, global_options)
  when "backup"
    Commands::DeleteBackup.execute(resource_type, args, options, global_options)
  else
    $stderr.puts "Error: Unknown resource type: #{resource_type}"
    $stderr.puts "Valid types: vm, container, ct, snapshot, backup"
    ExitCodes::USAGE_ERROR
  end

  exit exit_code if exit_code != 0
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rake test`
Expected: All tests pass

**Step 6: Update RBS signature**

Replace `sig/pvectl/commands/delete_snapshot.rbs`:

```rbs
module Pvectl
  module Commands
    class DeleteSnapshot
      VMID_PATTERN: Regexp

      def self.register_subcommand: (untyped parent) -> void

      def self.execute: (Array[String] args, Hash[Symbol, untyped] options, Hash[Symbol, untyped] global_options) -> Integer

      def initialize: (Array[String] args, Hash[Symbol, untyped] options, Hash[Symbol, untyped] global_options) -> void

      def execute: () -> Integer

      private

      def parse_vmids: (Array[String]? vmid_values) -> Array[Integer]

      def invalid_vmid: () -> String?

      def confirm_operation: () -> bool

      def perform_operation: () -> Integer

      def load_config: () -> void

      def service_options: () -> Hash[Symbol, untyped]

      def output_results: (Array[untyped] results) -> void

      def determine_exit_code: (Array[untyped] results) -> Integer

      def usage_error: (String message) -> Integer
    end
  end
end
```

Run: `BUNDLE_GEMFILE="" rbs parse sig/pvectl/commands/delete_snapshot.rbs`

**Step 7: Commit**

```bash
git add lib/pvectl/commands/delete_snapshot.rb lib/pvectl/commands/delete_vm.rb test/unit/commands/delete_snapshot_test.rb sig/pvectl/commands/delete_snapshot.rbs
git commit -m "feat(cli): refactor delete snapshot to GLI sub-command with --all mode"
```

---

### Task 7: Clean up parent command flags and run full verification

Remove snapshot-specific flags from parent `create` command that are now on the sub-command. Update documentation (CHANGELOG, README). Run full test suite.

**Files:**
- Modify: `lib/pvectl/commands/create_vm.rb:32-40` (remove snapshot-only flags)
- Modify: `CHANGELOG.md`
- Modify: `README.md`

**Step 1: Clean up create_vm.rb flags**

In `lib/pvectl/commands/create_vm.rb`, remove the snapshot-specific flags section (lines 32-40):

Remove:
```ruby
# Snapshot-specific flags
c.desc "Snapshot name (required for snapshots)"
c.flag [:name], arg_name: "NAME"
```

**Important:** Keep `--name` if it's used by VM creation (check `CreateVm#perform_create` — yes, it uses `@options[:name]`). So `--name` stays on the parent. Keep `--description`/`--notes` (used by backup). Keep `--vmstate` — remove ONLY if snapshot is the sole user.

Check `--vmstate` usage: search codebase for `:vmstate` outside snapshot files. If only snapshots use it, remove from parent. If create vm also uses it, keep it.

Remove only the comment "Snapshot-specific flags" and the `--vmstate` switch if snapshot-only.

**Step 2: Update CHANGELOG.md**

Add under `## [Unreleased]` > `### Changed`:

```markdown
- **cli**: Unified snapshot CLI syntax — snapshot name is now a positional argument, VMIDs use `--vmid` flag (repeatable), `--node` filters by node, `--all` deletes all snapshots (**breaking change**)
- **cli**: `create snapshot` and `delete snapshot` are now GLI sub-commands with dedicated flags
- **cli**: `get snapshots` and `describe snapshot` accept `--vmid` and `--node` flags
- **services**: Snapshot service methods accept `node:` parameter for node filtering
- **services**: Added `delete_all` method for removing all snapshots from VMs
```

**Step 3: Update README.md**

Update the snapshot examples section to reflect new syntax:

```markdown
### Snapshots

```bash
# List all snapshots cluster-wide
pvectl get snapshots

# List snapshots for specific VMs
pvectl get snapshots --vmid 100 --vmid 101

# List snapshots filtered by node
pvectl get snapshots --node pve1

# Create snapshot
pvectl create snapshot before-upgrade --vmid 100

# Create snapshot for multiple VMs
pvectl create snapshot before-upgrade --vmid 100 --vmid 101

# Create snapshot cluster-wide
pvectl create snapshot before-upgrade --yes

# Create snapshot with description and VM state
pvectl create snapshot before-upgrade --vmid 100 --description "Pre-upgrade" --vmstate

# Describe snapshot
pvectl describe snapshot before-upgrade --vmid 100

# Describe snapshot cluster-wide (search all VMs)
pvectl describe snapshot before-upgrade

# Delete snapshot
pvectl delete snapshot before-upgrade --vmid 100 --yes

# Delete snapshot from all VMs
pvectl delete snapshot before-upgrade --yes

# Delete ALL snapshots from a VM
pvectl delete snapshot --all --vmid 100 --yes

# Delete ALL snapshots cluster-wide
pvectl delete snapshot --all --yes

# Rollback to snapshot
pvectl rollback snapshot 100 before-upgrade --yes
```
```

**Step 4: Run full test suite**

Run: `bundle exec rake test`
Expected: All tests pass, 0 failures

**Step 5: Commit**

```bash
git add lib/pvectl/commands/create_vm.rb CHANGELOG.md README.md
git commit -m "docs: update changelog and readme for unified snapshot CLI syntax"
```
