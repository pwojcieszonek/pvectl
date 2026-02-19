# Documentation Update Rules

## CLAUDE.md philosophy

CLAUDE.md defines **architectural assumptions and conventions** — how to build, not what exists. It should contain:
- Design patterns and when to use them
- Architectural flow diagrams (data paths, layer responsibilities)
- Module layer roles (directory → purpose mapping)
- Coding conventions and style rules
- Configuration format and loading hierarchy
- Known pitfalls and anti-patterns

It must NOT contain:
- Class/module inventories or lists of files
- Specific class names beyond pattern examples (e.g., "BaseTemplate" in Hybrid Include is fine, but listing all 12 repositories is not)
- Feature lists or command enumerations (that belongs in README)
- Anything that requires updating when adding a new class within an existing pattern

**Litmus test:** If adding a new handler/model/presenter/repository requires editing CLAUDE.md, the document has drifted into inventory territory.

## MUST update documentation after completing changes

After finishing any feature, bugfix, refactor, or other code change — before claiming work is done — you MUST update:

### 1. CHANGELOG.md

- Add entry under `## [Unreleased]` in the appropriate section:
  - **Added** — new features and capabilities
  - **Changed** — changes to existing functionality
  - **Fixed** — bug fixes
  - **Removed** — removed features
  - **Documentation** — documentation-only changes
- Format: `- **scope**: Description of what changed`
- Follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) conventions
- All entries in English (matching project convention: code, comments, commits in English)

### 2. README.md

- Update if the change affects user-facing behavior:
  - New commands or subcommands
  - New flags or options
  - Changed CLI syntax or output
  - New configuration options
  - New features described in the Features section
- Do NOT update README for internal refactors, test changes, or implementation details invisible to the user

### When to skip

- Pure test changes (`test:` commits) — skip README, add to CHANGELOG only if significant
- CI/CD or tooling changes (`chore:` commits) — skip both unless user-facing
- `.claude/` config changes — skip both

### 3. CLAUDE.md — propose only, do NOT auto-update

After completing work, evaluate whether the change affects project architecture or conventions documented in CLAUDE.md. If it does, **propose the update to the user** — do NOT modify CLAUDE.md automatically.

Propose when:
- A new architectural pattern or convention was introduced
- An existing pattern described in CLAUDE.md was changed or removed
- A new module layer was added (new directory under `lib/pvectl/`)
- Design patterns table needs a new entry

Do NOT propose for:
- Adding new classes/files within existing patterns (new handler, new model, etc.)
- Bug fixes, refactors that don't change architecture
- Anything that would turn CLAUDE.md into a class inventory

Format: briefly describe what changed and suggest specific edits. Wait for user approval before touching CLAUDE.md.

### Order of operations

```
1. Implement changes
2. Verify (tests pass, linter clean)
3. Update CHANGELOG.md
4. Update README.md (if user-facing)
5. Propose CLAUDE.md update (if architecture changed)
6. Commit
```
