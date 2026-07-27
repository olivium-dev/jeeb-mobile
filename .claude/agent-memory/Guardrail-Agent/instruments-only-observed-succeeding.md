---
name: instruments-only-observed-succeeding
description: An instrument that has only ever been observed succeeding is unproven — ask of every check "what non-code condition could produce this result?"; four separate verification tools lied in one batch
metadata:
  type: feedback
---

**An instrument that has only ever been observed succeeding is unproven.** Before
trusting any check, ask two questions: *how would I know if this were lying?* and
*what non-code condition could produce this result?*

Four instrument failures in a single batch (b02-20260726), all in verification tooling
I or a lane had just built and believed:

| # | Instrument | How it lied | Fix |
|---|---|---|---|
| 1 | mutation application | a silently-unapplied mutation yields a green indistinguishable from a passing negative control | assert the diff patch is NON-EMPTY |
| 2 | residue check | `git status --porcelain` reported "clean" because **git ignores empty directories** | `--untracked-files=all` |
| 3 | RED detection | `flutter test --plain-name "<typo>"` exits non-zero when it matches **nothing**, reading as RED | positive control: require PASS on a clean tree; parse output for a zero-match signature, never trust the exit code |
| 4 | RED detection again | `flutter test` under `codex exec --sandbox workspace-write` exits **255** on a Flutter-cache/telemetry write denial — scored as RED | same positive control catches it; a denied environment can't produce a green PC either |

Note that #3 and #4 are the *same* defect reached from two unrelated directions — a
typo and an environment denial — and **neither involves the code under test**. That is
the general argument for **requiring a positive result rather than trusting an exit code
in either direction**.

A related trap: a ranking/bucketing scanner whose top bucket is silently always empty.
Mine read a per-file dict *after* the walk finished, so it only ever saw the last file
and hid the highest-signal finding entirely. And a scanner that fires on prose mentions
buries its real hits — "armed and quiet" must be readable as a state.

| 7 | ADR-005 marker check | searched the WHOLE diff for any capability marker, so **one marker anywhere satisfied every action in the commit** | scope to the action's own attribute block (verb → its method declaration), never a fixed ±N window — that borrows the previous action's marker |

| 8 | append-only numstat check | `git diff --numstat origin/main...HEAD` returned **empty** — not "0 deletions" — because the lanes worked **uncommitted** (no sandbox grant to commit). Reported "append-only holds" on a measurement it could not see | run **both** `diff --numstat HEAD` (working tree) and the committed form |

| 9 | absence/presence pairing check | passed a **vacuous** test: both polarities were asserted, but the subject was silently restored between them, so a genuine fail-closed mutation left it green | pairing is necessary, not sufficient — every pair must additionally pass a mutation |

| 10 | absence/presence pairing (see #9) | — |
| 11 | **the R14 mutation harness itself, again** | ran `flutter test --plain-name X` with **no test-file argument**, loading all 377 test files; the mutated run died in discovery before matching, so every bundle ended in the harness's own "FALSE RED — matched ZERO tests". Voided an entire lane's 7 negative controls | pass the test FILE before `--plain-name`; make it a required arg that fails fast |

**#11 is the sharpest irony in the set: R14's own failure mode — a confident RED that proves
nothing — manufactured by the R14 apparatus itself, for the second time** (#3 was a fake RED from
a typo'd name; #11 a fake RED from an unscoped runner). Same worthless output, different cause.
**A verification tool is not exempt from the failure class it was built to detect — it is a
prime candidate for it.** Also note what saved it: the zero-match detector added in #3 is the
only reason #11 surfaced instead of banking six passes proving nothing. **Never weaken a
detector while fixing the thing it caught.**

**A failed mutation has TWO causes — do not default to blaming the test.** Either the test is
vacuous, or **the mutation is faulty** (overwritten before the assertion, reset, wrong site,
never reached). Verify the mutation is live at the moment the assertion runs *before* weakening
confidence in the test. Blaming the test by default is the more destructive error: it discards a
working proof and propagates a false warning downstream. This happened — a test was declared
vacuous, two downstream lanes were warned off a sound guarantee, and the re-run showed the
mutation was at fault. **A failed mutation is evidence about the PAIR (test, mutation), not
about the test alone.**

| 12 | batch gate's lane→worktree map | pointed at a QUARANTINED tree and a NONEXISTENT one; absent path silently no-opped, so two lanes got no checks at all and the gate still printed PASS | preflight: mapped-but-absent is fatal, unmapped live lane is fatal, and print resolved path + HEAD SHA beside every verdict |

**An UNASKED check leaves no failure trace.** #12's worst property was not that a rule failed —
it was never asked the question, so there was nothing in any log to notice. **A gate that cannot
tell you WHAT IT INSPECTED cannot be audited.** Always emit the resolved subject (path + SHA)
alongside the verdict; a PASS with no named subject is unfalsifiable. Related trap: a *branch*
name is not a *path* — that substitution is what produced the nonexistent directory.

**Over-reporting now costs the same as under-reporting.** After a dozen genuine instrument
defects the reflex to file a thirteenth gets strong; one lane nearly filed a false one when `$?`
after `| tail` reported *tail's* status rather than the tool's. It checked, found its own pipe
artifact, and recorded the negative result. **A false instrument-defect report costs the same
credibility as a missed one** — verify the measurement apparatus before filing against the
subject.

**The stable generalization: structural checks confirm SHAPE; only mutation confirms POWER.**
Reading the test body — my own correction to "don't trust the scan" — is still structural, and
#9 defeated it. The ladder is: count → read → mutate. Only the last rung proves a test can fail.

Corollary for enumeration-style checks: enumerating declared criteria against test names catches
**missing** tests; only mutation catches **present-but-vacuous** ones. They are complementary, and
the enumeration table is far cheaper to produce — so it silently displaces the mutation work
unless the complementarity is stated explicitly on every sign-off.

#8 is the sharpest instance: a check can be blind rather than wrong, and blindness reads as a
clean pass. Always ask *could this check have failed on this input at all?* — and note it was
caught only because an independent-verifier rule forced a re-run instead of accepting a report.

#7 was found by *acting on* the base-rate argument rather than restating it: the first
previously-unchecked instrument tested was defective. Note also that the first fix for #7
was itself wrong — a symmetric ±6-line window still passed the planted case.

**How to apply:** when building any verification tool, construct a case where it MUST
fail and confirm it does, before trusting a pass. Keep the planted cases as a runnable
self-test, not a one-off — they catch the fix that is itself wrong.

**A correction is an unproven instrument too.** Make the self-test a standing gate with
three rules: (1) any change to a detection rule re-runs the suite — editing a regex or a
scoping window is editing an instrument; (2) a new check and its planted pair land in the
**same commit**, never separately, for the same reason a mutation and its named test must
not; (3) no sign-off may rely on a check that has not passed both directions. A one-time
audit would have recorded "defect found and fixed" and shipped a still-broken check. Prefer a positive control (prove the
instrument can see a success) plus a negative control (prove it can see a failure) over
either alone. Related: [[negative-control-before-fake-time-evidence]],
[[lineage-gate-before-any-deploy]].
