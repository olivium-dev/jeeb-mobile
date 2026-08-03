// The two Lottie marks screen 04 renders (`docs/redesign-2026-08/08-MOTION-SPEC.md`
// §2.6 and §2.9). Both wrappers exist so every call site inherits the same three
// rules the motion spec and the accessibility bar impose:
//
//  1. Explicit size — both canvases are authored at 2x their display size, so
//     the display box is a constant here and the mark never consumes unbounded
//     space while its composition is still decoding.
//  2. Reduce motion — `MediaQuery.disableAnimationsOf` must leave a *still
//     frame*, not a frozen mid-animation pose. The loop parks on frame 0; the
//     one-shot parks on its FINAL frame, because `empty-say-it`'s frame 0 is
//     deliberately blank (the mark has not entered yet) and parking at 0 would
//     leave an empty box where the empty-state illustration belongs.
//  3. Graceful decode failure — a missing/corrupt composition degrades to the
//     reserved box, never a red error widget. Same contract the app's
//     `SvgPicture.asset` call sites carry via `placeholderBuilder`.
//
// Both marks are decorative: the surrounding copy is what a screen reader
// announces, so each is wrapped in `ExcludeSemantics` here rather than at every
// call site.

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// `empty-say-it.json` — the "nothing here yet — say it" mark (spec §2.6).
///
/// One-shot by contract: an empty list is a still state and the brand forbids
/// decorative loops. The mark enters, gives a single rationed-orange invite
/// ring, and rests on the navy mic. **White surface only** (measured 9.0–11.6%
/// ink on white vs 2.1–4.6% on navy — the navy disc vanishes on navy), which is
/// exactly where screen 04's empty state lives.
///
/// **No RTL mirror**: the composition is radially symmetric about its mic
/// (`09-MOTION-VALIDATION.md` §8).
class ClientHomeEmptyMark extends StatelessWidget {
  const ClientHomeEmptyMark({super.key});

  /// `assets/animations/empty-say-it.json`, already registered in `pubspec.yaml`.
  static const String asset = 'assets/animations/empty-say-it.json';

  /// 160dp on screen for a 240×240 canvas.
  ///
  /// `09-MOTION-VALIDATION.md` §11 suggests ~120dp, which is the right read for
  /// `mic-listening` — that one sits *behind* a real [JeebMicHero] disc, so its
  /// Ø88 mark must stay under Ø118. This mark stands alone as the empty state's
  /// illustration, directly under the hero's Ø56 mic, and at 120dp its own mic
  /// renders Ø44 — visibly *smaller* than the button above it, which inverts
  /// the intended reading. 160dp puts the mark at Ø59, the calm big sibling of
  /// the hero mic, and still well under the Ø200 footprint the retired PNG
  /// reserved. Cost: the invite ring's w3 stroke lands at 2.0dp rather than the
  /// authored 1.5dp — still a thin ring, not a fill, so the orange stays
  /// rationed.
  static const double extent = 160;

  @override
  Widget build(BuildContext context) {
    // Disabled animations must not leave the blank pre-entrance frame:
    // `kAlwaysCompleteAnimation` pins progress at 1.0, the settled navy mic the
    // composition holds from f70 to f90.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: Lottie.asset(
        asset,
        controller: reduceMotion ? kAlwaysCompleteAnimation : null,
        animate: !reduceMotion,
        // One-shot: play once and hold the final frame — the player must not
        // rewind (`09-MOTION-VALIDATION.md` §11).
        repeat: false,
        width: extent,
        height: extent,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const SizedBox.square(dimension: extent),
      ),
    );
  }
}

/// `loading-dots.json` — the inline indeterminate wait (spec §2.9).
///
/// Three periwinkle dots whose opacity peak travels across the row. It replaces
/// `OmdsLoadingState`'s Material spinner on screen 04 so the client home waits
/// in the brand's own voice. Legitimately a loop: it depicts an ongoing state,
/// which is the only thing the brand lets loop.
///
/// **RTL: mirrored.** The phase sequence runs left→right (peaks at f30/f45/f60),
/// so Arabic must read right→left (`09-MOTION-VALIDATION.md` §8).
class ClientHomeLoadingDots extends StatelessWidget {
  const ClientHomeLoadingDots({super.key});

  /// `assets/animations/loading-dots.json`, already registered in `pubspec.yaml`.
  static const String asset = 'assets/animations/loading-dots.json';

  /// 120×48 canvas at the spec's 2x authoring ratio → 60×24dp on screen.
  static const double width = 60;

  /// Paired with [width] to keep the canvas aspect exactly 2.5:1.
  static const double height = 24;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    // Parking a loop on frame 0 is safe here: the file never fully clears (the
    // dots sit at 35% opacity at f0), so the still frame still reads as a wait.
    final Widget mark = Lottie.asset(
      asset,
      animate: !reduceMotion,
      repeat: true,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const SizedBox(width: width, height: height),
    );
    return ExcludeSemantics(
      child: Transform.flip(flipX: isRtl, child: mark),
    );
  }
}
