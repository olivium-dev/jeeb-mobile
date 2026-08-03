# Apply report — 14 · Receipt confirm

**Lane:** `14-receipt-confirm` · **Date:** 2026-08-03 · **Status:** applied (one open wiring request: the l10n batch)
**Instruction set:** `docs/redesign-2026-08/per-screen-revised/14-receipt-confirm.md` (10 tasks)

---

## What shipped

| Task | Done | Note |
|---|---|---|
| 1 · wiring file | ✅ | `docs/redesign-2026-08/wiring/14-receipt-confirm.md` written with §5's three requests verbatim. **W2 (`JeebCtaButton.isLoading`) is recorded as ALREADY SATISFIED** — Wave 1 shipped it (`jeeb_cta_button.dart`, `isLoading` on the general form + all four named forms, gated through `isInteractive`). Only the l10n batch is open. |
| 2 · delete the app bar | ✅ | `OMDSAppBar` gone; body is `SafeArea → Semantics('receipt_prompt', explicitChildNodes: true) → BlocConsumer`. Listener, `listenWhen` and all three state branches byte-identical. `receiptTitle` left in the ARB as an orphan (parity WARN only). |
| 3 · one sliver column | ✅ | `ListView` → `CustomScrollView` + one `SliverFillRemaining(hasScrollBody: false)` + `Padding(24/0/24/32)` + `Column`. `const Spacer()` for `dc-tpl 845`. Truck icon deleted. Heading restyled to `context.jeebText.h1` in `colorScheme.primary`. |
| 4 · `ProofPhotoHero` | ✅ | New `presentation/widgets/proof_photo_hero.dart`. `ClipRRect(OmdsBorderRadius.large)` → `SizedBox(_kProofHeroHeight = 230)` → `Stack`; `ColoredBox(surfaceContainerHigh)` ground; `receipt_proof_photo` wraps BOTH the `OmdsCachedImage` and the placeholder glyph; `PositionedDirectional` badge (navy @.85) and zoom pill (`surface` + `JeebShadows.floatPill`); whole-hero `GestureDetector` inside `Semantics(container, explicitChildNodes)`. The `· 9:38` timestamp is a marked TODO, not faked. |
| 5 · `showProofPhotoViewer` | ✅ | New `presentation/widgets/proof_photo_viewer.dart`. `showGeneralDialog<void>` with `barrierColor: colorScheme.scrim` (never `Colors.black` — token gate), `InteractiveViewer(1…4)` over `OmdsCachedImage(fit: contain)`, `receipt_proof_viewer_root` + `receipt_proof_viewer_close`. No route, no DI, no cubit. Called fire-and-forget from a synchronous `onTap`. |
| 6 · navy cash statement | ✅ | Extracted to a private `_CashStatement`. `EdgeInsets.all(Spacing.medium)`, `colorScheme.primary`, `OmdsBorderRadius.medium`, `JeebShadows.ctaNavy` (was peach `primaryContainer`). Filled `Icons.payments` at `Sizes.xLarge`, `Text.rich` with the money token at `w800`, `SizedBox(height: Sizes.threeXSmall)` (Sizes — 2px), sub-line `bodySmall` in `JeebSemanticColors.mutedText`. AC4 comment kept next to the card. |
| 7 · footer on the kit | ✅ | No `JeebCtaFooter`. `JeebCtaButton.primary(height: primaryHeightTall, leadingIcon: Icons.check, iconSize: Sizes.large, isLoading: confirming)` and `JeebCtaButton.outline(height: outlineHeightTall)`, both inside the untouched `Semantics(...) + ExcludeSemantics` idiom with their original `Key`s. The `OmdsLoadingButton` fallback was NOT needed. Confirm-error block moved above the primary CTA. |
| 8 · wire the hero | ✅ | `onZoom` is null unless `receipt.hasProofPhoto`, so the placeholder state has no zoom pill and an inert hero gesture. |
| 9 · widget test | ✅ | `test/features/delivery_receipt/delivery_receipt_screen_test.dart` — 9 tests, all six required assertions plus an amount-degrade case and a no-AppBar case. Bounded `pump()`s only. |
| 10 · verify | ✅ | See below. |

