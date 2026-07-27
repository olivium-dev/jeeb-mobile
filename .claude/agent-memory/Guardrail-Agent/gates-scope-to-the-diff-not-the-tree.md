---
name: gates-scope-to-the-diff-not-the-tree
description: Quality gates must evaluate the lane's diff, not the whole tree — a gate that blocks every lane on inherited state gets waived wholesale and then fails when it finally matters
metadata:
  type: feedback
---

**Quality gates evaluate the LANE'S DIFF (`git diff origin/main...HEAD`), not the tree.
Inherited findings are REPORTED, never BLOCKING. A lane is blocked only by what its own
changes introduce.**

**Why:** in b02-20260726 my `collision-check.py` scanned whole worktrees. A lane that had
changed **zero files** halted at its mandatory gate with "48 findings, 6 blocking" — the
blocker being inherited `origin/main` content the lane never created and was explicitly
forbidden to edit. Every other lane would have burned a run on the same thing.

The false positive is not the real damage. **A gate that blocks every lane on pre-existing
state trains lanes to treat it as noise and waive it wholesale — strictly worse than no
gate, because it then fails exactly when it finally reports something real.** Mechanical
enforcement earns its authority by being right about *who is responsible*.

**Three classes, kept explicit in the output, each carrying the git evidence that
classifies it:**
- **LANE-INTRODUCED** — in the lane's diff → BLOCKING, non-zero exit
- **DEPLOY GATE** — inherited but unsafe to ship (e.g. a lineage/ancestry failure) →
  blocks the *deploy*, not the lane. Without this middle class, a strict diff-scoped rule
  would stop gating a genuinely dangerous inherited condition.
- **INHERITED** — present at `origin/main` → REPORTED only

**How to apply:** when a gate fires, first ask *did this lane introduce it?* If not, it is
reporting, not blocking. Keep any escalation clause intact by discriminating **invoking** a
forbidden thing from **describing** it — require an invocation shape (`bash …`, `./…`,
`source …`, `$(…)`) rather than a prose match; adding stop-words is whack-a-mole and
eventually buries the real hit. Then prove the gate can still fail: inject the violation,
confirm it blocks, remove it, confirm it passes. See
[[instruments-only-observed-succeeding]] — this was the sixth instrument in one batch that
needed correcting once actually checked.
