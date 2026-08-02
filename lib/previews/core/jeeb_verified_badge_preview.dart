/// Widget previews for [JeebVerifiedBadge] — run with
/// `flutter widget-preview start`.
///
/// The widget has no cubit, no repository and no asset load: it is one
/// [Icon] inside one [Semantics]. Everything it puts on screen is a function of
/// three inputs — the `size` it is given, the ambient
/// `colorScheme.secondaryContainer`, and the [Directionality] and text scale of
/// the host. So "empty / loading / error" do not exist here, and these previews
/// are network-free because there is nothing to fetch, not merely because
/// [jeebPreviewHost] guards the wire.
///
/// Its states are therefore HOST states plus the two parameters:
///
///  * the two rows it actually ships inside (`CustomerProfileHeader._NameRow`
///    and `DeliveryManProfileHeader._NameRow` — same layout, different label),
///  * the longest plausible name, which is where the row geometry gives way,
///  * the `size` range the public parameter allows,
///  * the label missing, which is the only way this widget can break for the
///    users it exists for.
///
/// **About the captions.** The badge renders no text — its `semanticsLabel` is
/// invisible by design — so `find.text` has nothing of the widget's own to bind
/// to, and a render test could otherwise pass while every state drew the same
/// 20dp seal. Each preview therefore carries a one-line caption naming the state
/// under review, used by the test only to *address* a state. The assertions that
/// actually prove the states differ are the measured badge box and the read-back
/// semantics label in
/// `test/previews/core/jeeb_verified_badge_preview_test.dart`.
///
/// Three things these previews surface, all in the widget rather than in the
/// previews — see the notes on the individual states:
///
///  * the glyph is inked with `colorScheme.secondaryContainer`, a *container*
///    role, which is brand navy on white in the light scheme but a dark tone on
///    an equally dark surface in `ColorScheme.fromSeed(_jeebNavy, dark)`; the AR
///    RTL dark rendering of every preview below is the badge nearly dissolved
///    into the page;
///  * `size` is a raw logical-pixel double and [Icon.applyTextScaling] is left
///    at its `false` default, so the seal stays 20dp while the name beside it
///    doubles — compare the EN light and EN 200% renderings of
///    [jeebVerifiedBadgeCustomerRow];
///  * the label is caller-supplied with no floor, and the two shipping callers
///    already disagree about what it says.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../core/widgets/jeeb_verified_badge.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// The width the name row actually gets inside `CustomerProfileHeader`: a 390pt
/// phone, `Spacing.xLarge` gutters on both sides, an `Sizes.eightXLarge` avatar
/// and a `Spacing.small` gap. `390 - 24 - 24 - 80 - 12 = 250`.
///
/// Pinned in the fixture rather than left to the canvas [Size] on purpose. The
/// canvas honours `size`, but the render tests pump onto a fixed 800 × 600
/// surface — a row left to fill its host would wrap on the phone and not wrap
/// under test, so the state that breaks would only break in one of the two
/// places it is looked at.
const double _identityWidth = 250;

/// Width for the size-scale strip, pinned for the same reason.
const double _swatchStripWidth = 300;

/// Canvas box for a name row. Generous on purpose: the 200% rendering wraps
/// even a short name inside a 250pt column, and a box that clipped it would
/// report a fixture overflow rather than anything about the badge.
const Size _rowBox = Size(390, 220);

/// Canvas box for the long-name row, which wraps at 1.0 and wraps a great deal
/// further at 200%.
const Size _wrappedRowBox = Size(390, 460);

/// Canvas box for the size strip and the two bare-glyph states.
const Size _glyphBox = Size(390, 140);

/// Renders [child] above a caption naming the state under review.
///
/// The caption is preview scaffolding, not widget output — see the library doc.
/// Deliberately tiny and single-purpose so the 200%-text rendering of the matrix
/// still shows the badge rather than a wall of label.
Widget _hosted(String caption, Widget child) => Center(
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
///
/// Copied from those two headers rather than imported, so this stays a preview
/// of the badge and not of the profile screens. If either header ever changes
/// its gap or its cross-axis alignment, this preview is wrong and says nothing —
/// which is the trade the illustration previews make too.
class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, required this.label});

  final String name;

  /// Resolves the localized label the way the real `_NameBadge` does, so the
  /// AR rendering announces Arabic rather than a hardcoded English string.
  final String Function(AppLocalizations) label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: _identityWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.secondaryContainer,
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
class _Badge extends StatelessWidget {
  const _Badge({this.size = Sizes.large, this.label});

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
class _SwatchCell extends StatelessWidget {
  const _SwatchCell(this.size);

