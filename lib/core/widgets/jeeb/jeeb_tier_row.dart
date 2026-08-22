import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';
import 'jeeb_outlined_card.dart';
import 'jeeb_price_meter.dart';
import 'jeeb_surface_tone.dart';
import 'jeeb_tier_chip.dart';

const BorderRadius _pillRadius =
    BorderRadius.all(Radius.circular(JeebRadii.pill));

/// Which of the two tier rows is being drawn.
enum JeebTierRowVariant {
  /// Screen 07 — one line of copy, a trailing radio, no price meter.
  compact,

  /// Screen 08 — two lines, an SLA chip, a vehicle line and a price meter.
  catalog,
}

/// The selectable tier row (redesign-2026-08 §5 #8).
///
/// **Two named constructors that must not be merged.** They are not one layout
/// with flags: 07 is a radio list (single line + trailing Ø22 indicator, no
/// meter), 08 is a comparison table (two lines + SLA chip + vehicle line + a
/// four-dot price meter, and the check moves to the end of the *second* row).
/// Collapsing them produced the "one row with eight optional slots" shape the
/// plan explicitly rejects.
///
/// Both sit on [JeebOutlinedCard], so selection is the one state machine shared
/// with every other card — here [JeebCardState.accentSelected], R9's lit form:
/// orange-20% fill, 2px accent border, `0 0 24 rgba(215,59,0,.25)` glow
/// (`tpl 530`). Both inherit the border-box padding correction and the
/// `JeebSurfaceTone` re-tone, so the SLA chip and the price meter invert on the
/// selected card without either screen asking.
///
/// **The two a11y contracts differ, on purpose.** 07's node is reproduced byte
/// for byte from `RequestTierCard` (`inMutuallyExclusiveGroup` + `checked`) —
/// `delivery_create_screens_test.dart:130,137` read `flagsCollection.isChecked`
/// off it. 08's node keeps `tier_card.dart:138-146`'s shape (`container` +
/// `selected`). Both wrap the card in `ExcludeSemantics` so the card's own node
/// and the `InkWell` cannot double up.
///
/// **The kit imports no tier enum.** The app has six of them (`TierId`,
/// `OrderTier`, `ClientRequestTier`, …); [mark] arrives as a `String` emoji and
/// [metaIcon] as an `IconData`, both resolved by the feature.
class JeebTierRow extends StatelessWidget {
  /// Screen 07's radio row.
  ///
  /// R9-measured: `JeebRadii.lg`, pad `14/16`, gap 12 — 20px emoji · title
  /// `16/w700` with an optional [badge] 8px after it · [summary] `12/w500`,
  /// one line, ellipsized · trailing Ø22 indicator.
  const JeebTierRow.compact({
    super.key,
    required this.mark,
    required this.title,
    required String summary,
    required this.selected,
    required this.onTap,
    required this.identifier,
    required this.semanticLabel,
    required this.selectedHint,
    this.badge,
    this.radius = JeebRadii.lg,
    this.padding = compactPadding,
  })  : variant = JeebTierRowVariant.compact,
        summaryText = summary,
        priceLevel = 0,
        // Catalog-only slots. Empty rather than nullable so the catalog body
        // never needs a `!`, and a mis-built compact row degrades to "no text"
        // instead of throwing.
        priceCaption = '',
        slaLabel = '',
        metaLabel = '',
        metaIcon = null,
        slaForceLtr = true;

