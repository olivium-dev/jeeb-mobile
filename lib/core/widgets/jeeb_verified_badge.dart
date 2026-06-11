import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// SealCheck "verified" badge used wherever an account is verified
/// (customer profile header, delivery-man profile header). Shared so the two
/// profile screens reuse one implementation (RAIL 4). Brand navy glyph via
/// [ColorScheme.secondaryContainer]; the caller supplies the localized
/// accessibility [semanticsLabel].
class JeebVerifiedBadge extends StatelessWidget {
  const JeebVerifiedBadge({
    super.key,
    required this.semanticsLabel,
    this.size = Sizes.large,
  });

  /// Localized accessibility label (no visible text on the badge).
  final String semanticsLabel;

  /// Glyph size; defaults to the 20dp class used in both profile headers.
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
