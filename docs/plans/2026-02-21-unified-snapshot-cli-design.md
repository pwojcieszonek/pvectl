# Unified Snapshot CLI Syntax — Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor all snapshot commands to use consistent argument order (name first, VMIDs as repeatable `--vmid` flag), add `--node` filtering, and add `--all` delete mode.

**Architecture:** GLI sub-commands for `create snapshot` and `delete snapshot` with hybrid registration (sub-command + parent fallback). Flags `--vmid`/`--node` added to `get`/`describe` at command level. Service layer gains `node:` filtering and `delete_all` method.

**Breaking changes:** Yes — `--name` flag removed from create, argument order changed in delete, VMIDs become `--vmid` flag everywhere.

---

## 1. Unified CLI Syntax

```
# GET — list snapshots
pvectl get snapshots [--vmid N]... [--node NODE]

# CREATE — create snapshot
pvectl create snapshot <name> [--vmid N]... [--node NODE] [--description D] [--vmstate] [--yes]

# DELETE — delete snapshot by name
pvectl delete snapshot <name> [--vmid N]... [--node NODE] [--force] [--yes]

# DELETE --all — delete ALL snapshots
pvectl delete snapshot --all [--vmid N]... [--node NODE] [--force] [--yes]

# DESCRIBE — snapshot details
pvectl describe snapshot <name> [--vmid N]... [--node NODE]

# ROLLBACK — unchanged (always single-VM)
pvectl rollback snapshot <vmid> <snapname> [--start]
```

### Rules

- `--vmid` — repeatable flag (`--vmid 100 --vmid 101`), optional. Absent = cluster-wide operation
- `--node` — filters resources to a specific node, combinable with `--vmid`
- `<name>` — first positional argument (not a `--name` flag)
- `--all` in delete — deletes ALL snapshots (no `<name>` required)
- `--yes` skips interactive confirmation prompt. Without it — interactive prompt is shown
- Rollback stays unchanged — always single-VM operation

## 2. Architecture — GLI Sub-Commands

### Current registration (case-statement dispatcher)

```ruby
cli.command :create do |c|
  c.action do |global, options, args|
    case args.first
    when "snapshot" then CreateSnapshot.execute(...)
    when "vm"       then ...
    end
  end
end
```

### Target architecture — hybrid sub-command

```ruby
cli.command :create do |c|
  # Sub-command: snapshot (own flags)
  CreateSnapshot.register_subcommand(c)

  # Parent fallback: vm, container, backup
  c.action do |global, options, args|
    case args.first
    when "vm"        then ...
    when "container" then ...
    when "backup"    then ...
    end
  end
end
```

### CreateSnapshot.register_subcommand(parent)

```ruby
def self.register_subcommand(parent)
  parent.command :snapshot do |s|
    s.flag [:vmid], multiple: true, desc: "VM/CT ID (repeatable)"
    s.flag [:node], desc: "Filter by node"
    s.flag [:description], desc: "Snapshot description"
    s.switch [:vmstate], desc: "Include VM memory state"
    s.switch [:yes, :y], desc: "Skip confirmation"

    s.action do |global_options, options, args|
      execute(args, options, global_options)
    end
  end
end
```

### DeleteSnapshot.register_subcommand(parent)

```ruby
def self.register_subcommand(parent)
  parent.command :snapshot do |s|
    s.flag [:vmid], multiple: true, desc: "VM/CT ID (repeatable)"
    s.flag [:node], desc: "Filter by node"
    s.switch [:all], desc: "Delete ALL snapshots"
    s.switch [:force], desc: "Force removal"
    s.switch [:yes, :y], desc: "Confirm deletion"

    s.action do |global_options, options, args|
      execute(args, options, global_options)
    end
  end
end
```

### Get/Describe — flags at command level

```ruby
cli.command :get do |c|
  c.flag [:vmid], multiple: true, desc: "Filter by VM/CT ID"
  c.flag [:node], desc: "Filter by node"
  # ... handler registry dispatch
end
```

### GLI hybrid behavior (verified)

