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
const String _cancellationSuccessSheetDeliveryId = 'DLV-770013';

/// Preview scaffolding: names the fixture or geometry under review.
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
/// Per `CancellationResult`, this flag means the cancellation "requires admin
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
/// This is the geometry every modern iPhone and most Android phones hand a
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
