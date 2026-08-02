import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../offline_mode/application/offline_cubit.dart';
import '../application/wallet_hub_cubit.dart';
import '../application/wallet_hub_state.dart';
import '../domain/wallet_repository.dart';
import 'wallet_hub_l10n.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/wallet_hub_screen_fixtures.dart';

class WalletHubScreen extends StatelessWidget {
  const WalletHubScreen({super.key, this.repository, this.kycStatusGate});

  final WalletRepository? repository;

  final JeeberKycStatusGate? kycStatusGate;

  @override
  Widget build(BuildContext context) {
    final gate = kycStatusGate ?? sl<JeeberKycStatusGate>();
    return BlocProvider<WalletHubCubit>(
      create: (_) => WalletHubCubit(
        repository: repository ?? sl<WalletRepository>(),
      )..load(),
      child: _WalletHubView(kycPending: gate.status == JeeberKycStatus.pending),
    );
  }
}

class _WalletHubView extends StatelessWidget {
  const _WalletHubView({required this.kycPending});

  final bool kycPending;

  @override
  Widget build(BuildContext context) {
    final copy = WalletHubL10n.of(context, kycPending: kycPending);
    return Semantics(
      identifier: 'wallet_hub_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.title,
          showBackButton: true,
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: BlocBuilder<WalletHubCubit, WalletHubState>(
          builder: (context, state) {
            switch (state.status) {
              case WalletHubStatus.initial:
              case WalletHubStatus.loading:
                return const OmdsLoadingState();
              case WalletHubStatus.failed:
                return OmdsErrorState(
                  message: copy.loadError,
                  retryLabel: copy.retry,
                  onRetry: () => context.read<WalletHubCubit>().refresh(),
                );
              case WalletHubStatus.loaded:
                return RefreshIndicator(
                  onRefresh: () => context.read<WalletHubCubit>().refresh(),
                  child: _LoadedBody(balance: state.balance, copy: copy),
                );
            }
          },
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.balance, required this.copy});

  final WalletBalance? balance;
  final WalletHubL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = balance;
    final currency = b?.currency ?? '';
    final affordability = b?.affordabilityState ?? WalletAffordability.empty;
    final hasGift = (b?.giftCredit ?? 0) > 0;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
        Spacing.xLarge,
      ),
      children: [
        if (copy.kycPending)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Spacing.large),
            child: Semantics(
              identifier: 'wallet_kyc_pending_banner',
              container: true,
              child: _Banner(
                icon: Icons.hourglass_top_outlined,
                title: copy.kycPendingTitle,
                body: copy.kycPendingBody,
              ),
            ),
          ),

        Semantics(
          identifier: 'wallet_available_balance',
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.availableBalanceLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: Spacing.twoXSmall),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _fmt(b?.availableBalance ?? 0),
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (currency.isNotEmpty) ...[
                    const SizedBox(width: Spacing.xSmall),
                    Text(
                      currency,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (hasGift) ...[
                const SizedBox(height: Spacing.small),
                Semantics(
                  identifier: 'wallet_gift_badge',
                  container: true,
                  child: OmdsChip(
                    label: copy.giftBadge(_fmt(b?.giftCredit ?? 0), currency),
                    icon: const Icon(Icons.card_giftcard_outlined, size: 16),
                    enabled: false,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: Spacing.large),

        Semantics(
          identifier: 'wallet_affordability_card',
          container: true,
          child: _Banner(
            icon: _affordabilityIcon(affordability),
            title: copy.affordabilityTitle(affordability),
            body: copy.affordabilityBody(affordability),
            tone: _affordabilityTone(affordability, context.jeebRoles),
          ),
        ),

        const SizedBox(height: Spacing.medium),

        Semantics(
          identifier: 'wallet_reserved_now',
          container: true,
          child: _StatRow(
            icon: Icons.lock_clock_outlined,
            label: copy.reservedNowLabel,
            value: '${_fmt(b?.reservedNow ?? 0)} $currency'.trim(),
            hint: copy.reservedNowHint,
          ),
        ),

        const SizedBox(height: Spacing.large),

        Semantics(
          identifier: 'wallet_topup_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: copy.topUpCta,
            onTap: () => _onTopUp(context),
          ),
        ),

        const SizedBox(height: Spacing.small),

        Semantics(
          identifier: 'wallet_how_fees_work',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: copy.howFeesWork,
            variant: OmdsButtonVariant.text,
            onTap: () => _showHowFees(context),
          ),
        ),

        const SizedBox(height: Spacing.large),

        Semantics(
          identifier: 'wallet_earnings_row',
          button: true,
          container: true,
          child: OmdsSettingsRow(
            title: copy.earningsRow,
            subtitle: copy.earningsRowSubtitle,
            leadingIcon: Icons.insights_outlined,
            onTap: () => context.goNamed('earnings'),
          ),
        ),

        Semantics(
          identifier: 'wallet_see_all_activity',
          button: true,
          container: true,
          child: OmdsSettingsRow(
            title: copy.seeAllActivity,
            subtitle: copy.seeAllActivitySubtitle,
            leadingIcon: Icons.receipt_long_outlined,
            onTap: () => context.goNamed('wallet-activity'),
          ),
        ),
      ],
    );
  }

  void _onTopUp(BuildContext context) {
    if (_isOffline(context)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(copy.offlineMoneyBlocked)));
      return;
    }
    context.goNamed('wallet-charge-info');
  }

  bool _isOffline(BuildContext context) {
    try {
      return context.read<OfflineCubit>().state.status ==
          ConnectivityStatus.offline;
    } catch (_) {
      return false;
    }
  }

  void _showHowFees(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HowFeesSheet(copy: copy),
    );
  }

  IconData _affordabilityIcon(WalletAffordability a) {
    switch (a) {
      case WalletAffordability.enough:
        return Icons.check_circle_outline;
      case WalletAffordability.low:
        return Icons.warning_amber_outlined;
      case WalletAffordability.empty:
        return Icons.account_balance_wallet_outlined;
      case WalletAffordability.allReserved:
        return Icons.lock_clock_outlined;
    }
  }

  (Color, Color)? _affordabilityTone(WalletAffordability a, JeebRoles roles) {
    switch (a) {
      case WalletAffordability.enough:
        return null; // neutral / positive surface
      case WalletAffordability.low:
      case WalletAffordability.empty:
      case WalletAffordability.allReserved:
        return (roles.warningContainer, roles.onWarningContainer);
    }
  }

  String _fmt(double v) => v.toStringAsFixed(2);
}

