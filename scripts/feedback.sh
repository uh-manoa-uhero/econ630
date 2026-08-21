#!/usr/bin/env bash
# Post feedback to a student's homework repository as an issue.
#
#   ./scripts/feedback.sh 03 alice-hi "Good summary. See the note on exercise 4."
#   ./scripts/feedback.sh 03 alice-hi -f notes.md   # body from a file
#   ./scripts/feedback.sh 03 alice-hi               # opens your editor
#
# An issue is the efficient choice for occasional feedback: one command, the
# student is emailed, and they can reply in the same place. It is also visible in
# their repository's Issues tab, so nothing gets lost in a mail thread.
#
# If your comment is about one specific upload rather than the week as a whole,
# comment on the commit instead -- it anchors the remark to the file that was
# submitted:
#
#   gh api repos/ORG/REPO/commits/<sha>/comments -f body="..."
#
# Get the sha from: ./scripts/check_submissions.sh <week>
set -euo pipefail

cd "$(dirname "$0")/.."

ORG=uh-manoa-uhero
PREFIX=econ630-f26-hw

if ! command -v gh >/dev/null 2>&1; then
  echo "error: the gh CLI is required -- install it with: brew install gh" >&2
  exit 1
fi

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <week-number> <github-username> [message | -f <file>]" >&2
  echo "   eg: $0 03 alice-hi \"Good summary. See the note on exercise 4.\"" >&2
  exit 1
fi

week=$1
user=$2
shift 2

repo="$ORG/$PREFIX-$user"
title="Week $week feedback"

if ! gh repo view "$repo" >/dev/null 2>&1; then
  echo "error: $repo not found -- has create_hw_repos.sh been run for $user?" >&2
  exit 1
fi

case "${1:-}" in
  -f)
    if [ -z "${2:-}" ] || [ ! -f "$2" ]; then
      echo "error: -f needs a readable file" >&2
      exit 1
    fi
    gh issue create --repo "$repo" --title "$title" --body-file "$2"
    ;;
  "")
    # No message given: gh opens $EDITOR for the body.
    gh issue create --repo "$repo" --title "$title"
    ;;
  *)
    gh issue create --repo "$repo" --title "$title" --body "$1"
    ;;
esac
