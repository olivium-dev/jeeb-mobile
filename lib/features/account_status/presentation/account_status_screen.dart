import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_surface_tone.dart';
import '../../settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../application/account_status_cubit.dart';
import '../application/account_status_state.dart';
import '../data/dio_account_status_repository.dart';
import '../data/stub_account_status_repository.dart';
import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';
import 'account_status_l10n.dart';

/// The bare padded title band — R19's shape (`earnings_dashboard_screen.dart`
/// `_headerPadding`), the one header form for a screen that must not offer a
/// back circle.
const EdgeInsetsGeometry _kHeaderPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  0,
);

/// The scrolling band under the header — same 24 gutter, R22's 20 band lead-in.
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
/// MIDNIGHT M3-22 (derived; no tile). Nearest tiles: **R23** for the chrome
/// (`content` field, one orange glow top-end, no periwinkle, board-still) and
/// **R22** for the status rungs (glass strip stating a fact, docked exits,
/// destructive on danger-SOFT). Bands, top to bottom:
///   - bare padded title, `onSurface` ink (R19's header; a gate screen must NOT
///     gain the [JeebTopBar] back circle, `app_router.backFallbacks` excludes
///     it by name)
///   - the WHICH-blocked-state panel — soft danger `JeebInfoNote.error`
///   - the reason on R23's glass info strip
///   - a real empty band, then the docked support / sign-out exits
///
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

  /// The in-flight read (`account_status_loading`).
  static const String loadingIdentifier = 'account_status_loading';

  /// The failed read (`account_status_load_error`) and its retry pill.
  static const String loadErrorIdentifier = 'account_status_load_error';
  static const String retryIdentifier = 'account_status_retry_cta';

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
      // R23's field: `content`, one orange glow at the top end, no periwinkle
      // wash, no rings — and it does not move.
      child: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topEnd,
        animateDecor: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
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
                    style: context.jeebText.h2.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<AccountStatusCubit, AccountStatusState>(
                    builder: (context, state) {
                      switch (state.status) {
                        case AccountStatusScreenStatus.initial:
                        case AccountStatusScreenStatus.loading:
                          return _LoadingBody(copy: copy);
                        case AccountStatusScreenStatus.failed:
                          return _FailedBody(copy: copy);
                        case AccountStatusScreenStatus.loaded:
                          return _BlockedBody(
                            value: state.value,
                            serverReason: state.reason,
                            serverReasonCode: state.reasonCode,
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
      ),
    );
  }
}

/// The cold read of `GET /users/me`. `radar` is the variant for the same reason
/// M3-07 picked it on the profile tab: it is the only one whose subject is an
/// account "listening for a signal" rather than a request (a mic, a parcel, a
/// scooter). Its three identity discs are dropped — E2 draws jeebers in range,
/// and there is no second party on this surface to name.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.copy});

  final AccountStatusL10n copy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: JeebEmptyState(
        variant: JeebEmptyStateVariant.radar,
        status: JeebEmptyStateStatus.loading,
        medallions: const <JeebEmptyMedallion>[],
        identifier: AccountStatusScreen.loadingIdentifier,
        headline: copy.loadingHeadline,
      ),
    );
  }
}

/// The failed read. Same illustration, danger-tinted centre (kit ruling 1), and
/// the retry is the glass pill — never an orange act the board does not draw.
class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.copy});

  final AccountStatusL10n copy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: JeebEmptyState(
        variant: JeebEmptyStateVariant.radar,
        status: JeebEmptyStateStatus.error,
        medallions: const <JeebEmptyMedallion>[],
        identifier: AccountStatusScreen.loadErrorIdentifier,
        headline: copy.loadErrorTitle,
        body: copy.loadError,
        action: JeebCtaButton.outline(
          label: copy.retry,
          expand: false,
          identifier: AccountStatusScreen.retryIdentifier,
          onTap: () => context.read<AccountStatusCubit>().refresh(),
        ),
      ),
    );
  }
}

/// R23's `[glyph] gap [copy]` strip row, composed through [JeebInfoNote.label]
/// rather than its `icon:` slot for two reasons: the kit centres a leading
/// glyph on the row, and `statusReason` is free server text — at the measured
/// ceiling the glyph floats mid-paragraph, which the board never draws. The
/// `label:` hatch also keeps this line on the 14.5 `body` ramp instead of the
/// strip's 12.5 default. Sizes and gap are the kit's own consts.
class _ReasonLine extends StatelessWidget {
  const _ReasonLine({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final muted = JeebSurfaceTone.of(context).mutedInk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: JeebInfoNote.stripIconSize,
          color: muted,
        ),
        const SizedBox(width: JeebInfoNote.stripGap),
        Expanded(
          child: Text(
            reason,
            style: context.jeebText.body.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// The blocked-account body: status panel + reason over a real empty band, with
/// the two exit CTAs docked at the foot.
class _BlockedBody extends StatelessWidget {
  const _BlockedBody({
    required this.value,
    required this.serverReason,
    required this.serverReasonCode,
    required this.copy,
  });

  final AccountStatusValue value;
  final String? serverReason;
  final String? serverReasonCode;
  final AccountStatusL10n copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // D16 precedence: an operator's typed prose (already human-safe) wins;
    // else the ban-policy key looked up in the viewer's language; else the
    // localized per-state copy. A raw `Label{{...}}` never reaches here.
    final reason = serverReason ??
        copy.reasonForCode(serverReasonCode) ??
        copy.defaultReason(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // Scrolls rather than overflows when a long server reason meets a
          // large text scale; the residual space stays top-aligned on the field.
          child: ListView(
            padding: _kBodyPadding,
            children: [
              // WHICH-blocked-state panel (D5). Glyph is danger-SOFT, never
              // full-strength `error` — R22's ruling, and §9 gates only that pair.
              Semantics(
                identifier: 'account_status_banner',
                container: true,
                child: JeebInfoNote.error(
                  icon: value == AccountStatusValue.locked
                      ? Icons.lock_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  iconColor: scheme.onErrorContainer,
                  title: copy.banner(value),
                ),
              ),
              const SizedBox(height: Spacing.small),
              // Reason — operator prose verbatim, else the localized lookup,
              // on R23's glass info strip.
              Semantics(
                identifier: 'account_status_reason',
                // Without container the id merges up into account_status_root
                // and is folded away (JM-049 merge class).
                container: true,
                child: JeebInfoNote.muted(label: _ReasonLine(reason: reason)),
              ),
            ],
          ),
        ),
        JeebCtaFooter.single(
          // EDGE → logout-delete-account (JM-062, AC3): opens the confirm sheet.
          // Neutral glass — R22 reserves the dim red for Delete account.
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
