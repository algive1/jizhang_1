# dsh-patches — local fix for `dsh-codex-sync` session repair on DSH Desktop 2.0.x

Two files are patched inside the active DSH profile
(`~/.dsh/profiles/desktop/node_modules/dsh-codex-sync/lib/`):

| file | what changed |
|---|---|
| `session-repair.mjs` | rewritten repair/validation core (the upstream 1.6.1 version cannot read this DSH build's session logs at all) |
| `index.js` | one line: `input: { hint: '[--fix] [--root <dir>]' }` on the `repair-sessions` registration, so the composer executes the command instead of sending it to the model |

`session-repair.1.6.1.orig.mjs` is the untouched upstream file, kept for diffing
and reverting.

## Re-apply after a plugin update

```sh
sh /Users/algive/jizhang_01/dsh-patches/apply.sh
```

## Verify

```sh
cd /Users/algive/jizhang_01/dsh-patches
ELECTRON_RUN_AS_NODE=1 \
DSH_CHECKOUT='/Applications/DSH Desktop.app/Contents/Resources/app.asar/node_modules' \
'/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop' tests/verify-store.mjs   # store health (exit 1 if damaged)
ELECTRON_RUN_AS_NODE=1 \
DSH_CHECKOUT='/Applications/DSH Desktop.app/Contents/Resources/app.asar/node_modules' \
'/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop' tests/damage-classes.mjs # damage-class regression suite
```

Or run the plugin CLI directly (works without the app running):

```sh
ELECTRON_RUN_AS_NODE=1 \
DSH_CHECKOUT='/Applications/DSH Desktop.app/Contents/Resources/app.asar/node_modules' \
'/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop' \
~/.dsh/profiles/desktop/node_modules/dsh-codex-sync/bin/dsh-codex-sync.js repair-sessions --fix
```

## What upstream 1.6.1 got wrong on this build

* it decoded rows with `decodeStorageRecord` from `@deepseek-ai/dsh-session`,
  which this DSH build no longer exports → `0` events decoded → every legacy log
  reported as damaged;
* `--fix` then called the TokenMeter on an empty event list and threw
  `session header version must be 3, got 0`, repairing nothing;
* it only scanned `session.jsonl.zstd` (the v0 legacy generation) and ignored
  `session.v<N>.jsonl.zstd`, which is what the app actually reads;
* it validated with the lenient `recoverable` recovery path, which hides a
  seq-gap/seam by silently dropping the tail — the strict path (write/migration)
  is the one that throws in front of the user.

## Notes / limitations of the patched module

* packed chunk rows (`text-chunks`, `reasoning-chunks`, `tool-call-chunks`) are
  refused, not rewritten;
* seam repair remaps `sourceEventSeqs` only; a non-`append` surface-op payload
  with its own seq references can still fail post-repair validation, in which
  case the file is left untouched;
* a log whose final Zstandard frame is unfinished, or that a live process has
  open, is skipped rather than rewritten;
* an existing `.bak` is never overwritten, so the first backup stays intact.
