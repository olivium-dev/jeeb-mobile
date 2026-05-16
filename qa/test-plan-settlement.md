# Test Plan — Cash Settlement at Handover

Maps to: **FR-10.1**, **US-9.1**
Backend: `delivery-service` (settlement totals) + `wallet-service` (commission ledger)
Owner: Mobile QA + Finance QA
Status: Draft v1 — JEEB-110

> Per the **olivium-tech-stack-rules** policy, no payment is processed
> here — MVP cash collection is **out-of-band** between Client and
> Jeeber. The mobile app only **displays the breakdown** and records the
> commission entry server-side. When Jeeb adds card payment, it routes
> through `unified_payment_gateway` (Elixir) — covered by a separate plan.

## 1. Scope

The Jeeber-side delivery summary screen that shows what the Client owes
in cash, and the same breakdown on the Client's receipt screen.

In scope:
- Calculation correctness (goods + delivery fee, commission deducted from earnings)
- Currency formatting per locale
- Rounding rules (commission is the only line that can have fractions)
- Receipt generation post-handover
- Wallet-service ledger entry (commission)
- Refund / cancel paths that affect the final amount

Out of scope:
- Card / wallet payments (post-MVP, `unified_payment_gateway`)
- Tax invoicing (post-MVP)

## 2. Calculation under test

For a delivery with:

```
goods_cost    = G    (paid by Jeeber up-front, reimbursed by Client)
delivery_fee  = D    (negotiated in accepted offer)
commission    = round_half_even(D * 0.15, 2)
```

Two views:

**Jeeber summary** (US-9.1):

```
Client owes you:        G + D
Your earnings:          D − commission
Commission (15% of fee): commission   (deducted from your earnings)
```

**Client receipt** (FR-10.1):

```
Items / goods reimbursement:   G
Delivery fee:                  D
                               ────
Total paid in cash:            G + D
                               ────
(Platform commission: commission, deducted from the Jeeber's earnings)
```

Invariants:

1. The number the Client hands over in cash equals `G + D` exactly —
   commission is **never** added to the Client's total.
2. Commission only debits the Jeeber's wallet ledger, not the Client's.
3. Display currency is fixed at MVP (single currency); rounding uses
   banker's rounding to 2 decimal places.

## 3. Functional tests

### 3.1 Whole-number breakdowns

| # | G    | D    | Commission | Client cash | Jeeber earnings |
|---|------|------|------------|-------------|-----------------|
| 1 | 15.00| 5.00 | 0.75       | 20.00       | 4.25            |
| 2 | 0.00 | 10.00| 1.50       | 10.00       | 8.50            |
| 3 | 100.00| 20.00| 3.00      | 120.00      | 17.00           |

Verify on both Jeeber summary and Client receipt screens; verify the
wallet-service ledger entry equals commission.

### 3.2 Rounding

Commission = `round_half_even(D * 0.15, 2)`. The Jeeber earnings line
must equal `D − commission` exactly so the displayed numbers add up.

| # | D     | Raw 15%  | Rounded (banker's) | Earnings |
|---|-------|----------|---------------------|----------|
| 1 | 3.33  | 0.4995   | 0.50                | 2.83     |
| 2 | 3.34  | 0.5010   | 0.50                | 2.84     |
| 3 | 3.50  | 0.5250   | 0.52                | 2.98     |
| 4 | 0.10  | 0.0150   | 0.02                | 0.08     |
| 5 | 0.01  | 0.0015   | 0.00                | 0.01     |

Notes:

- A negative or zero earnings result is rejected by the offer service
  before a delivery exists, so test row D=0 should never reach the
  settlement screen — assert the screen handles it defensively (shows
  "—" not "$0.00") via fixture `qa-delivery-settlement-zero`.

### 3.3 Locale and currency

| # | Locale | Expected formatting (D=5)            |
|---|--------|--------------------------------------|
| 1 | en-US  | `$5.00`, decimal `.`                  |
| 2 | en-GB  | `£5.00`                               |
| 3 | ar-SA  | `٥٫٠٠ ر.س.` (Arabic-Indic digits, comma decimal, RTL layout) |
| 4 | fr-FR  | `5,00 €`, space thousands separator   |

The currency is sourced from the delivery payload, not the device
locale — but digit shaping and decimal separator follow device locale.
Verify mismatch case: device `ar-SA`, currency `USD` → `٥٫٠٠ US$`.

### 3.4 Receipt screen

| # | Step                                                                  | Expected                                                                                            |
|---|-----------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| 1 | Status flips to `delivered`                                           | Both apps show "Receipt" CTA in the timeline                                                        |
| 2 | Tap "Receipt" on Client side                                          | Modal with breakdown per §2; "Share" button → uses platform share sheet                             |
| 3 | Tap "Share" → "Save as PDF"                                           | PDF generated locally; opens in system viewer; layout matches receipt-template.png golden            |
| 4 | Open receipt offline                                                   | Renders from cache; "Synced just now" → "Synced 2 min ago" → "Synced when you were online"          |
| 5 | Receipt accessibility (VoiceOver)                                      | Reads "goods reimbursement fifteen dollars, delivery fee five dollars, total twenty dollars" — not raw numbers |

### 3.5 Cancellation and partial refunds (mobile display only)

