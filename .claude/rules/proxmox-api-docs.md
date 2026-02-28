# Proxmox API Documentation Rules

## MUST consult official sources before implementing API calls

When implementing or modifying any Proxmox API interaction (repositories, endpoints, parameters), you MUST:

1. **Check the local Proxmox API reference** in `docs/proxmox-api/` (JSON files parsed from official `apidata.js`):
   - Files are organized by API section: `nodes-qemu-status.json`, `nodes-lxc-config.json`, `storage.json`, etc.
   - Each file contains a flat array of endpoint objects with: `path`, `info` (per HTTP method with `parameters`, `returns`, `description`), `permissions`
   - Use `Read` tool to inspect the relevant file for your endpoint
   - Use `Grep` to search across all files: `grep -r "endpoint-keyword" docs/proxmox-api/`

2. **Check the proxmox-api gem documentation** via `context7` MCP server with library ID `/L-Eugene/proxmox-api` to verify:
   - Correct Ruby client usage and method chaining
   - How to pass parameters (remember the `params:` key fix — see MEMORY.md)

## File naming convention

| File | Covers |
|------|--------|
| `nodes-qemu-status.json` | `/nodes/{node}/qemu/{vmid}/status/*` (start, stop, current, etc.) |
| `nodes-qemu-config.json` | `/nodes/{node}/qemu/{vmid}/config` (VM configuration — large file, use offset/limit) |
| `nodes-qemu-snapshot.json` | `/nodes/{node}/qemu/{vmid}/snapshot/*` |
| `nodes-qemu-firewall.json` | `/nodes/{node}/qemu/{vmid}/firewall/*` |
| `nodes-qemu-agent.json` | `/nodes/{node}/qemu/{vmid}/agent/*` |
| `nodes-qemu-migrate.json` | `/nodes/{node}/qemu/{vmid}/migrate` |
| `nodes-lxc-status.json` | `/nodes/{node}/lxc/{vmid}/status/*` |
| `nodes-lxc-config.json` | `/nodes/{node}/lxc/{vmid}/config` |
| `nodes-lxc-snapshot.json` | `/nodes/{node}/lxc/{vmid}/snapshot/*` |
| `nodes-storage.json` | `/nodes/{node}/storage/*` (node-level storage) |
| `nodes-tasks.json` | `/nodes/{node}/tasks/*` |
| `nodes-disks.json` | `/nodes/{node}/disks/*` |
| `storage.json` | `/storage/*` (cluster-level storage config) |
| `access.json` | `/access/*` (auth, users, roles, tokens) |
| `cluster-*.json` | `/cluster/*` (HA, backup, firewall, SDN, etc.) |

## Updating the API reference

If `docs/proxmox-api/` is empty or outdated, regenerate with the update script:

```bash
bash docs/proxmox-api-update.sh
```

## MUST NOT

- **Guess or invent endpoint paths** — always verify against the local API reference
- **Assume parameter names** — Proxmox naming is inconsistent (e.g., `vmid` vs `id`, `reboot` vs `restart`)
- **Assume HTTP methods** — some operations use unexpected methods
- **Copy patterns from other APIs** — Proxmox has its own conventions

## Known Proxmox API gotchas

- LXC restart uses endpoint `reboot`, not `restart`
- LXC does NOT support `reset`, `suspend`, `resume`
- Task status endpoint returns UPID format strings
- Some endpoints use `POST` for read-like operations (e.g., task log with pagination)
- Storage content listing requires `content` parameter to filter by type
