# AGENTS.md — repo setup runbook

You are setting up a repository to use the shared configuration in
`Krister-Johansson/shared-configs`. Follow the steps in order. Two modes:

- **New repo**: all steps.
- **Migrate existing repo**: all steps, plus the notes marked **[migrate]**.

Work issue-first: create a tracking issue in the target repo ("Adopt
shared-configs setup"), do the work on a branch, and open a PR with
`Closes #<issue>` in the description.

## Step 0 — Preconditions

Verify before starting; stop and report if any fails:

```sh
gh auth status                      # authenticated gh CLI
gh repo view <owner/repo>           # target repo exists
```

Allow GitHub Actions to create PRs (required by release-please; off by default
on new repos):

```sh
gh api -X PUT repos/<owner/repo>/actions/permissions/workflow \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
```

Determine the repo type — it changes a few steps below:

- **package**: published to npm (has `"files"`/`"bin"`/`"exports"` and is meant
  to be installed by others)
- **service / frontend app**: deployed, not published

The target must be a Node/TypeScript project with these npm scripts in
package.json: `build`, `typecheck`, `test`, `coverage`. If any are missing, add
them first (`coverage` = the test runner with coverage; vitest:
`vitest run --coverage`, jest: `jest --coverage`). For plain-JS repos without a
`typecheck` script, set `run-typecheck: false` in the CI caller instead.

**Packages only** — also required:

```json
"prepublishOnly": "npm run build && npm test"
```

## Step 1 — Copy templates

From a checkout of shared-configs, copy each template to its destination in the
target repo:

| Source (this repo) | Destination (target repo) |
| --- | --- |
| `templates/workflows/ci.yml` | `.github/workflows/ci.yml` |
| `templates/workflows/release-please.yml` | `.github/workflows/release-please.yml` |
| `templates/workflows/codeql.yml` | `.github/workflows/codeql.yml` (see CodeQL note below) |
| `templates/workflows/scorecard.yml` | `.github/workflows/scorecard.yml` |
| `templates/github/dependabot.yml` | `.github/dependabot.yml` |
| `templates/github/ISSUE_TEMPLATE/*` | `.github/ISSUE_TEMPLATE/` |
| `templates/github/PULL_REQUEST_TEMPLATE.md` | `.github/PULL_REQUEST_TEMPLATE.md` |
| `templates/coderabbit.yaml` | `.coderabbit.yaml` |
| `templates/release-please-config.json` | `release-please-config.json` |
| `templates/release-please-manifest.json` | `.release-please-manifest.json` |
| `templates/codecov.yml` | `codecov.yml` |
| `templates/socket.yml` | `socket.yml` |
| `templates/gitignore` | `.gitignore` (merge if one exists) |
| `templates/npmrc` | `.npmrc` (packages only) |
| `templates/CONTRIBUTING.md` | `CONTRIBUTING.md` |
| `templates/SECURITY.md` | `SECURITY.md` |
| `templates/AGENTS.md` | `AGENTS.md` |
| `templates/prettierrc.json` | `.prettierrc` (only if adopting Prettier) |
| `templates/eslint.config.js` | `eslint.config.js` (only if adopting ESLint) |
| `templates/tsconfig.json` | `tsconfig.json` (starter for NEW repos only) |

**CodeQL note**: skip `codeql.yml` if the repo uses CodeQL **default setup** —
GitHub rejects advanced-configuration SARIF uploads while it's enabled (and
default setup already covers JS/TS + Actions). Check first:

```sh
gh api repos/<owner>/<repo>/code-scanning/default-setup --jq .state
# "configured" => default setup is on: do NOT copy codeql.yml
# "not-configured" => copy codeql.yml
```

**[migrate]** Do not overwrite an existing tsconfig, eslint, or prettier config.
Do not overwrite existing CONTRIBUTING/SECURITY if they contain repo-specific
content — merge instead: keep the repo-specific sections, adopt the
issue-first + TDD workflow sections from the template. If the repo has a
CLAUDE.md with repo-specific constraints, keep it; AGENTS.md adds the workflow
rules and the two must not contradict.

## Step 2 — Replace placeholders

In every copied file, replace:

