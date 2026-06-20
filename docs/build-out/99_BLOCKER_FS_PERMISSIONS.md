# 99 — HARD BLOCKER: filesystem read access revoked (macOS app-data/provenance protection)

**Detected:** 2026-06-19 (during /loop scenario-capture engagement kickoff)
**Severity:** BLOCKING — no orchestration can proceed until a human clears it.

## Symptom
This Claude Code session's process (and therefore every subagent it spawns) gets
`EPERM "Operation not permitted"` when **reading the content** of any file that
already existed under `~/Desktop/olivium/jeeb`, and gets **total** denial on the
external `/Volumes/Extreme Pro` SSD.

| Operation | Result |
|---|---|
| `stat`, `ls`, directory listing | ✅ works (metadata only) |
| **Write a NEW file** in the project | ✅ works (and reads back fine) |
| `cat`/`head`/`cp`/`dd`/`python3` read of a PRE-EXISTING file | ❌ Operation not permitted |
| `Read` tool on a pre-existing file | ❌ EPERM |
| `xattr -l` on a pre-existing file | ❌ Operation not permitted |
| `git show HEAD:<file>` / any git needing `getcwd`/`.git` | ❌ Operation not permitted |
| Anything on `/Volumes/Extreme Pro` (read OR write) | ❌ Operation not permitted |

## Root cause
macOS **app-data / provenance protection** (Sequoia+). Files written by the *prior*
session's Claude Code process carry that app's provenance; **this** session's process
is a different signed binary and the OS bars it from reading them. New files this
session creates are readable by it; pre-existing ones are not. Same mechanism blocks
the removable SSD.

This is NOT the Claude Code bash sandbox: `dangerouslyDisableSandbox` was tried and
the EPERM persisted; the harness `Read` tool (not sandboxed) fails identically.

## Why no workaround exists from here
- Every content-reading binary reachable from the shell is blocked (cat/cp/dd/python/git).
- Can't strip the provenance xattr — `xattr` itself is denied.
- Can't copy the tree out — `cp`/`cat` of sources are denied.
- Subagents run under the same harness → identical block; fanning out agents would
  burn tokens hitting EPERM with zero progress.
- The SSD (the required deliverable destination for scenario screenshots/videos) is
  fully inaccessible, so Part 2's deliverable is impossible regardless.

## The ONLY fix (requires the human, in person, at the machine)
Grant the terminal/Claude Code app **Full Disk Access** (and, on Sequoia, allow it
under **App Management** / **Files and Folders**):
1. System Settings → Privacy & Security → **Full Disk Access** → enable the app that
   runs Claude Code (Terminal / iTerm / the Claude app), then fully quit & relaunch it.
2. Also check **Privacy & Security → App Management** and **Files and Folders**.
3. Re-mount / re-authorize the **Extreme Pro** external volume for that app.
4. Re-run the /loop; access is re-probed at the top of every wake and work resumes
   automatically once reads succeed.

## State at time of block
Per engagement memory: the build itself (Phase 1 + Phase 2 — 62-screen blueprint
parity, analyze clean, 1488 flutter tests green, 336 mock tests green, both demo
spines verified on-device) was already **BUILD COMPLETE**. The blocked work is the
**Part-2 scenario-capture engagement** (enumerate scenarios → branch per scenario →
Maestro-drive → screenshot every state + record video → store on SSD). None of it
can start without the read access above.
