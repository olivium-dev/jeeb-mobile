# 23 · Wallet — REVISED instruction set (authoritative)

**Target file:** `lib/features/wallet/presentation/wallet_hub_screen.dart` (543 LOC) — plus the
lane-owned `wallet_hub_l10n.dart` and `test/features/wallet/wallet_hub_screen_test.dart`.
**Verdict: restyle** — confirmed. Same data, same route (`app_router.dart:1617` `/wallet`), same
section order, all 11 identifiers survive unmoved. Every `file:line` in the Opus proposal was
re-checked on 2026-08-03 against the render, the HTML, the source, the kit source, the widget
tests, the Maestro flow and both plan docs. Where this document contradicts the proposal, **this
document wins.**

**Kit status (the big delta): Wave 1 SHIPPED.** All six of the proposal's "blocking kit wiring
requests" (§13 items 1–6) are already satisfied in-tree and are **CUT**:

| proposal asked for | shipped as |
|---|---|
| `JeebInfoNote` `warning` + `outlined` tones, `trailing` slot | `JeebInfoNoteTone { muted, accent, success, warning, outlined, error }`; the kit's own doc comment (`jeeb_info_note.dart:74-79`) is literally 23's outlined-reserve-with-trailing-money example |
| `JeebNavySurfaceCard` bottom-END ring parameter | `JeebNavyRing.statBottomEnd` preset — "23: Ø170, bottom −50, end −50" (`jeeb_navy_surface_card.dart:42`, kit doc §2.1) |
| `JeebCtaButton` inline placement / leading glyph / accentText | `leadingIcon:` + `JeebCtaVariant.accentText` exist; "inline" is **not a `JeebCtaButton` param** — it is `JeebCtaFooter.inline` (`fromSTEB(24, 16, 24, 0)`, annotated "// 23" in the kit doc §2.2) |
| `JeebOutlinedCard` dividers + zero padding | `JeebOutlinedCard.grouped(children:, dividers: true)` — padding defaults to zero, divider is 1px `outlineVariant` inset 16 directional |
| `JeebTopBar` back + identifier | `identifier:` lands on the leading Ø40 circle — the kit owns the `<screen>_back` contract |
| `JeebListRow` mirrored chevron, filled glyph | shipped; note the audit renames: `padding:` (was `contentPadding`), `isEnabled:` (was `enabled`) |

Consume via `import '../../../core/widgets/jeeb/<file>.dart';`. The kit is frozen — never edit it,
never hand-roll a private copy of any of the above.

---

## A. Deltas from the Opus proposal (audit trail — implementer follows THIS doc)

**Cut / overruled:**
1. **All six kit wiring requests — CUT** (see table above). The only wiring request left is the
   non-blocking l10n batch (§E).
2. **Risk 3 ("hero ring corner contradicts the plan text") — RESOLVED.** The kit already ships
   `statBottomEnd`; no one can build it wrong now.
3. **§3.10 how-fees-sheet restyle — CUT to copy-only.** The sheet is a modal and is not on the
   board; "the render is the spec" cuts both ways. Keep `_HowFeesSheet` structurally byte-identical
   (identifier, `explicitChildNodes`, three `_FeeBullet`s, `OmdsPrimaryButton`). The ONE mandatory
   change is in copy, not pixels: `feesExplainerLine1` must derive its `10%` from
   `kJeebCommissionPercent` and say "platform fee" (§7.2 single-rate rule + D41/D44) — that lands
   in the l10n resolver (task 1), zero edits inside the sheet widget.
4. **`OmdsBorderRadius.large` as the hero's radius arg — CUT.** Kit `radius:` params are plain
   `double`s (kit doc §1.2). Pass `radius: Spacing.large` (20.0); the outlined notes and the grouped
   card keep their kit default of 16 — pass nothing.

**Corrected (factually off in the proposal):**
1. **`JeebInfoNote` body param is `text:`, NOT `body:`.** The kit audit flags exactly this —
   "Any draft calling `JeebInfoNote(body: …)`: the parameter is `text:` (23's drafts)"
   (03-WAVE1-KIT §3).
2. **`JeebTopBar` callback is `onLeadingPressed:`, not `onBack:`** (`jeeb_top_bar.dart:112`); the
   a11y label rides on `leadingTooltip:`.
3. **`JeebNavySurfaceCard` takes `rings: <List<JeebNavyRing>>`, not `ring:`** — pass
   `rings: const [JeebNavyRing.statBottomEnd]`. Padding is `EdgeInsetsGeometry`, default 14/16 —
   pass `EdgeInsetsDirectional.all(Spacing.large)` for the board's 20.
