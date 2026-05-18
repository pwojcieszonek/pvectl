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

1. **Start** — determine the working branch:
   - If currently on a non-`main` branch, **continue using it** (append commits to the ongoing branch). This is the default to avoid branch proliferation.
   - If on `main`, create a new feature branch:
     ```bash
     git checkout -b feat/my-feature main
     ```
   - Only create a new branch from `main` if the new work is a clearly different scope from the current branch.

2. **Commit** frequently with small, atomic commits (see Commit Rules below).

3. **Stop** — the agent's workflow ends at the commit. **DO NOT push and DO NOT create a PR on your own initiative.** Pushing and PR creation require an explicit user request.

### Rules

- **NEVER push to remote on agent initiative** — `git push`, `git push -u`, force-push, any variant. Push is permitted ONLY when the user explicitly asks for it (e.g. "push it", "wypchnij branch"). The agent must NOT decide on its own that the work is "ready to push" or push as part of a workflow.
- **NEVER create pull requests on agent initiative** — `gh pr create` and any equivalent (web UI automation, API calls, scripts) is permitted ONLY when the user explicitly asks (e.g. "open a PR", "stwórz PR"). The agent must never open a PR autonomously, even when commits land cleanly and the branch "feels finished".
- `git merge` is allowed for local merges. Use it to integrate feature branches when needed.
- Never commit directly to `main` for feature work — always go through a feature branch first.
- Always work on a feature branch — create one only if not already on a non-`main` branch.
- **Append commits to the existing feature branch** when continuing related work. Don't spin up a new branch per request.
- One logical *initiative* per branch (not one commit per branch). Multiple commits per branch is normal and preferred.
- Keep branches short-lived — they exist until the user decides to merge or open a PR.
- The `superpowers:finishing-a-development-branch` skill does NOT apply in this project — agent workflow ends at commit. Push, PR, and remote integration require explicit user action.

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
- **NEVER add `Co-Authored-By` trailers** — this is a hard rule, no exceptions. Do not add any Co-Authored-By, Signed-off-by, or similar trailers to commit messages. This applies to ALL commits: manual, from subagents, from scripts. When dispatching subagents that commit, explicitly instruct them: "Do NOT add Co-Authored-By or any trailers to commit messages."
- When the user asks to commit — execute immediately, no questions asked

### TDD Commit Rhythm

Following the red-green-refactor cycle, the natural commit points are:

1. `test(scope): add failing test for <behavior>` — after writing the test (red)
2. `feat(scope): implement <behavior>` — after making it pass (green)
3. `refactor(scope): <what changed>` — after cleanup (refactor)

Not every cycle needs 3 commits — use judgment. Small features can be one commit.
