# 17 · Offer composer — change proposal

**Screen id:** `17-offer-composer`
**Verdict:** `rebuild` — every presentation widget in the file is replaced (app bar → in-body top bar; plain text field → money field with ±1 steppers; modal dropdown → inline choice pills; icon-line economics → outlined breakdown card; inline CTA → docked CTA), plus one genuinely new surface element (the wallet strip). **The state layer is untouched**: `OfferFormCubit`, `OfferSubmissionRepository`, `WalletRepository`, the route and the constructor seams are all unchanged.
**Target file:** `lib/features/offers/presentation/offer_submission_screen.dart` (841 LOC) + `lib/features/offers/presentation/offer_composer_l10n.dart` + `lib/features/offers/domain/offer_eta_band.dart`
**Confirmed reachable from `lib/main.dart`:** yes — `app_router.dart:1231-1266` `GoRoute('/jeeber/requests/:id/offer')` name `jeeber-offer-submission` → `RootAwareBackScope` → `OfferSubmissionScreen`. `screen-repo-map.md:66` agrees with the prompt; no path correction needed. (Note `lib/features/offer_submission/` is an **orphaned duplicate** — do not edit it.)

---

## 0. What I read

- Render `screens/17-offer-composer.png`, HTML `screens/17-offer-composer.html` (69 lines, read in full), note `screens/17-offer-composer.note.md`.
- `lib/features/offers/**` — screen (841), `offer_composer_l10n.dart` (168), `application/offer_submission_cubit.dart`, `domain/offer_eta_band.dart`, `domain/offer_submission_repository.dart`, `data/dio_offer_submission_repository.dart`.
- Producers: `app_router.dart:1231-1266`; call sites `jeeber_request_detail_screen.dart:58-63` and `jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart:159-171` (both `pushNamed` with `pathParameters` only — **no `extra`**).
- `lib/core/jeeb_commission.dart` (`kJeebCommissionRate`, `kJeebCommissionPercent`), `lib/features/wallet/domain/wallet_repository.dart` (`WalletBalance`), `lib/core/formatting/friendly_reference.dart`, `lib/features/jeeber_request_feed/data/request_feed_models.dart` (`DeliveryRequest`, `JeeberRequestTier`).
- Wave-0 theme: `jeeb_text_styles.dart`, `jeeb_shadows.dart`, `jeeb_color_roles.dart`, `jeeb_semantic_colors.dart`. **`lib/core/widgets/jeeb/` does not exist yet** — this proposal depends on Wave 1 (§3).
- OMDS: `OmdsTextField`, `OmdsLoadingButton`, `OmdsColorTokens`/`OmdsColorTokensProvider`, `Spacing`, `OmdsBorderRadius`, `UIConstants`.
- Tests: `test/features/offers/offer_composer_error_l10n_test.dart`, `test/core/router/back_nav_offer_composer_test.dart`, `test/offer_form_cubit_test.dart`, `test/batch_j_supplementary_test.dart:120-175`, `test/decision_violations_test.dart:176-207`, `test/core/theme/no_raw_semantic_colors_test.dart` (this file is **not** listed), `tool/check_design_tokens.sh`.
- Maestro: `.maestro/flows/jm-045-offer-composer.yaml` (11 id references), `.maestro/flows/jm-044-offer-kyc-gate.yaml` (`offer_composer_root` only).
- Devtool catalog: `lib/devtool/catalog/entries/batch_07_entries.dart:183-279` (three previews; one uses a **`const`** constructor — the ctor must stay const-able).

### Five facts that shape everything below

1. **The fee math is already right.** `_reserve` (`:195-196`) is `_price! * kJeebCommissionRate`. The plan (§7.6) and `02-PLAN-ENHANCED.md` §5 both confirm it. Nothing about the arithmetic changes.
2. **The board's "Jeeb fee (10%)" is a D41/D44 violation.** The existing l10n resolver already says **"Platform fee (10%)"** (`offer_composer_l10n.dart:84-87`). Keep the app's wording, refuse the board's — see §9-C1.
3. **The board's `You keep (cash) $7.20` contradicts the app's current net line.** `netLine` (`offer_composer_l10n.dart:98-101`) renders `You earn (cash): $8.00` — the *full offer price* — because the 10% comes out of the prepaid wallet, not the cash. The board renders price − fee. The app's own earnings model already defines net as cash − fee (`earnings_summary.dart:88` "average cash kept per delivery after the fee"), so the board is consistent with earnings and the composer is the outlier. **This is a user-visible economic-meaning change and it needs owner sign-off** — see §9-C2.
4. **The header's `Pharmacy run · ⚡ Flash` is not available.** The route carries only `:id`; both in-app call sites push with `pathParameters` only. `DeliveryRequest` *has* `itemsSummary` and `tier`, but nothing hands them to this screen. Render `ORD-XXXXXX` alone + `TODO(redesign-24)`; the `extra` plumbing is a wiring request (§11-W3), not a fabrication.
5. **The band is 24 options, the board draws 3 pills.** `OfferEtaBand.defaultBand()` (`offer_eta_band.dart:49-50`) is 5..120 in 5-min steps because the tier is unknown. Collapsing the picker to exactly three pills would silently delete 21 legal bids. §4.2 keeps them behind an `Other` pill.

---

