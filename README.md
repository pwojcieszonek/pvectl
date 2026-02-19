# pvectl

A command-line tool for managing Proxmox clusters with kubectl-like syntax.

**pvectl** wraps the Proxmox API as a Ruby gem, providing familiar commands for managing VMs, containers, nodes, storage, backups, and snapshots from the terminal.

> **Note:** This project is in active development. Some features may not yet be fully stable.

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

## Commands Overview

### Read-Only Commands

| Command | Description | Example |
|---------|-------------|---------|
| `get` | List resources | `pvectl get vms` |
| `describe` | Detailed resource info | `pvectl describe vm 100` |
| `top` | Resource usage metrics | `pvectl top nodes` |
| `logs` | View logs and task history | `pvectl logs node pve1` |
| `ping` | Check cluster connectivity | `pvectl ping` |

### Interactive Commands

| Command | Description | Example |
|---------|-------------|---------|
| `console` | Open terminal session | `pvectl console vm 100` |

### Lifecycle Commands

| Command | Description | VM | Container |
|---------|-------------|:--:|:---------:|
| `start` | Start resource | yes | yes |
| `stop` | Hard stop | yes | yes |
| `shutdown` | Graceful shutdown | yes | yes |
| `restart` | Reboot | yes | yes |
| `reset` | Hard reset | yes | - |
| `suspend` | Hibernate | yes | - |
| `resume` | Resume from hibernation | yes | - |

### Resource Management Commands

| Command | Description | Example |
|---------|-------------|---------|
| `create` | Create VM, container, snapshot, or backup | `pvectl create vm --cores 4 --memory 8192` |
| `delete` | Delete resources | `pvectl delete vm 100 --yes` |
| `edit` | Edit config in $EDITOR | `pvectl edit vm 100` |
| `clone` | Clone VM or container | `pvectl clone vm 100 --name clone-01` |
| `migrate` | Migrate between nodes | `pvectl migrate vm 100 --target pve2` |

### Snapshot & Backup Commands

| Command | Description | Example |
|---------|-------------|---------|
| `create snapshot` | Create snapshot | `pvectl create snapshot 100 --name before-update` |
| `delete snapshot` | Delete snapshot | `pvectl delete snapshot 100 before-update --yes` |
| `rollback` | Rollback to snapshot | `pvectl rollback snapshot 100 before-update --yes` |
| `create backup` | Create backup (vzdump) | `pvectl create backup 100 --storage nfs-backup` |
| `delete backup` | Delete backup | `pvectl delete backup local:backup/... --yes` |
| `restore` | Restore from backup | `pvectl restore backup local:backup/... --vmid 200 --yes` |

### Configuration Commands

```bash
pvectl config get-contexts          # List all contexts
pvectl config use-context prod      # Switch context
pvectl config set-context staging --cluster=pve-staging --user=admin
pvectl config set-cluster prod --server=https://pve.example.com:8006
pvectl config set-credentials admin --token-id=root@pam!pvectl --token-secret=xxx
pvectl config view                  # Show config (secrets masked)
```

## Resource Types

| Type | Aliases | get | describe | top | logs | lifecycle | create | delete | clone | migrate | edit | console |
|------|---------|:---:|:--------:|:---:|:----:|:---------:|:------:|:------:|:-----:|:-------:|:----:|:-------:|
| nodes | node | yes | yes | yes | yes | - | - | - | - | - | - | - |
| vms | vm | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| containers | container, ct, cts | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| storage | stor | yes | yes | - | - | - | - | - | - | - | - | - |
| snapshots | snapshot, snap | yes | - | - | - | - | yes | yes | - | - | - | - |
| backups | backup | yes | - | - | - | - | yes | yes | - | - | - | - |

## Usage Examples

### Listing Resources

```bash
pvectl get nodes                      # List cluster nodes
pvectl get vms                        # List all VMs
pvectl get containers --node pve1     # Containers on specific node
pvectl get storage                    # List storage pools
pvectl get snapshots 100              # Snapshots for VM 100
pvectl get backups --storage nfs      # Backups on specific storage
```

