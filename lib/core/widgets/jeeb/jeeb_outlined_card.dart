import 'package:flutter/material.dart';

import 'jeeb_navy_surface_card.dart';
import 'jeeb_surface_tone.dart';

/// The three realized states of a Jeeb card (redesign-2026-08 §5 #3).
enum JeebCardState {
  /// White fill, `1.5px colorScheme.outline`, no shadow.
  normal,

  /// Delegates to `JeebNavySurfaceCard` — one state machine, so the navy
  /// variant cannot drift. Selection is a **fill swap, never a thicker border**.
  selected,

  /// `opacity .75` **and** the action row dropped (11's third offer).
  ///
  /// An explicit named state rather than an ad-hoc `Opacity`, so §7.2-C4 stays
  /// a conscious choice: the owner decision is that **every offer must remain
  /// acceptable**, so no shipping screen should reach for this today.
  dormant,
}

/// The white card (redesign-2026-08 §5 #3) — the shape almost everything on
/// the board sits inside.
///
/// White fill, `1.5px colorScheme.outline`, radius 16/18/20, **no shadow ever**
/// (the design is outline-over-shadow: a white card with a shadow does not
/// exist on this board).
///
/// It is one state machine with [JeebNavySurfaceCard]: passing
/// [JeebCardState.selected] *is* the navy card, which re-tones the subtree via
/// [JeebSurfaceTone]. Consumers never re-tone chips by hand.
///
/// Two entry points:
///  * the unnamed constructor — one [child] plus an optional [actions] row;
///  * [JeebOutlinedCard.grouped] — a list of rows with 1px inset dividers
///    (20's settings groups, 23's Earnings/All-activity card).
class JeebOutlinedCard extends StatelessWidget {
  const JeebOutlinedCard({
    super.key,
    required this.child,
    this.actions,
    this.state = JeebCardState.normal,
    this.radius = 16,
    this.padding = defaultPadding,
    this.borderColor,
    this.borderWidth = 1.5,
    this.actionsSpacing = 12,
    this.selectedShadow,
    this.selectedRings = const <JeebNavyRing>[],
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : children = const <Widget>[],
        dividers = false;

  /// The grouped form: rows own their own padding, so [padding] defaults to
  /// zero and [dividers] to true (`1px colorScheme.outlineVariant`, inset 16 on
  /// both sides — 23 `tpl 53`).
  const JeebOutlinedCard.grouped({
    super.key,
    required this.children,
    this.dividers = true,
    this.state = JeebCardState.normal,
    this.radius = 16,
    this.padding = EdgeInsetsDirectional.zero,
    this.borderColor,
    this.borderWidth = 1.5,
    this.selectedShadow,
    this.selectedRings = const <JeebNavyRing>[],
    this.onTap,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  })  : child = null,
        actions = null,
        actionsSpacing = 0;

  /// 13/16 — the dominant card padding (08 `tpl 419`, 12, 18). 04 and 06 pass
  /// 16 all round; 24 passes 14/16.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13);

  /// The dormant opacity (§5 #3).
  static const double dormantOpacity = 0.75;

  /// Card body, for the unnamed constructor.
  final Widget? child;

  /// Rows, for [JeebOutlinedCard.grouped].
  final List<Widget> children;

  /// Optional action row below [child]. **Dropped in [JeebCardState.dormant]** —
  /// that is what makes "the action row removed" structural instead of a note
  /// each consumer has to honour.
  final Widget? actions;

  /// Gap between [child] and [actions].
  final double actionsSpacing;

  /// 1px inset dividers between [children] (grouped form only).
  final bool dividers;

  /// Which of the three states this card is in.
  final JeebCardState state;

  /// Corner radius in logical px — 16 (04 08 16 20 23) · 18 (11 22 24) ·
  /// 20 (10 19). Design-exact px are legal here (§4.4 two-tier rule).
  final double radius;

  /// Content padding. Accepts `EdgeInsetsDirectional`; never hardcode
  /// left/right.
  final EdgeInsetsGeometry padding;

  /// Border ink; defaults to `colorScheme.outline` (`#916F66`). 11's
  /// recommended offer overrides it to `colorScheme.primary`.
  final Color? borderColor;

  /// Border width; 1.5 by default, 2 for 11's recommended offer.
  final double borderWidth;

  /// Shadow used when [state] is selected; defaults to
  /// [JeebNavySurfaceCard.selectedShadow] (`0 10 22 rgba(11,19,81,.28)`).
  final List<BoxShadow>? selectedShadow;

  /// Decorative rings for the selected (navy) state. Empty on every board
  /// screen — selection is a fill swap, not an ornament.
  final List<JeebNavyRing> selectedRings;

  /// Makes the whole card tappable.
  final VoidCallback? onTap;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label for the card node.
  final String? semanticLabel;

  /// Accessibility hint.
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = state == JeebCardState.selected;
    final JeebSurfaceToneData tone = isSelected
        ? JeebSurfaceToneData.navy(context)
        : JeebSurfaceToneData.light(context);

    final Widget body = _body(tone);

    if (isSelected) {
      // One state machine: the selected white card IS the navy card, which
      // publishes the navy tone to the subtree on its own.
      return JeebNavySurfaceCard(
        radius: radius,
        padding: padding,
        shadow: selectedShadow ?? JeebNavySurfaceCard.selectedShadow,
        rings: selectedRings,
        onTap: onTap,
        identifier: identifier,
        semanticLabel: semanticLabel,
        semanticHint: semanticHint,
        selected: true,
        child: body,
      );
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    // The board is `box-sizing: border-box`: the 1.5px stroke sits OUTSIDE the
    // 13/16 padding. Flutter paints a decoration border over the child, so the
    // stroke width has to be folded into the padding or content creeps 1.5px
    // under the outline.
    final EdgeInsetsGeometry contentPadding =
        padding.add(EdgeInsets.all(borderWidth));

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? scheme.outline,
          width: borderWidth,
        ),
        // No boxShadow, by design. Outlined cards never carry one.
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: onTap == null
            ? Padding(padding: contentPadding, child: body)
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(padding: contentPadding, child: body),
                ),
              ),
      ),
    );

    if (state == JeebCardState.dormant) {
      surface = Opacity(opacity: dormantOpacity, child: surface);
    }

    if (identifier != null || semanticLabel != null || onTap != null) {
      surface = Semantics(
        identifier: identifier,
        label: semanticLabel,
        hint: semanticHint,
        button: onTap != null,
        // A tappable card is a selection candidate, so report both polarities;
        // a static card reports nothing.
        selected: onTap == null ? null : isSelected,
        // Both flags are mandatory (§7.5): without them this node swallows the
        // ids of everything the consumer nests inside.
        container: true,
        explicitChildNodes: true,
        child: surface,
      );
    }

    return JeebSurfaceTone(tone: tone, child: surface);
  }

  Widget _body(JeebSurfaceToneData tone) {
    if (child == null) {
      return _groupedRows(tone);
    }
    // Dormant drops the action row — the explicit half of the named state.
    if (actions == null || state == JeebCardState.dormant) {
      return child!;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        child!,
        SizedBox(height: actionsSpacing),
        actions!,
      ],
    );
  }

  Widget _groupedRows(JeebSurfaceToneData tone) {
    final List<Widget> rows = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0 && dividers) {
        rows.add(
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: ColoredBox(
              color: tone.dividerInk,
              child: const SizedBox(height: 1, width: double.infinity),
            ),
          ),
        );
      }
      rows.add(children[index]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
