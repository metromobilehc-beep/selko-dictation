#!/usr/bin/env bash
# Moves build.mjs into api/ so Vercel registers it as a serverless function,
# then commits and pushes. Run from inside the repo.
set -euo pipefail

if [ ! -d .git ]; then
  echo "Not a git repo. cd into the selko-dictate clone first."
  exit 1
fi

echo "Before:"
git ls-files

# The whole fix: Vercel only treats files under a directory named api/ as functions.
if [ -f build.mjs ]; then
  mkdir -p api
  git mv build.mjs api/build.mjs
  echo "Moved build.mjs -> api/build.mjs"
elif [ -f api/build.mjs ]; then
  echo "api/build.mjs already in place."
else
  echo "build.mjs not found anywhere. Download it and put it at api/build.mjs."
  exit 1
fi

# Stray copies of earlier versions will shadow the route.
for stray in api/build.js build.js; do
  [ -f "$stray" ] && git rm -q "$stray" && echo "Removed stale $stray"
done

echo
echo "After:"
git ls-files

echo
for f in index.html library.json package.json vercel.json api/build.mjs; do
  [ -f "$f" ] && echo "  ok      $f" || echo "  MISSING $f"
done

# Confirm the deployed page will be the current build.
if grep -q "Can't reach a model backend" index.html 2>/dev/null; then
  echo "  ok      index.html is the current version"
else
  echo "  STALE   index.html is an older download — replace it before pushing"
fi

echo
read -rp "Commit and push? [y/N] " yn
[[ "$yn" =~ ^[Yy]$ ]] || { echo "Stopped. Nothing pushed."; exit 0; }

git add -A
git commit -m "Move build.mjs into api/ so Vercel registers the function"
git push

echo
echo "Pushed. When the Vercel build goes green:"
echo "  curl -s https://dictation.selko360.com/api/build"
echo "Expect: {\"ok\":true,\"function\":\"deployed\",\"keySet\":true}"
