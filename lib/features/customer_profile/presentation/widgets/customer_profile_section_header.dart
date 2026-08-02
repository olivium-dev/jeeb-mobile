import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

class CustomerProfileSectionHeader extends StatelessWidget {
  const CustomerProfileSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.large,
        Spacing.xLarge,
        Spacing.xSmall,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.secondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
