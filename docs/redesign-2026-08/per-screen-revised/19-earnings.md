# 19 · Earnings — REVISED instruction set (authoritative)

Reviewed against: `screens/19-earnings.{png,html,note.md}`, the live source of every lane file,
`03-WAVE1-KIT.md` **and the kit source itself** (`lib/core/widgets/jeeb/`), `00-MIGRATION-PLAN.md`
(STOP block, §4.4, §5, row 481), `02-PLAN-ENHANCED.md` (R1–R14, C5/C6), `_BASELINE.md`,
`.maestro/flows/jm-052-earnings-dashboard.yaml` + `jm-053-wallet-hub.yaml`, and every cited test.
Every `file:line` below was re-checked on 2026-08-03. Where this document contradicts the original
proposal (`per-screen/19-earnings.md`), **this document wins**.

Lane: feature dir `lib/features/earnings/` · file
`lib/features/earnings/presentation/earnings_dashboard_screen.dart` (581 LOC, 13 identifier
literals). Mounted twice from ONE provider (`EarningsTab`): as the jeeber shell tab
(`lib/features/shell/shell_screen.dart` `_Tab(id: 'earnings')`, ~`:235-242`) **and** as the
standalone route `/earnings` (`app_router.dart:1645-1650`, target of the wallet hub's
`wallet_earnings_row`). Verdict: **rebuild of the presentation tree in place.** Domain/data survive
untouched; cubit/state get one small additive change (task 3). **No route, DI, theme, or kit
wiring. No new Semantics identifier.**

## What changed vs the original proposal

- **CUT kit request #1 ("`JeebCtaFooter` needs a `dual` form").** It already exists:
  `JeebCtaFooter.split(expandLeading: true)` renders two equal `flex:1` children (kit §2.2 —
  "12: true (both flex:1)"). No screen-local fallback `Row`, no kit change.
- **CUT kit request #2 ("`JeebCtaButton.primary` needs `isLoading`").** `isLoading` shipped
  (kit §2.2: 22px spinner in the variant ink, `isInteractive` gates the tap). `OmdsLoadingButton`
  is deleted, not kept.
- **CUT the hand-rolled decorative ring.** The proposal builds a `Stack` +
  `PositionedDirectional(end: -50)` circle by hand. The kit ships it as data:
  `JeebNavyRing.statTopEnd` — doc'd *"19: Ø160, top −50, end −50"*
  (`jeeb_navy_surface_card.dart:37-38`) — clipped, directional, and `accentRing`-inked inside
  `JeebNavySurfaceCard(rings:)` with the safe no-bang token read (`:289-291`). Hand-rolling it is
  exactly the "private copy of a kit widget" review defect.
- **CUT the bespoke `Container` + `Row` delivery row.** Use kit `JeebListRow` (its default title
  treatment is 14/w700 `colorScheme.primary` — `jeeb_list_row.dart:149-155` — the board's row
  anatomy) inside a screen-owned grey rounded `Container`. Also cuts the proposal's
  `Spacing.small - 1` / `Spacing.small + 2` token arithmetic throughout — use kit defaults and
  nearest tokens (§4.4), noting the 1–3px divergences.
- **CUT the `earnings_tab.dart` wiring request (§3.9 of the proposal).** The wallet-balance
  plumbing needs no cross-feature edit: give `EarningsCubit` an optional `WalletRepository?`
  param that defaults through `sl.isRegistered<WalletRepository>()` — the exact shipped precedent
  at `offer_submission_screen.dart:94-96` (and `chat_cubit.dart` for a DI import in
  `application/`). `earnings_tab.dart`, DI and the router stay untouched.
- **CORRECTED: `JeebCtaButton` has no `shadow:` parameter.** The proposal's
  `JeebCtaButton.primary(height: 52, shadow: JeebShadows.ctaNavy)` does not compile; the primary
  variant paints `JeebShadows.ctaNavy` itself (kit §2.2), which is byte-identical to the html:66
  shadow `0 10 24 rgba(11,19,81,.28)`.
- **CORRECTED the shell citation.** The file is `lib/features/shell/shell_screen.dart` (not
  `shell/presentation/`); `_NavBarContentInset` is `:275-296`, mounted at `:127`. Substance
  confirmed: the shell consumes the TOP inset (`SafeArea(bottom: false)`, `:111-112`) and re-seeds
  `Sizes.fiveXLarge` into both bottom insets, so this screen needs `SafeArea(top: false)` only.
  The proposal's `SafeArea(top: true, bottom: true)` top half is a no-op — drop it.
- **CORRECTED an overstated test claim:** `test/core/jeeb_commission_test.dart` scans for decimal
  `0.1|0.10…` literals only (`_rateLiteral`, `:60`) — a typed `'10%'` string would NOT fail it.
  The interpolation rule stands anyway: plan row 481 pins "10% only via `kJeebCommissionRate`".