## Kit consumed (nothing hand-rolled)

`JeebCtaButton.primary` · `JeebCtaButton.outline` (+ `primaryHeightTall` / `outlineHeightTall`) ·
`JeebShadows.ctaNavy` · `JeebShadows.floatPill` · `context.jeebText.{h1,titleProminent,bodySmall,label,cardTitle}` ·
`JeebSemanticColors.mutedText`.
No private copy of any kit widget exists in this feature. `JeebMoneyBreakdown` is deliberately
**not** consumed (K1 — AC4/D11).

## Semantics / Key contracts

```
receipt_prompt                 delivery_receipt_screen.dart   (root, explicitChildNodes: true)
receipt_cash_to_jeeber_label   delivery_receipt_screen.dart   (_CashStatement wrapper)
receipt_confirm_error          delivery_receipt_screen.dart   (failed confirm only)
receipt_confirm_cta            delivery_receipt_screen.dart   (Semantics + ExcludeSemantics)
receipt_not_yet_cta            delivery_receipt_screen.dart   (Semantics + ExcludeSemantics)
receipt_proof_photo            proof_photo_hero.dart          (image: true, BOTH states)
receipt_proof_zoom_cta         proof_photo_hero.dart          (NEW — photo state only)
receipt_proof_viewer_root      proof_photo_viewer.dart        (NEW)
receipt_proof_viewer_close     proof_photo_viewer.dart        (NEW)
receipt_no_commission_line     — still never emitted (jm-033 AC4 negative assertion)
Key('receipt-load-error') · Key('receipt-confirm-cta') · Key('receipt-not-yet-cta')  — unchanged
```

No kit/OMDS button emits its own `identifier:` inside an `ExcludeSemantics` wrapper.

## Verification

**`dart analyze lib/features/delivery_receipt/ test/features/delivery_receipt/` → No issues found.**

**`flutter test test/features/delivery_receipt/` → +28, All tests passed** (19 pre-existing repository
tests + the 9 new widget tests). Zero existing assertions edited.

**`flutter test test/decision_violations_test.dart` → +4, All tests passed.**

**Design-token gate** — all 12 `check_design_tokens.sh` patterns hand-run over
`lib/features/delivery_receipt/`: **0 hits.** (The script was not run repo-wide: other lanes are
editing concurrently and their hits are not this lane's damage.)

**`test/core/router/w1_routes_resolve_test.dart` cannot be RUN**, and not because of this lane:
`app_router.dart`'s import closure pulls in six other in-flight lanes with their own
wiring-pending getters (`home_client`, `registration`, `onboarding`, `transcription`,
`client_offers`, `location`, `request_summary`, `auth`). **Zero of the reported errors originate in
`delivery_receipt`** (verified by bucketing every `lib/features/<x>/` path in the compiler output).
Re-run after the integration pass.

**Devtool catalog** (`batch_03_entries.dart:213–256`) still compiles — the `deliveryId` /
`repository` constructor seam, `_resolveRepository()`, the cubit/state/domain/data layers, the
`mutual-rating` listener and `_openDispute` are all untouched.

**Maestro** `jm-033`/`jm-032`/`jm-034` are id-based and every id they key on is preserved; re-run on
the S22 per the real-flow standard before the screen is called done (not a CI gate).

## Deviation from the instruction set — declared

The instruction set says to call `AppLocalizations` as if the four new keys exist. Done literally at
the call sites — but taken alone that leaves 4 `undefined_getter` errors and makes Task 9 and Task 10
unexecutable (the screen does not compile, so no widget test can run).

The obvious workaround — temporarily patching `lib/l10n/*` to run the suite, as the `10` lane did —
was investigated and **rejected as unsafe**: `lib/l10n/app_en.arb` was observed changing under this
session inside a 30-second window, and another lane's `l10n_backup/` with a checksum manifest was
already present in the shared scratchpad, i.e. a concurrent agent is mid patch/restore cycle on those
exact files. Racing it could have permanently clobbered a restore.

Instead this lane took the repo's own sanctioned stopgap route (13 existing `*_l10n.dart` resolvers,
e.g. `live_tracking_l10n.dart` from lane 12): a new feature-local
`lib/features/delivery_receipt/presentation/delivery_receipt_l10n.dart` declaring
`extension DeliveryReceiptRedesignL10n on AppLocalizations` with the four keys as EN/AR getters.
It is deliberately an **extension**, not a wrapper class, so:

