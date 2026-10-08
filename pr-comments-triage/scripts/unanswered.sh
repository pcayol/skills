#!/usr/bin/env bash
# Lists the review threads on a PR that are still open AND that the PR author
# has never replied to. Those two conditions are different signals and both
# matter: `isResolved` says the reviewer considers it closed, a reply from the
# author says it has at least been answered. A thread can be unresolved yet
# already answered, and that one is not part of the worklist.
#
# Usage: unanswered.sh <pr-number> [owner/repo]
set -euo pipefail

PR="${1:?usage: unanswered.sh <pr-number> [owner/repo]}"
REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"

gh api graphql -F owner="$OWNER" -F name="$NAME" -F number="$PR" -f query='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      author { login }
      reviewThreads(first: 100) {
        nodes {
          isResolved
          isOutdated
          path
          line
          comments(first: 20) {
            nodes { databaseId author { login } createdAt body }
          }
        }
      }
    }
  }
}' | jq -r '
  .data.repository.pullRequest as $pr
  | $pr.author.login as $me
  | $pr.reviewThreads.nodes[]
  | select(.isResolved | not)
  | select([.comments.nodes[].author.login] | index($me) | not)
  | .comments.nodes[0] as $c
  | "### ID=\($c.databaseId) | \($c.author.login) | \(.path):\(.line // "?")\(if .isOutdated then " | OUTDATED" else "" end) | \($c.createdAt)\n\($c.body)\n"
'

echo "=== REVIEW BODIES (no resolution state, judge by hand) ==="
gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
  --jq '.[] | select(.body != "") | "--- \(.user.login) \(.state) \(.submitted_at)\n\(.body)\n"'

echo "=== ISSUE COMMENTS ==="
gh api "repos/$REPO/issues/$PR/comments" --paginate \
  --jq '.[] | "--- \(.user.login) \(.created_at)\n\(.body)\n"'
