import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// "New Location" row on the Client Location screen (Figma 56539:1444): a
/// start-aligned label and a trailing circular navy add button. The whole row
/// is the tap target (mirrors the card behaviour); the circular button is a
/// navy filled circle with a peach-tinted "+" in Figma — here the glyph is
/// `onPrimary` on the navy circle (token-driven, see comparison.md).
class ClientLocationAddRow extends StatelessWidget {
  const ClientLocationAddRow({
    super.key,
    required this.label,
    required this.addSemanticLabel,
    required this.onTap,
  });

  final String label;
  final String addSemanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'client_location_add_new',
      button: true,
      label: addSemanticLabel,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: OmdsBorderRadius.uiMedium,
          onTap: onTap,
          child: _RowContent(label: label, onTap: onTap),
        ),
      ),
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style =
        Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.primary);
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(vertical: Spacing.xSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: Spacing.medium),
          _AddButton(onTap: onTap),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: Sizes.fourXLarge,
      child: Center(
        child: Container(
          width: Sizes.threeXLarge,
          height: Sizes.threeXLarge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
          ),
          child: Icon(
            Icons.add,
            size: Sizes.xLarge,
            color: scheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