| Placeholder | Value |
| --- | --- |
| `{{REPO_SLUG}}` | `owner/repo`, e.g. `Krister-Johansson/my-repo` |
| `{{PACKAGE_NAME}}` | npm package name from package.json |
| `{{NODE_MIN}}` | minimum Node from package.json `engines` (default `20`) |
| `{{SCOPE_NOTES}}` | 2-4 sentences: what the package does and which vulnerability classes are most relevant |
| `{{CURRENT_VERSION}}` | package.json `version` **[migrate]**, or `0.1.0` for a new repo |
| `{{SHARED_CONFIGS_SHA}}` / `{{SHARED_CONFIGS_VERSION}}` | see Step 3 |

Verify none remain: `grep -rn '{{' .github/ *.md *.json *.yaml 2>/dev/null` must return nothing.

## Step 3 — Pin the shared workflows

```sh
TAG=$(gh release view --repo Krister-Johansson/shared-configs --json tagName --jq .tagName)
SHA=$(gh api repos/Krister-Johansson/shared-configs/commits/$TAG --jq .sha)
```

Replace `{{SHARED_CONFIGS_SHA}}` with `$SHA` and `{{SHARED_CONFIGS_VERSION}}`
with `$TAG` in all four workflow files. Result:

```yaml
uses: Krister-Johansson/shared-configs/.github/workflows/ci.yml@<sha> # v1.2.3
```

## Step 4 — Configure the CI caller

Edit `.github/workflows/ci.yml` inputs to match the repo:

- `run-lint: true` only if the repo has a `lint` script.
- `run-typecheck: false` only for plain-JS repos without a `typecheck` script.
- `post-test-scripts`: extra npm test scripts, e.g. `"test:types attw"`.
- `upload-coverage-artifact: true` only if you add a local coverage-comment job.
- Repo-specific jobs (integration tests, coverage comments) go in the same file
  as sibling jobs of `ci:`.

And `.github/workflows/release-please.yml`:

- **package**: keep `publish-strategy: oidc` (or `npm-token` if a secret-based
  flow is required).
- **service / frontend app**: set `publish-strategy: none` and uncomment/adapt
  the `deploy` sibling job, gated on
  `needs.release.outputs.release_created == 'true'` (outputs: `tag_name`,
  `version`). release-please still manages versions, CHANGELOG, and releases.

**[migrate]** Delete the old workflow files the callers replace. Keep any
workflow that has no shared equivalent.

## Step 5 — Validate and open the PR

```sh
actionlint .github/workflows/*.yml     # must be clean (install: https://github.com/rhysd/actionlint)
npm ci && npm run build && npm run typecheck && npm run coverage
git checkout -b chore/adopt-shared-configs
git add -A && git commit -m "chore: adopt shared-configs reusable workflows and templates"
gh pr create --title "chore: adopt shared-configs setup" --body "... Closes #<tracking-issue>"
```

Wait for the PR checks. Expected check contexts (verify with `gh pr checks`):
`ci / build + test (node 20)`, `ci / build + test (node 22)`, `ci / linked issue`,
plus `CodeQL / codeql / Analyze (javascript-typescript)` on PRs.

## Step 6 — Branch protection (after the PR checks have run once)

```sh
./scripts/setup-branch-protection.sh <owner/repo> \
  "ci / build + test (node 20)" \
  "ci / build + test (node 22)" \
  "ci / linked issue"
```

Use the exact contexts from `gh pr checks` — add repo-specific ones (e.g.
integration jobs). **[migrate]** If old branch protection required the previous
check names, run this only when the migration PR is ready to merge, then merge.

## Step 7 — Manual steps to hand back to the human

Report these as a checklist; they need account access you don't have:

1. **npm Trusted Publishing** (packages with publish-strategy `oidc` only —
   skip for services/frontends):
   npmjs.com → package → Settings → Trusted Publisher:
   Provider `GitHub Actions`, Organization `Krister-Johansson`,
   Repository `<repo>`, Workflow filename `release-please.yml`.
   Until this exists, the publish job fails after a release — re-run it via
   the Actions tab once configured. (For `npm-token` instead: add an `NPM_TOKEN`
   granular automation token as a repo secret.)
2. Install GitHub Apps on the repo: **CodeRabbit**, **Socket**, **Codecov**.
3. Optional repo secrets: `CODECOV_TOKEN`, `SCORECARD_TOKEN` (PAT with
   Administration:read).

## Step 8 — Verify

- PR checks green; `linked issue` check passed (PR body has `Closes #N`).
- CodeRabbit reviewed the PR (its comment shows the remote config is applied).
- After merge: release-please opens/updates a release PR on the next
  `feat:`/`fix:` commit; merging it tags a release and publishes to npm.
