# 23 · Wallet — implementation report

Branch `feat/redesign-24-migration`. Instruction set:
`docs/redesign-2026-08/per-screen-revised/23-wallet.md` (followed in order; §A's corrections
applied — `text:` not `body:`, `onLeadingPressed:` not `onBack:`, `rings:` not `ring:`,
`JeebCtaFooter.inline` not a non-existent `JeebCtaPlacement`, defensive `JeebSemanticColors` read).

Status: **applied**. Nothing is blocked — the lane ships all copy through
`wallet_hub_l10n.dart`'s `_pick` maps, so `lib/features/wallet/` analyzes and tests green with no
integrator dependency. The single wiring request (`wiring/23-wallet.md`) is a non-blocking l10n
fold-in.

---

## Kit consumed (no private copies)

| Kit widget | Where |
|---|---|
| `JeebTopBar` | in-body header, `identifier: 'wallet_back'`, `leadingTooltip`, the verbatim `canPop ? pop : go('/')` callback. Renders in **all three** states now that `OMDSAppBar` is gone. |
| `JeebNavySurfaceCard` | the balance hero — `radius: Spacing.large` (20), `padding: all(20)`, `shadow: JeebShadows.heroNavy`, `rings: [JeebNavyRing.statBottomEnd]` (Ø170, bottom/end −50) |
| `JeebSectionLabel` | `AVAILABLE TO BID` (natural casing in; the kit owns the locale-gated transform) |
| `JeebInfoNote.muted` | KYC-pending banner (`wallet_kyc_pending_banner`) |
| `JeebInfoNote` (tone from state) | affordability note — `.success` for `enough`, `.warning` for the other three |
| `JeebInfoNote.outlined` | reserve row with the money in `trailing:` — the kit's own documented "23" form |
| `JeebCtaFooter.single` | the CTA block, `below:` carrying the orange fee link at the default `spacing: 10` |
| `JeebCtaButton` / `JeebCtaButton.accentText` | navy `+ Top up wallet` pill (h56, `leadingIcon: Icons.add`) and the one sanctioned orange text affordance |
| `JeebOutlinedCard.grouped` | the two-row exits card (r16, 1.5px `outline`, 1px divider inset 16 — all kit defaults) |
| `JeebListRow` ×2 | Earnings / All activity, filled `Icons.show_chart` / `Icons.article`, kit-owned mirrored chevron |

Screen-local widgets (all sanctioned, none a kit duplicate):
`_BalanceHero` (composition), `_GiftPill` (kit doc §5 explicitly leaves 23's on-navy starter pill
screen-local — the kit ships no unselected chip that reads on navy), `_CashDisclaimer` (the
docked trust line), plus the untouched `_HowFeesSheet` / `_FeeBullet`.

## Files changed

- `lib/features/wallet/presentation/wallet_hub_screen.dart` — full restyle.
- `lib/features/wallet/presentation/wallet_hub_l10n.dart` — copy only (lane-owned resolver).
- `test/features/wallet/wallet_hub_screen_test.dart` — 3 mechanical copy edits, 4 additive tests,
  0 removed, 0 weakened.

Files created: none beyond `docs/redesign-2026-08/wiring/23-wallet.md` and this report.

## Identifiers

All 11 frozen ids survive byte-identically:
`wallet_hub_root` · `wallet_kyc_pending_banner` · `wallet_available_balance` ·
`wallet_gift_badge` · `wallet_affordability_card` · `wallet_reserved_now` · `wallet_topup_cta` ·
`wallet_how_fees_work` · `wallet_earnings_row` · `wallet_see_all_activity` ·
`wallet_how_fees_explainer`.

