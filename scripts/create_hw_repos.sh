#!/usr/bin/env bash
# Create one private homework repository per student and give that student write
# access to their own repository only.
#
#   ./scripts/create_hw_repos.sh --team econ630-fall2026   # roster from the team
#   ./scripts/create_hw_repos.sh alice-hi bob-uh carol-mnoa
#
# Safe to re-run: existing repositories are left in place, and the README is
# refreshed from assignments/hw-repo-README.md so wording fixes propagate. Re-run
# it after adding a student to the team and only the new repo is created.
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
  echo "usage: $0 --team <team-slug>" >&2
  echo "       $0 <github-username> [<github-username> ...]" >&2
  exit 1
fi

# Resolve the roster: either the members of a team, or usernames given directly.
if [ "$1" = "--team" ]; then
  team=${2:-}
  if [ -z "$team" ]; then
    echo "error: --team needs a team slug, e.g. --team econ630-fall2026" >&2
    exit 1
  fi
  members=$(gh api "orgs/$ORG/teams/$team/members" --paginate --jq '.[].login' 2>/dev/null || true)
  if [ -z "$members" ]; then
    echo "error: no members found in team '$team' (check the slug, and that you can read it)" >&2
    exit 1
  fi
  # shellcheck disable=SC2086
  set -- $members
  echo ">>> roster from team '$team': $# student(s)"
fi

# Safety check: with base permissions above "none", every organization member can
# read every repository in the org -- including each other's homework. Team
# membership makes students organization members, so this matters here.
base=$(gh api "orgs/$ORG" --jq '.default_repository_permission' 2>/dev/null || echo "")
case "$base" in
  none) ;;
  "")   echo "!!! could not read the org's base permission -- verify it is 'No permission'" >&2 ;;
  *)    echo "!!! WARNING: base permissions are '$base', not 'none'." >&2
        echo "!!! Every organization member can therefore read every repository in $ORG," >&2
        echo "!!! including other students' homework. Fix before adding students:" >&2
        echo "!!!   Settings > Member privileges > Base permissions > No permission" >&2
        printf '!!! Continue anyway? [y/N] ' >&2
        read -r reply </dev/tty || reply=""
        case "$reply" in [yY]*) ;; *) echo "aborted" >&2; exit 1;; esac ;;
esac

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
