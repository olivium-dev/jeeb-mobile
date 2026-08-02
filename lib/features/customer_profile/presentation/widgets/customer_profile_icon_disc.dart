import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
