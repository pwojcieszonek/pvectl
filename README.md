# pvectl

A command-line tool for managing Proxmox clusters with kubectl-like syntax.

**pvectl** wraps the Proxmox API as a Ruby gem, providing familiar commands for managing VMs, containers, nodes, storage, backups, and snapshots from the terminal.

> **Note:** This project is in active development. Some features may not yet be fully stable.

## Features

- **kubectl-like syntax** — familiar commands: `get`, `describe`, `top`, `logs`
- **Multi-resource management** — VMs, containers, nodes, storage, snapshots, backups
- **Batch operations** — act on multiple resources with selectors: `-l status=running`
- **Multiple output formats** — table, wide, JSON, YAML
- **Watch mode** — auto-refreshing resource lists
- **Interactive wizards** — guided VM/container creation
- **Console access** — interactive terminal sessions via WebSocket
- **Multi-cluster contexts** — kubeconfig-style context switching
- **Plugin system** — extend with gem-based or directory-based plugins
- **Template management** — convert VMs/containers to templates, linked cloning

## Addressing resources by name

All VM and container commands accept a VMID **or** a name. Numeric arguments
are matched against VMIDs first; non-numeric arguments (or numbers with no
matching VMID) are matched by name.

```bash
pvectl start vm web           # start VM named "web"
pvectl stop ct db             # stop container named "db"
pvectl describe vm web-prod   # describe every VM named "web-prod"
pvectl clone vm web --name web-clone   # clone source by name (unambiguous)
```

**Ambiguity rules:**

- **Multi-target commands** (`start`, `stop`, `shutdown`, `restart`, `reset`,
  `suspend`, `resume`, `delete`) act on **every** resource whose name matches.
  If more than one resource matches, a confirmation prompt lists all affected
  VMIDs before proceeding.
- **Single-target commands** (`clone`, `console`, `set`, `edit`) require an
  **unambiguous** match. If a name matches several resources, the command
  errors: `'web' matches multiple resources (VMIDs 100, 105) — specify a VMID`.

**Name uniqueness:** VM and container names must be unique across the entire
cluster. `create`, `clone`, and renames via `set`/`edit` fail if the name (or
container hostname) is already in use:

```
a VM or container named 'web' already exists (VMID 100 on pve1)
```

## Installation

```bash
gem install pvectl
```

Or add to your Gemfile:

```bash
bundle add pvectl
```

**Requirements:** Ruby >= 3.0.0

## Quick Start

On first run, pvectl launches an interactive configuration wizard:

```bash
$ pvectl get nodes
Proxmox server URL (e.g., https://pve.example.com:8006): https://pve.example.com:8006
Verify SSL certificate? (y/n) y
Authentication method:
  1. API Token (recommended)
  2. Username/Password
Enter number: 1
Token ID (e.g., root@pam!tokenid): root@pam!pvectl
Token Secret: ********
Context name: [default] production
```

Once configured, explore your cluster:

```bash
pvectl get nodes                  # List cluster nodes
pvectl get vms                    # List all VMs
pvectl get vms -o wide            # Extended columns
pvectl get subscription           # Show Proxmox subscription per node (key masked)
pvectl describe vm 100            # Detailed VM info
pvectl top nodes                  # Resource usage
```

## Commands

| Command | Description |
|---------|-------------|
| `get` | List resources (nodes, VMs, containers, storage, disks, volumes, snapshots, backups, tasks, dns, services, hosts, node-capabilities, subscription) |
| `describe` | Show detailed information about a resource (nodes, VMs, containers, storage, disks, volumes, snapshots) |
| `top` | Display resource usage metrics (CPU, memory, disk) |
| `logs` | Show logs and task history (syslog, journal, task detail) |
| `start` `stop` `shutdown` `restart` | Lifecycle management |
| `create` | Create VMs, containers, snapshots, or backups |
| `delete` | Delete resources |
| `clone` | Clone VMs or containers with optional config changes |
| `migrate` | Migrate resources between nodes (supports live migration) |
| `move disk` | Move VM disk / container volume between storages on the same node |
| `feature` | Query whether a feature (clone/snapshot/copy) is available for a VM/CT |
| `edit` | Edit resource configuration in $EDITOR (vm, container, node, volume, dns, hosts) |
| `set` | Set resource properties non-interactively with key=value pairs |
| `pull` | Export resource configuration as kubectl-like YAML manifests |
| `push` | Apply YAML manifests to cluster (create or update resources) |
| `template` | Convert VM/container to template |
| `unlink` | Unlink disk(s) from a VM (keep volume as `unused[n]` or delete with `--force`) |
| `rollback` | Rollback to a snapshot |
| `restore` | Restore from a backup |
| `console` | Interactive terminal session |
| `service` | Manage systemd services on Proxmox nodes (start, stop, restart, reload) |
| `apt` | Manage APT packages on Proxmox nodes (list, update, changelog, versions) |
| `cloudinit` | Manage cloud-init for VMs (`regenerate`, `pending`, `dump`) |
| `sendkey` | Send a QEMU monitor key event to a VM (e.g., `ctrl-alt-delete`) |
| `ping` | Check cluster connectivity |
| `wakeonlan` | Send Wake-on-LAN packet to a cluster node |
| `config` | Manage configuration (contexts, clusters, credentials) |

Use `pvectl help <command>` for detailed usage, examples, and options.

## Documentation

Full documentation is available in the [GitHub Wiki](https://github.com/pwojcieszonek/pvectl/wiki):

- **[Getting Started](https://github.com/pwojcieszonek/pvectl/wiki/Getting-Started)** — installation, configuration, first commands
- **[Configuration Guide](https://github.com/pwojcieszonek/pvectl/wiki/Configuration-Guide)** — contexts, auth methods, environment variables
- **[Command Reference](https://github.com/pwojcieszonek/pvectl/wiki/Command-Reference)** — detailed docs for every command
- **[Selectors & Filtering](https://github.com/pwojcieszonek/pvectl/wiki/Selectors-and-Filtering)** — filter resources with `-l` flag
- **[Output Formats](https://github.com/pwojcieszonek/pvectl/wiki/Output-Formats)** — table, wide, JSON, YAML
- **[Workflows](https://github.com/pwojcieszonek/pvectl/wiki/Workflows)** — common scenarios and best practices
- **[Plugin Development](https://github.com/pwojcieszonek/pvectl/wiki/Plugin-Development)** — extend pvectl with custom commands
- **[Troubleshooting](https://github.com/pwojcieszonek/pvectl/wiki/Troubleshooting)** — common issues and solutions

## Configuration

Configuration file: `~/.pvectl/config` (kubeconfig-style YAML)

```bash
pvectl config view                      # Show current config
pvectl config get-contexts              # List contexts
pvectl config use-context production    # Switch context
```

See the [Configuration Guide](https://github.com/pwojcieszonek/pvectl/wiki/Configuration-Guide) for details on multi-cluster setup, authentication methods, and environment variables.

## Plugins

pvectl supports plugins via gems (`pvectl-plugin-*`) and local files (`~/.pvectl/plugins/*.rb`). See [Plugin Development](https://github.com/pwojcieszonek/pvectl/wiki/Plugin-Development).

## Development

```bash
git clone https://github.com/pwojcieszonek/pvectl.git
cd pvectl
bin/setup
rake test
bundle exec exe/pvectl
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/pwojcieszonek/pvectl](https://github.com/pwojcieszonek/pvectl).

## License

Released under the [MIT License](https://opensource.org/licenses/MIT).
