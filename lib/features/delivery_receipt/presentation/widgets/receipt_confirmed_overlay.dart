import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// The confirmation beat shown between "Yes, I got it" landing and the hand-off
/// to the mandatory rating screen (08-MOTION-SPEC §2.5, screen 14).
///
/// `success-check.json` is THE terminal mark — a delivered order, a wallet
/// top-up and a KYC approval all use it so they feel identical. It is a
/// ONE-SHOT: a controller plays it forward exactly once and the composition
/// then holds its settled frame (validated: 18 held frames, pixel delta 0).
///
/// It is deliberately **not** load-bearing. The screen schedules its navigation
/// on a timer that this widget cannot touch, so a slow or missing asset can
/// never strand the customer on the receipt prompt — the worst case is a blank
/// beat. Nothing here is interactive, so it adds no identifier and excludes
/// itself from semantics; the destination announces itself.
class ReceiptConfirmedOverlay extends StatefulWidget {
  const ReceiptConfirmedOverlay({super.key});

  /// 200x200 canvas → ~100 display (09-MOTION-VALIDATION §11).
  static const double markSize = 100;

  @override
  State<ReceiptConfirmedOverlay> createState() =>
      _ReceiptConfirmedOverlayState();
}

class _ReceiptConfirmedOverlayState extends State<ReceiptConfirmedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// `onLoaded` fires on every rebuild of the composition; the play must not.
  bool _played = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// `onLoaded` runs during the composition's build, so the play is deferred a
  /// frame — driving the controller mid-build would rebuild a widget that is
  /// already building.
  void _play(LottieComposition composition) {
    if (_played) return;
    _played = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.duration = composition.duration;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
        return;
      }
      _controller.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Opaque, not a scrim: this is the screen's own terminal state. Midnight
    // re-grounds it on the page navy so the beat does not flash a lighter slab.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Center(
        child: ExcludeSemantics(
          child: SizedBox(
            width: ReceiptConfirmedOverlay.markSize,
            height: ReceiptConfirmedOverlay.markSize,
            child: Lottie.asset(
              'assets/animations/success-check.json',
              controller: _controller,
              onLoaded: _play,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
