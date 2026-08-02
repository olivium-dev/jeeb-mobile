import 'package:flutter/material.dart';
import 'package:omds/omds.dart';




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
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.medium, color: theme.colorScheme.primary),
          const SizedBox(width: Spacing.xSmall),
          Flexible(child: _MetaText(text: text)),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
