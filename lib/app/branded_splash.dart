import 'package:flutter/material.dart';

/// Jeeb branded splash — matches the Figma design (node 56572:1711).
///
/// Full navy background with the "Jeeb" wordmark centered and
/// "Delivery App" at the bottom. Dependency-free so it renders instantly.
class BrandedSplash extends StatefulWidget {
  const BrandedSplash({super.key});

  static const Color _navy = Color(0xFF0B1351);
  static const Color _orange = Color(0xFFD73B00);

  @override
  State<BrandedSplash> createState() => _BrandedSplashState();
}

class _BrandedSplashState extends State<BrandedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.85, end: 1.0).animate(fade);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: BrandedSplash._navy,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: scale,
                  child: const _JeebWordmark(),
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 56),
                child: Text(
                  'Delivery App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JeebWordmark extends StatelessWidget {
  const _JeebWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text(
          'Jee',
          style: TextStyle(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        Text(
          'b',
          style: TextStyle(
            color: BrandedSplash._orange,
            fontSize: 64,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }
}
