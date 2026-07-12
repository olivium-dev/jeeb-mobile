import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/dio_account_session_terminator.dart';
import '../../domain/account_deletion_policy.dart';
import '../../domain/account_session_terminator.dart';

/// Which terminal action the [LogoutDeleteConfirmSheet] confirms.
enum LogoutDeleteMode {
  /// Sign out — revoke the gateway session + clear the local keystore.
  logout,

  /// Delete account — queue `status → deleted` (D5) + clear the local keystore.
  delete,

  /// Both terminal actions on one sheet (the JM-062 profile-row + account-status
  /// entry): renders BOTH `logout_confirm_cta` and `delete_confirm_cta`. The
  /// flow (jm-062 AC1) asserts both are present, then taps one.
  both,
}

/// `logout-delete-account` (JM-062, blueprint `logout-delete-account`).
///
/// The confirm surface for both terminal account actions. It is a **sheet, not
/// a route** (40_GUARDRAILS_ARCH §5 — sheets are `showModalBottomSheet`, mirrors
/// `CancelRequestSheet` / `OfferAcceptSheet`). It is hosted by
/// `SettingsScreen._AccountSection` (the JM-062 target) and is reachable from
/// `account-status` (JM-066) — the `account_status_signout_cta` routes to
/// `/settings`, whose Account section opens this sheet.
///
/// On confirm both modes converge on the SAME load-bearing outcome the JM-062 AC
/// requires: the local session is cleared (keystore tokens dropped via
/// [AccountSessionTerminator]) so the router's first-run gate flips to
/// unauthenticated, then `context.go('/')` lands on splash → `/login` (D5).
/// The gateway calls (`POST /v1/auth/logout`, `POST /v1/devices/unregister`,
/// delete) are best-effort inside the terminator — they never block the clear.
///
/// Semantics identifiers exposed (EXACT, 30_BACKLOG JM-062 AC):
///   - `logout_delete_confirm_sheet` — bottom-sheet root (signature id)
///   - `logout_confirm_cta`          — confirm the logout (logout mode)
///   - `delete_confirm_cta`          — confirm the deletion (delete mode)
///   - `logout_delete_cancel_cta`    — dismiss the sheet (keep the session)
class LogoutDeleteConfirmSheet extends StatefulWidget {
  const LogoutDeleteConfirmSheet({
    super.key,
    required this.mode,
    this.terminator,
    this.onCompleted,
    this.onCancelled,
  });

  /// Which terminal action this sheet confirms (logout vs delete).
  final LogoutDeleteMode mode;

  /// Optional terminator override. Production builds leave this null and the
  /// sheet self-provides a [DioAccountSessionTerminator] over `sl<Dio>()` +
  /// `sl<AuthTokenStore>()` (40_GUARDRAILS_ARCH §5.4 — screen self-provides;
  /// no `injection_container.dart` edit). Widget tests inject a scripted fake.
  final AccountSessionTerminator? terminator;

  /// Fired after the session has been cleared. [show] wires the default
  /// (`pop` the sheet + `context.go('/')` → splash); an explicit callback is for
  /// tests so they can assert the side effect without a router.
  final VoidCallback? onCompleted;

  /// Fired when the user dismisses without confirming. [show] wires `pop`.
  final VoidCallback? onCancelled;

  /// Opens the confirm sheet over the current route with the standard OMDS
  /// top-rounded shape + dimmed scrim. Returns `true` once the session is
  /// cleared (the caller's route is torn down by `go('/')`), `false`/`null` when
  /// dismissed.
  static Future<bool?> show(
    BuildContext context, {
    required LogoutDeleteMode mode,
    AccountSessionTerminator? terminator,
  }) {
    final rootContext = context;
    // Capture the session cubit BEFORE the sheet's own context: it lives at the
    // app root (provided by `app.dart`), and reading it after `go('/')` (which
    // tears the sheet down) would be unsafe.
    final session = rootContext.read<SessionCubit?>();
    final scrim = Theme.of(context)
        .colorScheme
        .onSecondaryContainer
        .withValues(alpha: UIConstants.opacityHigh);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => LogoutDeleteConfirmSheet(
        mode: mode,
        terminator: terminator,
        // EDGE (JM-062 AC, D5): on confirm the local session is already cleared
        // by the time this fires; refresh the SessionCubit so the router gate
        // re-reads the (now empty) keystore, then `go('/')` → first-run gate →
        // splash → `/login`. Pop the sheet FIRST so the destination's id is the
        // only thing on screen for Maestro.
        onCompleted: () async {
          Navigator.of(sheetContext).pop(true);
          await session?.refresh();
          if (rootContext.mounted) rootContext.go('/');
        },
        onCancelled: () => Navigator.of(sheetContext).pop(false),
      ),
    );
  }

  @override
  State<LogoutDeleteConfirmSheet> createState() =>
      _LogoutDeleteConfirmSheetState();
}

class _LogoutDeleteConfirmSheetState extends State<LogoutDeleteConfirmSheet> {
  late final AccountSessionTerminator _terminator = _resolveTerminator();
  bool _inFlight = false;

