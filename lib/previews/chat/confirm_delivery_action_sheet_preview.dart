/// Widget previews for [ConfirmDeliveryActionSheet] — run with
/// `flutter widget-preview start`.
///
/// The sheet carries no data: every string is localized copy resolved from the
/// ARB and the illustration is a [CustomPainter], so there is no repository,
/// cubit or image to fake. These previews are network-free because the widget
/// has nothing to fetch, not merely because [jeebPreviewHost] guards it.
///
/// Three things vary, and each one below exists for one of them:
///
/// * **[DeliveryConfirmKind]** — the two Figma sheets (56618:2751 picking,
///   56618:2852 heading off) share a single shell and differ only in two
///   strings, so a miswired `switch` in `_title`/`_subtitle` is invisible until
///   both are rendered next to each other.
/// * **`isConfirming`** — the gateway call in flight. The CTA label is replaced
///   by an indeterminate spinner and the tap target goes dead; that dead target
///   is the only thing stopping a double tap from firing the transition twice.
/// * **The box.** Production never shows this widget the way the first previews
///   do. It shows it inside a modal bottom-sheet route: bottom-anchored, corners
///   rounded, over a navy scrim. `Modal presentation` renders that real framing
///   through [ConfirmDeliveryActionSheet.show]; the bare-widget previews keep
///   the content stack easy to inspect in isolation.
///
/// Copy fixtures are the strings already pinned by `test/chat_dm_states_test.dart`
/// ("Confirm Picking the order" / "Confirm Heading off" / "Help user track the
/// order"), so preview and widget test stay comparable.
///
/// **What the AR RTL dark rendering shows, and why it is not fixable here.**
/// In dark mode the sheet's own colours fall below WCAG AA: the title is drawn
/// in `colorScheme.secondaryContainer` (#444559) on `surface` (#131318) —
/// **1.98:1** where large text needs 3:1 — and the Confirm CTA paints
/// `onPrimary` (#252b61) on that same `secondaryContainer` fill, **1.40:1**.
/// Both are role misuse rather than palette bugs: `secondaryContainer` is a
/// container colour being used as an on-surface ink, and the label paired with
/// a `secondaryContainer` fill is `onSecondaryContainer` (#e0e0f9), which would
/// give 7.23:1. Light mode is fine (17.13:1 / 17.13:1), which is exactly why
/// the dark rendering is in the matrix and not opt-in.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/chat/presentation/widgets/confirm_delivery_action_sheet.dart';

/// Phone width, and tall enough that the EN 200%-text rendering of the matrix
/// still fits.
///
/// Measured with the production Inter face at 390 pt wide: the picking sheet is
/// 357 pt tall at 1.0 and 537 pt at 200% (the title alone goes from one line to
/// three). A shorter box would paint overflow stripes that belong to the canvas
/// rather than to the widget — note that the same measurement taken in a widget
/// test reads ~120 pt taller, because `flutter test` substitutes a monospaced
/// test font whose glyphs are all one em wide.
const Size _sheetBox = Size(390, 560);

/// The bare sheet, driven exactly as `chat_screen` drives it.
///
/// `onConfirm` is a no-op: the previews are for looking at the sheet, and the
/// production callback is an async gateway call that has no business running
/// here.
Widget _sheet(DeliveryConfirmKind kind, {bool isConfirming = false}) =>
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
@JeebPreview(name: 'Picking · idle', size: _sheetBox)
Widget confirmDeliveryActionSheetPicking() =>
    _sheet(DeliveryConfirmKind.picking);

/// Figma 56618:2852 — the jeeber confirms they are setting off.
///
/// Worth its own preview precisely because it looks almost identical: the only
/// pixels that may differ are the title. If this ever renders "Confirm Picking
/// the order", the `switch` on [DeliveryConfirmKind] has collapsed and the
/// jeeber is being asked to confirm the wrong transition.
@JeebPreview(name: 'Heading off · idle', size: _sheetBox)
Widget confirmDeliveryActionSheetHeadingOff() =>
    _sheet(DeliveryConfirmKind.headingOff);

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
@JeebPreview(name: 'Confirming · spinner', size: _sheetBox)
Widget confirmDeliveryActionSheetConfirming() =>
    _sheet(DeliveryConfirmKind.picking, isConfirming: true);

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
@JeebPreview(name: 'Narrow phone · 320 pt', size: Size(320, 560))
Widget confirmDeliveryActionSheetNarrowPhone() => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 320,
        child: _sheet(DeliveryConfirmKind.picking),
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
@JeebPreview(name: 'Modal presentation · heading off', size: Size(390, 700))
Widget confirmDeliveryActionSheetInModalRoute() =>
    _modalPresentation(DeliveryConfirmKind.headingOff);

/// Hosts the sheet in a real modal route.
///
/// The local [Navigator] is what makes this self-contained: `show()` needs a
/// navigator to push onto, and a preview must not assume the canvas (or a test
/// harness) supplies one it can safely mutate.
Widget _modalPresentation(DeliveryConfirmKind kind) => Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _SheetOverChat(kind: kind),
      ),
    );

/// Opens the sheet over [_ChatBackdrop] on the first frame.
class _SheetOverChat extends StatefulWidget {
  const _SheetOverChat({required this.kind});

  final DeliveryConfirmKind kind;

  @override
  State<_SheetOverChat> createState() => _SheetOverChatState();
}

class _SheetOverChatState extends State<_SheetOverChat> {
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
  Widget build(BuildContext context) => const _ChatBackdrop();
}

/// A neutral stand-in for the chat thread behind the sheet — enough shape to
/// judge the scrim against.
///
/// Deliberately text-free, so every string a preview test pins can only have
/// come from the sheet itself.
class _ChatBackdrop extends StatelessWidget {
  const _ChatBackdrop();

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
