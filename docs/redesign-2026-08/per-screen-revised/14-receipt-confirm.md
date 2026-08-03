# 14 · Receipt confirm — REVISED instruction set (authoritative)

**Screen id:** `14-receipt-confirm`
**Verdict:** `rebuild` (confirmed — app bar deleted, `ListView` → sliver column with a real spacer,
cash line recolored peach → navy, one new modal viewer)
**Target file:** `lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart`
**New files:** `lib/features/delivery_receipt/presentation/widgets/proof_photo_hero.dart`,
`lib/features/delivery_receipt/presentation/widgets/proof_photo_viewer.dart`,
`test/features/delivery_receipt/delivery_receipt_screen_test.dart`
**Wave:** 2. **Blocked on:** Wave-1 `JeebCtaButton` (`lib/core/widgets/jeeb/` does not exist yet)
and the l10n wiring batch below. Write the code as if both are granted.

Every claim below was re-verified against the render, the HTML (`dc-tpl 827–850`), the note, the
current source, the Wave-0 theme files, OMDS, the Maestro flows and the gate scripts on 2026-08-03.
Where this document disagrees with the original proposal, this document wins.

---

## 1. Review verdicts on the original proposal

### Verified correct (kept)
- All structural claims: no top bar anywhere in the render; the truck icon is not in the design;
  the body is `column → content → flex:1 → footer` (`dc-tpl 845` is a bare `flex:1` div;
  `dc-tpl 846` pads the footer `0/24/32`).
- The cash card is navy `var(--jeeb-navy)` r16 with `0 10 24 rgba(11,19,81,.28)` — byte-identical
  to `JeebShadows.ctaNavy`. Today's card is `primaryContainer` = `#FFDBD1` peach
  (`app_theme.dart`, `_jeebOrangeContainer`), so this is a real color-family change.
- `mutedText` `#777FC0` on navy is 4.55:1 — recomputed, passes AA for the 12px/w600 sub-line.
- The proof timestamp (`· 9:38`) is a genuine data gap: `_parseReceipt`
  (`dio_delivery_receipt_repository.dart:132–154`) reads no capture time and `DeliveryReceipt`
  has no field. Ship the badge as `Proof of delivery` only. Never substitute `DateTime.now()`.
- **K1 refusal stands and is fully evidenced:** plan §5 #24 and 02-PLAN-ENHANCED §3.2 list 14 as a
  `JeebMoneyBreakdown` consumer; the note ("Deliberately no commission line"), Maestro
  `jm-033` `assertNotVisible: receipt_no_commission_line`, and three doc comments in the current
  file all forbid it. **14 is NOT a `JeebMoneyBreakdown` consumer.**
- No new route for the viewer (modal on the local `Navigator`); no DI change; no pubspec change.
  `InteractiveViewer` is core Flutter, zero prior usage in `lib/` — allowed.
- All six existing Semantics identifiers and their Maestro consumers check out exactly
  (`jm-033`, `jm-032:81`, `jm-034:47,51,141,145`).
- `MoneyFormat.format` wraps results in U+2066…U+2069, so the `indexOf`-split `Text.rich`
  emphasis is locale- and RTL-safe as claimed.
- The l10n copy table (§4 below) matches the arb files as they exist today.

### Corrected (the proposal was wrong)
1. **`Spacing.threeXSmall` does not exist** — it would not compile. The 2px gap under the cash
   line is `Sizes.threeXSmall` (2.0, `omds .../tokens/spacing.dart:43`).
2. **Scroll posture was self-contradictory** (footer inside the sliver in one section, outside the
   scroll in another). Resolved: ONE `CustomScrollView` with ONE
   `SliverFillRemaining(hasScrollBody: false)` holding the whole column, footer included.
   At default scale the footer reads as docked; at 200% text scale everything scrolls. Use
   `const Spacer()`, not `Expanded(SizedBox.shrink())`.
