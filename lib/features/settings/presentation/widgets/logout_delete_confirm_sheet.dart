import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/jeeb_scrim.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/dio_account_session_terminator.dart';
import '../../domain/account_deletion_policy.dart';
import '../../domain/account_session_terminator.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../../core/previews/jeeb_preview.dart';

enum LogoutDeleteMode {
  logout,

  delete,

  both,
}

class LogoutDeleteConfirmSheet extends StatefulWidget {
  const LogoutDeleteConfirmSheet({
    super.key,
    required this.mode,
    this.terminator,
    this.onCompleted,
    this.onCancelled,
  });

  final LogoutDeleteMode mode;

  final AccountSessionTerminator? terminator;

  final VoidCallback? onCompleted;

  final VoidCallback? onCancelled;

  static Future<bool?> show(
    BuildContext context, {
    required LogoutDeleteMode mode,
    AccountSessionTerminator? terminator,
  }) {
    final rootContext = context;
    final session = rootContext.read<SessionCubit?>();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: JeebScrim.barrier(context),
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => LogoutDeleteConfirmSheet(
        mode: mode,
        terminator: terminator,
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
    if (sl.isRegistered<AccountSessionTerminator>()) {
      return sl<AccountSessionTerminator>();
    }
    final dio = resolveGatewayDio();
    final tokenStore =
        sl.isRegistered<AuthTokenStore>() ? sl<AuthTokenStore>() : AuthTokenStore();
    return DioAccountSessionTerminator(dio, tokenStore);
  }

  Future<void> _run(LogoutDeleteMode action) async {
    if (_inFlight) return;
    setState(() => _inFlight = true);
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

    final confirmCtas = <Widget>[
      if (!isDelete)
        _confirmCta(
          theme,
          semanticsIdentifier: 'logout_confirm_cta',
          buttonKey: const Key('logout-confirm-cta'),
          text: l10n.appBarSignOut,
          onTap: () => _run(LogoutDeleteMode.logout),
        ),
      if (isBoth) const SizedBox(height: Spacing.small),
      if (isDelete || isBoth)
        _confirmCta(
          theme,
          semanticsIdentifier: 'delete_confirm_cta',
          buttonKey: const Key('delete-confirm-cta'),
          text: l10n.accountDeleteConfirm,
          onTap: () => _run(LogoutDeleteMode.delete),
        ),
    ];

    return Semantics(
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

  Widget _confirmCta(
    ThemeData theme, {
    required String semanticsIdentifier,
    required Key buttonKey,
    required String text,
    required VoidCallback onTap,
  }) {
    return Semantics(
      identifier: semanticsIdentifier,
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

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    // MIDNIGHT: `primary` IS #D73B00, so this grabber was painting a bright
    // orange bar over the sign-out sheet. Inert chrome takes the .22 rung.
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: semantics.glassBorderVivid,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width with room for the logout stack (handle → 64 pt icon → title →
/// one-sentence body → 48 pt confirm → 48 pt cancel), measured at 368 pt EN /
const Size _logoutDeleteConfirmSheetBox = Size(390, 460);

/// The JM-062 profile-row sheet, which carries a second 48 pt CTA — 428 pt EN /
/// 452 pt AR.
const Size _logoutDeleteConfirmSheetBothBox = Size(390, 500);

/// The delete stack, whose three-sentence purge warning is the longest copy this
/// widget can be asked to lay out — 512 pt EN.
const Size _logoutDeleteConfirmSheetDeleteBox = Size(390, 560);

/// The narrowest phone the app supports, and the taller box its extra wrapping
/// needs — `both` reaches 472 pt at 100% here.
const Size _logoutDeleteConfirmSheetNarrowBox = Size(320, 520);

/// Width of the smallest supported phone (iPhone SE 1st gen class).
const double _logoutDeleteConfirmSheetSmallPhoneWidth = 320;

/// A terminator with no transport, no keystore and no side effect.
/// Both methods resolve immediately, which is what the real one does after a
/// successful clear — so a confirm tap in the canvas runs the same code path
class _LogoutDeleteConfirmSheetInertTerminator
    implements AccountSessionTerminator {
  const _LogoutDeleteConfirmSheetInertTerminator();

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

/// A terminator whose calls never resolve, so the sheet stays `_inFlight`
/// forever and the spinner state can be *looked at* instead of caught in a
/// single frame.
class _LogoutDeleteConfirmSheetHangingTerminator
    implements AccountSessionTerminator {
  const _LogoutDeleteConfirmSheetHangingTerminator();

  @override
  Future<void> logout() => Completer<void>().future;

  @override
  Future<void> deleteAccount() => Completer<void>().future;
}

/// Fires a confirm CTA on the first frame, so a state that only exists *after* a
/// tap can be reviewed as a static preview.
/// It walks the element tree for the [OmdsLoadingButton] carrying [buttonKey]
class _LogoutDeleteConfirmSheetAutoConfirm extends StatefulWidget {
  const _LogoutDeleteConfirmSheetAutoConfirm({
    required this.buttonKey,
    required this.child,
  });

  /// Key of the [OmdsLoadingButton] to fire (`logout-confirm-cta` /
  /// `delete-confirm-cta`).
  final Key buttonKey;

  final Widget child;

  @override
  State<_LogoutDeleteConfirmSheetAutoConfirm> createState() =>
      _LogoutDeleteConfirmSheetAutoConfirmState();
}

class _LogoutDeleteConfirmSheetAutoConfirmState
    extends State<_LogoutDeleteConfirmSheetAutoConfirm> {
  @override
  void initState() {
    super.initState();
    // Post-frame, because the button has to exist before it can be found — the
    WidgetsBinding.instance.addPostFrameCallback((_) => _fire());
  }

  void _fire() {
    if (!mounted) return;
    OmdsLoadingButton? target;
    void visit(Element element) {
      if (target != null) return;
      final Widget widget = element.widget;
      if (widget is OmdsLoadingButton && widget.key == this.widget.buttonKey) {
        target = widget;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    target?.onTap();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Mounts the sheet the way `showModalBottomSheet` presents it — bottom-anchored
/// content on the surface colour — without needing a [Navigator] to push onto.
Widget _logoutDeleteConfirmSheetHosted(
  LogoutDeleteMode mode, {
  double width = 390,
  AccountSessionTerminator terminator =
      const _LogoutDeleteConfirmSheetInertTerminator(),
  Key? confirmKey,
}) {
  final Widget sheet = Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(
      width: width,
      child: LogoutDeleteConfirmSheet(
        mode: mode,
        terminator: terminator,
        // No-ops on purpose. Production pops the sheet, refreshes SessionCubit
        onCompleted: () {},
        onCancelled: () {},
      ),
    ),
  );
  if (confirmKey == null) return sheet;
  return _LogoutDeleteConfirmSheetAutoConfirm(
    buttonKey: confirmKey,
    child: sheet,
  );
}

/// The default reading: `LogoutDeleteMode.logout`, the sheet the Settings
/// Account section opens and the one `account_status_signout_cta` (JM-066)
@JeebPreview(
  group: 'settings',
  name: 'Sign out',
  size: _logoutDeleteConfirmSheetBox,
)
Widget logoutDeleteConfirmSheetLogout() =>
    _logoutDeleteConfirmSheetHosted(LogoutDeleteMode.logout);

/// `LogoutDeleteMode.delete` — the irreversible half, and the longest copy the
/// sheet can render.
@JeebPreview(
  group: 'settings',
  name: 'Delete account',
  size: _logoutDeleteConfirmSheetDeleteBox,
)
Widget logoutDeleteConfirmSheetDelete() =>
    _logoutDeleteConfirmSheetHosted(LogoutDeleteMode.delete);

/// `LogoutDeleteMode.both` — the JM-062 profile-row entry, which puts both
/// terminal actions on one sheet.
@JeebPreview(
  group: 'settings',
  name: 'Sign out + delete',
  size: _logoutDeleteConfirmSheetBothBox,
)
Widget logoutDeleteConfirmSheetBoth() =>
    _logoutDeleteConfirmSheetHosted(LogoutDeleteMode.both);

/// The clear in flight — the double-fire guard, made visible, and the one state
/// no widget test in this repo renders.
@JeebPreview(
  group: 'settings',
  name: 'Clearing session',
  size: _logoutDeleteConfirmSheetBothBox,
)
Widget logoutDeleteConfirmSheetInFlight() => _logoutDeleteConfirmSheetHosted(
      LogoutDeleteMode.both,
      terminator: const _LogoutDeleteConfirmSheetHangingTerminator(),
      confirmKey: const Key('logout-confirm-cta'),
    );

/// `both` at 320 pt — the narrowest phone, and the width ceiling for the CTAs.
/// The `OmdsLoadingButton` pill is a FIXED 48 pt (`Sizes.fourXLarge`) at every
@JeebPreview(
  group: 'settings',
  name: 'Narrow phone · 320 pt',
  size: _logoutDeleteConfirmSheetNarrowBox,
)
Widget logoutDeleteConfirmSheetNarrowPhone() => _logoutDeleteConfirmSheetHosted(
      LogoutDeleteMode.both,
      width: _logoutDeleteConfirmSheetSmallPhoneWidth,
    );
