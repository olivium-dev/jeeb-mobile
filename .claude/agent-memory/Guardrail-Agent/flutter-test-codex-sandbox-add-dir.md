---
name: flutter-test-codex-sandbox-add-dir
description: flutter test exits 255 under codex exec --sandbox workspace-write because Flutter writes to its SDK cache lockfile and ~/.dart-tool; fix with --add-dir for both plus FLUTTER_SUPPRESS_ANALYTICS=true
metadata:
  type: project
---

`flutter test` **cannot run** under `codex exec --sandbox workspace-write` as-is. Flutter
writes outside the workspace and both writes are denied, producing **exit 255**:

- `/Users/oudaykhaled/development/flutter/bin/cache/lockfile`
- `~/.dart-tool/dart-flutter-telemetry-session.json`

**Fix** (proven by isolated probe — "All tests passed!", 3 tests, identical sandbox
config): pass `--add-dir` for the Flutter SDK path **and** `~/.dart-tool`, plus
`FLUTTER_SUPPRESS_ANALYTICS=true`.

**Why this bites late:** `dart analyze` is unaffected and passes cleanly, so a lane looks
healthy right up until its first test run. Check the `codex exec` prompt for `--add-dir`
*before* dispatching — it is far cheaper than discovering it after a lane burns a run.

**The dangerous part:** exit 255 is non-zero, so any harness that treats "non-zero =
test failed" will score a sandbox denial as a **passing negative control**. This is the
same fake-RED failure as a typo'd `--plain-name`, reached from a completely different
direction, and neither involves the code under test. See
[[instruments-only-observed-succeeding]] — the fix is to require a positive control
(test PASSES on a clean tree) rather than trust an exit code in either direction.

**Second trap, same sandbox:** Codex `--sandbox workspace-write` also **cannot commit in a
linked git worktree**. The worktree's `.git` is a *file* pointing at
`<main-clone>/.git/worktrees/<name>`, outside the sandbox, so `git add` fails with
`Unable to create index.lock: Operation not permitted`. Fix: `--add-dir <main-clone>/.git`.
A Flutter lane in a linked worktree therefore needs **three** `--add-dir` flags: Flutter SDK,
`~/.dart-tool`, and the main clone's `.git`.

**Derive the grant list from REQUIREMENTS, not from failures.** A grant list assembled by
fixing observed failures can only ever contain traps already tripped — three of one shape
landed that way (SDK lockfile, linked-worktree gitdir, and the framework's own mandated
execution-log directory). Instead enumerate what the framework and the lane's plan *oblige*
the executor to do — read the worktree, run the toolchain, commit to a linked worktree,
write an execution log to the dossier, write evidence files, resolve deps, build an APK —
then grant each path. *"What must this executor write, per its instructions?"* surfaces the
docs directory immediately; *"what has broken so far?"* never does. Doing this derivation
once surfaced `~/.pub-cache` (`pub get`) and `~/.gradle` + `~/.android` (APK build) before
anyone tripped them.

**The shape that predicts the next one:** both traps are operations that write somewhere
nobody thinks of as "outside the worktree" — an SDK cache lockfile, a `$HOME` telemetry
file, a linked worktree's real git dir — and both **fail late**. `dart analyze` passes,
edits apply, tests can be authored, and then the first *outward-reaching* action dies. A
lane running only analysis looks green right up until it tests or commits. When adding any
new sandboxed operation, ask what it writes outside the workspace and test the
outward-reaching action early instead of inferring health from analysis.

**Companion lesson:** cap-driven kills (exit 144) on long multi-step runs should be fixed
by **chunking**, not by raising the timeout — chunking additionally buys a file-fence
check at each chunk boundary, which a single long run cannot give you. For a lane with a
large file set or an active tripwire, chunked execution is the default, not the recovery.
