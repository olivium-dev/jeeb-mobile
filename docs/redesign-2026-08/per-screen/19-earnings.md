# 19 · Earnings — change proposal

Lane: Wave 2 (self-contained) · feature dir `lib/features/earnings/`
File: `lib/features/earnings/presentation/earnings_dashboard_screen.dart` (581 LOC, 12 widgets,
13 identifier literals). Confirmed live: `shell_screen.dart:236` → `EarningsTab` →
`EarningsDashboardScreen`, and `app_router.dart:1645` `/earnings`. `screen-repo-map.md:68` agrees
with the prompt — no STOP-table correction applies to 19.
Design: `screens/19-earnings.{png,html,note.md}`
Verdict: **rebuild** — the same data, a completely different container tree. Nothing is deleted from
the data model, nothing new is fetched, and **no new Semantics identifier is needed**.

---

## 0. One-paragraph summary

The board keeps every number this screen already computes and re-ranks them: one navy hero card
answers "how did I do" (`CASH COLLECTED` + three stats on a divider), one outlined strip answers
"what did it cost" (fees), a grey list answers "from what" (per-delivery rows), and the two
cross-feature exits become a docked two-pill footer + one inline text link. Five M3 `Card`s and two
`OmdsSettingsRow`s disappear. Two things on the render are **not buildable honestly**: the `★ 4.8
This week` rating (no period-scoped rating exists anywhere in the app) and the per-row tier emoji +
human item name (`⚡ Pharmacy run`) — the earnings wire item is `{deliveryId, amount, syncedAt}` and
carries neither. One board string is **refused outright**: `Jeeb fees paid` is a D41/D44 violation.

---

## 1. Semantics inventory — FROZEN (all 13 must still be emitted)

Greped from `lib/features/earnings/` (the only identifiers in the feature tree):

| identifier | today at | after the rebuild |
|---|---|---|
| `earnings_dashboard_root` | `:45` | unchanged — still the single `<screen>_root`, still wraps the `Scaffold` |
| `earnings_period_today` | `:212` (`earnings_period_${period.name}`) | unchanged — re-homed onto `JeebSelectChip` |
| `earnings_period_week` | `:212` | unchanged |
| `earnings_period_month` | `:212` | unchanged |
| `earnings_total_cash` | `:250` | re-homed onto the **amount block inside the navy hero** (eyebrow + `$127.50` + trust line), NOT the whole card — see §6.1 |
| `earnings_fees_paid` | `:296` | re-homed onto the outlined fee strip |
| `earnings_net_per_offer` | `:350` | re-homed onto hero stat #2 (`$7.08 / Avg kept per offer`) |
| `earnings_deliveries_count` | `:362` | re-homed onto hero stat #1 (`18 / Deliveries`) |
| `earnings_member_since` | `:438` (conditional on `summary.memberSince != null`) | re-homed onto hero stat #3 — still conditional, same condition |
| `earnings_breakdown_empty` | `:478` | unchanged — shown when `summary.deliveries.isEmpty` but the period is funded |
| `earnings_delivery_row_<id>` | `:504` | unchanged — re-homed onto the grey row |
| `earnings_wallet_link` | `:525` | re-homed onto the **footer outline pill** (`Wallet`) |
| `earnings_activity_link` | `:546` | re-homed onto the **section-label trailing text link** (`See all`) — see §3.6 |
| `earnings_export_cta` | `:568` | re-homed onto the **footer navy pill** (`Export PDF`) |
| `earnings_empty` | `:115` | unchanged |

**New identifiers: none.** Every interactive element on the board maps 1:1 onto an existing one.
That is the single strongest argument that this is a restyle-with-restructure and not a new surface.

### Maestro impact — `.maestro/flows/jm-052-earnings-dashboard.yaml` keeps passing, unchanged

Three things in that flow constrain the layout and all three are satisfied:

- `assertVisible: earnings_member_since` (AC1, unconditional) — folding member-since into hero stat
  #3 keeps it **on the first screenful**; today it sits mid-list. Strictly better for this flow.
- `scrollUntilVisible: earnings_wallet_link` / `earnings_activity_link` (`direction: DOWN`) — both
  become always-visible (footer / section header). Maestro's `scrollUntilVisible` succeeds
  immediately when the element is already on screen, so **do not edit the flow**.
- `assertNotVisible: earnings_gross_payout | earnings_commission_line | earnings_net_payout` —
  nothing in this proposal introduces any of them.

Maestro is not in CI (§7.5), so this is a manual guarantee: if a later reviewer moves the wallet link
back into the scroll body, the flow still passes; if anyone renames it, the flow rots silently.

---

## 2. Layout & structure

### 2.1 Today

```
Scaffold(appBar: OMDSAppBar('Earnings'))
└ BlocConsumer
  └ OmdsPullToRefresh > ListView(padding: EdgeInsets.all(Spacing.medium /*16*/))
    ├ _PeriodFilterRow          Row of OmdsChip
    ├ _TotalCashCard            M3 Card, pad 24
    ├ _FeesPaidCard             M3 Card, pad 20, leading Icons.percent_outlined
    ├ _StatsRow                 two M3 Cards side by side (net-per-offer | deliveries)
    ├ _MemberSinceRow           icon + two Texts
    ├ _DeliveryBreakdownList    titleSmall + N ListTiles
    ├ _WalletLink               OmdsSettingsRow
    ├ _ActivityLink             OmdsSettingsRow
    └ _ExportButton             OmdsLoadingButton
```

Seven stacked equal-weight blocks in one scroll view, 16px gutters, everything the same colour. The
designer note names exactly this: *"one navy hero card answers 'how did I do' … instead of four
equal grey cards"*.

### 2.2 Target (measured from `19-earnings.html`)