3. **The viewer barrier may not be `Colors.black`** — `tool/check_design_tokens.sh` bans
   `Colors.<name>` in `lib/features/`. Use `Theme.of(context).colorScheme.scrim`.
4. Minor line cites: `Icons.payments_outlined` is at `:272` (not `:271`); the first
   `onPrimaryContainer` ink is at `:273`.
5. **`OMDSOutlinedButton` cannot build the outline CTA at all** — verified: despite the name it
   draws NO border (filled `secondaryContainer` box, no height param). The board's transparent
   1.5px-outline pill therefore requires `JeebCtaButton.outline` from the Wave-1 kit. This
   strengthens the kit dependency; there is no OMDS fallback for the outline pill.
6. "The AR already reads exactly this" (re `receiptConfirmCta`) is overstated — `نعم، استلمته` is
   "Yes, I received it" — but the conclusion is right: leave the AR value unchanged.

### Cut (scope creep / churn — do NOT do these)
1. **`JeebCtaFooter` `stack` form wiring request — CUT.** A named kit form for a single consumer
   contradicts the proposal's own §3 logic. Compose the footer locally: a `Column` of two
   `JeebCtaButton`s with a `Spacing.small` gap. If a second vertical-pair screen appears later,
   the kit owner can lift it then.
2. **Optional `letterSpacing: -0.5` on the heading — CUT.** Plain `context.jeebText.h1` (R3: do
   not drift the ramp for 1px).
3. **`EdgeInsets.all` → `EdgeInsetsDirectional.symmetric` churn on the cash card — CUT.**
   `EdgeInsets.all(Spacing.medium)` is direction-neutral and gate-clean. Keep it.
4. **`JeebNavySurfaceCard` "optional if Wave 1 lands first" — CUT the ambiguity.** Build the cash
   card as a local `Container` with the three tokens (`primary` fill, `OmdsBorderRadius.medium`,
   `JeebShadows.ctaNavy`). One card does not justify a kit dependency.
5. The "for the record" route sketch for an addressable viewer — dropped entirely.

---

## 2. Guardrails (hard, checked at review)

1. **Semantics identifiers — all preserved, spelled identically:** `receipt_prompt` (root,
   `explicitChildNodes: true`), `receipt_cash_to_jeeber_label`, `receipt_proof_photo`
   (`image: true` + `label:` kept, wraps photo AND placeholder), `receipt_confirm_cta`,
   `receipt_not_yet_cta`, `receipt_confirm_error`. New: `receipt_proof_zoom_cta`,
   `receipt_proof_viewer_root`, `receipt_proof_viewer_close`.
   `receipt_no_commission_line` stays **never emitted** (Maestro negative assertion).
2. **Duplicate-id hazard:** keep the existing outer
   `Semantics(container/button/enabled/label/onTap) + ExcludeSemantics(child:)` idiom on both
   CTAs verbatim (`:310–329`, `:333–348`). Pass `identifier: null` (default) to any kit/OMDS
   button — `JeebCtaButton`/`OmdsLoadingButton` must NOT emit their own id inside an
   `ExcludeSemantics` wrapper.
3. **Do not touch:** the `DeliveryReceiptScreen` constructor seam (`deliveryId`, `repository` —
   devtool catalog `batch_03_entries.dart:213–256` depends on it), `_resolveRepository()`, the
   `BlocConsumer` listener navigation to `mutual-rating` (`:113–128`, D56), `_openDispute`
   (`:359–364`, push to `escalate`), both `_*ErrorCopy` helpers, the cubit/state/domain/data
   layers, and the `Key('receipt-load-error' / 'receipt-confirm-cta' / 'receipt-not-yet-cta')`
   values (pass them through to the new buttons).
4. **No edits to** `app_router.dart` (route + `backFallbacks['delivered-receipt']` already
   correct), `injection_container.dart`, `lib/core/theme/*`, `lib/l10n/*.arb`, `pubspec.yaml`,
   `lib/core/widgets/**` (kit is Wave-1-owned), or any other feature's files.
