# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **rbs**: Full RBS type signatures for the entire codebase (175 files, ~4300 lines under `sig/`)
- **rbs**: External stubs for GLI and ProxmoxAPI gems (`sig/external/`)
- **rbs**: Pragmatic typing strategy — strict types for domain layer, `untyped` at gem boundaries
- **console**: Interactive terminal session for VMs and containers via `pvectl console vm|ct <ID>`
- **console**: WebSocket-based xtermjs protocol with native Ruby implementation (websocket-driver gem)
- **console**: Session authentication with interactive credential prompt when API token is insufficient
- **plugins**: Plugin system with gem-based (`pvectl-plugin-*`) and directory-based (`~/.pvectl/plugins/*.rb`) discovery
- **plugins**: `PluginLoader` class for automatic plugin loading with graceful error handling
- **commands**: `SharedFlags` module for reusable flag definitions across commands

### Changed
- **cli**: Refactored all command definitions from inline `cli.rb` to self-registration via `.register(cli)` class methods
- **cli**: `cli.rb` reduced from ~930 lines to ~96 lines (globals, error handling, PluginLoader)