class _HowFeesSheet extends StatelessWidget {
  const _HowFeesSheet({required this.copy});

  final WalletHubL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'wallet_how_fees_explainer',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.medium,
          Spacing.xSmall,
          Spacing.medium,
          Spacing.large,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy.feesExplainerTitle,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.small),
            _FeeBullet(text: copy.feesExplainerLine1),
            _FeeBullet(text: copy.feesExplainerLine2),
            _FeeBullet(text: copy.feesExplainerLine3),
            const SizedBox(height: Spacing.large),
            OmdsPrimaryButton(
              text: copy.feesExplainerGotIt,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeBullet extends StatelessWidget {
  const _FeeBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String body;

  final (Color, Color)? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = tone?.$1 ?? theme.colorScheme.surfaceContainerHighest;
    final fg = tone?.$2 ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyLarge),
              if (hint != null) ...[
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: Spacing.small),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
// ============================== JEEB PREVIEWS ==============================

const Size _walletHubScreenPhoneBox = Size(390, 844);

class _WalletHubScreenEdgeStandIn extends StatelessWidget {
  const _WalletHubScreenEdgeStandIn(this.routeName);

  final String routeName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          routeName,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _WalletHubScreenHost extends StatefulWidget {
  const _WalletHubScreenHost({
    required this.repository,
    required this.kycStatusGate,
    this.offline = false,
  });

  final WalletRepository repository;
  final JeeberKycStatusGate kycStatusGate;
  final bool offline;

  @override
  State<_WalletHubScreenHost> createState() => _WalletHubScreenHostState();
}

class _WalletHubScreenHostState extends State<_WalletHubScreenHost> {
  late final GoRouter _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => _hub(),
        routes: <RouteBase>[
          for (final String name in const <String>[
            'wallet-charge-info',
            'earnings',
            'wallet-activity',
          ])
            GoRoute(
              path: name,
              name: name,
              builder: (_, _) => _WalletHubScreenEdgeStandIn(name),
            ),
        ],
      ),
    ],
  );

  Widget _hub() {
    final Widget screen = WalletHubScreen(
      repository: widget.repository,
      kycStatusGate: widget.kycStatusGate,
    );
    if (!widget.offline) return screen;
    return BlocProvider<OfflineCubit>(
      create: (_) => OfflineCubit()..setOffline(),
      child: screen,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

Widget _walletHubScreenHosted(
  WalletRepository repository, {
  JeeberKycStatusGate kycStatusGate = const WalletHubScreenKycGate.approved(),
  bool offline = false,
}) =>
    _WalletHubScreenHost(
      repository: repository,
      kycStatusGate: kycStatusGate,
      offline: offline,
    );

Widget _walletHubScreenWith(WalletBalance balance) =>
    _walletHubScreenHosted(WalletHubScreenFakeRepository(balance));

@JeebPreview(
  group: 'wallet',
  name: 'Ready to bid · funded',
  size: _walletHubScreenPhoneBox,
  matrix: true,
)
Widget walletHubScreenReadyToBid() =>
    _walletHubScreenWith(walletHubScreenHealthy);

@JeebPreview(
  group: 'wallet',
  name: 'Running low · starter credit',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenRunningLowWithGift() =>
    _walletHubScreenWith(walletHubScreenLowWithGift);

@JeebPreview(
  group: 'wallet',
  name: 'Empty · KYC pending',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenEmptyWithKycPending() => _walletHubScreenHosted(
      const WalletHubScreenFakeRepository(walletHubScreenEmpty),
      kycStatusGate: const WalletHubScreenKycGate.pending(),
    );

@JeebPreview(
  group: 'wallet',
  name: 'All reserved',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenEverythingReserved() =>
    _walletHubScreenWith(walletHubScreenAllReserved);

@JeebPreview(
  group: 'wallet',
  name: 'Ceiling · LBP + every band',
  size: _walletHubScreenPhoneBox,
  matrix: true,
)
Widget walletHubScreenCeilingLbp() => _walletHubScreenHosted(
      const WalletHubScreenFakeRepository(walletHubScreenLbpCeiling),
      kycStatusGate: const WalletHubScreenKycGate.pending(),
    );

@JeebPreview(
  group: 'wallet',
  name: 'Error · load failed',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenLoadFailed() =>
    _walletHubScreenHosted(const WalletHubScreenFailingRepository());

@JeebPreview(
  group: 'wallet',
  name: 'Loading · spinner',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenLoadingSpinner() =>
    _walletHubScreenHosted(const WalletHubScreenPendingRepository());

@JeebPreview(
  group: 'wallet',
  name: 'Offline · top-up blocked',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenOfflineTopUp() => _walletHubScreenHosted(
      const WalletHubScreenFakeRepository(walletHubScreenOfflineFunded),
      offline: true,
    );
