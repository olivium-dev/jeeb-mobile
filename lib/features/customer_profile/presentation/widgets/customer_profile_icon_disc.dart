import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

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
// ============================= JEEB PREVIEWS =============================

/// Specimen box for single disc.
const Size _customerProfileIconDiscDiscBox = Size(340, 150);

/// Wider box for multiple discs.
const Size _customerProfileIconDiscStripBox = Size(390, 190);

/// Eight production glyphs in screen order.
const List<IconData> _customerProfileIconDiscProductionGlyphs = <IconData>[
  Icons.delivery_dining_outlined,
  Icons.lock_outline,
  Icons.notifications_none,
  Icons.language_outlined,
  Icons.location_on_outlined,
  Icons.call_outlined,
  Icons.star_outline,
  Icons.logout_outlined,
];

/// Host specimen with caption; caption uses outer theme for readability.
Widget _customerProfileIconDiscHosted({
  required String caption,
  required Widget sample,
}) {
  return Builder(
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            sample,
            const SizedBox(height: Spacing.xSmall),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.small),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Canonical disc: password row lock.
@JeebPreview(
  group: 'customer_profile',
  name: 'Password row · lock',
  size: _customerProfileIconDiscDiscBox,
)
Widget customerProfileIconDiscLock() => _customerProfileIconDiscHosted(
  caption: 'Password row · lock',
  sample: const CustomerProfileIconDisc(icon: Icons.lock_outline),
);

/// Widest glyph: delivery scooter.
@JeebPreview(
  group: 'customer_profile',
  name: 'Widest glyph · scooter',
  size: _customerProfileIconDiscDiscBox,
)
Widget customerProfileIconDiscScooter() => _customerProfileIconDiscHosted(
  caption: 'Widest glyph · scooter',
  sample: const CustomerProfileIconDisc(icon: Icons.delivery_dining_outlined),
);

/// All eight production glyphs.
@JeebPreview(
  group: 'customer_profile',
  name: 'All 8 production glyphs',
  size: _customerProfileIconDiscStripBox,
)
Widget customerProfileIconDiscProductionSet() => _customerProfileIconDiscHosted(
  caption: 'All 8 production glyphs',
  sample: Padding(
    padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
    child: Wrap(
      spacing: Spacing.xSmall,
      runSpacing: Spacing.xSmall,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final IconData glyph in _customerProfileIconDiscProductionGlyphs)
          CustomerProfileIconDisc(icon: glyph),
      ],
    ),
  ),
);

/// RTL trap: sign-out glyph never mirrored in Arabic.
@JeebPreview(
  group: 'customer_profile',
  name: 'Sign-out glyph · no mirroring',
  size: _customerProfileIconDiscDiscBox,
)
Widget customerProfileIconDiscLogout() => _customerProfileIconDiscHosted(
  caption: 'Sign-out glyph · no mirroring',
  sample: const CustomerProfileIconDisc(icon: Icons.logout_outlined),
);

/// Dark scheme: glyph vanishes; left is current, right is M3 fix.
@JeebPreview(
  group: 'customer_profile',
  name: 'Dark scheme · glyph vanishes',
  size: _customerProfileIconDiscStripBox,
)
Widget customerProfileIconDiscOnDarkSurface() {
  final ThemeData dark = AppTheme.dark();
  return _customerProfileIconDiscHosted(
    caption: 'Dark scheme · glyph vanishes',
    sample: Theme(
      data: dark,
      child: ColoredBox(
        color: dark.colorScheme.surface,
        child: const Padding(
          padding: EdgeInsets.all(Spacing.medium),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CustomerProfileIconDisc(icon: Icons.lock_outline),
              SizedBox(width: Spacing.medium),
              _CustomerProfileIconDiscOnSecondaryContainerReference(
                icon: Icons.lock_outline,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// M3 reference: `onSecondaryContainer` on `secondaryContainer`; preview-only.
class _CustomerProfileIconDiscOnSecondaryContainerReference
    extends StatelessWidget {
  const _CustomerProfileIconDiscOnSecondaryContainerReference({
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
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
        color: colorScheme.onSecondaryContainer,
      ),
    );
  }
}

/// Disc beside row label; EN 200% shows icon shrinking relative to text.
@JeebPreview(
  group: 'customer_profile',
  name: 'Beside its row label',
  size: _customerProfileIconDiscStripBox,
)
Widget customerProfileIconDiscBesideLabel() => _customerProfileIconDiscHosted(
  caption: 'Beside its row label',
  sample: Builder(
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xLarge),
        child: Row(
          children: <Widget>[
            const CustomerProfileIconDisc(icon: Icons.lock_outline),
            const SizedBox(width: Spacing.xSmall),
            Expanded(
              child: Text(
                AppLocalizations.of(context).customerProfilePasswordSecurity,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    },
  ),
);