## 1. Layout & structure

### Deleted

| What | Where | Why |
|---|---|---|
| `Scaffold.appBar: OMDSAppBar(title:, leading:)` | `:262-274` | The design has no Material app bar. It draws an in-body row, `padding 14/24/0`, gap 14: a Ø40 `surface-high` circle with an 18px × glyph, then a two-line title block (HTML `dc-tpl 986-992`). |
| `_OrderRefHeader` (whole class) | `:368-400` | Its two lines split: `Your offer` becomes the top-bar title (20/w700 navy), `ORD-…` becomes the top-bar subtitle (12.5/w600 periwinkle). `l10n.intro` (the "Quote a fair fee…" paragraph) is **deleted** — the board has no intro copy and R1 says the space below stays white. |
| `_PriceField` (whole class) | `:444-473` | Replaced by `JeebMoneyField` (§3). The board's field is h64 / r16 / `surface-high` fill / **2px navy border** / `$` 24 w800 periwinkle + amount 26 w800 navy + two ±1 pills — none of which `OmdsTextField` can express. |
| `_EtaDropdown`'s `InputDecorator` + `InkWell` body | `:492-525` | Replaced by an inline row of three `flex:1` choice pills (HTML `dc-tpl 1004-1007`). The `_openPicker` sheet is **kept** but demoted to an `Other` affordance (§4.2). |
| `_EconomicsCard` + `_EconLine` (whole classes) | `:579-672` | Replaced by `JeebMoneyBreakdown` (§3). The board has no per-line icons, no `OMDSSectionCard` title, and adds a `Your offer` row and a divider the current card has neither of. |
| `OMDSSectionCard(title: l10n.title, …)` | `:608-610` | The breakdown card is untitled on the board; today it repeats the screen title ("Send your offer") inside the card, which reads as a bug. |
| `_SendButton` as an inline scroll child | `:304-307` | The CTA docks (HTML `dc-tpl 1029-1031`: `flex:1` spacer then `padding 0/24/32`). |
| `SizedBox(height: Spacing.xLarge)` before the CTA | `:303` | Superseded by the `Expanded` spacer. |
| `maxLength: kOfferNoteMaxLength` on the note field | `:432` | The visible 500-char counter it produces does not exist on the board. The **limit stays** — moved to `inputFormatters: [LengthLimitingTextInputFormatter(kOfferNoteMaxLength)]`, so the gateway `MaxNoteLength` guard is unchanged. Keep the `kOfferNoteMaxLength` const. |
| `labelText: l10n.noteLabel` on the note field | `:430` | The board shows a placeholder only (`Add a note — "I'm 5 mins from the pharmacy" (optional)`), no floating label. `noteHint` becomes the placeholder; `noteLabel` survives as the field's `Semantics.label` for screen readers. |

### Added / moved — target tree

```
OfferSubmissionScreen                      (ctor + BlocProvider at :99-119 UNCHANGED)
└ _OfferComposer / _OfferComposerState     (state fields :141-202 UNCHANGED)
  └ BlocConsumer<OfferFormCubit, OfferFormState>   (:206-210 UNCHANGED)
    └ Semantics(identifier:'offer_composer_root', explicitChildNodes:true)
      └ Scaffold                                   (no appBar)
        └ SafeArea
          └ Column
            ├ JeebTopBar.close(                                   ← kit #1, leading mode `close`
            │    title: l10n.title,                               //  "Your offer"
            │    subtitle: _headerSubtitle,                        //  "ORD-9C37B6"
            │    subtitleIdentifier:'offer_composer_order_ref',
            │    identifier:'offer_composer_close_cta',
            │    onLeading: widget.onWithdrawn,
            │    tooltip: l10n.closeTooltip)
            ├ Expanded
            │  └ SingleChildScrollView(
            │       padding: EdgeInsetsDirectional.fromSTEB(24, 20, 24, 0))
            │     └ Column(crossAxisAlignment: stretch)
            │        ├ JeebSectionLabel(l10n.priceSectionLabel)                    // YOUR PRICE
            │        ├ SizedBox(height: Spacing.small ~10)
            │        ├ JeebMoneyField(                                             ← kit, §3
            │        │    controller: _priceController,
            │        │    currencyLabel: _currencySymbol,
            │        │    errorText: state.priceError,
            │        │    onChanged: …, onStep: _stepPrice,
            │        │    identifier:'offer_composer_price_field',
            │        │    decrementIdentifier:'offer_composer_price_decrement',
            │        │    incrementIdentifier:'offer_composer_price_increment')
            │        ├ SizedBox(height: Spacing.medium ~18)
            │        ├ JeebSectionLabel(l10n.etaSectionLabel, hint: _etaHint)      // PICKUP ETA · ≤ 60 min
            │        ├ SizedBox(height: Spacing.small ~10)
            │        ├ Semantics(identifier:'offer_composer_eta_dropdown',
            │        │           container:true, explicitChildNodes:true)
            │        │   └ JeebChipRow(role: choice, expanded: true)               ← kit #6
            │        │       ├ JeebSelectChip('20 min', id:'offer_composer_eta_option_0')
            │        │       ├ JeebSelectChip('40 min', id:'offer_composer_eta_option_1')
            │        │       ├ JeebSelectChip('60 min', id:'offer_composer_eta_option_2')
            │        │       └ JeebSelectChip(l10n.etaOther,                        // only when band > 3
            │        │                        id:'offer_composer_eta_more_cta')
            │        ├ _EtaError(state.etaError)                                    // only when non-null
            │        ├ SizedBox(height: Spacing.medium ~18)
            │        ├ _NoteField(controller: _noteController)                      // restyled, id kept
            │        ├ SizedBox(height: Spacing.medium ~18)
            │        ├ JeebMoneyBreakdown(                                          ← kit #24, §3
            │        │    rows: [offer, platformFee],
            │        │    total: youKeep,
            │        │    footnote: reserveNote,
            │        │    footnoteIcon: Icons.lock_outline,
            │        │    identifiers: fee→'offer_composer_fee_line',
            │        │                 total→'offer_composer_net_line',
            │        │                 footnote→'offer_composer_reserve_note')
            │        ├ SizedBox(height: Spacing.small ~12)
            │        └ JeebInfoNote.accent(                                         ← kit #22, §3
            │             icon: Icons.account_balance_wallet,   // board draws a card glyph
            │             text: l10n.walletStrip(...),
            │             linkLabel: l10n.walletTopUpCta,       // "Top up"
            │             onLink: _openTopUp,
            │             identifier:'offer_composer_wallet_strip',
            │             linkIdentifier:'offer_composer_wallet_topup_cta')
            │             // omitted entirely when _wallet == null
            └ JeebCtaFooter.single(                                                 ← kit #2
                 child: JeebCtaButton.primary(
                   height: 58,
                   isLoading: state.isSubmitting,
                   label: _sendLabel,                    // "Send offer — keep $7.20"
                   identifier:'offer_composer_send_cta'))
```

