# 23 · Wallet — change proposal

Lane: Wave 2 (self-contained) · feature dir `lib/features/wallet/`
File: `lib/features/wallet/presentation/wallet_hub_screen.dart` (543 LOC, 6 widgets, 10 identifier
literals on this screen). Confirmed live: `app_router.dart:1617` `/wallet` → `WalletHubScreen`, and
`screen-repo-map.md:72` agrees with the prompt — no STOP-table correction applies to 23.
Design: `screens/23-wallet.{png,html,note.md}`
Verdict: **restyle** — same data, same route, same section order, all 10 identifiers survive
unmoved. But be honest about the diff size: **every container in `_LoadedBody` is replaced** and two
private widgets (`_Banner`, `_StatRow`) are deleted, so this is a restyle at the product level and a
container-tree replacement at the Flutter level.

> Gate reminder: this file is on the `no_raw_semantic_colors_test.dart` migrated list
> (`test/core/theme/no_raw_semantic_colors_test.dart:33`). **No `Color(0x`, no `Colors.<name>`, no
> `.tertiary*`.** Orange comes only from `context.jeebRoles.accent`; the two on-navy orange
> translucents come only from `JeebSemanticColors.accentTint` / `.accentRing`.

---

## 0. One-paragraph summary

The board keeps every field this screen already reads and re-ranks them into five stacked blocks
with a real empty lower third: a navy `heroNavy` balance card that says what the money is *for*
(`AVAILABLE TO BID`) and carries the starter-credit pill on-card, a green success note that answers
affordability as honest state copy, an outlined reserve row that explains the hold ("released if
you're not picked"), an **inline** (not docked) navy top-up pill with an orange text link under it,
and a grouped outlined card holding the two cross-feature exits. The docked footer is a single
periwinkle trust line — `Customer cash never passes through this wallet.` — which is net-new and is
the sharpest copy on the screen. Structurally the M3 `AppBar` moves in-body, the `ListView` becomes
a `CustomScrollView` + `SliverFillRemaining` so the ~30% white below the list card is real emptiness
(R1) rather than a stretched list. Three board strings are **rate-literal** (`the 10%`, `the 10%
reserve`) and must render from `kJeebCommissionPercent`, never typed. Two board facts are **not
buildable**: `1 live offer` (no offer count on `WalletBalance`) and the `$` symbol appearing without
`MoneyFormat` (which exists and should finally be used here). One board word — `included` on the
starter-credit pill — makes a claim about how the gateway composes `availableBalance` that the
contract does not define; proposed neutral wording below.

---

## 1. Semantics inventory — FROZEN (all 10 on this screen must still be emitted)

Greped from `lib/features/wallet/presentation/wallet_hub_screen.dart` (§7.5 requires this before the
first edit). The other 24 identifiers in the feature tree belong to
`wallet_charge_info_screen.dart` / `wallet_activity_list_screen.dart` / `transaction_detail_screen.dart`
/ `customer_wallet_stub_screen.dart` and are **out of this lane's scope — do not touch those files**.

| identifier | today at | after the restyle |
|---|---|---|
| `wallet_hub_root` | `:80` | unchanged — still the single `<screen>_root`, still wraps the `Scaffold`, `container: true` |
| `wallet_kyc_pending_banner` | `:148` | unchanged — re-homed onto `JeebInfoNote` (tone `muted`), still the first child, still gated on `copy.kycPending` |
| `wallet_available_balance` | `:160` | re-homed onto the **content Column inside** `JeebNavySurfaceCard` (not the card itself, so the decorative ring stays out of the node). Keeps `container: true` **and `explicitChildNodes: true`** — without it the nested gift-badge id is swallowed (§7.5) |
| `wallet_gift_badge` | `:195` | re-homed onto the on-navy accent pill (was `OmdsChip`) — still gated on `giftCredit > 0` (D42) |
| `wallet_affordability_card` | `:212` | re-homed onto `JeebInfoNote` (tone `success` / `warning`) |
| `wallet_reserved_now` | `:226` | re-homed onto the outlined reserve note |
| `wallet_topup_cta` | `:240` | re-homed onto `JeebCtaButton(variant: primary, placement: inline)` — `button: true` stays |
| `wallet_how_fees_work` | `:253` | re-homed onto `JeebCtaButton(variant: accentText)` — `button: true` stays |
| `wallet_earnings_row` | `:271` | re-homed onto `JeebListRow` #1 inside the grouped `JeebOutlinedCard` |
| `wallet_see_all_activity` | `:288` | re-homed onto `JeebListRow` #2 |
| `wallet_how_fees_explainer` | `:376` | unchanged — the bottom sheet root, `container: true` + `explicitChildNodes: true` |

### New identifiers (2)

| identifier | element | why |
|---|---|---|
| `wallet_back` | `JeebTopBar` back circle | The board replaces the M3 `AppBar` with an in-body Ø40 circle. Today's `OMDSAppBar` back button carries **no** identifier, so this is a pure addition and `JeebTopBar` owns the `<screen>_back` contract (§5 #1) |
| `wallet_cash_disclaimer` | the docked trust line | Net-new element carrying a product claim ("customer cash never passes through this wallet") that is worth pinning; non-interactive, so `container: true` only, no `button:` |

### Maestro impact — `.maestro/flows/jm-053-wallet-hub.yaml` keeps passing, unchanged

All seven ACs are satisfied by the layout above:

- AC1 asserts `wallet_available_balance`, `wallet_gift_badge`, `wallet_affordability_card`,
  `wallet_reserved_now`, `wallet_topup_cta` **all visible without scrolling**. Measured against the
  render they land at y≈150–470 of 956 — comfortably above the fold, better than today where the
  reserve row is the fourth item of an `EdgeInsets`-16 `ListView`.
- AC2/AC3 tap `wallet_topup_cta` / `wallet_how_fees_work` — both stay `goNamed('wallet-charge-info')`
  and `showModalBottomSheet`; destinations unchanged.
- AC4/AC5 tap `wallet_earnings_row` / `wallet_see_all_activity` and assert `earnings_total_cash` /
  `wallet_activity_root` — both stay `goNamed('earnings')` / `goNamed('wallet-activity')`.
- AC6 asserts the affordability card renders for `wallet_state=insufficient` — the `warning` tone
  branch keeps the same identifier.
- AC7 asserts `wallet_kyc_pending_banner` for `kyc_status=pending` — still the first child.

Maestro is not in CI (§7.5), so this is a manual guarantee. **Do not move the reserve row below the
top-up CTA** — that would push it near the fold on a small device and AC1 has no `scrollUntilVisible`.

---

## 2. Layout & structure

### 2.1 Today (`wallet_hub_screen.dart:79-299`)

```
Semantics(wallet_hub_root) > Scaffold
├ appBar: OMDSAppBar(title, showBackButton, onBackPressed)        :83-92
└ body: BlocBuilder<WalletHubCubit, WalletHubState>               :93
  ├ initial/loading → OmdsLoadingState                            :96-98
  ├ failed          → OmdsErrorState(retry)                       :99-104
  └ loaded          → RefreshIndicator > _LoadedBody              :105-109
      ListView(padding: fromSTEB(16, 20, 16, 32))                 :132-138
      ├ [if kycPending] _Banner(hourglass)                        :144-156
      ├ Semantics(wallet_available_balance) > Column              :159-206
      │   ├ Text(label, bodyMedium/onSurfaceVariant)
      │   ├ Row[ Text(_fmt, headlineMedium w700), Text(currency, titleMedium) ]
      │   └ [if gift] Semantics(wallet_gift_badge) > OmdsChip(enabled:false)
      ├ SizedBox(20)                                              :208
      ├ Semantics(wallet_affordability_card) > _Banner(tone?)     :211-220
      ├ SizedBox(16)                                              :222
      ├ Semantics(wallet_reserved_now) > _StatRow                 :225-234
      ├ SizedBox(20)                                              :236
      ├ Semantics(wallet_topup_cta) > OmdsPrimaryButton           :239-247
      ├ SizedBox(12)                                              :249
      ├ Semantics(wallet_how_fees_work) > OmdsPrimaryButton(text) :252-261
      ├ SizedBox(20)                                              :263
      ├ Semantics(wallet_earnings_row) > OmdsSettingsRow          :270-280
      └ Semantics(wallet_see_all_activity) > OmdsSettingsRow      :287-297
```

Everything is a flat, evenly-spaced, edge-to-edge list. Nothing is grouped, nothing is promoted,
nothing is docked, and the list expands to fill the viewport — the exact high-density shape R1 says
must go.

### 2.2 Target (measured from `23-wallet.html`; gutter 24 throughout)

```
Semantics(wallet_hub_root) > Scaffold(body: SafeArea > Column)
├ JeebTopBar(leading: back, title: copy.title, identifier: 'wallet_back')   pad 14/24/0
└ Expanded > BlocBuilder
    ├ initial/loading → OmdsLoadingState              (unchanged)
    ├ failed          → OmdsErrorState(retry)         (unchanged)
    └ loaded          → OmdsPullToRefresh > CustomScrollView
        ├ SliverPadding(EdgeInsetsDirectional.fromSTEB(24, 16, 24, 0))
        │ └ SliverList
        │   ├ [if kycPending] Semantics(wallet_kyc_pending_banner)
        │   │                 > JeebInfoNote(tone: muted, glyph: hourglass_top)   +12
        │   ├ JeebNavySurfaceCard(radius 20, pad 20, shadow: heroNavy,
        │   │   ring: accentRing Ø170 at bottom-END, clip: true)
        │   │ └ Semantics(wallet_available_balance, explicitChildNodes)
        │   │   ├ JeebSectionLabel('Available to bid', onNavy)          12.5/w700/+1.2
        │   │   ├ Row(baseline)[ $6.40  statHero/white ,  USD  bodySmall+w700/periwinkle ]
        │   │   └ [if gift] Semantics(wallet_gift_badge) > _GiftPill    pad 6/12 r999
        │   ├ 12
        │   ├ Semantics(wallet_affordability_card)
        │   │ > JeebInfoNote(tone: success|warning, r16, pad 13/16, gap 12)
        │   ├ 12
        │   ├ Semantics(wallet_reserved_now)
        │   │ > JeebInfoNote(tone: outlined, trailing: value)           r16, 1.5px outline
        │   ├ 16
        │   ├ Semantics(wallet_topup_cta)
        │   │ > JeebCtaButton(primary, inline, h56, leading: Icons.add) shadow ctaNavy
        │   ├ 12
        │   ├ Semantics(wallet_how_fees_work)
        │   │ > JeebCtaButton(accentText, centered)                     13/w700 accent
        │   ├ 16
        │   └ JeebOutlinedCard(r16, dividers: true)
        │     ├ Semantics(wallet_earnings_row)      > JeebListRow(show_chart)
        │     └ Semantics(wallet_see_all_activity)  > JeebListRow(article)
        └ SliverFillRemaining(hasScrollBody: false)
            > Align(bottomCenter) > Padding(0/24/30)
              > Semantics(wallet_cash_disclaimer) > Text(trust line, caption/mutedText, center)
```

**Three structural rules this encodes, and why each is a `SliverFillRemaining` and not a `Spacer`:**

1. **R1 — the spacer is real emptiness.** Measured on the render, content ends at y≈635 of 956
   (66%); the trust line sits at y≈914. That ~30% of white is the design. A `Column` +
   `Spacer` inside a `SingleChildScrollView` cannot express "fill the viewport but scroll when it
   overflows"; `SliverFillRemaining(hasScrollBody: false)` + `Align(bottomCenter)` does exactly
   that, and it is the only shape that survives 200% text scale without a render overflow.
2. **`OmdsPullToRefresh` needs a scrollable descendant** — a `CustomScrollView` qualifies.
3. **The top bar is outside the scroll view** so it does not scroll away, matching the board
   (`padding: 14px 24px 0` on a non-scrolling row).

### 2.3 Deleted

| what | where | replaced by |
|---|---|---|
| `OMDSAppBar` in `Scaffold.appBar` | `:83-92` | `JeebTopBar(leading: back)`, in-body. `onBackPressed` logic (`canPop ? pop : go('/')`) moves verbatim onto `JeebTopBar.onBack` — **do not simplify it**, `backFallbacks['wallet'] = '/'` (`app_router.dart:505`) depends on this screen never popping the last page |
| `_Banner` | `:440-493` | `JeebInfoNote` (kit). Its `BorderRadius.circular(12)` at `:465` is one of the 8 **pre-existing** `tool/check_design_tokens.sh` violations — it dies with the widget |
| `_StatRow` | `:496-543` | `JeebInfoNote(tone: outlined, trailing: value)` |
| `RefreshIndicator` | `:106` | `OmdsPullToRefresh` — also a pre-existing token-gate violation on this file |
| `_fmt` (`toStringAsFixed(2)`) | `:361` | `MoneyFormat.format(v, currency: c)` (`lib/core/formatting/money_format.dart:33`) — already the app-wide formatter, already LTR-isolated, already used by 8 feature files |
| `OmdsChip(enabled: false)` gift badge | `:197-201` | screen-local `_GiftPill` (on-navy; OMDS has no on-navy chip and CI pulls OMDS from GitHub, so nothing goes upstream) |
| `OmdsSettingsRow` ×2 | `:274-279`, `:291-296` | `JeebListRow` ×2 inside one `JeebOutlinedCard` with an inset divider |

### 2.4 Added

- The docked trust line (§3.8) — the only genuinely new element on the screen.
- The decorative Ø170 `accentRing` circle on the hero (§3.2).
- The inset 1px `outlineVariant` divider between the two list rows.

---

## 3. Section-by-section

### 3.1 Top bar → `JeebTopBar`

HTML `:15-18`: row, `padding 14px 24px 0`, gap 14; Ø40 circle `--jeeb-surface-high` containing a
20px navy back arrow; title `Wallet` 20/w700 navy.

```dart
JeebTopBar(
  leading: JeebTopBarLeading.back,
  identifier: 'wallet_back',
  title: copy.title,                       // jeebText.h2 inside the kit widget
  onBack: () => context.canPop() ? context.pop() : context.go('/'),
)
```

The glyph must be `DirectionalIcons.back(context)` (kit-internal), never `Icons.arrow_back` — the
app is Arabic-first and `Icon` does not auto-mirror (`directional_icons.dart:6-8`).

### 3.2 Balance hero → `JeebNavySurfaceCard`

HTML `:20-27`. `margin 16/24/0`, `background --jeeb-navy`, `border-radius 20`, `padding 20`,
`overflow: hidden`, `box-shadow rgba(11,19,81,.3) 0 12px 28px`.

```dart
JeebNavySurfaceCard(
  radius: OmdsBorderRadius.large,           // 20 — exact match
  padding: const EdgeInsets.all(Spacing.large),   // 20 — exact match
  shadow: JeebShadows.heroNavy,             // 0 12 28 rgba(11,19,81,.30) — byte-exact
  ring: JeebNavyRing.bottomEnd,             // Ø170, 1.5px, JeebSemanticColors.accentRing
  child: Semantics(
    identifier: 'wallet_available_balance',
    container: true,
    explicitChildNodes: true,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...]),
  ),
)
```

**Correction to the plan's R6.** §00 and 02 §2-R6 both say the hero's decorative circle sits at the
**top-END**. On 23 the HTML is `right: -50px; bottom: -50px` (`:21`) — **bottom-END**. `JeebNavySurfaceCard`
must expose the corner, not hard-code it, and must place it with `PositionedDirectional(end: -50,
bottom: -50)` so RTL mirrors it. Diameter 170, `border: 1.5px rgba(215,59,0,.30)` →
`Border.all(width: 1.5, color: semantic.accentRing)` inside a `ClipRRect` (the HTML's `overflow:
hidden`).

Contents:

| element | HTML | Flutter |
|---|---|---|
| eyebrow `AVAILABLE TO BID` | 12.5/w700, ls 1.2, uppercase, periwinkle (`:22`) | `JeebSectionLabel(copy.availableToBid)` — the kit's **12.5 default** is an exact match (§5 #10). Its baked `mutedText` ink **is** periwinkle `#777FC0`; measured against navy `#0B1351` that is **4.53:1 — AA passes**, so no on-navy ink override is needed |
| amount `$6.40` | 38/w800, ls −1, white (`:23`) | `Text(MoneyFormat.format(b.availableBalance, currency: b.currency), style: context.jeebText.statHero.copyWith(color: cs.onPrimary))` — `statHero` is 38/w800/−1.0, byte-exact |
| suffix `USD` | 14/w700, periwinkle (`:23`) | `context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700, color: semantic.mutedText)` — 12/w700. **Stated divergence: 14 → 12.** The ramp has no 14/w700 slot and §7.3 bans `fontSize:` in `lib/features`; R3 says rank by weight, not size |
| row | `align-items: baseline; gap 8` | `Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic)` + `SizedBox(width: Spacing.xSmall)` — the existing code (`:171-189`) already does this correctly; keep it |

**The `$` glyph is buildable — stop hand-rolling it.** `MoneyFormat.format` renders `$6.40` for USD
and `LBP 15,000.00` otherwise, wrapped in `U+2066…U+2069`. Because the non-USD branch already
carries the code, render the `USD` suffix only when the symbol branch fired:

```dart
// MoneyFormat prints the ISO code inline for non-USD, so the suffix would double it.
final code = currency.trim().toUpperCase();
final showCurrencySuffix = code.isEmpty || code == 'USD';
```

### 3.3 Starter-credit pill → screen-local `_GiftPill` (keeps `wallet_gift_badge`)

HTML `:24-26`: `margin-top 10`, inline-flex, gap 7, `padding 6px 12px`, `border-radius 999`,
`background rgba(215,59,0,.20)`, `border 1px rgba(215,59,0,.40)`, 🎁 at 13px + label 12/w700 white.

```dart
Container(
  padding: const EdgeInsetsDirectional.fromSTEB(
      Spacing.small, Spacing.xSmall - 2, Spacing.small, Spacing.xSmall - 2),
  decoration: BoxDecoration(
    color: semantic.accentTint,                                   // orange @12%
    border: Border.all(color: semantic.accentRing, width: 1),     // orange @30%
    borderRadius: OmdsBorderRadius.pill,
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [...]),
)
```

**Stated divergence:** the board uses orange at **20% fill / 40% border**; the sanctioned tokens are
12% (`accentTint`) and 30% (`accentRing`). Wave 0 is frozen (§4.6) and this file cannot hold a raw
`Color(0x` (`no_raw_semantic_colors_test.dart:52`), so the two nearest tokens win. Visually the pill
reads slightly quieter on navy; that is the correct trade.

The 🎁 is an emoji in the HTML (`:25`). Ship it as a literal emoji `Text` inside the kit-free pill,
not `Icons.card_giftcard` — R10 keeps emoji and glyphs separate, and today's
`Icons.card_giftcard_outlined` (`:199`) is an *outline* icon, which R10 bans outright.

**Copy — refuse `included`.** The board says `$5.00 starter credit included`. `WalletBalance`
(`domain/wallet_repository.dart:17-31`) defines `giftCredit` and `availableBalance` as independent
fields; nothing in the contract or in `DioWalletRepository._parse` says the gift is a *component* of
the balance. Ship `{amount} starter credit` (today's shape, `wallet_hub_l10n.dart:53`) and record
"is `giftCredit` additive or included?" as an open question for the W1m owner. Placing the pill
inside the hero already carries the intended affinity without asserting arithmetic we cannot verify.

### 3.4 Affordability note → `JeebInfoNote`

HTML `:29-35`: `margin 12/24/0`, `padding 13px 16px`, `border-radius 16`, `background rgb(234,244,236)`,
row gap 12; 20px filled check-circle `#2E7D32`; title 14/w700 navy; sub 12/w500 periwinkle.

```dart
Semantics(
  identifier: 'wallet_affordability_card',
  container: true,
  child: JeebInfoNote(
    tone: _affordabilityTone(affordability),     // success | warning
    icon: _affordabilityIcon(affordability),
    title: copy.affordabilityTitle(affordability),
    body: copy.affordabilityBody(affordability),
  ),
)
```

Token map (plan §4.1 rows "positive tint (23)" and "KYC quality green (22)"):

| HTML | token |
|---|---|
| `rgb(234,244,236)` | `context.jeebRoles.successContainer` (`#DCFCE7`) — **REFUSE** `--jeeb-success #43A047`, it breaks the WCAG gate |
| `#2E7D32` glyph | `context.jeebRoles.success` (`#1B7A3D`) |
| title 14/w700 navy | `context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)` on `cs.onSurface`, kit-internal |
| sub 12/w500 periwinkle | kit-internal 12.5/w500 on `mutedText` |

**Icons must become filled (R10).** `_affordabilityIcon` (`:335-346`) ships four `_outlined`
variants; the board draws solid glyphs everywhere:

| state | today | target |
|---|---|---|
| `enough` | `Icons.check_circle_outline` | `Icons.check_circle` |
| `low` | `Icons.warning_amber_outlined` | `Icons.warning_rounded` |
| `empty` | `Icons.account_balance_wallet_outlined` | `Icons.account_balance_wallet` |
| `allReserved` | `Icons.lock_clock_outlined` | `Icons.lock` |

`_affordabilityTone` (`:350-359`) keeps its exact branching — `enough` → success, everything else →
warning. Today it returns a `(Color, Color)` record built from `roles.warningContainer/
onWarningContainer`; convert it to return a `JeebInfoNoteTone` enum so the color pair lives in the
kit (§7.3 keeps the file token-clean either way, but the enum is what stops the fourth lane from
inventing a fifth grey panel).

**The board only draws the `enough` state.** The other three are not in the design and must not be
dropped — D43 and `wallet_hub_screen_test.dart:125-146` both depend on them, and Maestro AC6 drives
`wallet_state=insufficient`.

### 3.5 Reserve note → `JeebInfoNote(tone: outlined, trailing: value)`

HTML `:37-44`: `margin 12/24/0`, `padding 13px 16px`, `border-radius 16`,
`border 1.5px --jeeb-brown-outline`, gap 12; 19px filled navy padlock; title `Reserved right now`
14/w700 navy; sub `1 live offer · released if you're not picked` 12/w500 periwinkle; trailing
`$0.80` 16/w800 navy.

- `1.5px --jeeb-brown-outline` → `cs.outline` (`#916F66`) at width 1.5. **No shadow** (R7).
- r16 → `OmdsBorderRadius.medium`.
- padlock → `Icons.lock` on `cs.primary`.
- value → `MoneyFormat.format(b.reservedNow, currency: b.currency)` in
  `context.jeebText.cardTitle.copyWith(fontWeight: FontWeight.w800)` (15.5/w800 vs the board's
  16/w800 — a stated 0.5px divergence).

**`1 live offer` is a data gap — omit it, do not fake it.** `WalletBalance` carries `reservedNow`
(an amount) and no count; §7.6 lists "reserved-amount breakdown (23)" among the still-genuinely-
suspect items and `DioWalletRepository._parse` reads no such field. Ship the second half of the
sentence only:

```dart
// TODO(redesign-24): the board's "1 live offer" needs a live-reserve COUNT —
// WalletBalance has the amount only. Omitted, not faked.
```

Today's hint copy (`wallet_hub_l10n.dart:60`) already says the honest thing in longer form; shorten
it to the board's `Released if you're not picked` and keep the count out.

### 3.6 Top-up CTA → `JeebCtaButton(primary, inline)`

HTML `:46-49`: wrapper `padding 16px 24px 0`; pill `height 56`, `border-radius 999`, navy fill,
white, gap 10, 16.5/w600, `box-shadow rgba(11,19,81,.28) 0 10px 24px`; leading 19px white `+`.

```dart
Semantics(
  identifier: 'wallet_topup_cta',
  button: true,
  container: true,
  child: JeebCtaButton(
    variant: JeebCtaVariant.primary,
    placement: JeebCtaPlacement.inline,      // §5 #2 — 23's CTA is mid-flow, not docked
    height: 56,
    leading: Icons.add,
    label: copy.topUpCta,                    // "Top up wallet"
    onTap: () => _onTopUp(context),
  ),
)
```

Shadow = `JeebShadows.ctaNavy` (`0 10 24 rgba(11,19,81,.28)`) — byte-exact. Type = `jeebText.button`
(17/w600 vs the board's 16.5/w600).

**`_onTopUp` (`:306-314`) and `_isOffline` (`:316-324`) are unchanged** — the D35 offline money
guard and its "no `OfflineCubit` in the tree ⇒ treat as online" fallback are load-bearing
(§7.4 "never delete a `_resolve*()` fallback branch") and the board says nothing about them.

### 3.7 Fee link → `JeebCtaButton(accentText)`

HTML `:50`: `margin-top 10`, centered, 13/w700, `--jeeb-orange`.
Copy: `How fees work — the 10%, explained`.

```dart
JeebCtaButton(
  variant: JeebCtaVariant.accentText,       // ink = context.jeebRoles.accent (#D73B00)
  label: copy.howFeesWork(kJeebCommissionPercent),
  onTap: () => _showHowFees(context),
)
```

`#D73B00` on white is 4.66:1 — AA passes. This is the **only** orange text on the screen, and it is
sanctioned by R5 ("Orange text: … `How fees work`"). Today the same element is an
`OmdsPrimaryButton(variant: text)` which paints `onSurfaceVariant` — a real visual change.

**The `10%` must be a placeholder.** See §11-C1.

### 3.8 Grouped list card → `JeebOutlinedCard` + 2× `JeebListRow`

HTML `:53-65`: `margin 18/24/0`, `border 1.5px --jeeb-brown-outline`, `border-radius 16`; rows
`padding 14px 16px` gap 12; 19px navy glyph; title 14/w700 navy; sub 11.5/w500 periwinkle; trailing
16px periwinkle chevron; divider `height 1, background --jeeb-surface-highest, margin 0 16px`.

```dart
JeebOutlinedCard(
  radius: OmdsBorderRadius.medium,            // 16
  padding: EdgeInsets.zero,                   // rows own their padding
  dividers: true,                             // 1px cs.outlineVariant, inset 16
  children: [
    Semantics(identifier: 'wallet_earnings_row', button: true, container: true,
      child: JeebListRow(
        icon: Icons.show_chart,                        // the board's polyline path
        title: copy.earningsRow,                       // "Earnings"
        subtitle: copy.earningsRowSubtitle,            // "Cash collected, fees paid"
        onTap: () => context.goNamed('earnings'),
      )),
    Semantics(identifier: 'wallet_see_all_activity', button: true, container: true,
      child: JeebListRow(
        icon: Icons.article,                           // the board's lined-square path
        title: copy.seeAllActivity,                    // "All activity"
        subtitle: copy.seeAllActivitySubtitle,         // "Top-ups, reserves, releases"
        onTap: () => context.goNamed('wallet-activity'),
      )),
  ],
)
```

Glyphs, decoded from the SVG paths: `:1389` `M3.5 18.5 9 13l4 4 7.6-8.6…` = `Icons.show_chart`;
`:1398` `M19 3H5a2 2 0 0 0-2 2v14…` = `Icons.article`. Today's `Icons.insights_outlined` /
`Icons.receipt_long_outlined` (`:277`, `:294`) are outline variants — R10 bans them.

Chevron: `DirectionalIcons.disclosure(context)` at 16px on `mutedText`, kit-internal. `OmdsSettingsRow`
does not mirror and does not carry the outlined-group treatment, which is why it goes.

### 3.9 Docked trust line — NET NEW

HTML `:66-67`: `flex:1` spacer, then `padding 0 24px 30px`, centered, 11.5/w500 periwinkle:
`Customer cash never passes through this wallet.`

```dart
SliverFillRemaining(
  hasScrollBody: false,
  child: Align(
    alignment: AlignmentDirectional.bottomCenter,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge, Spacing.large, Spacing.xLarge, Spacing.twoXLarge - 2),
      child: Semantics(
        identifier: 'wallet_cash_disclaimer',
        container: true,
        child: Text(copy.cashDisclaimer,
            textAlign: TextAlign.center,
            style: context.jeebText.caption.copyWith(color: semantic.mutedText)),
      ),
    ),
  ),
)
```

`caption` is 11.5/w600 vs the board's 11.5/w500 — stated divergence, size exact.

This line is the best copy on the board and it is *true*: the wallet is fee-only, prepaid, and the
customer pays the Jeeber in cash (D41/D44, `wallet_charge_info_screen.dart:6-16`). It reinforces the
same claim the charge-info screen makes and belongs in the l10n batch verbatim.

### 3.10 The how-fees explainer sheet (`_HowFeesSheet`, `:367-409`)

Not on the board (it is a modal). Restyle lightly, keep the identifier and all three bullets:

- Sheet surface: `JeebShadows.sheet` (`0 −4 24 rgba(11,19,81,.08)`) via `showModalBottomSheet`'s
  `shape: RoundedRectangleBorder(borderRadius: OmdsBorderRadius.topLarge)`.
- Title `:391-393`: `theme.textTheme.titleLarge.copyWith(w700)` → `context.jeebText.h2`.
- `_FeeBullet` check glyph `:426`: `Icons.check` on `cs.primary` → keep; size 18 is fine (R10's
  18–20 band).
- `OmdsPrimaryButton` `:400-403` → `JeebCtaButton(variant: primary)`.
- Line 1 (`:68-71`) hardcodes `10%` in the string — must become `{rate}` (§11-C1).

---

## 4. Tokens — every hardcoded value that changes

The file is already `Color(0x`-free (the gate enforces it). The drift is in **shape, weight and
elevation**, exactly as §3 of the plan predicts:

| today | where | becomes | evidence |
|---|---|---|---|
| `BorderRadius.circular(12)` | `_Banner:465` | deleted with `_Banner`; kit uses r16 | HTML `:29`, `:37`, `:53` all `border-radius: 16px` |
| `RefreshIndicator` | `:106` | `OmdsPullToRefresh` | `tool/check_design_tokens.sh` bans the raw widget (pre-existing violation) |
| `EdgeInsetsDirectional.fromSTEB(16, 20, 16, 32)` | `:133-138` | `fromSTEB(24, 16, 24, 0)` + a docked footer | HTML gutters are 24 (`margin: … 24px …` on every block); plan §4.3 `--screen-gutter: 24` → `Spacing.xLarge` |
| `headlineMedium.copyWith(w700)` | `:177-178` | `context.jeebText.statHero` (38/w800/−1.0) | HTML `:23` `font-size:38px; font-weight:800; letter-spacing:-1px` |
| `bodyMedium` on `onSurfaceVariant` (balance label) | `:167-169` | `JeebSectionLabel` (12.5/w700/+1.2/uppercase/`mutedText`) | HTML `:22` |
| `titleMedium` on `onSurfaceVariant` (currency) | `:183-186` | `bodySmall.copyWith(w700)` on `mutedText` | HTML `:23` 14/w700 periwinkle |
| `titleSmall.copyWith(w700)` (banner title) | `:478-479` | kit-internal 14/w700 navy | HTML `:32`, `:40` |
| `bodyMedium` (banner body) | `:484` | kit-internal 12.5/w500 `mutedText` | HTML `:33`, `:41` |
| `bodyLarge` / `bodySmall` (`_StatRow`) | `:521`, `:526-528` | kit-internal, as above | HTML `:40-41` |
| `titleMedium.copyWith(w700)` (reserve value) | `:537-538` | `cardTitle.copyWith(w800)` | HTML `:43` 16/w800 |
| `theme.colorScheme.surfaceContainerHighest` as banner fill | `_Banner:459` | `jeebRoles.successContainer` (affordability) / `surfaceContainerHigh` (KYC note) | HTML `:29` `rgb(234,244,236)`; plan §4.1 "positive tint (23)" |
| no shadow anywhere | — | `JeebShadows.heroNavy` on the hero, `JeebShadows.ctaNavy` on the CTA, **nothing else** | HTML `:20` and `:47` are the only two `box-shadow` declarations on the screen; R7 — a white card with a shadow does not exist on this board |
| no outline anywhere | — | `cs.outline` @1.5px on the reserve note + the grouped card | HTML `:37`, `:53` |
| `_fmt` → bare `6.40` | `:361` | `MoneyFormat.format` → `$6.40` LTR-isolated | HTML `:23`, `:43`; `money_format.dart:33` |
| `Icons.*_outlined` ×7 | `:151`, `:199`, `:229`, `:277`, `:294`, `:337-344` | filled equivalents | R10: "filled, single-colour, five sizes … no outline or two-tone variants anywhere" |

**No new theme symbol is needed.** Everything above resolves through Wave-0 output
(`context.jeebText`, `JeebShadows`, `context.jeebRoles`, `Theme.of(context).extension<JeebSemanticColors>()!`)
plus `OmdsBorderRadius` / `Spacing`. Do not open `lib/core/theme/*` (§4.6, frozen).

---

## 5. Shared components consumed

| kit widget (§5) | replaces | notes for the kit lane |
|---|---|---|
| #1 `JeebTopBar` | `OMDSAppBar` `:83-92` | needs `leading: back` + `identifier` + `onBack`. No trailing slot on 23 |
| #2 `JeebCtaButton` | `OmdsPrimaryButton` ×2 `:243`, `:256` | needs **`placement: inline`** (23's CTA is mid-flow, not docked — §5 #2 already calls this out), a **leading glyph**, and the **`accentText`** variant |
| #3 `JeebOutlinedCard` | — (new grouping) | needs `dividers: true` (inset 1px `outlineVariant`, margin-inline 16) and `padding: EdgeInsets.zero` so rows own their padding |
| #4 `JeebNavySurfaceCard` | — (new hero) | needs `shadow: JeebShadows.heroNavy` **and** a `ring` corner parameter — 23's ring is **bottom-END**, not top-END (see §3.2). Radius 20, pad 20 |
| #10 `JeebSectionLabel` | `Text(bodyMedium)` `:166-169` | the 12.5 default is exact. Used on navy — its `mutedText` ink is AA there (4.53:1), no override needed |
| #22 `JeebInfoNote` | `_Banner` ×2, `_StatRow` | **three asks**: a `warning` tone (`jeebRoles.warningContainer`/`onWarningContainer`) for the three non-healthy affordability states; an `outlined` tone (white + 1.5px `cs.outline`) for the reserve row; and the already-specced `trailing: value` slot |
| #25 `JeebListRow` | `OmdsSettingsRow` ×2 `:274`, `:291` | 23 is the widget's primary consumer alongside 20. Chevron via `DirectionalIcons.disclosure` |

**Not from the kit:** the on-navy starter-credit pill. It is a one-screen shape (on-navy, orange
translucent, emoji-led) and #6 `JeebSelectChip` has no on-navy unselected treatment. Keep it a
private `_GiftPill` in `wallet_hub_screen.dart`.

**Nothing goes into OMDS** — CI checks OMDS out fresh from GitHub (§5 preamble).

---

## 6. New functionality & data

**There is none.** This is the cleanest screen on the spine in that respect: the board asks for no
new interaction, no new state, no new fetch. `WalletHubCubit` (`application/wallet_hub_cubit.dart`),
`WalletHubState` and `WalletRepository` are **untouched**. Do not add a field, do not add a method,
do not touch DI.

Three board facts and their honest disposition:

| board fact | source? | disposition |
|---|---|---|
| `$6.40` / `USD` | `WalletBalance.availableBalance` + `.currency` | **buildable** — via `MoneyFormat` |
| `$5.00 starter credit` | `WalletBalance.giftCredit` (D42) | **buildable**. The word `included` is not — §3.3 |
| `$0.80` reserved | `WalletBalance.reservedNow` | **buildable** |
| `1 live offer` | nothing on `WalletBalance`, nothing in `DioWalletRepository._parse` | **omit + `TODO(redesign-24)`** (§3.5). §7.6 already lists "reserved-amount breakdown (23)" as suspect — confirmed |
| `the 10%` (×2) | `kJeebCommissionPercent` (`lib/core/jeeb_commission.dart:80`) | **buildable, and mandatory** — §11-C1 |

DI note: `injection_container.dart` still binds `StubWalletRepository`
(`data/stub_wallet_repository.dart`), which returns `availableBalance: 120.0, reservedNow: 0.0,
giftCredit: 50.0, enough`. So in a local run the reserve note reads `$0.00` and the hero reads
`$120.00`. That is the stub, not a bug — **do not "fix" the stub to match the render's $6.40** and
do not repoint DI (W1m is backend-owned, CTO-D2, and `injection_container.dart` is integrator-owned
under §7.4).

---

## 7. New routes

**None.** Every destination already exists and is already reached by name:

| edge | target | registered at |
|---|---|---|
| `wallet_topup_cta` | `goNamed('wallet-charge-info')` | `app_router.dart:1634` |
| `wallet_earnings_row` | `goNamed('earnings')` | `app_router.dart:1646` |
| `wallet_see_all_activity` | `goNamed('wallet-activity')` | `app_router.dart:1658` |
| back | `canPop ? pop : go('/')` | `backFallbacks['wallet'] = '/'`, `app_router.dart:505` |

`app_router.dart` must not be edited by this lane.

---

## 8. RTL

Everything on this screen mirrors, and three things will break if built carelessly:

1. **The decorative ring.** `right: -50px; bottom: -50px` must be
   `PositionedDirectional(end: -50, bottom: -50)` inside the kit widget — a `Positioned(right:)`
   would put it on the wrong side in Arabic and clip against the text.
2. **Money.** `MoneyFormat.format` already wraps in `U+2066 … U+2069`
   (`money_format.dart:26-37`), so `$6.40` keeps its symbol placement inside an Arabic paragraph.
   Today's `'${_fmt(...)} $currency'` (`:231`) is **not** isolated and reorders in `ar` — this
   proposal fixes a live RTL defect.
3. **Glyph direction.** Back arrow → `DirectionalIcons.back(context)`; row chevron →
   `DirectionalIcons.disclosure(context)`. Both live inside kit widgets; verify in the kit's RTL
   smoke test, not here.

Everything else is directional by construction: `EdgeInsetsDirectional` for all padding (already
the file's habit — `:133`, `:146`, `:420`), `AlignmentDirectional.bottomCenter` for the footer,
`CrossAxisAlignment.start` in Columns, and `Row` (which mirrors automatically).

The centered elements (fee link, trust line) use `TextAlign.center` and are direction-neutral.

**200% text scale:** the hero's baseline `Row` (`$6.40` + `USD`) is the one overflow risk — 38px at
2× is 76px and the suffix adds ~40px of width. Wrap it in a `Flexible` + `FittedBox(fit: BoxFit.scaleDown,
alignment: AlignmentDirectional.centerStart)` on the amount only. The `SliverFillRemaining` shape
guarantees the rest scrolls rather than overflowing.

---

## 9. l10n

Copy that changes. **The lane can land all of it immediately in
`wallet_hub_l10n.dart`'s `_pick(en, ar)` maps** — that file exists precisely for this
(`wallet_hub_l10n.dart:6-24`) and is lane-owned, so this screen is **not blocked on the integrator
batch**. The integrator later folds the keys into `app_en.arb` / `app_ar.arb` + getters with no
call-site change.

| getter | EN today | EN target | note |
|---|---|---|---|
| `availableBalanceLabel` | "Available balance" (`app_en.arb:4421`) | **"Available to bid"** | the ARB key `walletAvailableBalanceLabel` has exactly **one** consumer (`wallet_hub_l10n.dart:47`) — its value can be changed in place |
| `topUpCta` | "Top up" (`app_en.arb:4423`) | **"Top up wallet"** | ⚠️ **do NOT change this ARB value** — `walletTopUpCta` is also read by `kyc_status_view.dart:515,737` and `offer_composer_l10n.dart:163`. Add a **new** key `walletTopUpWalletCta` (or a lane-local `_pick`) |
| `giftBadge(amount)` | "{amount} {currency} starter credit" | "{amount} starter credit" | amount now carries its own symbol from `MoneyFormat`, so drop the trailing currency arg |
| `affordabilityTitle(enough)` | "Ready to bid" | **"You're set to bid"** | designer note: "affordability is honest state copy ('You're set to bid')" |
| `affordabilityBody(enough)` | "You have enough to place offers." | **"Enough balance for the {rate}% reserve on typical offers."** | `{rate}` ← `kJeebCommissionPercent` |
| `reservedNowLabel` | "Reserved now" | **"Reserved right now"** | HTML `:40` |
| `reservedNowHint` | "Held against your live offers — released when each offer is decided." | **"Released if you're not picked."** | HTML `:41`, minus the unbuildable count |
| `howFeesWork` | "How fees work" | **"How fees work — the {rate}%, explained"** | HTML `:50` |
| `earningsRow` / subtitle | "Earnings & fees" / "Your net cash and the fees you've paid." | **"Earnings"** / **"Cash collected, fees paid"** | HTML `:56` |
| `seeAllActivity` / subtitle | "See all activity" / "Reserves, fees, refunds and top-ups." | **"All activity"** / **"Top-ups, reserves, releases"** | HTML `:62` |
| `cashDisclaimer` | — | **"Customer cash never passes through this wallet."** | NEW, HTML `:67` |
| `feesExplainerLine1` | "You only pay a flat 10% fee on offers you win." | "You only pay a flat {rate}% platform fee on offers you win." | §11-C1 + D41/D44 |

Every one needs a **real** Arabic value (the parity gate fails both directions, §7.4). Suggested AR
for the new strings: `متاح للمزايدة` · `اشحن المحفظة` · `أنت جاهز للمزايدة` ·
`رصيدك يكفي لحجز الـ{rate}٪ على العروض المعتادة.` · `محجوز الآن` · `يُعاد إليك إذا لم يقع الاختيار عليك.` ·
`كيف تعمل الرسوم — شرح الـ{rate}٪` · `الأرباح` · `النقد المُحصَّل والرسوم المدفوعة` · `كل النشاط` ·
`الشحن والحجوزات والإفراجات` · `نقود العميل لا تمر أبداً عبر هذه المحفظة.`

---

## 10. Test impact

### 10.1 Breaks, legitimately — `test/features/wallet/wallet_hub_screen_test.dart`

| test | line | why it breaks | fix |
|---|---|---|---|
| `AC6/D43: healthy state shows "Ready to bid" copy` | `:118-123` | the designer note explicitly renames this state to **"You're set to bid"** | update the two `find.text` strings. **Legitimate** — the copy change is the note's headline item |
| `AC6/D43: low state …` | `:125-135` | asserts `find.text('Ready to bid'), findsNothing` | update the negative string to "You're set to bid" |
| `AC6/D43: all-reserved …` | `:137-146` | same | same |

`'Running low'` and `'Everything is reserved'` are unchanged, so those positive assertions stand.

**Everything else in that file passes untouched**, and that is the proposal's strongest self-check:
`AC1` (`:80-96`, nine identifiers), `D42` gift gating (`:98-105`), `AC3` sheet open (`:107-116`),
`AC7` ×2 (`:148-166`) and the failed-load guard (`:168-178`) all assert on identifiers and on
cubit-driven conditions, none of which move.

⚠️ `pump()` uses `tester.pumpAndSettle()`. Nothing added here animates, so no timeout risk.

### 10.2 Passes untouched

- `test/core/router/w2_routes_resolve_test.dart:190-197` — asserts `find.byType(WalletHubScreen)`
  after `goNamed('wallet')`. The class name and constructor seams (`this.repository`,
  `this.kycStatusGate`) are preserved verbatim, so this cannot break. **Never delete those seams**
  (§7.4).
- `test/features/notifications/notifications_list_screen_test.dart:368-381` — dispatches
  `low_balance` / `fee_won` to a **stub** `/wallet` route; independent of this file.
- `test/core/router/back_nav_all_routes_test.dart:107,195` — router-level only. Preserving
  `canPop ? pop : go('/')` on `JeebTopBar.onBack` keeps the runtime behaviour that pairs with
  `backFallbacks['wallet']`.
- `test/core/theme/no_raw_semantic_colors_test.dart:33` — asserts the file **exists at this path**
  and holds no raw color. Do not move or rename `wallet_hub_screen.dart`.
- `test/core/jeeb_commission_test.dart` — a source scan of `lib/**.dart` for a second `0.10`
  literal in commission context. Using `kJeebCommissionPercent` keeps it green; typing `10` into a
  Dart string near the word "reserve" would trip it.

### 10.3 Goldens

**None exist for wallet** (`find test -name '*.png'` → only `active_delivery_jeeber` and
`order_history`). Nothing to regenerate.

### 10.4 Gates

`tool/check_design_tokens.sh` currently reports **8 pre-existing violations, 2 of them in this
file** (`BorderRadius.circular(12)` at `:465`, `RefreshIndicator` at `:106`). This proposal removes
both as a side effect. That is a bonus, not a requirement — do not touch the other six
(`settlement_screen.dart` ×2, `settlement_detail_screen.dart`, `client_location_screen.dart`,
`wallet_activity_list_screen.dart`, `reviews_list_screen.dart`); they belong to other lanes.

### 10.5 New tests to add (additive only)

- `wallet_back` and `wallet_cash_disclaimer` render (one `find.bySemanticsIdentifier` each).
- An RTL smoke: pump under `Locale('ar')`, assert no overflow and that the hero amount still
  contains the U+2066 isolate.

---

## 11. Conflicts — what the board asks for that we refuse

**C1 (D41/D44 + single-rate rule) — the board types `10%` three times.**
`How fees work — the 10%, explained` (`:50`) and `Enough balance for the 10% reserve on typical
offers.` (`:33`), plus today's `feesExplainerLine1` ("a flat 10% fee"). The plan's locked rule is
"`kJeebCommissionRate` is the only numeric copy of the rate … compute, never hardcode" (§7.2), and
`lib/core/jeeb_commission.dart:80` ships `kJeebCommissionPercent` for exactly this display case.
**Refuse the literal; ship `{rate}` placeholders.** Also confirm the explainer never says
"Commission" — `decision_violations_test.dart:206` asserts `findsNothing` on that word for the
earnings surface, and D41/D44 governs the framing app-wide. Today's copy says "fee", which is fine;
prefer **"platform fee"**.

**C2 — `1 live offer` (HTML `:41`).** Refused as fabricated data. `WalletBalance` has no count.
Omit with `TODO(redesign-24)`. §7.6 already flagged the reserved-amount breakdown as suspect; this
confirms it. (JEBV4-176 is the precedent for why a plausible placeholder is worse than an absence.)

**C3 — `starter credit included` (HTML `:25`).** Refused as an unverifiable claim: the gateway
contract does not define whether `giftCredit` is a component of `availableBalance`. Ship
`{amount} starter credit`. This is a wording downgrade, not a layout change — the pill, its
position and its treatment are all built as drawn.

**C4 — the `$` symbol (HTML `:23`, `:43`).** *Not* a refusal, a correction of how it must be built:
never typed, always `MoneyFormat.format`, which is currency-aware and LTR-isolated. Typing `'\$'`
would break the moment the gateway returns a non-USD currency, which `DioWalletRepository._parse`
explicitly tolerates.

**Nothing else on this screen conflicts with a locked decision.** Specifically checked and clear:
D42 (gift badge gates on `giftCredit > 0` — preserved), D43 (state copy, not a capacity number — the
board *strengthens* this, which is the note's whole point), D35 (offline money guard — untouched),
D92/D93 (no in-app payment: the board adds no amount field, no card input, no store directory),
D38/D39 (KYC-pending banner — kept even though the board omits it), B04/D56/D52/D20 (not applicable
to this screen).

One documentation nit: §6 Wave 2 of the plan says "keep `JeeberKycGateBuilder` at
`wallet_hub_screen.dart:61`". Line 61 is `final gate = kycStatusGate ?? sl<JeeberKycStatusGate>();` —
the screen uses the **`JeeberKycStatusGate` interface**, not the `JeeberKycGateBuilder` widget
(`jeeber_kyc_status_gate.dart:241`). The intent is right; preserve line 61 and the `kycStatusGate`
constructor seam exactly as written.

---

## 12. Risks

1. **Density is the whole change here (risk #13).** Four of the five blocks already exist in the
   same order; if a reviewer only diffs the token swaps, the screen will still look like today's.
   The proof is the `SliverFillRemaining` and the 24px gutters — compare against `23-wallet.png` at
   the same scale, not against a checklist.
2. **`JeebInfoNote` is on the critical path and needs three tones, not two.** 23 alone consumes
   `success`, `warning` and `outlined`. If the kit ships only `muted`/`success`/`accent`, this lane
   hand-rolls two panels and R7 drifts. Raised as a wiring request.
3. **The hero ring corner contradicts the plan text.** Someone building `JeebNavySurfaceCard` from
   §5 #4 alone will hard-code top-END and 23 will be wrong. Raised.
4. **`walletTopUpCta` is shared with two other features.** Changing its ARB value would silently
   restyle the KYC-pending and insufficient-balance CTAs. Called out in §9; the safe move is a new
   key.
5. **The stub makes the screen look wrong locally.** `StubWalletRepository` returns `$120.00 / $0.00
   / $50.00`; the reserve note will read `$0.00` and the pill `$50.00 starter credit`. Do not chase
   the render's numbers by editing the stub.
6. **Periwinkle on white.** The board's subtitles and trust line are `#777FC0` on white, which
   `color_role_contrast_test.dart:129-140` documents as *failing* AA. The plan sanctions `mutedText`
   for exactly these decorative/secondary roles and the guard only fires on `onSecondaryContainer`,
   so nothing goes red — but this screen has four such strings and it is an accessibility debt the
   whole board carries. Flagging, not refusing.

---

## 13. Wiring requests

**To the Wave-1 kit lane** (blocking; all are additive to widgets already specced):

1. `JeebInfoNote` — add a **`warning`** tone (`jeebRoles.warningContainer` / `onWarningContainer`)
   and an **`outlined`** tone (white + `1.5px cs.outline`, no shadow). Confirm the `trailing: value`
   slot from §5 #22 is real.
2. `JeebNavySurfaceCard` — the decorative ring corner must be a **parameter**; 23 needs
   **bottom-END** (`right:-50, bottom:-50`, Ø170, `1.5px accentRing`), not the top-END the plan text
   assumes. Placed with `PositionedDirectional`.
3. `JeebCtaButton` — confirm `placement: inline` (non-docked), a **leading glyph** slot, and the
   **`accentText`** variant.
4. `JeebOutlinedCard` — `dividers: true` with a 1px `cs.outlineVariant` line inset 16 on both sides,
   and `padding: EdgeInsets.zero` so grouped rows own their own padding.
5. `JeebTopBar` — `leading: back` + `identifier` + `onBack`; no trailing slot needed for 23.
6. `JeebListRow` — chevron via `DirectionalIcons.disclosure`, filled navy leading glyph, subtitle in
   `mutedText`.

**To the integrator** (non-blocking — the lane ships via `wallet_hub_l10n.dart` first):

7. The 12 ARB keys in §9, EN + real AR + getters, **with a new `walletTopUpWalletCta` rather than a
   value change to `walletTopUpCta`**.

**To the owner** (non-blocking, record the answer):

8. Is `WalletBalance.giftCredit` **included in** or **additive to** `availableBalance`? The board's
   copy asserts "included"; the contract does not say. Until answered we ship the neutral wording.