Two added, per §B: `wallet_back` (the kit's `<screen>_back` contract on the Ø40 leading circle —
today's `OMDSAppBar` back had no id, so this is pure addition) and `wallet_cash_disclaimer`
(screen-owned, non-interactive, no `button:`).

`wallet_available_balance` stayed on the content **Column inside** the navy card — wrapping the
card would have pulled the decorative ring into the node — and kept both `container: true` and
`explicitChildNodes: true`, without which the nested `wallet_gift_badge` id is swallowed.

Block order unchanged (Maestro `jm-053-wallet-hub.yaml` AC1 asserts five ids with no
`scrollUntilVisible`): [KYC banner] → hero → affordability → reserve → CTA → grouped card →
(fill) trust line.

## Behaviour preserved verbatim

- `context.canPop() ? context.pop() : context.go('/')` with its comment — pairs with
  `backFallbacks['wallet'] = '/'`.
- `_onTopUp` / `_isOffline` including the "no OfflineCubit ⇒ treat as online" fallback (D35).
- Both constructor seams (`repository`, `kycStatusGate`) and the `WalletHubScreen` class name /
  file path (`w2_routes_resolve_test`, `no_raw_semantic_colors_test` both key on them).
- All four `WalletAffordability` branches (D43 / Maestro AC6 / three widget tests).
- `_HowFeesSheet` structurally byte-identical; only its line-1 copy changed, and that change lives
  in the l10n resolver.

## Copy

Every `10%` now derives from `kJeebCommissionPercent` — `affordabilityBody(enough)`, `howFeesWork`
and `feesExplainerLine1`. `feesExplainerLine1` also says "platform fee", never "Commission"
(D41/D44). Every amount goes through `MoneyFormat.format`, which fixes a live RTL defect: the old
`'${_fmt(v)} $currency'` had no LTR isolate, so `$6.40` reordered inside Arabic paragraphs.

Deliberately NOT rendered (honest gaps, both recorded in `wiring/23-wallet.md`):

- the board's `1 live offer ·` half of the reserve subtitle — `WalletBalance` has the reserved
  *amount* only; there is no count on the wire. Marked `TODO(redesign-24)` at the call site.
- the word `included` on the starter-credit pill — the contract does not define whether
  `giftCredit` composes `availableBalance`.

## Token-gate

`bash tool/check_design_tokens.sh` → **6** violations, down from 8. Both of this file's are gone
(`RefreshIndicator` → `OmdsPullToRefresh`; `BorderRadius.circular(12)` → deleted with `_Banner`).
The remaining six belong to other lanes (settlement ×3, client-location, wallet-activity-list,
reviews-list) and were left alone.

`no_raw_semantic_colors_test` still passes for this file: no `Color(0x`, no `Colors.<palette>`,
no `.tertiary*`. `JeebSemanticColors` is read defensively
(`extension<JeebSemanticColors>() ?? JeebSemanticColors.light()`) in all three places that need it,
because `test/support/sync_app_localizations.dart` themes with `ThemeData.light()` and a bang
would crash every wallet test.

## Gates

- `dart analyze lib/features/wallet test/features/wallet` → **No issues found.**
- `flutter test test/features/wallet/wallet_hub_screen_test.dart` → **13/13 pass** (9 pre-existing
  + 4 new).
- `flutter test test/core/jeeb_commission_test.dart` → all pass.
- `flutter test test/core/theme/no_raw_semantic_colors_test.dart` → this file's case passes.
- `test/core/router/w2_routes_resolve_test.dart` and `test/decision_violations_test.dart` **fail to
  compile — NOT from this lane.** Both pull in `lib/features/rating/presentation/mutual_rating_screen.dart`
  (8 undefined `AppLocalizations` members) and `lib/features/kyc/presentation/kyc_wizard_screen.dart`
  (`_CaptureProgress` undefined) — concurrent lanes whose l10n/widget wiring has not landed. Nothing
  in the failure output references `wallet`.
- Repo-wide `flutter analyze` and the full suite were deliberately NOT run: other agents are
  editing concurrently, per the task brief.

## Divergences from the board (stated, not accidental)

| board | shipped | why |
|---|---|---|
| gift pill fill 20% / stroke 40% orange | `semantic.accentTint` (12%) / `accentRing` (30%) | sanctioned tokens beat two one-off alphas |
| `USD` suffix 14/w700 | `bodySmall` 12/w700 | no 14/w700 slot on the ramp; R3 ranks by weight |
| reserve value 16/w800 | `cardTitle` 15.5/w800 | nearest-token band |
| fee link 13/w700 | `accentText` 13.5/w700 | kit-owned, stated in kit doc §2.2 |
| trust line w500 | `caption` 11.5/w600 | nearest-token band |
| grouped card top gap 18 | `Spacing.medium` (16) | no 18 token at feature level |
| trust-line bottom inset 30 | `Spacing.twoXLarge` (32) | no 30 token |
| hero label→amount gap 6 | `Spacing.twoXSmall` (4) | no 6 token; instruction-set value |
