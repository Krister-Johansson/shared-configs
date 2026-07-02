# shared-configs

One place for the repo setup shared by all
[Krister-Johansson](https://github.com/Krister-Johansson) packages: reusable
GitHub Actions workflows, the shared CodeRabbit configuration, and copyable
templates for everything that GitHub can't reference remotely.

Used by [gqlprune](https://github.com/Krister-Johansson/gqlprune) and
[prisma-extension-timescaledb](https://github.com/Krister-Johansson/prisma-extension-timescaledb).

> **Setting up a repo with an AI agent?** Point it at [AGENTS.md](AGENTS.md) —
> it's a deterministic runbook for the whole setup.

## What lives where

| Asset | Mechanism | Where |
| --- | --- | --- |
| CI, release-please (+ npm publish or deploy chaining), Scorecard, CodeQL | Reusable workflows (`workflow_call`) — consumers keep ~15-line callers | [`.github/workflows/`](.github/workflows/) |
| CodeRabbit review settings | One shared file, pulled via `remote_config.url` | [`.coderabbit.yaml`](.coderabbit.yaml) |
| Everything GitHub can't remote-include, organized as **common + profile** | Copied per repo | [`templates/`](templates/) |
| Branch protection ruleset | Applied via `gh api` | [`scripts/setup-branch-protection.sh`](scripts/setup-branch-protection.sh) |

## Repo profiles

Every repo copies [`templates/common/`](templates/common/) plus **one** profile:

| Profile | For | Caller specifics |
| --- | --- | --- |
| [`templates/package/`](templates/package/) | npm packages | `publish-strategy: oidc` (Trusted Publishing), `.npmrc` |
| [`templates/service/`](templates/service/) | deployed backends/APIs | `publish-strategy: none`, skeleton `integration`/`docker-build` CI jobs, `deploy` job chained on release outputs |
| [`templates/frontend/`](templates/frontend/) | deployed web apps | `publish-strategy: none`, skeleton Playwright `e2e` job, optional release-gated deploy |

Repo-specific jobs stay in the caller files as sibling jobs — when the same job
shape shows up in 2+ repos, it gets promoted into a shared reusable workflow
here.

## Quick start (new or existing repo)

1. **Copy the templates**: everything from `templates/common/` plus your
   profile directory (`templates/package/`, `templates/service/`, or
   `templates/frontend/`) — destination mapping in [AGENTS.md](AGENTS.md)
   step 1 (workflows go to `.github/workflows/`, `github/` to `.github/`,
   dotfile templates get their leading dot).

2. **Replace the placeholders** — `{{REPO_SLUG}}` (e.g. `Krister-Johansson/my-repo`),
   `{{PACKAGE_NAME}}`, `{{NODE_MIN}}`, `{{SCOPE_NOTES}}`, `{{CURRENT_VERSION}}`
   (the package.json version for existing repos, `0.1.0` for new ones), and
   `{{SHARED_CONFIGS_SHA}}` / `{{SHARED_CONFIGS_VERSION}}` (see next step).

3. **Pin the reusable workflows** to the latest release of this repo:

   ```sh
   TAG=$(gh release view --repo Krister-Johansson/shared-configs --json tagName --jq .tagName)
   SHA=$(gh api repos/Krister-Johansson/shared-configs/commits/$TAG --jq .sha)
   # in each .github/workflows/*.yml caller:
   #   uses: Krister-Johansson/shared-configs/.github/workflows/ci.yml@$SHA # $TAG
   ```

   Dependabot (from the copied `dependabot.yml`) bumps these pins weekly when
   new shared-configs releases are tagged.

4. **package.json requirements**: scripts `build`, `typecheck`, `test`, `coverage`
   (and `lint` if you enable `run-lint`), plus a publish gate:

   ```json
   "prepublishOnly": "npm run build && npm test"
   ```

5. **Branch protection** (after CI has run once so the check names are known):

   ```sh
   gh pr checks <pr-number> --repo <owner/repo>   # read the exact check contexts
   ./scripts/setup-branch-protection.sh <owner/repo> "ci / build + test (node 20)" "ci / build + test (node 22)" "ci / linked issue"
   ```

6. **One-time manual steps** (cannot be automated):
   - **npm Trusted Publishing** (default publish strategy, no secret needed):
     npmjs.com → package → Settings → Trusted Publisher →
     Provider *GitHub Actions*, Organization *Krister-Johansson*,
     Repository *\<repo\>*, Workflow filename *release-please.yml*.
     (npm matches the **caller** repo and filename, so the reusable indirection
     changes nothing here.)
   - Install the **CodeRabbit**, **Socket**, and **Codecov** GitHub Apps on the repo.
   - Optional secrets: `CODECOV_TOKEN` (coverage upload), `SCORECARD_TOKEN`
     (PAT with Administration:read for the Branch-Protection score),
     `NPM_TOKEN` (only with `publish-strategy: npm-token`).

## Reusable workflow reference

### `ci.yml`

| Input | Default | Purpose |
| --- | --- | --- |
| `node-versions` | `'["20", "22"]'` | JSON array for the test matrix |
| `run-lint` | `false` | Run `npm run lint` |
| `run-typecheck` | `true` | Run `npm run typecheck` (disable for plain-JS repos) |
| `post-test-scripts` | `""` | Extra npm scripts after coverage, e.g. `"test:types attw"` |
| `upload-coverage-artifact` | `false` | Upload `coverage/` artifact for PR comment jobs |
| `require-issue-link` | `true` | Fail PRs that don't reference an issue (`Closes #N`) |

Secrets: `CODECOV_TOKEN` (optional). Repo-specific jobs (integration tests,
coverage comments) live as sibling jobs in the caller file.

### `release-please.yml`

| Input | Default | Purpose |
| --- | --- | --- |
| `publish-strategy` | `"oidc"` | `oidc` = npm Trusted Publishing (packages, recommended); `npm-token` = classic secret + `--provenance`; `none` = services/frontends — releases + CHANGELOG only, no npm |
| `publish-node-version` | `"24"` | Node for the publish job (Trusted Publishing needs >= 22.14) |

| Output | Purpose |
| --- | --- |
| `release_created` | `'true'` when this run created a GitHub release |
| `tag_name` / `version` | e.g. `v1.2.3` / `1.2.3` — chain deploy jobs off these |

Secrets: `NPM_TOKEN` (only for `npm-token`). Caller job must grant
`contents: write`, `pull-requests: write` (+ `id-token: write` when publishing
to npm). The consumer repo owns `release-please-config.json` +
`.release-please-manifest.json`.

**Services and frontend apps**: use `publish-strategy: none` and add a `deploy`
sibling job in the caller gated on
`needs.release.outputs.release_created == 'true'` — see the commented example
in [`templates/workflows/release-please.yml`](templates/workflows/release-please.yml).
Everything else (CI, CodeQL, Scorecard, CodeRabbit, templates) applies to
non-package repos unchanged; skip the npm Trusted Publisher and `.npmrc` steps.

### `scorecard.yml` / `codeql.yml`

Near-zero config. Triggers (cron etc.) live in the caller templates because
reusable workflows can't define them. Scorecard takes the optional
`SCORECARD_TOKEN` secret; CodeQL takes a `languages` input
(default `javascript-typescript`).

## Development workflow the templates encode

- **Issue-first**: every PR must track a GitHub issue (`Closes #N`) — enforced
  by the `linked issue` CI job.
- **TDD**: failing test first, then the implementation (see `templates/AGENTS.md`).
- **Conventional Commits** drive release-please versioning.

## Versioning of this repo

release-please tags `vX.Y.Z` releases from Conventional Commits on `main`.
Consumers pin `uses:` references to a release SHA with the version as a
comment; their dependabot bumps the pin. Breaking changes to workflow inputs
are `feat!:` commits (major bump) so consumers see them coming.
