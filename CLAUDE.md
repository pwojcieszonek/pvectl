# CLAUDE.md

Guidelines for Claude Code when working with this repository.

## Project Overview

**pvectl** is a Ruby CLI gem for managing Proxmox clusters with kubectl-like syntax. It wraps the Proxmox API, exposing familiar commands for VM/container management, node operations, storage, backups, and snapshots.

## Developer Commands

```bash
bin/setup              # Install dependencies
rake test              # Run tests (prefer /test-run)
bin/console            # Interactive console
bundle exec exe/pvectl # Run CLI locally
bundle exec rake release # Release new version
```

**Ruby:** 3.3.0 (`.ruby-version`)

## Architecture

### Layer Diagram

Two data paths depending on operation type:

```
                    ┌──────────────────────────────────┐
                    │           CLI Layer               │
                    │  GLI::App (cli.rb) → Commands     │
                    └────────┬─────────────┬───────────┘
                             │             │
                  read-only  │             │  mutating
              (get,top,logs, │             │  (lifecycle,delete,
               describe)     │             │   clone,create,edit,
                             ▼             ▼   migrate)
                    ┌──────────┐  ┌─────────────────┐
                    │ Handlers │  │    Services      │
                    │ +Registry│  │  (orchestration) │
                    └────┬─────┘  └───────┬─────────┘
                         │                │
                         └───────┬────────┘
                                 ▼
                    ┌──────────────────────┐
                    │    Repositories      │
                    │  → Models → Parsers  │
                    │  → Connection        │
                    └──────────┬───────────┘
                               ▼
                         Proxmox API

        Presentation (both paths):
        Models → Presenters → Formatters → Output
```

### Module Layers (`lib/pvectl/`)

| Directory | Role |
|-----------|------|
| `commands/` | CLI command definitions, routing, Template Method hierarchies |
| `commands/*/handlers/` | Per-resource handlers for read-only commands (dispatched via Registry) |
| `services/` | Orchestration of complex operations (lifecycle, CRUD, migration, resource fetching) |
| `repositories/` | Proxmox API encapsulation, conversion to domain models |
| `models/` | Domain models (value objects) |
| `presenters/` | Column definitions and formatting per resource type |
| `formatters/` | Output strategies (table, json, yaml, wide) |
| `parsers/` | Proxmox config parsers (net, disk, cloud-init, LXC mount) |
| `selectors/` | Resource filtering by attributes (`-l status=running,tags=prod`) |
| `wizards/` | Interactive resource creators (step-by-step prompts) |
| `utils/` | Helper utilities (resource resolver) |
| `config/` | Loading, validation, saving multi-context configuration |
| `connection/` | API client with retry (exp. backoff) and timeout |

### Design Patterns

| Pattern | Usage |
|---------|-------|
| **Repository** | API encapsulation, conversion to domain models |
| **Presenter** | Column definitions and formatting per resource type |
| **Strategy** | Formatters (Table, JSON, YAML, Wide) |
| **Registry** | Base registry mapping resource name → handler; each read-only command inherits its own copy |
| **Handler** | Per-resource handlers in read-only commands, dispatched via Registry |
| **Template Method** | Base module defines flow, specializations (VM/Container) implement hooks — used in lifecycle, delete, create, edit, migrate |
| **Dependency Injection** | Repositories and services injected via constructor (testable with mocks) |

### Hybrid Module Include Pattern

Pattern used in Template Method specializations (VM/Container) for correct MRO with ClassMethods propagation:

```ruby
module VmSpecialization
  include BaseTemplate  # MRO: Specialization BEFORE Base in ancestors

  def self.included(base)
    base.extend(BaseTemplate::ClassMethods)  # propagate class methods
  end
end
```

**Note:** `self.included(base) { base.include(Base...) }` is **incorrect** — it places Base BEFORE Specialization in MRO, so template methods (NotImplementedError) mask implementations.

### Typed OperationResult Pattern

Mutating operations return a typed `OperationResult` with a subclass per resource type. Each type has a dedicated Presenter with resource-specific columns (e.g., VMID vs CTID). New resource type = new subclass + presenter.

## Configuration

### Config File Format (`~/.pvectl/config`)

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

### Environment Variables (higher priority than config file)

| Variable | Description |
|----------|-------------|
| `PROXMOX_HOST` | Server URL |
| `PROXMOX_TOKEN_ID` | API token ID |
| `PROXMOX_TOKEN_SECRET` | Token secret |
| `PROXMOX_USER` / `PROXMOX_PASSWORD` | Alternative to token |
| `PROXMOX_VERIFY_SSL` | SSL verification |
| `PROXMOX_TIMEOUT` | Timeout (seconds) |
| `PVECTL_CONTEXT` | Context override |
| `PVECTL_CONFIG` | Alternative config path |

### Loading Hierarchy

```
Built-in defaults → Config file → ENV variables → CLI flags
```

## Conventions

### CLI (kubectl style)

Commands grouped by type:

| Group | Commands | Pattern |
|-------|----------|---------|
| **Read-only** | `get`, `describe`, `top`, `logs` | Handler + Registry |
| **Lifecycle** | `start`, `stop`, `shutdown`, `restart`, `reset`, `suspend`, `resume` | Template Method (VM/Container) |
| **CRUD (VM/CT)** | `create`, `delete`, `edit`, `migrate` | Template Method (VM/Container) |
| **Snapshot/Backup** | `create`/`delete` snapshot/backup, `rollback`, `restore` | Dedicated commands |
| **Standalone** | `clone`, `ping` | Dedicated commands per resource type |
| **Config** | `config <subcommand>` | GLI subcommands |

Syntax: `pvectl <command> <resource_type> [id...] [--flags]`

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | CLI usage error |
| 3 | Configuration error |
| 4 | API connection error |
| 5 | Resource not found |
| 6 | Permission denied |
| 130 | Interrupted (Ctrl+C) |

### Testing

Use `/test-run` instead of `rake test` directly — provides intelligent error analysis.

**Structure:** `test/unit/` mirrors `lib/pvectl/`, convention: `<class>_test.rb`

### Ruby Code Style

Follow the [Ruby Style Guide](https://rubystyle.guide). Write **idiomatic Ruby** — leverage the language's unique features (blocks, iterators, `attr_*`, `?`/`!`/`=` suffixes), don't translate patterns from other languages.

### Code Documentation (RDoc)

Required for classes, modules, and public methods:
- `@param`, `@return`, `@raise`, `@example`

## MCP Servers

| Server | Libraries (libraryId) |
|--------|------------------------|
| `context7` | `/davetron5000/gli`, `/piotrmurach/tty-table`, `/minitest/minitest`, `/L-Eugene/proxmox-api` |

**Configuration:** `.mcp.json`
