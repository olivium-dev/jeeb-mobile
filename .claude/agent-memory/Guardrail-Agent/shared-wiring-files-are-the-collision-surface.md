---
name: shared-wiring-files-are-the-collision-surface
description: In multi-lane worktree batches, per-feature file fences miss the shared wiring files (injection_container.dart, app.dart, push_notification_handler.dart, Program.cs) — those are where lanes actually collide
metadata:
  type: project
---

In a parallel-lane delivery batch (b01/b02 style, one git worktree per feature lane), the
per-feature scope fences written into planning briefs consistently fence *feature* directories
and forget the **shared wiring files that every lane must touch to register anything**:

- mobile: `lib/core/di/injection_container.dart`, `lib/app/app.dart`,
  `lib/core/notifications/application/push_notification_handler.dart`, `lib/main.dart`, `pubspec.yaml`
- gateway: `src/JeebGateway/Program.cs`

These have no natural feature owner, so the first lane to commit one silently wins and every
later lane hits a conflict at integration.

**Why:** observed in b02-20260726 sweep 1 (2026-07-26). FM-2 (a lane the manifest had *deferred*
to Wave B) committed a `ChatMessageSignals` registration into `injection_container.dart` — a file
FM-3's brief claimed exclusively and FM-5's brief explicitly forbade. FM-3 had zero commits, so
the conflict was still latent and cheap to fix. FM-2 also took `app.dart` and
`push_notification_handler.dart`, both of which FM-1's undeclared inbox lane needed next.
Full write-up: `docs/batches/b02-20260726/GUARDRAIL-FINDINGS.md` (GF-01..GF-05).

**Resolution that worked (Lane Governor R4, 2026-07-26):** not a hard fence — a published
**primary-owner map** for each wiring file plus an **append-only exception** for non-owners
(zero deletions, zero reordering, declared in the lane's execution log), enforced mechanically by
`git diff --numstat` (deletions column must be 0). Rationale: these are registration manifests,
not logic, so additive lines merge trivially and a hard fence would serialize every lane for no
safety gain. A consequence to watch: R4 reassigned `app.dart` to FM-3 *after* FM-3's own planning
brief had excluded it — a later Lane Governor ruling outranks an earlier feature brief, so
re-read `MANIFEST.md` before trusting a brief's file fence.

**How to apply:** when defining lanes for a batch, publish the ownership map for the shared
wiring files *first*, before any per-feature fence — every lane needs one of them, so leaving
them unassigned guarantees a collision. Two mechanical checks catch it early:
`git -C <wt> diff --name-only origin/main...HEAD` per lane plus a pairwise intersection, and
"is every declared-deferred lane's worktree actually empty?" — a deferred lane running is what
produced the collision here, not a lane misreading its fence. Detector kept at
`docs/batches/b02-20260726/tools/collision-check.py`; it generalizes by editing its LANES/OWNED tables.
