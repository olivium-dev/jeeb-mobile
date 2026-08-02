/// Widget previews for [BrandedSplash] — run with
/// `flutter widget-preview start`.
///
/// [BrandedSplash] takes no arguments, reads no repository and has exactly one
/// string. There is no empty / loading / error axis to preview: the only inputs
/// it has are the ones the *window* supplies — how wide the frame is, how tall
/// it is, and how much of it the system chrome has already claimed. Those are
/// the states below.
///
/// That makes it network-free by construction — there is nothing to seed and no
/// cubit to build — so [jeebPreviewHost]'s `CatalogNetworkGuard` is pure net
/// here, not the plan.
///
/// The frame has to be pinned INSIDE the preview rather than left to the canvas
/// [Size], for the same reason `responsive_body_preview.dart` documents: the
/// canvas honours `size`, but the render tests in `test/previews/` pump onto a
/// fixed 800 × 600 surface. A preview that merely asked for a 440 × 956 canvas
/// would be measured at 800 × 600 under test and all five states would silently
/// become the same widget. `_DeviceFrame` therefore simulates the window with a
/// [SizedBox] plus a [MediaQuery] override for `size` / `padding`, and
/// `_hosted` unbounds both axes so a frame larger than the host is honoured
/// instead of clamped.
///
/// Three things these previews surfaced, all in the widget rather than in the
/// previews — see the notes on the individual states:
///
///  * the wordmark width is the fixed token `Sizes.twoHundredLarge` (200 pt),
///    not a fraction of the frame, so it is 55.6 % of a 360 pt phone and 24.0 %
///    of an 834 pt tablet — the `_SplashLogo` dartdoc's "~45 % of a 440dp
///    frame … the brand-sized analogue of Figma's 182px (≈41 %)" is only true
///    at exactly 440 pt;
///  * the tagline is inked with `colorScheme.onSecondary` on a
///    `colorScheme.secondaryContainer` fill — not an M3 pair. It survives in
///    the light scheme (white on navy, 17.13 : 1) and collapses to **1.40 : 1**
///    in dark, which is what the AR RTL **dark** rendering of every state below
///    shows. `jeeb_bootstrap.dart` hosts the splash with
///    `themeMode: ThemeMode.system`, so that is the first frame a dark-mode
///    user sees;
///  * `_SplashTagline` is a bare `Text` with no `Padding`, so its line box is
///    the full safe width of the device with a zero side gutter — latent
///    rather than live, because both shipped taglines are short.
library;

import 'package:flutter/material.dart';

import '../../app/branded_splash.dart';
import '../harness/jeeb_preview.dart';

/// The Figma frame the widget is specified against (node `56572:1711`), and the
/// surface size `client_home_screen_test.dart` and friends pump at.
const Size _figmaFrame = Size(440, 956);

/// The smallest phone the app is still expected to look right on — the width
/// `jeeber_feed_card_test.dart` uses for its compact case.
const Size _compactFrame = Size(360, 640);

/// A modern notched phone (iPhone 15 Pro class) in portrait.
const Size _notchedFrame = Size(393, 852);

/// The same device rotated. A cold launch in landscape is a real path on
/// Android tablets and on any phone with rotation unlocked.
const Size _landscapeFrame = Size(852, 393);

/// A tablet in portrait (iPad Air class).
const Size _tabletFrame = Size(834, 1194);

/// Status-bar + home-indicator insets of a notched phone in portrait.
const EdgeInsets _notchInsets = EdgeInsets.only(top: 59, bottom: 34);

/// Rotated: the notch moves to a side, the home indicator thins out.
const EdgeInsets _landscapeInsets = EdgeInsets.only(
  left: 59,
  right: 59,
  bottom: 21,
);

// Each `@JeebPreview` below declares a canvas box of `frame + (12, 44)`: the
// frame itself, its 1 pt outline, and the caption strip above it. The sizes are
// spelled out inline because an annotation argument has to be a constant
// expression.

/// Simulates one window around [BrandedSplash].
///
/// The splash is full-bleed and sizes itself to whatever it is given, so a
/// preview that just returned `const BrandedSplash()` would render the host's
/// box and tell you nothing about the device. This pins the window the widget
/// thinks it is in — both the box it is laid out in and the `MediaQuery` its
/// [SafeArea] reads — and captions it, so a state wired to the wrong frame
/// fails the render test instead of looking plausible in the canvas.
///
/// The caption and the outline are fixtures. Nothing here is production.
class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({
    required this.label,
    required this.frame,
    this.insets = EdgeInsets.zero,
  });

  final String label;
  final Size frame;
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: frame,
              padding: insets,
              viewPadding: insets,
              viewInsets: EdgeInsets.zero,
            ),
            child: SizedBox.fromSize(
              size: frame,
              child: const BrandedSplash(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Unbounds both axes so a simulated frame wider or taller than the host is
/// rendered at its real size instead of being clamped down to the host.
///
/// The render tests pump onto 800 × 600; four of the five frames below are
/// taller than that and two are wider. An `Align` + `SizedBox` (the idiom the
/// chat previews use) cannot do this — it passes the host's constraints down
/// and the oversized box is silently clamped.
Widget _hosted({
  required String label,
  required Size frame,
  EdgeInsets insets = EdgeInsets.zero,
}) =>
    SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _DeviceFrame(label: label, frame: frame, insets: insets),
      ),
    );