```
Scaffold
└ SafeArea(top: true, bottom: true)            ← bottom: true is load-bearing, see §2.4
  └ Column
    ├ Padding(14/24/0)  Text('Earnings', jeebText.h2, colorScheme.primary)   [html:15]
    ├ Padding(14/24/0)  JeebChipRow(role: sort)  Today | This week | Month    [html:16-20]
    ├ Expanded
    │ └ OmdsPullToRefresh > ListView(padding: 0/24, AlwaysScrollableScrollPhysics)
    │   ├ SizedBox(Spacing.medium /*16*/)
    │   ├ _CashHero            JeebNavySurfaceCard r20 pad20 heroNavy + accentRing [html:22-32]
    │   ├ SizedBox(Spacing.small /*12*/)
    │   ├ _FeeStrip            JeebOutlinedCard r16 pad 14/16                      [html:34-41]
    │   ├ SizedBox(Spacing.medium /*18→16*/)
    │   ├ _BreakdownHeader     JeebSectionLabel + 'See all' text link             [html:44]
    │   ├ SizedBox(Spacing.xSmall+2 → Spacing.small /*10→12*/)
    │   └ ...N × _DeliveryRow  r16 surfaceContainerHigh, gap Spacing.xSmall /*8*/ [html:46-60]
    └ _EarningsFooter          JeebCtaFooter.dual, pad 0/24/32                     [html:64-67]
```

**What moves:** the four stat cards collapse into the hero's divider row; the two `OmdsSettingsRow`
exits move out of the scroll body (one to the footer, one to the section header); the export CTA
moves from the end of the list to the docked footer.

**What is added:** nothing structural. One decorative ring, one divider, one footer.

**What is deleted:** `OMDSAppBar`, five M3 `Card`s, two `OmdsSettingsRow`s, `ListTile`,
`_MemberSinceRow` as a standalone row, `Icons.event_available_outlined`,
`Icons.account_balance_wallet_outlined`, `Icons.receipt_long_outlined`.

### 2.3 Density (R1) — this is the part that is easy to skip

With the real mock (2–3 deliveries) the content ends at roughly 60% of the viewport and the rest is
plain white above the footer. **Do not** add a `Spacer`, do not centre anything, do not let the list
grow a `shrinkWrap` filler. The `Expanded(ListView)` produces the emptiness for free — that is the
correct implementation of R1 here, and it is also why the footer must be a sibling of the `Expanded`
rather than the last list item.

### 2.4 The shell interaction the render cannot show

`EarningsDashboardScreen` is a **tab body**, not a route with its own bottom edge. `shell_screen.dart`
wraps every tab in `_NavBarContentInset` (`:265-292`), which re-adds `Sizes.fiveXLarge` (56) to both
`padding.bottom` and `viewPadding.bottom` so exactly one screen-level mechanism reserves the tab bar.
The docked footer therefore MUST sit inside `SafeArea(bottom: true)`; otherwise it renders under
`_JeebBottomBar`. This is the sanctioned mechanism per that file's own comment — do not hand-add 56px.