`Expanded(child: SingleChildScrollView(...))` + a docked footer reproduces the render exactly (content ends at ~62% of the viewport, lower ~38% plain white — R1 / risk-13) **and** survives 200% text scale, which a bare `Column` + `flex:1` would not.

### Section rhythm (measured from the HTML, not invented)

| Gap | HTML | Dart |
|---|---|---|
| top bar → YOUR PRICE | `padding 20px 24px 0` | `SizedBox(height: Spacing.large)` (20) |
| label → field | `margin-top: 10px` | `Spacing.small` (12; nearest token, §4.3 permits) |
| field → PICKUP ETA | `padding 18px` | `Spacing.medium` (16) |
| ETA row → note | `18px` | `Spacing.medium` |
| note → breakdown | `18px` | `Spacing.medium` |
| breakdown → wallet strip | `12px` | `Spacing.small` |
| footer | `padding 0 24 32` | `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)` |

Screen gutter is **24** (`Spacing.xLarge`) everywhere — today it is `EdgeInsets.all(Spacing.medium)` = 16 (`:276`).

---

## 2. Tokens — every hardcoded value that changes

The file has **zero** `Color(0x…)` literals today (it is token-clean) but it is **shape-** and **weight-poor**: every visual decision is delegated to OMDS defaults. Mapping:

