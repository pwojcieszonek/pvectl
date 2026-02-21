# Git Workflow Rules

## Branch Strategy

This project uses simple feature branches — NO git worktrees.

### Branch Naming

Use descriptive branch names with prefixes matching Conventional Commits:

| Prefix | Use Case | Example |
|--------|----------|---------|
| `feat/` | New features | `feat/describe-command` |
| `fix/` | Bug fixes | `fix/get-params-encoding` |
| `refactor/` | Code restructuring | `refactor/repository-pattern` |
| `test/` | Test improvements | `test/mock-coverage` |
| `docs/` | Documentation | `docs/rdoc-annotations` |
| `chore/` | Tooling, deps, config | `chore/update-dependencies` |

### Branch Lifecycle

1. **Create** branch from `main` before starting work:
   ```bash
   git checkout -b feat/my-feature main
   ```

2. **Commit** frequently with small, atomic commits (see Commit Rules below)

3. **Finish** by pushing and creating a Pull Request:
   ```bash
   git push -u origin feat/my-feature
   gh pr create --title "..." --body "..."
   ```

### Rules

- **NEVER merge locally to `main`** — always push the branch and create a PR via `gh pr create`
- Never commit directly to `main` for feature work
- Always create a feature branch before implementation starts
- One logical change per branch
- Keep branches short-lived
- The `finishing-a-development-branch` skill options that involve local merge or discard do NOT apply — always use the Push + PR path

## Commit Rules

### Format: Conventional Commits

```
<type>(<scope>): <description>
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

**Scope:** module or area affected (e.g., `cli`, `repositories`, `logs`, `config`)

### Examples

```
feat(cli): register logs command with filtering flags
fix(repositories): pass GET query params via rest-client params key
test(logs): add handler unit tests with mock repositories
refactor(presenters): extract shared column definitions
docs(logs): add RDoc documentation for public API
```

### Commit Discipline

- Commit after each logical unit of work (TDD cycle: test → implement → refactor)
- Never bundle unrelated changes in one commit
- Write imperative mood descriptions: "add", "fix", "remove" — not "added", "fixes"
- No `Co-Authored-By` trailers
- When the user asks to commit — execute immediately, no questions asked

### TDD Commit Rhythm

Following the red-green-refactor cycle, the natural commit points are:

1. `test(scope): add failing test for <behavior>` — after writing the test (red)
2. `feat(scope): implement <behavior>` — after making it pass (green)
3. `refactor(scope): <what changed>` — after cleanup (refactor)

Not every cycle needs 3 commits — use judgment. Small features can be one commit.
