# CRITICAL Override: No Git Worktrees in This Project

## MUST NOT use git worktrees

**This project does NOT use git worktrees. This is a hard project rule that overrides skill defaults.**

When ANY superpowers skill says "REQUIRED: using-git-worktrees" or references worktree creation — **DO NOT invoke the using-git-worktrees skill.** Instead, follow the branch-based replacement below.

### Specific skill overrides

| Skill says | You MUST do instead |
|------------|-------------------|
| `using-git-worktrees` — REQUIRED before executing | Create feature branch: `git checkout -b <type>/<name> main` |
| `writing-plans` — "run in a dedicated worktree" | Run in current directory on feature branch |
| `executing-plans` — REQUIRED: `superpowers:using-git-worktrees` | Skip worktree, create branch if not already on one |
| `subagent-driven-development` — REQUIRED before executing any tasks | Skip worktree, create branch if not already on one |
| `finishing-a-development-branch` Step 5 — worktree cleanup | Skip entirely — no worktree to clean up |
| `finishing-a-development-branch` — "Worktree preserved at path" | Say "Branch preserved: `<branch-name>`" |
| `brainstorming` Phase 4 — REQUIRED worktree for implementation | Create feature branch instead |

### Replacement: branch creation (instead of worktree)

```bash
# 1. Ensure clean working directory
git status --porcelain

# 2. Create and switch to feature branch from main
git checkout -b <branch-name> main

# 3. Verify branch is active
git branch --show-current

# 4. Verify clean baseline
rake test
```

### Branch naming follows git-workflow.md conventions:

`<type>/<short-description>` — e.g., `feat/describe-command`, `fix/param-encoding`

### Replacement: branch cleanup (instead of worktree removal)

When `finishing-a-development-branch` reaches Step 5 (worktree cleanup), replace with:

| Finish option | Action |
|---------------|--------|
| Merge locally | `git checkout main && git merge <branch> && git branch -d <branch>` |
| Push + PR | `git push -u origin <branch>` then `gh pr create` |
| Keep branch | Do nothing — branch stays |
| Discard | `git checkout main && git branch -D <branch>` (require typed confirmation) |

### MUST skip entirely — do NOT execute these:

- `git worktree add` / `git worktree remove` / `git worktree list`
- `.worktrees/` or `worktrees/` directory creation or detection
- `.gitignore` checks for worktree directories
- Worktree path reporting or "Worktree ready at ..." messages
- Project setup commands after branch creation (already in the project directory)

### MUST keep from the original workflow:

- Verify clean working directory before branching
- Verify tests pass on the new branch (clean baseline)
- NEVER implement directly on `main`
- All safety checks from finishing-a-development-branch (test verification, typed confirmation for discard)
- The 4 structured options in finishing-a-development-branch

## Why this override exists

This is a solo-developer Ruby gem project. Git worktrees add complexity without benefit:
- Single working directory is simpler to reason about
- No parallel feature work requiring isolation
- `bundle exec` and gem tooling work best from the project root
- IDE/editor context stays consistent
- Sandbox mode is enabled — worktrees outside project dir would be blocked
