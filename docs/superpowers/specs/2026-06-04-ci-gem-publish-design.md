# CI: automatic gem build & publish on version change

**Date:** 2026-06-04
**Branch:** `feat/ci-gem-publish`
**File touched:** `.github/workflows/ci.yml`

## Goal

Extend the existing CI workflow so that, whenever `Pvectl::VERSION`
(`lib/pvectl/version.rb`) changes and lands on `main`, CI automatically builds
the gem, tags the release, creates a GitHub Release, and publishes the gem to
RubyGems — all driven by a single source of truth: the `VERSION` constant.

No separate version field is maintained anywhere; the gemspec already derives
its version from `Pvectl::VERSION`, so the workflow reads the same constant.

## Requirements (agreed with maintainer)

1. The current `test` job MUST keep running on **every pull request** to `main`.
   A PR with failing tests must not be mergeable (branch protection enforces
   this; CI provides the signal).
2. A gem MUST NOT be published unless tests pass (`release` job `needs: test`).
3. Publishing happens on `push` to `main` only (i.e. after a PR merge).
4. Version-change detection is **tag-based**: if tag `v<VERSION>` already exists,
   the release steps are skipped (idempotent — safe on re-runs / re-merges).
5. Publishing to RubyGems uses **OIDC Trusted Publishing** (no long-lived API
   key stored in the repo).
6. The workflow creates a git tag `v<VERSION>` and a GitHub Release whose body is
   the matching `## [<VERSION>]` section of `CHANGELOG.md`, with the built `.gem`
   attached as a release asset.

## Triggers & job structure

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
```

| Job       | Runs on                          | Responsibility                                   |
|-----------|----------------------------------|--------------------------------------------------|
| `test`    | every PR **and** every push to `main` | `bundle exec rake test` (unchanged behavior)     |
| `release` | push to `main` only, `needs: test`    | detect new version → tag, GitHub Release, publish |

- `release` is gated by `if: github.event_name == 'push'` so it never appears on
  PRs, and by `needs: test` so it never runs when tests fail.

## Permissions (least privilege)

- Top-level stays `permissions: contents: read`.
- The `release` job overrides with its own elevated scope:
  - `contents: write` — push tag + create GitHub Release.
  - `id-token: write` — OIDC token for Trusted Publishing.

## `release` job — step order

1. **checkout** with `fetch-depth: 0` (full history + tags).
2. **setup-ruby** — Ruby from `.ruby-version`, `bundler-cache: true`.
3. **Read version** — `ruby -r ./lib/pvectl/version -e 'print Pvectl::VERSION'`
   → step output `version`. Single source of truth.
4. **Check tag exists** — `git ls-remote --tags origin "refs/tags/v$VERSION"`;
   step output `exists` (`true`/`false`). If `true`, every subsequent step is
   skipped via `if: steps.<check>.outputs.exists == 'false'`.
5. **Extract release notes** — pull the `## [<VERSION>]` section from
   `CHANGELOG.md` (up to the next `## ` heading) into `release-notes.md`.
6. **Configure OIDC credentials** — `rubygems/configure-rubygems-credentials@v1`
   (exchanges the OIDC token for a short-lived RubyGems API key).
7. **Build** — `bundle exec rake build` → `pkg/pvectl-<VERSION>.gem`.
8. **Push to RubyGems** — `gem push pkg/pvectl-<VERSION>.gem`. Publishing happens
   **before** tagging, so a failed push leaves no orphan tag/release.
9. **Create GitHub Release** — `gh release create "v$VERSION"
   "pkg/pvectl-$VERSION.gem" --notes-file release-notes.md`. One command creates
   the tag, the Release, and uploads the `.gem` as an asset. Uses
   `GH_TOKEN: ${{ github.token }}`.

## CHANGELOG heading format

Headings look like `## [0.2.0] — 2026-05-17`. Extraction matches the line
starting with `## [<VERSION>]` and captures everything until the next line
starting with `## `, excluding both heading lines from the emitted notes.

## One-time maintainer setup (outside this repo)

OIDC Trusted Publishing requires a Trusted Publisher entry on rubygems.org for
the `pvectl` gem, pointing at repo `pwojcieszonek/pvectl` and this workflow:

- If the gem already exists on rubygems.org → add a Trusted Publisher in the
  gem's settings (Owner → Trusted Publishers).
- If the gem does not yet exist (`0.2.0` appears unpublished) → create a
  **pending** Trusted Publisher for the not-yet-existing gem name; the first
  OIDC-authenticated `gem push` will create the gem.

This is a manual, one-time action by the maintainer; the workflow cannot perform
it.

## Out of scope (YAGNI)

- No Ruby version matrix, no linting additions.
- No automated version bump — editing `version.rb` stays a deliberate manual
  decision by the maintainer (release timing is the maintainer's call).

## Verification

- `act` / push to a throwaway branch is not used; correctness is verified by:
  - YAML validity (workflow parses, jobs/steps well-formed).
  - Logic review: tag-existence gate, `needs`/`if` wiring, permissions scope.
  - The first real publish is observed by the maintainer after merge.
