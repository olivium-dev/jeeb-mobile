import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../wallet/domain/wallet_repository.dart';

/// onboarding-funding (JM-041). Starter-credit explainer shown after KYC is
/// submitted: a fixed, non-refundable starter credit usable post-KYC (D42) +
/// the reserve-10%-per-offer rule (D1). NO in-app payment (D92/D93) — top-up is
/// done at a store via wallet-charge-info. Top-up is allowed pre-approval
/// (D38/D39), so Continue lands on kyc-pending-status.
///
/// DATA (CTO-D2 wallet model): the explainer is enriched with the LIVE wallet
/// snapshot from the real backend endpoint (W1m `GET /v1/jeeb/wallet`, surfaced
/// through [WalletRepository] — `giftCredit` is the D42 starter credit,
/// `reservedNow` the sum of live 10% reserves, D1). It depends only on the
/// wallet `domain/` contract (no cross-feature `application/` import) and reads
/// `sl<WalletRepository>()` — until W1m is live the DI default is the
/// INTEGRATOR-STUB, so the explainer still renders real numbers from a
/// deterministic snapshot. The static explainer copy is the AC and is ALWAYS
/// visible — it is NEVER gated on the network call, so `funding_explainer` +
/// both CTAs survive a slow/failed wallet fetch (fail-safe,
/// 40_GUARDRAILS_ARCH §3). The live amounts only *enrich* the copy when loaded.
///
/// Edges OWNED here (21_NAV_PLAN §C JM-041):
///   onboarding-funding → wallet-charge-info  (`funding_topup_cta`)
///   onboarding-funding → kyc-pending-status  (`funding_continue_cta`)
///
/// Redesign-2026-08 (Jeeb design system, no board render for this screen — the
/// language is taken from its journey neighbour, 23-wallet): a re-skin, not a
/// product change. Same data, same route, same two CTAs in the same order, all
/// four identifiers unmoved. Three bands over a deliberately empty lower third
/// (R1): navy starter-credit hero (the same `heroNavy` + bottom-END accent ring
/// the wallet balance hero wears, so the two money surfaces read as one
/// family) → the reserve rule as a kit info note carrying the live reserved
/// amount → the docked CTA pair. Prepaid, fee-only: nothing here implies an
/// in-app card payment (D92/D93).
class OnboardingFundingScreen extends StatefulWidget {
  const OnboardingFundingScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final WalletRepository? repository;

  @override
  State<OnboardingFundingScreen> createState() =>
      _OnboardingFundingScreenState();
}

