# 17 · Offer composer — REVISED instruction set (authoritative)

**Screen id:** `17-offer-composer` · **Verdict:** rebuild of the presentation layer only.
**Lane-owned files:** `lib/features/offers/**` and `test/features/offers/**` — nothing else.
**State layer untouched:** `OfferFormCubit`, `OfferFormState`, `OfferSubmissionRepository`,
`WalletRepository`, the route, and every constructor seam stay byte-identical.

Review status: every `file:line` in the original proposal was checked against the tree.
The anchors are accurate (two trivial corrections below). The revisions here are about
**ownership, scope, and one missed Maestro flow** — not about the proposal's facts.

---

## 0. What this revision changed

**Cut (not evidenced by the render / out of lane):**
1. §10 "restyle the insufficient-balance sheet" — the sheet is not on the board. Leave
   `_InsufficientBalanceSheet` (`offer_submission_screen.dart:699-810`) **byte-identical**.
2. `_kMaxOfferPrice` — there is no server or product price cap (`offer_submission_cubit.dart:118-121`
   validates `price > 0` only). Inventing a numeric ceiling fabricates a product rule. The
   stepper floors at 0 and that is all.
3. W6 ("confirm JeebSectionLabel 12.5px default") — already in the plan verbatim (§5 #10,
   plan line 365). No request needed.
4. "Add this file to `no_raw_semantic_colors_test.dart`" — out of this lane; that test file
   is not ours. Verified the screen is NOT in its `migratedFiles` list, so no action either way.

**Corrected:**
1. **`JeebMoneyField` cannot be created by this lane.** `lib/core/widgets/jeeb/` is outside
   `lib/features/offers/` — it is Wave-1 kit territory and the directory does not exist yet.
   It becomes wiring request WR-1; the screen imports it as if granted.
2. **Kit API params the proposal assumed but never requested** — `JeebTopBar` subtitle
   identifier/`header:true`, `onLeading`, `tooltip`, leading identifier; `JeebMoneyBreakdown`
   per-row identifiers. Now explicit in WR-3 / WR-1.
3. **The Maestro row-tap reasoning.** With the 24-option fallback band the row renders FOUR
   pills (3 + `Other`), and the row's exact centre falls in the 8px gap between pills 2 and 3
   — the `tapOn: offer_composer_eta_dropdown` tap selects nothing. That is still harmless
   (the following `offer_composer_eta_option_0` tap makes the draft valid), but the row
   container must stay hit-testable so the tap is a real no-op, not a hit-test failure:
   put a `ColoredBox(color: Colors.transparent)` inside the Semantics container
   (`Colors.transparent` is the one `Colors.*` the token gate allows).
4. **A missed flow:** `.maestro/flows/jm-046-insufficient-balance-sheet.yaml` also taps
   `offer_composer_eta_dropdown` → `offer_composer_eta_option_0` (twice) and asserts the
   sheet ids + that `offer_composer_price_field` retains its value. Added to the freeze matrix.
