import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// M5/A4: the pending terminal's looping `kyc-review.json` scan-line was removed
// — R23 is board-static, so it renders the still `_GlyphMark` again.

/// `success-check.json` — the shared terminal mark, played ONCE when the KYC
/// decision lands on *approved*. Decorative (the copy beneath already says it),
/// controller-driven so it can never loop, and it gates nothing.
class KycApprovedMark extends StatefulWidget {
  const KycApprovedMark({super.key});

  /// 200x200 canvas → ~100 display (09-MOTION-VALIDATION §11).
  static const double markSize = 100;

  @override
  State<KycApprovedMark> createState() => _KycApprovedMarkState();
}

class _KycApprovedMarkState extends State<KycApprovedMark>
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
        // Reduce motion: jump straight to the settled check — the confirmation
        // still reads, nothing moves.
        _controller.value = 1;
        return;
      }
      _controller.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: KycApprovedMark.markSize,
          height: KycApprovedMark.markSize,
          child: Lottie.asset(
            'assets/animations/success-check.json',
            controller: _controller,
            onLoaded: _play,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