/// The reference reading: the exact Figma frame the widget is specified
/// against, with no system chrome claimed.
///
/// Everything the dartdoc claims is true here and only here — the 200 pt
/// wordmark is 45.5 % of the 440 pt width, and the tagline sits the designed
/// 48 pt (`Spacing.fourXLarge`) off the bottom edge. Read the four states below
/// against this one.
@JeebPreview(group: 'app', name: 'Figma frame 440 × 956', size: Size(452, 1000))
Widget brandedSplashFigmaFrame() => _hosted(
      label: 'Figma frame · 440 × 956 · no insets',
      frame: _figmaFrame,
    );

/// The small end of the range: a 360 pt phone.
///
/// `Sizes.twoHundredLarge` is a fixed 200 pt, so the wordmark is now **55.6 %**
/// of the width rather than the ≈41 % the `_SplashLogo` dartdoc cites from
/// Figma. Nothing clips — `BoxFit.contain` keeps the aspect ratio and there is
/// room — but the brand mark is a third larger relative to the frame than the
/// design specifies.
///
/// This is also the state to read the 200 % rendering of. `_SplashTagline` is a
/// bare `Text` with no `Padding` and no width constraint, so its line box is the
/// full 360 pt of the frame with a ZERO side gutter (measured: 360 pt wide at
/// left = 0). At 1.0 the tagline is short enough that nobody notices; the moment
/// a string is long enough to wrap, it wraps against the glass.
@JeebPreview(group: 'app', name: 'Compact 360 × 640', size: Size(372, 684))
Widget brandedSplashCompactPhone() => _hosted(
      label: 'Compact phone · 360 × 640 · no insets',
      frame: _compactFrame,
    );

/// The state ~every iOS user actually sees: a notched phone with a 59 pt status
/// bar and a 34 pt home indicator.
///
/// [BrandedSplash] wraps its body in a `SafeArea`, so the 48 pt tagline margin
/// is measured from the TOP of the home indicator, not from the display edge —
/// the tagline ends up 82 pt clear of the bottom of the glass here against 48 pt
/// in the Figma-frame state above.
///
/// The wordmark's "optical" lift moves too. `_SplashBody` gets it from
/// asymmetric 10 : 9 `Spacer` weights applied to the SAFE box, so it is a
/// by-product of spare height rather than a fixed offset: measured 14.9 pt
/// above true centre on the Figma frame and 7.5 pt here. A device whose bottom
/// inset exceeded its top one would land the wordmark *below* true centre.
@JeebPreview(group: 'app', name: 'Notched 393 × 852 · inset 59/34', size: Size(405, 896))
Widget brandedSplashNotchedPhone() => _hosted(
      label: 'Notched phone · 393 × 852 · inset 59/34',
      frame: _notchedFrame,
      insets: _notchInsets,
    );

/// The short viewport: the same device rotated, launched cold.
///
/// This is the state the vertical composition was never drawn for. `_SplashBody`
/// is a non-scrolling `Column` whose fixed children do not shrink, so all the
/// give is in the two `Spacer`s — and the frame is 393 pt tall before the 21 pt
/// home indicator comes off.
///
/// It holds up, and the measurement is the useful part: 152.5 pt of fixed
/// children (80.5 wordmark + 24 tagline + 48 margin) in a 372 pt safe box, so
/// 219.5 pt of give, of which the 200 % rendering spends 24. The splash is one
/// of the few surfaces in the app with slack to spare at the accessibility
/// ceiling.
///
/// What it does show is the wordmark stranded: 200 pt of mark centred in 852 pt
/// of navy, with the 59 pt side insets doing nothing, because the composition
/// has no horizontal structure for `SafeArea` to inset.
@JeebPreview(group: 'app', name: 'Landscape 852 × 393', size: Size(864, 438))
Widget brandedSplashLandscape() => _hosted(
      label: 'Landscape · 852 × 393 · inset 59/59/21',
      frame: _landscapeFrame,
      insets: _landscapeInsets,
    );

/// The large end of the range: a tablet in portrait.
///
/// The other half of the fixed-token problem. The wordmark is still 200 pt, so
/// it is **24.0 %** of an 834 pt frame — a little over half the specified
/// proportion — and reads as a small mark adrift in a very large navy field.
/// The tagline is likewise still `titleMedium`, unscaled, 1194 pt down.
/// Nothing breaks; it simply stops being the brand composition that was signed
/// off.
@JeebPreview(group: 'app', name: 'Tablet 834 × 1194', size: Size(846, 1238))
Widget brandedSplashTablet() => _hosted(
      label: 'Tablet portrait · 834 × 1194 · no insets',
      frame: _tabletFrame,
    );
