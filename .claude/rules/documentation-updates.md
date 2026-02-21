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

### 3. CLI Help (`long_desc`)

When adding or modifying a command, MUST update its `long_desc` help text:

- Every command MUST have a `long_desc` with man-page style sections: DESCRIPTION, EXAMPLES, NOTES, SEE ALSO
- Sub-commands use `parent.long_desc <<~HELP ... HELP` BEFORE `parent.command :name do |s|` (NOT `s.long_desc` inside the block — GLI ignores it)
- Sub-commands also need `parent.desc "..."` before `parent.command` for the short description
- Include 2-5 practical examples with `$ pvectl ...` syntax
- Reference related commands in SEE ALSO

### 4. GitHub Wiki

When changes affect user-facing behavior, update the relevant wiki page(s):

- Wiki repo is cloned locally (see `CLAUDE.local.md` for path)
- Key pages to consider: Command-Reference.md, Configuration-Guide.md, Getting-Started.md, Workflows.md
- New commands → update Command-Reference.md
- New flags/options → update Command-Reference.md and any relevant guide pages
- New configuration options → update Configuration-Guide.md
- Commit and push wiki changes separately (wiki is a separate git repo)

### When to skip

- Pure test changes (`test:` commits) — skip README/wiki, add to CHANGELOG only if significant
- CI/CD or tooling changes (`chore:` commits) — skip all unless user-facing
- `.claude/` config changes — skip all

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
2. Update RBS signatures (see rbs-signatures.md)
3. Update CLI help long_desc (if command changed)
4. Verify (tests pass, rbs parse clean)
5. Update CHANGELOG.md
6. Update README.md (if user-facing)
7. Update GitHub Wiki (if user-facing)
8. Propose CLAUDE.md update (if architecture changed)
9. Commit code changes
10. Commit and push wiki changes (separate repo)
```
