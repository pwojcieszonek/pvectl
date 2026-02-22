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
pvectl describe vm 100            # Detailed VM info
pvectl top nodes                  # Resource usage
```

## Commands

| Command | Description |
|---------|-------------|
| `get` | List resources (nodes, VMs, containers, storage, disks, snapshots, backups, tasks) |
| `describe` | Show detailed information about a resource |
| `top` | Display resource usage metrics (CPU, memory, disk) |
| `logs` | Show logs and task history (syslog, journal, task detail) |
| `start` `stop` `shutdown` `restart` | Lifecycle management |
| `create` | Create VMs, containers, snapshots, or backups |
| `delete` | Delete resources |
| `clone` | Clone VMs or containers with optional config changes |
| `migrate` | Migrate resources between nodes (supports live migration) |
| `edit` | Edit VM/container configuration in $EDITOR |
| `template` | Convert VM/container to template |
| `resize disk` | Resize VM/container disks |
| `rollback` | Rollback to a snapshot |
| `restore` | Restore from a backup |
| `console` | Interactive terminal session |
| `ping` | Check cluster connectivity |
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
