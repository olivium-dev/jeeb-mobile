import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// SealCheck "verified" badge; shared across profile screens (RAIL 4).
class JeebVerifiedBadge extends StatelessWidget {
  const JeebVerifiedBadge({
    super.key,
    required this.semanticsLabel,
    this.size = Sizes.large,
  });

  /// Localized accessibility label.
  final String semanticsLabel;

  /// Icon size.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      identifier: 'jeeb_verified_badge',
      image: true,
      child: Icon(
        Icons.verified,
        size: size,
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
    );
  }
}
