/// The Jeeb platform commission rate — ONE copy, app-wide.
///
/// ## Authority
///
/// The rate is the GATEWAY's, not the app's. `CommissionCalculator.FlatRate`
/// (`jeeb-gateway/src/JeebGateway/Financials/CommissionCalculator.cs:54`,
/// `public const decimal FlatRate = 0.10m;`) is what settlement actually pays,
/// per owner ruling Q-001 (2026-07-07: flat 10% for v1). The constant below is
/// a MIRROR of that value, and mirrors go stale — see "the wire path" at the
/// bottom for what replacing it would take.
///
/// ## Why this file exists
///
/// The number was written out longhand in three places that shared nothing:
///
///   * `features/earnings/domain/earnings_summary.dart` — `kJeebFeeRate`, the
///     only one that was ever named
///   * `features/offers/presentation/offer_submission_screen.dart` — inline
///     `_price! * 0.10`, the wallet reserve shown to a Jeeber before they bid
///   * `features/wallet/data/stub_wallet_transaction_repository.dart` —
///     `feeRate: 0.1`, and this one RENDERS: it is still the DI-bound wallet
///     repository, so its literal is what a Jeeber reads on a fee row
///
/// Three unrelated edits to change one business rule, in three features owned
/// at three different times. The next rate change makes the app lie to Jeebers
/// about their own take-home in whichever place gets missed.
///
/// ## The precedent this is guarding against, which already happened
///
/// A FIFTH copy existed on the gateway, and it drifted: `GET /tiers` advertised
/// per-tier commissions of 0.25 / 0.20 / 0.15 for weeks while settlement paid a
/// flat 10%, because the tier catalogue and `CommissionCalculator` were never
/// connected. It is fixed now — `DeliveryServiceClient.cs:74` overwrites the
/// upstream's rate with `CommissionCalculator.FlatRate`, and
/// `AdminTiersController.cs:320-326` rejects any write that is not exactly
/// 0.10. No user was ever harmed, and the reason is worth stating plainly: the
/// app never parsed `commissionRate` at all, so the wrong number could not
/// reach a screen. That is luck, not design, and it is exactly the shape this
/// file exists to stop the client from recreating.
///
/// ## The wire path, if this should stop being a constant
///
/// It CAN come from the server today. `GET /v1/tiers`
/// (`jeeb-gateway/src/JeebGateway/Controllers/V1/JeebTiersController.cs:55`) is
/// `[AllowAnonymous]` + `[PublicEndpoint]` and answers with
/// `items[].commissionRate` — `DeliveryTierDto.CommissionRate`
/// (`src/JeebGateway/Tiers/TiersDtos.cs:10`), a `double`, camelCase on the wire
/// (no `PropertyNamingPolicy` override exists in the gateway's MVC pipeline, so
/// ASP.NET Core's `JsonSerializerDefaults.Web` applies). Mobile already CALLS
/// that catalogue — `features/tier_selection/data/tier_repository.dart:57`,
/// currently against the legacy `[Obsolete]` `/tiers` alias — and its parser
/// (`_parseTier`, `:85-102`) simply drops the field; `Tier` has no rate member.
///
/// Deliberately NOT wired here, because a rate fetched over the network raises
/// questions this change is not the place to answer and must not guess at:
/// what the offer composer shows while the fetch is in flight, what it shows
/// when the fetch fails (a Jeeber must never be asked to bid against an unknown
/// fee), whether a cached rate may be trusted across sessions, and what
/// happens when a rate change lands between a Jeeber reading the reserve and
/// the gateway settling it. Those need an owner decision, not a default.
///
/// Until then: ONE constant, this one. If it changes, it changes here, and the
/// guard test in `test/core/jeeb_commission_test.dart` fails any second copy
/// that reappears in `lib/`.
library;

/// Flat platform commission, as a fraction of the delivery price.
///
/// Mirrors `CommissionCalculator.FlatRate = 0.10m` on the gateway. Every fee,
/// reserve and take-home figure the app renders derives from THIS.
const double kJeebCommissionRate = 0.10;

/// The same rate as a whole-number percentage, for display copy.
///
/// Exists so a screen never writes "10%" as a bare string beside a number
/// computed from [kJeebCommissionRate] — the two would then be free to disagree,
/// which is the same defect one layer down.
const int kJeebCommissionPercent = 10;
