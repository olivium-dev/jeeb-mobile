---
name: dart-implements-widening-trap
description: In jeeb-mobile, repository interfaces are `implements`-based with 60+ having 3+ implementors — adding one member breaks every site at once, including devtool catalog files outside any lane's fence
metadata:
  type: project
---

`jeeb-mobile` expresses essentially every repository interface via Dart `implements`
(not `extends`). Dart `implements` demands re-implementation of **every** member, so
adding a single method to a shared interface breaks **every** implementor
simultaneously — a hard compile break, not a subtle regression.

A census of `lib/` + `test/` finds **60+ interfaces with ≥3 `implements` sites**
(`LiveTrackingRepository` 12, `RatingRepository` 11, `NotificationsRepository` 9,
`RequestFeedRepository` 9, `OffersRepository` 8, `ActiveDeliveriesRepository` 8, …).

**The compounding factor:** `lib/devtool/catalog/entries/batch_*.dart` is a systematic
implementor of these interfaces — `batch_05_entries.dart:376,402,430` implement
`RequestFeedRepository`; `batch_07_entries.dart:104,116,127` implement
`NotificationsRepository`. In a fenced multi-lane batch the devtool catalog is
outside **every** lane's fence, so a lane that widens an interface breaks files it
cannot legally edit and has no in-fence fix for.

**Why:** found in b02-20260726 while checking FM-3's lifecycle contract. FM-3 reasoned
its way to the answer; FM-1 had the identical exposure on `NotificationsRepository`
and no reason to look — its "durable inbox" work (read-state, persistence, delivery
status) is exactly the shape that wants new interface members.

**How to apply:** before adding any member to a shared interface, enumerate its
`implements` sites across `lib/` and `test/` and check whether any fall outside the
editable fence. If yes, express the new capability as a **separate opt-in
mixin/interface** rather than widening the existing one. Tool:
`docs/batches/b02-20260726/tools/interface-widening-check.py <worktree> <Interface>
<fence-prefix>...` — exit 1 means blocked; run with no interface name for the census.
Related: [[shared-wiring-files-are-the-collision-surface]] — same failure family
(shared surfaces that per-feature fences don't cover).
