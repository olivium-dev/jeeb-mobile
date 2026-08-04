# w3 — `kyc-status` onto the Jeeb design system

**Screen:** `lib/features/kyc/presentation/kyc_status_view.dart` (+ its host chrome in
`kyc_wizard_screen.dart`). **No render exists** — this is one of the 46 the board never drew, so the
reference was its neighbour `screens/22-become-a-jeeber.png` (the identity step of the same wizard).

## What the neighbour does, and what this screen did instead

| 22 (redesigned) | `kyc-status` before |
|---|---|
| Ø40 tonal back circle + `jeebText.h2` navy title, in-body | Material `OMDSAppBar` supplied by the wizard |
| 24px gutters, blocks 12–20px apart | `EdgeInsets.all(20)` uniform |
| Outlined cards r18, 1.5px brown, **no shadow** | no cards at all — flat rows |
| Grey `surface-high` r16 note, 12.5/w500 periwinkle | hand-rolled `Container` + `OmdsBorderRadius.small` + `bodyMedium` |
| One h56 navy pill docked at `0/24/32` under real emptiness | 3 stacked OMDS buttons + a `Spacer`, all inside the body padding |
| Weight carries hierarchy (Inter 500→800) | `headlineSmall.copyWith(w700)` / `bodyMedium` M3 defaults |

## What changed

* **Structure** — `_StatusScaffold` is now `Expanded(ListView)` + a docked `JeebCtaFooter.single`.
  24px gutters (`_kStatusBodyPadding`), content top-aligned, the lower third left genuinely white
  (R1). It scrolls instead of overflowing when a long Arabic reason meets a large text scale.
* **CTAs** — every `OmdsPrimaryButton` / `OmdsLoadingButton` → `JeebCtaButton`
  (`primary` navy pill + `JeebShadows.ctaNavy` / `outline` / `text`). The old emphasis map is
  preserved 1:1: what was `secondary` is `outline`, what was `text` is `text`.
  `_PendingBackCta` → `_BackToProfileCta`, now shared by all three bodies that offer that exit.
* **Notes** — `_TopupAllowedNote` → `JeebInfoNote.muted` (exactly 22's grey strip);
  `_RejectionReasonNotice` → `JeebInfoNote.error` (Wave-0's soft `errorContainer` pair, not the
  legacy `#B00020` slab).
* **Resubmit "what to fix"** — a bare arrow/text `Column` → `JeebOutlinedCard.grouped` of
  `JeebListRow`s (the card draws the inset dividers).
* **Head slot** — the two terminals with no authored Lottie now put their glyph on a Ø88
  role-tinted disc (`errorContainer` / `jeebRoles.warningContainer`), matching the 88/100 size band
  of `KycReviewMark` / `KycApprovedMark` instead of a bare 64px red glyph.
* **Tokens** — `jeebText.h1` (navy) titles, `jeebText.body` (`onSurfaceVariant`) copy,
  `jeebText.bodySmall` for the auto-check-stopped line. No raw `TextStyle`, no hex, no `fontSize:`.
* **Host chrome** — `KycWizardScreen` gives the *status* step a `JeebTopBar` (the schema/submitting
  steps keep the OMDS bar, as the screen-22 lane left them). Back goes through the wizard's
  existing `_leaveWizard`, matching the identity step and `backFallbacks['kyc-status'] == '/'`.
* **Simplification** — `_PendingActions` / `_ExpiredPendingActions` / `_ActivePendingActions`
  (three widget classes that only re-ordered the same three buttons) collapse into the `actions:`
  list, with the promotion contract stated once.

## What deliberately did NOT change

* **D52 holds** — the rejected body still has NO resubmit CTA; only `kyc_status_view_rejection`
  → `kyc-rejected` (appeal via support). The resubmit CTA remains exclusive to the
  `resubmitRequested` tri-state.
* Flow, edges, copy, poll schedule, role activation and the CTA order in every state.
* All 8 `Semantics(identifier:)` values byte-identical: `kyc_status_root`,
  `kyc_status_poll_expired`, `kyc_status_check_again_cta`, `kyc_status_topup_cta`,
  `kyc_status_topup_allowed_note`, `kyc_status_back`, `kyc_status_feed_cta`,
  `kyc_status_wallet_cta`, `kyc_status_view_rejection`, `kyc_status_resubmit_cta`,
  `kyc_status_resubmit_steps`. All seven `Key`s unmoved.
* Zero new strings — no `.arb` / `app_localizations.dart` edit, so no wiring request was needed.
  No shared file (`app_router`, DI, `lib/l10n`, `lib/core/theme`, the kit, pubspec) was touched.
* The Lottie marks landed by the motion lane are untouched.

## Two things the visual pass caught

1. **`DirectionalIcons.forward` double-flips.** `Icons.arrow_forward_rounded` already declares
   `matchTextDirection: true`, so `Icon` mirrors it in Arabic on its own; resolving it through
   `DirectionalIcons` turned it back around. Verified by rendering the resubmit body in `ar` — the
   glyph now points at the text. (The helper itself is repo-wide and was left alone.)
2. The pending body has **no navy pill** until the automatic poller expires. That is deliberate and
   now documented at the `actions:` list: nothing is urgent while a submission is under review, and
   the navy pill appears exactly when "Check again" becomes the do-it-now action.

## Gates

* `dart analyze lib/features/kyc test/kyc_status_view_test.dart` → **No issues found.**
* `flutter test test/kyc_status_view_test.dart test/kyc_wizard_screen_test.dart test/features/kyc/`
  → **92 passed** (baseline 91; +1 new kit-composition test).
* `test/decision_violations_test.dart` (D52) → 4 passed ·
  `test/semantics_identifier_surfacing_test.dart` → 13 passed ·
  `test/core/router/w2_routes_resolve_test.dart` + dev-seam + KYC gate → 51 passed.
* One test edit, in this screen's own file: `FM5-F11-W3` asserted the promoted CTA by
  `OmdsLoadingButton.backgroundColor`; promotion is now the kit variant, so it asserts
  `JeebCtaButton.variant == primary` (and W4 now pins `outline` on the other side).

## Remaining inconsistencies vs 22

* The terminal titles stay **centre-aligned** under a centred mark; 22 (and most of the board) is
  start-aligned. Changing it would leave a centred mark over a left title.
* Three different head marks now share the slot: an 88px looping Lottie, a 100px green success
  Lottie (the shared terminal mark — its green is the composition's, not `jeebRoles.success`), and
  the 88px tinted glyph disc. Sizes match; inks do not.
* On the rejected body the head disc and the reason note are both `errorContainer` — two pinks
  stacked.
* No `JeebSectionLabel` over the resubmit checklist: it would need a new l10n key (constraint 4).
* The pending footer stacks two same-weight outline pills; 22 ends in a single pill.
