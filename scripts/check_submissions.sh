#!/usr/bin/env bash
# Report who submitted a given week and when, so lateness is a lookup rather than
# a judgement call.
#
#   ./scripts/check_submissions.sh 03 2026-09-06T20:00:00-10:00
#   ./scripts/check_submissions.sh 03                      # no deadline check
#
# The timestamp reported is the commit date GitHub recorded when the file was
# uploaded. For uploads made through the web interface this is set server-side,
# so it cannot be backdated.
set -euo pipefail

cd "$(dirname "$0")/.."

ORG=uh-manoa-uhero
PREFIX=econ630-f26-hw

if ! command -v gh >/dev/null 2>&1; then
  echo "error: the gh CLI is required -- install it with: brew install gh" >&2
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <week-number, zero-padded> [<deadline, ISO 8601>]" >&2
  echo "   eg: $0 03 2026-09-06T20:00:00-10:00" >&2
  exit 1
fi

week=$1
deadline=${2:-}
file="week${week}.pdf"

# Every homework repo in the org, derived from the naming convention.
repos=$(gh repo list "$ORG" --limit 200 --json name --jq \
        ".[] | select(.name | startswith(\"$PREFIX-\")) | .name")

if [ -z "$repos" ]; then
  echo "no repositories matching $ORG/$PREFIX-* -- has create_hw_repos.sh been run?" >&2
  exit 1
fi

printf '%-28s %-26s %s\n' "student" "uploaded" "status"
printf '%-28s %-26s %s\n' "-------" "--------" "------"

deadline_epoch=""
if [ -n "$deadline" ]; then
  # BSD date (macOS) needs the format spelled out; strip the colon in the offset.
  deadline_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" \
    "$(printf '%s' "$deadline" | sed 's/\(.*\)\(..\):\(..\)$/\1\2\3/')" +%s 2>/dev/null || true)
  if [ -z "$deadline_epoch" ]; then
    echo "warning: could not parse deadline '$deadline'; reporting times only" >&2
  fi
fi

for name in $repos; do
  student=${name#"$PREFIX-"}
  when=$(gh api "repos/$ORG/$name/commits?path=$file&per_page=1" \
           --jq '.[0].commit.committer.date' 2>/dev/null || true)

  if [ -z "$when" ] || [ "$when" = "null" ]; then
    printf '%-28s %-26s %s\n' "$student" "-" "MISSING"
    continue
  fi

  status="on time"
  if [ -n "$deadline_epoch" ]; then
    got=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$when" +%s 2>/dev/null || echo "")
    if [ -n "$got" ] && [ "$got" -gt "$deadline_epoch" ]; then
      status="LATE"
    fi
  else
    status=""
  fi
  printf '%-28s %-26s %s\n' "$student" "$when" "$status"
done
