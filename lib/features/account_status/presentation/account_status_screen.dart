import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../application/account_status_cubit.dart';
import '../application/account_status_state.dart';
import '../data/dio_account_status_repository.dart';
import '../data/stub_account_status_repository.dart';
import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';
import 'account_status_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/account_status_screen_fixtures.dart';

class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key, this.repository});

  final AccountStatusRepository? repository;

  AccountStatusRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<AccountStatusRepository>()) {
      return sl<AccountStatusRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioAccountStatusRepository(sl<Dio>());
    }
    return const StubAccountStatusRepository();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountStatusCubit>(
      create: (_) =>
          AccountStatusCubit(repository: _resolveRepository())..load(),
      child: const _AccountStatusView(),
    );
  }
}

class _AccountStatusView extends StatelessWidget {
  const _AccountStatusView();

  @override
  Widget build(BuildContext context) {
    final copy = AccountStatusL10n.of(context);
    return Semantics(
      identifier: 'account_status_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: copy.title),
        body: BlocBuilder<AccountStatusCubit, AccountStatusState>(
          builder: (context, state) {
            switch (state.status) {
              case AccountStatusScreenStatus.initial:
              case AccountStatusScreenStatus.loading:
                return const OmdsLoadingState();
              case AccountStatusScreenStatus.failed:
                return OmdsErrorState(
                  message: copy.loadError,
                  retryLabel: copy.retry,
                  onRetry: () =>
                      context.read<AccountStatusCubit>().refresh(),
                );
              case AccountStatusScreenStatus.loaded:
                return _BlockedBody(
                  value: state.value,
                  serverReason: state.reason,
                  copy: copy,
                );
            }
          },
        ),
      ),
    );
  }
}

class _BlockedBody extends StatelessWidget {
  const _BlockedBody({
    required this.value,
    required this.serverReason,
    required this.copy,
  });

  final AccountStatusValue value;
  final String? serverReason;
  final AccountStatusL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = serverReason ?? copy.defaultReason(value);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Spacing.medium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              value == AccountStatusValue.locked
                  ? Icons.lock_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'account_status_banner',
              container: true,
              child: Text(
                copy.banner(value),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'account_status_reason',
              container: true,
              child: Text(
                reason,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'account_status_support_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: copy.supportCta,
                onTap: () => context.goNamed('support-ticket'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'account_status_signout_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: copy.signoutCta,
                variant: OmdsButtonVariant.outlined,
                onTap: () => LogoutDeleteConfirmSheet.show(
                  context,
                  mode: LogoutDeleteMode.both,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _accountStatusScreenPhoneBox = Size(390, 844);

/// The one destination the support CTA has, stubbed.
/// The real target is `support-ticket` (JM-063, `/support`, D76); here it only
/// has to exist so a tap lands somewhere and shows which route was taken.
class _AccountStatusScreenStandIn extends StatelessWidget {
  const _AccountStatusScreenStandIn(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: diagnostic, not shipped copy, and a latin route name
          label,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _AccountStatusScreenHost extends StatefulWidget {
  const _AccountStatusScreenHost({required this.repository});

  final AccountStatusRepository repository;

  @override
  State<_AccountStatusScreenHost> createState() =>
      _AccountStatusScreenHostState();
}

class _AccountStatusScreenHostState extends State<_AccountStatusScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/account-status',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const _AccountStatusScreenStandIn('splash (D5)'),
      ),
      GoRoute(
        path: '/account-status',
        builder: (_, _) => AccountStatusScreen(repository: widget.repository),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (_, _) =>
            const _AccountStatusScreenStandIn('support-ticket (JM-063)'),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

Widget _accountStatusScreenHosted(AccountStatusRepository repository) =>
    _AccountStatusScreenHost(repository: repository);

@JeebPreview(
  group: 'account_status',
  name: 'Suspended · no server reason',
  size: _accountStatusScreenPhoneBox,
)
Widget accountStatusScreenSuspendedNoReason() => _accountStatusScreenHosted(
      const AccountStatusScreenFakeRepository(accountStatusScreenSuspended),
    );

@JeebPreview(
  group: 'account_status',
  name: 'Locked · server reason',
  size: _accountStatusScreenPhoneBox,
  matrix: true,
)
Widget accountStatusScreenLockedServerReason() => _accountStatusScreenHosted(
      const AccountStatusScreenFakeRepository(
        accountStatusScreenLockedWithReason,
      ),
    );

@JeebPreview(
  group: 'account_status',
  name: 'Locked · long server reason',
  size: _accountStatusScreenPhoneBox,
  matrix: true,
)
Widget accountStatusScreenLongServerReason() => _accountStatusScreenHosted(
      const AccountStatusScreenFakeRepository(
        accountStatusScreenLockedLongReason,
      ),
    );

@JeebPreview(
  group: 'account_status',
  name: 'Error · status read failed',
  size: _accountStatusScreenPhoneBox,
)
Widget accountStatusScreenLoadFailed() => _accountStatusScreenHosted(
      const AccountStatusScreenFailingRepository(),
    );

@JeebPreview(
  group: 'account_status',
  name: 'Loading · cold entry',
  size: _accountStatusScreenPhoneBox,
)
Widget accountStatusScreenLoading() => _accountStatusScreenHosted(
      const AccountStatusScreenPendingRepository(),
    );