  AccountSessionTerminator _resolveTerminator() {
    final explicit = widget.terminator;
    if (explicit != null) return explicit;
    // S6 Stream C: prefer the DI-registered terminator (the canonical release
    // default) when DI is configured; the self-provide below is the no-DI seam.
    if (sl.isRegistered<AccountSessionTerminator>()) {
      return sl<AccountSessionTerminator>();
    }
    // Self-provide over the shared gateway Dio + keystore. resolveGatewayDio()
    // returns the registered singleton when DI is configured and otherwise
    // mirrors the AppConfig selection (a dev-seam / deep-link entry before the
    // DI batch lands) so the sheet never crashes.
    final dio = resolveGatewayDio();
    final tokenStore =
        sl.isRegistered<AuthTokenStore>() ? sl<AuthTokenStore>() : AuthTokenStore();
    return DioAccountSessionTerminator(dio, tokenStore);
  }

  Future<void> _run(LogoutDeleteMode action) async {
    if (_inFlight) return;
    setState(() => _inFlight = true);
    // The terminator is fail-safe (never throws): the gateway calls are
    // best-effort and the local keystore clear always runs (D5).
    switch (action) {
      case LogoutDeleteMode.delete:
        await _terminator.deleteAccount();
      case LogoutDeleteMode.logout:
      case LogoutDeleteMode.both:
        await _terminator.logout();
    }
    if (!mounted) return;
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDelete = widget.mode == LogoutDeleteMode.delete;
    final isBoth = widget.mode == LogoutDeleteMode.both;

    final title =
        isDelete ? l10n.accountDeleteDialogTitle : l10n.signOutDialogTitle;
    final body = isDelete
        ? l10n.accountDeleteDialogBody(kAccountPurgeGraceDays)
        : l10n.signOutDialogBody;

    // Build the confirm CTA(s). For [both] we render the logout CTA then the
    // delete CTA so the flow can assert (and tap) either by id.
    final confirmCtas = <Widget>[
      if (!isDelete)
        _confirmCta(
          theme,
          id: 'logout_confirm_cta',
          buttonKey: const Key('logout-confirm-cta'),
          text: l10n.appBarSignOut,
          onTap: () => _run(LogoutDeleteMode.logout),
        ),
      if (isBoth) const SizedBox(height: Spacing.small),
      if (isDelete || isBoth)
        _confirmCta(
          theme,
          id: 'delete_confirm_cta',
          buttonKey: const Key('delete-confirm-cta'),
          text: l10n.accountDeleteConfirm,
          onTap: () => _run(LogoutDeleteMode.delete),
        ),
    ];

    return Semantics(
      // JM-062/066 flows assert `logout_delete_sheet`; the unit test asserts the
      // legacy `logout_delete_confirm_sheet`. Nest both so neither regresses.
      identifier: 'logout_delete_sheet',
      explicitChildNodes: true,
      child: Semantics(
        identifier: 'logout_delete_confirm_sheet',
        explicitChildNodes: true,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.small,
              Spacing.xLarge,
              Spacing.xLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetDragHandle(),
                const SizedBox(height: Spacing.large),
                Icon(
                  isDelete ? Icons.delete_outline : Icons.logout,
                  size: Sizes.sixXLarge,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: Spacing.medium),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Spacing.medium),
                // Warning copy (lofiOutline: "irreversibility / role suspension
                // implications" for delete; "sign in again" for logout).
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.twoXLarge),
                ...confirmCtas,
                const SizedBox(height: Spacing.small),
                // logout_delete_cancel_cta — dismiss, keep the session. Inert
                // while a confirm is in flight so it can't tear down mid-clear.
                Semantics(
                  identifier: 'logout_delete_cancel_cta',
                  container: true,
                  button: true,
                  enabled: !_inFlight,
                  label: l10n.actionCancel,
                  onTap: _inFlight ? null : widget.onCancelled,
                  child: ExcludeSemantics(
                    child: OMDSOutlinedButton(
                      key: const Key('logout-delete-cancel-cta'),
                      text: l10n.actionCancel,
                      enabled: !_inFlight,
                      onTap: () => widget.onCancelled?.call(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A confirm CTA — confirm → session cleared → splash (D5). Disabled + spinner
  /// while in flight so it can't double-fire the clear.
  Widget _confirmCta(
    ThemeData theme, {
    required String id,
    required Key buttonKey,
    required String text,
    required VoidCallback onTap,
  }) {
    return Semantics(
      identifier: id,
      container: true,
      button: true,
      enabled: !_inFlight,
      label: text,
      onTap: _inFlight ? null : onTap,
      child: ExcludeSemantics(
        child: OmdsLoadingButton(
          key: buttonKey,
          text: text,
          isLoading: _inFlight,
          isEnabled: !_inFlight,
          onTap: onTap,
          backgroundColor: theme.colorScheme.error,
          textColor: theme.colorScheme.onError,
          borderRadius: OmdsBorderRadius.uiSmall,
        ),
      ),
    );
  }
}

/// Centered M3 drag handle (32×4 pill) tinted with the brand primary — matches
/// the shared sheet handle styling used across the app's bottom sheets
/// (mirrors `CancelRequestSheet._SheetDragHandle`).
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}
