# W5 apply report — `wallet-charge-info` (+ `customer-wallet` stub)

Lane: `lib/features/wallet/` leftovers · Branch `feat/redesign-24-migration` · 2026-08-03
Reference render: `screens/23-wallet.png` / `.html` (no render exists for either file).
Siblings matched: `wallet_hub_screen.dart`, `wallet_activity_list_screen.dart`,
`transaction_detail_screen.dart`, `widgets/wallet_activity_row.dart` — all already redesigned.

## Files changed

| File | Status |
|---|---|
| `lib/features/wallet/presentation/wallet_charge_info_screen.dart` | re-skinned |
| `lib/features/wallet/presentation/customer_wallet_stub_screen.dart` | re-skinned |

No new files, no new l10n keys, no pubspec edit, no shared-file edit, no wiring request.

## What the neighbour establishes (measured from `23-wallet.html`)

- In-body header: Ø40 `surfaceContainerHigh` circle + navy 20/w700 title, gutter 24, top 14.
- Cards: 1.5px `--jeeb-brown-outline`, r16, rows `14/16` with gap 12 — **outline, no shadow**.
- Note panels: r16, `13/16`, gap 12 (tinted fill or 1.5px outline).
- Primary CTA: h56 navy pill, `rgba(11,19,81,.28) 0 10 24`.
- Block gaps 12–18; the bottom third of the screen is plain white (R1).
- Orange appears exactly twice: the 30% decorative ring on the navy hero and the fee-explainer
  text link. Nowhere else.

## `wallet_charge_info_screen.dart`

Static, no-payment instructional screen (D92/D93). **Nothing was added that could read as payment**
— no card field, no amount field, no store list; the three `assertNotVisible` ids in
`.maestro/flows/jm-054-wallet-charge-info.yaml` remain absent by construction.

| Before | After |
|---|---|
| `OMDSAppBar` (Material, centred) | in-body `JeebTopBar` (`identifier: 'charge_info_back'`), 24px gutter — the bar all three redesigned wallet siblings use |
| 3 loose numbered rows separated by `SizedBox(16)` | one `JeebOutlinedCard.grouped`; the kit's inset 1px dividers carry the sequence (23's grouped-exits shape, `transaction_detail_screen.dart`'s field-rows shape) |
| step padding ad hoc | `JeebListRow.defaultPadding` (14/16) + gap 12 — one rhythm with every other grouped row in the redesign |
| `theme.textTheme.labelLarge` / `bodyLarge` | `context.jeebText.bodySmall` (w800, badge digit) / `context.jeebText.body` |
| 2 hand-rolled icon+text rows | `JeebInfoNote.muted` ×2, `Icons.sync` / `Icons.percent` (filled glyphs, R10 — was `*_outlined`) |
| CTA `OmdsPrimaryButton` at the end of the `ListView` | `JeebCtaFooter.single` + `JeebCtaButton` docked over real white emptiness (R1) |
| two duplicated `canPop ? pop : goNamed('wallet')` closures | one `_back(context)` used by both the bar and the CTA — identical behaviour, one source |

Kept exactly: the numbered-badge idea (navy disc, `Sizes.xLarge`), all copy, block order, the
`goNamed('wallet')` vs `pop()` contract, and every identifier.

## `customer_wallet_stub_screen.dart`

Restyled **as a stub**. No balance, no top-up, no payment method, no invented data — it still says
the same four sentences (cash on delivery, D11).

| Before | After |
|---|---|
| `OMDSAppBar` | in-body `JeebTopBar` (`identifier: 'customer_wallet_stub_back'`) |
| centred Ø64 raw `payments_outlined` glyph | start-aligned Ø56 tonal disc + Ø24 navy `Icons.payments` — the house state-mark idiom (`kyc_rejected_screen.dart`'s `_RejectionMark`); the board never draws a loose glyph and never centres a band |
| centred `headlineSmall` + `bodyMedium` | start-aligned `context.jeebText.h1` navy + `context.jeebText.body` in `onSurfaceVariant` (brown — periwinkle is banned as body text on white) |
| hand-rolled `Container` + `surfaceContainerHighest` + `OmdsBorderRadius.uiMedium` panel | `JeebInfoNote.muted` stacked form (title + text), `Icons.local_atm` |
| CTA at the end of the `ListView` | `JeebCtaFooter.single` + `JeebCtaButton`, docked (R1) |

## Identifier contract

Preserved byte-identically, each still inside its own original
`Semantics(identifier:, [button: true,] container: true)` wrapper (the `client_unreachable_screen`
/ `kyc_rejected_screen` re-home pattern — the kit widget is the child, it does not own the id):

`charge_info_root` · `charge_info_store_step` · `charge_info_identity_step` ·
`charge_info_pay_cash_step` · `charge_info_auto_update_note` · `charge_info_fee_note` ·
`charge_info_back_cta` · `customer_wallet_stub` · `customer_wallet_stub_done`

Two NEW ids, both on the newly-identified top-bar circles, per the `<screen>_<element>` rule:
`charge_info_back`, `customer_wallet_stub_back`. `charge_info_back` cannot shadow
`charge_info_back_cta` in a Maestro selector (the CTA's id is the longer string, and no flow taps
the bare `_back`); this is the same `kyc_rejected_back` / `kyc_rejected_back_cta` pair that already
shipped in this migration.

## Gates

| Gate | Result |
|---|---|
| `flutter analyze --no-pub lib/features/wallet` | **No issues found** |
| `flutter analyze --no-pub` (repo) | 8 issues, **0 errors** — all pre-existing `containsSemantics` infos in test files, none in this lane |
| `flutter test --no-pub` (full) | **4664 pass / 61 skip / 1 fail** — baseline exactly; the one failure is the pre-existing `gesture_log_test` local-SDK skew |
| `flutter test test/features/wallet test/semantics_identifier_surfacing_test.dart` | 56 pass |
| `test/core/router/w2_routes_resolve_test.dart` | 7 pass (`/wallet/charge-info` still resolves) |
| `bash tool/check_design_tokens.sh` | 1 violation, pre-existing and **not in this lane** (`location/…/client_location_screen.dart:1023` raw `TextField`) |
| throwaway pump check (EN + AR, then deleted) | all 11 ids found, no exceptions; at 390×844 all five JM-054 AC1 content ids **plus** the CTA are on screen without scrolling |

## Deliberate refusals

- **No navy hero card.** 23's signature element states a number; neither screen has one, and
  inventing a "$0.00" or a fake balance would be a data-honesty violation.
- **No orange anywhere.** The board's orange marks what is live or expiring; nothing on a static
  instruction sheet or a cash-only stub decays.
- **No section labels / no trust line.** Both would need new ARB keys (l10n has no gen-l10n here),
  and the wave's instruction is restraint, not new copy.
- **No payment affordance of any kind** on charge-info, and no promotion of the stub into a wallet.
