import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// `success-check.json` fired once when a top-up lands (08-MOTION-SPEC §2.5,
/// screen 23).
///
/// The spec REFUSED a coin-drop of its own: "a coin-drop reads dead without
/// bounce, and bounce is forbidden. Money moments deserve the same quiet
/// certainty as delivery — same mark, same feeling." So the wallet reuses the
/// shared terminal mark.
///
/// ONE-SHOT: a controller plays it forward exactly once. Under reduce-motion it
/// jumps to the settled frame instead. Callers overlay it inside an
/// [IgnorePointer] — the wallet stays fully usable while it plays.
///
/// It reports nothing back. Its host times the mark out on its own clock, so a
/// composition that loads slowly (or not at all) can never leave an overlay
/// stuck on the wallet.
class WalletTopUpConfirmedMark extends StatefulWidget {
  const WalletTopUpConfirmedMark({super.key});

  /// 200x200 canvas → ~100 display (09-MOTION-VALIDATION §11).
  static const double markSize = 100;

  @override
  State<WalletTopUpConfirmedMark> createState() =>
      _WalletTopUpConfirmedMarkState();
}

class _WalletTopUpConfirmedMarkState extends State<WalletTopUpConfirmedMark>
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
    // Decorative: the balance itself is the announcement, so this adds no
    // second semantics node over `wallet_available_balance`.
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: WalletTopUpConfirmedMark.markSize,
          height: WalletTopUpConfirmedMark.markSize,
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