  /// Screen 08's catalog row.
  ///
  /// Layout `tpl 419-435`: r16, pad `13/16`, gap 9 — row 1 is 17px emoji ·
  /// [name] `cardTitle` · optional [badgeLabel] · a `flex:1` gap · the
  /// [JeebPriceMeter]; row 2, 8px below, is the SLA chip · optional
  /// [metaIcon] · [metaLabel], with the 15px check pinned to the row end when
  /// selected.
  const JeebTierRow.catalog({
    super.key,
    required String emoji,
    required String name,
    required this.priceLevel,
    required this.priceCaption,
    required this.slaLabel,
    required this.metaLabel,
    required this.selected,
    required this.onTap,
    required this.identifier,
    required this.semanticLabel,
    required this.selectedHint,
    this.metaIcon,
    String? badgeLabel,
    this.slaForceLtr = true,
    this.radius = JeebRadii.lg,
    this.padding = catalogPadding,
  })  : variant = JeebTierRowVariant.catalog,
        mark = emoji,
        title = name,
        badge = badgeLabel,
        summaryText = null;

  /// 07: `14/16` (`tpl 356`).
  static const EdgeInsetsGeometry compactPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14);

  /// 08: `13/16` (`tpl 419`).
  static const EdgeInsetsGeometry catalogPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13);

  /// 07's emoji size (`tpl 357`).
  static const double compactMarkSize = 20;

  /// 08's emoji size (`tpl 421`).
  static const double catalogMarkSize = 17;

  /// 07's row gap (`tpl 356`).
  static const double compactSpacing = 12;

  /// 08's row gap (`tpl 420`).
  static const double catalogSpacing = 9;

  /// Diameter of 07's trailing indicator (`tpl 361`).
  static const double indicatorSize = 22;

  /// 08's trailing check glyph (`tpl 468`).
  static const double checkSize = 15;

  /// Badge pill padding — `2/8` on both screens (`tpl 375`, `tpl 455`).
  static const EdgeInsetsGeometry badgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2);

  /// Which constructor built this row.
  final JeebTierRowVariant variant;

  /// The tier emoji (`⚡ 🚀 🟦 🤝 🌿`). A `String`, because the kit cannot
  /// import a feature's tier enum. `JeebTierChip.emojiFor(slug)` resolves it.
  final String mark;

  /// The localized tier name.
  final String title;

  /// `Most picked` (07) / `Recommended` (08), or null. **The two are drawn
  /// differently** — see [_Badge].
  final String? badge;

  /// Whether this tier is the chosen one.
  final bool selected;

  /// Selection callback. Null draws the row inert — a read-only disclosure of
  /// a tier chosen elsewhere, with no ink and no tap target.
  final VoidCallback? onTap;

  /// Frozen Maestro id — `request_type_flash_radio` (07),
  /// `tier_selection_card_<id>` (08). Applied via an explicit `Semantics`
  /// wrapper, never OMDS's own `identifier:`.
  final String identifier;

  /// The full spoken description. Required: the visible copy is split across
  /// four nodes that `ExcludeSemantics` removes, so this is the only signal.
  final String semanticLabel;

  /// Announced as the hint only while [selected].
  final String selectedHint;

  /// Corner radius (`JeebRadii.lg` — R9 draws 18).
  final double radius;

  /// Content padding.
  final EdgeInsetsGeometry padding;

  /// 07 only — the one-line `Under 1 hour · Highest price · Priority pickup`.
  final String? summaryText;

  /// 08 only — how many of the four price dots are filled (flash 4 … eco 1).
  final int priceLevel;

  /// 08 only — the price wording (`Highest price`). Empty on a compact row.
  final String priceCaption;

  /// 08 only — the SLA band (`≤ 1 hr`, `Flexible`). Empty on a compact row.
  final String slaLabel;

  /// 08 only — the vehicle line (`Bike / scooter`). Empty on a compact row.
  final String metaLabel;

  /// 08 only — the optional vehicle glyph, 14px, muted ink.
  final IconData? metaIcon;

  /// 08 only. `≤ 1 hr` is a latin-numeric run that RTL reorders into `hr 1 ≥`,
  /// so the SLA chip is isolated to LTR by default (the precedent is
  /// `handover_code_display.dart:60-63`). Pass **false** for a pure-Arabic
  /// label such as `Flexible`/`مرن`, which must follow the ambient direction.
  final bool slaForceLtr;

  @override
  Widget build(BuildContext context) {
    final Widget card = JeebOutlinedCard(
      state: selected ? JeebCardState.accentSelected : JeebCardState.normal,
      radius: radius,
      padding: padding,
      onTap: onTap,
      // No identifier/label here on purpose: this row owns its own a11y node,
      // and the card's node is dropped by the ExcludeSemantics below.
      child: variant == JeebTierRowVariant.compact
          ? _CompactBody(row: this)
          : _CatalogBody(row: this),
    );

    switch (variant) {
      case JeebTierRowVariant.compact:
        // Byte-identical to `RequestTierCard.build` — two tests read
        // `flagsCollection.isChecked` off this node.
        return Semantics(
          identifier: identifier,
          inMutuallyExclusiveGroup: true,
          checked: selected,
          label: semanticLabel,
          hint: selected ? selectedHint : null,
          button: true,
          child: ExcludeSemantics(child: card),
        );
      case JeebTierRowVariant.catalog:
        // The shape `tier_card.dart:138-146` already ships.
        return Semantics(
          identifier: identifier,
          container: true,
          button: true,
          selected: selected,
          label: semanticLabel,
          hint: selected ? selectedHint : null,
          child: ExcludeSemantics(child: card),
        );
    }
  }
}

