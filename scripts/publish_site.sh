#!/usr/bin/env bash
# Publish the rendered site in docs/ to the gh-pages branch.
#
# Why a separate branch: main carries sources only. index.qmd sets
# `date: last-modified`, and the HTML is self-contained (~1.9 MB), so every
# render produces a wholly new file. Committing docs/ to main would add another
# copy to history each time. Here the site lives on gh-pages, which is
# force-replaced with a single commit, so only one copy of the output is ever
# reachable and the repository size stays flat no matter how often you publish.
# Nothing of value is lost: the site is fully regenerable from main.
#
# SYLLABUS_ECON630.pdf is served from the same branch, which is why the download
# link in index.qmd is a plain relative link gated by the same GitHub sign-in as
# the syllabus itself.
#
# Usage:
#   quarto render          # produce docs/
#   ./scripts/publish_site.sh   # push docs/ to gh-pages
#
# GitHub Pages must be configured to serve branch gh-pages from / (root).
set -euo pipefail

cd "$(dirname "$0")/.."

BRANCH=gh-pages

if [ ! -f docs/index.html ]; then
  echo "error: docs/index.html not found -- run 'quarto render' first" >&2
  exit 1
fi

URL=$(git remote get-url origin)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cp -R docs/. "$TMP/"

# macOS sprinkles these through any browsed directory; do not publish them.
find "$TMP" -name '.DS_Store' -delete

# Stop GitHub running the output through Jekyll, which would drop files and
# directories whose names begin with an underscore.
touch "$TMP/.nojekyll"

git -C "$TMP" init -q -b "$BRANCH"
git -C "$TMP" add -A
git -C "$TMP" commit -q -m "Site build $(date '+%Y-%m-%d %H:%M')"

# Force-push: this branch is disposable output, so it is replaced rather than
# appended to. The previous build's objects become unreachable and stop counting
# toward the size of a clone.
git -C "$TMP" push -f "$URL" "$BRANCH"

echo "Published $(du -sh docs | cut -f1) to $BRANCH"
