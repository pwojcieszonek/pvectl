# CI Gem Build & Publish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `.github/workflows/ci.yml` so a change to `Pvectl::VERSION` landing on `main` automatically builds, tags, GitHub-releases, and publishes the gem to RubyGems via OIDC.

**Architecture:** Single workflow file, two jobs. `test` runs on every PR and every push to `main` (unchanged). A new `release` job runs only on push to `main`, gated by `needs: test`; it reads the version from `version.rb`, and if tag `v<VERSION>` does not yet exist, it configures OIDC credentials, builds the gem, pushes it to RubyGems, then creates a git tag + GitHub Release with notes from `CHANGELOG.md` and the `.gem` attached.

**Tech Stack:** GitHub Actions, `ruby/setup-ruby`, `rubygems/configure-rubygems-credentials@v2.0.0` (OIDC Trusted Publishing), `bundler/gem_tasks` (`rake build`), `gh` CLI, `awk`.

---

## Note on methodology

A GitHub Actions workflow file has no unit-testable surface — there is no
red/green TDD cycle here. "Verification" means: the YAML parses, the job/step
wiring (`needs`, `if`, `permissions`) is correct, and `actionlint` (if available)
is clean. The first real publish is observed by the maintainer after merge.

## File structure

- Modify: `.github/workflows/ci.yml` — add `push` trigger + `release` job.
- Modify: `CHANGELOG.md` — record the new CI capability under `[Unreleased]`.

No `lib/` changes → no RBS updates. No CLI/flag changes → no README/Wiki/`long_desc` updates.

---

### Task 1: Add `release` job to the CI workflow

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Replace the whole workflow file with the final content**

Write `.github/workflows/ci.yml` with exactly this content:

```yaml
name: CI
permissions:
  contents: read

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Set up test config
        run: |
          mkdir -p ~/.pvectl
          cp test/fixtures/config/valid_config.yml ~/.pvectl/config
          chmod 600 ~/.pvectl/config

      - name: Run tests
        run: bundle exec rake test

  release:
    needs: test
    if: github.event_name == 'push'
    runs-on: ubuntu-latest

    permissions:
      contents: write   # push tag + create GitHub Release
      id-token: write   # OIDC for RubyGems Trusted Publishing

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Read gem version
        id: version
        run: echo "version=$(ruby -r ./lib/pvectl/version -e 'print Pvectl::VERSION')" >> "$GITHUB_OUTPUT"

      - name: Check whether tag already exists
        id: tag
        run: |
          if git ls-remote --exit-code --tags origin "refs/tags/v${{ steps.version.outputs.version }}" >/dev/null 2>&1; then
            echo "exists=true" >> "$GITHUB_OUTPUT"
            echo "Tag v${{ steps.version.outputs.version }} already exists — skipping release."
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
            echo "Tag v${{ steps.version.outputs.version }} not found — proceeding with release."
          fi

      - name: Extract release notes from CHANGELOG
        if: steps.tag.outputs.exists == 'false'
        run: |
          awk -v ver="${{ steps.version.outputs.version }}" '
            $0 ~ "^## \\[" ver "\\]" { capture = 1; next }
            capture && /^## / { exit }
            capture { print }
          ' CHANGELOG.md > release-notes.md
          echo "----- release-notes.md -----"
          cat release-notes.md

      - name: Configure RubyGems credentials (OIDC)
        if: steps.tag.outputs.exists == 'false'
        uses: rubygems/configure-rubygems-credentials@v2.0.0

      - name: Build gem
        if: steps.tag.outputs.exists == 'false'
        run: bundle exec rake build

      - name: Push gem to RubyGems
        if: steps.tag.outputs.exists == 'false'
        run: gem push "pkg/pvectl-${{ steps.version.outputs.version }}.gem"

      - name: Create git tag and GitHub Release
        if: steps.tag.outputs.exists == 'false'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "v${{ steps.version.outputs.version }}" \
            "pkg/pvectl-${{ steps.version.outputs.version }}.gem" \
            --title "v${{ steps.version.outputs.version }}" \
            --notes-file release-notes.md
```

- [ ] **Step 2: Validate YAML parses**

Run:
```bash
ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml"); puts "YAML OK"'
```
Expected: `YAML OK` (no exception).

- [ ] **Step 3: Lint the workflow (best-effort)**

Run:
```bash
command -v actionlint >/dev/null && actionlint .github/workflows/ci.yml || echo "actionlint not installed — skipping (not required)"
```
Expected: either `actionlint` prints no findings, or the skip message. Do NOT install actionlint just for this.

- [ ] **Step 4: Logic self-check (manual, no command)**

Confirm by reading the file:
- `release` has `needs: test` AND `if: github.event_name == 'push'`.
- Top-level `permissions` stays `contents: read`; elevated scope is only inside `release`.
- Every release-action step (notes → OIDC → build → push → release) carries `if: steps.tag.outputs.exists == 'false'`.
- Gem push happens BEFORE `gh release create` (no orphan tag on push failure).

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "feat(ci): build, tag, release and publish gem on version change"
```

---

### Task 2: Document the change in CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add an entry under `## [Unreleased]` → `### Added`**

Add this line to the `Added` subsection of `[Unreleased]` (create the `### Added`
subsection if it does not exist there yet):

```markdown
- **ci**: Automatically build, tag, create a GitHub Release, and publish the gem to RubyGems (OIDC Trusted Publishing) when `Pvectl::VERSION` changes on `main`; release is gated on passing tests and is idempotent via the `v<VERSION>` tag check.
```

- [ ] **Step 2: Verify the entry is well-formed**

Run:
```bash
grep -n "Trusted Publishing" CHANGELOG.md
```
Expected: one matching line under the `[Unreleased]` section.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(ci): changelog entry for automatic gem publish"
```

---

## Maintainer action required before the first publish (outside this repo)

The `release` job cannot succeed until a **Trusted Publisher** is configured on
rubygems.org for the `pvectl` gem, pointing at:

- Repository: `pwojcieszonek/pvectl`
- Workflow filename: `ci.yml`
- (Optional) a GitHub Actions environment name — only if you also add
  `environment: <name>` to the `release` job for extra protection.

Two cases:
- Gem already on rubygems.org → Owner dashboard → *Trusted Publishers* → add the
  entry above.
- Gem not yet published (`0.2.0` appears unpublished) → create a **pending**
  Trusted Publisher for the not-yet-existing name; the first OIDC `gem push`
  creates the gem.

Until this is done, the workflow will run and fail at the "Configure RubyGems
credentials" / "Push gem" step — which is the expected, safe failure mode (no
partial publish).

## Self-Review (completed)

- **Spec coverage:** triggers ✓ (Task 1 Step 1), `test` unchanged ✓, `release`
  gated by `needs`/`if` ✓, tag-based idempotency ✓, OIDC publish ✓, tag +
  Release + notes from CHANGELOG + `.gem` asset ✓, least-privilege permissions ✓,
  maintainer setup documented ✓, CHANGELOG entry ✓ (Task 2).
- **Placeholder scan:** none — full YAML and the exact CHANGELOG line are inline.
- **Type/name consistency:** step ids (`version`, `tag`) and their outputs
  (`version`, `exists`) are referenced consistently across all steps; artifact
  path `pkg/pvectl-<version>.gem` matches `rake build` output and is reused
  identically in push and release steps.