5. **Gate compliance** (`tool/check_design_tokens.sh`): no `Color(0x…)`, no `Colors.<name>`
   (except `Colors.transparent`), no `SizedBox(width|height: <number>)`, no
   `EdgeInsets.<x>(<number>`, no `BorderRadius.circular(<number>`, no `fontSize:`, no raw
   `AppBar(`. The 230px hero height goes through `static const double _kProofHeroHeight = 230;`
   (a named const defeats the SizedBox literal pattern; 230 is a one-screen dimension).
6. **Lints:** `sort_constructors_first` (constructor first in every new class),
   `prefer_const_constructors`, `prefer_final_locals`, `use_build_context_synchronously` (the
   viewer open is a sync fire-and-forget inside `onTap` — no `await` before any `context` use),
   `avoid_print`. Comments short, *why*-focused.
7. **Analyze bar:** the branch baseline is 11 issues / 6 errors (pre-existing, SDK skew). Your
   code must add ZERO new analyze issues once the l10n batch lands.

---

## 3. Ordered task list (execute top to bottom)

### Task 1 — Write the wiring file
Create `docs/redesign-2026-08/wiring/14-receipt-confirm.md` with exactly the three requests in §5
below. Everything after this task assumes they are granted.

### Task 2 — Delete the app bar; root the body in `SafeArea`
In `_DeliveryReceiptView.build` (`:98–157`): remove `appBar:` (`:99–105`) entirely. Body becomes
`SafeArea(child: Semantics(identifier: 'receipt_prompt', explicitChildNodes: true, child:
BlocConsumer(...)))` — the Semantics value and flags unchanged, listener and all three state
branches unchanged. `l10n.receiptTitle` becomes an orphan getter (parity script WARNs only) —
leave the key alone.

### Task 3 — Rebuild `_LoadedBody` as one sliver column
Replace the `ListView` (`:208–349`) with:

```
CustomScrollView(slivers: [
  SliverFillRemaining(hasScrollBody: false,
    child: Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge),   // 24/0/24/32
      child: Column(children: [
        SizedBox(height: Spacing.large),                           // ~HTML 22 top
        <heading>,
        SizedBox(height: Spacing.large),                           // HTML 20
        ProofPhotoHero(...),
        SizedBox(height: Spacing.medium),                          // HTML 16
        <cash statement>,
        const Spacer(),                                            // dc-tpl 845 flex:1
        <confirm error, only when confirmStatus == failed>,
        <primary CTA>,
        SizedBox(height: Spacing.small),                           // HTML 12
        <outline CTA>,
      ])))])
```

Delete the truck `Icon` + its `SizedBox` (`:216–221`). Heading: existing
`Text(l10n.receiptPromptHeading, textAlign: TextAlign.center)` restyled to
`context.jeebText.h1` with `color: theme.colorScheme.primary` (replaces the
`headlineSmall.copyWith(w700)` at `:226–228`). Documented divergences: side gutter 24 vs HTML's
28 on the heading only; heading top 20 vs 22.

### Task 4 — Create `presentation/widgets/proof_photo_hero.dart`
Public `ProofPhotoHero` widget (constructor first): params `proofPhotoUrl` (`String?`),
`photoSemanticLabel`, `badgeText`, `zoomCtaText`, `onZoom` (`VoidCallback?`).

- Frame: `ClipRRect(borderRadius: OmdsBorderRadius.large /* 20, dc-tpl 834 */)` →
  `SizedBox(height: _kProofHeroHeight, width: double.infinity)` → `Stack`.
