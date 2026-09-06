import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../wallet/domain/wallet_repository.dart';

/// How the one wallet read this screen makes is going.
enum _WalletRead { loading, loaded, failed }

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
/// MIDNIGHT M3-18 (no board tile — derived). Nearest tiles: **R4 wallet** for the
/// money treatment and **R23 become-a-jeeber** for the funnel chrome. Carried
/// from R4: the hero money surface (`glassFillEmphasis` + `glassBorderStrong`
/// rung with 23's own Ø170 bottom-END accent ring), the eyebrow-over-figure
/// lockup, the `caption`-over-`cardTitle` w800 reserve stat, and the
/// wallet-family state block. Carried from R23 (this screen's caller, the KYC
/// wizard): the `content` field with ONE quiet orange glow at the top end, no
/// wash, no rings, no motion. Money emphasis is `price` 22/w800 (token sheet
/// §6) — R4's 40px `statHero` belongs to the wallet's one balance, and an
/// explainer must not out-shout it. No orange CTA: no tile draws this screen,
/// so theme ruling 3 ("when in doubt: not orange") holds and the only orange
/// left is the field glow and the hero ring.
class OnboardingFundingScreen extends StatefulWidget {
  const OnboardingFundingScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final WalletRepository? repository;

  @override
  State<OnboardingFundingScreen> createState() =>
      _OnboardingFundingScreenState();
}

class _OnboardingFundingScreenState extends State<OnboardingFundingScreen> {
  /// The live wallet snapshot, or `null` until [_read] reaches
  /// [_WalletRead.loaded]. The explainer never blocks on it (fail-safe).
  WalletBalance? _balance;

  _WalletRead _read = _WalletRead.loading;

