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