  final double size;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: Sizes.threeXLarge,
            child: Center(child: _Badge(size: size)),
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
///
/// This is the one a designer signs off, and the rendering to compare across the
/// matrix rather than to admire in EN light:
///
///  * **EN 200% text** — the name goes from 24pt to 48pt and the seal stays
///    exactly 20 × 20. `size` is a raw double and [Icon] only multiplies it by
///    the text scaler when `applyTextScaling` is true, which nothing in
///    `AppTheme` or OMDS sets. At the accessibility ceiling the badge is under
///    half the height of the capital letter it sits next to.
///  * **AR RTL dark** — the row mirrors correctly (the [Row] is order-based, and
///    `Spacing.xSmall` is a symmetric [SizedBox], so there is no
///    `EdgeInsets.only` to get wrong), but the glyph itself is
///    `colorScheme.secondaryContainer` on `colorScheme.surface`: 17.13:1 in
///    light and 1.98:1 in dark, against the 3:1 WCAG 1.4.11 asks of a graphical
///    object.
@JeebPreview(group: 'core', name: 'Customer row (production)', size: _rowBox)
Widget jeebVerifiedBadgeCustomerRow() => _hosted(
      'Customer profile row',
      _NameRow(
        name: 'Sami Fawaz',
        label: (AppLocalizations l10n) =>
            l10n.customerProfileVerifiedBadgeLabel,
      ),
    );

/// The other shipping host: the jeeber profile header, same geometry, different
/// label.
///
/// Visually identical to the preview above — which is the point. The badge takes
/// its whole meaning from a caller-supplied string, and the two callers already
/// disagree: `customerProfileVerifiedBadgeLabel` is "Verified account" and
/// `deliveryManProfileVerifiedBadgeLabel` is "Verified". A sighted user sees one
/// badge across the app; a screen-reader user hears two different ones. Nothing
/// in the widget prevents that, and nothing in the canvas shows it — the render
/// test reads the semantics node back so the divergence is at least pinned.
@JeebPreview(group: 'core', name: 'Jeeber row (production)', size: _rowBox)
Widget jeebVerifiedBadgeJeeberRow() => _hosted(
      'Jeeber profile row',
      _NameRow(
        name: 'Kamal Hajj',
        label: (AppLocalizations l10n) =>
            l10n.deliveryManProfileVerifiedBadgeLabel,
      ),
    );

/// Longest plausible content: a full Lebanese compound name in the 250pt the
/// identity column actually gets.
///
/// The name has nowhere to go but down — production wraps it (`AutoDirectionText`
/// with no `maxLines`) rather than ellipsizing — so it becomes a multi-line
/// block, and `CrossAxisAlignment.center` parks the seal against the MIDDLE of
/// that block: floating in whitespace, with the name it verifies a line or more
/// above it. A verification mark reads as attached to the first line of a name;
/// here it detaches. Measured in the render test as
/// `badge.center.dy - name.top > one line height`.
///
/// The badge is never pushed off the trailing edge, which is the failure this
/// preview was written to look for: [Flexible] gives the text the leftovers, so
/// the 20dp seal and its 8pt gap are always reserved. That half is fine.
@JeebPreview(group: 'core', name: 'Long name (wraps)', size: _wrappedRowBox)
Widget jeebVerifiedBadgeLongName() => _hosted(
      'Long name wraps; badge centres on the block',
      _NameRow(
        name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        label: (AppLocalizations l10n) =>
            l10n.customerProfileVerifiedBadgeLabel,
      ),
    );

/// The full range of the public `size` parameter, side by side.
///
/// Only `Sizes.large` (20dp, the default) ships today; both callers take it.
/// The strip exists because `size` is public and unconstrained, and because it
/// shows what the 200% rendering of [jeebVerifiedBadgeCustomerRow] *would* look
/// like if the icon scaled with text: 20dp → 40dp is the right-hand swatch.
///
/// The left-hand swatch is the other end: `Sizes.small` (12dp) is the smallest
/// step the token scale offers above `xSmall`, and it is where the seal's
/// serrated edge and the check inside it have to survive on a 1× screen. Look at
/// it before reaching for a compact variant in a list row — nothing ships one
/// today, and the whole strip is the one input to this widget that no other
/// preview or test exercises.
@JeebPreview(group: 'core', name: 'Size scale 12-40dp', size: _glyphBox)
Widget jeebVerifiedBadgeSizeScale() => _hosted(
      'Size scale: 12 / 20 / 32 / 40 dp',
      const SizedBox(
        width: _swatchStripWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _SwatchCell(Sizes.small),
            _SwatchCell(Sizes.large),
            _SwatchCell(Sizes.twoXLarge),
            _SwatchCell(Sizes.threeXLarge),
          ],
        ),
      ),
    );

/// The state that breaks for the only users this widget has: the label is empty.
///
/// `semanticsLabel` is `required`, but "required" only means *present* — there
/// is no assert, no fallback and no default. A caller that passes `''` (or an
/// ARB key that has not been translated yet, which resolves to an empty string
/// rather than to the English fallback) still gets a node flagged `image: true`
/// and announced as nothing at all. Pixel-identical to
/// [jeebVerifiedBadgeCustomerRow]'s badge, so no amount of looking at the canvas
/// finds it; the render test reads the label back instead.
///
/// This is not hypothetical for a badge whose entire output is a glyph: the
/// label IS the widget for a screen-reader user, and the widget accepts its own
/// absence silently.
@JeebPreview(group: 'core', name: 'Empty label (silent)', size: _glyphBox)
Widget jeebVerifiedBadgeUnlabelled() => _hosted(
      'Empty semanticsLabel: announced as nothing',
      const _Badge(label: ''),
    );

/// The bare glyph on the plain surface, no name and no row around it.
///
/// The rendering where the ink problem is unmistakable, because there is nothing
/// else on the page to compare against. `colorScheme.secondaryContainer` is a
/// *container* role — `app_theme.dart` says in as many words that anything which
/// wants to PAINT must use a foreground role, never a `*Container` one. The
/// light scheme hard-codes that role to the brand navy so it happens to work
/// (17.13:1 on white); the dark scheme is generated by
/// `ColorScheme.fromSeed(_jeebNavy, dark)`, where the same role is exactly what
/// M3 means by a container — a dark fill meant to sit *behind* ink, here used as
/// the ink, on a surface of nearly the same tone.
@JeebPreview(group: 'core', name: 'Bare glyph on surface', size: _glyphBox)
Widget jeebVerifiedBadgeBare() => _hosted(
      'Bare 20dp glyph on surface',
      const _Badge(),
    );
