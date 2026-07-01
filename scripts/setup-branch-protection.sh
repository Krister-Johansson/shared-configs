#!/usr/bin/env bash
# Create or update the "main-protection" ruleset on a repository.
#
# Usage:
#   setup-branch-protection.sh <owner/repo> <required-check-context>...
#
# Example (check contexts are the rendered job names — read them from a PR run
# with `gh pr checks <pr>` after the caller workflows have run once):
#   setup-branch-protection.sh Krister-Johansson/my-repo \
#     "ci / build + test (node 20)" \
#     "ci / build + test (node 22)" \
#     "ci / linked issue"
#
# Applies: PR required (no direct pushes), no force-push, no deletion,
# conversation resolution required, and the given required status checks
# (strict: branch must be up to date with main before merging).
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <owner/repo> <required-check-context>..." >&2
  exit 1
fi

REPO="$1"
shift

# Build the required_status_checks JSON array from the remaining args.
CHECKS=$(printf '%s\n' "$@" | jq -R '{context: .}' | jq -s .)

PAYLOAD=$(jq -n --argjson checks "$CHECKS" '{
  name: "main-protection",
  target: "branch",
  enforcement: "active",
  conditions: { ref_name: { include: ["~DEFAULT_BRANCH"], exclude: [] } },
  rules: [
    { type: "deletion" },
    { type: "non_fast_forward" },
    {
      type: "pull_request",
      parameters: {
        required_approving_review_count: 0,
        dismiss_stale_reviews_on_push: false,
        require_code_owner_review: false,
        require_last_push_approval: false,
        required_review_thread_resolution: true,
        allowed_merge_methods: ["merge", "squash", "rebase"]
      }
    },
    {
      type: "required_status_checks",
      parameters: {
        strict_required_status_checks_policy: true,
        required_status_checks: $checks
      }
    }
  ]
}')

# Update in place when a ruleset with this name already exists; create otherwise.
EXISTING_ID=$(gh api "repos/$REPO/rulesets" --jq '[.[] | select(.name == "main-protection")][0].id // empty')

if [ -n "$EXISTING_ID" ]; then
  echo "Updating existing ruleset $EXISTING_ID on $REPO"
  gh api --method PUT "repos/$REPO/rulesets/$EXISTING_ID" --input - <<<"$PAYLOAD" >/dev/null
else
  echo "Creating ruleset on $REPO"
  gh api --method POST "repos/$REPO/rulesets" --input - <<<"$PAYLOAD" >/dev/null
fi

echo "Done. Required checks:"
printf '  - %s\n' "$@"
