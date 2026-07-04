import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/directional_icons.dart';
import 'customer_profile_icon_disc.dart';

/// A single Account/Support row on the customer profile: navy icon disc +
/// muted label + trailing affordance (chevron by default, or a custom
/// [trailing] such as the "Register" pill). Built as a tappable [Row] (not a
/// [ListTile]) so a trailing intrinsic-width widget like [OmdsPrimaryButton]
/// lays out cleanly; min 48dp touch target enforced via [ConstrainedBox]
/// (design §5). Its own widget class — no `_buildXxx`.
class CustomerProfileRow extends StatelessWidget {
  const CustomerProfileRow({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticsId,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String semanticsId;
  final VoidCallback onTap;

  /// Optional trailing widget; defaults to a directional chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticsId,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.fiveXLarge),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.xLarge,
              vertical: Spacing.xSmall,
            ),
            child: _RowContent(icon: icon, label: label, trailing: trailing),
          ),
        ),
      ),
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CustomerProfileIconDisc(icon: icon),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing ?? _Chevron(color: theme.colorScheme.outline),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      DirectionalIcons.disclosureIos(context),
      size: Sizes.medium,
      color: color,
    );
  }
}
