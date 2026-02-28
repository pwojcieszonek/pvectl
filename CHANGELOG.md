# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **commands**: `pvectl set` command for non-interactive resource configuration (vm, container, volume, node) with key=value syntax
- **commands**: `pvectl edit volume` for interactive volume property editing via YAML editor
- **commands**: `pvectl edit node` for interactive node configuration editing via YAML editor
- **commands**: `pvectl get volume <vm|ct> <ID...>` and `pvectl get volume --storage <STORAGE>` list virtual disk volumes from VM/CT config or storage content API
- **commands**: `pvectl describe volume <vm|ct> <ID> <disk_name>` shows detailed information about a specific virtual disk
- **volumes**: Volume selector with `-l format=raw,storage=local-lvm` filtering for `get volume`
- **describe disk**: `pvectl describe disk /dev/xxx [--node NODE]` shows device info and structured SMART attributes (ATA table or parsed NVMe/SAS key-value pairs)
- **parsers**: SmartText parser for converting NVMe/SAS smartctl text output into structured data
- **repositories**: `Disk#smart` method for SMART data retrieval from Proxmox API (`GET /nodes/{node}/disks/smart`)

### Changed
- **describe vm**: reorganize output to match PVE web UI tabs (Summary, Hardware, Cloud-Init, Options, Task History, Snapshots, Pending Changes) with previously hidden config keys (ACPI, KVM, Tablet, Freeze CPU, Local Time, NUMA) now visible in Options section
- **describe container**: reorganize output to match PVE web UI tabs (Summary, Resources, Network, DNS, Options, Task History, Snapshots, High Availability) with all options visible
- **describe**: add Task History section showing recent operations for VM and container resources
- **get**: `storages` is now the primary resource name (consistent with `vms`, `nodes`, etc.); `storage` and `stor` remain as aliases

### Fixed
- **presenters**: rename misleading "Wearout" label to "Life Remaining" in describe disk output (Proxmox reports remaining life, not wear percentage)
- **presenters**: remove "Mounted" field from describe disk output (mount status applies to partitions, not whole disks)

### Documentation
- **cli**: Added `long_desc` man-page style help text to all commands (~25 commands) with DESCRIPTION, EXAMPLES, NOTES, and SEE ALSO sections
- **cli**: Enabled `wrap_help_text :verbatim` for proper formatting of code examples in help output
- **cli**: Enabled `sort_help :manually` to display commands in logical declaration order
- **readme**: Transformed README from 529-line reference into ~130-line landing page with links to GitHub Wiki
- **wiki**: Created comprehensive GitHub Wiki with 10 pages: Home, Getting Started, Command Reference, Configuration Guide, Selectors & Filtering, Output Formats, Workflows, Plugin Development, Troubleshooting, FAQ

### Removed
- **commands**: `pvectl resize volume` command (replaced by `pvectl set volume ... size=+10G`)

### Changed
- **commands**: `pvectl edit` now supports `volume` and `node` resource types in addition to `vm` and `container`
- **presenters**: reduce default table columns to 6 (NAME, ID, STATUS, NODE, CPU, MEMORY); UPTIME, TEMPLATE, TAGS moved to wide output
- **presenters**: NAME column now appears first (before VMID/CTID), matching kubectl convention
- **presenters**: extract shared display helpers (format_bytes, uptime_human, tags_display, template_display) to Presenters::Base
- **cli**: boolean config flags (`--start`, `--numa`, `--agent`, `--privileged`, `--onboot`) now support negation (`--no-start`, `--no-agent`, etc.) in `create` and `clone` commands
- **cli**: Unified snapshot CLI syntax — snapshot name is now a positional argument, VMIDs use `--vmid` flag (repeatable), `--node` filters by node, `--all` deletes all snapshots (**breaking change**)
- **cli**: `create snapshot` and `delete snapshot` are now GLI sub-commands with dedicated flags
- **cli**: `get snapshots` and `describe snapshot` accept `--vmid` and `--node` flags
- **services**: Snapshot service methods accept `node:` parameter for node filtering
- **services**: Added `delete_all` method for removing all snapshots from VMs

### Fixed
- **services**: `--agent` and `--onboot` now correctly send disable value to API when negated (previously only supported enabling)
- **services**: `create container` no longer forces `unprivileged: 1` when `--privileged` flag is not specified (respects API defaults)
- **cli**: `--status` flag now correctly filters VMs and containers by status in `get` command (previously ignored for VM/CT resources)