- Base: `ColoredBox(color: colorScheme.surfaceContainerHigh)` (the board's `#EAE7EB` ground —
  replaces today's `surfaceContainerHighest` at `:249`).
- Photo (when `proofPhotoUrl` non-null): `Positioned.fill` →
  `Semantics(identifier: 'receipt_proof_photo', image: true, label: photoSemanticLabel)` →
  `OmdsCachedImage(url: …, fit: BoxFit.cover)` — no `width`/`height` args. Placeholder branch
  (no photo): the SAME Semantics wrapper around the centered
  `Icon(Icons.image_not_supported_outlined, size: Sizes.twoXLarge, color: onSurfaceVariant)` —
  the identifier must exist in both states (Maestro asserts it on the seeded journey).
  K3 stands: real photos fill the frame; the HTML's floating 190px art is mock-only.
- Badge (`dc-tpl 836`): `PositionedDirectional(start: Spacing.small, top: Spacing.small)` — pill
  `Container`, fill `colorScheme.primary.withValues(alpha: 0.85)`, radius
  `OmdsBorderRadius.pill`, padding
  `EdgeInsetsDirectional.symmetric(horizontal: Spacing.small, vertical: Spacing.twoXSmall)`,
  text `badgeText` in `context.jeebText.label` + `colorScheme.onPrimary`. On the badge:
  `// TODO(redesign-24): needs gateway proof-photo capture time — omitted, not faked.`
- Zoom pill (`dc-tpl 837`), rendered ONLY when `proofPhotoUrl != null`:
  `PositionedDirectional(end: Spacing.small, bottom: Spacing.small)` →
  `Semantics(identifier: 'receipt_proof_zoom_cta', button: true, label: zoomCtaText,
  onTap: onZoom)` → tappable pill, fill `colorScheme.surface`, ink `colorScheme.primary`,
  `context.jeebText.label`, `OmdsBorderRadius.pill`, `boxShadow: JeebShadows.floatPill`
  (K4 stands: floating chip over imagery, same token as 12's map ETA pill).
- Whole-hero tap: wrap the `Stack` in
  `Semantics(container: true, explicitChildNodes: true, child: GestureDetector(onTap: onZoom))`
  per the `active_request_card.dart` idiom — it must not swallow `receipt_proof_photo` and adds
  no identifier of its own. `onZoom` is null when there is no photo, so the gesture is inert.

### Task 5 — Create `presentation/widgets/proof_photo_viewer.dart`
A top-level `Future<void> showProofPhotoViewer(BuildContext context, {required String url,
required String closeLabel})` using `showGeneralDialog<void>` with
`barrierColor: Theme.of(context).colorScheme.scrim` (NOT `Colors.black` — gate) and an opaque
feel via full-bleed content:

```
Semantics(identifier: 'receipt_proof_viewer_root', explicitChildNodes: true)
└ Stack
  ├ Positioned.fill(InteractiveViewer(minScale: 1, maxScale: 4,
  │     child: Center(OmdsCachedImage(url: url, fit: BoxFit.contain))))
  └ PositionedDirectional(top: <SafeArea>, end: Spacing.medium,
        Semantics(identifier: 'receipt_proof_viewer_close', button: true,
                  label: closeLabel, onTap: pop)
          └ close glyph, ink colorScheme.onPrimary)
```

No cubit, no state, no route: the dialog owns its lifetime; call site guards on
`receipt.hasProofPhoto`. The call in `onZoom` is sync fire-and-forget (discarding the Future in a
sync closure is lint-clean; do not mark the closure `async`).

### Task 6 — Rebuild the cash statement (navy, two lines, emphasized amount)
Replace `:261–288`. Keep `Semantics(identifier: 'receipt_cash_to_jeeber_label')` wrapping the
whole card. Local `Container`: `padding: EdgeInsets.all(Spacing.medium)`,
`color: colorScheme.primary`, `borderRadius: OmdsBorderRadius.medium`,
`boxShadow: JeebShadows.ctaNavy` (`dc-tpl 838`). Row: `Icon(Icons.payments /* filled, R10 */,
size: Sizes.xLarge, color: onPrimary)` + `SizedBox(width: Spacing.small)` + expanded `Column`:

- Line 1 — keep the existing template logic (`:198–206`) but hoist the formatted amount:
  ```dart
  final amountText = receipt.hasKnownAmount
      ? MoneyFormat.format(receipt.cashAmount!, currency: receipt.currency)
      : null;
  final cashText = amountText != null
      ? l10n.receiptCashToJeeber(amountText, jeeberLabel)
      : l10n.receiptCashToJeeberNoAmount(jeeberLabel);
  ```
  Render via `Text.rich` in `context.jeebText.titleProminent` + `onPrimary`; when
  `amountText != null && cashText.indexOf(amountText) >= 0`, split into three spans with the
  middle span `FontWeight.w800` (17/w800 — documented −2px divergence from HTML's 19; do not
  reopen the Wave-0 ramp; w800 degrades to w700 until Inter-ExtraBold ships — expected). The
  U+2066/U+2069 isolate lives inside the emphasized span, so RTL is free. When the token is not
  found (amount-unknown branch), render the plain string.
- `SizedBox(height: Sizes.threeXSmall)` — **`Sizes`, not `Spacing`** (2px, HTML `margin-top:2`).
- Line 2 — `l10n.receiptCashNote` in `context.jeebText.bodySmall` +
  `Theme.of(context).extension<JeebSemanticColors>()!.mutedText` (`dc-tpl 844`, AA at 4.55:1).

Keep the AC4 doc comment (`:289–292`) about `receipt_no_commission_line` next to the card.

### Task 7 — Rebuild the footer CTAs on the Wave-1 kit
Inside the Task-3 column (no `JeebCtaFooter`):

- Confirm error: the existing `Semantics(identifier: 'receipt_confirm_error')` + `Text` block
  (`:293–305`) moves here, restyled `context.jeebText.bodySmall.copyWith(color:
  colorScheme.error)`, followed by `SizedBox(height: Spacing.small)`. Only when
  `confirmStatus == failed`.
- Primary (`dc-tpl 847–849`): keep the outer `Semantics('receipt_confirm_cta', …)` +
  `ExcludeSemantics` idiom verbatim; inside, `JeebCtaButton.primary` — height 58, pill, navy,
  `JeebShadows.ctaNavy`, leading `Icons.check` at `Sizes.large`, label `l10n.receiptConfirmCta`
  in `context.jeebText.button`, `isLoading: confirming` (wiring request W2),
  `key: Key('receipt-confirm-cta')`, same `onTap`.
  *Fallback if W2 is declined:* keep `OmdsLoadingButton` (it accepts `height`, `borderRadius`,
  `backgroundColor`, `textStyle`) wrapped in a `DecoratedBox` carrying `JeebShadows.ctaNavy`;
  the leading ✓ is then omitted (it has no icon slot) — note it in the wiring file as a known
  divergence, do not hack a Row around it.
- `SizedBox(height: Spacing.small)`.
- Outline (`dc-tpl 850`): outer `Semantics('receipt_not_yet_cta', …)` + `ExcludeSemantics` kept
  verbatim; inside, `JeebCtaButton.outline` — height 54, pill, 1.5px `colorScheme.outline`,
  ink `colorScheme.primary`, label `l10n.receiptNotYetCta`, `key: Key('receipt-not-yet-cta')`,
  same `onTap`/enabled gating. There is NO OMDS fallback for this one (`OMDSOutlinedButton`
  draws no border) — if the kit is late, this screen waits; do not ship a borderless stand-in.

### Task 8 — Wire the hero into `_LoadedBody`
`ProofPhotoHero(proofPhotoUrl: receipt.proofPhotoUrl, photoSemanticLabel:
l10n.receiptProofPhotoLabel, badgeText: l10n.receiptProofBadge, zoomCtaText:
l10n.receiptProofZoomCta, onZoom: receipt.hasProofPhoto ? () => showProofPhotoViewer(context,
url: receipt.proofPhotoUrl!, closeLabel: l10n.receiptProofViewerCloseLabel) : null)`.

### Task 9 — New widget test `test/features/delivery_receipt/delivery_receipt_screen_test.dart`
The screen currently has NO widget test; the behavioural contract lives only in out-of-CI
Maestro. Mount via the `repository:` seam with `FakeDeliveryReceiptRepository`; use bounded
`pump()`s, never `pumpAndSettle` (OmdsCachedImage's fetch never completes under the test
HttpClient — same posture as `w1_routes_resolve_test.dart:203–208`). Assert:
1. the five positive identifiers exist on the loaded body;
2. `receipt_no_commission_line` findsNothing AND no text containing `%` / `Commission` /
   `Platform fee` (pins JM-033 AC4 in CI for the first time);
3. `proofPhotoUrl: null` ⇒ `receipt_proof_zoom_cta` findsNothing;
4. tapping `receipt_proof_zoom_cta` shows `receipt_proof_viewer_root` +
   `receipt_proof_viewer_close`;
5. an `ar`-locale pump renders without exceptions (RTL smoke);
6. a 200% `textScaler` pump renders without overflow errors (pins the scroll posture).

### Task 10 — Verify
- `flutter analyze` — no NEW issues beyond the 11-issue/6-error baseline (full cleanliness only
  after the integrator lands the l10n batch).
- `bash tool/check_design_tokens.sh` — zero violations in `lib/features/delivery_receipt/`.
- `flutter test test/features/delivery_receipt/ test/core/router/w1_routes_resolve_test.dart
  test/core/router/back_nav_all_routes_test.dart test/decision_violations_test.dart` — all green,
  no existing assertion edited.
- Devtool catalog still compiles (constructor seam untouched); its three states now exercise
  photo+amount, placeholder+no-zoom, and error.
- Maestro `jm-033`/`jm-032`/`jm-034` are id-based and survive; re-run on the S22 per the
  real-flow standard before the screen is called done (not a CI gate).

---

## 4. Copy changes (all through the wiring batch — never edit arb files yourself)

| Key | Today (EN / AR) | Board | Action |
|---|---|---|---|
| `receiptConfirmCta` | `Yes, I received it` / `نعم، استلمته` | `Yes, I got it` | EN value edit only; AR unchanged |
| `receiptNotYetCta` | `Not yet` / `ليس بعد` | `Not yet — something's wrong` | both locales change |
| `receiptCashNote` | — | `At the door. That's it — no card, no fees.` | NEW |
| `receiptProofBadge` | — | `Proof of delivery` | NEW (no timestamp — data gap) |
| `receiptProofZoomCta` | — | `Tap to zoom` | NEW |
| `receiptProofViewerCloseLabel` | — | (a11y close label) | NEW |

`receiptTitle` becomes an orphan getter → parity script WARN only; leave it.

---

## 5. Wiring requests — final text for `docs/redesign-2026-08/wiring/14-receipt-confirm.md`

```
### l10n
file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: four new receipt keys plus two CTA copy edits for the redesigned confirm-receipt screen.
exact change:
  app_en.arb — edit two values:
    "receiptConfirmCta": "Yes, I got it",
    "receiptNotYetCta": "Not yet — something's wrong",
  app_en.arb — add after the "@receiptProofPhotoLabel" entry:
    "receiptCashNote": "At the door. That's it — no card, no fees.",
    "@receiptCashNote": { "description": "JM-033 sub-line under the cash statement (dc-tpl 844) — reinforces cash-only, no in-app payment (D11)." },
    "receiptProofBadge": "Proof of delivery",
    "@receiptProofBadge": { "description": "JM-033 overlay badge on the proof photo. No timestamp — gateway has no proof-capture time (redesign data gap)." },
    "receiptProofZoomCta": "Tap to zoom",
    "@receiptProofZoomCta": { "description": "JM-033 zoom pill on the proof photo (receipt_proof_zoom_cta) — opens the full-screen viewer." },
    "receiptProofViewerCloseLabel": "Close",
    "@receiptProofViewerCloseLabel": { "description": "a11y label on receipt_proof_viewer_close in the proof-photo viewer modal." },
  app_ar.arb — edit one value:
    "receiptNotYetCta": "ليس بعد — هناك مشكلة",
  app_ar.arb — add after "receiptProofPhotoLabel":
    "receiptCashNote": "عند الباب. هذا كل شيء — لا بطاقة ولا رسوم.",
    "receiptProofBadge": "إثبات التسليم",
    "receiptProofZoomCta": "اضغط للتكبير",
    "receiptProofViewerCloseLabel": "إغلاق",
  app_localizations.dart — add next to the existing receipt getters (~line 2347):
    String get receiptCashNote => _get('receiptCashNote');
    String get receiptProofBadge => _get('receiptProofBadge');
    String get receiptProofZoomCta => _get('receiptProofZoomCta');
    String get receiptProofViewerCloseLabel => _get('receiptProofViewerCloseLabel');
why: the redesigned cash card renders a second line, the proof hero renders a badge and a zoom
pill, and the viewer modal needs an a11y close label; the two CTA edits are the board's copy.
The parity gate fails half-landed keys, so this must land as one batch.
```

```
### cross-feature
file: lib/core/widgets/jeeb/jeeb_cta_button.dart (Wave-1 kit owner)
need: an `isLoading` state on JeebCtaButton.primary (spinner replaces glyph+label, taps
suppressed while true).
exact change: add `final bool isLoading;` (default false) to JeebCtaButton; when true render the
existing OMDS spinner idiom instead of the icon+label row and ignore onTap.
why: 14's confirm CTA ships an in-flight spinner today via OmdsLoadingButton (:320-327); the
redesign moves it to JeebCtaButton (leading check glyph, h58 navy pill) and without isLoading the
double-fire protection visibly regresses. Fallback if declined: 14 keeps OmdsLoadingButton under
a ctaNavy DecoratedBox and drops the leading glyph.
```

```
### cross-feature
file: docs/redesign-2026-08/00-MIGRATION-PLAN.md §5 #24, docs/redesign-2026-08/02-PLAN-ENHANCED.md §3.2
need: remove 14 from JeebMoneyBreakdown's consumer list (it becomes "17, 19").
exact change: §5 #24 consumer column "14 17 19" → "17 19"; 02-PLAN-ENHANCED §3.2 "17 (+14, 19)"
→ "17 (+19)".
why: the board renders no breakdown on 14; the designer note says "Deliberately no commission
line"; Maestro jm-033 asserts receipt_no_commission_line NOT visible (AC4/D11); and
JeebMoneyBreakdown exists to render the platform-fee row — mounting it on 14 would put the fee
on a customer surface by construction.
```

No route request. No DI request. No theme request. No pubspec change.

---

## 6. Stop conditions — what "done" means

**Done when all of these hold:**
1. The screen renders the board: no app bar; centered h1 heading; 230px r20 proof hero with
   badge + zoom pill (photo state) or neutral ground (placeholder state, no zoom pill); navy
   cash card with emphasized amount + periwinkle sub-line; real empty space; docked-reading
   footer of navy pill + outlined pill.
2. All six pre-existing identifiers emit unchanged; the three new ones emit; ExcludeSemantics
   idiom intact; `receipt_no_commission_line` still never emitted.
3. Task-10 verification passes: no new analyze issues, token gate clean, all listed test files
   green with zero existing assertions edited, new widget test in place.
4. RTL: both overlay pills via `PositionedDirectional`, footer/heading paddings directional or
   neutral, `ar` smoke test green.
5. Wiring file written exactly as §5.

**Must NOT touch:** router, DI, theme files, arb files, pubspec, `lib/core/widgets/**`, the
cubit/state/domain/data layers of this feature, any other feature, the constructor seam, the
listener/`_openDispute` navigation, any existing test assertion, the `receiptTitle` key. No new
endpoint or entity field (the proof timestamp stays a TODO). No `DateTime.now()` stand-ins.
