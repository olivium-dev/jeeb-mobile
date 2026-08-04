# Wiring requests — 12 · Live tracking

> Status note (written at implementation time, 2026-08-03): the five
> `cross-feature` kit requests below were authored **before Wave 1 shipped**.
> Every one of them was verified present in the shipped kit
> (`lib/core/widgets/jeeb/`) while implementing this screen, so they are
> recorded as **ALREADY SATISFIED — no integrator action**. They are kept
> verbatim because §G of the instruction set requires them on the record and
> because they document exactly which kit affordances screen 12 depends on.
>
> **The only OPEN request is the `l10n` batch.**

---

### l10n

file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb (+ AppLocalizations getters)
need: Seven tracking-redesign strings; feature-local stopgap `live_tracking_l10n.dart` carries them until this lands, then the stopgap getters swap to these keys.
exact change:
```
  app_en.arb:
    "trackingArrivingIn": "Arriving in {minutes} min",
    "@trackingArrivingIn": {"description": "Floating ETA pill on the live-tracking map (screen 12).", "placeholders": {"minutes": {"type": "int"}}},
    "trackingCourierOnTheWay": "{name} is on the way",
    "@trackingCourierOnTheWay": {"description": "Courier-card title on live tracking.", "placeholders": {"name": {"type": "String"}}},
    "trackingCashOnDelivery": "{amount} cash on delivery",
    "@trackingCashOnDelivery": {"description": "Courier-card subtitle money qualifier (D11 — customer-facing, no commission).", "placeholders": {"amount": {"type": "String"}}},
    "trackingDoorCodeNote": "Door code — share only at handoff",
    "@trackingDoorCodeNote": {"description": "Door-code strip label on live tracking."},
    "trackingCashShort": "cash",
    "@trackingCashShort": {"description": "Short cash qualifier in the tracking top-bar meta line; screen readers get summaryCashLabel instead."},
    "trackingNoShowCta": "Report no-show",
    "@trackingNoShowCta": {"description": "Tracking footer start action (board copy)."},
    "trackingDisputeCta": "Open dispute",
    "@trackingDisputeCta": {"description": "Tracking footer end action (board copy)."}
  app_ar.arb:
    "trackingArrivingIn": "الوصول خلال {minutes} دقيقة",
    "trackingCourierOnTheWay": "{name} في الطريق",
    "trackingCashOnDelivery": "{amount} نقداً عند التسليم",
    "trackingDoorCodeNote": "رمز الباب — شاركه عند التسليم فقط",
    "trackingCashShort": "نقداً",
    "trackingNoShowCta": "الإبلاغ عن عدم الحضور",
    "trackingDisputeCta": "فتح نزاع"
```
why: Board copy for the pill, courier card, door-code strip and footer; screen 12 compiles today off the LiveTrackingL10n stopgap and swaps call-sites when these land.

call sites to re-point when the keys land (all in `lib/features/live_tracking/presentation/`):
`live_tracking_l10n.dart` — `arrivingIn` · `courierOnTheWay` · `cashOnDelivery` · `doorCodeNote` · `cashShort` · `disputeCta` · `noShowCta`. Every consumer already reads them through `LiveTrackingL10n`, so the swap is inside that one file.

---

### cross-feature — ALREADY SATISFIED (verified in the shipped kit)

file: lib/core/widgets/jeeb/jeeb_top_bar.dart
need: Screen 12 needs the two-line variant with (a) `identifier` params on leading AND trailing actions, (b) a `subtitle` WIDGET slot (its subtitle is four semantics leaves, not one Text), (c) the two-line title at `jeebText.titleProminent` 17/w700 per the plan's own typography table (00-MIGRATION-PLAN.md:215), not h2 scaled down.
exact change: `JeebTopBar({required JeebTopBarLeading leading, String? leadingIdentifier, VoidCallback? onLeadingTap, required Widget title, Widget? subtitle, JeebTopBarAction? trailing})` with `JeebTopBarAction({required Widget icon, required String identifier, required VoidCallback onTap})`.
why: 12's header carries `tracking_back` + `order_summary_open_chat` on the circles and five pinned semantics leaves in the subtitle line.
**shipped as:** `JeebTopBar.back(identifier:, onLeadingPressed:, title:, titleScale: JeebTopBarTitleScale.compact, subtitleSlot:, trailing: JeebTopBarAction(icon:, onPressed:, identifier:, semanticLabel:))`. Consumed unchanged.

