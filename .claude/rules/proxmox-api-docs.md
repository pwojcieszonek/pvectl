# Proxmox API Documentation Rules

## MUST consult official sources before implementing API calls

When implementing or modifying any Proxmox API interaction (repositories, endpoints, parameters), you MUST:

1. **Check the official Proxmox API documentation** at `https://pve.proxmox.com/pve-docs/api-viewer/` to verify:
   - Correct endpoint paths (e.g., `/nodes/{node}/qemu/{vmid}/status/current`)
   - Required and optional parameters
   - Expected response format
   - HTTP methods (GET, POST, PUT, DELETE)

2. **Check the proxmox-api gem documentation** at `https://github.com/L-Eugene/proxmox-api` to verify:
   - Correct Ruby client usage and method chaining
   - How to pass parameters (remember the `params:` key fix — see MEMORY.md)

## MUST NOT

- **Guess or invent endpoint paths** — always verify against the API viewer
- **Assume parameter names** — Proxmox naming is inconsistent (e.g., `vmid` vs `id`, `reboot` vs `restart`)
- **Assume HTTP methods** — some operations use unexpected methods
- **Copy patterns from other APIs** — Proxmox has its own conventions

## Known Proxmox API gotchas

- LXC restart uses endpoint `reboot`, not `restart`
- LXC does NOT support `reset`, `suspend`, `resume`
- Task status endpoint returns UPID format strings
- Some endpoints use `POST` for read-like operations (e.g., task log with pagination)
- Storage content listing requires `content` parameter to filter by type

## How to check

Use `WebFetch` tool with the API viewer URL or `context7` MCP server with library ID `/L-Eugene/proxmox-api` to look up correct endpoint signatures before writing repository code.