### Output Formats

```bash
pvectl get vms                        # Table (default)
pvectl get vms -o wide                # Extended columns
pvectl get vms -o json                # JSON for scripting
pvectl get vms -o yaml                # YAML
```

### Watch Mode

```bash
pvectl get nodes --watch              # Auto-refresh every 2s
pvectl get vms -w --watch-interval 5  # Custom interval
```

### Resource Metrics

```bash
pvectl top nodes                      # Node CPU/memory/disk usage
pvectl top vms --sort-by cpu          # VMs sorted by CPU usage
pvectl top containers --all           # Include stopped containers
```

### Logs

```bash
pvectl logs node pve1                 # Node syslog
pvectl logs node pve1 --journal       # Systemd journal
pvectl logs vm 100                    # Task history for VM
pvectl logs vm 100 --all-nodes        # Search across all nodes
pvectl logs vm 100 --type vzdump      # Task history filtered by type
pvectl logs vm 100 --since 2026-01-01 # Filter by date
pvectl logs node pve1 --limit 100     # Limit number of entries
pvectl logs task UPID:pve1:000ABC:... # Log output for specific task
```

### Detailed Information

```bash
pvectl describe node pve1             # Full node diagnostics
pvectl describe vm 100                # VM config, disks, network, snapshots
pvectl describe container 200         # Container details
pvectl describe storage local-lvm     # Storage pool info
```

### Console Access

```bash
pvectl console vm 100                 # Open terminal to VM
pvectl console ct 200                 # Open terminal to container
pvectl console vm 100 --node pve1     # Specify node explicitly
pvectl console vm 100 --user root@pam # Provide username (prompted for password)
```

> **Note:** Console requires session authentication (username/password). If your config
> only has an API token, pvectl will prompt for credentials interactively.
> Disconnect with `Ctrl+]`.

### Lifecycle Operations

```bash
# Single resource
pvectl start vm 100
pvectl shutdown container 200

# Multiple resources
pvectl stop vm 100 101 102

# Batch operations with selectors
pvectl stop vm --all -l status=running
pvectl start vm --all -l tags=prod --node pve1

# Async/sync control
pvectl shutdown vm 100 --wait --timeout 120
pvectl start vm 100 --async
```

### Selectors

Filter resources using kubectl-style selectors:

```bash
-l status=running                     # Exact match
-l status!=stopped                    # Not equal
-l name=~web-*                        # Wildcard match (* = any characters)
-l "status in (running,paused)"       # In list
-l status=running -l tags=prod        # Multiple (AND logic)
```

Supported fields: `status`, `name`, `tags`, `pool`

### Creating Resources

```bash
# VM with flags
pvectl create vm 100 --cores 4 --memory 8192 --disk storage=local-lvm,size=50G

# Container with flags
pvectl create container 200 --hostname nginx --ostemplate local:vztmpl/debian-12.tar.zst

# Interactive wizard
pvectl create vm --interactive
pvectl create container --interactive

# Dry run
pvectl create vm 100 --cores 2 --memory 4096 --dry-run
```

### Cloning and Migration

```bash
# Clone VM
pvectl clone vm 100 --name web-clone --target pve2

# Linked clone (requires template)
pvectl clone vm 100 --linked --name thin-clone

# Live migration
pvectl migrate vm 100 --target pve2 --online

# Batch migration
pvectl migrate vm --all --node pve1 --target pve2 --yes
```

### Editing Configuration

```bash
pvectl edit vm 100                    # Opens config as YAML in $EDITOR
pvectl edit container 200 --editor nano
pvectl edit vm 100 --dry-run          # Show diff without applying
```

## Configuration

### Configuration File

Located at `~/.pvectl/config` (YAML, kubeconfig-style):