4. **There is no `JeebCtaPlacement`.** The CTA block is `JeebCtaFooter.single(padding:
   JeebCtaFooter.inline, below: <fee link>, child: <top-up pill>)` — its default `spacing: 10`
   is byte-exact the HTML's `margin-top: 10` on the fee link, and `.single` applies no SafeArea
   (kit doc: "23's inline form must not gain a bottom inset").
5. **`JeebSemanticColors` must be read defensively in this file — never with `!`.**
   `test/support/sync_app_localizations.dart:42` builds every widget test on `ThemeData.light()`
   (no extensions); a bang would crash all 9 wallet tests. Use the kit's own pattern
   (`jeeb_profile_header.dart:252-256`):
   `final semantic = Theme.of(context).extension<JeebSemanticColors>() ?? JeebSemanticColors.light();`
   (`context.jeebText` / `context.jeebRoles` already fall back safely.)
6. **`jeeb_commission_test.dart` does NOT fire on a `10` typed inside a string** — its regex is
   the decimal literal `0\.10*` near commission-context words. The `{rate}` mandate stands anyway,
   on the plan's single-rate rule (§7.2: "compute, never hardcode") — the correction is only which
   guard enforces it.
7. **`jeebText.bodySmall` is 12/w600** (`jeeb_text_styles.dart:271-273`), not 12/w500 as §3.4's
   token map implies. The USD-suffix `copyWith(w700)` is unaffected.
8. **`JeebCtaButton.accentText` is 13.5/w700** (kit doc §2.2), vs the board's 13/w700 — a 0.5px
   stated divergence, not the proposal's "13/w700 exact".
9. Citation nits: `wallet-activity` route name is at `app_router.dart:1661` (not :1658); the
   `earnings` route block at `:1644-1648`. Destinations and names unchanged — nothing follows
   from this beyond accuracy.

**Kept — verified true, load-bearing:**
- The full §1 identifier inventory: all 11 at `:80/:148/:160/:195/:212/:226/:240/:253/:271/:288/:376`,
  byte-checked. The other wallet-feature screens' identifiers are out of scope.
- The Maestro analysis: `.maestro/flows/jm-053-wallet-hub.yaml` AC1 asserts five ids visible with
  **no `scrollUntilVisible`** — do not move the reserve row below the CTA.
- The ARB analysis: `walletAvailableBalanceLabel` (`app_en.arb:4421`) has exactly one consumer
  (`wallet_hub_l10n.dart:47`) → value-change in place is safe; `walletTopUpCta` (`:4423`) is shared
  with `kyc_status_view.dart:515,737` and `offer_composer_l10n.dart:163` → **must not change**;
  a new key is requested instead.
- C1–C4: `{rate}` placeholders for every `10%`; **omit** `1 live offer` (no count on
  `WalletBalance`, `wallet_repository.dart:17-31`; plan §7.6 lists "reserved-amount breakdown (23)"
  as suspect); **drop the word `included`** from the starter-credit pill (the contract does not
  define whether `giftCredit` composes `availableBalance`); `$` only ever via `MoneyFormat.format`
  (`money_format.dart:54-60` — currency-aware, LTR-isolated; today's `'${_fmt(...)} $currency'` at
  `:231` is a live RTL defect this fixes).
- The token-gate bonus: this restyle deletes both of this file's pre-existing violations
  (`RefreshIndicator:106`, `BorderRadius.circular(12):465`). The other six (settlement ×3 —
  `settlement_screen.dart:222,253` + `settlement_detail_screen.dart:84` —, `client_location_screen.dart:1088`,
  `wallet_activity_list_screen.dart:105`, `reviews_list_screen.dart:181`) belong to other lanes —
  leave them.
- The stub warning: `StubWalletRepository` returns `120.0 / 0.0 / 50.0` — locally the hero reads
  `$120.00` and the reserve `$0.00`. That is the stub, not a bug. Do not edit the stub, do not
  touch DI (`injection_container.dart` is integrator-owned).
- D-sweep: D42 (gift gates on `giftCredit > 0`) kept; D43 (state copy, no capacity number)
  strengthened by the note; D35 offline guard untouched (`_onTopUp:306-314`, `_isOffline:316-324`
  — never delete the no-OfflineCubit fallback); D38/D39 KYC banner kept even though the board
  omits it; D92/D93 clean (no payment affordance added); D56/D52/D20 not applicable.
- The doc nit: `wallet_hub_screen.dart:61` is the `JeeberKycStatusGate` **interface** seam, not a
  `JeeberKycGateBuilder` widget. Preserve line 61 and both constructor seams (`repository`,
  `kycStatusGate`) verbatim — `w2_routes_resolve_test.dart:190-197` and the whole test file
  depend on them.

---

## B. Frozen inventory — all 11 must survive byte-identical

