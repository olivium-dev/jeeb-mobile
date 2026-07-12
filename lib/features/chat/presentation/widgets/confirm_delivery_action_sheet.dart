import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'delivery_confirm_illustration.dart';

/// Which delivery confirmation the sheet drives.
enum DeliveryConfirmKind {
  /// Jeeber confirms physically picking the order up (Figma node 56618:2751).
  picking,

  /// Jeeber confirms heading off to deliver (Figma node 56618:2852).
  headingOff,
}

/// Modal bottom sheet shown over the dimmed chat when the Jeeber confirms a
/// delivery state transition (picking the order / heading off).
///
/// Composed entirely from OMDS primitives + tokens: an M3 drag handle, the
/// shared [DeliveryConfirmIllustration], a navy title, a periwinkle subtitle,
/// and a navy [OmdsLoadingButton] Confirm CTA that shows a spinner while the
/// gateway call runs. The same shell renders both confirmations — only the
/// copy differs.
class ConfirmDeliveryActionSheet extends StatelessWidget {
  const ConfirmDeliveryActionSheet({
    super.key,
    required this.kind,
    required this.onConfirm,
    this.isConfirming = false,
  });

  final DeliveryConfirmKind kind;

  /// Fired when the Confirm CTA is tapped.
  final VoidCallback onConfirm;

  /// True while the heading-off / picking call is in flight.
  final bool isConfirming;

  /// Opens the sheet over the current route with a navy-tinted scrim. Returns
  /// the value popped by the sheet (`true` once confirmed), or null if
  /// dismissed.
  static Future<bool?> show(
    BuildContext context, {
    required DeliveryConfirmKind kind,
    required Future<void> Function() onConfirm,
  }) {
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
      builder: (sheetContext) => _ConfirmSheetHost(
        kind: kind,
        onConfirm: onConfirm,
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (kind) {
        DeliveryConfirmKind.picking => l10n.confirmPickingSheetTitle,
        DeliveryConfirmKind.headingOff => l10n.confirmHeadingOffSheetTitle,
      };

  String _subtitle(AppLocalizations l10n) => switch (kind) {
        DeliveryConfirmKind.picking => l10n.confirmPickingSheetSubtitle,
        DeliveryConfirmKind.headingOff => l10n.confirmHeadingOffSheetSubtitle,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'confirm_delivery_action_sheet',
      // explicitChildNodes keeps the drag handle, title, and Confirm CTA as
      // independent, id-addressable semantics nodes instead of letting the
      // framework collapse them into this container node (QA B1: Maestro could
      // only see `confirm_delivery_action_sheet`).
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
          child: _SheetContent(
            title: _title(l10n),
            subtitle: _subtitle(l10n),
            ctaLabel: l10n.confirmDeliveryActionCta,
            isConfirming: isConfirming,
            onConfirm: onConfirm,
          ),
        ),
      ),
    );
  }
}

/// Stateful host that flips the CTA into its loading state while the supplied
/// async [onConfirm] runs, then pops `true` on success.
class _ConfirmSheetHost extends StatefulWidget {
  const _ConfirmSheetHost({required this.kind, required this.onConfirm});

  final DeliveryConfirmKind kind;
  final Future<void> Function() onConfirm;

  @override
  State<_ConfirmSheetHost> createState() => _ConfirmSheetHostState();
}

class _ConfirmSheetHostState extends State<_ConfirmSheetHost> {
  bool _confirming = false;

  Future<void> _handleConfirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConfirmDeliveryActionSheet(
      kind: widget.kind,
      isConfirming: _confirming,
      onConfirm: _handleConfirm,
    );
  }
}

/// Vertical content stack: drag handle, illustration, text block, CTA.
class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.isConfirming,
    required this.onConfirm,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final bool isConfirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetDragHandle(),
        const SizedBox(height: Spacing.twoXLarge),
        const FractionallySizedBox(
          widthFactor: 0.62,
          child: DeliveryConfirmIllustration(),
        ),
        const SizedBox(height: Spacing.twoXLarge),
        _SheetTextBlock(title: title, subtitle: subtitle),
        const SizedBox(height: Spacing.twoXLarge),
        _SheetConfirmCta(
          label: ctaLabel,
          isConfirming: isConfirming,
          onConfirm: onConfirm,
        ),
      ],
    );
  }
}

/// Centered M3 drag handle (32×4 pill) tinted with the brand primary.
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Semantics(
        identifier: 'confirm_delivery_drag_handle',
        label: l10n.confirmDeliveryActionDragHandleA11y,
        child: Container(
          width: Spacing.twoXLarge,
          height: Spacing.twoXSmall,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: OmdsBorderRadius.pill,
          ),
        ),
      ),
    );
  }
}

/// Centered navy title + periwinkle subtitle.
class _SheetTextBlock extends StatelessWidget {
  const _SheetTextBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Semantics(
          identifier: 'confirm_delivery_title',
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.secondaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Semantics(
          identifier: 'confirm_delivery_subtitle',
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width navy Confirm CTA that spins while the action runs.
///
/// The `Semantics` node owns the tap action and is an explicit `container`
/// boundary — the same shape as the proven `ChatComposerIconButton`
/// (`chat_detail_send_button`), which Maestro can tap in flow 04. This makes
/// the CTA a standalone, id-addressable, tappable node rather than relying on
/// the inner [OmdsLoadingButton]'s bare `GestureDetector` semantics (QA B1).
class _SheetConfirmCta extends StatelessWidget {
  const _SheetConfirmCta({
    required this.label,
    required this.isConfirming,
    required this.onConfirm,
  });

  final String label;
  final bool isConfirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = !isConfirming;
    return Semantics(
      identifier: 'confirm_delivery_confirm_button',
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onConfirm : null,
      child: ExcludeSemantics(
        child: OmdsLoadingButton(
          key: const Key('confirm-delivery-confirm-button'),
          text: label,
          isLoading: isConfirming,
          onTap: onConfirm,
          backgroundColor: colorScheme.secondaryContainer,
          textColor: colorScheme.onPrimary,
          borderRadius: OmdsBorderRadius.uiSmall,
        ),
      ),
    );
  }
}
