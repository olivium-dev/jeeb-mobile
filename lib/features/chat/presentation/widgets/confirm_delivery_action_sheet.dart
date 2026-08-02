import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'delivery_confirm_illustration.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/confirm_delivery_action_sheet_preview_test.dart
// ===========================================================================

// Widget previews for [ConfirmDeliveryActionSheet] — run with
// `flutter widget-preview start`.
//
// The sheet carries no data: every string is localized copy resolved from the
// ARB and the illustration is a [CustomPainter], so there is no repository,
// cubit or image to fake. These previews are network-free because the widget
// has nothing to fetch, not merely because [jeebPreviewHost] guards it.
//
// Three things vary, and each one below exists for one of them:
//
// * **[DeliveryConfirmKind]** — the two Figma sheets (56618:2751 picking,
//   56618:2852 heading off) share a single shell and differ only in two
//   strings, so a miswired `switch` in `_title`/`_subtitle` is invisible until
//   both are rendered next to each other.
// * **`isConfirming`** — the gateway call in flight. The CTA label is replaced
//   by an indeterminate spinner and the tap target goes dead; that dead target
//   is the only thing stopping a double tap from firing the transition twice.
// * **The box.** Production never shows this widget the way the first previews
//   do. It shows it inside a modal bottom-sheet route: bottom-anchored, corners
//   rounded, over a navy scrim. `Modal presentation` renders that real framing
//   through [ConfirmDeliveryActionSheet.show]; the bare-widget previews keep
//   the content stack easy to inspect in isolation.
//
// Copy fixtures are the strings already pinned by `test/chat_dm_states_test.dart`
// ("Confirm Picking the order" / "Confirm Heading off" / "Help user track the
// order"), so preview and widget test stay comparable.
//
// **What the AR RTL dark rendering shows, and why it is not fixable here.**
// In dark mode the sheet's own colours fall below WCAG AA: the title is drawn
// in `colorScheme.secondaryContainer` (#444559) on `surface` (#131318) —
// **1.98:1** where large text needs 3:1 — and the Confirm CTA paints
// `onPrimary` (#252b61) on that same `secondaryContainer` fill, **1.40:1**.
// Both are role misuse rather than palette bugs: `secondaryContainer` is a
// container colour being used as an on-surface ink, and the label paired with
// a `secondaryContainer` fill is `onSecondaryContainer` (#e0e0f9), which would
// give 7.23:1. Light mode is fine (17.13:1 / 17.13:1), which is exactly why
// the dark rendering is in the matrix and not opt-in.

/// Phone width, and tall enough that the EN 200%-text rendering of the matrix
/// still fits.
///
/// Measured with the production Inter face at 390 pt wide: the picking sheet is
/// 357 pt tall at 1.0 and 537 pt at 200% (the title alone goes from one line to
/// three). A shorter box would paint overflow stripes that belong to the canvas
/// rather than to the widget — note that the same measurement taken in a widget
/// test reads ~120 pt taller, because `flutter test` substitutes a monospaced
/// test font whose glyphs are all one em wide.
const Size _confirmDeliveryActionSheetSheetBox = Size(390, 560);

/// The bare sheet, driven exactly as `chat_screen` drives it.
///
/// `onConfirm` is a no-op: the previews are for looking at the sheet, and the
/// production callback is an async gateway call that has no business running
/// here.
Widget _confirmDeliveryActionSheetSheet(DeliveryConfirmKind kind, {bool isConfirming = false}) =>
    ConfirmDeliveryActionSheet(
      kind: kind,
      isConfirming: isConfirming,
      onConfirm: () {},
    );