- the screen's call sites are spelled exactly as the instruction set requires — `l10n.receiptCashNote`;
- Dart resolves instance members before extension members, so the real getters win silently the
  moment the batch lands — no conflict, no call-site change;
- deletion is one file plus one clearly-marked import line, and that step is written into the
  wiring file for the integrator.

Nothing outside `lib/features/delivery_receipt/` and this lane's own docs/test files was written.

**Incidental repair, disclosed:** while taking a defensive copy this lane wrote three files into the
shared scratchpad path `…/scratchpad/l10n_backup/`, which turned out to be another lane's backup
directory, overwriting its three `lib/l10n` copies with the then-current (patched) contents. This was
detected against that directory's own `SHA256` manifest and **repaired**: the three files were
re-copied from the now-pristine working tree and all three SHA-256s again match the manifest
byte-for-byte. `lib/l10n/` in the working tree was never written to by this lane.

## Accepted divergences from the board

1. **Proof badge has no timestamp.** The board reads `Proof of delivery · 9:38`;
   `_parseReceipt` reads no capture time and `DeliveryReceipt` has no field. Shipped as
   `Proof of delivery` with a `TODO(redesign-24)` at the badge. No `DateTime.now()` stand-in.
2. **Money renders `$8.00`, the board renders `$8`.** `MoneyFormat.format` is the app-wide rule
   (always two decimals, LTR-isolated); it was not forked for one screen.
3. **Emphasized amount is 17/w800, the board is 19/w800** — the Wave-0 ramp is not reopened for
   2px (instruction §1). w800 currently degrades to the bundled w700 until Inter-ExtraBold ships.
4. **Heading gutter 24, the board's is 28**; heading top offset 20 (`Spacing.large`), the board's
   is 22. Both documented in the instruction set.
5. **Outline CTA label** is `context.jeebText.cardTitle.copyWith(w600)` = 15.5/w600, the board's
   exact value (`dc-tpl 850`), passed via `labelStyle` because the kit's outline default is 13.5 —
   the kit's own doc names 14 as the `labelStyle` consumer for precisely this. Token-derived, no
   raw `fontSize:`.
6. **Cash-card icon** is `Icons.payments` at `Sizes.xLarge` (24) vs the board's 22px custom
   banknote glyph; **badge/pill vertical padding** is `Spacing.twoXSmall` (4) vs the board's 5.
7. **Real photos fill the frame** (`BoxFit.cover`); the board's floating 190px 3D illustration is
   mock art (K3).

## Files

Changed: `lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart`
Created: `lib/features/delivery_receipt/presentation/widgets/proof_photo_hero.dart` ·
`lib/features/delivery_receipt/presentation/widgets/proof_photo_viewer.dart` ·
`lib/features/delivery_receipt/presentation/delivery_receipt_l10n.dart` (STOPGAP — delete on wiring) ·
`test/features/delivery_receipt/delivery_receipt_screen_test.dart` ·
`docs/redesign-2026-08/wiring/14-receipt-confirm.md` · this report

Not touched: `app_router.dart`, `injection_container.dart`, `lib/core/theme/*`,
`lib/core/widgets/jeeb/*`, `lib/l10n/*`, `pubspec.yaml`, `delivery_receipt_cubit.dart`,
`delivery_receipt_state.dart`, `domain/*`, `data/*`, `lib/devtool/**`, Maestro flows,
`test/decision_violations_test.dart`, any other feature.