5. Line-number nits: `kJeebCommissionPercent` is `jeeb_commission.dart:78` (not :88);
   `netPerOffer` is `earnings_summary.dart:170` (not :88). `Spacing.small` = 12,
   `Spacing.medium` = 16, `Spacing.large` = 20, `Spacing.xLarge` = 24, `Spacing.twoXLarge` = 32
   (the proposal's tree annotations "~10"/"~18" were wrong; its table was right).
6. `_NoteField`: `OmdsTextField` HAS a `fillColor` param (verified `omds_text_field.dart:35`),
   so pass the fill directly; the `OmdsColorTokensProvider` `copyWith` wrapper is needed only
   for `inputBorderColor: Colors.transparent`. The focused border is already 2px
   `colorScheme.primary` inside OMDS (verified :193-198) — do not re-implement it.
7. The wallet strip radius (14) and every other design-exact px live inside kit widgets —
   the proposal's `OmdsBorderRadius.medium` aside was wrong anyway (medium = 16, not 14).
   Not the screen's problem: the screen file contains **zero** raw px.

**Decided (was "owner decision" — a decision is made here, flagged, not silent):**
- **C2 — adopt the board's money math.** Breakdown = `Your offer $8.00` / `Platform fee (10%)
  −$0.80` / divider / **`You keep` `$7.20`** + reserve footnote; CTA repeats the kept amount.
  Rationale: the designer note names this computation explicitly ("offer → 10% fee → 'you
  keep $7.20' … repeated on the CTA"); the CTA is unbuildable from the render any other way;
  and `earnings_summary.dart:170` (`netPerOffer` = "average cash kept per delivery after the
  fee") already defines net this way, so today the composer and Earnings disagree. Drop the
  `(cash)` qualifier — under this reading it is literally wrong (cash in hand is $8.00); the
  reserve footnote preserves the wallet-vs-cash mechanics. **Flag the semantic change of
  `offer_composer_net_line` in the lane notes / PR notes** (plan §7.2 refusal-note pattern)
  so the owner sees it at review; all copy lives in `OfferComposerL10n`, so a revert is one line.
- **C1 — the board's "Jeeb fee (10%)" is refused** (D41/D44, plan §7.2). Render
  **"Platform fee (10%)"** — `offer_composer_l10n.dart:84-87` already says it. The `10` must
  come from `kJeebCommissionPercent` (`jeeb_commission.dart:78`), never a literal.
- **C3 — currency:** render `$` only when the resolved `_currency` is `USD`; otherwise render
  the code. Helper lives in `OfferComposerL10n`.

---

## 1. Preconditions — check before writing a line

This screen consumes Wave-1 kit widgets from `lib/core/widgets/jeeb/`. **That directory does
not exist yet.** If any of these is missing when you start, append the wiring requests (§9),
write nothing else, and report BLOCKED:

| Widget | Use here | Plan home |
|---|---|---|
| `JeebTopBar` (close mode) | header | §5 #1 — 17 is the ONLY `close` consumer |
| `JeebCtaButton` + `JeebCtaFooter` | docked send CTA, h58 | §5 #2 |
| `JeebSelectChip`/`JeebChipRow` (`choice` role) | ETA pills | §5 #6 — 17 is the canonical `choice` consumer |
| `JeebSectionLabel` (+ `hint` slot) | YOUR PRICE / PICKUP ETA | §5 #10 — 17 is why the hint slot exists |
| `JeebInfoNote` (`accent` tone + link) | wallet strip | §5 #22 |
| `JeebMoneyBreakdown` | economics card | §5 #24 |
| `JeebStepperPill` | ±1 (inside JeebMoneyField) | §5 #27 |
| `JeebMoneyField` | price field | **NOT in §5 — wiring request WR-1** |

Wave-0 symbols that DO exist and must be used: `context.jeebText.h2/.button`,
`JeebShadows.ctaNavy`, `context.jeebRoles.accent`, `JeebSemanticColors` (`mutedText` =
`#777FC0`). All verified present in `lib/core/theme/`.

---

## 2. Frozen Semantics inventory — all 16 values must still be emitted, spelled identically

| Identifier | Today (verified) | After |
|---|---|---|
| `offer_composer_root` | :259 | unchanged, wraps the Scaffold |
| `offer_composer_close_cta` | :265 | JeebTopBar leading × (`button: true, container: true`) |
| `offer_composer_order_ref` | :378 (`header: true`) | JeebTopBar subtitle (`header: true`) — WR-3 |
| `offer_composer_price_field` | :459 (`textField: true`) | JeebMoneyField's editable core; must stay tappable-to-focus (Maestro taps then `inputText`) and stay the FIRST `EditableText` in the tree (`offer_composer_error_l10n_test.dart:56`) |
| `offer_composer_eta_dropdown` | :501 | the ETA chip-row container (`container: true, explicitChildNodes: true`, hit-testable — §0 corrected #3) |
| `offer_composer_eta_option_<i>` | :555 (sheet rows) | the inline choice pills, i = index into `quickOptions` |
| `offer_composer_note_field` | :426 | unchanged (restyled OmdsTextField) |
| `offer_composer_fee_line` | :615 | breakdown Platform-fee row — WR-1/kit param |
| `offer_composer_net_line` | :624 | breakdown total ("You keep") row |
| `offer_composer_reserve_note` | :635 | breakdown footnote |
| `offer_composer_send_cta` | :685 | the docked CTA |
| `insufficient_balance_sheet` | :737 | unchanged |
| `insufficient_balance_needed_amount` | :765 | unchanged |
| `insufficient_balance_available_amount` | :774 | unchanged |
| `insufficient_topup_cta` | :782 | unchanged |
| `insufficient_keep_editing_cta` | :797 | unchanged |

New identifiers (additive, `<screen>_<element>` convention):
`offer_composer_price_decrement`, `offer_composer_price_increment` (fixed by plan §5 #27),
`offer_composer_eta_more_cta` (the conditional `Other` pill),
`offer_composer_eta_sheet_option_<i>` (full-band sheet rows — MUST be a new prefix: the sheet
opens over the inline pills on a non-opaque route, so reusing `_option_0..2` would make
`find.bySemanticsIdentifier`/Maestro ambiguous), `offer_composer_offer_line` (breakdown
"Your offer" row), `offer_composer_wallet_strip`, `offer_composer_wallet_topup_cta`.

Why the ETA scheme is safe: only `offer_composer_eta_dropdown` and `_eta_option_0` are
referenced anywhere (verified: `offer_composer_error_l10n_test.dart:59,61`; jm-045:107-189;
jm-046:78-165; nothing references `_option_1+`). `option_0..2` survive on the inline pills;
the tap sequences stay green end-to-end unmodified.

---

## 3. Tasks — execute top to bottom

**T1. Append the wiring requests** from §9 to `docs/redesign-2026-08/wiring/17-offer-composer.md`,
verbatim. Then write everything below as if they are granted.

**T2. `lib/features/offers/domain/offer_eta_band.dart` — add `quickOptions`** (lane-owned,
pure Dart, keep the file Flutter-free):
```dart
/// The 3 representative options the composer surfaces inline (screen 17 draws
/// exactly three pills). Thirds of the band ceiling snapped to real options;
/// returns [options] verbatim when there are 3 or fewer.
List<int> get quickOptions { ... }
```
For the 5..120 fallback band this yields `[40, 80, 120]`; for a 60-ceiling band exactly the
board's `[20, 40, 60]`. The full band stays the authority (D14) — nothing is deleted.

**T3. `lib/features/offers/presentation/offer_composer_l10n.dart` — copy changes.** Follow the
file's own documented interim pattern (`_pick(en, ar)` + the ARB keys ride wiring request WR-5):
- `title` → `_pick('Your offer', 'عرضك')` (stop delegating to `offerSubmissionTitle`).
- NEW: `priceSectionLabel` ('Your price'), `etaSectionLabel` ('Pickup ETA'),
  `etaCeilingHint(int minutes)` ('· ≤ {minutes} min' — numeric run LTR-isolated),
  `etaOther` ('Other'), `offerRowLabel` ('Your offer'), `keepRowLabel` ('You keep'),
  `walletStrip(String amount)` ('Wallet: {amount} available'),
  `sendCtaWithNet(String amount)` ('Send offer — keep {amount}'),
  `currencyMark(String currency)` → `'$'` iff `USD`, else the code (C3),
  a private isolate helper wrapping every interpolated amount in U+2066…U+2069.
- `noteHint` → the board's placeholder: `'Add a note — "I\'m 5 mins from the pharmacy" (optional)'`
  + real AR. `noteLabel` survives (used as the note field's `Semantics.label`).
- Fee/net getters: split into breakdown row form — `feeRowLabel` uses `kJeebCommissionPercent`
  (import `core/jeeb_commission.dart` here or format at the call site — the label and the math
  must share the const). Value strings like `−$0.80` keep the U+2212 the board draws, isolated.
- Keep `feeLinePending` / `netLinePending` / `reserveNotePendings` — the EMPTY state renders
  them (see T8). Keep `intro` getter body but it loses its last consumer; leave the ARB key alone.
- Also fix (in scope, lane-owned): the existing AR interpolations at :110-115 lack isolates.

**T4. Screen header** (`offer_submission_screen.dart`): delete `appBar: OMDSAppBar(...)`
(:262-274), the `_OrderRefHeader` call (:280) and class (:367-400). Wrap the body in `SafeArea`.
First child of the new `Column`:
```
JeebTopBar.close(
  title: l10n.title,                      // 'Your offer' — jeebText.h2
  subtitle: _displayRef,                  // 'ORD-9C37B6' (existing getter :320-325)
  subtitleIdentifier: 'offer_composer_order_ref',   // header: true — WR-3
  leadingIdentifier: 'offer_composer_close_cta',
  onLeading: widget.onWithdrawn,
  tooltip: l10n.closeTooltip)
```
`Pharmacy run · ⚡ Flash` is NOT renderable — the route carries only `:id` (verified: both
call sites push `pathParameters` only; `app_router.dart` builder reads only `:id`). Emit
`// TODO(redesign-24): needs the request tier/itemsSummary on this route — omitted, not faked.`
(wiring request WR-6 is the optional upgrade path).

**T5. Body scaffold**: `Column` → `JeebTopBar` → `Expanded(child: SingleChildScrollView(
padding: EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.large, Spacing.xLarge, 0)))`
→ docked `JeebCtaFooter.single` (T9). Gutter is 24 everywhere (today 16 at :276). Section
rhythm: label→control `Spacing.small`; control→next-label `Spacing.medium`; breakdown→wallet
strip `Spacing.small` (nearest-token rule, plan §4.3).

**T6. Price block**: `JeebSectionLabel(l10n.priceSectionLabel)`, then replace the `_PriceField`
call (:282-286) and class (:443-473) with `JeebMoneyField` (WR-1), passing:
`controller: _priceController`, `currencyMark: l10n.currencyMark(_currency)`,
`errorText: state.priceError`, `onChanged` (unchanged parse), `onStep: _stepPrice`, and the
three identifiers (`offer_composer_price_field` / `_price_decrement` / `_price_increment`).
Keep `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))`. Add to `_OfferComposerState`:
```dart
void _stepPrice(int delta) {
  final next = (_price ?? 0) + delta;
  if (next <= 0) {
    setState(() => _price = null);
    _priceController.clear();
    return;                                // floor at 0; no invented ceiling
  }
  setState(() => _price = next.toDouble());
  _priceController.text = _fmt(next.toDouble());   // 2dp matches the render's 8.00
}
```
Do NOT reformat on keystrokes (fights the caret). Do NOT prefill `8.00` — it is a filled
*state* in the render, and prefilling breaks Maestro's `inputText: "10"` (it appends).

**T7. ETA block**: `JeebSectionLabel(l10n.etaSectionLabel, hint: l10n.etaCeilingHint(
_etaBand.options.last))` — `Flash allows` is tier-gapped, render the ceiling only, with the
same TODO as T4. Then replace the `_EtaDropdown` call (:288-293) and its `InputDecorator`
body (:492-525) with:
```
Semantics(identifier: 'offer_composer_eta_dropdown', container: true, explicitChildNodes: true,
  child: ColoredBox(color: Colors.transparent,          // keeps the legacy tap target real
    child: JeebChipRow role: choice, expanded pills:
      quickOptions[i] → Semantics(identifier: 'offer_composer_eta_option_$i', button: true,
                          child: JeebSelectChip(...))
      + IF _etaBand.options.length > quickOptions.length:
        'Other' pill → identifier 'offer_composer_eta_more_cta' → opens _openPicker))
```
- `_openPicker` (:527-574) is KEPT as-is except its rows' identifier string becomes
  `'offer_composer_eta_sheet_option_$i'` (one-token edit at :555) — 21 legal bids survive.
- A sheet-picked value outside `quickOptions` renders as the selected 4th pill in place of
  `Other` (the selection must stay visible; today the dropdown shows it).
- Render `state.etaError` beneath the row in a small local `_EtaError` widget
  (`textTheme.bodySmall` + `colorScheme.error`) — the InputDecorator that rendered it is gone.
- Delete `Icons.timer_outlined` / `Icons.arrow_drop_down`. With WR-6 granted later, the band
  collapses to 3 options and the `Other` pill disappears by itself.

**T8. Note field + breakdown + wallet strip**:
- `_NoteField`: drop `labelText:` (board shows placeholder only; keep `noteLabel` as the
  Semantics `label` on the existing :425 wrapper), `hintText: l10n.noteHint`, move the limit
  from `maxLength:` (visible counter — not on the board) to
  `inputFormatters: const [LengthLimitingTextInputFormatter(kOfferNoteMaxLength)]` (gateway
  `MaxNoteLength` guard intact, `kOfferNoteMaxLength` const stays), pass
  `fillColor: colorScheme.surfaceContainerHigh`, `borderRadius: UIConstants.borderRadiusLarge`,
  and hide the resting border via `OmdsColorTokensProvider(tokens:
  context.omdsColorTokens.copyWith(inputBorderColor: Colors.transparent), child: ...)`.
- Replace `_EconomicsCard`/`_EconLine` (:579-672 incl. the `OMDSSectionCard(title: l10n.title)`
  bug at :608-610) with `JeebMoneyBreakdown`: rows `[offerRowLabel → $8.00 (id:
  offer_composer_offer_line), feeRowLabel → −$0.80 (id: offer_composer_fee_line)]`, total
  `keepRowLabel → $7.20` (id: `offer_composer_net_line`, net = `_price! - _reserve!`), footnote
  = the existing `reserveNote` copy + lock glyph (id: `offer_composer_reserve_note`). No row
  icons. **Empty state** (no price): rows render the existing `feeLinePending` /
  `netLinePending` / `reserveNotePending` sentences — the card must look deliberate, never blank.
- Wallet strip below (`Spacing.small` gap): `JeebInfoNote.accent(icon: wallet glyph, text:
  l10n.walletStrip(...availableBalance...), linkLabel: _l10n.walletTopUpCta, onLink: () =>
  context.goNamed('wallet-charge-info'), identifier: 'offer_composer_wallet_strip',
  linkIdentifier: 'offer_composer_wallet_topup_cta')`. **Omit the strip entirely when
  `_wallet == null`** — never render `$0.00` (JEBV4-176). No refresh plumbing: the snapshot
  stays as-is after a top-up round-trip; the 402 path remains authoritative. The `Top up`
  link is the ONLY orange on this screen (`jeebRoles.accent`, inside the kit) — do not orange
  the CTA, the fee row, or the reserve note.

**T9. CTA**: delete `_SendButton` (:674-694), the inline call (:304-307) and the preceding
`SizedBox` (:303). Dock `JeebCtaFooter.single` after the `Expanded`, padding
`EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)`:
`JeebCtaButton.primary(height: 58, isLoading: state.isSubmitting, onTap: () =>
_onSendTapped(context), label: _sendLabel, identifier: 'offer_composer_send_cta')` where
`_sendLabel = (_price != null && _price! > 0) ? l10n.sendCtaWithNet(fmt(net)) : l10n.sendCta`.
If WR-2 (`isLoading`) is refused: `OmdsLoadingButton` inside the footer wrapped in a
`DecoratedBox` carrying `JeebShadows.ctaNavy` — behaviour first, shadow second.

**T10. Sweep**: confirm `_OrderRefHeader`, `_PriceField`, `_EtaDropdown` (body only — the
picker function survives), `_EconomicsCard`, `_EconLine`, `_SendButton` classes are deleted;
`l10n.intro` has no call site; no `fontSize:`/`EdgeInsets.<x>(N)`/`BorderRadius.circular(N)`/
raw `TextField(`/`Colors.*` (except the two sanctioned `Colors.transparent`) remain in the
feature file. Run `bash tool/check_design_tokens.sh` and `flutter analyze` (baseline: 11
issues / 6 errors PRE-EXIST from the local-SDK skew — zero NEW ones is the bar).

**T11. New tests** (additive, in `test/features/offers/`):
1. `offer_eta_band_quick_options_test.dart` — pure Dart: 60-ceiling band → `[20,40,60]`;
   ≤3-option band returns itself; ceiling is always last.
2. `offer_composer_price_stepper_test.dart` — `+1` from empty → `1.00`; `−1` at empty/0 no-op;
   CTA label tracks the net; both stepper identifiers resolve.
3. `offer_composer_wallet_strip_test.dart` — strip renders with a wallet; ABSENT with a null
   wallet repo.
4. AR RTL smoke — composer pumps under `Locale('ar')` at `textScaleFactor: 2.0`: no overflow,
   amounts render LTR inside RTL sentences.

**T12. Verify the freeze matrix** (run, do not edit):
`test/features/offers/offer_composer_error_l10n_test.dart`,
`test/core/router/back_nav_offer_composer_test.dart` (drives platform popRoute — removing the
app bar does not touch it), `test/offer_form_cubit_test.dart`,
`test/batch_j_supplementary_test.dart:120-175`, `test/decision_violations_test.dart` — all
green unmodified. Devtool catalog `batch_07_entries.dart:240-277` compiles unchanged (ctor
untouched, still const-able; its three previews render the new UI; `validationErrors` must
show the money-field error AND `_EtaError`). Maestro `jm-045`, `jm-046`, `jm-044`: pass
unmodified per §2; not in CI — re-run on the S22 per the real-flow standard.

---

## 4. RTL requirements (all mandatory)

1. `$ 8.00 [−1][+1]` mirrors to `[+1][−1] 8.00 $` while digits stay LTR — the kit builds it as
   a plain `Row` with the editable core forced `TextDirection.ltr` (WR-1; `OmdsTextField`
   exposes neither `textDirection` nor `textAlign` — verified — which is why the money field
   must be a kit widget with a raw `TextField`, legal outside `lib/features`).
2. Every interpolated amount (`−$0.80`, `$7.20`, `Wallet: $6.40 available`,
   `Send offer — keep $7.20`, `≤ 60`) is isolate-wrapped inside `OfferComposerL10n`, not at
   call sites — one helper covers EN and AR.
3. Use `EdgeInsetsDirectional` for the new asymmetric paddings. The × glyph is symmetric (no
   `DirectionalIcons` needed); `Expanded` pill rows and `spaceBetween` breakdown rows mirror
   correctly by construction.
4. Keep U+2212 for `−1` / `−$0.80` (it is what the board draws); the pills' `−1`/`+1` are
   kit-local numeric symbols, not l10n keys.

---

## 5. Code quality bar

- Lints: `prefer_const_constructors`, `prefer_final_locals`, `sort_constructors_first`,
  `use_build_context_synchronously` (the `_openPicker`/sheet paths already guard `mounted` —
  keep that discipline for anything you touch), `avoid_print`.
- Comments: short, *why*-focused, per the existing file's discipline. The doc header comment
  (:16-41) must be UPDATED, not deleted — it documents the identifier contract; amend the
  net-line bullet to the new "You keep" meaning.
- The file SHRINKS (six bespoke classes replaced by kit consumption): keep the remaining
  private widgets (`_NoteField`, `_EtaError`, `_InsufficientBalanceSheet`, `_AmountRow`)
  in-file, matching the current structure. No extraction into `presentation/widgets/` needed.
- Reuse `_fmt`, `_reserve`, `_currency`, `_displayRef` — do not duplicate derivations.

---

## 6. Stop conditions

**Done means:** all §2 identifiers emitted verbatim + the seven new ones; renders match the
board's structure (in-body top bar, money field with steppers, 3-pill ETA row [+`Other` on the
fallback band], placeholder-only note, untitled breakdown with "Platform fee (10%)"/"You keep",
wallet strip, docked h58 CTA restating the net); empty state renders the pending copy; T11
tests pass; T12 matrix green unmodified; `check_design_tokens.sh` clean; `flutter analyze`
shows zero NEW issues; wiring file appended; the C2 semantic change is flagged in lane notes.

**Do NOT touch:** `OfferFormCubit`/state/repositories/domain contracts (except the additive
`quickOptions` getter); the constructor signature or any seam; `_InsufficientBalanceSheet`
and its 5 identifiers; `app_router.dart`, DI, `lib/core/theme/*`, `lib/l10n/*.arb`,
`pubspec.yaml`, `lib/core/widgets/**`, any other feature dir, any `.maestro/` flow, any
existing test, `test/decision_violations_test.dart`, `../omds-flutter`; the orphaned duplicate
`lib/features/offer_submission/` (do not edit, do not delete); the 6 pre-existing analyze
errors. Never render tier names for the non-marketing enum values, never hardcode `10`%,
never fabricate a wallet balance.

---

## 7. Wiring requests — append EXACTLY this to `docs/redesign-2026-08/wiring/17-offer-composer.md`

```
### cross-feature
file: lib/core/widgets/jeeb/jeeb_money_field.dart
need: WR-1 — a JeebMoneyField kit widget (named in plan §4.2 as the home of the 24/26 w800 money-input consts but absent from the §5 table); 17 is its only consumer.
exact change: New widget: min-height 64 (not fixed — must survive 200% text), radius 16, fill colorScheme.surfaceContainerHigh, border 2px colorScheme.primary (colorScheme.error when errorText != null), padding 0/18, gap 8. Children: currency mark Text 24/w800 JeebSemanticColors.mutedText; editable core (raw TextField is legal here) 26/w800 navy, textDirection: TextDirection.ltr, textAlign start, caller-supplied controller/inputFormatters/onChanged; trailing JeebStepperPill pair (§5 #27: pad 6/12, r999, 1.5px colorScheme.outline, 12.5/w700 navy, gap 6) firing onStep(-1)/onStep(+1); errorText rendered beneath. Params: identifier (Semantics textField: true on the editable core), decrementIdentifier, incrementIdentifier, currencyMark, errorText, onChanged, onStep. Layout is a plain Row so RTL mirrors while the amount stays LTR.
why: Screen 17's price field (HTML dc-tpl 995-1000) — h64/r16/2px-navy border/$ 24w800/amount 26w800/±1 pills — none of which OmdsTextField can express (no textDirection/textAlign params; border/fill from tokens); design-exact px are banned in lib/features.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_cta_button.dart
need: WR-2 — JeebCtaButton needs an isLoading param (disable + spinner), missing from §5 #2.
exact change: `final bool isLoading;` — when true the button is non-tappable and shows the standard progress indicator in place of the label, exactly what OmdsLoadingButton does today.
why: 17's send CTA renders OfferFormState.isSubmitting (offer_submission_screen.dart:688-689 today); losing the loading state would allow double-submits. Fallback if refused: 17 keeps OmdsLoadingButton inside JeebCtaFooter wrapped in a DecoratedBox carrying JeebShadows.ctaNavy.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_top_bar.dart
need: WR-3 — the close mode (§5 #1, 17 is its only consumer) must expose: leadingIdentifier, onLeading, tooltip, subtitle, and subtitleIdentifier rendered with Semantics(header: true).
exact change: `JeebTopBar.close({required String title, String? subtitle, String? subtitleIdentifier, String? leadingIdentifier, VoidCallback? onLeading, String? tooltip})` — leading = Ø40 colorScheme.surfaceContainerHigh circle + 18px navy × glyph, Semantics(identifier: leadingIdentifier, button: true, container: true); subtitle 12.5/w600 JeebSemanticColors.mutedText wrapped Semantics(identifier: subtitleIdentifier, header: true).
why: 17 re-homes two FROZEN identifiers onto the kit: offer_composer_close_cta (leading) and offer_composer_order_ref (subtitle, header: true today at offer_submission_screen.dart:378) — Maestro jm-045 AC3 asserts the latter.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_info_note.dart
need: WR-4 — the accent tone's trailing link (§5 #22) must be tappable and identifiable.
exact change: params `String? linkLabel, VoidCallback? onLink, String? linkIdentifier, String? identifier` — link renders 12.5/w700 context.jeebRoles.accent, wrapped Semantics(identifier: linkIdentifier, button: true); the note itself wrapped Semantics(identifier: identifier).
why: 17's wallet strip: `Top up` navigates to wallet-charge-info and carries offer_composer_wallet_topup_cta; the strip carries offer_composer_wallet_strip. Also note: JeebMoneyBreakdown (§5 #24) rows/total/footnote must accept optional semantics identifiers for the same reason — 17 re-homes offer_composer_fee_line / _net_line / _reserve_note onto it (asserted by Maestro jm-045 AC1).

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: WR-5 — the offer-composer redesign keys (screen ships meanwhile on the OfferComposerL10n feature-local resolver per its documented JM-008/JM-031 pattern; swap is call-site-free).
exact change (EN; AR values are in OfferComposerL10n ready to copy):
  "offerComposerTitle": "Your offer",
  "offerComposerPriceSectionLabel": "Your price",
  "offerComposerEtaSectionLabel": "Pickup ETA",
  "offerComposerEtaCeilingHint": "· ≤ {minutes} min",
  "offerComposerEtaOther": "Other",
  "offerComposerOfferRowLabel": "Your offer",
  "offerComposerKeepRowLabel": "You keep",
  "offerComposerWalletStrip": "Wallet: {amount} available",
  "offerComposerSendKeep": "Send offer — keep {amount}",
  "offerComposerNoteHint": "Add a note — \"I'm 5 mins from the pharmacy\" (optional)"
  (+ @-descriptions and the 4-edit recipe per §7.4). NOTE for owner visibility: offerComposerKeepRowLabel changes offer_composer_net_line semantics from "You earn (cash): <full price>" to "You keep: <price − fee>" — adopted per the board + designer note + earnings-model consistency (netPerOffer, earnings_summary.dart:170); flagged, not silent.
why: guardrail 5 — all user-visible strings through l10n; the feature-local map is the sanctioned interim, these keys are the permanent home.

### route
file: lib/core/router/app_router.dart (+ jeeber_request_detail_screen.dart:58-63, jeeber_feed_tab_view.dart:159-171 — other lanes)
need: WR-6 (OPTIONAL — screen is correct and shippable without it): pass the DeliveryRequest as `extra` on pushNamed('jeeber-offer-submission') and read it in the route builder.
exact change: builder reads `final request = state.extra as DeliveryRequest?;` and hands the composer an optional `DeliveryRequest? request` ctor param (additive, defaulted null); both call sites add `extra: request`.
why: lights up the header's "Pharmacy run" (itemsSummary), the tier chip, and the real per-tier ETA band (3 pills, no Other). The degraded path (ORD-ref only, fallback band) must exist regardless — deep-link/push entry never has extra. Only `flash` maps to a marketing tier name; the other enum values must not be relabelled.
```
