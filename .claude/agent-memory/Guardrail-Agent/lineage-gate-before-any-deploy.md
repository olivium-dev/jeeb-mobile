---
name: lineage-gate-before-any-deploy
description: Never deploy without `git merge-base --is-ancestor <deployed-sha> <candidate-sha>` passing — health checks prove a build runs, only ancestry proves it is not a regression
metadata:
  type: feedback
---

**No deploy candidate ships without `git merge-base --is-ancestor <currently-deployed-sha>
<candidate-sha>` passing.** Non-zero exit means the candidate is missing code that is
currently running, and deploying it silently regresses the service.

> **Health checks prove a build RUNS. Only ancestry proves it is not a REGRESSION.**

A `health=200` / `unauth=401` deploy gate **cannot** detect this: a regressed build is
perfectly healthy, it is merely old, and it passes every smoke test — which is exactly
what makes it dangerous. Only forward candidates descended from the deployed SHA are
eligible; predecessor deployment targets are forbidden.

Read the deployed SHA **from the live host**, never inferred from a branch name.

**Why:** this has now bitten the Jeeb fleet twice. In b01, MSI ran chat-service `a1012c0`
— not an ancestor of `origin/main` — two shipped fixes were never deployed and nobody
noticed until a jeeber could not see customer messages (one-way-chat P0). In b02 the same
shape appeared in jeeb-gateway: every b02 gateway lane sat 21 device-verified commits
behind deployed `d883dfd` (including a P0 chat-payload fix and the whole P7 offer-wait
contract), because b02 branched off `origin/main` while the deployed code lived on an
unmerged `batch/b01-*` branch. A predecessor target was also incorrectly considered.

**Count with `git rev-list --count A..B`, never `git log --oneline A..B | wc -l`.** They
disagree: `git log` applies default history simplification and drops merge commits. On the
b02 gap they returned 14 vs the true 21 (14 non-merge + 7 merges) — an under-report of a
third of the blast radius. Both are real numbers with different denominators; "how many
commits am I missing" is the total, so `rev-list --count` is the instrument. Report both
figures so the discrepancy can never be re-litigated.

**How to apply:** run the check before every deploy and paste its output into the deploy
record — no output, no deploy. Bind it on whoever actually deploys (the integration
orchestrator), not only on feature lanes, since integration is where deploys happen. Flag
any `docker service update` / `systemctl restart` / symlink-swap / deploy-script
invocation that appears without an accompanying ancestry check. Watch for the structural
version of this bug: when a batch branches off `main` but the deployed code lives on an
unmerged branch, **every** lane in that batch inherits the defect, so check all of them
rather than the one whose planner happened to notice. Detector:
`docs/batches/b02-20260726/tools/collision-check.py` (G15). Related:
[[negative-control-before-fake-time-evidence]].