- **ADDED a consequence the proposal missed:** deleting `OMDSAppBar` removes the auto back button
  on the **pushed** `/earnings` route (wallet hub → earnings, jm-053 AC4). The board is a tab root
  with no top bar; system back / predictive back still pops. jm-053 only asserts
  `earnings_total_cash` visibility (`:143`) — unaffected. Call this out in the PR notes.
- **KEPT (verified true):** all 13 identifier lines of §1; the two data-truth uppercase edits and
  ONLY those; refusal C1 (no period-scoped rating exists — `CustomerProfileViewData.rating`,
  `customer_profile_view_data.dart:45`, is all-time/per-role); refusal C2 ("Jeeb fees paid" —
  D41/D44); the G2/G3 data gaps (wire item is `{deliveryId, amount, syncedAt}`,
  `earnings_summary.dart:17-20` — no tier, no item name); the `earnings_total_cash` scoping
  (§5.1); the `MoneyFormat.signed` wiring request (checked against `money_format.dart:33-38`);
  the refusal of `JeebProfileHeader` and `JeebMoneyBreakdown` for this screen (§2 divergences).
- **HARDENED:** the consumer-owned Semantics idiom (kit §1.1 calls it "the dominant call-site
  idiom") — every one of the 13 frozen wrappers is kept **byte-verbatim** and NO kit widget gets
  an `identifier:`; never read `Theme.of(context).extension<JeebSemanticColors>()!` with a bang —
  `wrapForTest` builds on `ThemeData.light()` (`test/support/sync_app_localizations.dart:42`) and
  the bang crashes every widget test — use the kit's own fallback idiom; the sort chips get a
  `MinTapTarget` wrapper (kit §5: min-48dp is call-site responsibility; helper at
  `lib/core/accessibility/accessibility.dart`).

---

## 1. Semantics inventory — FROZEN (all 13 literals re-verified in source 2026-08-03)

Every wrapper below is kept **byte-identical** (same identifier string, same
`container:`/`button:` flags). Kit widgets under them get **no** `identifier:` param — they add no
node of their own when none is passed (kit §1.1), so the frozen wrapper stays the only node.

| identifier | today at | after the rebuild |
|---|---|---|
| `earnings_dashboard_root` | `:45` (`container: true`, wraps the Scaffold) | unchanged |
| `earnings_period_${period.name}` (×3) | `:212` (`button: true`) | wrapper kept verbatim, re-homed onto `MinTapTarget(JeebSelectChip(role: sort))` |
| `earnings_total_cash` | `:250` (`container: true`) | re-homed onto the eyebrow+amount+trust-line `Column` INSIDE the navy hero — not the whole card (§5.1) |
| `earnings_fees_paid` | `:296` (`container: true`) | re-homed onto the outlined fee strip |
| `earnings_net_per_offer` | `:350` (`container: true`, via `_StatCard`) | re-homed onto hero stat #2; gains `hint: copy.netPerOfferHint` (§5.2) |
| `earnings_deliveries_count` | `:362` (`container: true`) | re-homed onto hero stat #1 |
| `earnings_member_since` | `:438` (`container: true`; conditional on `summary.memberSince != null`, `:158`) | re-homed onto hero stat #3 — **same condition** |
| `earnings_breakdown_empty` | `:478` (`container: true`) | unchanged — shown when `summary.deliveries.isEmpty` in a funded period |
| `earnings_delivery_row_${item.deliveryId}` | `:504` (`container: true`) | unchanged — wraps the grey row container |
| `earnings_wallet_link` | `:525` (`button: true, container: true`) | re-homed onto the footer outline pill |
| `earnings_activity_link` | `:546` (`button: true, container: true`) | re-homed onto the section-header trailing text link (§4.6) |
| `earnings_export_cta` | `:568` (`button: true, container: true`) | re-homed onto the footer navy pill |
| `earnings_empty` | `:115` (`container: true`) | unchanged |

**New identifiers: none.**

### Maestro — `.maestro/flows/jm-052-earnings-dashboard.yaml` passes unchanged (do not edit it)

- AC1 `assertVisible: earnings_member_since` is unconditional in the flow; the id stays
  conditional on the wire exactly as today — identical behaviour, not this lane's regression
  surface.
- `scrollUntilVisible: earnings_wallet_link / earnings_activity_link (direction: DOWN)` — both
  become always-on-screen (footer / section header). `scrollUntilVisible` succeeds immediately
  for an already-visible element.
- `assertNotVisible: earnings_gross_payout | earnings_commission_line | earnings_net_payout` —
  nothing here introduces any of them.
- `jm-053-wallet-hub.yaml:143` asserts `earnings_total_cash` after tapping `wallet_earnings_row`
  — survives (the id still emits in the funded hero).

---

## 2. Deliberate divergences from the board (note them in the PR)

| Board | Ship | Why |
|---|---|---|
| header per plan §5 #23 / kit §2.4 note ("19 uses `JeebProfileHeader`") | a padded `Text(copy.title, jeebText.h2)` | Measured: `html:15` is a bare 20/w700 title — no Ø46 avatar, no eyebrow, no rating pill (the `★ 4.8` at `html:30` is a hero *stat*, refused below). `JeebProfileHeader` with every slot null renders a 19px `name` — wrong size, zero value. A lone title is not that widget's pattern, so this is not a "private copy" |
| fee strip per the prompt's "Use `JeebMoneyBreakdown`" | `JeebOutlinedCard` single-value row | Measured: 19 has **no breakdown** — no label/value rows, no divider, no total, no lock footnote (`html:34-41` is icon-disc + title + subtitle + one value). `JeebMoneyLine` has no subtitle slot. D41/D44 wording is enforced here by `earnings_dashboard_l10n.dart`, which is fee-only by construction (its class doc) |
| `CASH COLLECTED` | keep `totalCashLabel` ("Total cash earned") | already translated, D41-equivalent; the real change the board asks for is the uppercase `JeebSectionLabel` treatment, which it gets |
| `Jeeb fees paid` (`html:37`) | keep `feesPaidLabel` ("Platform fees paid") | **REFUSED** — D41/D44; plan row 481 pins "Platform fee", never a Jeeb-branded fee line; same class as `02-PLAN-ENHANCED.md` C5 |
| `★ 4.8 / This week` (`html:30`) | hero stat #3 = member-since (`DateFormat.yMMM`) | **REFUSED** — no period-scoped rating exists on any contract; `EarningsSummary` has no rating field; the only rating in the app is all-time/per-role (`customer_profile_view_data.dart:45`). A real number under a false label is the JEBV4-176 failure mode (C6 precedent) |
| `10%` typed in the subtitle (`html:38`) | interpolate `kJeebCommissionPercent` (`jeeb_commission.dart:78`) | plan row 481; single-source rule |
| row leading tier emoji `⚡🤝🚀` (`html:47`) | omitted, no leading slot | **data gap** — `EarningsDeliveryItem` carries no tier (`earnings_summary.dart:17-20`); `JeebTierChip` needs a `TierId` that does not exist. TODO, never faked |
| row title `Pharmacy run · Fri` | `Delivery <id> · Fri` | item name is a data gap; the **weekday IS derivable** from the existing `item.date` |
| `Wallet · $6.40` | `Wallet` + ` · $x.xx` **only when a real balance loaded** | `WalletBalance.availableBalance` exists (`wallet_repository.dart:26`) behind DI (`injection_container.dart:741`); fetched fire-and-forget (task 3); never a placeholder, `$0.00` renders only as a real fetched zero |
| `fee $0.80` word order | keep `deliveryRowFee` ("$0.80 fee") | shipped, translated; word order is cosmetic — do not churn a translation |
| footer pad bottom 30, gap 10 | `JeebCtaFooter.docked` (32), default `spacing` (12) | 30→32 sanctioned by `02-PLAN-ENHANCED.md` §3.3; 10→12 nearest default, same rule |
| row r14, strip pad 14/16, `%`-disc Ø38 | r16 (`OmdsBorderRadius.medium`), kit default 13/16, Ø40 (`Sizes.threeXLarge`) | §4.4 radius bridge ("14 → `.medium` at feature level"); nearest-token rule; kit-exact px live inside the kit only |
| stat/fee/amount weights (w800 at 17/16/14px) | `titleProminent` (17/w700) / `cardTitle` (15.5/w700) | R3: no `fontSize:` literals in features; nearest ramp entry, weight carries via ink |

---

## 3. Task list — execute top to bottom

**Task 1 — Write the wiring file.** Create `docs/redesign-2026-08/wiring/19-earnings.md` with the
two blocks from §8. Write the row-amount code as if the `MoneyFormat.signed` request were granted
(one call site will not compile until the integrator lands it — expected; say so in your report).

**Task 2 — `earnings_dashboard_l10n.dart` (lane-owned; no ARB edit).**
Add `import '../../../core/jeeb_commission.dart';`. Then:

| getter | change | EN | AR |
|---|---|---|---|
| `totalCashHint` | replace value | `Paid to you directly — never through Jeeb.` | `يُدفع لك مباشرة — لا يمر عبر جيب أبدًا.` |
| `netPerOfferLabel` | replace value (stat-slot length) | `Avg kept / offer` | `متوسط المحتفظ به / عرض` |
| `feesPaidHint` | replace value, rate interpolated | `$kJeebCommissionPercent% per won offer, from your wallet` | `$kJeebCommissionPercent٪ لكل عرض فائز، من محفظتك` |
| `walletLink` | replace value (pill length) | `Wallet` | `المحفظة` |
| `activityLink` | replace value (header-link length) | `See all` | `عرض الكل` |
| `deliveryRowTitleDated(String id, String weekday)` | NEW | `Delivery $id · $weekday` | `توصيلة $id · $weekday` |
| `walletLinkSubtitle` (`:108-109`), `activityLinkSubtitle` (`:113-116`) | **DELETE** | — | — |

Sole consumers of the two deleted getters are this screen's `:530`/`:551` (grep-verified). Keep
`totalCashLabel`, `feesPaidLabel`, `netPerOfferHint`, `deliveriesLabel`, `memberSinceLabel`,
`breakdownTitle`, `deliveryRowTitle`, `deliveryRowFee`, `period(...)`, the empty/error/export
getters — all still consumed.

**Task 3 — wallet balance plumbing (all lane-owned; zero wiring).**
- `application/earnings_state.dart`: add `final WalletBalance? walletBalance;` (ctor default
  null, `copyWith` via `walletBalance: walletBalance ?? this.walletBalance`, add to `props`).
  Import `../../wallet/domain/wallet_repository.dart` (cross-feature *import*, not edit —
  precedent `offer_submission_screen.dart:77`).
- `application/earnings_cubit.dart`:

```dart
EarningsCubit({
  required EarningsRepository repository,
  WalletRepository? walletRepository,          // OPTIONAL — every call site keeps compiling
  this.jeeberId = '',
})  : _repository = repository,
      _walletRepository = walletRepository ?? _resolveWalletRepository(),
      super(const EarningsState()) {
  loadEarnings();
  _loadWalletBalance();                        // fire-and-forget, once per mount
}

// Same seam as offer_submission_screen.dart:94-96 — tests that register
// nothing resolve null and never fetch.
static WalletRepository? _resolveWalletRepository() =>
    sl.isRegistered<WalletRepository>() ? sl<WalletRepository>() : null;

Future<void> _loadWalletBalance() async {
  final repo = _walletRepository;
  if (repo == null) return;
  try {
    final balance = await repo.fetchBalance();
    if (!isClosed) emit(state.copyWith(walletBalance: balance));
  } on WalletRepositoryException {
    // A wallet read must never degrade the earnings screen: no error state,
    // no retry — the footer pill simply renders without the balance suffix.
  }
}
```

  (DI import in `application/` has precedent: `chat_cubit.dart`.) Existing constructions —
  `earnings_cubit_test.dart` ×5, `earnings_dashboard_data_truth_test.dart:56`,
  `earnings_tab.dart:23`, `batch_03_entries.dart:465` — all pass `repository:` by name and
  compile untouched; with no registered wallet repo they fetch nothing, so every existing
  `blocTest` emission sequence is unchanged.

**Task 4 — rebuild `earnings_dashboard_screen.dart`.** Keep the class name, the const
constructor, the `BlocConsumer` + `_onStateChange` listener (`:57-70`) verbatim. New structure:

```
Semantics(identifier: 'earnings_dashboard_root', container: true)          // :44-46 verbatim
└ Scaffold                                                                 // NO appBar — :48 deleted
  └ BlocConsumer<EarningsCubit, EarningsState>(listener: _onStateChange)
    └ SafeArea(top: false)               // bottom = tab bar via _NavBarContentInset, or the
      └ Column                           // device inset on the standalone /earnings route
        ├ Padding(STEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0)) // html:15 — 14→16
        │  └ Text(copy.title, style: context.jeebText.h2.copyWith(color: cs.primary))
        ├ Padding(STEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0)) // html:16
        │  └ _PeriodFilterRow            // ALWAYS mounted — chips stay tappable in every state
        ├ Expanded(child: <state body>)
        └ if (ready && summary funded) _EarningsFooter                     // §4.7
```

State bodies inside the `Expanded`:

| state | body |
|---|---|
| `loading` | `Center(OmdsLoadingState())` — title+chips stay mounted (improvement, free) |
| `error` | the existing `OmdsErrorState` block (`:80-85`) |
| ready + `summary.isEmpty` | `OmdsPullToRefresh > ListView(AlwaysScrollableScrollPhysics, padding: horizontal Spacing.xLarge)` containing ONLY the `earnings_empty` block (`:114-125` verbatim). **No footer, no money widget** — this is what keeps `data_truth_test:102` (`textContaining('0.00')` → nothing) true |
| ready + data | `_ReadyBody` below |

`_ReadyBody` = `OmdsPullToRefresh > ListView(padding: EdgeInsetsDirectional.symmetric(horizontal:
Spacing.xLarge))` with children, gaps as `SizedBox(height: <token>)`:
`Spacing.medium` → hero → `Spacing.small` (html 12) → fee strip → `Spacing.medium` (html 18→16) →
section-header row → `Spacing.xSmall` (html 10→8) → delivery rows at `Spacing.xSmall` gaps
(html 8, exact) → `Spacing.medium` tail.

**Density (R1):** with 2–3 rows the list ends ~60% down and the rest is plain white above the
docked footer. Do not add a `Spacer`, do not centre, do not `shrinkWrap` — `Expanded(ListView)`
produces the emptiness for free.

### 4.1 Period pills — `:197-234` → `JeebChipRow` of `JeebSelectChip(role: sort)`

```dart
JeebChipRow(                                   // spacing default 8 — html:16 gap 8, exact
  children: [
    for (final p in EarningsPeriod.values)
      Semantics(
        identifier: 'earnings_period_${p.name}',   // FROZEN — wrapper verbatim from :211-213
        button: true,
        child: MinTapTarget(                       // kit §5: 48dp is call-site duty
          child: JeebSelectChip(
            role: JeebChipRole.sort,               // 8/15 · 12.5/w600→700 — html:17-19
            label: _label(p),                      // existing switch, :224-233
            selected: p == state.period,
            onTap: () => context.read<EarningsCubit>().loadEarnings(period: p),
          ),
        ),
      ),
  ],
)
```

`OmdsChip` (`:214`) is deleted. Never pass a padding — the `sort` role IS the measured spec
(kit §2.3 cites 19 by name at its `:17` doc table).

### 4.2 The navy hero — `_TotalCashCard` (`:237-280`) + `_StatsRow` (`:339-424`) + `_MemberSinceRow` (`:428-466`) → one `_CashHero`

```dart
JeebNavySurfaceCard(                            // html:22 — r20, pad 20, navy
  radius: Spacing.large,                        // 20
  padding: const EdgeInsetsDirectional.all(Spacing.large),
  shadow: JeebShadows.heroNavy,                 // 0 12 28 @.30 — doc'd "stat hero cards",
                                                //   jeeb_shadows.dart:72; byte-equal to html:22
  rings: const [JeebNavyRing.statTopEnd],       // Ø160 top −50 end −50 — BUILT FOR 19,
                                                //   jeeb_navy_surface_card.dart:37; html:23
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Semantics(
      identifier: 'earnings_total_cash',        // FROZEN — flags verbatim from :249-251
      container: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        JeebSectionLabel(copy.totalCashLabel),  // html:24 — uppercases internally; NEVER
                                                //   .toUpperCase() at the call site
        const SizedBox(height: Spacing.xSmall),
        Text(value,                             // MoneyFormat.format(summary.totalCashEarned, …)
          style: context.jeebText.statHero.copyWith(color: cs.onPrimary),  // 38/w800 — html:25
          semanticsLabel: value),               // keep, as :265
        const SizedBox(height: Spacing.twoXSmall),
        Text(copy.totalCashHint,                // the board's trust line (task 2)
          style: context.jeebText.bodySmall.copyWith(color: semantic.mutedText)),
      ]),
    ),
    const SizedBox(height: Spacing.small),
    Container(height: 1, color: cs.onPrimary.withValues(alpha: 0.12)),   // html:27 — an
    const SizedBox(height: Spacing.small),      // on-navy hairline; NOT outlineVariant
    Row(children: [ /* three _HeroStat columns, SizedBox(width: Spacing.large) between */ ]),
  ]),
)
```

- `semantic` is read ONCE per build as
  `Theme.of(context).extension<JeebSemanticColors>() ?? JeebSemanticColors.light()` — **never the
  `!` bang** (`wrapForTest` runs on `ThemeData.light()`, `sync_app_localizations.dart:42`; the
  kit itself uses this fallback, `jeeb_navy_surface_card.dart:289-291`).
- `_HeroStat` (screen-local, and it is layout — not a kit copy): value
  `context.jeebText.titleProminent.copyWith(color: cs.onPrimary)` (html 17/w800 → 17/w700,
  §2 table), label `context.jeebText.caption.copyWith(color: semantic.mutedText)` (html 11/w600 →
  11.5/w600). Each column is **`Flexible`** (not `Expanded`) so `ar` at 200% shrink-wraps instead
  of clipping, with the label allowed 2 lines.

| slot | value / label | frozen wrapper |
|---|---|---|
| 1 | `'${summary.deliveryCount}'` / `copy.deliveriesLabel` | `Semantics(identifier: 'earnings_deliveries_count', container: true)` |
| 2 | `MoneyFormat.format(summary.netPerOffer, currency: summary.currency)` (+ `semanticsLabel`) / `copy.netPerOfferLabel` | `Semantics(identifier: 'earnings_net_per_offer', container: true, hint: copy.netPerOfferHint)` — the D44 explanation loses its visual slot (`:408-417`) and survives as the a11y hint |
| 3 | `DateFormat.yMMM().format(...)` over `summary.memberSince` (reuse `_formatDate`, `:461-465`) / `copy.memberSinceLabel` | `Semantics(identifier: 'earnings_member_since', container: true)` — rendered **only when `summary.memberSince != null`**, same condition as `:158` |

`JeebNavySurfaceCard` adds no Semantics node (no identifier passed), so the four frozen wrappers
sit flat with zero `explicitChildNodes` risk — see §5.1.

### 4.3 The fee strip — `_FeesPaidCard` (`:283-337`) → `_FeeStrip`

```dart
Semantics(
  identifier: 'earnings_fees_paid',             // FROZEN — flags verbatim from :295-297
  container: true,
  child: JeebOutlinedCard(                      // html:34 — white, 1.5px outline, r16, NO shadow
    // radius/padding: kit defaults (16; 13/16 vs board 14/16 — §2 divergence)
    child: Row(children: [
      Container(                                // the % disc — html:35, Ø38→40
        width: Sizes.threeXLarge, height: Sizes.threeXLarge,
        decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surfaceContainerHigh),
        child: Icon(Icons.percent, size: Sizes.medium, color: cs.primary),  // FILLED — R10;
      ),                                        // a bare '%' Text has no l10n home
      const SizedBox(width: Spacing.small),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(copy.feesPaidLabel,                // "Platform fees paid" — the D41/D44 line; the
          style: context.jeebText.cardTitle.copyWith(color: cs.primary)),   // board's copy is REFUSED
        Text(copy.feesPaidHint,                 // task-2 rewrite, rate interpolated
          style: context.jeebText.bodySmall.copyWith(color: semantic.mutedText)),
      ])),
      const SizedBox(width: Spacing.small),
      Text(feesValue, style: context.jeebText.titleProminent.copyWith(color: cs.primary),
        semanticsLabel: feesValue),             // keep, as :329
    ]),
  ),
)
```

### 4.4 Section header — `:486` → `JeebSectionLabel` + trailing link

```dart
Row(children: [
  Expanded(
    child: Semantics(
      label: copy.breakdownTitle,               // screen reader still hears "Recent deliveries"
      child: JeebSectionLabel(copy.period(state.period.name)),  // → THIS WEEK — html:44; the
    ),                                          // label is the PERIOD, not a static title
  ),
  Semantics(
    identifier: 'earnings_activity_link',       // FROZEN — flags verbatim from :545-547
    button: true,
    container: true,
    child: JeebCtaButton.text(                  // onSurfaceVariant 15.5/w600 — R4's brown
      label: copy.activityLink,                 // "See all" (task 2)
      onTap: () => context.pushNamed('wallet-activity'),   // :553 verbatim; route registered,
    ),                                          //   app_router.dart:1661
  ),
])
```

The board has NO activity link (`html:63` is a bare spacer) — this placement exists solely
because the identifier is frozen and Maestro AC3 taps it. `JeebCtaButton.text`'s 48px height is
the a11y floor; the extra air around the label row is accepted.

Render this header row in **every funded body** (even when `summary.deliveries.isEmpty`) so
`earnings_activity_link` keeps today's presence; below it render either the rows or the
`earnings_breakdown_empty` block (`:477-481` verbatim).

### 4.5 Delivery rows — `_DeliveryRow` (`:494-514`) → grey container + `JeebListRow`

```dart
Semantics(
  identifier: 'earnings_delivery_row_${item.deliveryId}',   // FROZEN — :503-505 verbatim
  container: true,
  child: Container(
    decoration: BoxDecoration(
      color: cs.surfaceContainerHigh,           // html:46 --jeeb-surface-high
      borderRadius: OmdsBorderRadius.medium,    // 16 ← design 14, §4.4 bridge
    ),
    child: JeebListRow(                         // defaults: title 14/w700 primary, subtitle
      title: title,                             //   caption/w500 muted, pad 14/16 — the board's
      subtitle: copy.deliveryRowFee(fee),       //   row anatomy; adds NO Semantics node
      trailing: Text(cash,
        style: context.jeebText.cardTitle.copyWith(color: cs.primary),
        semanticsLabel: cash),                  // keep, as :510
      showChevron: false,
    ),
  ),
)
// TODO(redesign-24): needs gateway tier + item name on the earnings entry — omitted, not faked.
```

- `title`: `copy.deliveryRowTitleDated(item.deliveryId, weekday)` where `weekday =
  DateFormat.E().format(parsed)` from `DateTime.tryParse(item.date)` — same intl pattern as
  `:461-465`. When `item.date` is empty/unparseable, fall back to `copy.deliveryRowTitle(id)`.
- `cash`: `MoneyFormat.format(item.cashCollected, currency: item.currency, signed: true)` — the
  `signed:` param is wiring request §8-A; **if refused, drop the `+` entirely.** Never
  concatenate `'+' + …` — outside the LTR isolate the sign renders on the wrong side in Arabic
  (`money_format.dart:11-18`), and never hand-roll a local isolate in `lib/features`.
- `ListTile` (`:506`) is deleted.

### 4.6 The footer — `_WalletLink` (`:518-536`) + `_ExportButton` (`:559-580`) → `JeebCtaFooter.split`

```dart
JeebCtaFooter.split(                            // html:64 — two flex:1 pills; padding default
  expandLeading: true,                          //   docked = STEB(24,0,24,32); no SafeArea of its
  leading: Semantics(                           //   own (the screen's SafeArea covers it)
    identifier: 'earnings_wallet_link',         // FROZEN — flags verbatim from :524-527
    button: true,
    container: true,
    child: JeebCtaButton.outline(               // 1.5px outline, no shadow — html:65
      label: walletLabel,
      height: 52,                               // board 52/52; kit defaults (50/56) would
      onTap: () => context.pushNamed('wallet'), //   misalign the pair — :532 verbatim
    ),
  ),
  trailing: Semantics(
    identifier: 'earnings_export_cta',          // FROZEN — flags verbatim from :567-570
    button: true,
    container: true,
    child: JeebCtaButton.primary(               // navy pill; paints JeebShadows.ctaNavy itself
      label: copy.exportButton,                 //   (byte-equal to html:66) — NO shadow param
      height: 52,
      isLoading: state.exportMode == EarningsExportMode.exporting,
      onTap: () => context.read<EarningsCubit>().exportPdf(),  // isInteractive already gates
    ),                                          //   the loading tap — drop :574-576's manual if
  ),
)
```

- `walletLabel`: `state.walletBalance == null ? copy.walletLink :
  '${copy.walletLink} · ${MoneyFormat.format(state.walletBalance!.availableBalance,
  currency: state.walletBalance!.currency)}'` — the money token is already LTR-isolated, the `·`
  is bidi-neutral; safe in both directions.
- Rendered **only** in the funded ready state (§Task 4 table) — the empty state stays money-free
  for `data_truth_test:102`, and parity with today (no exits on the empty body) is kept.
- Both `OmdsSettingsRow`s, `OmdsLoadingButton`, `Icons.account_balance_wallet_outlined`,
  `Icons.receipt_long_outlined`, `Icons.event_available_outlined`, `Icons.percent_outlined` are
  deleted from the file.

**Task 5 — test updates** (`test/features/earnings/earnings_dashboard_data_truth_test.dart`,
`test/earnings_cubit_test.dart` — both lane-owned):

- Exactly two line edits in the data-truth file, both because `JeebSectionLabel` uppercases
  internally (EN locale; derive with `JeebSectionLabel.resolveCase` if you prefer):
  - `:103` `find.text('Total cash earned')` → `find.text('TOTAL CASH EARNED')` (still
    `findsNothing` — the empty state must not render the funded hero);
  - `:111` same string → `findsOneWidget`.
  Everything else in that file must pass untouched: `:99` (empty title), `:102` (no `0.00`
  anywhere in the empty tree), `:114` (`'⁦$1,000.00⁩'` — the hero amount stays ONE
  `Text` fed by `MoneyFormat`). **If any other assertion in it fails, your tree is wrong — fix
  the tree, never the finder.**
- Add (additive only):
  - all three `earnings_period_<name>` ids emit;
  - `earnings_member_since` emits iff `summary.memberSince != null` (two pumps);
  - funded state: `earnings_wallet_link` + `earnings_export_cta` visible **without scrolling**;
    empty state: both absent (pins §4.6's two guarantees);
  - cubit: with a fake `WalletRepository`, `walletBalance` lands in state; with a throwing fake,
    no error state is emitted (task 3's silence contract);
  - an `ar` pump of a funded body: renders without overflow, and once §8-A lands, the row amount
    keeps its `+` inside the isolate.

**Task 6 — gates.**
`flutter analyze` (bar: the same 5 pre-existing infos, 0 errors, nothing new — `_BASELINE.md`);
`bash tool/check_design_tokens.sh`;
`flutter test test/features/earnings/ test/earnings_cubit_test.dart test/shell_role_tabs_test.dart
test/features/wallet/wallet_hub_screen_test.dart test/decision_violations_test.dart
test/core/jeeb_commission_test.dart`;
`grep -rn "identifier:" lib/features/earnings/` diffed against §1 — 13 literals, byte-identical.
Report which steps were blocked on the §8-A wiring grant.

---

## 5. Semantics details

### 5.1 `earnings_total_cash` scope
Scope it to the eyebrow+amount+trust-line `Column` inside the hero, NOT the whole card, and let
the three stat wrappers be siblings below the divider. `JeebNavySurfaceCard` adds no node of its
own, so four frozen Maestro-asserted ids coexist with zero `explicitChildNodes` flags to get
wrong. (Wrapping the whole card would force `explicitChildNodes: true` and make all four ids
depend on one flag.)

### 5.2 Labels that survive the visual compression
- stat #2 carries `hint: copy.netPerOfferHint` (the D44 explanation, visible today at `:408-417`);
- every money `Text` keeps its existing `semanticsLabel` (`:265`, `:329`, `:510`);
- the section-header row carries `label: copy.breakdownTitle` (§4.4).

---

## 6. Data — what exists, what does not

Buildable from state with no new endpoint (verified against `earnings_summary.dart` and the mock
body in `earnings_cubit_test.dart:61-81`): `totalCashEarned`, `deliveryCount`, `netPerOffer`
(D44 getter, `:171-174`), `feesPaid`, `kJeebCommissionPercent`, per-row
`cashCollected`/`feePaid`/`date`, `memberSince`, PDF export
(`dio_earnings_repository.dart:34`, DI-bound), wallet balance (task 3).

Gaps — omit, never fake: per-row tier (**G2**) and item name (**G3**) — the wire item is
`{deliveryId, amount:{value,currency}, syncedAt}`; period-scoped rating (**C1**, refused). No
endpoint is invented, no field is invented, no placeholder number is rendered.

---

## 7. RTL & scaling

1. All new insets are `EdgeInsetsDirectional` / `AlignmentDirectional` — the gate misses
   `EdgeInsetsDirectional`, so this is discipline, not a script.
2. The decorative ring mirrors via the kit (`PositionedDirectional` inside
   `JeebNavySurfaceCard`) — you write no positioning code.
3. The `+` sign lives INSIDE the money isolate or not at all (§4.5).
4. The hero divider/stat row: `Flexible` stat columns, 2-line labels — the single 200%-scale
   regression risk this rebuild introduces (today's `_StatsRow` is two cards; three columns are
   tighter).
5. `JeebSectionLabel` casing is locale-gated inside the widget; AR passes through untouched.

---

## 8. Wiring requests — final text for `docs/redesign-2026-08/wiring/19-earnings.md`

### A · cross-feature (core formatting)
file: lib/core/formatting/money_format.dart
need: an opt-in `+` sign rendered inside the existing LTR isolate, for 19's per-delivery cash-in
rows (`+$8.00`, html:49).
exact change:
```dart
static String format(double amount, {String currency = 'USD', bool signed = false}) {
  final value = _group(amount.toStringAsFixed(2));
  final code = currency.trim().toUpperCase();
  final sign = signed && amount > 0 ? '+' : '';
  final token =
      (code.isEmpty || code == 'USD') ? '$sign\$$value' : '$sign$code $value';
  return '$_lri$token$_pdi';
}
```
why: `U+002B` is bidi-class ES; concatenated outside the isolate it resolves with the paragraph
direction and renders `$8.00+` in Arabic. Default `false` keeps every existing call site
byte-identical. If refused, screen 19 drops the `+` (decorative) — it will not hand-roll a local
isolate.

### B · l10n (non-blocking follow-up — the resolver already ships these strings)
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: dedicated keys for the earnings fee-only copy currently served by
`earnings_dashboard_l10n.dart` `_pick` pairs (that file's own protocol: fold in and delete when
the keys land). New/changed values after this lane: `totalCashHint` = "Paid to you directly —
never through Jeeb." / "يُدفع لك مباشرة — لا يمر عبر جيب أبدًا."; `netPerOfferLabel` = "Avg kept /
offer" / "متوسط المحتفظ به / عرض"; `feesPaidHint` = "{percent}% per won offer, from your wallet" /
"{percent}٪ لكل عرض فائز، من محفظتك" (percent = `kJeebCommissionPercent`); `walletLink` = "Wallet"
/ "المحفظة"; `activityLink` = "See all" / "عرض الكل"; `deliveryRowTitleDated` = "Delivery {id} ·
{weekday}" / "توصيلة {id} · {weekday}". Retired: the wallet/activity subtitle strings.
why: keeps the ARB parity gate untouched now, while recording the eventual migration so no
translation is orphaned.

---

## 9. Stop conditions

**Done means:** `earnings_dashboard_screen.dart`, `earnings_dashboard_l10n.dart`,
`earnings_state.dart`, `earnings_cubit.dart` match §3-§4; all 13 identifiers grep byte-identical
(§1); the Task-6 suites are green except the one §8-A-blocked call site (reported); 0 new analyze
issues; token script clean; the PR notes call out: the pushed-`/earnings` back-affordance change,
the §2 divergence table, and the C1/C2 refusals.

**Do NOT touch:** `lib/features/shell/*` (incl. `earnings_tab.dart` — task 3 makes it
unnecessary) · `lib/core/router/app_router.dart` · `lib/core/di/injection_container.dart` ·
`lib/core/theme/*` · `lib/core/widgets/jeeb/*` (frozen — consume) · `lib/core/formatting/*`
(request §8-A, don't edit) · `lib/l10n/*` · `pubspec.yaml` · `test/support/*` ·
`lib/devtool/*` (batch_03 mounts the real screen and compiles untouched) ·
`.maestro/*` · `test/decision_violations_test.dart` · `test/core/jeeb_commission_test.dart` ·
the wallet feature (`wallet_repository.dart` is imported, never edited) · the four `_BASELINE.md`
failures. Do not add a rating, a tier emoji, an item name, a fabricated wallet balance, or any
"Commission"/gross/net-payout framing anywhere.
