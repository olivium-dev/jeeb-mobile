import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// 32dp navy circular disc with a centered white glyph — the leading element
/// of every customer-profile row (design §5). Navy = secondaryContainer,
/// glyph = onSecondary, both from the theme (no literals).
class CustomerProfileIconDisc extends StatelessWidget {
  const CustomerProfileIconDisc({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.twoXLarge,
      height: Sizes.twoXLarge,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: Sizes.large,
        color: colorScheme.onSecondary,
      ),
    );
  }
}
