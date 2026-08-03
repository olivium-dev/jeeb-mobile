import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../application/account_status_cubit.dart';
import '../application/account_status_state.dart';
import '../data/dio_account_status_repository.dart';
import '../data/stub_account_status_repository.dart';
import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';
import 'account_status_l10n.dart';

/// The board's header band: 24px gutters, 16px above the title
/// (redesign-2026-08 §4.3 — `--screen-gutter: 24`).
const EdgeInsetsGeometry _kHeaderPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  0,
);

/// The scrolling band under the header — same 24px gutter, 20px of air below
/// the title before the state panel.
const EdgeInsetsGeometry _kBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.large,
  Spacing.xLarge,
  Spacing.large,
);

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
/// redesign-2026-08: re-skinned onto the Jeeb kit — the OMDS app bar becomes an
/// in-body padded title (screen 19's shape; a gate screen must NOT gain the
/// [JeebTopBar] back circle, `app_router.backFallbacks` excludes it by name),
/// the blocked state becomes a role-coloured [JeebInfoNote] instead of a 64px
/// error glyph over centred text, and the two exits dock in a [JeebCtaFooter]
/// under a real empty band (R1 — never vertically centre, never fill it).
/// Flow, copy and both edges are unchanged.
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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'account_status_root',
      container: true,
      child: Scaffold(
        // No app bar: the title is an in-body band so it reads identically in
        // every state (loading / failed / loaded), like the rest of the board.
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: _kHeaderPadding,
                child: Text(
                  copy.title,
                  style: context.jeebText.h2.copyWith(color: scheme.primary),
                ),
              ),
              Expanded(
                child: BlocBuilder<AccountStatusCubit, AccountStatusState>(
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
            ],
          ),
        ),
      ),
    );
  }
}

/// The blocked-account body: status panel + reason over a real empty band, with
/// the two exit CTAs docked at the foot.
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
    final scheme = Theme.of(context).colorScheme;
    // Prefer a server-supplied reason; else localized per-state copy.
    final reason = serverReason ?? copy.defaultReason(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // Scrolls rather than overflows when a long server reason meets a
          // large text scale; the residual space stays white and top-aligned.
          child: ListView(
            padding: _kBodyPadding,
            children: [
              // Status banner — the WHICH-blocked-state headline (D5). The
              // kit's error tone is the soft Wave-0 errorContainer, not the
              // legacy red slab; the state is the message, so it keeps its
              // role colour on every surface.
              Semantics(
                identifier: 'account_status_banner',
                container: true,
                child: JeebInfoNote.error(
                  icon: value == AccountStatusValue.locked
                      ? Icons.lock_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  title: copy.banner(value),
                ),
              ),
              const SizedBox(height: Spacing.medium),
              // Reason — server reason verbatim, else localized per-state copy.
              Semantics(
                identifier: 'account_status_reason',
                // container so the reason owns its own node, mirroring the
                // banner above. Without it the default explicitChildNodes:false
                // annotation merges this identifier up into account_status_root
                // (which already owns that node), folding the reason id away
                // (JM-049 merge class).
                container: true,
                child: Text(
                  reason,
                  style: context.jeebText.body.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        JeebCtaFooter.single(
          // EDGE → logout-delete-account (JM-062, JM-066 AC3). Open the
          // confirm sheet (`logout_delete_sheet`) directly; on confirm the
          // session is cleared and the gate routes to splash → /login (D5).
          below: Semantics(
            identifier: 'account_status_signout_cta',
            button: true,
            container: true,
            child: JeebCtaButton.outline(
              label: copy.signoutCta,
              onTap: () => LogoutDeleteConfirmSheet.show(
                context,
                mode: LogoutDeleteMode.both,
              ),
            ),
          ),
          // EDGE → support-ticket (JM-063, D76). `/support` is registered.
          child: Semantics(
            identifier: 'account_status_support_cta',
            button: true,
            container: true,
            child: JeebCtaButton.primary(
              label: copy.supportCta,
              onTap: () => context.goNamed('support-ticket'),
            ),
          ),
        ),
      ],
    );
  }
}