  /// The classified failure behind [_WalletRead.failed], so the rung renders
  /// kind-aware copy instead of another screen's app-bar title.
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    // Unlike every sibling seam this used to throw a raw GetIt StateError when
    // nothing was registered; a null repo now reaches the failed rung.
    final repo =
        widget.repository ??
        (sl.isRegistered<WalletRepository>() ? sl<WalletRepository>() : null);
    if (repo == null) {
      if (mounted) {
        setState(() {
          _failure = const UnknownFailure();
          _read = _WalletRead.failed;
        });
      }
      return;
    }
    try {
      final balance = await repo.fetchBalance();
      if (mounted) {
        setState(() {
          _balance = balance;
          _failure = null;
          _read = _WalletRead.loaded;
        });
      }
    } on WalletRepositoryException catch (e) {
      // Fail-safe: the explainer is static copy, so a failed wallet fetch only
      // drops the enrichment and raises the retryable state block.
      if (mounted) {
        setState(() {
          _failure = e.cause ?? const UnknownFailure();
          _read = _WalletRead.failed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failure = AppFailure.of(e);
          _read = _WalletRead.failed;
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _failure = null;
      _read = _WalletRead.loading;
    });
    _loadBalance();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final balance = _balance;
    final money = _MoneyEnrichment.of(balance);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // R23's field: base wash + ONE quiet orange glow at the top end, no rings,
      // no twinkles, no motion — the chrome this screen's caller already wears.
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topEnd,
        animateDecor: false,
        // The board's header is an in-body row, not a Material app bar (§5 #1).
        child: SafeArea(
          child: Column(
            children: [
              JeebTopBar(
                identifier: 'funding_back',
                title: l10n.fundingTitle,
                leadingTooltip: MaterialLocalizations.of(
                  context,
                ).backButtonTooltip,
                // Reachable by deep link with an empty stack: pop when we can,
                // else go to the shell — never pop the last page.
                onLeadingPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              // `funding_explainer` is the screen ROOT (65_W2_TEST_PLAN §2
              // JM-041) and renders in EVERY load state — the copy is the AC.
              Expanded(
                child: Semantics(
                  identifier: 'funding_explainer',
                  container: true,
                  explicitChildNodes: true,
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        // 24px gutters; the footer owns the bottom inset, so
                        // this sliver ends flush.
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          Spacing.xLarge,
                          Spacing.medium,
                          Spacing.xLarge,
                          0,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // ── Starter credit (D42) ──────────────────────
                            _StarterCreditHero(
                              label: l10n.fundingStarterCreditLabel,
                              body: l10n.fundingStarterCreditBody,
                              amount: money.starterCredit,
                            ),
                            const SizedBox(height: Spacing.small),
                            // ── Reserve-10%-per-offer (D1) ────────────────
                            // The kit's documented wallet reserve-row form.
                            JeebInfoNote.outlined(
                              icon: Icons.lock,
                              text: l10n.fundingReserveBody,
                              trailing: money.reservedNow == null
                                  ? null
                                  : _ReservedNowStat(
                                      label: l10n.fundingReservedNowLabel,
                                      value: money.reservedNow!,
                                    ),
                            ),
                            // Not in the lower third: SliverFillRemaining
                            // measures intrinsics, the illustration cannot.
                            _WalletReadBlock(
                              read: _read,
                              failure: _failure,
                              onRetry: _retry,
                            ),
                          ]),
                        ),
                      ),
                      // ── The empty lower third is the design (R1/R4): dock
                      // the CTAs at its foot, scroll only on real overflow.
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Align(
                          alignment: AlignmentDirectional.bottomCenter,
                          child: _FundingCtas(l10n: l10n),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two enrichment figures, already formatted — or null where the wallet has
/// nothing to say. Keeps the "only when non-zero" rule in ONE place.
@immutable
class _MoneyEnrichment {
  const _MoneyEnrichment({this.starterCredit, this.reservedNow});

  factory _MoneyEnrichment.of(WalletBalance? balance) {
    if (balance == null) return const _MoneyEnrichment();
    return _MoneyEnrichment(
      starterCredit: balance.giftCredit > 0
          ? MoneyFormat.format(balance.giftCredit, currency: balance.currency)
          : null,
      reservedNow: balance.reservedNow > 0
          ? MoneyFormat.format(balance.reservedNow, currency: balance.currency)
          : null,
    );
  }

  final String? starterCredit;
  final String? reservedNow;
}

/// The starter-credit money surface (D42) — R4's hero lockup at explainer
/// scale: eyebrow, `price` figure when the snapshot knows it, then the copy
/// that is the AC and therefore renders in every load state.
class _StarterCreditHero extends StatelessWidget {
  const _StarterCreditHero({
    required this.label,
    required this.body,
    this.amount,
  });

  final String label;
  final String body;

  /// The live gift-credit amount, or `null` when it is unknown or zero.
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final money = amount;

    return JeebNavySurfaceCard(
      padding: const EdgeInsetsDirectional.all(Spacing.large),
      // 23's own wallet-hero ring — the carry that makes the jeeber's two money
      // surfaces read as one family.
      rings: const [JeebNavyRing.statBottomEnd],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JeebSectionLabel(label),
          const SizedBox(height: Spacing.xSmall),
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
                  style: context.jeebText.price.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.small),
          ],
          Text(
            body,
            style: context.jeebText.body.copyWith(color: semantic.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// R4's balance-card stat, reused as the reserve row's trailing slot: a caption
/// label over a w800 money figure.
class _ReservedNowStat extends StatelessWidget {
  const _ReservedNowStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final text = context.jeebText;

    return Semantics(
      identifier: 'funding_reserved_now_amount',
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            textAlign: TextAlign.end,
            style: text.caption.copyWith(color: semantic.mutedText),
          ),
          const SizedBox(height: Sizes.threeXSmall),
          Text(
            value,
            textAlign: TextAlign.end,
            style: text.cardTitle.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// The wallet read's own loading / error rung, docked above the CTAs so it can
/// never displace the AC explainer. `pocket` is the money subject of the empty
/// family — an empty pocket is what a wallet with nothing to report looks like.
/// The loaded rung draws nothing: the empty lower third is the design.
class _WalletReadBlock extends StatelessWidget {
  const _WalletReadBlock({
    required this.read,
    required this.onRetry,
    this.failure,
  });

  final _WalletRead read;
  final AppFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (read == _WalletRead.loaded) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
      child: read == _WalletRead.failed
          ? JeebFailureBlock.compact(
              failure: failure ?? const UnknownFailure(),
              identifier: 'funding_wallet_error',
              retryIdentifier: 'funding_wallet_retry',
              exitIdentifier: 'funding_wallet_exit',
              variant: JeebEmptyStateVariant.pocket,
              onRetry: onRetry,
              // R6: a 401/403 cannot be retried — the exit pill is the only act.
              onExit: failure is UnauthorizedFailure
                  ? () => context.go('/')
                  : () => context.canPop() ? context.pop() : context.go('/'),
            )
          : JeebEmptyState.compact(
              identifier: 'funding_wallet_loading',
              status: JeebEmptyStateStatus.loading,
              reason: JeebEmptyStateReason.loading,
              variant: JeebEmptyStateVariant.pocket,
              headline: l10n.fundingWalletLoadingHeadline,
            ),
    );
  }
}

/// The docked CTA pair. Order is the flow's, not the hierarchy's: top-up stays
/// the first affordance (as it shipped), Continue stays the pill the thumb
/// lands on last.
class _FundingCtas extends StatelessWidget {
  const _FundingCtas({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return JeebCtaFooter.single(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.xLarge,
        Spacing.xLarge,
        Spacing.twoXLarge,
      ),
      // ── Continue → kyc-pending-status (D38/D39). Periwinkle `primary`,
      // never accent: no tile draws an orange act on this screen.
      below: Semantics(
        identifier: 'funding_continue_cta',
        button: true,
        container: true,
        child: JeebCtaButton.primary(
          label: l10n.fundingContinueCta,
          // `kyc-status` = `/profile/kyc?step=status`; the param is
          // forward-compatible (JM-042) and resolves honestly today.
          onTap: () => context.goNamed(
            'kyc-status',
            queryParameters: const {'step': 'status'},
          ),
        ),
      ),
      // ── Top up → wallet-charge-info (D92/D93, NO in-app pay).
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
    );
  }
}