class _OnboardingFundingScreenState extends State<OnboardingFundingScreen> {
  /// The live wallet snapshot, or `null` while loading / on failure. The
  /// explainer never blocks on it (fail-safe): a `null` snapshot simply hides
  /// the enrichment amounts and shows the static copy alone.
  WalletBalance? _balance;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final repo = widget.repository ?? sl<WalletRepository>();
    try {
      final balance = await repo.fetchBalance();
      if (mounted) setState(() => _balance = balance);
    } on WalletRepositoryException {
      // Fail-safe: the explainer is static copy; a failed wallet fetch must not
      // hide it. Leave `_balance` null so only the enrichment is omitted.
    } catch (_) {
      // Same — any unexpected error must not break the explainer.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final balance = _balance;
    return Scaffold(
      // The board's header is an in-body row, not a Material app bar (§5 #1).
      body: SafeArea(
        child: Column(
          children: [
            JeebTopBar(
              identifier: 'funding_back',
              title: l10n.fundingTitle,
              // Normally pushed after KYC submission, but also reachable via
              // deep link with an empty Navigator stack. Pop when we can
              // (pushed entry), else return to the shell — never pop the last
              // page (which would leave an empty Navigator → black surface).
              onLeadingPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
            // `funding_explainer` is the screen ROOT (65_W2_TEST_PLAN §2
            // JM-041) and is ALWAYS present regardless of the wallet load state
            // — the explainer is the AC, not the live numbers.
            Expanded(
              child: Semantics(
                identifier: 'funding_explainer',
                container: true,
                explicitChildNodes: true,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      // 24px gutters; the footer owns the bottom inset, so this
                      // sliver ends flush.
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        Spacing.xLarge,
                        Spacing.medium,
                        Spacing.xLarge,
                        0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Starter credit (D42) ────────────────────────
                          _StarterCreditHero(
                            body: l10n.fundingStarterCreditBody,
                            // Live enrichment: the actual D42 gift-credit
                            // amount, shown only once the wallet snapshot
                            // loads and it is non-zero.
                            amount: balance != null && balance.giftCredit > 0
                                ? MoneyFormat.format(
                                    balance.giftCredit,
                                    currency: balance.currency,
                                  )
                                : null,
                          ),
                          const SizedBox(height: Spacing.small),
                          // ── Reserve-10%-per-offer (D1) ──────────────────
                          // `accent` is the tone whose INK is navy (the orange
                          // is only ever its optional link, which this note has
                          // none of) — the rule is body copy, and periwinkle
                          // body text is banned on light surfaces.
                          JeebInfoNote.accent(
                            icon: Icons.lock,
                            text: l10n.fundingReserveBody,
                            // Live enrichment: the amount currently reserved
                            // across live offers (D1), shown only when non-zero.
                            trailing: balance != null && balance.reservedNow > 0
                                ? Semantics(
                                    identifier: 'funding_reserved_now_amount',
                                    child: Text(
                                      MoneyFormat.format(
                                        balance.reservedNow,
                                        currency: balance.currency,
                                      ),
                                      style: context.jeebText.cardTitle
                                          .copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: scheme.onSurface,
                                          ),
                                    ),
                                  )
                                : null,
                          ),
                        ]),
                      ),
                    ),
                    // ── The empty lower third is the design (R1): fill the
                    // viewport, dock the CTAs at its foot, and scroll only once
                    // the content genuinely overflows (200% text scale, long AR
                    // copy).
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: AlignmentDirectional.bottomCenter,
                        // Order is the flow's, not the hierarchy's: top-up
                        // stays the first affordance (as it shipped), Continue
                        // stays the navy pill the thumb lands on last.
                        child: JeebCtaFooter.single(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            Spacing.xLarge,
                            Spacing.xLarge,
                            Spacing.xLarge,
                            Spacing.twoXLarge,
                          ),
                          // ── Continue → kyc-pending-status (top-up allowed
                          // pre-approval, D38/D39).
                          below: Semantics(
                            identifier: 'funding_continue_cta',
                            button: true,
                            container: true,
                            child: JeebCtaButton.primary(
                              label: l10n.fundingContinueCta,
                              // The KYC wizard hosts the status view at
                              // `/profile/kyc?step=status` (registered name
                              // `kyc-status`). The `step=status` param is
                              // forward-compatible: JM-042 wires the wizard to
                              // open the status view on it; the route resolves
                              // honestly today either way.
                              onTap: () => context.goNamed(
                                'kyc-status',
                                queryParameters: const {'step': 'status'},
                              ),
                            ),
                          ),
                          // ── Top up → wallet-charge-info (D92/D93, NO in-app
                          // pay).
                          child: Semantics(
                            identifier: 'funding_topup_cta',
                            button: true,
                            container: true,
                            child: JeebCtaButton.outline(
                              label: l10n.fundingTopupCta,
                              // EDGE → wallet-charge-info (D92/D93, JM-054).
                              onTap: () => context.goNamed('wallet-charge-info'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The navy starter-credit hero (D42) — the amount when the wallet snapshot
/// knows it, over the explainer copy that is the AC and therefore renders in
/// every load state. Same shadow + off-canvas accent ring as the wallet balance
/// hero (screen 23) so the jeeber's two money surfaces read as one family.
class _StarterCreditHero extends StatelessWidget {
  const _StarterCreditHero({required this.body, this.amount});

  /// The always-visible explainer sentence.
  final String body;

  /// The live gift-credit amount, or `null` when it is unknown or zero.
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = amount;

    return JeebNavySurfaceCard(
      radius: Spacing.large,
      padding: const EdgeInsetsDirectional.all(Spacing.large),
      shadow: JeebShadows.heroNavy,
      rings: const [JeebNavyRing.statBottomEnd],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (money != null) ...[
            Semantics(
              identifier: 'funding_starter_credit_amount',
              child: FittedBox(
                // A 200% text scale is the one thing that can push the number
                // off the card, so it scales down rather than wraps.
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  money,
                  style: context.jeebText.statHero
                      .copyWith(color: scheme.onPrimary),
                ),
              ),
            ),
            const SizedBox(height: Spacing.small),
          ],
          Text(
            body,
            style: context.jeebText.body.copyWith(color: scheme.onPrimary),
          ),
        ],
      ),
    );
  }
}