/// 07's single-line body. Built as its own widget so its `context` sits **below**
/// the card's `JeebSurfaceTone`, which is what makes the navy re-tone automatic.
class _CompactBody extends StatelessWidget {
  const _CompactBody({required this.row});

  final JeebTierRow row;

  @override
  Widget build(BuildContext context) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    final JeebTextStyles text = context.jeebText;

    return Row(
      children: <Widget>[
        Text(row.mark, style: const TextStyle(fontSize: JeebTierRow.compactMarkSize)),
        const SizedBox(width: JeebTierRow.compactSpacing),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      row.title,
                      // 16/w700. `cardTitle` is the 15.5/w700 token; only the
                      // size is a design-exact override (§4.4).
                      style: text.cardTitle.copyWith(
                        fontSize: 16,
                        color: tone.titleInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (row.badge != null) ...<Widget>[
                    const SizedBox(width: 8),
                    _Badge(label: row.badge!, variant: row.variant, tone: tone),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                row.summaryText!,
                // 12/w500 (R9). `bodySmall` is 12.5/w600, so both are
                // design-exact overrides — legal inside the kit (§4.4).
                style: text.bodySmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tone.mutedInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: JeebTierRow.compactSpacing),
        _RadioIndicator(selected: row.selected),
      ],
    );
  }
}

/// 07's Ø22 trailing indicator.
///
/// **Selected is an orange disc with a white check** — the R9 tile draws
/// `background: var(--jeeb-orange)` with `fill="#fff"`, so this is a tile-drawn
/// orange and inside the budget. Unselected is a 2px glass ring.
class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      final JeebSemanticColors semantics = _semantics(context);
      return Container(
        width: JeebTierRow.indicatorSize,
        height: JeebTierRow.indicatorSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: semantics.glassBorderVivid, width: 2),
        ),
      );
    }
    final JeebRoles roles = context.jeebRoles;
    return Container(
      width: JeebTierRow.indicatorSize,
      height: JeebTierRow.indicatorSize,
      decoration: BoxDecoration(color: roles.accent, shape: BoxShape.circle),
      child: Center(
        child: Icon(Icons.check, size: 13, color: roles.onAccent),
      ),
    );
  }
}

/// 08's two-line body. Same reason as [_CompactBody] for being a separate
/// widget: it must read the card's tone, not the ambient one.
class _CatalogBody extends StatelessWidget {
  const _CatalogBody({required this.row});

  final JeebTierRow row;

  @override
  Widget build(BuildContext context) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    final JeebTextStyles text = context.jeebText;

    // 11.5/w600 — `caption` exactly.
    final TextStyle metaStyle = text.caption.copyWith(color: tone.mutedInk);

