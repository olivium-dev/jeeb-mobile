---
name: negative-control-before-fake-time-evidence
description: A fake-time test only counts as merge evidence after it is shown capable of failing — named mutation, named test, expected RED reason, plus hash-verified revert; "tests pass" alone is rejected
metadata:
  type: feedback
---

Any fake-time / timing test offered as merge evidence must first be proven **capable
of failing**. The accepted procedure is **named mutation → named test → expected RED
reason**: each mutation names its single definition site, the exact test it must turn
red, and *why* that test should fail — stated in advance. If the test goes red for a
different reason than predicted, the test is not measuring what its author thinks, and
that is itself a finding.

**Revert safety:** clean-tree precondition → `git hash-object <target>` → hand-edit →
`git diff -- "$TARGET" > patch` and **assert the patch is NON-EMPTY** → run the named
test with `--plain-name`, confirm RED → `git apply -R patch` → re-hash and assert
equality → assert `git status --porcelain` empty and `git diff --quiet` exit 0. One
mutation at a time. Patch file, never `git stash` — a patch is attachable as evidence.

**The evidence contract (all five, or refuse):** named test · `file:line` of the
mutation · the actual diff · the actual RED output · both-hashes-equal revert proof.
**"Tests pass" alone is explicitly rejected.**

**Why:** owner/Lane-Governor ruling during b02-20260726, generalized from FM-5's
guardrail. The rejection clause is the load-bearing part — it converts "write good
negative controls" from an instruction a lane can nod at into something a QA reviewer
can refuse a lane for, with no judgment call. The non-empty-patch assertion is equally
load-bearing: a mutation that silently fails to apply yields a GREEN test
indistinguishable from a passing negative control — the exact failure this procedure
exists to catch, reproduced inside the procedure itself.

**A recorded mutation is a POINTER, and pointers rot.** The ledger entry names the
specific test the mutation proved could go red. Rename that test — even mechanically, even
to improve it — and the entry points at nothing, while the evidence still READS as valid.
A rename must update every ledger entry citing the old name **in the same commit**. Capture
a clean baseline of ledger→test resolution BEFORE any bulk rename, so a dangle introduced
by it is attributable rather than discovered later with no known-good state to compare to.

**When binding criteria to tests, bind on the BODY, never the existing name** — a test whose
name and body disagree will launder that lie into a coverage claim. And **pre-declare the
known-untested criteria to the executor**: naming the expected gaps in advance removes the
incentive to invent plausible bindings under pressure to make the number look good. A green
check bought with a false binding is strictly worse than an honest INCONCLUSIVE — it converts
"unverifiable" into "verified" while proving nothing, and buries the thing the exercise
exists to expose.

**How to apply:** require a dry run (harness mechanics, no mutation, zero residue)
once per lane before its first real mutation, then the five-row contract per test.
Check residue with `--untracked-files=all`: plain `git status --porcelain` ignores
empty directories, so a tool can leave a stray path while truthfully reporting "clean"
— that bug was found in the harness itself during b02's dry run. Harness:
`docs/batches/b02-20260726/tools/r14-mutation-harness.sh`. Related:
[[dart-implements-widening-trap]], [[shared-wiring-files-are-the-collision-surface]].
