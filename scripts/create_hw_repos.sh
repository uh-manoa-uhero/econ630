#!/usr/bin/env bash
# Create one private homework repository per student and give that student write
# access to their own repository only.
#
#   ./scripts/create_hw_repos.sh alice-hi bob-uh carol-mnoa
#
# Safe to re-run: existing repositories are left in place, and the README is
# refreshed from assignments/hw-repo-README.md so wording fixes propagate.
#
# Why per-student repositories rather than a shared one: everything in the course
# repository is visible to everyone with read access, so homework cannot live
# there. A private repository per student is the only arrangement on GitHub that
# keeps one student's work invisible to the others.
set -euo pipefail

cd "$(dirname "$0")/.."

ORG=uh-manoa-uhero
PREFIX=econ630-f26-hw
TEMPLATE=assignments/hw-repo-README.md

if ! command -v gh >/dev/null 2>&1; then
  echo "error: the gh CLI is required -- install it with: brew install gh" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <github-username> [<github-username> ...]" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "error: $TEMPLATE not found" >&2
  exit 1
fi

# The student-facing text is everything after the first '---' line.
readme=$(awk 'found {print} /^---$/ && !found {found=1}' "$TEMPLATE")
if [ -z "$readme" ]; then
  echo "error: no content after the '---' marker in $TEMPLATE" >&2
  exit 1
fi
encoded=$(printf '%s\n' "$readme" | base64 | tr -d '\n')

for user in "$@"; do
  repo="$ORG/$PREFIX-$user"

  if gh repo view "$repo" >/dev/null 2>&1; then
    echo ">>> $repo exists"
  else
    gh repo create "$repo" --private \
      --description "ECON 630 Fall 2026 homework -- $user"
    echo ">>> created $repo"
  fi

  # Create or update README.md. The contents API needs the current blob sha to
  # replace a file, so look it up and pass it only when the file already exists.
  sha=$(gh api "repos/$repo/contents/README.md" --jq .sha 2>/dev/null || true)
  if [ -n "$sha" ]; then
    gh api -X PUT "repos/$repo/contents/README.md" \
      -f message="Refresh homework instructions" \
      -f content="$encoded" -f sha="$sha" >/dev/null
    echo "    README refreshed"
  else
    gh api -X PUT "repos/$repo/contents/README.md" \
      -f message="Add homework instructions" \
      -f content="$encoded" >/dev/null
    echo "    README added"
  fi

  # push = write access: enough to upload files through the web interface.
  gh api -X PUT "repos/$repo/collaborators/$user" -f permission=push >/dev/null
  echo "    invited $user with write access"
done

echo
echo "Done. Students receive an invitation email; the repository appears once they accept."
echo "Do NOT give the econ630-fall2026 team access to these repositories -- that would"
echo "make every submission readable by the whole class."
