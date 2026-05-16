import 'package:flutter/material.dart';

/// Jeeb branded splash shown during cold-start bootstrap.
///
/// Rendered the moment the Flutter engine hands off from the native splash,
/// so the user never sees a white frame while [Bootstrap.minimal] is running.
/// The logo mark fades + scales in once per launch; the indicator is a thin
/// circular spinner sitting under the wordmark.
///
/// This widget is intentionally dependency-free (no DI, no OMDS theme lookup,
/// no GoogleFonts) so it can render with zero async work and zero allocations
/// from the design system. Brand color matches `AppTheme._primarySeed` —
/// duplicated as a const here to keep the splash off the cold-start critical
/// path of `AppTheme.light()`.
class BrandedSplash extends StatefulWidget {
  const BrandedSplash({super.key});

  static const Color _brand = Color(0xFF1B6B4E);

  @override
  State<BrandedSplash> createState() => _BrandedSplashState();
}

class _BrandedSplashState extends State<BrandedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.92, end: 1.0).animate(fade);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: scale,
                  child: const _JeebMark(),
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(BrandedSplash._brand),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JeebMark extends StatelessWidget {
  const _JeebMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        color: BrandedSplash._brand,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'J',
        style: TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
    );
  }
}
