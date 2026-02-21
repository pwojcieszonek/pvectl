# Branch Before Changes Rule

## MUST create a feature branch before modifying any repository files

Every time you need to modify files in the repository, you MUST follow this sequence:

```
1. Create branch  →  2. Make changes  →  3. Commit  →  4. Push  →  5. Create PR
```

### Workflow

```bash
# 1. Ensure you are on main and up to date
git checkout main
git pull

# 2. Create feature branch (see git-workflow.md for naming conventions)
git checkout -b <type>/<short-description> main

# 3. Make changes, commit (see git-workflow.md for commit conventions)
git add <files>
git commit -m "<type>(<scope>): <description>"

# 4. Push and create PR
git push -u origin <type>/<short-description>
gh pr create --title "<title>" --body "<body>"
```

### Rules

- **NEVER commit changes directly to `main`** — always create a branch first
- Create the branch **before** making any file modifications, not after
- One logical change per branch — don't mix unrelated work
- If the user asks to make a change without specifying a branch, create one automatically following `git-workflow.md` naming conventions
- After PR is created, stay on the feature branch unless the user says otherwise

### When this applies

- Any code changes (`lib/`, `test/`, `sig/`)
- Configuration changes (`.claude/rules/`, `CLAUDE.md`, `.mcp.json`)
- Documentation changes (`CHANGELOG.md`, `README.md`)
- Any other tracked file in the repository

### When this does NOT apply

- Read-only operations (exploring code, running tests, searching)
- Changes to files outside the repository (memory files, local config)
