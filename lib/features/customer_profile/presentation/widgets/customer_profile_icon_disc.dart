import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/customer_profile/customer_profile_icon_disc_preview_test.dart
// ===========================================================================

// Widget previews for [CustomerProfileIconDisc] — run with
// `flutter widget-preview start`.
//
// The disc is a pure function of one argument: an [IconData]. It owns no
// state, no cubit and no repository, so every preview below is a plain
// constructor call — network-free by construction, not just by the guard in
// [jeebPreviewHost].
//
// Two things about the widget shape this section:
//
// * **It renders no text of its own.** A canvas of six near-identical navy
//   circles is unreadable, and — worse — a render test could not tell one
//   preview from another, which is the exact failure `expectedText` exists to
//   catch. So each preview is a *specimen*: the disc, plus a caption naming
//   the state. The caption is preview chrome, not part of the component; it is
//   deliberately `labelSmall` / `onSurfaceVariant` so it never reads as the
//   disc's own label. This follows the previews on `ChatComposerIconButton`.
// * **Everything it can get wrong is a colour or a direction, not a layout.**
//   The disc is a fixed 32dp circle (`Sizes.twoXLarge`) around a fixed 20dp
//   glyph (`Sizes.large`), so it cannot overflow. What it *can* do is render a
//   glyph that disappears into its own fill, or a glyph that points the wrong
//   way in Arabic. The two specimens at the bottom of this section exist for
//   exactly those, and they are why this widget is worth previewing at all.
//
// The glyphs used here are the eight production values read off
// `customer_profile_rows.dart` — the only call site — rather than invented
// ones, so the canvas shows the discs a customer actually sees.

/// Specimen box for a single disc: the disc is 32dp square, so this is a short,
/// wide box with enough height for the caption to double in the 200%-text
/// rendering without clipping the evidence.
const Size _customerProfileIconDiscDiscBox = Size(340, 150);

/// Wider, taller box for the specimens that show more than one disc, or a disc
/// next to a row label.
const Size _customerProfileIconDiscStripBox = Size(390, 190);

/// The eight glyphs `CustomerProfileRows` mounts, in the order the profile
/// screen renders them: register-delivery, password, notifications, language,
/// addresses, contact, rate-app, logout.
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

/// One specimen: [sample] — the disc under review, in whatever surround the
/// state calls for — with a caption naming the state underneath it.
///
/// The caption is built from the *outer* theme on purpose. Specimens that
/// re-theme their sample (see [customerProfileIconDiscOnDarkSurface]) must
/// still be readable in the canvas, so the label may not inherit the sample's
/// scheme.
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

/// The canonical disc, as the "Password and security" row mounts it.
///
/// This is the baseline reading: white glyph on the navy `secondaryContainer`,
/// 17.1:1 in the light scheme. Compare it against
/// [customerProfileIconDiscOnDarkSurface] — same widget, same code path, and
/// the only thing that changed is the ambient scheme.
@JeebPreview(
  group: 'customer_profile',
  name: 'Password row · lock',
  size: _customerProfileIconDiscDiscBox,
)
Widget customerProfileIconDiscLock() => _customerProfileIconDiscHosted(
  caption: 'Password row · lock',
  sample: const CustomerProfileIconDisc(icon: Icons.lock_outline),
);

/// The tightest glyph in the production set: the delivery scooter.
///
/// 20dp of glyph inside a 32dp circle leaves 6dp of navy on each side, and this
/// is the glyph that spends it — a wide, detailed scooter that reads as a smudge
/// at this size where `lock_outline` still reads as a lock. It is also the only
/// disc a *new* customer sees at the top of the list (the row is hidden once the
/// account is a Jeeber), so it is the first impression of the whole pattern.
@JeebPreview(
  group: 'customer_profile',
  name: 'Widest glyph · scooter',
  size: _customerProfileIconDiscDiscBox,
)
Widget customerProfileIconDiscScooter() => _customerProfileIconDiscHosted(
  caption: 'Widest glyph · scooter',
  sample: const CustomerProfileIconDisc(icon: Icons.delivery_dining_outlined),
);

