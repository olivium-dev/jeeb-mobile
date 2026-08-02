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