---

### cross-feature — ALREADY SATISFIED (verified in the shipped kit)

file: lib/core/widgets/jeeb/jeeb_stepper.dart
need: Per-node semantics contract + a pulse flag. Each node must emit `Semantics(identifier: stepIdentifiers[i], container: true, selected: isActive, value: labels[i])` — `tracking_lifecycle_bodies_test.dart` d/e reads `node.value` and `node.identifier` and is the acceptance gate. Active-node pulse (`pulseActive`) animates the `JeebShadows.stepGlow` spread only, must respect `MediaQuery.disableAnimationsOf(context)`, and callers disable it on the terminal step.
exact change: `JeebStepper({required int currentIndex, required List<String> labels, required List<String> stepIdentifiers, bool pulseActive = false})`; plain `Row` (auto-RTL), no Stack offsets.
why: Screen 12's `OrderTrackingStepper` becomes a thin wrapper; the four `tracking_step_*` ids and the P6/A5 At-Door relabel ride this contract.
**shipped as:** exactly that signature (+ optional `identifier`/`semanticLabel`, which 12 deliberately omits so `tracking_stepper` stays the screen's own node). Consumed unchanged.

---

### cross-feature — ALREADY SATISFIED (verified in the shipped kit)

file: lib/core/widgets/jeeb/jeeb_info_note.dart
need: `onTap` + a trailing WIDGET slot on the `muted` tone. 12's door-code strip is tappable (routes to `/orders/{id}/otp`) and its trailing is either `JeebCodeCells.strip` or a keyed CTA Text.
exact change: `JeebInfoNote({required JeebInfoNoteTone tone, required Widget leading, required Widget label, Widget? trailing, VoidCallback? onTap})` — when `onTap != null` wrap in Material/InkWell with the note's own radius.
why: The plan (§5 #22) already names 12 as the "trailing value: 2 1 4 4" consumer; without onTap the row loses its only unconditional route to the OTP screen (the 2026-07-31 P0).
**shipped as:** `JeebInfoNote.muted(icon:, iconSize:, iconColor:, label:, trailing:, gap:, onTap:)` — the note adds NO semantics node when `identifier` is omitted, which is what keeps 12's own `tracking_handover_code_row` node the only one. Consumed unchanged.

---

### cross-feature — ALREADY SATISFIED (verified in the shipped kit)

file: lib/core/widgets/jeeb/jeeb_code_cells.dart
need: The `strip` variant must render the code as ONE `Text` (no per-character widgets) inside an LTR isolate and forward a `key` to that Text.
exact change: `JeebCodeCells.strip(String code, {Key? textKey})` → one `Text(code, key: textKey)` at 20/w800/ls5.
why: `live_tracking_handover_code_test.dart:189/219` does `find.byKey(Key('tracking.codeRowValue'))` and `find.text('1234')` — per-digit splitting breaks both.
**shipped as:** `JeebCodeCells.strip(value, {Key? textKey, String? identifier, String? semanticLabel})`. Consumed unchanged.

---

### cross-feature — ALREADY SATISFIED (verified in the shipped kit)

file: lib/core/widgets/jeeb/jeeb_tier_chip.dart
need: The tier→emoji lexicon exposed as a static so non-chip consumers stay centralised (§9-Q7). Screen 12 draws `⚡ Flash` as PLAIN TEXT (12-live-tracking.html:19), not a pill — it consumes only the emoji.
exact change: `static String emojiFor(String tierId)` (returns '' for unknown ids).
why: 12's top-bar meta line renders the emoji inline; duplicating the lexicon in the feature would fork it.
**shipped as:** `static String emojiFor(String? tierId) => JeebTier.fromId(tierId).emoji;`. Consumed unchanged.