| identifier | today | after |
|---|---|---|
| `wallet_hub_root` | `:80` | unchanged — `container: true`, still wraps the `Scaffold` |
| `wallet_kyc_pending_banner` | `:148` | passed to `JeebInfoNote.muted(identifier:)`; still the first sliver child, still gated on `copy.kycPending` |
| `wallet_available_balance` | `:160` | screen-owned `Semantics` around the content **Column inside** the navy card (not the card — keeps the decorative ring out of the node). Keep `container: true` AND `explicitChildNodes: true` (`:162`) or the nested gift id is swallowed |
| `wallet_gift_badge` | `:195` | screen-owned `Semantics(container: true)` around `_GiftPill`; still gated `giftCredit > 0` (D42) |
| `wallet_affordability_card` | `:212` | passed to `JeebInfoNote(identifier:)` |
| `wallet_reserved_now` | `:226` | passed to `JeebInfoNote.outlined(identifier:)` |
| `wallet_topup_cta` | `:240` | passed to `JeebCtaButton(identifier:)` |
| `wallet_how_fees_work` | `:253` | passed to `JeebCtaButton.accentText(identifier:)` |
| `wallet_earnings_row` | `:271` | passed to `JeebListRow(identifier:)` #1 |
| `wallet_see_all_activity` | `:288` | passed to `JeebListRow(identifier:)` #2 |
| `wallet_how_fees_explainer` | `:376` | unchanged — the sheet is copy-only this wave |

