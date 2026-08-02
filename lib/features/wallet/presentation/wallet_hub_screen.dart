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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
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
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/wallet/wallet_hub_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so two things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device ([_walletHubScreenPhoneBox],
//    390x844) rather than the harness's default 390x200 — a scrolling money
//    screen cannot be judged in a 200 pt strip.
//
// 2. Unlike `SavedLocationsScreen`, this screen BUILDS without a `Router`:
//    every `goNamed`/`canPop` call sits inside a callback, not in `build`. It
//    is not TAPPABLE without one, though — `wallet_topup_cta`,
//    `wallet_earnings_row`, `wallet_see_all_activity` and the app-bar back
//    arrow all reach for GoRouter the moment you touch them, and the canvas is
//    a surface you tap. [_WalletHubScreenHost] supplies a local [GoRouter] with
//    stand-ins for the three named destinations, so a tap lands somewhere and
//    tells you WHICH edge it took instead of throwing.
//
// State is driven the only way this screen allows: through the `repository:`
// and `kycStatusGate:` constructor seams, with the fakes shared verbatim with
// the Screen Catalog entry
// (`lib/devtool/catalog/fixtures/wallet_hub_screen_fixtures.dart`). No preview
// builds a `DioWalletRepository`, and `sl<WalletRepository>()` /
// `sl<JeeberKycStatusGate>()` are never reached — network-free by construction
// rather than by the guard in [jeebPreviewHost].
//
// One state cannot be reached from here: `refresh()`'s failure branch, which
// keeps `status: loaded` and only sets `error`, is emitted after a pull-to-
// refresh and renders NOTHING (the loaded branch never reads `state.error`).
// In the canvas you can reach it by pulling down on a preview whose fake throws
// on the second read; there is no `cubit:` seam to seed it directly.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * the balance line is `Row(Text(amount), SizedBox, Text(currency))` with no
//    `Flexible` on either child, and `_fmt` is `toStringAsFixed(2)` — no
//    grouping, no locale digits. Measured on the 390 pt phone these previews
//    declare:
//      - `Ceiling · LBP + every band` overflows the balance Row by 6.5 pt and
//        the gift chip by 51 pt at 100% TEXT, in EN and AR alike. An LBP
//        wallet clips its own balance on a stock phone with no accessibility
//        setting touched.
//      - `Ready to bid · funded` — 145.00 USD, the most ordinary wallet there
//        is — overflows by 82 pt at 200% text; the ceiling by 362 pt.
//      - the gift chip is a `Row` inside a `Container` with nothing flexible
//        either: 276 pt over in EN at 200% (`50.00 USD starter credit`).
//    `_StatRow` (reserved-now) is the counter-example — its label is
//    `Expanded`, so it shrinks instead of overflowing. The same unformatted
//    number is what an Arabic jeeber sees: latin digits, no separators, and
//    the currency mirrored to the LEFT of the amount.
//    The render tests do not see any of this on their own — `previewCanvas`
//    pumps on the 800x600 test surface, not the `size:` a preview declares, and
//    everything fits at 800 pt. The 100%-text case is pinned deliberately (see
//    `does not fit a 390 pt phone` in the render test); the rest is what the
//    canvas is for.
//  * `wallet_topup_cta` renders IDENTICALLY offline (`Offline · top-up
//    blocked`): full-strength `OmdsPrimaryButton`, no disabled state, no
//    inline notice. The D35 money guard only speaks after the tap, as a
//    SnackBar. Every other CTA on the screen behaves the same way, so the
//    offline wallet looks fully operable.
//  * the error branch (`Error · load failed`) replaces the WHOLE body, so a
//    jeeber who cannot load a balance also loses `wallet_topup_cta` — the one
//    action that would fix an empty wallet — along with the fees explainer and
//    both cross-wave rows. `Retry` is all that is left.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _walletHubScreenPhoneBox = Size(390, 844);

/// One of the three named destinations the hub owns, stubbed.
///
/// The real routes live in `app_router.dart`; here they only have to exist so a
/// tap on `wallet_topup_cta` / `wallet_earnings_row` / `wallet_see_all_activity`
/// lands somewhere and shows WHICH edge was taken.
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
          // Forced LTR: a diagnostic, not shipped copy, and a latin route name
          // reorders visually inside an RTL paragraph.
          routeName,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [WalletHubScreen] so its CTAs are tappable.
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state
/// `canPop()`/`goNamed()` depend on. `Router.withConfig` is exactly what
/// `MaterialApp.router` does internally, so this adds a Router and nothing else
/// — the ambient theme, locale and text scale still come from the preview host
/// above it.
class _WalletHubScreenHost extends StatefulWidget {
  const _WalletHubScreenHost({
    required this.repository,
    required this.kycStatusGate,
    this.offline = false,
  });

  final WalletRepository repository;
  final JeeberKycStatusGate kycStatusGate;

  /// Mounts an [OfflineCubit] seeded OFFLINE above the screen (D35). Left
  /// false there is no provider at all, which is the production tree — the
  /// screen's `_isOffline` catches the lookup and treats it as online.
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

/// The happy path (D30 `enough`): funded, a live 10% reserve against one open
/// offer, KYC approved.
///
/// Matrixed because the balance line is the screen's signature element and it
/// is a bare [Row] — amount, then currency, neither of them flexible. The AR
/// rendering is where that Row mirrors (currency LEFT of the amount, latin
/// digits unchanged); the 200% rendering is where it overflows the 390 pt phone
/// by 82 pt, on the plainest three-digit USD wallet the app can produce. Note
/// that the gift badge is absent here: `giftCredit == 0` hides
/// `wallet_gift_badge` (D42), so this is also the "no starter credit" layout.
@JeebPreview(
  group: 'wallet',
  name: 'Ready to bid · funded',
  size: _walletHubScreenPhoneBox,
  matrix: true,
)
Widget walletHubScreenReadyToBid() =>
    _walletHubScreenWith(walletHubScreenHealthy);

/// D30 `low` + D42 starter credit — the only state that renders
/// `wallet_gift_badge`.
///
/// Worth reading as a pair: the affordability card says "Running low" in the
/// warning tone while the badge directly above it announces 50.00 USD of
/// credit. Both are true (the gift is not spendable against a reserve yet) and
/// together they are the most confusing 100 pt on the screen.
@JeebPreview(
  group: 'wallet',
  name: 'Running low · starter credit',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenRunningLowWithGift() =>
    _walletHubScreenWith(walletHubScreenLowWithGift);

/// The zero state (D30 `empty`) on a jeeber whose KYC is still pending
/// (D38/D39) — the combination a newly-registered jeeber actually opens the
/// wallet in, and the only state that renders `wallet_kyc_pending_banner`.
///
/// Two stacked banners before the balance is even reached, both in the same
/// container shape: the pending banner (neutral surface) and the affordability
/// card (warning tone). The balance itself is `0.00 USD`.
@JeebPreview(
  group: 'wallet',
  name: 'Empty · KYC pending',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenEmptyWithKycPending() => _walletHubScreenHosted(
      const WalletHubScreenFakeRepository(walletHubScreenEmpty),
      kycStatusGate: const WalletHubScreenKycGate.pending(),
    );

/// D30 `allReserved`: the balance is real (20.00) but every cent is held
/// against live offers, so `wallet_available_balance` and `wallet_reserved_now`
/// show the SAME number.
///
/// The screen never says that in so many words — it prints both amounts and
/// leaves the reader to notice they match. This is the state D43 exists for:
/// the copy ("Everything is reserved") is what carries the meaning, not the
/// numbers.
@JeebPreview(
  group: 'wallet',
  name: 'All reserved',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenEverythingReserved() =>
    _walletHubScreenWith(walletHubScreenAllReserved);

/// The layout ceiling: a Lebanese-pound wallet with a starter credit and the
/// KYC-pending banner up — the tallest, widest content the hub can hold.
///
/// Not a synthetic stress test. LBP is a live currency here and its amounts run
/// to eight digits, so `89750000.00` is what a real jeeber sees. Read the
/// matrix top to bottom:
///
///   * EN light — already broken, with no accessibility setting touched: there
///     is no thousands separator anywhere on the screen (`_fmt` is
///     `toStringAsFixed(2)`), and on the 390 pt phone this box declares the
///     balance Row overflows by 6.5 pt and the gift chip by 51 pt.
///   * AR RTL dark — the digits stay latin (no `NumberFormat`, no arabic-indic)
///     and the Row mirrors, putting `LBP` to the LEFT of the amount. The
///     balance Row overflows here too, by the same 6.5 pt.
///   * EN 200% — 362 pt over on the balance Row and 399 pt on the gift chip.
///     Neither has a `Flexible` child to give way.
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

/// `GET /v1/jeeb/wallet` failed.
///
/// The cubit collapses every [WalletFailure] onto one `failed` status, so this
/// single picture covers offline, 401 and 500 alike. What the picture shows is
/// the cost of that collapse: the error state replaces the ENTIRE body, so the
/// jeeber loses `wallet_topup_cta`, the fees explainer and both cross-wave rows
/// along with the balance. "Retry" re-runs `refresh()`, which is the only way
/// out.
@JeebPreview(
  group: 'wallet',
  name: 'Error · load failed',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenLoadFailed() =>
    _walletHubScreenHosted(const WalletHubScreenFailingRepository());

/// The cold-start window, held open by a read that never lands.
///
/// `load()` runs from the `BlocProvider.create`, so this is the first frame of
/// every entry into the hub: a bare centred spinner with no app-bar-level hint
/// of what is loading, and no skeleton of the balance line that is about to
/// appear. `load()` also guards on `status != initial`, so a rebuild cannot
/// restart it — a request that never lands leaves the screen here for good,
/// with no retry affordance (unlike the error state, which at least offers one).
@JeebPreview(
  group: 'wallet',
  name: 'Loading · spinner',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenLoadingSpinner() =>
    _walletHubScreenHosted(const WalletHubScreenPendingRepository());

/// The D35 money guard, made visible: a healthy wallet with an [OfflineCubit]
/// seeded OFFLINE above the screen.
///
/// Compare it with `Ready to bid · funded` — the only difference on screen is
/// the balance (63.00 vs 145.00). `wallet_topup_cta` is a full-strength
/// [OmdsPrimaryButton] in both, because the guard lives inside `_onTopUp` and
/// only speaks AFTER the tap, as a SnackBar. There is no disabled treatment, no
/// inline notice, and no offline banner on this screen at all, so an offline
/// jeeber reads a fully operable wallet and discovers otherwise one tap at a
/// time.
@JeebPreview(
  group: 'wallet',
  name: 'Offline · top-up blocked',
  size: _walletHubScreenPhoneBox,
)
Widget walletHubScreenOfflineTopUp() => _walletHubScreenHosted(
      const WalletHubScreenFakeRepository(walletHubScreenOfflineFunded),
      offline: true,
    );