| Today | Where | Becomes |
|---|---|---|
| `OMDSAppBar` chrome (M3 app-bar height/elevation/title style) | `:262` | `JeebTopBar.close`; title `context.jeebText.h2` (20/w700), subtitle `bodySmall`+ (12.5/w600) inked `JeebSemanticColors.mutedText`; circle `colorScheme.surfaceContainerHigh`, glyph `colorScheme.primary` |
| `theme.textTheme.titleMedium?.copyWith(fontWeight: w700)` | `:385-387` | `context.jeebText.h2` |
| `theme.textTheme.bodySmall?.copyWith(color: onSurfaceVariant)` | `:392-394` | `context.jeebText.bodySmall`, ink `JeebSemanticColors.mutedText` (`#777FC0` — the render's periwinkle, **not** brown `onSurfaceVariant`) |
| `OmdsTextField` default fill/border (white + `#CBD0E0` 1px) | `:461-471` | `JeebMoneyField`: fill `colorScheme.surfaceContainerHigh` (`#EAE7EB`), border `2px colorScheme.primary` (`#0B1351`), radius 16 (`Spacing.medium` inside the kit) |
| `Icon(Icons.attach_money)` prefix | `:467` | a `Text` currency mark, `24/w800`, ink `JeebSemanticColors.mutedText` (HTML `dc-tpl 996`) |
| — (no such element) | new | amount `26/w800` navy — a **kit-local const** inside `JeebMoneyField`; §4.2 of the plan explicitly sanctions this (no ramp entry covers 24/26 money input, and `lib/core/widgets/jeeb/` is exempt from the `fontSize:` ban) |
| — (no such element) | new | ±1 pills: `JeebStepperPill` — pad `6/12`, r999, `1.5px colorScheme.outline` (`#916F66`), `12.5/w700` navy, gap 6 |
| `InputDecorator` + `Icons.timer_outlined` + `Icons.arrow_drop_down` | `:506-513` | gone; section label + choice pills carry the meaning |
| `theme.textTheme.bodyLarge` on the ETA value | `:516` | `JeebSelectChip(role: choice)` — 13.5/w600, **navy** unselected ink on white + `1.5px outline`; selected = navy fill + white (R2/R8; note choice pills do **not** use the brown `onSurfaceVariant` that filter/sort pills use) |
| `OMDSSectionCard` (M3 card: 12px radius + elevation) | `:608` | `JeebOutlinedCard` via `JeebMoneyBreakdown` — white, `1.5px colorScheme.outline`, r16, **no shadow** (R7: a white card with a shadow does not exist on this board) |
| `Icon(size: Spacing.medium, color: colorScheme.primary)` ×3 | `:662-666` | deleted — the breakdown has no row icons; only the footnote keeps a 14px lock glyph inked `mutedText` |
| `theme.textTheme.bodyMedium` (fee/net rows) | `:619, :628` | label `13.5/w600` `mutedText`; value `13.5/w700` navy; total row `15/w800` navy with a `17px` value (`JeebMoneyBreakdown` internals) |
| `theme.textTheme.bodySmall?.copyWith(onSurfaceVariant)` (reserve note) | `:639-641` | `11.5/w500`, ink `mutedText` |
| `1px` divider | — (none today) | `colorScheme.outlineVariant` (`#E5E1E5`), margin `10/0` |
| `OmdsLoadingButton` default (h48, OMDS stadium, no shadow) | `:687-691` | `JeebCtaButton.primary`: h58, `OmdsBorderRadius.pill`, fill `colorScheme.primary`, label `context.jeebText.button` white, `boxShadow: JeebShadows.ctaNavy` |
| `showOmdsSnackbar` | `:253` | unchanged (approved fleet pattern, 40_GUARDRAILS §8) |
| wallet strip (new) | new | `colorScheme.surfaceContainerHigh` fill, r14 (`OmdsBorderRadius.medium`), pad `11/16`, glyph 17px navy, text `12.5/w600` navy, link `12.5/w700` **`context.jeebRoles.accent`** — never `colorScheme.tertiary` |
| `EdgeInsets.all(Spacing.medium)` body padding | `:276` | `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.large, Spacing.xLarge, 0)` |

**Orange audit for this screen:** the render uses `--jeeb-orange` exactly **once** — the `Top up` word (HTML `dc-tpl 1028`). Nothing else on 17 is orange. Do not orange the CTA (that privilege belongs to 16's decaying `Make offer`, R5), do not orange the fee row, do not tint the reserve note. This file is **not** in `no_raw_semantic_colors_test.dart`'s list, but `jeebRoles.accent` is still the only correct source and adding the file to that list is a reasonable follow-up.

---

## 3. Shared components this screen must consume

All from `lib/core/widgets/jeeb/` (Wave 1). **None exist yet** — this screen cannot land before build-order steps 1–5 and 11.

| Kit # | Widget | How 17 uses it | Wave-1 build-order step |
|---|---|---|---|
| 1 | `JeebTopBar` | **`leading: close`** mode (17 is the *only* consumer of the × mode — plan §5 #1 and 02 §3.3 both name it). Two-line variant: title + subtitle. Needs `subtitleIdentifier` so `offer_composer_order_ref` can ride the subtitle. | 3 |
| 2 | `JeebCtaButton` + `JeebCtaFooter` | `single` form, h**58** (17 is the h58 case; 08 is h56). Needs **`isLoading`** — see §11-W2. | 4 |
| 3 | `JeebOutlinedCard` | indirectly, as the shell of `JeebMoneyBreakdown` (r16, 1.5px outline, no shadow, `1px outlineVariant` divider) | 1 |
| 6 | `JeebSelectChip` / `JeebChipRow` | **`role: choice`** — pad `11/0`, `flex:1`, 13.5/w600, unselected ink **navy** (17 is the canonical `choice` consumer; R2) | 5 |
| 10 | `JeebSectionLabel` | twice. The second use needs the **`hint` slot** — `PICKUP ETA` + `· ≤ 60 min` in one paragraph, hint `text-transform:none; letter-spacing:0; w600` (HTML `dc-tpl 1002-1003`). 17 is the reason that slot exists. Both labels render at the **12.5px default**, not the shipped 11px token (plan §4.2 correction / R14 — 17's HTML says 13px). | 3 |
| 22 | `JeebInfoNote` | **`accent` tone** with a **tappable** trailing link — 17 is the tone's defining consumer (navy 12.5/w600 body + orange w700 link). | 2 |
| 24 | `JeebMoneyBreakdown` | the whole economics card. 17 is its primary consumer and **the single enforcement point for D41/D44 wording + `kJeebCommissionRate`**. | 11 |
| 27 | `JeebStepperPill` | the ±1 adjusters. 17 is the only consumer. | 12 |
| — | **`JeebMoneyField`** | the price field. Named in plan §4.2 as the home for the 24/26 w800 money-input consts but **absent from the §5 table** — see §11-W1. | (new) |

**Not shared, stays local:** `_NoteField` (restyled `OmdsTextField`), `_EtaError`, `_InsufficientBalanceSheet` (§8 note), `_headerSubtitle` / `_sendLabel` derivations.

### `_NoteField` — how to hit the board without a raw `TextField`

`tool/check_design_tokens.sh` bans `\bTextField\(` in `lib/features`. `OmdsTextField` hardcodes its border from `context.omdsColorTokens`, so wrap it locally:

```dart
OmdsColorTokensProvider(
  tokens: context.omdsColorTokens.copyWith(
    inputFillColor: colorScheme.surfaceContainerHigh,
    inputBorderColor: Colors.transparent, // gate-exempt; board draws no resting border
  ),
  child: OmdsTextField(
    controller: controller,
    hintText: l10n.noteHint,
    borderRadius: UIConstants.borderRadiusLarge, // 16.0
    minLines: _kNoteFieldMinLines,
    maxLines: _kNoteFieldMaxLines,
    inputFormatters: const [LengthLimitingTextInputFormatter(kOfferNoteMaxLength)],
    …unchanged…
  ),
)
```

`Colors.transparent` is the one `Colors.*` the gate excludes. The focused 2px `colorScheme.primary` border stays — a desirable focus affordance the static render cannot show.

---

## 4. New functionality

### 4.1 ±$1 price steppers (new interaction, no new state)

The board's ±1 pills (HTML `dc-tpl 999-1000`) are net-new. Implementation is entirely local to `_OfferComposerState`:

```dart
void _stepPrice(int delta) {
  final next = ((_price ?? 0) + delta).clamp(0.0, _kMaxOfferPrice);
  setState(() => _price = next == 0 ? null : next);
  _priceController.text = next == 0 ? '' : _fmt(next);   // reuses _fmt at :202
}
```

- `−1` at 0 is a no-op (the kit pill renders `enabled: false`; do not hide it — the board draws both).
- Writing `_fmt(next)` (2 dp) matches the render's `8.00`. Do **not** reformat on every keystroke — that fights the caret.
- `_kMaxOfferPrice`: there is no server-published cap. The gateway's only related signal is the 20-live-offer cap (`offer_submission_cubit.dart:181-187`). Use a defensive local ceiling only to stop unbounded taps; **do not** render it as a rule and do not claim it is a product limit.

### 4.2 ETA: three inline pills, full band preserved

The band stays the authority (D14). Add a pure-Dart derivation to `offer_eta_band.dart` (lane-owned, no Flutter):

```dart
/// The three representative options the composer surfaces inline (screen 17
/// draws exactly three pills). Thirds of the band ceiling, snapped to real
/// options — for a ≤60 band this is exactly the board's 20/40/60.
List<int> get quickOptions { … }   // returns `options` verbatim when length <= 3
```

- The three pills carry `offer_composer_eta_option_0..2` and drive `_selectedEta` directly (no sheet).
- A fourth `Other` pill (`offer_composer_eta_more_cta`) appears **only when** `options.length > quickOptions.length` and opens the **existing** `_openPicker` sheet (`:527-574`), unchanged except that its rows take **new** identifiers `offer_composer_eta_sheet_option_<i>` (§6 explains why they cannot reuse the inline ones).
- When the sheet returns a value not in `quickOptions`, render it as a 4th selected pill in place of `Other` so the selection is always visible.
- The label hint is `≤ {band.options.last} min` — derived from the band that already exists. **`Flash allows ≤ 60 min` is not renderable today** (no tier — fact 4); emit `// TODO(redesign-24): needs the request tier on this route — omitted, not faked.`

With the tier wired (§11-W3) the band becomes 3 options and the `Other` pill disappears on its own — the design's exact 3-pill row.

### 4.3 Live CTA amount

`_sendLabel` = `l10n.sendCtaWithNet(_fmt(net), _currency)` when `_price != null && _price! > 0`, else `l10n.sendCta` ("Send offer"). `net = _price! - _reserve!`. Recomputed on every `setState` the price already triggers — no cubit change.

### 4.4 Wallet strip (new surface element, existing data)

`_wallet` is **already** fetched in `initState` (`:164-178`) and today feeds only the 402 sheet. The strip renders `_wallet!.availableBalance` + `_wallet!.currency` and a `Top up` link that does what the sheet's CTA does (`:789-792`): `context.goNamed('wallet-charge-info')`.

- `_wallet == null` (repo unregistered, or the best-effort fetch failed) → **omit the strip entirely**. Never render `$0.00` — that would be the JEBV4-176 fabrication defect.
- This is what the note means by "wallet balance + top-up inline so a 402 never surprises". It is a display of data the screen already holds; no new endpoint.
- Refresh: re-run `_loadWallet()` when the composer regains focus after `wallet-charge-info` (await the `goNamed` return is not available on `go`; simplest honest option is to leave the snapshot as-is and let the 402 path stay authoritative — do **not** invent a wallet stream).

### 4.5 What the cubit/state layer needs

**Nothing.** `OfferFormCubit`, `OfferFormState`, `OfferSubmissionRepository`, `WalletRepository` and every constructor seam (`repository`, `walletRepository`, `cubit`, `submissionService`, `onWithdrawn`, `onSubmitted`, `onRequestGone`) are untouched. `state.priceError` / `state.etaError` / `state.isSubmitting` / the four listener modes all keep their current consumers.

### 4.6 Data gaps (declared, not faked)

| Design element | Source | Verdict |
|---|---|---|
| fee math, net, reserve | `kJeebCommissionRate` | **buildable today** (plan §7.6) |
| `$6.40 available` wallet strip | `WalletBalance.availableBalance` | **buildable today** |
| `ORD-9C37B6` | `friendlyReference(requestId, prefix: 'ORD-')` (`:320-325`) | **buildable today** |
| `Pharmacy run` (items summary) | `DeliveryRequest.itemsSummary` — not passed to this route | **gap** → `TODO(redesign-24)`, wiring request W3 |
| `⚡ Flash` (tier chip) | `DeliveryRequest.tier` — not passed; and the enum is `light/standard/bulk/flash`, not the 5 marketing tiers | **gap** → `TODO(redesign-24)`, W3. Even with W3, only `flash` maps to a marketing tier name; the other three must not be relabelled |
| `Flash allows ≤ 60 min` | needs the tier | **partial** — render `≤ {band ceiling} min` |
| suggested/prefilled price `8.00` | `DeliveryRequest.potentialEarnings` exists but is not passed | **do not prefill.** Prefilling would also break Maestro's `inputText: "10"` (it appends) |

---

## 5. New routes

**None.** 17 adds no surface. `/jeeber/requests/:id/offer` keeps its `RootAwareBackScope` self-wrap and stays **out** of `backFallbacks` (plan §6 Wave-4 note + §7.4). The `Top up` link and the sheet's top-up CTA both reuse the existing `wallet-charge-info` route.

---

## 6. Semantics identifiers

### Frozen inventory (all 16 must still be emitted)

| Identifier | Today | After |
|---|---|---|
| `offer_composer_root` | `:259` Semantics over Scaffold | unchanged |
| `offer_composer_close_cta` | `:265` app-bar `IconButton` | the `JeebTopBar` × circle (`button: true, container: true`) |
| `offer_composer_order_ref` | `:378` header block (`header: true`) | the `JeebTopBar` **subtitle** (`header: true`) |
| `offer_composer_price_field` | `:459` `OmdsTextField` wrapper | `JeebMoneyField`'s editable core (`textField: true`) — must stay tappable-to-focus (Maestro taps then `inputText`) |
| `offer_composer_eta_dropdown` | `:501` the InkWell that opens the sheet | the **ETA chip row container** (`container: true, explicitChildNodes: true`) |
| `offer_composer_eta_option_<i>` | `:555` sheet rows | the **inline choice pills**, i = index into `quickOptions` |
| `offer_composer_note_field` | `:426` | unchanged (restyled `OmdsTextField`) |
| `offer_composer_fee_line` | `:615` | `JeebMoneyBreakdown`'s Platform-fee row |
| `offer_composer_net_line` | `:624` | `JeebMoneyBreakdown`'s total row |
| `offer_composer_reserve_note` | `:635` | `JeebMoneyBreakdown`'s footnote |
| `offer_composer_send_cta` | `:685` | `JeebCtaButton` |
| `insufficient_balance_sheet` | `:737` | unchanged |
| `insufficient_balance_needed_amount` | `:765` | unchanged |
| `insufficient_balance_available_amount` | `:774` | unchanged |
| `insufficient_topup_cta` | `:782` | unchanged |
| `insufficient_keep_editing_cta` | `:797` | unchanged |

### Why `offer_composer_eta_dropdown` goes on the row container

`.maestro/flows/jm-045-offer-composer.yaml:125-133` does `tapOn: offer_composer_eta_dropdown` → `extendedWaitUntil visible: offer_composer_eta_option_0` → `tapOn: offer_composer_eta_option_0`. With the identifier on the row, the tap lands on the row's centre — the middle pill — which is a legal ETA selection; `option_0` stays visible (no modal covers it) and its tap re-selects. **The flow passes end-to-end, unmodified.** The same holds for `offer_composer_error_l10n_test.dart:56-67`.

Putting `offer_composer_eta_dropdown` on the `Other` pill instead would break both: the sheet would cover the inline `option_0`, and `find.bySemanticsIdentifier` (a **widget** finder — `flutter_test/finders.dart:623`) would then be ambiguous between an inline pill and a sheet row on the same non-opaque route. That is also why the sheet rows must take the new `_sheet_option_<i>` prefix rather than reusing `_option_<i>`.

### New identifiers (additive, `<screen>_<element>` convention)

| Identifier | Element |
|---|---|
| `offer_composer_price_decrement` | −1 pill (name fixed by plan §5 #27) |
| `offer_composer_price_increment` | +1 pill |
| `offer_composer_eta_more_cta` | `Other` pill (conditional) |
| `offer_composer_eta_sheet_option_<i>` | full-band sheet rows |
| `offer_composer_wallet_strip` | the wallet info note |
| `offer_composer_wallet_topup_cta` | its `Top up` link |
| `offer_composer_offer_line` | the breakdown's `Your offer` row (optional but symmetric with fee/net) |

---

## 7. RTL

The board is a pure LTR mock; four things need care.

1. **The money field is the real risk.** `$ 8.00 [−1][+1]` must mirror to `[+1][−1] 8.00 $` **while the digits stay LTR**. Build it inside `JeebMoneyField` as a plain `Row` (auto-mirrors) whose editable core sets `textDirection: TextDirection.ltr` and `textAlign: TextAlign.start`. `OmdsTextField` exposes neither — a second reason the money field must be a kit widget (a raw `TextField` is legal in `lib/core/widgets/jeeb/`; the gate only scans `lib/features`).
2. **Every money string is interpolated into a sentence** (`Platform fee (10%)`, `−$0.80`, `Wallet: $6.40 available`, `Send offer — keep $7.20`). Wrap each numeric run in Unicode isolates (`⁦` … `⁩`) inside `OfferComposerL10n`, not at the call site, so one helper covers EN and AR. The existing AR copy already interpolates amounts (`offer_composer_l10n.dart:110-115`) and has this latent bug today — fixing it is in scope.
3. **`≤ 60 min`** in the section-label hint is the same case; isolate the `≤ 60`.
4. **Direction-safe by construction:** the × glyph is symmetric (no `DirectionalIcons` needed — a back chevron would have been); the ETA `Row` of `Expanded` pills reverses order correctly; `Row(mainAxisAlignment: spaceBetween)` breakdown rows mirror label↔value correctly; use `EdgeInsetsDirectional` for the body/footer padding (the current `EdgeInsets.all` is symmetric so it is not a bug today, but the new asymmetric footer padding is).
5. **The `−` in `−1` and `−$0.80`** is U+2212 MINUS SIGN in the HTML. Keep it (it is what the design draws) and let the isolate handle placement.

---

## 8. Test impact

| Test | Verdict |
|---|---|
| `test/features/offers/offer_composer_error_l10n_test.dart` | **Should pass unmodified.** It enters text into `EditableText.first` (the price field is still the first editable in the tree), taps `offer_composer_eta_dropdown` (now the row → selects the middle ETA), taps `offer_composer_eta_option_0` (inline pill → selects 20), taps `offer_composer_send_cta`, and asserts the localized snack. All four survive. **If** the row-container tap proves flaky, the legitimate fix is to drop the `eta_dropdown` tap from `_submitValidDraft` — the identifier assertions stay untouched, nothing is renamed, no gate is weakened. |
| `test/core/router/back_nav_offer_composer_test.dart` | **Unaffected** — it drives the platform `popRoute` message and asserts the location; it never touches the app bar. Removing `Scaffold.appBar` does not change `RootAwareBackScope`. |
| `test/offer_form_cubit_test.dart`, `test/batch_j_supplementary_test.dart:120-175` | **Unaffected** — cubit-only. |
| `test/decision_violations_test.dart:176-207` | **Unaffected** — it pumps `SettlementDetailScreen`. But it is the reason "Platform fee" / "Commission" wording is non-negotiable here (§9-C1). |
| `test/core/theme/no_raw_semantic_colors_test.dart` | Unaffected (this file is not listed). Adding it after the migration is a sensible follow-up, not a requirement. |
| `tool/check_design_tokens.sh` | Must stay clean: no `fontSize:`, no `Color(0x`, no `EdgeInsets.<x>(N)`, no `BorderRadius.circular(N)`, no raw `TextField(` in the feature file. All design-exact px live in the kit. |
| `lib/devtool/catalog/entries/batch_07_entries.dart:240-277` | **Compiles unchanged** — the ctor is untouched and stays `const`-able. Its three previews (`idle`, `submitting`, `validationErrors`) all render the new UI, and `_FakeWalletRepository(_composerWallet)` means the new wallet strip is visible in the catalog. |
| `.maestro/flows/jm-045-offer-composer.yaml` | **Passes unmodified** (see §6). Not in CI — re-run on the S22 per the real-flow standard. |
| `.maestro/flows/jm-044-offer-kyc-gate.yaml` | Asserts `offer_composer_root` only. Unaffected. |

### Tests to add (additive)

1. `test/features/offers/offer_eta_band_quick_options_test.dart` — pure-Dart: a ≤60 band yields exactly `[20,40,60]`; a 3-option band returns itself; the ceiling is always the last entry.
2. `test/features/offers/offer_composer_price_stepper_test.dart` — `+1` from empty → `1.00`; `−1` at 0 is a no-op; the CTA label tracks the net; `offer_composer_price_decrement` / `_increment` resolve.
3. `test/features/offers/offer_composer_wallet_strip_test.dart` — strip renders with a wallet, is **absent** with a null wallet repo.
4. An `ar` RTL smoke on the composer (money isolates render, no overflow at `textScaleFactor: 2.0`).

---

## 9. Conflicts — refused, and why

**C1 — "Jeeb fee (10%)" is refused (D41/D44).** The HTML (`dc-tpl 1015`) writes `Jeeb fee (10%)`. `test/decision_violations_test.dart:203-207` pins the framing ("Platform fee", never "Commission") and the plan §7.2 restates it. Render **"Platform fee (10%)"** — which is what `offer_composer_l10n.dart:84-87` already says. The `10%` in the label must come from `kJeebCommissionPercent` (`jeeb_commission.dart:88`), not a literal, so the label and the number beside it cannot disagree.

**C2 — `You keep (cash) $7.20` changes the meaning of `offer_composer_net_line`. OWNER DECISION.**
Today the app renders `You earn (cash): $8.00` — the *full offer price* — and documents why (`offer_composer_l10n.dart:95-97`: the 10% comes from the pre-charged wallet, so the cash kept equals the offer). The board renders price − fee.
Both are defensible; they answer different questions. My recommendation is to **adopt the board**, for one non-aesthetic reason: the app's own earnings model already defines net as cash − fee (`earnings_summary.dart:88`, `netPerOffer` = "average cash kept per delivery after the fee"), so today the composer and the earnings screen tell a Jeeber two different numbers for the same delivery. Adopting the board makes them agree, and the CTA ("keep $7.20") becomes the same number the Jeeber will later see in Earnings.
What makes it an owner call rather than an engineering one: it changes what a Jeeber reads **at the moment of commitment**, and the parenthetical `(cash)` is literally inaccurate under the new reading — the cash in hand is $8.00. If the owner adopts it, I would ship the label as **"You keep"** (drop `(cash)`) and keep the `Your offer $8.00` row directly above it, which preserves the cash fact without the misleading qualifier. **Do not ship this silently.**

**C3 — the render's `$` symbol is not a currency model.** The screen renders `_currency` (`:200`, wallet currency else `USD`). Render `$` only when the resolved currency is `USD`; otherwise render the code. Hardcoding `$` would misprice an LBP wallet.

**C4 — no other conflict.** B04 (chat mic) is screen 21; D56 (no skip/back) is screen 15 — the × here is `offer_composer_close_cta`, a pre-existing withdraw affordance, not a D56 violation; D52/D20 do not touch this screen. The `offerCapReached` literal (`offer_submission_cubit.dart:181-187`) stays a literal — it has no localized copy and the redesign does not change it.

**Not a conflict but worth stating:** the render shows a **filled** composer (`8.00`, `40 min` selected). That is a filled *state*, not a default. The empty state (no price, no ETA selected, breakdown showing the `Pending` variants at `feeLinePending`/`netLinePending`/`reserveNotePending`, CTA reading plain "Send offer") is the one a Jeeber actually lands on, and it must look deliberate — the breakdown card renders with its pending copy, not as an empty box.

---

## 10. The insufficient-balance sheet (`:699-810`)

Not on the board. Keep its structure, identifiers and copy verbatim; apply tokens only: `context.jeebText.h2` for the title, `body` for the body, `JeebMoneyBreakdown`-style rows for needed/available, `JeebCtaButton.primary` + `JeebCtaButton.outline` for the two CTAs. Zero behavioural change. If Wave 1 slips, leaving this sheet untouched is acceptable — it is reachable only on a 402.

---

## 11. Wiring requests (other owners)

- **W1 — `JeebMoneyField` is missing from the Wave-1 table.** Plan §4.2 names it as the home for the money-input type consts, but §5's 28-widget list does not include it. 17 is its only consumer. Either add it to Wave 1 or explicitly delegate it to this lane (it must still live in `lib/core/widgets/jeeb/` — a raw `TextField` and design-exact px are illegal in `lib/features`). Spec: h64 min (not fixed — 200% text), r16, fill `surfaceContainerHigh`, `2px primary` border (→ `colorScheme.error` when `errorText != null`), currency mark 24/w800 `mutedText`, amount 26/w800 navy LTR-forced, trailing `JeebStepperPill` pair, optional `errorText` beneath.
- **W2 — `JeebCtaButton` needs `isLoading`.** §5 #2 specs variants and heights but no loading state; `state.isSubmitting` must disable + spin the CTA (today `OmdsLoadingButton` does this). Fallback if refused: keep `OmdsLoadingButton(height:, borderRadius:, backgroundColor:, textStyle:)` inside `JeebCtaFooter` and take the shadow from a wrapping `DecoratedBox(JeebShadows.ctaNavy)`.
- **W3 — (optional) pass the request payload to the composer route.** `app_router.dart:1231-1266` + `jeeber_feed_tab_view.dart:166` + `jeeber_request_detail_screen.dart:59` would need to hand the `DeliveryRequest` over as `extra`. That would light up `Pharmacy run` (`itemsSummary`), the tier chip and the real tier ETA band. Costs three edits across two other lanes and the integrator; **the screen is correct and shippable without it** (the header degrades to `ORD-XXXXXX` and the band to its 5..120 fallback). Deep-link/push entry has no `extra` regardless, so the degraded path must exist either way.
- **W4 — l10n keys for the integrator batch.** Land in `OfferComposerL10n` first (the file's documented pattern, `offer_composer_l10n.dart:5-20`), then swap: `offerComposerTitle` ("Your offer" — today's `offerSubmissionTitle` is "Send your offer"), `offerComposerPriceSectionLabel` ("Your price"), `offerComposerEtaSectionLabel` ("Pickup ETA"), `offerComposerEtaCeilingHint` ("· ≤ {minutes} min"), `offerComposerEtaOther` ("Other"), `offerComposerOfferLine` ("Your offer"), `offerComposerKeepLine` ("You keep"), `offerComposerWalletStrip` ("Wallet: {amount} available"), `offerComposerSendWithNet` ("Send offer — keep {amount}"). `walletTopUpCta` ("Top up") already exists and is reused verbatim. `offerSubmissionIntro` loses its last consumer — leave the key, do not delete it.
- **W5 — `JeebInfoNote.accent` needs a tappable, identifiable trailing link.** §5 #22 lists "link" as a trailing option but does not say it takes `onTap` + an identifier. 17 needs both (`offer_composer_wallet_topup_cta`).
- **W6 — `JeebSectionLabel` default size.** Confirm the 12.5px default + `hint` slot land as §4.2's correction describes; 17's HTML says 13px/w700/ls1.2 with a `text-transform:none` w600 hint. If the widget ships at the raw 11px token, this screen's two labels will be visibly small against the render.
