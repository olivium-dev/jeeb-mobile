import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// The two Lottie marks that head the KYC terminal states (08-MOTION-SPEC §2.8
// and §2.5; both verified white-surface-safe in 09-MOTION-VALIDATION §7). They
// replace the flat `Icons.hourglass_top_rounded` / `Icons.verified_rounded`
// glyphs at the head of `_StatusScaffold` — same slot, same size band, so the
// three status bodies stay visually consistent.
//
// Both marks are decorative: the title and body copy beneath them already say
// "under review" / "approved", so each is wrapped in ExcludeSemantics rather
// than emitting a second, redundant node inside `kyc_status_root`.

/// `kyc-review.json` — the document being scanned while the submission is
/// pending (08-MOTION-SPEC §2.8). It **loops**, and legitimately so: the state
/// it depicts is ongoing, which is exactly the loop policy's carve-out.
///
/// Reduce-motion renders frame 0 — the document with the orange beam still at
/// opacity 0 — which is a perfectly good static "documents received" mark.
class KycReviewMark extends StatelessWidget {
  const KycReviewMark({super.key});

  /// The composition is authored at 220x220 and canvases are ~2x display size
  /// (08-MOTION-SPEC §4), which would put this at 110 — but `_StatusScaffold`
  /// is a fixed `Column` with a `Spacer` and no scroll, and the pending body
  /// (title + copy + two notes + three CTAs) has ~44px of slack over the 64px
  /// glyph this replaces. 88 keeps the mark clearly bigger than the glyph with
  /// headroom to spare; 110 overflowed by 2px on an 800x600 surface.
  static const double _markSize = 88;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: _markSize,
          height: _markSize,
          child: Lottie.asset(
            'assets/animations/kyc-review.json',
            // Vertical scan travel only — 08-MOTION-SPEC §2.8 flags this file
            // `RTL: none`, so it must NOT be mirrored in Arabic.
            animate: !reduceMotion,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// `success-check.json` — the shared terminal mark (08-MOTION-SPEC §2.5), fired
/// once when the KYC decision lands on *approved*.
///
/// ONE-SHOT, enforced here rather than trusted: the composition carries no loop
/// flag, so looping is purely the player's `repeat:` argument. A controller
/// drives a single `forward()` and the file then holds its settled frame
/// (validated: 18 held frames, pixel delta 0.0000).
///
/// It never gates anything — [_ApprovedBody]'s role activation and its three
/// CTAs are live from the first frame.
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
