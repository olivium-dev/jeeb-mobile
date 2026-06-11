import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// A small icon + text meta row in the delivery-man profile header
/// (rating summary, location/availability). The leading glyph is brand orange
/// ([ColorScheme.primary] per design §4); text uses muted secondary text.
class DeliveryManMetaRow extends StatelessWidget {
  const DeliveryManMetaRow({
    super.key,
    required this.icon,
    required this.text,
    required this.semanticsId,
  });

  final IconData icon;
  final String text;
  final String semanticsId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: semanticsId,
      label: text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.medium, color: theme.colorScheme.primary),
          const SizedBox(width: Spacing.xSmall),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
