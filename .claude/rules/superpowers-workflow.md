# Superpowers Plugin Workflow

## Skill Invocation Order

The superpowers plugin provides a structured development workflow. Follow this sequence:

```
User request
    ↓
1. brainstorming          — explore intent, propose approaches, get design approval
    ↓
2. writing-plans          — break design into bite-sized tasks with TDD steps
    ↓
3. [execution method]     — subagent-driven-development OR executing-plans
    ↓
4. finishing-a-branch     — verify tests, present merge options, clean up
```

## Skill-Specific Rules

### brainstorming

- MUST be invoked before any creative/feature work
- Explore project context first (files, recent commits, architecture)
- Ask clarifying questions one at a time
- Propose 2-3 approaches with trade-offs and a recommendation
- Write design doc to `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Do NOT write any code until design is approved

### writing-plans

- Each task step = 2-5 minutes of work
- Include exact file paths, complete code, exact commands
- Follow TDD: write test → verify fail → implement → verify pass → commit
- Save plan to `docs/plans/YYYY-MM-DD-<topic>-plan.md`

### subagent-driven-development (preferred for this project)

- Dispatch fresh subagent per task
- Two-stage review: spec compliance FIRST, then code quality
- Never dispatch multiple implementers in parallel
- Provide full task text to subagents (don't reference plan file)

### executing-plans

- Load plan, review critically before starting
- Execute in batches (default: 3 tasks), report between batches
- Stop on blockers — ask for clarification rather than guessing

### verification-before-completion

- ALWAYS run verification commands before claiming anything is done
- No "should work", "probably passes" — only evidence from fresh runs
- Required before: commits, PRs, task completion, moving to next task

### finishing-a-development-branch

- Verify all tests pass first
- Present exactly 4 structured options (merge, PR, keep, discard)
- See git-workflow.md for branch cleanup details
- **IMPORTANT:** Skip worktree cleanup steps (this project does not use worktrees)
- After branch is closed (merged or discarded), propose deleting associated plan files from `docs/plans/` that were created during the branch's lifecycle

## Plan Files (`docs/plans/`)

- `docs/plans/` is in `.gitignore` — plan files are local-only working documents
- Do NOT attempt `git add` on any file under `docs/plans/`
- Do NOT treat `git add` failure for plan files as an error — it is expected behavior
- Design docs and implementation plans stay local; they are not part of the repository

## Anti-Patterns

- Skipping brainstorming because "it's simple" — every feature goes through design
- Writing code before design approval
- Claiming completion without running verification
- Trusting subagent success reports without independent verification
- Skipping spec review and going straight to code quality review
- Attempting to `git add` files from `docs/plans/` — they are gitignored
