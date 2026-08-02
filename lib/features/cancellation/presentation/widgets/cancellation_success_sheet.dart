import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/cancellation_result.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Bottom sheet after success. OmdsBottomSheet lacks scroll-safe body layout.
class CancellationSuccessSheet extends StatelessWidget {
  const CancellationSuccessSheet({
    super.key,
    required this.result,
    required this.onDone,
  });

  final CancellationResult result;
  final VoidCallback onDone;

  static Future<void> show({
    required BuildContext context,
    required CancellationResult result,
    required VoidCallback onDone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.large),
        ),
      ),
      builder: (_) => CancellationSuccessSheet(
        result: result,
        onDone: onDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SuccessIcon(),
            const SizedBox(height: Spacing.medium),
            _SuccessTitle(text: l10n.cancellationSuccess),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'cancellation_sheet_done_cta',
              container: true,
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.actionDone,
                onTap: onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check_circle_outline,
      size: 56,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

class _SuccessTitle extends StatelessWidget {
  const _SuccessTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge,
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
// Render tests:
// test/previews/cancellation/cancellation_success_sheet_preview_test.dart
// ===========================================================================
//
// Widget previews for [CancellationSuccessSheet] — run with
// `flutter widget-preview start`.
//
// This is the last surface a user sees after cancelling a delivery
// (T-MOB-024): `CancellationScreen` listens for `CancellationSuccess` and
// hands the gateway's [CancellationResult] to
// `CancellationSuccessSheet.show()`.
//
// **Network-free by construction.** The sheet takes no repository, no cubit and
// no seam — it is a [StatelessWidget] over a value object and a callback. Every
// preview below builds that value object inline, so there is nothing to fetch
// and nothing for [jeebPreviewHost]'s guard to catch.
//
// **What the preview set is actually about.** The sheet's `build` never reads
// `result`. Icon, title and CTA are the same three widgets for every possible
// [CancellationResult], so its "states" are not payload states — they are one
// rendering, plus the geometry it is handed. The set below therefore covers
// both halves honestly:
//
//  * three DIFFERENT payloads that the sheet renders IDENTICALLY
//    ([cancellationSuccessSheetCancelled],
//    [cancellationSuccessSheetPendingApproval],
//    [cancellationSuccessSheetJeeberRestricted]) — the drop is the finding, and
//    `test/previews/cancellation/cancellation_success_sheet_preview_test.dart`
//    proves it by comparing the rendered strings rather than by eye;
//  * the two geometries that can break it —
//    [cancellationSuccessSheetNarrowPhone] and
//    [cancellationSuccessSheetGestureBarInset].
//
// **About the captions.** Because the three payload previews render the same
// copy, `find.text('Delivery cancelled')` cannot tell them apart and an
// `expectedText` map bound to widget output would be the exact weak assertion
// the harness warns about. Each preview therefore carries a one-line caption
// naming the fixture or geometry under review — useful in the canvas, where
// five near-identical cards are otherwise indistinguishable, and used by the
// test only to ADDRESS a state. The assertions that prove the states differ
// (measured boxes) and that three of them deliberately do not (identical
// strings) live in the test.
//
// **Tapping in the canvas.** `onDone` is a no-op here. Production pops twice —
// the modal route off the root navigator, then `CancellationScreen` itself —
// and neither navigator exists in a preview.

/// Phone width the sheet is designed against.
const double _cancellationSuccessSheetPhoneWidth = 390;

/// The narrowest phone the app still supports (iPhone SE 1st-gen class).
const double _cancellationSuccessSheetNarrowPhoneWidth = 320;

/// Bottom safe-area inset of a gesture-bar phone, the padding the sheet's own
/// [SafeArea] is there to absorb.
const double _cancellationSuccessSheetGestureBarInsetValue = 34;

/// Canvas box for the sheet at phone width: ~204 pt of sheet plus the caption.
const Size _cancellationSuccessSheetBox = Size(390, 260);

/// Same content at 320 pt — the copy still fits one line, so only the width
/// changes.
const Size _cancellationSuccessSheetNarrowBox = Size(320, 260);

/// Taller box, because the gesture-bar rendering adds 34 pt below the CTA.
const Size _cancellationSuccessSheetInsetBox = Size(390, 300);

/// The delivery id the cancellation fixtures in
/// `test/cancellation_cubit_test.dart` use, reused here so a reviewer comparing
/// the two is looking at one delivery.
const String _cancellationSuccessSheetDeliveryId = 'DLV-770013';

/// Preview scaffolding: names the fixture or geometry under review.
///
/// Deliberately tiny and single-purpose so the 200%-text rendering of the
/// matrix still shows the sheet rather than a wall of label.
class _CancellationSuccessSheetCaption extends StatelessWidget {
  const _CancellationSuccessSheetCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      );
}

/// Mounts the sheet the way `showModalBottomSheet(isScrollControlled: true)`
/// presents it — bottom-anchored on a [Material] surface with the 20 pt rounded
/// top the widget's own `show()` sets — without needing a [Navigator] to push
/// onto.
///
/// Two details are load-bearing:
///
///  * **The width pin.** The render tests pump an 800 px viewport and ignore
///    [JeebPreview.size]; without [width] CI would be reviewing a bottom sheet
///    at a width no phone has.
///  * **The [MediaQuery] override.** [jeebPreviewHost] already wraps everything
///    in a [SafeArea], which zeroes `MediaQuery.padding` for its descendants —
///    so the sheet's OWN `SafeArea` would be a no-op and [bottomInset] would be
///    unreviewable. Re-introducing the padding here, inside the host, is what
///    puts the sheet back in the situation a real phone gives it.
Widget _cancellationSuccessSheetHosted(
  CancellationResult result, {
  required String caption,
  double width = _cancellationSuccessSheetPhoneWidth,
  double bottomInset = 0,
}) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _CancellationSuccessSheetCaption(caption),
        const SizedBox(height: Spacing.xSmall),
        SizedBox(
          width: width,
          child: Builder(
            builder: (BuildContext context) {
              final MediaQueryData mq = MediaQuery.of(context);
              return Material(
                color: Theme.of(context).colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(Spacing.large),
                  ),
                ),
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(bottom: bottomInset),
                  ),
                  child: CancellationSuccessSheet(
                    result: result,
                    onDone: () {},
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// The default reading: a plain pre-pickup cancel that the gateway accepted
/// outright, on a 390 pt phone.
///
/// This is the one a designer signs off, and the matrix is on here because
/// everything worth checking about this sheet is visible in the three
/// renderings side by side:
///
///  * **AR RTL dark** — the layout is a centred [Column] with symmetric
///    padding, so there is nothing to mirror and nothing that can mirror
///    *wrongly*; what this rendering is really for is the copy
///    ("تم إلغاء التوصيل" over a "تم" pill, both materially shorter than the
///    English) and the check mark, which is
///    `colorScheme.primary` — see [_SuccessIcon] in the widget. Every other
///    success affordance in this app inks with `context.jeebRoles.success`
///    (`availability_card`, `order_status_chip`, `dispute_status_screen`); this
///    one is brand navy in light and a pale lavender in dark, so the single
///    glyph carrying "it worked" reads as chrome rather than as confirmation.
///  * **EN 200% text** — the accessibility ceiling. The title doubles; the icon
///    does not (a bare 56 pt [Icon], and Flutter only text-scales icons when
///    `IconThemeData.applyTextScaling` is set), so the hierarchy inverts. The
///    `OmdsPrimaryButton` pill is a fixed 48 pt at every scale, which for a
///    label this short is survivable — "Done" / "تم" is the shortest CTA in the
///    app and the reason this sheet escapes the overflow that bites
///    `LogoutDeleteConfirmSheet`.
@JeebPreview(
  group: 'cancellation',
  name: 'Cancelled outright',
  size: _cancellationSuccessSheetBox,
  matrix: true,
)
Widget cancellationSuccessSheetCancelled() => _cancellationSuccessSheetHosted(
      const CancellationResult(
        deliveryId: _cancellationSuccessSheetDeliveryId,
        weeklyCount: 1,
      ),
      caption: 'Payload: weeklyCount 1, cancelled outright',
    );

/// `pendingApproval: true` — a post-pickup client cancel that is NOT final yet.
///
/// Per `CancellationResult`, this flag means the cancellation "requires admin
/// approval". The sheet is handed that fact and renders the identical
/// unqualified "Delivery cancelled" over a "Done" button, so the user is told a
/// delivery is cancelled while it is still awaiting review — and is given no
/// hint that anything further will happen.
///
/// Put this card beside [cancellationSuccessSheetCancelled] in the canvas: they
/// are pixel-identical, which is the whole point of previewing it.
@JeebPreview(
  group: 'cancellation',
  name: 'Pending admin approval',
  size: _cancellationSuccessSheetBox,
)
Widget cancellationSuccessSheetPendingApproval() =>
    _cancellationSuccessSheetHosted(
      const CancellationResult(
        deliveryId: _cancellationSuccessSheetDeliveryId,
        weeklyCount: 2,
        pendingApproval: true,
      ),
      caption: 'Payload: pendingApproval = true',
    );

/// The jeeber half of the same drop: a third strike in 30 days and a `red`
/// restriction tier.
///
/// `strikeCount` and `restriction` are the two fields on [CancellationResult]
/// that carry a consequence for the person reading the sheet — a red tier is
/// what gates a jeeber out of the feed — and this is the only screen the
/// gateway hands them to. Rendered: the same green-less check mark, the same
/// "Delivery cancelled", the same "Done".
///
/// Worth a card of its own rather than a footnote, because the fix is not
/// "add a line of copy": a restricted jeeber needs a different sheet, and this
/// is the picture that makes that obvious.
@JeebPreview(
  group: 'cancellation',
  name: 'Jeeber 3rd strike · red tier',
  size: _cancellationSuccessSheetBox,
)
Widget cancellationSuccessSheetJeeberRestricted() =>
    _cancellationSuccessSheetHosted(
      const CancellationResult(
        deliveryId: _cancellationSuccessSheetDeliveryId,
        weeklyCount: 3,
        strikeCount: 3,
        restriction: 'red',
      ),
      caption: 'Payload: strikeCount 3, restriction red',
    );

/// The same sheet at 320 pt — the narrowest phone, and the width ceiling for
/// both the title and the CTA.
///
/// Two things are clamped here and neither reports an overflow when it gives
/// up. The `OmdsPrimaryButton` pill is a fixed 48 pt (`Sizes.fourXLarge`) with
/// its label in a [Center] and no `maxLines`, so a label too tall for the pill
/// is painted over its edge rather than growing it; and `_SuccessTitle` is a
/// bare [Text] with no ellipsis, so the title grows the sheet instead. At 100%
/// neither is close, in either locale — this is the state that says so, and the
/// baseline any future copy change is measured against.
///
/// The matrix is on for the same reason it is on for the production card: 320 pt
/// at 200% text is the tightest box this widget will ever be laid out in, and it
/// is not obviously survivable until you look at it.
@JeebPreview(
  group: 'cancellation',
  name: 'Narrow phone · 320 pt',
  size: _cancellationSuccessSheetNarrowBox,
  matrix: true,
)
Widget cancellationSuccessSheetNarrowPhone() => _cancellationSuccessSheetHosted(
      const CancellationResult(
        deliveryId: _cancellationSuccessSheetDeliveryId,
        weeklyCount: 1,
      ),
      caption: 'Geometry: 320 pt narrow phone',
      width: _cancellationSuccessSheetNarrowPhoneWidth,
    );

/// A gesture-bar phone: 34 pt of bottom safe-area under the sheet.
///
/// This is the geometry every modern iPhone and most Android phones hand a
/// bottom sheet, and the reason the widget opens with a [SafeArea] at all. The
/// card to compare it against is [cancellationSuccessSheetCancelled]: the CTA
/// must sit 34 pt higher, clear of the home indicator, rather than under it.
///
/// It is previewable only because `_cancellationSuccessSheetHosted`
/// re-introduces the padding that [jeebPreviewHost]'s own [SafeArea] strips —
/// see the note there. Without that, this card would be a duplicate of the
/// production one and the inset would go unreviewed, which is precisely how a
/// CTA ends up under a home indicator.
@JeebPreview(
  group: 'cancellation',
  name: 'Gesture-bar inset · 34 pt',
  size: _cancellationSuccessSheetInsetBox,
)
Widget cancellationSuccessSheetGestureBarInset() =>
    _cancellationSuccessSheetHosted(
      const CancellationResult(
        deliveryId: _cancellationSuccessSheetDeliveryId,
        weeklyCount: 1,
      ),
      caption: 'Geometry: 34 pt gesture-bar inset',
      bottomInset: _cancellationSuccessSheetGestureBarInsetValue,
    );
