import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';

/// A small icon + text meta row in the delivery-man profile header
/// (rating summary, location/availability).
///
/// MIDNIGHT: R15's below-disc meta line and R16's card meta run — periwinkle
/// `mutedText` copy with the glyph in board ink (`onSurface`), which is how
/// §4.1 keeps the aggregate star off the rationed warm inks.
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
          Icon(icon, size: Sizes.medium, color: theme.colorScheme.onSurface),
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
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Text(
      text,
      style: context.jeebText.bodySmall.copyWith(color: semantic.mutedText),
      overflow: TextOverflow.ellipsis,
    );
  }
}
