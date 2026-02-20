# RBS Type Signatures Rules

## MUST maintain RBS signatures alongside code changes

Every time you create, modify, or delete a Ruby file under `lib/`, you MUST update the corresponding RBS signature file under `sig/`.

### When creating a new file

- Create `sig/pvectl/<path>.rbs` mirroring `lib/pvectl/<path>.rb`
- Include signatures for all public and private methods, attr_readers, constants, and class inheritance
- Follow existing RBS conventions in the project (see below)

### When modifying an existing file

- Update the corresponding `.rbs` file to reflect:
  - New methods added
  - Changed method signatures (parameters, return types)
  - Removed methods
  - Changed visibility (public/private)
  - New or changed constants
  - Changed inheritance or module includes

### When deleting a file

- Delete the corresponding `.rbs` file

### When renaming/moving a file

- Rename/move the corresponding `.rbs` file to match the new path

## Validation

After creating or modifying `.rbs` files, validate syntax:

```bash
BUNDLE_GEMFILE="" rbs parse sig/pvectl/<path>.rbs
```

The `rbs` gem is NOT in the project's Gemfile — always use `BUNDLE_GEMFILE=""` to bypass bundler.

## Conventions

Follow these established project conventions:

| Convention | Example |
|------------|---------|
| Nullable types | `String?` for values that can be nil |
| Boolean predicates | `def running?: () -> bool` |
| API data hashes | `Hash[Symbol, untyped]` |
| Void returns | `-> void` for methods with no meaningful return |
| VMIDs/CTIDs | `Integer` (or `Integer \| String` when API accepts both) |
| UPIDs | `String` |
| Gem boundary types | `untyped` for objects from external gems (GLI, ProxmoxAPI, TTY, Pastel) |
| Optional parameters | `?String name` for positional, `?key: String` for keyword |
| Block parameters | `{ (String) -> void }` or `{ () -> String }` |

### RBS limitations to remember

- **No `protected`** — use `private` instead (RBS only supports `public` and `private`)
- **No `extend untyped`** — list class methods directly with a comment
- **No `nil` in tuple literals** — use `[String?, String?]` instead of `[String, String] | [nil, nil]`

## Order of operations

RBS updates fit into the documentation workflow (see `documentation-updates.md`):

```
1. Implement changes
2. Update RBS signatures          ← here
3. Verify (tests pass, rbs parse clean)
4. Update CHANGELOG.md
5. Update README.md (if user-facing)
6. Propose CLAUDE.md update (if architecture changed)
7. Commit
```

## When to skip

- Changes to files outside `lib/` (tests, config, docs, `.claude/` rules)
- Changes to `lib/pvectl/version.rb` — `VERSION` constant is already in `sig/pvectl.rbs`