/// Figma 56618:2751 — the jeeber confirms the parcel is physically in hand.
///
/// The default reading, and the longer of the two titles. "Confirm Picking the
/// order" fits one line at 390 pt but takes THREE at 200% text, which is where
/// the 32 pt gaps around the text block start doing real work — check that the
/// title and subtitle still read as one block and have not run into the
/// illustration. The sentence-case "Picking the order" is copy as shipped, not
/// a typo to fix here.
@JeebPreview(group: 'chat', name: 'Picking · idle', size: _confirmDeliveryActionSheetSheetBox)
Widget confirmDeliveryActionSheetPicking() =>
    _confirmDeliveryActionSheetSheet(DeliveryConfirmKind.picking);

/// Figma 56618:2852 — the jeeber confirms they are setting off.
///
/// Worth its own preview precisely because it looks almost identical: the only
/// pixels that may differ are the title. If this ever renders "Confirm Picking
/// the order", the `switch` on [DeliveryConfirmKind] has collapsed and the
/// jeeber is being asked to confirm the wrong transition.
@JeebPreview(group: 'chat', name: 'Heading off · idle', size: _confirmDeliveryActionSheetSheetBox)
Widget confirmDeliveryActionSheetHeadingOff() =>
    _confirmDeliveryActionSheetSheet(DeliveryConfirmKind.headingOff);

/// The confirm call is in flight.
///
/// The CTA swaps its label for `OmdsButtonLoading`, and its `Semantics` node
/// drops to `enabled: false` with no tap action — the double-tap guard QA B1
/// asked for, made visible. Two things to check here that no widget test can:
/// the button keeps its 48 pt height across the label→spinner swap (it must not
/// jump, the swap is animated), and the spinner is actually visible. In the AR
/// RTL dark rendering it very nearly is not — the indicator inherits the CTA's
/// text colour against the fill dimmed to 60%, which is **1.03:1** there. See
/// the contrast note in the library doc above.
@JeebPreview(group: 'chat', name: 'Confirming · spinner', size: _confirmDeliveryActionSheetSheetBox)
Widget confirmDeliveryActionSheetConfirming() =>
    _confirmDeliveryActionSheetSheet(DeliveryConfirmKind.picking, isConfirming: true);

/// The narrowest phone the app supports (320 pt), pinned to that width by the
/// preview itself.
///
/// The pin is not decoration: the render tests pump an 800 px viewport and
/// ignore [JeebPreview.size], so this is the only state whose width is
/// guaranteed in CI as well as in the canvas.
///
/// 320 pt is where "Confirm Picking the order" stops fitting on one line
/// (measured: 64 pt of title here against 32 pt at 390 pt) and where the
/// illustration — sized as a *fraction* (0.62) of the sheet width rather than a
/// fixed box — shrinks with it. It is also the tightest case for the whole
/// sheet: 553 pt of content at 200% text against the 568 pt height of the
/// phone this width belongs to, i.e. 15 pt of scrim left. `_SheetContent` is a
/// plain [Column] with no scroll fallback, so anything that adds a bottom inset
/// from there is a hard overflow.
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
///
/// This is the only preview that exercises the production entry point — the
/// navy scrim, the `topXLarge` top corners, the bottom anchoring, and the
/// stateful `_ConfirmSheetHost` that flips the CTA into its loading state and
/// pops `true`. Everything above renders a shape production never ships: the
/// bare widget top-aligned on an opaque surface.
///
/// Tapping Confirm dismisses the sheet, because the host pops as soon as the
/// supplied future resolves — hot-restart the preview to bring it back.
@JeebPreview(group: 'chat', name: 'Modal presentation · heading off', size: Size(390, 700))
Widget confirmDeliveryActionSheetInModalRoute() =>
    _confirmDeliveryActionSheetModalPresentation(DeliveryConfirmKind.headingOff);

/// Hosts the sheet in a real modal route.
///
/// The local [Navigator] is what makes this self-contained: `show()` needs a
/// navigator to push onto, and a preview must not assume the canvas (or a test
/// harness) supplies one it can safely mutate.
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
    // same sequencing `dev_chat_preview_screen.dart` uses for its auto-opened
    // sheets.
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
///
/// Deliberately text-free, so every string a preview test pins can only have
/// come from the sheet itself.
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
