# W4 · Goods cost — apply report

Lane: `lib/features/goods_cost/**` (undesigned screen — no render on the board).
Reference neighbour: **17 · Offer composer** (`screens/17-offer-composer.png/.html`) and its shipped
implementation `lib/features/offers/presentation/offer_submission_screen.dart`.

Status: **done.**

---

## 1. What the neighbour does, and what this screen did instead

| | 17 (redesigned) | goods-cost (before) |
|---|---|---|
| header | in-body `JeebTopBar.close`, 40px circle + h2 title + periwinkle subtitle, inside the 24px gutter | `OMDSAppBar` — Material chrome bar |
| section headers | `JeebSectionLabel` — 12.5/w700/ls1.2 uppercase periwinkle (`YOUR PRICE`) | none; the field label lived inside the input |
| money input | h64 / r16 / **2px navy** box on `surfaceContainerHigh`, amount 26/w800 navy | stock `OmdsTextField` + a hardcoded `Icons.attach_money` `$` glyph |
| honest note | `JeebInfoNote` strip (wallet) — r14, `surfaceContainerHigh`, glyph + 12.5 line | a plain `bodyMedium` paragraph under the headline |
| CTA | docked `JeebCtaFooter.single` + navy pill `JeebCtaButton.primary`, pad `0/24/32` | `OmdsLoadingButton` pushed down by a `Spacer` inside a `Spacing.medium` all-round padding |
| gutters / rhythm | 24px sides, `Spacing.large` top, `Spacing.small`/`medium` blocks | 16px all round |
| type | every run a `jeebText` token | `theme.textTheme.titleMedium` / `bodyMedium` |
| residual space | real emptiness — bottom ~40% plain white | same shape (a `Spacer`), for a different reason |

## 2. What changed

`lib/features/goods_cost/presentation/goods_cost_screen.dart` — one file, re-skinned in place.

* **`OMDSAppBar` → `JeebTopBar.back`** (in-body, `identifier: 'goods_cost_back'`, `leadingTooltip`
  from `MaterialLocalizations`). Same pop behaviour (`Navigator.maybePop`), no result change.
* **The h1 headline was folded into the bar's `subtitle`.** Both existing strings survive verbatim —
  `goodsCostTitle` is the h2 bar title, `goodsCostHeadline` the periwinkle qualifier under it. The
  first draft kept a 24/w700 h1 *below* a 20/w700 bar title; re-viewing the render killed it — 17
  never stacks a headline larger than the bar title beneath it, and the inverted hierarchy was the
  most obviously "different product" thing left on the screen.
* **The field label became a `JeebSectionLabel`** over the input, still driven by the untouched
  `_label()` helper, so the gateway-authoritative currency and its neutral degrade are byte-identical
  (the devtool catalog's "Currency read degraded" state still reads correctly).
* **New `_AmountField`** — the board's money-field treatment (`min-h 64 / r16 / 2px navy /
  surfaceContainerHigh`, amount `jeebText.h1`@w800 navy, LTR-isolated editable core, error swaps the
  stroke to `colorScheme.error`). Replaces `OmdsTextField`. Rationale and its two snapped design
  values are documented on the class.
* **`goodsCostBody` moved into a `JeebInfoNote.muted`** (`Icons.payments`,
  `identifier: 'goods_cost_cash_note'`) in 17's wallet-strip slot. Copy unchanged — only re-housed.
* **`OmdsLoadingButton` → `JeebCtaFooter.single(JeebCtaButton.primary)`**, `identifier:
  'goods_cost_submit_cta'`. Same enable rule (`text.trim().isNotEmpty && !submitting`), same
  `isLoading`.
* **`Semantics(identifier: 'goods_cost_root')`** root, matching `offer_composer_root`.
* Every raw `TextStyle`/`textTheme` headline run is now a `jeebText` token; every inset is
  `EdgeInsetsDirectional` on a `Spacing` token. Zero colour literals.

New file: `test/features/goods_cost/goods_cost_screen_test.dart` (7 tests) — the screen had **no**
widget test before. Pins the kit composition, the five identifiers, both currency-label states, the
CTA enable rule, and RTL + 200%-text layout.

## 3. What was deliberately NOT done

* **No fee math, no `JeebMoneyBreakdown`, no "You keep" row.** The goods cost is cash the Client
  hands over in full — Jeeb takes a cut of the *delivery fee*, never of the goods. 17's whole
  economics block is the one thing from the neighbour that must not be copied here, and the class doc
  now says so in the file so a later lane does not "complete the pattern".
* **No `±1` stepper pills.** The neighbour's money field has them; adding them here would be a new
  affordance (a receipt total is typed, not nudged).
* **No `JeebMoneyField` import.** It lives in another lane's feature directory, and its `onStep` is a
  required param — see wiring `WR-GOODS-1`.
* **No new l10n keys and no feature-local l10n shim.** The screen is an orphan
  (JEBV4-227: zero external refs, broken backend endpoint); standing up a resolver class for it is
  over-investment. The honest-cash string is requested as `WR-GOODS-2` instead, with the exact
  one-line call-site swap, and the note ships on existing copy meanwhile.
* **No top-bar subtitle metadata** (17 shows `ORD-… · Pharmacy run · ⚡ Flash`). This route carries
  only `deliveryId`; a raw id is not a designed subtitle and nothing else exists to render.
* **`keyboardType: TextInputType.number` kept as-is** — on iOS that pad has no decimal point, which
  is a genuine pre-existing defect for a cents amount. Out of a re-skin lane's remit; flagged here.

## 4. Decision-gate check

* D41/D44 — no "Commission" anywhere; no fee framing at all on this surface (§3 above).
* D20 / D52 / D56 — not applicable to this screen; nothing added that touches them.
* Constraint 1 — the only pre-existing test hook was `Key('goods-cost-error')`; it is byte-identical
  and still on the error `Text`. There were no `Semantics(identifier:)` on this screen before, so
  nothing could be broken; the five new ones follow `<screen>_<element>`.

## 5. Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/goods_cost test/features/goods_cost` | **No issues found** |
| `flutter test test/features/goods_cost/` | **16 passed, 0 failed** (9 pre-existing + 7 new) |
| `flutter test test/devtool/catalog_network_guard_test.dart` | 2 passed (the catalog mounts this screen ×3) |
| `tool/check_design_tokens.sh` patterns, on this file | 0 hits across all 12 |

## 6. Wiring

`docs/redesign-2026-08/wiring/w4-goods-cost.md` — `WR-GOODS-1` (optional stepper slot on the
promoted `JeebMoneyField`, deletes `_AmountField`) and `WR-GOODS-2` (`goodsCostCashNote` EN+AR).
Neither blocks the screen.