### Added
- **cli**: `get disks` command to list physical disks (block devices) on cluster nodes with `--node` filtering
- **cli**: `get disk` alias for `get disks`
- **cli**: selector support for disks (`-l type=ssd,health=PASSED,node=pve1,gpt=yes,mounted=yes`)
- **selectors**: support `template` field filtering for VMs and containers (`-l template=yes`, `-l template=no`)
- **cli**: `-l`/`--selector` flag for `get` command enables kubectl-style filtering for VMs and containers (e.g., `-l status=running,tags=prod`, `-l name=~web-*`)
- **cli**: `--status` flag acts as shortcut for `-l status=VALUE` for VM/CT resources, combinable with other selectors
- **cli**: `pvectl template vm/ct` command for converting VMs and containers to Proxmox templates (irreversible, with confirmation prompt or `--yes` flag, `--force` to stop running resources)
- **cli**: `pvectl get templates` handler for listing templates with optional `--type vm|ct` filter
- **models**: `type` attribute added to VM and Container models (distinguishes `qemu`/`lxc`)
- **cli**: `pvectl get tasks` command for cluster-wide task listing with `--node`, `--limit`, `--since`, `--until`, `--type`, `--status` filtering flags
- **rbs**: Full RBS type signatures for the entire codebase (175 files, ~4300 lines under `sig/`)
- **rbs**: External stubs for GLI and ProxmoxAPI gems (`sig/external/`)
- **rbs**: Pragmatic typing strategy — strict types for domain layer, `untyped` at gem boundaries
- **console**: Interactive terminal session for VMs and containers via `pvectl console vm|ct <ID>`
- **console**: WebSocket-based xtermjs protocol with native Ruby implementation (websocket-driver gem)
- **console**: Session authentication with interactive credential prompt when API token is insufficient
- **plugins**: Plugin system with gem-based (`pvectl-plugin-*`) and directory-based (`~/.pvectl/plugins/*.rb`) discovery
- **plugins**: `PluginLoader` class for automatic plugin loading with graceful error handling
- **commands**: `SharedFlags` module for reusable flag definitions across commands
- **commands**: `SharedConfigParsers` mixin module for shared CLI flag parsing (disks, nets, cloud-init, mountpoints) across create and clone commands
- **cli**: Configuration flags for `pvectl clone vm/ct` — modify CPU, memory, disks, network, and other settings during clone (two-step: clone then config update via PUT API)
- **models**: `:partial` status on `OperationResult` for operations that partially succeed (e.g. clone OK but config update failed)
- **resize**: `pvectl resize disk vm/ct <id> <disk> <size>` command for resizing VM and container disks with confirmation prompt and `--yes` flag
- **describe**: `pvectl describe snapshot <name> [vmid...]` command showing detailed snapshot metadata with visual snapshot tree

### Fixed
- **wizards**: Remove duplicate confirmation prompt in `create vm` and `create ct` interactive wizards — wizard no longer asks "Create this VM/container?" before showing the summary; only the summary-based confirmation remains
- **presenters**: Clone operation output now displays the new (cloned) resource data (VMID/CTID, name, node) instead of the source resource data
- **config**: `SimplePrompt` fallback now supports `required:`, `convert:`, and extra keyword arguments matching `TTY::Prompt#ask` interface (fixes `unknown keyword: :required` in interactive `create` wizard)

### Changed
- **cli**: `pvectl get snapshots`, `pvectl create snapshot`, and `pvectl delete snapshot` without VMIDs now operate cluster-wide (previously required at least one VMID)
- **commands**: Extracted `IrreversibleCommand` mixin from `DeleteCommand` for reuse in template and other destructive commands
- **services**: Extract `Services::TaskListing` from `Logs::Handlers::TaskLogs` for shared multi-node task listing logic
- **cli**: Refactored all command definitions from inline `cli.rb` to self-registration via `.register(cli)` class methods
- **cli**: `cli.rb` reduced from ~930 lines to ~96 lines (globals, error handling, PluginLoader)
- **cli**: `template` command now uses `--yes` to skip confirmation (was `--force`) for consistency with `delete` and other destructive commands
- **cli**: `template --force` now stops running VMs/containers before conversion (matching `delete --force` behavior)
- **cli**: `ArgvPreprocessor` refactored to use dynamic GLI reflection instead of static flag maps — automatically discovers all registered flags and switches
- **commands**: `CreateVm` and `CreateContainer` refactored to use `SharedFlags` config groups and `SharedConfigParsers` mixin, eliminating inline flag definitions and parser method duplication

### Fixed
- **cli**: Command flags placed after positional arguments are now correctly reordered (e.g., `pvectl delete vm 103 --yes` now works as expected)
