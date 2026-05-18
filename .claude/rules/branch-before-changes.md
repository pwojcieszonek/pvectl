# Branch Before Changes Rule

## MUST work on a feature branch before modifying any repository files

Every time you need to modify files in the repository, you MUST follow this sequence:

```
1. Be on a feature branch  →  2. Make changes  →  3. Commit  →  STOP
```

**Workflow ends at commit.** The agent must NOT push and must NOT create a pull request on its own initiative. Push and PR creation require an explicit user request — see `git-workflow.md` for details.

### Workflow

```bash
# 1. Determine the working branch
#    - If already on a non-main feature branch: continue using it (preferred)
#    - If on main: create a new feature branch
git status                              # check current branch
git checkout -b <type>/<short-description> main   # only if on main

# 2. Make changes, commit (see git-workflow.md for commit conventions)
git add <files>
git commit -m "<type>(<scope>): <description>"

# 3. STOP. Do NOT push or create PRs on your own — these need explicit user request.
#    git merge is allowed for local integration when appropriate.
```

### Rules

- **NEVER commit changes directly to `main`** — always work on a feature branch.
- **NEVER push to remote on agent initiative** — `git push` only when the user explicitly asks for it.
- **NEVER create pull requests on agent initiative** — `gh pr create` only when the user explicitly asks for it.
- `git merge` is allowed for local merges between branches.
- If currently on a non-`main` branch, **continue working there** — do not create a new branch unless the new request is clearly a different scope.
- Create a new branch **before** making any file modifications, not after.
- One logical *initiative* per branch — multiple commits per branch is expected and desired.
- If the user asks to make a change without specifying a branch and we're on `main`, create one automatically following `git-workflow.md` naming conventions.
- After committing, stay on the feature branch.

### When this applies

- Any code changes (`lib/`, `test/`, `sig/`)
- Configuration changes (`.claude/rules/`, `CLAUDE.md`, `.mcp.json`)
- Documentation changes (`CHANGELOG.md`, `README.md`)
- Any other tracked file in the repository

### When this does NOT apply

- Read-only operations (exploring code, running tests, searching)
- Changes to files outside the repository (memory files, local config)
