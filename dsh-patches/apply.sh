#!/bin/sh
# Re-install the local dsh-codex-sync patches into the active DSH Desktop profile.
#
# Why a script: the profile's node_modules files are hardlinked into the pnpm
# content-addressable store, so editing them in place would also rewrite the
# store copy. This script copies the patched files next to the originals and
# renames them into place, which breaks the hardlink and leaves the store
# pristine. A plugin update (dsh-market / `dsh plugin update`) restores the
# upstream files, so re-run this afterwards.
#
# Usage: sh apply.sh [/path/to/profile]   (default: ~/.dsh/profiles/desktop)
set -eu

PATCH_DIR=$(cd "$(dirname "$0")" && pwd)
PROFILE=${1:-"$HOME/.dsh/profiles/desktop"}
TARGET_DIR="$PROFILE/node_modules/dsh-codex-sync/lib"

if [ ! -d "$TARGET_DIR" ]; then
  echo "dsh-codex-sync not installed in $PROFILE — nothing to patch" >&2
  exit 1
fi

for name in session-repair.mjs index.js; do
  src="$PATCH_DIR/$name"
  dst="$TARGET_DIR/$name"
  [ -f "$src" ] || { echo "missing patch file $src" >&2; exit 1; }
  cp "$src" "$dst.new"
  rm -f "$dst"
  mv "$dst.new" "$dst"
  echo "patched $dst"
done

echo
echo "Verify with:"
echo "  cd '$PATCH_DIR' && ELECTRON_RUN_AS_NODE=1 DSH_CHECKOUT='/Applications/DSH Desktop.app/Contents/Resources/app.asar/node_modules' '/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop' tests/verify-store.mjs"
echo "Restart DSH Desktop for the running app to pick the patch up (HMR is disabled in this profile)."
