import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../l10n/app_localizations.dart';
import '../previews/jeeb_preview.dart';

/// SealCheck "verified" badge; shared across profile screens (RAIL 4).
class JeebVerifiedBadge extends StatelessWidget {
  const JeebVerifiedBadge({
    super.key,
    required this.semanticsLabel,
    this.size = Sizes.large,
  });

  /// Localized accessibility label.
  final String semanticsLabel;

  /// Icon size.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      identifier: 'jeeb_verified_badge',
      image: true,
      child: Icon(
        Icons.verified,
        size: size,
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The width the name row actually gets inside `CustomerProfileHeader`: a 390pt
/// phone, `Spacing.xLarge` gutters on both sides, an `Sizes.eightXLarge` avatar
const double _jeebVerifiedBadgeIdentityWidth = 250;

/// Width for the size-scale strip, pinned for the same reason.
const double _jeebVerifiedBadgeSwatchStripWidth = 300;

/// Canvas box for a name row. Generous on purpose: the 200% rendering wraps
/// even a short name inside a 250pt column, and a box that clipped it would
const Size _jeebVerifiedBadgeRowBox = Size(390, 220);

/// Canvas box for the long-name row, which wraps at 1.0 and wraps a great deal
/// further at 200%.
const Size _jeebVerifiedBadgeWrappedRowBox = Size(390, 460);

/// Canvas box for the size strip and the two bare-glyph states.
const Size _jeebVerifiedBadgeGlyphBox = Size(390, 140);

/// Renders [child] above a caption naming the state under review.
/// The caption is preview scaffolding, not widget output — see the library doc.
Widget _jeebVerifiedBadgeHosted(String caption, Widget child) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          child,
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

/// Reproduces the production name row shared by `CustomerProfileHeader` and
/// `DeliveryManProfileHeader`: a [Flexible] name, `Spacing.xSmall`, the badge,
/// vertically centred.
class _JeebVerifiedBadgeNameRow extends StatelessWidget {
  const _JeebVerifiedBadgeNameRow({required this.name, required this.label});

  final String name;

  /// Resolves the localized label the way the real `_NameBadge` does, so the
  /// AR rendering announces Arabic rather than a hardcoded English string.
  final String Function(AppLocalizations) label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: _jeebVerifiedBadgeIdentityWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: Spacing.xSmall),
          JeebVerifiedBadge(semanticsLabel: label(AppLocalizations.of(context))),
        ],
      ),
    );
  }
}

/// The badge on its own, with the production customer-profile label unless
/// [label] overrides it.
class _JeebVerifiedBadgeBadge extends StatelessWidget {
  const _JeebVerifiedBadgeBadge({this.size = Sizes.large, this.label});

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => JeebVerifiedBadge(
        semanticsLabel:
            label ?? AppLocalizations.of(context).customerProfileVerifiedBadgeLabel,
        size: size,
      );
}

/// One entry in the size strip: the glyph at [size], over the number.
class _JeebVerifiedBadgeSwatchCell extends StatelessWidget {
  const _JeebVerifiedBadgeSwatchCell(this.size);

  final double size;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: Sizes.threeXLarge,
            child: Center(child: _JeebVerifiedBadgeBadge(size: size)),
          ),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            size.toStringAsFixed(0),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      );
}

/// The state that ships on the customer profile: `Sizes.large` (20dp) beside a
/// short name, announced as "Verified account".
@JeebPreview(group: 'core', name: 'Customer row (production)', size: _jeebVerifiedBadgeRowBox)
Widget jeebVerifiedBadgeCustomerRow() => _jeebVerifiedBadgeHosted(
      'Customer profile row',
      _JeebVerifiedBadgeNameRow(
        name: 'Sami Fawaz',
        label: (AppLocalizations l10n) =>
            l10n.customerProfileVerifiedBadgeLabel,
      ),
    );

/// The other shipping host: the jeeber profile header, same geometry, different
/// label.
@JeebPreview(group: 'core', name: 'Jeeber row (production)', size: _jeebVerifiedBadgeRowBox)
Widget jeebVerifiedBadgeJeeberRow() => _jeebVerifiedBadgeHosted(
      'Jeeber profile row',
      _JeebVerifiedBadgeNameRow(
        name: 'Kamal Hajj',
        label: (AppLocalizations l10n) =>
            l10n.deliveryManProfileVerifiedBadgeLabel,
      ),
    );

/// Longest plausible content: a full Lebanese compound name in the 250pt the
/// identity column actually gets.
@JeebPreview(group: 'core', name: 'Long name (wraps)', size: _jeebVerifiedBadgeWrappedRowBox)
Widget jeebVerifiedBadgeLongName() => _jeebVerifiedBadgeHosted(
      'Long name wraps; badge centres on the block',
      _JeebVerifiedBadgeNameRow(
        name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        label: (AppLocalizations l10n) =>
            l10n.customerProfileVerifiedBadgeLabel,
      ),
    );

/// The full range of the public `size` parameter, side by side.
/// Only `Sizes.large` (20dp, the default) ships today; both callers take it.
@JeebPreview(group: 'core', name: 'Size scale 12-40dp', size: _jeebVerifiedBadgeGlyphBox)
Widget jeebVerifiedBadgeSizeScale() => _jeebVerifiedBadgeHosted(
      'Size scale: 12 / 20 / 32 / 40 dp',
      const SizedBox(
        width: _jeebVerifiedBadgeSwatchStripWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _JeebVerifiedBadgeSwatchCell(Sizes.small),
            _JeebVerifiedBadgeSwatchCell(Sizes.large),
            _JeebVerifiedBadgeSwatchCell(Sizes.twoXLarge),
            _JeebVerifiedBadgeSwatchCell(Sizes.threeXLarge),
          ],
        ),
      ),
    );

/// The state that breaks for the only users this widget has: the label is empty.
/// `semanticsLabel` is `required`, but "required" only means *present* — there
@JeebPreview(group: 'core', name: 'Empty label (silent)', size: _jeebVerifiedBadgeGlyphBox)
Widget jeebVerifiedBadgeUnlabelled() => _jeebVerifiedBadgeHosted(
      'Empty semanticsLabel: announced as nothing',
      const _JeebVerifiedBadgeBadge(label: ''),
    );

/// The bare glyph on the plain surface, no name and no row around it.
/// The rendering where the ink problem is unmistakable, because there is nothing
@JeebPreview(group: 'core', name: 'Bare glyph on surface', size: _jeebVerifiedBadgeGlyphBox)
Widget jeebVerifiedBadgeBare() => _jeebVerifiedBadgeHosted(
      'Bare 20dp glyph on surface',
      const _JeebVerifiedBadgeBadge(),
    );
