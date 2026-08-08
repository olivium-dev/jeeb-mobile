import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_scrim.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_cubit.dart';

/// Destructive confirm ceremony for "Unregister as Jeeber" (F3), mirroring
/// [LogoutDeleteConfirmSheet]'s shape (drag handle, icon, title, body,
/// destructive CTA, cancel CTA).
///
/// Unlike that sheet, this one is outcome-aware: it never assumes success.
/// The confirm CTA awaits [SettingsCubit.unregisterAsJeeber] and then always
/// closes — the resulting banner (done / blocked / "temporarily
/// unavailable" on a 502) is rendered by the Settings screen's existing
/// banner→snackbar listener, so a dark backend never reads as a fake success.
class UnregisterJeeberConfirmSheet extends StatefulWidget {
  const UnregisterJeeberConfirmSheet({
    super.key,
    required this.cubit,
    this.onCompleted,
    this.onCancelled,
  });

  final SettingsCubit cubit;

  /// Test seam, mirroring [LogoutDeleteConfirmSheet]: [show] wires these to
  /// `Navigator.pop`; a widget test can supply plain callbacks instead and
  /// mount the sheet directly, with no modal route required.
  final VoidCallback? onCompleted;
  final VoidCallback? onCancelled;

  static Future<bool?> show(
    BuildContext context, {
    required SettingsCubit cubit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: JeebScrim.barrier(context),
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => UnregisterJeeberConfirmSheet(
        cubit: cubit,
        onCompleted: () => Navigator.of(sheetContext).pop(true),
        onCancelled: () => Navigator.of(sheetContext).pop(false),
      ),
    );
  }

  @override
  State<UnregisterJeeberConfirmSheet> createState() =>
      _UnregisterJeeberConfirmSheetState();
}

class _UnregisterJeeberConfirmSheetState
    extends State<UnregisterJeeberConfirmSheet> {
  bool _inFlight = false;

  Future<void> _confirm() async {
    if (_inFlight) return;
    setState(() => _inFlight = true);
    await widget.cubit.unregisterAsJeeber();
    if (!mounted) return;
    widget.onCompleted?.call();
  }

  void _cancel() {
    if (_inFlight) return;
    widget.onCancelled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      identifier: 'unregister_jeeber_confirm_sheet',
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
                Icons.person_remove_outlined,
                size: Sizes.sixXLarge,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: Spacing.medium),
              Text(
                l10n.unregisterJeeberDialogTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Spacing.medium),
              Text(
                l10n.unregisterJeeberDialogBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.twoXLarge),
              Semantics(
                identifier: 'unregister_jeeber_confirm_cta',
                container: true,
                button: true,
                enabled: !_inFlight,
                label: l10n.unregisterJeeberConfirmCta,
                onTap: _inFlight ? null : _confirm,
                child: ExcludeSemantics(
                  child: OmdsLoadingButton(
                    key: const Key('unregister-jeeber-confirm-cta'),
                    text: l10n.unregisterJeeberConfirmCta,
                    isLoading: _inFlight,
                    isEnabled: !_inFlight,
                    onTap: _confirm,
                    backgroundColor: theme.colorScheme.error,
                    textColor: theme.colorScheme.onError,
                    borderRadius: OmdsBorderRadius.uiSmall,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'unregister_jeeber_cancel_cta',
                container: true,
                button: true,
                enabled: !_inFlight,
                label: l10n.actionCancel,
                onTap: _inFlight ? null : _cancel,
                child: ExcludeSemantics(
                  child: OMDSOutlinedButton(
                    key: const Key('unregister-jeeber-cancel-cta'),
                    text: l10n.actionCancel,
                    enabled: !_inFlight,
                    onTap: _cancel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
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
