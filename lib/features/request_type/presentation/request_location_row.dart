import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// The "Location" section row on the Request type screen (Figma 56535:2392):
/// a start-aligned "Current Location" label and an end-aligned "Change
/// Location" text action with a trailing chevron. The action area is the tap
/// target and navigates to the location picker.
class RequestLocationRow extends StatelessWidget {
  const RequestLocationRow({
    super.key,
    required this.currentLabel,
    required this.changeLabel,
    required this.onChange,
  });

  final String currentLabel;
  final String changeLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _CurrentLabel(text: currentLabel)),
        const SizedBox(width: Spacing.medium),
        _ChangeAction(label: changeLabel, onTap: onChange),
      ],
    );
  }
}

class _CurrentLabel extends StatelessWidget {
  const _CurrentLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'request_type_current_location_label',
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ChangeAction extends StatelessWidget {
  const _ChangeAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_type_change_location_button',
      button: true,
      label: label,
      child: InkWell(
        borderRadius: OmdsBorderRadius.uiSmall,
        onTap: onTap,
        child: _ActionContent(label: label),
      ),
    );
  }
}

class _ActionContent extends StatelessWidget {
  const _ActionContent({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: scheme.primary);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xSmall,
        vertical: Spacing.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          const SizedBox(width: Spacing.twoXSmall),
          Icon(Icons.chevron_right, size: Sizes.large, color: scheme.primary),
        ],
      ),
    );
  }
}