    Widget slaChip = JeebTierChip.meta(label: row.slaLabel);
    if (row.slaForceLtr) {
      // `≤ 1 hr` is a latin-numeric run: RTL reorders it to `hr 1 ≥` without
      // this isolate. A pure-Arabic label opts out via `slaForceLtr: false`.
      slaChip = Directionality(textDirection: TextDirection.ltr, child: slaChip);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            // The emoji + name + badge group owns the `flex:1` slack, so the
            // meter is pinned to the row end and the badge stays next to the
            // name (`tpl 452-456`).
            Expanded(
              child: Row(
                children: <Widget>[
                  Text(
                    row.mark,
                    style: const TextStyle(fontSize: JeebTierRow.catalogMarkSize),
                  ),
                  const SizedBox(width: JeebTierRow.catalogSpacing),
                  Flexible(
                    child: Text(
                      row.title,
                      style: text.cardTitle.copyWith(color: tone.titleInk),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (row.badge != null) ...<Widget>[
                    const SizedBox(width: JeebTierRow.catalogSpacing),
                    _Badge(
                      label: row.badge!,
                      variant: row.variant,
                      tone: tone,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: JeebTierRow.catalogSpacing),
            // Delegated, never reimplemented: the on-navy dot inversion lives in
            // one place (§5 #21) and it reads the same tone this body does.
            JeebPriceMeter(level: row.priceLevel, caption: row.priceCaption),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            slaChip,
            const SizedBox(width: 8),
            if (row.metaIcon != null) ...<Widget>[
              Icon(row.metaIcon, size: 14, color: tone.mutedInk),
              const SizedBox(width: 8),
            ],
            // Expanded, not Flexible: it doubles as the `flex:1` gap that pins
            // the check to the row end (`tpl 467-468`).
            Expanded(
              child: Text(
                row.metaLabel,
                style: metaStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (row.selected) ...<Widget>[
              const SizedBox(width: 8),
              Icon(
                Icons.check,
                size: JeebTierRow.checkSize,
                color: tone.titleInk,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The two badges are **not** one treatment.
///
///  * 07 `Most picked` — `accentContainer` fill + `onAccentContainer` ink at
///    `10.5/w800`. R9 draws orange-28%-on-navy with `#FFB499` ink; the
///    container/onContainer quartet is that pair, AA-gated (§9).
///  * 08 `Recommended` — a **solid** accent pill with `onAccent` ink at
///    `10/w800` (`tpl 455`). The dominant board badge is this one.
///
/// On a plain navy surface the 07 badge falls back to the solid 08 treatment;
/// on R9's accent-selected fill it stays tinted (wave-A).
/// 07's default tier *is* flagged `recommended` in today's data
/// (`tier_repository.dart:100`), so selected-and-badged really happens.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.variant,
    required this.tone,
  });

  final String label;
  final JeebTierRowVariant variant;
  final JeebSurfaceToneData tone;

  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;
    // Wave-A: R9's lit row keeps the tinted badge — a solid accent pill on the
    // orange-20% fill loses its edge, which is what the navy fallback is for.
    final bool tinted = variant == JeebTierRowVariant.compact &&
        (!tone.onNavy || tone.accentSelected);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tinted ? roles.accentContainer : roles.accent,
        borderRadius: _pillRadius,
      ),
      child: Padding(
        padding: JeebTierRow.badgePadding,
        child: Text(
          label,
          // `badge` is 10.5/w800 — 07 exactly. 08 draws 10px; the kit may use
          // design-exact px (§4.4), and the 08 wiring asked for the difference
          // to be kept rather than averaged away.
          style: context.jeebText.badge.copyWith(
            fontSize: variant == JeebTierRowVariant.catalog ? 10 : null,
            color: tinted ? roles.onAccentContainer : roles.onAccent,
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

/// A bare `!` read crashes under harnesses themed with `ThemeData.light()`.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