New identifiers (2): `wallet_back` (via `JeebTopBar(identifier:)` — the kit's `<screen>_back`
contract; today's OMDSAppBar back has no id, pure addition) and `wallet_cash_disclaimer`
(screen-owned `Semantics(container: true)` on the docked trust line — non-interactive, no
`button:`).

Frozen non-identifier contracts: the `WalletHubScreen` class name and file path
(`no_raw_semantic_colors_test.dart:33` asserts the path; `w2_routes_resolve_test.dart` finds the
type); both constructor seams; `goNamed('wallet-charge-info' | 'earnings' | 'wallet-activity')`;
the back behaviour `context.canPop() ? context.pop() : context.go('/')` **verbatim with its
comment** — it pairs with `backFallbacks['wallet'] = '/'` (`app_router.dart:505`,
`back_nav_all_routes_test.dart:107,195`).

Color gate: this file is on the migrated list (`no_raw_semantic_colors_test.dart:33`) — no
`Color(0x`, no `Colors.<palette>`, no `.tertiary*`, ever.

---

## C. Tasks — execute in order, no backtracking

Token access in this file: `context.jeebText`, `context.jeebRoles` (if still needed — see task 4),
`JeebShadows`, `Theme.of(context).colorScheme`, `Spacing`/`Sizes`/`OmdsBorderRadius`, and
`JeebSemanticColors` **only** via the defensive read (§A-corrected-5). No `fontSize:`, no
`BorderRadius.circular(<number>)`, no `SizedBox(width|height: <number>)`, no `EdgeInsets.<x>(<number>` —
`tool/check_design_tokens.sh` bans them all in `lib/features/`.

### 1. `wallet_hub_l10n.dart` — all copy, first (everything else renders it)

Import `../../../core/jeeb_commission.dart`. Change getters in place (call-site names stay so the
screen diff stays mechanical); every string needs a REAL Arabic value:

| getter | new EN | new AR | note |
|---|---|---|---|
| `availableBalanceLabel` | `Available to bid` | `متاح للمزايدة` | switch from `_l10n.walletAvailableBalanceLabel` to `_pick(...)`; the ARB value-change is wiring request §E |
| `topUpCta` | `Top up wallet` | `اشحن المحفظة` | switch from `_l10n.walletTopUpCta` to `_pick(...)` — NEVER change that shared ARB key (§A-kept) |
| `giftBadge(String amount)` | `$amount starter credit` | `رصيد بداية $amount` | drop the `currency` param — `MoneyFormat` output carries its own symbol. NOT "included" (C3) |
| `back` (NEW) | `Back` | `رجوع` | `JeebTopBar.leadingTooltip` a11y label |
| `affordabilityTitle(enough)` | `You're set to bid` | `أنت جاهز للمزايدة` | the designer note's headline change; the other three states' titles UNCHANGED (tests pin them) |
| `affordabilityBody(enough)` | `Enough balance for the $kJeebCommissionPercent% reserve on typical offers.` | `رصيدك يكفي لحجز الـ$kJeebCommissionPercent٪ على العروض المعتادة.` | C1 — never a literal `10` |
| `reservedNowLabel` | `Reserved right now` | `محجوز الآن` | |
| `reservedNowHint` | `Released if you're not picked.` | `يُعاد إليك إذا لم يقع الاختيار عليك.` | C2 — the `1 live offer ·` half is omitted, not faked |
| `howFeesWork` | `How fees work — the $kJeebCommissionPercent%, explained` | `كيف تعمل الرسوم — شرح الـ$kJeebCommissionPercent٪` | C1 |
| `earningsRow` / `earningsRowSubtitle` | `Earnings` / `Cash collected, fees paid` | `الأرباح` / `النقد المُحصَّل والرسوم المدفوعة` | |
| `seeAllActivity` / `seeAllActivitySubtitle` | `All activity` / `Top-ups, reserves, releases` | `كل النشاط` / `الشحن والحجوزات والإفراجات` | |
| `cashDisclaimer` (NEW) | `Customer cash never passes through this wallet.` | `نقود العميل لا تمر أبداً عبر هذه المحفظة.` | true per D41/D44 (`wallet_charge_info_screen.dart:6-16`) |
| `feesExplainerLine1` | `You only pay a flat $kJeebCommissionPercent% platform fee on offers you win.` | `تدفع رسوم منصة ثابتة $kJeebCommissionPercent٪ فقط على العروض التي تفوز بها.` | C1 + D41/D44 ("platform fee", never "Commission" — `decision_violations_test.dart:206` pins the framing) |

`feesExplainerLine2/3`, `feesExplainerTitle`, `feesExplainerGotIt`, `kycPendingTitle/Body`,
`offlineMoneyBlocked`, `loadError`, `retry`, `title`, `comingSoon`: unchanged.

### 2. Screen skeleton — top bar out of the scroll, real emptiness below

Add imports: `../../../core/formatting/money_format.dart`,
`../../../core/theme/jeeb_semantic_colors.dart`, `../../../core/theme/jeeb_shadows.dart`,
`../../../core/theme/jeeb_text_styles.dart`, and the kit files
(`jeeb_top_bar.dart`, `jeeb_navy_surface_card.dart`, `jeeb_info_note.dart`, `jeeb_cta_button.dart`,
`jeeb_cta_footer.dart`, `jeeb_outlined_card.dart`, `jeeb_list_row.dart`, `jeeb_section_label.dart`)
from `../../../core/widgets/jeeb/`.

Rework `_WalletHubView.build` (`:77-115`):

```dart
Semantics(identifier: 'wallet_hub_root', container: true,
  child: Scaffold(
    body: SafeArea(
      child: Column(children: [
        JeebTopBar(
          identifier: 'wallet_back',
          title: copy.title,
          leadingTooltip: copy.back,
          // Stack-REPLACING goNamed('wallet') means there is usually nothing
          // to pop — pop when we can, else return to the shell. Pairs with
          // backFallbacks['wallet'] = '/'. KEEP VERBATIM.
          onLeadingPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        Expanded(child: BlocBuilder<WalletHubCubit, WalletHubState>(...)),
      ]),
    ),
  ),
)
```

- `OMDSAppBar` (`:83-92`) is deleted; the top bar now renders in **all** states (loading / failed /
  loaded), which is also 11's corrected pattern.
- loading/failed branches unchanged (`OmdsLoadingState` / `OmdsErrorState` + retry).
- loaded: `RefreshIndicator` (`:106`) → `OmdsPullToRefresh(onRefresh: () =>
  context.read<WalletHubCubit>().refresh(), child: _LoadedBody(...))` — kills the second
  token-gate violation.

In `_LoadedBody`, replace the `ListView` (`:132`) with:

```dart
CustomScrollView(slivers: [
  SliverPadding(
    padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0),   // gutter 24, top 16
    sliver: SliverList(delegate: SliverChildListDelegate([ ...blocks, gaps of
        SizedBox(height: Spacing.small) /* 12 */ between banner/hero/notes,
        SizedBox(height: Spacing.medium) /* 16 */ before the grouped card ])),
  ),
  SliverFillRemaining(hasScrollBody: false, child: /* task 7 */),
])
```

Why `SliverFillRemaining` and not a `Spacer`: content ends at ~66% of the render's height and the
trust line docks at the bottom — "fill the viewport but scroll when it overflows" is R1's real
emptiness, and it is the only shape that survives 200% text scale without overflow. The CTA block
(task 5) carries its own `JeebCtaFooter.inline` padding — no extra gap before it.

Block order is FROZEN (Maestro AC1 has no scroll): [KYC banner] → hero → affordability → reserve →
CTA block → grouped card → (fill) trust line.

### 3. Balance hero — `JeebNavySurfaceCard` + `JeebSectionLabel` + `_GiftPill`

Replace `:159-206` with:

```dart
JeebNavySurfaceCard(
  radius: Spacing.large,                              // 20 — board-exact
  padding: const EdgeInsetsDirectional.all(Spacing.large),
  shadow: JeebShadows.heroNavy,                       // 0 12 28 rgba(11,19,81,.30)
  rings: const [JeebNavyRing.statBottomEnd],          // Ø170, bottom/end −50, accentRing
  child: Semantics(
    identifier: 'wallet_available_balance',
    container: true,
    explicitChildNodes: true,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...]),
  ),
)
```

Contents (top to bottom, gaps `Spacing.twoXSmall`(4+2 rhythm as today) / `Spacing.small` before the pill — today's `:170,:193` gaps survive):
- `JeebSectionLabel(copy.availableBalanceLabel)` — natural casing, NEVER `.toUpperCase()` yourself
  (kit uppercases, locale-gated). Its periwinkle ink on navy is a deliberate kit non-reader
  ("19/23 measured", kit doc §1.5) — no override.
- Amount row — keep today's baseline `Row` shape (`:171-189`), restyled:
  ```dart
  Row(crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic, children: [
    Flexible(child: FittedBox(fit: BoxFit.scaleDown,          // 200%-scale guard
      alignment: AlignmentDirectional.centerStart,
      child: Text(MoneyFormat.format(b?.availableBalance ?? 0, currency: currency),
        style: context.jeebText.statHero                      // 38/w800/−1 — board-exact
            .copyWith(color: theme.colorScheme.onPrimary)))),
    if (showCurrencySuffix) ...[
      const SizedBox(width: Spacing.xSmall),
      Text('USD', style: context.jeebText.bodySmall
          .copyWith(fontWeight: FontWeight.w700, color: semantic.mutedText)),
    ],
  ])
  ```
  where `final code = currency.trim().toUpperCase(); final showCurrencySuffix = code.isEmpty ||
  code == 'USD';` — `MoneyFormat` prints the ISO code inline for non-USD, so the suffix would
  double it. Suffix 12/w700 vs board 14/w700: stated divergence (no 14/w700 ramp slot; R3 ranks by
  weight).
- Gift pill, gated exactly as today: `if (hasGift) ... Semantics(identifier: 'wallet_gift_badge',
  container: true, child: _GiftPill(label: copy.giftBadge(MoneyFormat.format(b?.giftCredit ?? 0,
  currency: currency))))`.

`_GiftPill` — NEW private widget in this file (sanctioned screen-local: kit doc §5 "23's
starter-credit pill: screen-local; no on-navy unselected chip exists in the kit, by design").
Replaces the `OmdsChip` (`:197-201`):

```dart
Container(
  padding: const EdgeInsetsDirectional.symmetric(
      horizontal: Spacing.small, vertical: Spacing.xSmall - 2), // 6px: board value, no token between 4 and 8
  decoration: BoxDecoration(
    color: semantic.accentTint,                    // orange @12% — vs board 20%, sanctioned token wins
    border: Border.all(color: semantic.accentRing), // orange @30% — vs board 40%, same trade
    borderRadius: OmdsBorderRadius.pill,
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Text('🎁', style: context.jeebText.body),      // literal emoji (board), 13.5≈13px; NOT Icons.card_giftcard
    const SizedBox(width: Spacing.xSmall - 2),     // 7px board gap
    Text(label, style: context.jeebText.bodySmall.copyWith(
        fontWeight: FontWeight.w700, color: cs.onPrimary)),
  ]),
)
```

### 4. The three notes — `JeebInfoNote`, filled icons, tone enum

KYC banner (`:144-156`): `_Banner` call → `JeebInfoNote.muted(identifier:
'wallet_kyc_pending_banner', icon: Icons.hourglass_top, title: copy.kycPendingTitle, text:
copy.kycPendingBody)` — remember `text:`, not `body:`. Keep the `if (copy.kycPending)` gate and
first position; keep it wrapped in a bottom-padding of `Spacing.small`.

Affordability (`:211-220`): → `JeebInfoNote(tone: _affordabilityTone(affordability), icon:
_affordabilityIcon(affordability), title: copy.affordabilityTitle(affordability), text:
copy.affordabilityBody(affordability), identifier: 'wallet_affordability_card')`.

- `_affordabilityTone` (`:350-359`): change signature to `JeebInfoNoteTone
  _affordabilityTone(WalletAffordability a)` — `enough` → `JeebInfoNoteTone.success`, the other
  three → `.warning`. Same branching; the color pairs now live in the kit. Drop the now-unused
  `JeebRoles` param; if nothing else reads `context.jeebRoles`, remove the
  `jeeb_color_roles.dart` import (analyze-clean).
- `_affordabilityIcon` (`:335-346`) goes filled (R10 bans outline variants): `enough` →
  `Icons.check_circle`, `low` → `Icons.warning`, `empty` → `Icons.account_balance_wallet`,
  `allReserved` → `Icons.lock_clock`.
- **All four states stay.** The board draws only `enough`; D43, `wallet_hub_screen_test.dart:125-146`
  and Maestro AC6 (`wallet_state=insufficient`) depend on the other three.

Reserve (`:225-234`): `_StatRow` call → the kit's own documented 23 form:

```dart
JeebInfoNote.outlined(
  identifier: 'wallet_reserved_now',
  icon: Icons.lock,                                   // filled padlock, board-exact
  title: copy.reservedNowLabel,
  text: copy.reservedNowHint,
  trailing: Text(
    MoneyFormat.format(b?.reservedNow ?? 0, currency: currency),
    style: context.jeebText.cardTitle.copyWith(fontWeight: FontWeight.w800), // 15.5/w800 vs board 16/w800
  ),
)
// TODO(redesign-24): the board's "1 live offer" needs a live-reserve COUNT —
// WalletBalance has the amount only. Omitted, not faked.
```

### 5. CTA block — `JeebCtaFooter.single` with the fee link in `below:`

Replace `:238-261` (both `OmdsPrimaryButton`s and their wrappers + the two `SizedBox` gaps):

```dart
JeebCtaFooter.single(
  padding: JeebCtaFooter.inline,        // 24/16/24/0 — the kit's "23" constant
  below: JeebCtaButton.accentText(      // the ONE sanctioned orange text affordance (R5)
    identifier: 'wallet_how_fees_work',
    label: copy.howFeesWork,
    onTap: () => _showHowFees(context),
  ),
  child: JeebCtaButton(                 // primary: navy pill h56, jeebText.button, JeebShadows.ctaNavy — all kit defaults
    identifier: 'wallet_topup_cta',
    label: copy.topUpCta,
    leadingIcon: Icons.add,             // 19px default — board-exact
    onTap: () => _onTopUp(context),
  ),
)
```

But the scroll slivers already carry the 24 gutter — so **either** hoist this block out of the
`SliverPadding` into its own sliver, **or** (simpler, do this) keep it inside the padded list and
pass `padding: const EdgeInsetsDirectional.only(top: Spacing.medium)` so the horizontal gutter is
not doubled. State which you did in the code comment.

`_onTopUp` (`:306-314`) and `_isOffline` (`:316-324`) are UNTOUCHED — the D35 offline guard and
its no-provider fallback are load-bearing.

### 6. Grouped exits — `JeebOutlinedCard.grouped` + 2× `JeebListRow`

Replace `:265-297` (both `OmdsSettingsRow`s):

```dart
JeebOutlinedCard.grouped(children: [          // 1.5px cs.outline, r16, dividers inset 16 — all defaults
  JeebListRow(
    identifier: 'wallet_earnings_row',
    icon: Icons.show_chart,                   // the board's polyline glyph (html:1389), filled
    title: copy.earningsRow,
    subtitle: copy.earningsRowSubtitle,
    onTap: () => context.goNamed('earnings'),
  ),
  JeebListRow(
    identifier: 'wallet_see_all_activity',
    icon: Icons.article,                      // the board's lined-square glyph (html:1398), filled
    title: copy.seeAllActivity,
    subtitle: copy.seeAllActivitySubtitle,
    onTap: () => context.goNamed('wallet-activity'),
  ),
])
```

Chevron mirroring is kit-internal (`DirectionalIcons.disclosure`). Preserve the two R-4 honesty
comments (`:265-269`, `:282-286`) above their rows — they document why these edges are real.

### 7. Docked trust line — the only net-new element

The `SliverFillRemaining(hasScrollBody: false)` child:

```dart
Align(
  alignment: AlignmentDirectional.bottomCenter,
  child: Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge, Spacing.large, Spacing.xLarge, Spacing.twoXLarge), // bottom 32 vs board 30 — no 30 token
    child: Semantics(
      identifier: 'wallet_cash_disclaimer',
      container: true,
      child: Text(copy.cashDisclaimer,
          textAlign: TextAlign.center,
          style: context.jeebText.caption.copyWith(color: semantic.mutedText)), // 11.5/w600 vs board w500
    ),
  ),
)
```

### 8. Deletions & cleanup

- Delete `_Banner` (`:440-493`), `_StatRow` (`:496-543`), `_fmt` (`:361`) and the
  `(Color, Color)?` record plumbing. Delete now-unused imports (`omds` stays — OmdsLoadingState /
  OmdsErrorState / OmdsPullToRefresh / OmdsBorderRadius / Spacing all come from it).
- `_HowFeesSheet` / `_FeeBullet` (`:367-436`): byte-identical except nothing — task 1 already
  changed its line-1 copy at the l10n layer.
- Update the class doc comment's stale phrases only if they now lie (the AC-surface list still
  holds); keep the D-references.

### 9. Tests — `test/features/wallet/wallet_hub_screen_test.dart` (this lane owns it)

Mechanical edits (3, all from the designer-note copy change):
1. `:118-123` — `find.text('Ready to bid')` → `find.text("You're set to bid")` (positive).
2. `:125-135` — the negative assertion string likewise.
3. `:137-146` — likewise.
`'Running low'` / `'Everything is reserved'` assertions stand. Everything else in the file passes
untouched — it asserts identifiers and cubit-driven conditions only. `pumpAndSettle` stays safe
(nothing added animates; `isLoading` unused).

Add (additive only):
4. `wallet_back` and `wallet_cash_disclaimer` resolve (`find.bySemanticsIdentifier`, one test).
5. RTL smoke: pump inside `Directionality`/`Locale('ar')`, expect no exceptions and that the hero
   amount string contains `⁦` (the MoneyFormat isolate).
6. A rate-derivation guard: `find.textContaining('$kJeebCommissionPercent%')` finds the
   affordability body in the `enough` state (pins C1 at the widget level).

Expected net: 3 edited, ~3 added, 0 removed, 0 weakened.

### 10. Gates + wiring file

- Write §E verbatim to `docs/redesign-2026-08/wiring/23-wallet.md`.
- `flutter analyze` — bar per `_BASELINE.md`: 5 pre-existing infos, **0 errors, no new issues**.
- `flutter test test/features/wallet/wallet_hub_screen_test.dart
  test/core/router/w2_routes_resolve_test.dart test/core/theme/no_raw_semantic_colors_test.dart
  test/core/jeeb_commission_test.dart test/decision_violations_test.dart` — all green now (the
  lane ships copy via `_pick`, so nothing waits on the integrator).
- `bash tool/check_design_tokens.sh` — expect **6** violations (down from 8; both of this file's
  gone; do not touch the other six).
- Visual pass against `screens/23-wallet.png` at the same scale. The bottom ~30% is *supposed* to
  be empty (R1) — do not stretch content to fill it (plan risk #13: if it still looks like
  today's evenly-spaced list, the change failed).

---

## D. Stop conditions

**Done means:** all 11 frozen identifiers + 2 new ones emitted byte-identically; five-block layout
(navy hero w/ bottom-END ring + on-card gift pill · success/warning note · outlined reserve note
w/ trailing money · inline navy CTA + orange fee link · grouped 2-row exits card) over a real
empty lower third with the docked trust line; every amount through `MoneyFormat`; every `10%`
through `kJeebCommissionPercent`; zero `Icons.*_outlined` on this screen; both token-gate
violations in this file gone; analyze/test deltas exactly §C-9/§C-10; wiring file written.

**Do NOT touch:** `wallet_hub_cubit.dart` / `wallet_hub_state.dart` / `domain/` / `data/` (no new
fields, no stub edits, no DI); the other wallet screens (`wallet_charge_info_screen.dart`,
`wallet_activity_list_screen.dart`, `transaction_detail_screen.dart`,
`customer_wallet_stub_screen.dart` — same directory, other lanes); `lib/core/router/*`,
`lib/core/di/*`, `lib/core/theme/*`, `lib/core/widgets/jeeb/*` (consume only), `lib/l10n/*`,
`pubspec.yaml`, OMDS, `.maestro/`, `tool/`. Do not: reorder the five blocks (Maestro AC1 has no
scroll); rename the file or class; drop a `WalletAffordability` branch; change `walletTopUpCta`'s
ARB value; type `$`, `10%` or `0.10` anywhere; use `JeebSemanticColors` with `!`; put the word
"included" on the gift pill or a live-offer count on the reserve note; add a payment/amount
affordance (D92/D93); delete the `_isOffline` fallback or the `canPop` back branch.

---

## E. Wiring requests — final text for `docs/redesign-2026-08/wiring/23-wallet.md`

*(One request. Non-blocking — the lane ships everything via `wallet_hub_l10n.dart`'s `_pick` maps
first; this folds the strings into the ARB layer afterwards with no call-site change. All six kit
requests from the original proposal were verified already shipped in Wave 1 and are withdrawn.)*

### l10n
file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: fold the wallet-hub redesign copy out of `wallet_hub_l10n.dart`'s `_pick` maps into real keys; one existing value change; one NEW key so the shared top-up label is not touched.
exact change:
app_en.arb — change in place (single consumer, `wallet_hub_l10n.dart:47`):
```json
"walletAvailableBalanceLabel": "Available to bid",
```
app_en.arb — add (append-only; `walletTopUpCta` stays untouched — it is shared with kyc_status_view.dart:515,737 and offer_composer_l10n.dart:163):
```json
"walletTopUpWalletCta": "Top up wallet",
"@walletTopUpWalletCta": { "description": "JM-053 wallet-hub primary CTA (wallet_topup_cta); distinct from the shared short walletTopUpCta." },
"walletBackLabel": "Back",
"@walletBackLabel": { "description": "A11y label for the wallet-hub top-bar back circle (wallet_back)." },
"walletGiftBadge": "{amount} starter credit",
"@walletGiftBadge": { "description": "Starter-credit pill on the balance hero (wallet_gift_badge, D42). {amount} arrives pre-formatted by MoneyFormat. Deliberately NOT the word included — the contract does not define gift/balance composition.", "placeholders": {"amount": {}} },
"walletAffordabilityEnoughTitle": "You're set to bid",
"walletAffordabilityEnoughBody": "Enough balance for the {rate}% reserve on typical offers.",
"@walletAffordabilityEnoughBody": { "description": "{rate} MUST be interpolated from kJeebCommissionPercent (single-rate rule).", "placeholders": {"rate": {}} },
"walletReservedRightNowLabel": "Reserved right now",
"walletReservedRightNowHint": "Released if you're not picked.",
"walletHowFeesWorkCta": "How fees work — the {rate}%, explained",
"@walletHowFeesWorkCta": { "placeholders": {"rate": {}} },
"walletEarningsRowTitle": "Earnings",
"walletEarningsRowSubtitle": "Cash collected, fees paid",
"walletAllActivityTitle": "All activity",
"walletAllActivitySubtitle": "Top-ups, reserves, releases",
"walletCashDisclaimer": "Customer cash never passes through this wallet.",
"walletFeesExplainerLine1": "You only pay a flat {rate}% platform fee on offers you win.",
"@walletFeesExplainerLine1": { "description": "D41/D44: platform fee, never Commission; {rate} from kJeebCommissionPercent.", "placeholders": {"rate": {}} }
```
app_ar.arb — same keys:
```json
"walletAvailableBalanceLabel": "متاح للمزايدة",
"walletTopUpWalletCta": "اشحن المحفظة",
"walletBackLabel": "رجوع",
"walletGiftBadge": "رصيد بداية {amount}",
"walletAffordabilityEnoughTitle": "أنت جاهز للمزايدة",
"walletAffordabilityEnoughBody": "رصيدك يكفي لحجز الـ{rate}٪ على العروض المعتادة.",
"walletReservedRightNowLabel": "محجوز الآن",
"walletReservedRightNowHint": "يُعاد إليك إذا لم يقع الاختيار عليك.",
"walletHowFeesWorkCta": "كيف تعمل الرسوم — شرح الـ{rate}٪",
"walletEarningsRowTitle": "الأرباح",
"walletEarningsRowSubtitle": "النقد المُحصَّل والرسوم المدفوعة",
"walletAllActivityTitle": "كل النشاط",
"walletAllActivitySubtitle": "الشحن والحجوزات والإفراجات",
"walletCashDisclaimer": "نقود العميل لا تمر أبداً عبر هذه المحفظة.",
"walletFeesExplainerLine1": "تدفع رسوم منصة ثابتة {rate}٪ فقط على العروض التي تفوز بها."
```
app_localizations.dart — plain getters for the un-parameterized keys; the placeholder keys follow the hand-rolled `replaceFirst` pattern (`app_localizations.dart`, e.g. `chatBroadcastTtlLabel`):
```dart
String walletGiftBadge(String amount) =>
    _get('walletGiftBadge').replaceFirst('{amount}', amount);
String walletAffordabilityEnoughBody(int rate) =>
    _get('walletAffordabilityEnoughBody').replaceFirst('{rate}', '$rate');
String walletHowFeesWorkCta(int rate) =>
    _get('walletHowFeesWorkCta').replaceFirst('{rate}', '$rate');
String walletFeesExplainerLine1(int rate) =>
    _get('walletFeesExplainerLine1').replaceFirst('{rate}', '$rate');
```
why: the redesigned wallet hub renders this copy today from `wallet_hub_l10n.dart`'s lane-local `_pick` maps (the JM-031/JM-045 precedent); folding it into the ARB layer retires that resolver's temporary strings with no screen change. The `{rate}` placeholders keep `kJeebCommissionPercent` as the only copy of the rate.

**Open question for the owner (not a file change, record the answer in this file when it comes):**
is `WalletBalance.giftCredit` *included in* or *additive to* `availableBalance`? The board's pill
says "included"; the contract (`wallet_repository.dart:17-31`, `DioWalletRepository._parse`) does
not define it. Until answered the pill ships the neutral `{amount} starter credit`.