/// All eight production glyphs at once, in screen order.
///
/// A disc is only ever seen in a vertical stack of its siblings, so the review
/// question is not "is this glyph fine" but "do these eight read as one set".
/// Mixed `_outline` and `_none` / `_outlined` suffixes across the set are the
/// thing to watch: `notifications_none` is a hairline bell next to the much
/// heavier `delivery_dining_outlined`, and at 20dp that weight difference is
/// the only signal distinguishing the rows apart from the label.
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

/// The RTL trap, in the one glyph of the set that carries a direction.
///
/// `Icons.logout_outlined` is a door with an arrow leaving it to the **right**,
/// and it is declared as a plain `IconData` — no `matchTextDirection`, unlike
/// `Icons.arrow_forward` or `Icons.chevron_right`. The disc passes whatever it
/// is given straight to [Icon], so nothing downstream mirrors it either.
///
/// `directional_icons.dart` opens by warning that "a hardcoded `arrow_back` /
/// `chevron_right` points the WRONG way under RTL" and offers
/// `DirectionalIcons` as the fix; the sign-out glyph never went through it.
/// Read the **AR RTL dark** rendering of this specimen next to its EN one: the
/// arrow does not move, so in Arabic the user exits the door backwards.
@JeebPreview(
  group: 'customer_profile',
  name: 'Sign-out glyph · no mirroring',
  size: _customerProfileIconDiscDiscBox,
)
Widget customerProfileIconDiscLogout() => _customerProfileIconDiscHosted(
  caption: 'Sign-out glyph · no mirroring',
  sample: const CustomerProfileIconDisc(icon: Icons.logout_outlined),
);

/// The state that costs the disc its glyph: the dark scheme.
///
/// The class doc calls the pairing "navy = secondaryContainer, glyph =
/// onSecondary, both from the theme (no literals)". That reads as disciplined
/// M3, but the two roles are not a *pair* — `onSecondary` is the ink for
/// `secondary`, and only `onSecondaryContainer` is guaranteed to contrast with
/// `secondaryContainer`. In the light scheme the mismatch is invisible because
/// `onSecondary` is hardcoded to white (17.1:1). In the dark scheme, which is
/// `ColorScheme.fromSeed`, `onSecondary` is a *dark* tone and the disc renders
/// **1.40:1** — below the 3:1 WCAG 1.4.11 floor for graphical objects, i.e. a
/// navy circle with nothing legible in it. The same glyph on
/// `onSecondaryContainer` would be 7.23:1.
///
/// This specimen forces the dark scheme so the defect shows in *every* cell of
/// the matrix rather than only in the AR RTL dark one, and puts the two
/// candidate inks side by side: left is what ships, right is the M3 pair.
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

/// The disc as M3 would pair it — `onSecondaryContainer` on
/// `secondaryContainer` — drawn here purely as the reference swatch beside
/// [customerProfileIconDiscOnDarkSurface].
///
/// It deliberately does **not** live in production: this is a preview-only
/// control, so the canvas can show what the fix would look like without any
/// change to [CustomerProfileIconDisc] itself.
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

/// The disc in the geometry it actually ships in: leading element of a row,
/// with the row's real localized label beside it.
///
/// Reproduces the first two children of `_RowContent`
/// (`customer_profile_row.dart:70`) rather than mounting the row itself, so
/// what is under review stays the disc. The label is resolved from the ambient
/// [AppLocalizations] so the AR rendering carries the real Arabic string
/// ("كلمة المرور والأمان") instead of an English placeholder.
///
/// The point of this specimen is the **EN 200% text** rendering: the label
/// doubles, the disc does not. Both `Sizes.twoXLarge` and `Sizes.large` are
/// fixed tokens and [Icon] does not opt into `applyTextScaling`, so a user at
/// 200% gets 32dp discs beside 28pt text and the row's leading column stops
/// reading as an icon at all. The 48dp row height is enforced by
/// `CustomerProfileRow`, not here, so nothing clips — the disc just shrinks in
/// relative terms until it is decoration.
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
