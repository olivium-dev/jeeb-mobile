import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../wallet/domain/wallet_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/onboarding_funding_screen_fixtures.dart';

class OnboardingFundingScreen extends StatefulWidget {
  const OnboardingFundingScreen({super.key, this.repository});

  final WalletRepository? repository;

  @override
  State<OnboardingFundingScreen> createState() =>
      _OnboardingFundingScreenState();
}

class _OnboardingFundingScreenState extends State<OnboardingFundingScreen> {
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
    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = _balance;
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.fundingTitle,
        showBackButton: true,
        onBackPressed: () =>
            context.canPop() ? context.pop() : context.go('/'),
      ),
      body: Semantics(
        identifier: 'funding_explainer',
        container: true,
        explicitChildNodes: true,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            OMDSSectionCard(
              title: l10n.fundingTitle,
              showDivider: false,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fundingStarterCreditBody,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (balance != null && balance.giftCredit > 0)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(top: Spacing.small),
                      child: Semantics(
                        identifier: 'funding_starter_credit_amount',
                        child: Text(
                          _formatMoney(balance.giftCredit, balance.currency),
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.medium),
            OMDSSectionCard(
              title: l10n.fundingTitle,
              showDivider: false,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fundingReserveBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (balance != null && balance.reservedNow > 0)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(top: Spacing.small),
                      child: Semantics(
                        identifier: 'funding_reserved_now_amount',
                        child: Text(
                          _formatMoney(balance.reservedNow, balance.currency),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'funding_topup_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.fundingTopupCta,
                variant: OmdsButtonVariant.secondary,
                onTap: () => context.goNamed('wallet-charge-info'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'funding_continue_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.fundingContinueCta,
                onTap: () => context.goNamed(
                  'kyc-status',
                  queryParameters: const {'step': 'status'},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(double amount, String currency) {
  final value = amount.toStringAsFixed(2);
  return currency.isEmpty ? value : '$value $currency';
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, not the harness default.
/// Public so the render test can reproduce the canvas box with
const Size onboardingFundingScreenPhoneBox = Size(390, 844);

/// The smallest phone the app supports (iPhone SE 1st gen / small Androids).
/// Worth its own card twice over: at normal text size it is the frame the
const Size onboardingFundingScreenCompactBox = Size(320, 568);

/// Hosts the real screen on the stack named by [entry], reading [repository],
/// optionally at [textScale] and in [arabic].
Widget _onboardingFundingScreenHosted({
  WalletRepository repository = const OnboardingFundingScreenStaticWallet(
    onboardingFundingScreenEnrichedBalance,
  ),
  OnboardingFundingScreenEntry entry = OnboardingFundingScreenEntry.standalone,
  double textScale = 1,
  bool arabic = false,
}) {
  final Widget hosted = OnboardingFundingScreenHost(
    entry: entry,
    screen: OnboardingFundingScreen(repository: repository),
  );
  final Widget scaled = textScale == 1
      ? hosted
      : Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: hosted,
          ),
        );
  if (!arabic) return scaled;
  return Builder(
    builder: (BuildContext context) => Localizations.override(
      context: context,
      locale: const Locale('ar'),
      child: Directionality(textDirection: TextDirection.rtl, child: scaled),
    ),
  );
}

/// The one state in which the screen shows everything it can show: the D42
/// starter credit AND a live D1 reserve, both enrichment amounts rendered.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Enriched · starter credit + live reserve',
  size: onboardingFundingScreenPhoneBox,
  matrix: true,
)
Widget onboardingFundingScreenEnriched() => _onboardingFundingScreenHosted();

/// The state every real jeeber is in on arrival: the starter credit is on file,
/// but no offer has been sent yet, so `reservedNow` is 0.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Nothing reserved yet',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenNothingReserved() =>
    _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenStaticWallet(
        onboardingFundingScreenUnreservedBalance,
      ),
    );

/// The mirror image: the starter credit has been spent (`giftCredit` 0) and
/// everything left is reserved against live offers.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Gift spent · everything reserved',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenGiftSpent() => _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenStaticWallet(
        onboardingFundingScreenGiftSpentBalance,
      ),
    );

/// The fail-safe branch: `fetchBalance()` throws the typed
/// [WalletRepositoryException] and the screen swallows it, leaving `_balance`
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Fail-safe · wallet read failed',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenLoadFailed() => _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenFailingWallet(),
    );

/// The first frame, and the only one 100% of users are guaranteed to see:
/// `initState` fires the fetch, the frame is painted, and the amounts arrive
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Loading · read still in flight',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenLoading() => _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenPendingWallet(),
    );

/// The other half of the arrow's contract: the screen sitting ON TOP of the KYC
/// wizard, where `context.canPop()` is true and back POPS.
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Pushed on the KYC wizard · back pops',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenPushedOnWizard() =>
    _onboardingFundingScreenHosted(
      entry: OnboardingFundingScreenEntry.pushedOnKycWizard,
    );

/// The floor: the smallest supported phone at NORMAL text size.
/// Measured, this one is GOOD news, and it is a card because it is one
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Compact 320x568',
  size: onboardingFundingScreenCompactBox,
)
Widget onboardingFundingScreenCompact() => _onboardingFundingScreenHosted();

/// The accessibility ceiling with the longest content the formatter can
/// produce, on the frame where it breaks: 200% text, a weak-unit currency, and
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'Ceiling · 200% text on a 320 phone',
  size: onboardingFundingScreenCompactBox,
)
Widget onboardingFundingScreenCeiling() => _onboardingFundingScreenHosted(
      repository: const OnboardingFundingScreenStaticWallet(
        onboardingFundingScreenCeilingBalance,
      ),
      textScale: 2,
    );

/// The combination the standard matrix cannot render: Arabic AND 200% text.
/// RTL mirrors the `EdgeInsetsDirectional` list padding and both cards, while
@JeebPreview(
  group: 'jeeber_onboarding_funding',
  name: 'AR · 200% text',
  size: onboardingFundingScreenPhoneBox,
)
Widget onboardingFundingScreenArabicLargeText() =>
    _onboardingFundingScreenHosted(textScale: 2, arabic: true);
