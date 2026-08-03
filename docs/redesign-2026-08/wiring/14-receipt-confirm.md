# Wiring requests — 14 · Receipt confirm

> Status note (written at implementation time, 2026-08-03): §5 of the instruction set was authored
> **before Wave 1 shipped**. Request **W2** (`JeebCtaButton.isLoading`) was verified present in the
> shipped kit while implementing this screen (`lib/core/widgets/jeeb/jeeb_cta_button.dart:57` —
> `this.isLoading = false` on the general form and on `.primary`), so it is recorded as
> **ALREADY SATISFIED — no integrator action**. It is kept verbatim because §5 requires it on the
> record and because it documents exactly which kit affordance the confirm CTA depends on.
>
> **The only OPEN request is the `l10n` batch (W1).** The doc-hygiene request (W3) is docs-only.

---

### l10n

file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: four new receipt keys plus two CTA copy edits for the redesigned confirm-receipt screen.
exact change:
```
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
  app_localizations.dart — add next to the existing receipt getters (~line 2376):
    String get receiptCashNote => _get('receiptCashNote');
    String get receiptProofBadge => _get('receiptProofBadge');
    String get receiptProofZoomCta => _get('receiptProofZoomCta');
    String get receiptProofViewerCloseLabel => _get('receiptProofViewerCloseLabel');
```
why: the redesigned cash card renders a second line, the proof hero renders a badge and a zoom
pill, and the viewer modal needs an a11y close label; the two CTA edits are the board's copy.
The parity gate fails half-landed keys, so this must land as one batch.

**Integrator — one extra step when this lands:**
`lib/features/delivery_receipt/presentation/delivery_receipt_l10n.dart` is a feature-local
STOPGAP (the `live_tracking_l10n.dart` / `otp_handover_l10n.dart` precedent): it declares
`extension DeliveryReceiptRedesignL10n on AppLocalizations` carrying the four new keys as EN/AR
getters so the screen compiles and its widget test runs before this batch lands. Dart resolves
instance members ahead of extension members, so the four real getters win the moment they exist —
**delete that file and its one import line in `delivery_receipt_screen.dart`** (marked
`STOPGAP import`). No other call site changes; the spellings are already
`l10n.receiptCashNote` / `.receiptProofBadge` / `.receiptProofZoomCta` /
`.receiptProofViewerCloseLabel`.

---

### cross-feature — **ALREADY SATISFIED, no action**

file: lib/core/widgets/jeeb/jeeb_cta_button.dart (Wave-1 kit owner)
need: an `isLoading` state on JeebCtaButton.primary (spinner replaces glyph+label, taps
suppressed while true).
exact change: add `final bool isLoading;` (default false) to JeebCtaButton; when true render the
existing OMDS spinner idiom instead of the icon+label row and ignore onTap.
why: 14's confirm CTA ships an in-flight spinner today via OmdsLoadingButton (:320-327); the
redesign moves it to JeebCtaButton (leading check glyph, h58 navy pill) and without isLoading the
double-fire protection visibly regresses. Fallback if declined: 14 keeps OmdsLoadingButton under
a ctaNavy DecoratedBox and drops the leading glyph.

**Verified shipped 2026-08-03** — `JeebCtaButton` exposes `isLoading` (default `false`) on the
general form, `.primary`, `.outline`, `.text` and `.accentText`; `isInteractive` gates taps on
`isEnabled && !isLoading && onTap != null`. Screen 14 consumes it directly; the OmdsLoadingButton
fallback was NOT taken and the leading ✓ ships.

---

### cross-feature

file: docs/redesign-2026-08/00-MIGRATION-PLAN.md §5 #24, docs/redesign-2026-08/02-PLAN-ENHANCED.md §3.2
need: remove 14 from JeebMoneyBreakdown's consumer list (it becomes "17, 19").
exact change: §5 #24 consumer column "14 17 19" → "17 19"; 02-PLAN-ENHANCED §3.2 "17 (+14, 19)"
→ "17 (+19)".
why: the board renders no breakdown on 14; the designer note says "Deliberately no commission
line"; Maestro jm-033 asserts receipt_no_commission_line NOT visible (AC4/D11); and
JeebMoneyBreakdown exists to render the platform-fee row — mounting it on 14 would put the fee
on a customer surface by construction.

---

No route request. No DI request. No theme request. No pubspec change.
