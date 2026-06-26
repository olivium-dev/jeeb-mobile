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

/// `account-status` (JM-066, D5). Terminal screen shown when
/// `getMe.status ∈ {suspended, locked}`. The router's [AccountStatusGate]
/// forces this route and blocks ALL tab access while the account is not active;
/// the only exits are contact-support and sign-out.
///
/// W4 body (JM-066): the redirect-gate PREDICATE landed in W0 (router +
/// [AccountStatusGate]); this is the data-bound body fill. It reads the blocked
/// status from `GET /users/me` (U1 — 42_GUARDRAILS_MOCK W-1 FLOOR) so the
/// banner + reason copy reflect WHICH blocked state the account is in
/// (suspended vs locked, D5). It renders the D30 four-state machine
/// (40_GUARDRAILS_ARCH §3): loading → loaded (banner + reason + CTAs) | failed
/// (retry). The screen NEVER polices its own reachability (40_GUARDRAILS_ARCH
/// §12) — the gate owns that.
///
/// CTAs (both target REGISTERED routes — navigation honesty, CTO brief §6.7):
///   * `account_status_support_cta` → `support-ticket` (JM-063, `/support`, D76).
///   * `account_status_signout_cta` → the logout/delete confirm host
///     `settings` (JM-062); the confirm clears the session and the router gate
///     then routes to splash (`/` → first-run, D5).
///
/// Semantics identifiers exposed (EXACT — 30_BACKLOG JM-066):
///   `account_status_root`         — screen host container (gate target)
///   `account_status_support_cta`  — Contact support → support-ticket
///   `account_status_signout_cta`  — Sign out → logout-delete host
class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final AccountStatusRepository? repository;

  /// Resolves the repo: an explicit override (tests) → the registered
  /// `AccountStatusRepository` (when the integrator DI batch lands it) → a LIVE
  /// `DioAccountStatusRepository` over `sl<Dio>()` when GetIt is configured →
  /// the inert `StubAccountStatusRepository` for bare router-resolution widget
  /// tests. Mirrors `NotificationsListScreen._resolveRepository()`.
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

/// The blocked-account body: status banner + reason + the two exit CTAs.
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
    // Prefer a server-supplied reason; else localized per-state copy.
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
            // Status banner — the WHICH-blocked-state headline (D5).
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
            // Reason — server reason verbatim, else localized per-state copy.
            Semantics(
              identifier: 'account_status_reason',
              // container so the reason owns its own node, mirroring the banner
              // above. Without it the default explicitChildNodes:false annotation
              // merges this identifier up into account_status_root (which already
              // owns that node), folding the reason id away (JM-049 merge class).
              container: true,
              child: Text(
                reason,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: Spacing.large),
            // EDGE → support-ticket (JM-063, D76). `/support` is registered.
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
            // EDGE → logout-delete-account (JM-062, JM-066 AC3). Open the
            // confirm sheet (`logout_delete_sheet`) directly; on confirm the
            // session is cleared and the gate routes to splash → /login (D5).
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
