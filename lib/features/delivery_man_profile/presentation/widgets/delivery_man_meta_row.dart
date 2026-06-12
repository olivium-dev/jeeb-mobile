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
    // Identifier-only + `container: true`, mirroring the proven `_NameText`
    // pattern in delivery_man_profile_header.dart. The previous explicit
    // `label: text` competed with the text-emitting `_MetaText` child for the
    // accessible name, which risks folding the identifier away at the native
    // layer; `_MetaText` already exposes `text` as the readable label, so the
    // duplicate wrapper label is dropped and the identifier owns its own node.
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