Server is authoritative; mobile renders whatever the delivery payload
says. These are pure display tests.

| # | Server state                                                         | Expected Jeeber summary                                              |
|---|----------------------------------------------------------------------|----------------------------------------------------------------------|
| 1 | Cancelled before pickup                                              | "No payment due — order cancelled"; commission line absent           |
| 2 | Cancelled after pickup, with partial cancellation fee F              | "Client owes you F" (no commission since no delivery fee earned)     |
| 3 | Disputed — settlement on hold                                        | Banner "Settlement on hold pending dispute" over the breakdown       |

## 4. Wallet-service ledger checks

After every successful handover:

| # | Check                                                        | Expected                                                                            |
|---|--------------------------------------------------------------|-------------------------------------------------------------------------------------|
| 1 | `GET /v1/wallets/{jeeber_id}/entries`                        | One commission debit entry with `delivery_id`, `amount=commission`, `currency=USD`  |
| 2 | Entry idempotency: re-trigger settlement on the same delivery | No duplicate entry; idempotency key = `delivery_id`                                 |
| 3 | Entry on a cancelled-before-pickup delivery                  | No entry exists                                                                     |
| 4 | Entry on a refunded delivery                                  | Original commission debit + reversal credit, both visible in ledger                 |

These are validated by the `wallet-service` API smoke pack (curl), not
by the mobile app, but the mobile receipt screen MUST agree with the
ledger — covered as a contract test in §6.

## 5. Test inventory

### 5.1 Unit (`test/features/settlement/`)

- `commission_calculator_test.dart` — banker's rounding, every row of §3.2
- `currency_formatter_test.dart` — every row of §3.3 + RTL bidi
- `receipt_serializer_test.dart` — round-trip, accessibility hint generation

### 5.2 Widget (`test/features/settlement/presentation/`)

- `jeeber_summary_widget_test.dart` — happy path + each cancellation row of §3.5
- `client_receipt_widget_test.dart` — golden against `qa/goldens/receipt_*.png`

### 5.3 Integration (`integration_test/settlement/`)

- `flow_handover_to_receipt_test.dart` — Patrol drives OTP success → receipt; asserts numbers match the seeded delivery payload

### 5.4 E2E + contract

- `qa/maestro/settlement/flow_receipt_share.yaml` — single device, share sheet exercised
- `qa/contract/settlement_receipt.pact.json` — Pact contract between mobile and `delivery-service` for the breakdown payload (per `pact-consumer-driven-contract`)

## 6. Cross-service contract

The mobile receipt must show numbers identical to those returned by
`delivery-service` AND those persisted by `wallet-service`. Run as a
nightly job:

```bash
DELIVERY=$(curl -sf "$DELIVERY_API/v1/deliveries/$DID" -H "Authorization: Bearer $T")
LEDGER=$(curl -sf "$WALLET_API/v1/wallets/$JID/entries?delivery_id=$DID" -H "Authorization: Bearer $T")

jq -e --argjson l "$LEDGER" '
  .commission == ($l[0].amount | tonumber)
  and .currency == $l[0].currency
' <<< "$DELIVERY"
```

Failure here means delivery-service and wallet-service disagree —
mobile QA files Sev-1 against whichever service is wrong, NOT a mobile
defect.

## 7. Test data

Seeded in `jeeb-infrastructure/seeds/qa-settlement.sql`:

| Fixture                          | G     | D     | Notes                              |
|----------------------------------|-------|-------|------------------------------------|
| `qa-delivery-settle-whole`       | 15.00 | 5.00  | §3.1 row 1                         |
| `qa-delivery-settle-fraction`    | 7.42  | 3.33  | §3.2 row 1 — fractional commission |
| `qa-delivery-settle-zero-fee`    | 10.00 | 0.10  | §3.2 row 4 — tiny commission       |
| `qa-delivery-settle-cancelled`   | 12.00 | 0.00  | §3.5 row 1                         |
| `qa-delivery-settle-disputed`    | 20.00 | 6.00  | §3.5 row 3 — dispute on hold       |
| `qa-delivery-settle-arabic`      | 10.00 | 4.00  | Locale ar-SA, currency SAR         |

## 8. Acceptance gate

A build is allowed to ship to staging only when:

- Every row in §3.1 and §3.2 passes on Tier 1 devices.
- Currency formatting goldens (§3.3) match for all four locales.
- Contract test §6 has been green for ≥ 7 nightly runs.
- No display drift between Jeeber summary and Client receipt for
  any seeded fixture.

## 9. Risks and assumptions

- **Assumption**: Commission rate is fixed at 15%. If product changes
  this to a tiered rate, every numeric row in §3.1 / §3.2 must be
  regenerated and the calculator unit test rewritten.
- **Assumption**: Single currency at MVP. The locale matrix in §3.3
  exists to catch *future* multi-currency regressions early.
- **Risk**: PDF receipt generation uses `printing` package; the
  `pdf` package's font fallback for Arabic numerals has shipped a
  regression before (v3.10.7). Pin the version and golden-test the
  PDF render.
- **Risk**: Banker's rounding versus arithmetic rounding will produce
  visibly different commissions on D=3.50 (0.52 vs 0.53). Confirm
  with finance which the org has standardised on; this plan assumes
  banker's rounding because that's what most Olivium services use.
