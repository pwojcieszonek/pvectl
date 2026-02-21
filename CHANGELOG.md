# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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

### Fixed
- **wizards**: Remove duplicate confirmation prompt in `create vm` and `create ct` interactive wizards — wizard no longer asks "Create this VM/container?" before showing the summary; only the summary-based confirmation remains
- **presenters**: Clone operation output now displays the new (cloned) resource data (VMID/CTID, name, node) instead of the source resource data
- **config**: `SimplePrompt` fallback now supports `required:`, `convert:`, and extra keyword arguments matching `TTY::Prompt#ask` interface (fixes `unknown keyword: :required` in interactive `create` wizard)

### Changed
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
