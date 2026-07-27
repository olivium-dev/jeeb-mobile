---
name: verifier-must-not-share-executor-sandbox
description: Run gate/fence checks from a shell that does NOT share the executor's sandbox — if the verifier shares grants, binary and sandbox with the thing it checks, whatever blinds the executor blinds the check
metadata:
  type: feedback
---

**A lane's fence and gate results are acceptable only if produced by a verifier that does not
share the executor's sandbox.** Run the checks from your own unsandboxed shell rather than
trusting the executor's self-report. The execution log must show **who ran each gate**; a
result with no named runner, or one produced inside the executor's own sandbox, is not
evidence.

**Why this is different in kind from "test the instrument harder."** Instrument defects can
be fixed by adversarial testing. A *shared blind spot* cannot: if the verifier runs inside
the same sandbox, under the same grants, through the same binary as the thing it checks,
then whatever blinds the executor blinds the check too — and testing that check more
aggressively does not help, because the failure is shared rather than internal. Proof from
b02-20260726: a Codex sandbox denial (`flutter test` → exit 255) was read as a *passing
negative control*, because the harness treated any non-zero exit as RED and ran in the same
sandbox that produced the denial. **An instrument that shares the executor's blind spots
must be moved, not hardened.** This is "the auditor is never the executor" extended to
tooling.

**The payoff is where the failure lands:** with an independent verifier, a missing sandbox
grant costs the *verification*, not the *work* — files persist on disk and the orchestrator
re-verifies. With a shared one, the missing grant kills the run.

**Companion rule — a sandbox denial is REPORTED, never routed around.** This belongs in the
executor contract, not the tooling notes: it governs agent behaviour. An agent that
improvises around a denial destroys the signal and leaves the orchestrator unable to tell a
real failure from an environment one — and the workaround usually succeeds at something
*adjacent*, so the run still looks complete. Forbidden: copying files out of the worktree to
commit elsewhere, `--no-verify`, swapping binaries, writing to a temp path "just to get
past it", silently skipping the step. Required: stop, report the exact denial text and the
operation attempted, wait for a grant. Observed cost of stopping correctly: zero.

**How to apply:** for any append-only grant, require the `git diff --numstat` (column 2 == 0)
rather than an assertion that nothing was deleted — a lane saying "I only added lines" is a
self-report; the numstat is a measurement, and per this rule the verifier runs it. Related:
[[instruments-only-observed-succeeding]], [[flutter-test-codex-sandbox-add-dir]],
[[gates-scope-to-the-diff-not-the-tree]].