```yaml
apiVersion: pvectl/v1
kind: Config

clusters:
  - name: production
    cluster:
      server: https://pve1.example.com:8006
      insecure-skip-tls-verify: false

users:
  - name: admin-prod
    user:
      token-id: root@pam!pvectl
      token-secret: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

contexts:
  - name: prod
    context:
      cluster: production
      user: admin-prod
      default-node: pve1

current-context: prod
```

### Authentication

**API Token (recommended):**
```yaml
user:
  token-id: root@pam!pvectl
  token-secret: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Username/Password:**
```yaml
user:
  username: root@pam
  password: your-password
```

### Environment Variables

Override config file settings (useful for CI/CD):

| Variable | Description |
|----------|-------------|
| `PROXMOX_HOST` | Server URL |
| `PROXMOX_TOKEN_ID` | API token ID |
| `PROXMOX_TOKEN_SECRET` | API token secret |
| `PROXMOX_USER` | Username (alternative to token) |
| `PROXMOX_PASSWORD` | Password (alternative to token) |
| `PROXMOX_VERIFY_SSL` | SSL verification (true/false) |
| `PROXMOX_TIMEOUT` | Timeout in seconds |
| `PVECTL_CONTEXT` | Override active context |
| `PVECTL_CONFIG` | Alternative config path |

**Priority:** CLI flags > Environment variables > Config file > Defaults

### Security

- Config file created with `0600` permissions (owner read/write only)
- Config directory uses `0700` permissions
- Secrets masked in `config view` output
- Use API tokens instead of passwords when possible

## Global Flags

```
-o, --output FORMAT    Output format: table (default), json, yaml, wide
-v, --verbose          Enable verbose output for debugging
-c, --config FILE      Path to configuration file
    --color            Force colored output (even when not TTY)
    --no-color         Disable colored output
```

Global flags can be placed anywhere in the command line:

```bash
pvectl get vms -o json                # After command
pvectl -o json get vms                # Before command
pvectl get -o json vms                # Between arguments
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Usage/argument error |
| 3 | Configuration error |
| 4 | API connection error |
| 5 | Resource not found |
| 6 | Permission denied |
| 130 | Interrupted (Ctrl+C) |

## Plugins

pvectl supports plugins that add new commands or extend existing resource types.

### Gem-Based Plugins

Install any gem following the `pvectl-plugin-*` naming convention:

```bash
gem install pvectl-plugin-ceph
```

Gem plugins are discovered automatically — no configuration needed. The gem must provide a `pvectl_plugin/register.rb` file that calls `Pvectl::PluginLoader.register_plugin(YourCommand)`.

### Directory-Based Plugins

Place `.rb` files in `~/.pvectl/plugins/`:

```ruby
# ~/.pvectl/plugins/my_command.rb
class MyCommand
  def self.register(cli)
    cli.desc "My custom command"
    cli.command :my_command do |c|
      c.action do |_global, _options, _args|
        puts "Hello from plugin!"
      end
    end
  end
end

Pvectl::PluginLoader.register_plugin(MyCommand)
```

### Plugin Capabilities

Plugins can:
- Add new top-level commands (e.g., `pvectl my-command`)
- Register new resource types with existing commands (`get`, `top`, `logs`, `describe`) via `ResourceRegistry`

### Loading Order

1. Built-in commands
2. Gem-based plugins (`pvectl-plugin-*`)
3. Directory-based plugins (`~/.pvectl/plugins/*.rb`)

Broken plugins are skipped with a warning — they never crash pvectl. Use `GLI_DEBUG=true` for full stack traces.

## Development

```bash
git clone https://github.com/pwojcieszonek/pvectl.git
cd pvectl
bin/setup                             # Install dependencies
rake test                             # Run tests
bin/console                           # Interactive console
bundle exec exe/pvectl                # Run CLI locally
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/pwojcieszonek/pvectl](https://github.com/pwojcieszonek/pvectl).

## License

Released under the [MIT License](https://opensource.org/licenses/MIT).
