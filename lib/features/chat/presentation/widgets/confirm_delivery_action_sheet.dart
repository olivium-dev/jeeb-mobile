import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'delivery_confirm_illustration.dart';

import '../../../../core/previews/jeeb_preview.dart';

enum DeliveryConfirmKind {
  picking,
  headingOff,
}

class ConfirmDeliveryActionSheet extends StatelessWidget {
  const ConfirmDeliveryActionSheet({
    super.key,
    required this.kind,
    required this.onConfirm,
    this.isConfirming = false,
  });

  final DeliveryConfirmKind kind;
  final VoidCallback onConfirm;
  final bool isConfirming;

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
              color: theme.colorScheme.primary,
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

/// Semantics node required for QA B1 (Maestro testing).
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [ConfirmDeliveryActionSheet] — run with

/// Phone width, and tall enough that the EN 200%-text rendering of the matrix
/// still fits.
const Size _confirmDeliveryActionSheetSheetBox = Size(390, 560);

/// The bare sheet, driven exactly as `chat_screen` drives it.
/// `onConfirm` is a no-op: the previews are for looking at the sheet, and the
Widget _confirmDeliveryActionSheetSheet(DeliveryConfirmKind kind, {bool isConfirming = false}) =>
    ConfirmDeliveryActionSheet(
      kind: kind,
      isConfirming: isConfirming,
      onConfirm: () {},
    );

/// Figma 56618:2751 — the jeeber confirms the parcel is physically in hand.
/// The default reading, and the longer of the two titles. "Confirm Picking the
@JeebPreview(group: 'chat', name: 'Picking · idle', size: _confirmDeliveryActionSheetSheetBox)
Widget confirmDeliveryActionSheetPicking() =>
    _confirmDeliveryActionSheetSheet(DeliveryConfirmKind.picking);

/// Figma 56618:2852 — the jeeber confirms they are setting off.
/// Worth its own preview precisely because it looks almost identical: the only
@JeebPreview(group: 'chat', name: 'Heading off · idle', size: _confirmDeliveryActionSheetSheetBox)
Widget confirmDeliveryActionSheetHeadingOff() =>
    _confirmDeliveryActionSheetSheet(DeliveryConfirmKind.headingOff);

/// The confirm call is in flight.
/// The CTA swaps its label for `OmdsButtonLoading`, and its `Semantics` node
@JeebPreview(group: 'chat', name: 'Confirming · spinner', size: _confirmDeliveryActionSheetSheetBox)
Widget confirmDeliveryActionSheetConfirming() =>
    _confirmDeliveryActionSheetSheet(DeliveryConfirmKind.picking, isConfirming: true);

/// The narrowest phone the app supports (320 pt), pinned to that width by the
/// preview itself.
@JeebPreview(group: 'chat', name: 'Narrow phone · 320 pt', size: Size(320, 560))
Widget confirmDeliveryActionSheetNarrowPhone() => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 320,
        child: _confirmDeliveryActionSheetSheet(DeliveryConfirmKind.picking),
      ),
    );

/// The sheet as the jeeber actually meets it: pushed by
/// [ConfirmDeliveryActionSheet.show] over the dimmed chat.
@JeebPreview(group: 'chat', name: 'Modal presentation · heading off', size: Size(390, 700))
Widget confirmDeliveryActionSheetInModalRoute() =>
    _confirmDeliveryActionSheetModalPresentation(DeliveryConfirmKind.headingOff);

/// Hosts the sheet in a real modal route.
/// The local [Navigator] is what makes this self-contained: `show()` needs a
Widget _confirmDeliveryActionSheetModalPresentation(DeliveryConfirmKind kind) => Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _ConfirmDeliveryActionSheetSheetOverChat(kind: kind),
      ),
    );

/// Opens the sheet over [_ConfirmDeliveryActionSheetChatBackdrop] on the first frame.
class _ConfirmDeliveryActionSheetSheetOverChat extends StatefulWidget {
  const _ConfirmDeliveryActionSheetSheetOverChat({required this.kind});

  final DeliveryConfirmKind kind;

  @override
  State<_ConfirmDeliveryActionSheetSheetOverChat> createState() => _ConfirmDeliveryActionSheetSheetOverChatState();
}

class _ConfirmDeliveryActionSheetSheetOverChatState extends State<_ConfirmDeliveryActionSheetSheetOverChat> {
  @override
  void initState() {
    super.initState();
    // Post-frame, because `show()` needs a mounted route to push onto — the
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    await ConfirmDeliveryActionSheet.show(
      context,
      kind: widget.kind,
      // Resolves immediately: no gateway, no delay, no network.
      onConfirm: () async {},
    );
  }

  @override
  Widget build(BuildContext context) => const _ConfirmDeliveryActionSheetChatBackdrop();
}

/// A neutral stand-in for the chat thread behind the sheet — enough shape to
/// judge the scrim against.
/// Deliberately text-free, so every string a preview test pins can only have
class _ConfirmDeliveryActionSheetChatBackdrop extends StatelessWidget {
  const _ConfirmDeliveryActionSheetChatBackdrop();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _bubble(colors, width: 210, incoming: true),
            _bubble(colors, width: 150, incoming: false),
            _bubble(colors, width: 240, incoming: true),
          ],
        ),
      ),
    );
  }

  /// One placeholder bubble. [AlignmentDirectional] rather than [Alignment] so
  /// the fake thread mirrors in the AR rendering like the real one does.
  Widget _bubble(
    ColorScheme colors, {
    required double width,
    required bool incoming,
  }) =>
      Container(
        alignment: incoming
            ? AlignmentDirectional.centerStart
            : AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: width,
          height: 44,
          decoration: BoxDecoration(
            color: incoming
                ? colors.surfaceContainerHighest
                : colors.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}