Consequence for the design: the board's `padding: 0 24px 30px` becomes
`EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)` (32) inside the
SafeArea. 30→32 is the divergence the plan already sanctioned (`02-PLAN-ENHANCED.md` §3.3: *"Footer
bottom padding is 30 or 32 … pick 32 and note the divergence"*).

### 2.5 State bodies

| state | today | target |
|---|---|---|
| `loading` | whole body replaced by `OmdsLoadingState` | title + period chips **stay mounted**; only the `Expanded` swaps to `OmdsLoadingState`. Period chips remain tappable during a reload — this is a real improvement and costs nothing, because the chips are now hoisted above the state switch |
| `error` | `OmdsErrorState` full-body | same, inside the `Expanded` |
| `ready` + `summary.isEmpty` | `_EmptyEarnings` (chips + `OmdsEmptyState`) | same content, new chrome: chips are hoisted, the `OmdsEmptyState` sits in the `Expanded`. **Footer NOT rendered** — see §9-R3 |
| `ready` + data | `_ReadyBody` | §2.2 |

---

## 3. Section-by-section change list

### 3.1 Screen title — `:48` `appBar: OMDSAppBar(title: copy.title)` → in-body `Text`

`html:15` — `padding: 14px 24px 0; font-size: 20px; font-weight: 700; color: var(--jeeb-navy)`.
There is no back button, no leading, no trailing: 19 is a tab root.

```dart
Padding(
  padding: const EdgeInsetsDirectional.fromSTEB(
    Spacing.xLarge, Spacing.small, Spacing.xLarge, 0,
  ),
  child: Text(copy.title, style: context.jeebText.h2?.copyWith(
    color: Theme.of(context).colorScheme.primary,
  )),
)
```

**Kit note (§5 #1):** `JeebTopBar`'s `leading` is specced as a *mode* — `back` / `close` / `identity`
— with no "none". 19 needs title-only. **Do not** consume `JeebTopBar` here and do not invent a
fourth mode for one screen; a padded `Text` is the honest 4-line answer. Filed as a kit note, not a
blocker.

**Plan divergence, stated:** `00-MIGRATION-PLAN.md` §5 #23 and `02-PLAN-ENHANCED.md` §3.2 both list
**19 as a `JeebProfileHeader` consumer**. Measured, it is not: `19-earnings.png` and `html:15` show a
bare 20/w700 title — no Ø46 avatar, no eyebrow, no trailing rating pill. That assumption almost
certainly came from the `★ 4.8` in the hero (which is a *stat*, not a header pill, `html:30`).
**19 does not consume `JeebProfileHeader`.**

### 3.2 Period pills — `:197-234` `_PeriodPill` (`OmdsChip`) → `JeebSelectChip(role: sort)`

`html:17-19` — pad `8px 16px`, `r999`, `12.5px/w600`; unselected `1.5px var(--jeeb-brown-outline)` +
ink `var(--jeeb-brown-subtitle)`; selected `var(--jeeb-navy)` fill + white ink.

That is §5 #6's **`sort`** role verbatim (`8/15`, 12.5/w600–700, unselected ink `onSurfaceVariant`).
Pass the role, never a padding (risk #15).

```dart
JeebChipRow(                                  // gap Spacing.xSmall (8) — html:16
  children: [
    for (final p in EarningsPeriod.values)
      JeebSelectChip(
        role: JeebChipRole.sort,
        label: _label(p),
        selected: p == state.period,
        identifier: 'earnings_period_${p.name}',   // FROZEN
        onTap: () => context.read<EarningsCubit>().loadEarnings(period: p),
      ),
  ],
)
```

`OmdsChip` goes away. Note Wave 0 already flipped `chipTheme.shape` to `StadiumBorder()`, so nothing
else on this screen inherits the old 8px rect.

### 3.3 The navy hero — `:237-280` `_TotalCashCard` + `:339-424` `_StatsRow` + `:428-466` `_MemberSinceRow` → one `_CashHero`

`html:22` — `margin: 16px 24px 0; background: var(--jeeb-navy); border-radius: 20px; padding: 20px;
overflow: hidden; box-shadow: rgba(11,19,81,.3) 0 12px 28px`.

| element | html | Flutter |
|---|---|---|
| container | r20, navy, `0 12 28 rgba(11,19,81,.3)` | `JeebNavySurfaceCard(radius: Spacing.large /*20*/, padding: Spacing.large, shadow: JeebShadows.heroNavy)` — this is R6-(b) with a shadow, and `heroNavy` is defined for exactly "stat hero cards (19, 23)" |
| decorative ring | `:23` `position:absolute; right:-50; top:-50; Ø160; border 1.5px rgba(215,59,0,.3)` | `PositionedDirectional(end: -50, top: -50)` inside the card's `Stack`, Ø160 circle, `Border.all(width: 1.5, color: semantic.accentRing)`, clipped by the card's own `ClipRRect`. **`end`, not `right`** — §7 |
| eyebrow | `:24` 12.5/w700/ls1.2/uppercase/periwinkle | `JeebSectionLabel(copy.totalCashLabel)` (default 12.5, `mutedText`, internal `toUpperCase()`) |
| amount | `:25` 38/w800/ls−1/white | `context.jeebText.statHero` + `colorScheme.onPrimary`. Value stays `MoneyFormat.format(summary.totalCashEarned, currency: summary.currency)` — already LTR-isolated |
| trust line | `:26` 12.5/w600 periwinkle, *"Paid to you directly — never through Jeeb."* | `context.jeebText.bodySmall` + `semantic.mutedText`. **Adopt the board's copy** — it is the sharper statement of the same D41 fact the current `totalCashHint` makes. New EN/AR pair in `earnings_dashboard_l10n.dart` (§4.3) |
| divider | `:27` `border-top 1px rgba(255,255,255,.12)`, `margin-top 14; padding-top 14` | `Divider(height: 1, color: colorScheme.onPrimary.withValues(alpha: 0.12))` with `Spacing.small` (12) above and below. Do **not** use `outlineVariant` — this is an on-navy hairline |
| stat row | `:27` `display:flex; gap:18px` | `Row` of three `Flexible` stat columns, `SizedBox(width: Spacing.large /*20*/)` between. `Flexible`, not `Expanded` — at 200% text scale the three columns must be allowed to shrink-wrap rather than clip (§7) |

Each stat (`html:28-30`): value 17/w800 white → `context.jeebText.titleProminent` + `onPrimary`;
label 11/w600 periwinkle → `context.jeebText.caption` + `mutedText`.

| slot | render | code |
|---|---|---|
| 1 | `18` / `Deliveries` | `'${summary.deliveryCount}'` / `copy.deliveriesLabel` — id `earnings_deliveries_count` |
| 2 | `$7.08` / `Avg kept / offer` | `MoneyFormat.format(summary.netPerOffer, …)` / `copy.netPerOfferLabel` — id `earnings_net_per_offer` |
| 3 | `★ 4.8` / `This week` | **REFUSED — see §9-C1.** Renders `DateFormat.yMMM()` of `summary.memberSince` over `copy.memberSinceLabel`, and only when `memberSince != null` — id `earnings_member_since` |

The `netPerOfferHint` ("Average cash you keep per delivery after fees.") has no slot in the hero.
Keep it as the stat's `Semantics(hint:)` so the D44 explanation is not lost to screen readers.

### 3.4 The fee strip — `:283-337` `_FeesPaidCard` → `_FeeStrip`

`html:34` — `margin: 12px 24px 0; padding: 14px 16px; border-radius: 16px; border: 1.5px solid
var(--jeeb-brown-outline); gap: 12px`. **White fill, outline, no shadow** (R7).

```dart
Semantics(
  identifier: 'earnings_fees_paid',
  container: true,
  child: JeebOutlinedCard(
    radius: Spacing.medium,                        // 16
    padding: const EdgeInsetsDirectional.symmetric(
      vertical: Spacing.small + 2, horizontal: Spacing.medium),   // 14/16
    child: Row(children: [ disc, Expanded(text), value ]),
  ),
)
```

- **disc** `html:35` — Ø38, `r999`, `var(--jeeb-surface-high)` fill, glyph `%` 15/w800 navy.
  Build as `Container(width: 38, height: 38, shape: BoxShape.circle,
  color: colorScheme.surfaceContainerHigh)` wrapping `Icon(Icons.percent, size: Sizes.medium,
  color: colorScheme.primary)`. Use the **icon**, not a literal `'%'` `Text` — R10 ("icons: filled,
  single-colour"), and a bare glyph string has no l10n home. `Icons.percent_outlined` is dropped in
  favour of the filled face per R10.
- **title** `html:37` 14/w700 navy → `context.jeebText.cardTitle` (15.5/w700, the nearest ramp entry;
  R3 says do not chase 1.5px).
- **subtitle** `html:38` 12/w500 periwinkle, *"10% per won offer, from your wallet"* →
  `context.jeebText.bodySmall` + `mutedText`. **The `10` is interpolated from
  `kJeebCommissionPercent`** (`lib/core/jeeb_commission.dart:78`), never typed — §7.2 "Single 10%
  literal". See §4.3 for the string.
- **value** `html:40` 16/w800 navy → `context.jeebText.titleProminent`, `MoneyFormat.format(
  summary.feesPaid, …)`, `semanticsLabel` preserved.

**Board copy REFUSED:** `html:37` says **"Jeeb fees paid"**. D41/D44 (`decision_violations_test.dart:176-208`)
pins the platform's cut as **"Platform fee"** and bans "Commission" framing; the shipped copy
`feesPaidLabel` = **"Platform fees paid"** is already correct. Keep it. Same refusal class as C5 in
`02-PLAN-ENHANCED.md`.

**Plan divergence, stated:** §5 #24 lists 19 as a `JeebMoneyBreakdown` consumer. Measured, 19 has
**no** breakdown card — no label/value rows, no divider, no total row, no lock footnote. The fee strip
is a single-value row and is correctly served by `JeebOutlinedCard`. **19 does not consume
`JeebMoneyBreakdown`.** This does not weaken D41/D44 enforcement: on this screen the wording lives in
`earnings_dashboard_l10n.dart`, which is already fee-only by construction (its class doc names D41/D44
as the reason the `earningsGross`/`earningsCommission`/`earningsNet` ARB keys are *not* reused).

### 3.5 Section header — `:486` `Text(copy.breakdownTitle, titleSmall)` → `JeebSectionLabel` + link

`html:44` — `font-size: 13px; font-weight: 700; letter-spacing: 1.2px; text-transform: uppercase;
color: var(--jeeb-periwinkle)`, and the text is **the selected period** (`THIS WEEK`), not a static
"Recent deliveries".

```dart
Row(children: [
  JeebSectionLabel(copy.period(state.period.name)),   // TODAY | THIS WEEK | THIS MONTH
  const Spacer(),
  _ActivityLink(copy: copy),                          // earnings_activity_link
])
```

`JeebSectionLabel` defaults to 12.5px per §4.2's correction (13px here is the same token, R14).
`toUpperCase()` is applied inside the widget and is a no-op for Arabic.

`copy.breakdownTitle` ("Recent deliveries") stops being rendered but is **kept** and moved onto the
row's `Semantics(label:)`, so a screen reader still hears what the section is rather than a bare
"THIS WEEK" that duplicates the selected chip.

### 3.6 `earnings_activity_link` — `:539-557` `OmdsSettingsRow` → inline text link

The board has **no** "See all activity" row: `html:63` is a bare `flex:1` spacer between the last
delivery row and the footer. But the identifier is frozen (§7.5) and the Maestro flow taps it (AC3).

Resolution: render it as the section header's trailing action — brown `onSurfaceVariant`, 13/w600, no
pill. That is R4's third ink ("brown = a secondary interactive word") and it is the same treatment 11
gives its footer link. It is visible without scrolling, so the Maestro `scrollUntilVisible` still
passes.

```dart
Semantics(
  identifier: 'earnings_activity_link',
  button: true,
  child: JeebCtaButton.text(                       // §5 #2 `text` variant, onSurfaceVariant
    label: copy.activityLink,                      // 'See all activity' → shorten to 'See all', §4.3
    onTap: () => context.pushNamed('wallet-activity'),
  ),
)
```

`activityLinkSubtitle` loses its only call site. **Delete the getter** (`earnings_dashboard_l10n.dart:113-116`)
— it is lane-owned, has no other consumer in `lib/` or `test/` (verified by grep), and leaving dead
copy behind is how a translation gets shipped for a string nobody renders.

### 3.7 Delivery rows — `:468-514` `_DeliveryBreakdownList` / `_DeliveryRow`

`html:46` — `padding: 11px 14px; border-radius: 14px; background: var(--jeeb-surface-high);
gap: 10px`, list `gap: 8px`, `margin-top: 10px`.

```dart
Semantics(
  identifier: 'earnings_delivery_row_${item.deliveryId}',   // FROZEN
  container: true,
  child: Container(
    decoration: BoxDecoration(
      color: cs.surfaceContainerHigh,
      borderRadius: OmdsBorderRadius.medium,                // 16 ← design 14 (§4.4 rule of two tiers)
    ),
    padding: const EdgeInsetsDirectional.symmetric(
      vertical: Spacing.small - 1, horizontal: Spacing.small + 2),   // 11/14
    child: Row(children: [ Expanded(titleBlock), amount ]),
  ),
)
```

| element | html | Flutter |
|---|---|---|
| leading tier emoji `⚡ 🤝 🚀` | `:47` 15px | **OMITTED — data gap, §5-G2.** No leading slot; the row starts at the title and the 10px gap collapses |
| title `Pharmacy run · Fri` | `:49` 13/w700 navy, `ellipsis` | `copy.deliveryRowTitle(item.deliveryId)` + ` · ` + weekday, `maxLines: 1, overflow: TextOverflow.ellipsis`, style `context.jeebText.body.copyWith(fontWeight: FontWeight.w700)`. The item **name** is a data gap (§5-G3); the **weekday IS derivable** from the existing `item.date` |
| subtitle `fee $0.80` | `:49` 11/w600 periwinkle | `copy.deliveryRowFee(MoneyFormat.format(item.feePaid, …))`, `context.jeebText.caption` + `mutedText` |
| amount `+$8.00` | `:49` 14/w800 navy | `context.jeebText.cardTitle`, value = `MoneyFormat.format(item.cashCollected, …)`. The **leading `+` is a bidi hazard — §7.2** |

On the `copyWith(fontWeight:)`: the ramp has no 13/w700 entry (`body` is 13.5/w500, `bodySmall`
12/w600, `cardTitle` 15.5/w700). Using `bodySmall` for the title would make it *lighter* than the
`caption` subtitle and invert R4's ranking. `body.copyWith(fontWeight: FontWeight.w700)` is 0.5px off
the board, keeps the ranking, writes no `fontSize:` literal, and passes `check_design_tokens.sh`. Do
not re-open `jeeb_text_styles.dart` for this (Wave 0 is frozen).

`ListTile` is deleted — its 16px M3 insets and its own `contentPadding` fight the 11/14 spec.

### 3.8 The footer — `:518-536` `_WalletLink` + `:559-580` `_ExportButton` → `JeebCtaFooter`

`html:64` — `display:flex; gap:10px; padding: 0 24px 30px`, both children `flex:1; height:52px;
border-radius:999px`.

| pill | html | Flutter |
|---|---|---|
| `Wallet · $6.40` | `:65` `1.5px var(--jeeb-brown-outline)`, 14/w600 navy, no shadow | `JeebCtaButton.outline(height: 52)`, `Semantics(identifier: 'earnings_wallet_link', button: true)`, `onTap: () => context.pushNamed('wallet')` |
| `Export PDF` | `:66` navy fill, white 14/w600, `0 10 24 rgba(11,19,81,.28)` | `JeebCtaButton.primary(height: 52, shadow: JeebShadows.ctaNavy)`, `Semantics(identifier: 'earnings_export_cta', button: true)`, `isLoading: state.exportMode == EarningsExportMode.exporting` |

Both `pushNamed` targets are registered today (`app_router.dart` — `wallet`, `wallet-activity`); no
route work.

**Two kit requests (§8):**
1. **`JeebCtaFooter` needs a `dual` form.** §5 #2 realizes three forms — `single`, `split` (text +
   pill), `textStack`. 19's footer is **two equal `flex:1` pills** (outline + primary, gap 10, h52),
   which is none of them. 24's order-history footer may want the same. If the kit owner refuses, the
   fallback is a screen-local `Row(children: [Expanded(outline), SizedBox(Spacing.small), Expanded(primary)])`
   built from two `JeebCtaButton`s — no visual difference, just duplication.
2. **`JeebCtaButton.primary` needs `isLoading`.** Export is a real async action with a spinner today
   (`OmdsLoadingButton`, `:571`). §5 #2 specs no loading state. If refused, keep `OmdsLoadingButton`
   for this one pill and accept that its radius/height come from OMDS rather than the board.

The `walletLinkSubtitle` getter (`earnings_dashboard_l10n.dart:108-109`) loses its call site —
**delete it**, same reasoning as §3.6.

### 3.9 The wallet balance in the pill — `$6.40`

The board's pill reads `Wallet · $6.40`. `WalletBalance.availableBalance` **exists** and
`WalletRepository` **is DI-registered** (`injection_container.dart:741` → `DioWalletRepository`), so
this is not a §7.6 data gap — it is a plumbing question, and plumbing crosses a feature boundary this
lane does not own.

**Ship (this lane): label only — `Wallet`.** With
`// TODO(redesign-24): balance needs WalletRepository in EarningsCubit — see 19-earnings.md §3.9.`

**Wiring request (integrator, fully specced so it is a 3-file change):**

```dart
// earnings_cubit.dart — OPTIONAL param; every existing call site keeps compiling
EarningsCubit({
  required EarningsRepository repository,
  WalletRepository? walletRepository,          // NEW, nullable
  this.jeeberId = '',
});
// earnings_state.dart:  final WalletBalance? walletBalance;   (null = not fetched / fetch failed)
// earnings_tab.dart:12  walletRepository: sl<WalletRepository>(),
```

Rules that make it safe: the fetch is **fire-and-forget** and a failure emits nothing (a wallet read
must never turn the earnings screen into an error state); the pill renders the ` · $x.xx` suffix
**only when `walletBalance != null`**; and a `0.00` balance renders as `$0.00` because it is a real
fetched value, not a fabricated one. The nullable param is what keeps
`earnings_cubit_test.dart`, `earnings_dashboard_data_truth_test.dart`, `shell_role_tabs_test.dart`,
`shell_tab_badge_test.dart`, `shell_role_toggle_mounted_test.dart` and
`shell_dual_role_landing_test.dart` compiling untouched — all six construct
`EarningsCubit(repository: …)` positionally-by-name.

---

## 4. Tokens

### 4.1 Every style expression that changes

The file is already hex-free; what changes is that ad-hoc `textTheme.copyWith(fontWeight:)` calls
become ramp reads.

| today | line | becomes |
|---|---|---|
| `OMDSAppBar(title:)` | 48 | deleted → `context.jeebText.h2` + `colorScheme.primary` |
| `EdgeInsets.all(Spacing.medium)` (16 gutter) | 110, 148 | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` (24) — §4.3 `--screen-gutter` |
| `theme.textTheme.labelLarge` | 258 | `JeebSectionLabel` (12.5/w700/ls1.2/uppercase/`mutedText`) |
| `displaySmall?.copyWith(fontWeight: bold)` | 262 | `context.jeebText.statHero` (38/w800/ls−1) |
| `bodySmall?.copyWith(color: onSurfaceVariant)` | 270, 316, 413 | `context.jeebText.bodySmall` + `JeebSemanticColors.mutedText` |
| `Card()` ×5 | 252, 298, 390 | `JeebNavySurfaceCard` (hero) / `JeebOutlinedCard` (fee strip) / plain `Container` (rows) |
| `Icon(Icons.percent_outlined, color: onSurfaceVariant)` | 303 | Ø38 `surfaceContainerHigh` disc + `Icons.percent` in `colorScheme.primary` |
| `titleSmall` | 312, 486 | `context.jeebText.cardTitle` / `JeebSectionLabel` |
| `titleMedium?.copyWith(fontWeight: bold)` | 326, 397 | `context.jeebText.titleProminent` |
| `labelSmall` | 405, 412 | `context.jeebText.caption` |
| `bodyMedium` / `bodyMedium?.copyWith(w600)` | 448, 452 | folded into hero stat #3 (`caption` label + `titleProminent` value) |
| `OmdsChip` | 214 | `JeebSelectChip(role: sort)` |
| `OmdsSettingsRow` ×2 | 528, 549 | `JeebCtaButton.outline` (footer) / `JeebCtaButton.text` (section header) |
| `OmdsLoadingButton` | 571 | `JeebCtaButton.primary(isLoading:)` — or kept, §3.8 |
| `ListTile` | 506 | `Container` + `Row` |

### 4.2 New token consumers introduced

| token | where | source |
|---|---|---|
| `JeebShadows.heroNavy` | the navy hero | §4.5, named for "stat hero cards (19, 23)" |
| `JeebShadows.ctaNavy` | Export PDF pill | `html:66` `0 10 24 rgba(11,19,81,.28)` |
| `JeebSemanticColors.accentRing` | the Ø160 decorative circle | `html:23` `rgba(215,59,0,.3)` |
| `JeebSemanticColors.mutedText` | eyebrow, stat labels, fee subtitle, row subtitle | `--jeeb-periwinkle` |
| `colorScheme.surfaceContainerHigh` | `%` disc, delivery rows | `--jeeb-surface-high` `#EAE7EB` |
| `colorScheme.outline` | fee strip border, wallet pill border | `--jeeb-brown-outline` 1.5px |
| `colorScheme.onPrimary.withValues(alpha: .12)` | hero divider | `html:27` |

**Not used on this screen, deliberately:** `context.jeebRoles.accent` as a fill (19 has exactly one
orange element and it is the 30% decorative ring — R5); `OmdsColorTokens.starRatingColor` (§4.1
explicitly: "On 01, 16, **19**, 21 and 24 the ★ is an unstyled glyph" — and here it is refused
outright, §9-C1); `JeebSemanticColors.accentTint`; `readTick`.

### 4.3 Copy changes — all in `earnings_dashboard_l10n.dart` (lane-owned)

That file is the feature's sanctioned l10n bridge (its own class doc: it "supplies the
genuinely-missing strings from a feature-local EN/AR map until the integrator lands the dedicated
keys"). New copy lands there as `_pick(en, ar)` pairs — **no ARB edit, so the l10n parity gate is
untouched** — and the same keys go into `50_ROUTE_REQUESTS.md` / the integrator batch as a follow-up.

| getter | EN | AR |
|---|---|---|
| `totalCashHint` *(replaces existing)* | `Paid to you directly — never through Jeeb.` | `يُدفع لك مباشرة — لا يمر عبر جيب أبدًا.` |
| `netPerOfferLabel` *(shortened for the stat slot)* | `Avg kept / offer` | `متوسط المحتفظ به / عرض` |
| `feesPaidHint` *(rewritten, rate interpolated)* | `$kJeebCommissionPercent% per won offer, from your wallet` | `$kJeebCommissionPercent٪ لكل عرض فائز، من محفظتك` |
| `activityLink` *(shortened)* | `See all` | `عرض الكل` |
| `walletLink` *(shortened for the pill)* | `Wallet` | `المحفظة` |
| `deliveryRowTitleDated(id, weekday)` *(new)* | `Delivery $id · $weekday` | `توصيلة $id · $weekday` |
| **deleted** | `walletLinkSubtitle`, `activityLinkSubtitle` | — |

`totalCashLabel` ("Total cash earned") is **kept, not replaced** by the board's "Cash collected":
both are D41-safe, the shipped one is already translated, and it is asserted by
`earnings_dashboard_data_truth_test.dart` (§8). The board's semantic is identical; the divergence is
one word and it buys back a translation round-trip. It renders **uppercase** through
`JeebSectionLabel`, which is the actual visual change the board asks for.

The weekday comes from `DateFormat.E().format(DateTime.parse(item.date))` under
`Localizations.localeOf(context)` — `intl` is already imported at `:4` and already used for
`DateFormat.yMMM()` at `:464`. When `item.date` is empty or unparseable (the mock omits it on some
rows), fall back to the undated `copy.deliveryRowTitle(id)`.

---

## 5. Data — what exists, what does not

Verified against `earnings_summary.dart` and the real mock body in `earnings_cubit_test.dart:61-81`.

**Buildable from state today (no new call, no derivation beyond arithmetic that already exists):**

| board figure | source |
|---|---|
| `$127.50` cash collected | `summary.totalCashEarned` |
| `18 Deliveries` | `summary.deliveryCount` |
| `$7.08 Avg kept / offer` | `summary.netPerOffer` — `(totalCashEarned − feesPaid) / deliveryCount`, already the D44 getter |
| `$12.75` fees | `summary.feesPaid` |
| `10%` in the fee subtitle | `kJeebCommissionPercent` |
| `+$8.00` / `fee $0.80` per row | `item.cashCollected` / `item.feePaid` |
| `· Fri` | `DateFormat.E()` over the existing `item.date` (`syncedAt`/`deliveredAt`) |
| `Export PDF` | `EarningsRepository.exportEarningsPdf` — shipped, `GET /v1/jeeb/earnings/export` (`dio_earnings_repository.dart:34`). §7.6 lists "PDF export (19)" as suspect; **it is not** — it is implemented and DI-bound |

**Gaps — omit, never fake:**

| # | board asks for | why it cannot be built |
|---|---|---|
| **G1** | `★ 4.8` / `This week` | No period-scoped rating exists anywhere. `CustomerProfileViewData.rating` (`customer_profile/domain/customer_profile_view_data.dart:45`) is an **all-time, per-role** average from `GET /user-management/users/me` in a different feature — rendering it under the label "This week" would be a lie with a number attached, which is the JEBV4-176 failure mode. **Refused, §9-C1.** Slot 3 renders `earnings_member_since` instead |
| **G2** | per-row tier emoji `⚡ 🤝 🚀` | `EarningsDeliveryItem` has no tier. The wire item is `{id, deliveryId, type:'delivery', amount:{value,currency}, syncedAt}` — `type` is the ledger entry kind, not a tier. `JeebTierChip` needs a `TierId` there is no way to obtain. `// TODO(redesign-24): needs gateway tier on the earnings entry — omitted, not faked.` |
| **G3** | row title `Pharmacy run`, `Groceries, Spinneys` | no item name/description on the entry. Row keeps `Delivery <id>` and gains only the weekday |
| **G4** | `$6.40` wallet balance | exists but lives behind `WalletRepository` — plumbing, not truth. §3.9 |

No endpoint is invented. No field is invented. No placeholder number is rendered.

---

## 6. Semantics wiring details

### 6.1 Why `earnings_total_cash` goes on the amount block, not the whole hero

If the hero card carried `earnings_total_cash` and the stats row carried `earnings_net_per_offer` /
`earnings_deliveries_count` / `earnings_member_since` inside it, the outer node would swallow the
three inner ones unless it also set `explicitChildNodes: true` (§7.5, the `active_request_card.dart`
idiom). That works, but it makes four frozen Maestro-asserted ids depend on one flag being right.

Scope `earnings_total_cash` to the eyebrow + amount + trust-line `Column` instead, and let the stat
`Semantics` be siblings below the divider. Same card, no nesting, zero flag risk. Both are valid;
this one cannot regress silently.

### 6.2 The delivery-row list

`earnings_delivery_row_${item.deliveryId}` stays a `container: true` wrapper. Its children are three
`Text`s with no ids, so no `explicitChildNodes` is needed.

### 6.3 Semantic labels that must survive the visual compression

- hero stat #2 keeps `Semantics(hint: copy.netPerOfferHint)` — the D44 explanation has no visual slot.
- the money `Text`s keep their existing `semanticsLabel: value` (`:265`, `:329`, `:510`).
- the section header keeps `Semantics(label: copy.breakdownTitle)` (§3.5).

---

## 7. RTL

The screen is RTL-safe today and must stay so. Four hazards, three of them new:

### 7.1 The decorative ring (new)

`html:23` positions the circle at `right: -50`. Under `ar` the hero must mirror it to the start edge,
because it is a top-**END** corner ornament per R6/`02-PLAN-ENHANCED.md` §2-R6. Use
`PositionedDirectional(end: -50, top: -50)` inside the card's `Stack` — never `Positioned(right:)`.
`JeebNavySurfaceCard`'s ring parameter should already do this; if it exposes `Positioned`, that is a
kit bug worth reporting rather than working around locally.

### 7.2 The `+` on `+$8.00` (new, and the one real bidi trap)

`MoneyFormat.format` returns `U+2066 $8.00 U+2069` — an LTR isolate. `U+002B PLUS SIGN` is bidi class
**ES**, which resolves as a neutral next to an isolate and therefore takes the *paragraph* direction:
concatenating `'+' + MoneyFormat.format(...)` renders as `$8.00+` in Arabic, with the sign on the
wrong side. The `+` must live **inside** the isolate.

Correct fix (wiring request, one file, additive):

```dart
// lib/core/formatting/money_format.dart
static String format(double amount, {String currency = 'USD', bool signed = false}) {
  ...
  final sign = signed && amount > 0 ? '+' : '';
  final token = (code.isEmpty || code == 'USD') ? '$sign\$$value' : '$sign$code $value';
  return '$_lri$token$_pdi';
}
```

Default `false` ⇒ every one of the app's existing call sites is byte-identical, and the isolate now
wraps the sign. **If the owner refuses a shared-core edit: drop the `+`.** It is decorative — the row
sits under a hero labelled "CASH COLLECTED" and beside a line that already says "fee $0.80". Do
**not** hand-roll a local isolate string in `lib/features`.

### 7.3 Directional insets everywhere

The board's `padding: 14px 24px 0`, `margin: 16px 24px 0`, `padding: 0 24px 30px` and `padding: 11px
14px` all become `EdgeInsetsDirectional`. The gate's `EdgeInsets\.[a-zA-Z]+\([0-9]` regex does not
catch `EdgeInsetsDirectional`, so this is discipline, not a gate — write the tokens anyway
(`Spacing.xLarge`, `Spacing.small`, `Spacing.twoXLarge`).

### 7.4 Text scale 200%

Two places clip if built naively: the three-stat hero row (three columns + two 20px gaps in ~350dp)
and the two footer pills (`Wallet` / `Export PDF` at 14px). Use `Flexible` (not `Expanded`) on the
stat columns and let their labels wrap to two lines; give the footer pills
`textAlign: TextAlign.center` + `maxLines: 2`. The current `_StatsRow` already survives 200% because
it is two cards, not three; three is the regression risk this rebuild introduces.

---

## 8. Test impact

### 8.1 `test/features/earnings/earnings_dashboard_data_truth_test.dart` — 2 legitimate line edits

| line | today | after | why |
|---|---|---|---|
| 103 | `expect(find.text('Total cash earned'), findsNothing)` | `find.text('TOTAL CASH EARNED')` | `JeebSectionLabel` uppercases internally (`html:24` `text-transform: uppercase`). The **assertion's meaning is unchanged** — the empty state still must not render the funded hero |
| 111 | `expect(find.text('Total cash earned'), findsOneWidget)` | `find.text('TOTAL CASH EARNED')` | same |

Everything else in that file passes untouched, and this is worth stating precisely because it is the
T11/SW-01 guard:

- `:99` `find.text('No earnings yet this period')` — the empty body still renders `OmdsEmptyState`
  with `copy.emptyTitle`. **Unchanged.**
- `:102` `find.textContaining('0.00')` `findsNothing` in the empty state — the empty body renders the
  title, the period chips and the empty state. **No money widget exists in that tree**, and the
  footer (the only place a `$0.00` wallet balance could ever appear) is deliberately not rendered in
  the empty state (§9-R3). **Unchanged, and this is the reason for that decision.**
- `:114` `find.text('⁦$1,000.00⁩')` — the hero amount is still
  `MoneyFormat.format(1000, 'USD')`, one widget. **Unchanged.**

If either uppercase edit "fixes" a failure that is not exactly these two strings, the proposal is
wrong — stop and re-read, do not broaden the finder.

### 8.2 Untouched by construction

| suite | why it is safe |
|---|---|
| `test/earnings_cubit_test.dart` | pure domain/cubit; no widget assertions. Only affected if the §3.9 wallet param lands, and that param is **optional** |
| `test/decision_violations_test.dart:176-208` | asserts on `SettlementDetailScreen`, not this screen. The refusal in §3.4 is what keeps it that way |
| `test/core/jeeb_commission_test.dart` | guards against a *second* copy of `0.10` in `lib/`. §4.3 interpolates `kJeebCommissionPercent`; typing `10%` into the string would fail it |
| `test/shell_role_tabs_test.dart:158,205,222` | `find.text('Earnings')` `findsWidgets` — the **tab label** still renders it, so deleting `OMDSAppBar` does not break it. (It would break `findsNWidgets(2)`; the assertion is `findsWidgets`, verified) |
| `shell_tab_badge_test`, `shell_role_toggle_mounted_test`, `shell_dual_role_landing_test`, `jeeber_recap_path_binding_test` | construct the repository/cubit only |
| `test/features/wallet/wallet_hub_screen_test.dart:93` | asserts `wallet_earnings_row` on the *wallet* side of the edge; this lane does not touch it |

### 8.3 Goldens

None. 19 has no committed golden (the six PNGs are 18 + the 24-sheet). Nothing to regenerate.

### 8.4 Tests worth ADDING (never in place of the above)

- `earnings_period_${p.name}` ×3 emitted for all three `EarningsPeriod.values`.
- `earnings_member_since` emitted iff `summary.memberSince != null` (the Maestro AC1 assertion has no
  widget-test twin today).
- `earnings_wallet_link` and `earnings_export_cta` are visible **without scrolling** — the property
  the docked footer is buying, and the one a future refactor would silently take away.
- an `ar` RTL smoke: `+$8.00` renders with the sign on the left of the digits (§7.2).

---

## 9. Conflicts and refusals

**C1 — `★ 4.8 / This week` is refused.** `html:30`. No period-scoped rating exists on any contract the
app consumes; `EarningsSummary` has no rating field and the earnings endpoint returns none. The only
rating in the app (`CustomerProfileViewData.rating`, `ratingCount`) is an all-time per-role average
owned by another feature. Rendering it beneath the label "This week" would attach a real number to a
false claim. **Slot 3 of the hero renders `earnings_member_since` instead** — data the screen already
had, in a slot the board built for a third stat. If the owner wants a rating there, the honest form is
`★ 4.8 / Overall` sourced from `customer_profile`, which is a cross-feature wiring decision, not this
lane's. Consistent with `02-PLAN-ENHANCED.md` §4-C6 (the reach-count precedent).

**C2 — `Jeeb fees paid` is refused.** `html:37`. D41/D44 pin the platform's cut as "Platform fee"; the
shipped `feesPaidLabel` is already "Platform fees paid". Same class as C5 in `02-PLAN-ENHANCED.md`
(17's "Jeeb fee (10%)"). The strip keeps the compliant string; the board's shape is adopted in full.

**C3 — the literal `10%` is refused as a string.** `html:38`. `kJeebCommissionPercent` is
interpolated. `jeeb_commission_test.dart` fails any second copy of the rate in `lib/`.

**C4 — no conflict with D56, D52, D20, B04, the accept-sheet tense, the pinned chat summary, or the
deep-link guard.** None of them touch this surface. Explicitly checked.

### Risks

**R1 — `JeebCtaFooter` has a fourth realized form (two equal pills) that the kit does not spec.**
Cheap either way (§3.8), but if three lanes each hand-roll it, the plan's chip-drift failure mode
repeats one component up.

**R2 — the hero is the screen's whole information hierarchy.** Four numbers that today occupy four
cards now share one 20px-padded card with an 18px gap. At `ar` + 200% text this is the first thing
that breaks. `Flexible`, not `Expanded` (§7.4).

**R3 — the footer is not rendered in the empty state, and that is a deliberate, arguable call.** The
board has no empty state. Rendering the footer there would put the wallet exit on a screen where a
jeeber with zero earnings arguably wants it most — but it would also put a money token inside the tree
that `earnings_dashboard_data_truth_test.dart:102` asserts is money-free. This proposal keeps parity
with today (footer in the funded body only) and flags the UX question to the owner rather than
resolving it by weakening the T11 guard.

**R4 — density is unverifiable in a diff (plan risk #13).** With 3 rows this screen ends near 60% of
the viewport. The review must be "hold the PNG next to the simulator at the same scale", not "the
tokens are right".

---

## 10. Build order for this lane

Blocked on Wave 1 kit steps 1 (`JeebOutlinedCard` + `JeebNavySurfaceCard`), 4 (`JeebCtaButton` +
`JeebCtaFooter`), 5 (`JeebSelectChip` + `JeebChipRow`) and 11's `JeebSectionLabel`. Not blocked on
`JeebInfoNote`, `JeebMoneyBreakdown`, `JeebProfileHeader`, `JeebTopBar`, `JeebAvatar`, `JeebTierChip`
or any waveform/mic work — 19 consumes none of them.

1. `earnings_dashboard_l10n.dart` — new/edited EN+AR pairs, delete the two dead subtitle getters.
2. Shell of the screen: `SafeArea` + `Column` + hoisted title/chips + `Expanded` + footer stub.
   Verify all 13 identifiers still emit before styling anything.
3. `_CashHero` (hardest: ring, divider, three on-navy stats, `earnings_total_cash` scoping).
4. `_FeeStrip`, `_BreakdownHeader`, `_DeliveryRow`.
5. Footer (`JeebCtaFooter.dual` or the local fallback).
6. `earnings_dashboard_data_truth_test.dart` — the two uppercase edits, then the four added tests.
7. `dart analyze --fatal-infos .` vs `_BASELINE.md`; `bash tool/check_design_tokens.sh`;
   `flutter test test/features/earnings/ test/earnings_cubit_test.dart test/shell_role_tabs_test.dart`.