- `pvectl create snapshot name --vmid 100` → hits snapshot sub-command
- `pvectl create vm 100` → falls through to parent action (case dispatcher)
- `pvectl create container 100` → falls through to parent action
- No changes needed to vm/container/backup registration

## 3. Service Layer — `--node` and `--all`

### Node filtering

Add optional `node:` parameter to service methods. Filtering happens after resolver:

```ruby
def list(vmids, node: nil)
  resources = resolve_resources(vmids)
  resources = resources.select { |r| r[:node] == node } if node
  return [] if resources.empty?
  # ...
end
```

Shared private method:

```ruby
def resolve_resources(vmids)
  vmids.empty? ? @resolver.resolve_all : @resolver.resolve_multiple(vmids)
end
```

### Delete --all mode

New `delete_all` method in service:

```ruby
def delete_all(vmids, node: nil, force: false)
  resources = resolve_resources(vmids)
  resources = resources.select { |r| r[:node] == node } if node
  return [] if resources.empty?

  execute_multi(resources, :delete_all) do |r|
    snapshots = @snapshot_repo.list(r[:vmid], r[:node], r[:type])
    snapshots.reject! { |s| s.name == "current" }
    snapshots.each do |snap|
      @snapshot_repo.delete(r[:vmid], r[:node], r[:type], snap.name, force: force)
    end
  end
end
```

### Existing methods

`create`, `delete`, `describe`, `list` all gain `node:` parameter.

## 4. Error Handling and Validation

| Scenario | Behavior |
|----------|----------|
| `create snapshot` (no name) | `USAGE_ERROR` — "Snapshot name required" |
| `delete snapshot` (no name and no `--all`) | `USAGE_ERROR` — "Snapshot name or --all required" |
| `delete snapshot name --all` | `USAGE_ERROR` — "Cannot use --all with snapshot name" |
| `delete snapshot name` (no `--yes`) | **Interactive prompt** — "You are about to delete snapshot 'name' from N VMs... Proceed? [y/N]:" |
| `delete snapshot --all` (no `--yes`) | **Interactive prompt** — "You are about to delete ALL snapshots from N VMs... Proceed? [y/N]:" |
| `delete snapshot name --yes` | Skips prompt, executes immediately |
| `--vmid abc` (non-numeric) | `USAGE_ERROR` — "Invalid VMID: abc" |
| `--node` nonexistent | Empty result (resolver finds no resources on that node) |
| `--vmid` + `--node` — VM on different node | Empty result after filter |
| Cluster-wide create (no `--yes`) | Interactive prompt with VM list |
| Single-VM create | No prompt (as before) |

## 5. File Changes

| File | Change |
|------|--------|
| `lib/pvectl/commands/create_snapshot.rb` | Refactor to `register_subcommand(parent)`, positional `name` arg, `--vmid`/`--node` flags |
| `lib/pvectl/commands/delete_snapshot.rb` | Refactor to `register_subcommand(parent)`, `name` arg or `--all`, `--vmid`/`--node` flags |
| `lib/pvectl/commands/create_vm.rb` | Hybrid: `CreateSnapshot.register_subcommand(c)` + parent fallback |
| `lib/pvectl/commands/delete_vm.rb` | Hybrid: `DeleteSnapshot.register_subcommand(c)` + parent fallback |
| `lib/pvectl/commands/get/command.rb` | Add `--vmid` (multiple) and `--node` flags |
| `lib/pvectl/commands/get/handlers/snapshots.rb` | Use `options[:vmid]` and `options[:node]` instead of `args` |
| `lib/pvectl/commands/describe/command.rb` | Add `--vmid` (multiple) and `--node` flags |
| `lib/pvectl/commands/describe/handlers/snapshots.rb` | Use `options[:vmid]` and `options[:node]` instead of `args` |
| `lib/pvectl/services/snapshot.rb` | `node:` param, `resolve_resources`, `delete_all` |
| `sig/pvectl/services/snapshot.rbs` | Updated signatures |
| `sig/pvectl/commands/*.rbs` | New signatures |
| Unit tests | New tests for new syntax, update existing |
| `CHANGELOG.md` | Breaking change entry |
| `README.md` | New syntax examples |
