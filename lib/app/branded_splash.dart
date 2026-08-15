import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/jeeb_midnight_palette.dart';
import '../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../core/previews/jeeb_preview.dart';

class BrandedSplash extends StatelessWidget {
  const BrandedSplash({super.key});

  static const String _logoAsset = 'assets/brand/jeeb_logo.svg';
  static const Duration entranceDuration = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlayStyle,
      child: Semantics(
        identifier: '_splash_screen',
        container: true,
        child: const ColoredBox(
          color: JeebMidnight.surface,
          child: SafeArea(child: Center(child: _SplashLogo())),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final double logoWidth = (MediaQuery.sizeOf(context).width * 0.42)
        .clamp(152.0, 184.0)
        .toDouble();
    return Semantics(
      identifier: '_splash_logo',
      label: l10n.splashLogoSemantic,
      image: true,
      container: true,
      child: Center(
        child: _SplashLogoEntrance(
          child: SvgPicture.asset(
            BrandedSplash._logoAsset,
            width: logoWidth,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _SplashLogoEntrance extends StatefulWidget {
  const _SplashLogoEntrance({required this.child});

  final Widget child;

  @override
  State<_SplashLogoEntrance> createState() => _SplashLogoEntranceState();
}

class _SplashLogoEntranceState extends State<_SplashLogoEntrance>
    with SingleTickerProviderStateMixin {
  static const Curve _entranceCurve = Cubic(0.2, 0.4, 0.4, 1);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BrandedSplash.entranceDuration,
  );
  late final Animation<double> _opacity = _controller.drive(
    TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0.86,
        ).chain(CurveTween(curve: const Cubic(0.4, 0, 0.6, 1))),
        weight: 42,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.86,
          end: 1,
        ).chain(CurveTween(curve: _entranceCurve)),
        weight: 58,
      ),
    ]),
  );
  late final Animation<double> _scale = _controller.drive(
    TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.08,
        ).chain(CurveTween(curve: const Cubic(0.2, 0, 0.4, 1))),
        weight: 48,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.08,
          end: 1,
        ).chain(CurveTween(curve: _entranceCurve)),
        weight: 52,
      ),
    ]),
  );

  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The Figma frame the widget is specified against (node `56572:1711`), and the
/// surface size `client_home_screen_test.dart` and friends pump at.
const Size _brandedSplashFigmaFrame = Size(440, 956);

/// The smallest phone the app is still expected to look right on — the width
/// `jeeber_feed_card_test.dart` uses for its compact case.
const Size _brandedSplashCompactFrame = Size(360, 640);

/// A modern notched phone (iPhone 15 Pro class) in portrait.
const Size _brandedSplashNotchedFrame = Size(393, 852);

/// The same device rotated. A cold launch in landscape is a real path on
/// Android tablets and on any phone with rotation unlocked.
const Size _brandedSplashLandscapeFrame = Size(852, 393);

/// A tablet in portrait (iPad Air class).
const Size _brandedSplashTabletFrame = Size(834, 1194);

/// Status-bar + home-indicator insets of a notched phone in portrait.
const EdgeInsets _brandedSplashNotchInsets = EdgeInsets.only(
  top: 59,
  bottom: 34,
);

/// Rotated: the notch moves to a side, the home indicator thins out.
const EdgeInsets _brandedSplashLandscapeInsets = EdgeInsets.only(
  left: 59,
  right: 59,
  bottom: 21,
);

// Each `@JeebPreview` below declares a canvas box of `frame + (12, 44)`: the

/// Simulates one window around [BrandedSplash].
/// The splash is full-bleed and sizes itself to whatever it is given, so a
/// preview that just returned `const BrandedSplash()` would render the host's
class _BrandedSplashDeviceFrame extends StatelessWidget {
  const _BrandedSplashDeviceFrame({
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
            child: SizedBox.fromSize(size: frame, child: const BrandedSplash()),
          ),
        ),
      ],
    );
  }
}

/// Unbounds both axes so a simulated frame wider or taller than the host is
/// rendered at its real size instead of being clamped down to the host.
Widget _brandedSplashHosted({
  required String label,
  required Size frame,
  EdgeInsets insets = EdgeInsets.zero,
}) => SingleChildScrollView(
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: _BrandedSplashDeviceFrame(
      label: label,
      frame: frame,
      insets: insets,
    ),
  ),
);

/// The reference reading: the exact Figma frame the widget is specified
/// against, with no system chrome claimed.
@JeebPreview(group: 'app', name: 'Figma frame 440 × 956', size: Size(452, 1000))
Widget brandedSplashFigmaFrame() => _brandedSplashHosted(
  label: 'Figma frame · 440 × 956 · no insets',
  frame: _brandedSplashFigmaFrame,
);

/// The small end of the range: a 360 pt phone.
/// The responsive wordmark stays compact enough to leave a calm navy field.
@JeebPreview(group: 'app', name: 'Compact 360 × 640', size: Size(372, 684))
Widget brandedSplashCompactPhone() => _brandedSplashHosted(
  label: 'Compact phone · 360 × 640 · no insets',
  frame: _brandedSplashCompactFrame,
);

/// The state ~every iOS user actually sees: a notched phone with a 59 pt status
/// bar and a 34 pt home indicator.
@JeebPreview(
  group: 'app',
  name: 'Notched 393 × 852 · inset 59/34',
  size: Size(405, 896),
)
Widget brandedSplashNotchedPhone() => _brandedSplashHosted(
  label: 'Notched phone · 393 × 852 · inset 59/34',
  frame: _brandedSplashNotchedFrame,
  insets: _brandedSplashNotchInsets,
);

/// The short viewport: the same device rotated, launched cold.
/// This is the state the vertical composition was never drawn for. `_SplashBody`
@JeebPreview(group: 'app', name: 'Landscape 852 × 393', size: Size(864, 438))
Widget brandedSplashLandscape() => _brandedSplashHosted(
  label: 'Landscape · 852 × 393 · inset 59/59/21',
  frame: _brandedSplashLandscapeFrame,
  insets: _brandedSplashLandscapeInsets,
);

/// The large end of the range: a tablet in portrait.
/// The wordmark caps at 184 pt instead of growing into a tablet-sized billboard.
@JeebPreview(group: 'app', name: 'Tablet 834 × 1194', size: Size(846, 1238))
Widget brandedSplashTablet() => _brandedSplashHosted(
  label: 'Tablet portrait · 834 × 1194 · no insets',
  frame: _brandedSplashTabletFrame,
);
