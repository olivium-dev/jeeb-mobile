import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import 'jeeb_navy_surface_card.dart';
import 'jeeb_surface_tone.dart';

/// The four realized states of a Jeeb card (MIDNIGHT sheet §3/§4).
enum JeebCardState {
  /// Rest glass: `glassFill` + 1px `glassBorder`, no blur, no shadow.
  normal,

  /// Delegates to `JeebNavySurfaceCard` — one state machine, so the navy
  /// variant cannot drift. Selection is a **fill swap, never a thicker border**.
  selected,

  /// R9's *lit* selection (`tpl 530`): `accentSelectedFill` + a 2px accent
  /// border + `JeebShadows.accentSelected`. The one selection that is a stroke.
  accentSelected,

  /// `opacity .75` **and** the action row dropped (11's third offer).
  ///
  /// An explicit named state rather than an ad-hoc `Opacity`, so §7.2-C4 stays
  /// a conscious choice: the owner decision is that **every offer must remain
  /// acceptable**, so no shipping screen should reach for this today.
  dormant,
}

/// The rest glass card (MIDNIGHT sheet §4) — the shape almost everything on
/// the board sits inside.
///
/// `glassFill` (white 7%) + a 1px `glassBorder`, radius `lg`, **no blur** (the
/// translucency is pre-baked) and no shadow — bar the lit state's glow.
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
    this.radius = JeebRadii.lg,
    this.padding = defaultPadding,
    this.borderColor,
    this.borderWidth = 1,
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
  /// both sides — R22 `margin: 0 16px`).
  const JeebOutlinedCard.grouped({
    super.key,
    required this.children,
    this.dividers = true,
    this.state = JeebCardState.normal,
    this.radius = JeebRadii.lg,
    this.padding = EdgeInsetsDirectional.zero,
    this.borderColor,
    this.borderWidth = 1,
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

  /// R9's lit selection is the one 2px stroke in the card system; the state
  /// owns the width so a consumer cannot half-apply it.
  static const double accentSelectedBorderWidth = 2;

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

  /// Which of the four states this card is in.
  final JeebCardState state;

  /// Corner radius — a [JeebRadii] rung; the board's cards are `lg`.
  final double radius;

  /// Content padding. Accepts `EdgeInsetsDirectional`; never hardcode
  /// left/right.
  final EdgeInsetsGeometry padding;

  /// Border ink; defaults to `glassBorder`. A recommended/lit frame overrides
  /// it to `jeebRoles.accent`.
  final Color? borderColor;

  /// Border width; 1 by default (sheet §4), 2 for a lit frame.
  final double borderWidth;

  /// Shadow used when [state] is selected; defaults to
  /// [JeebNavySurfaceCard.selectedShadow].
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
    final bool isNavySelected = state == JeebCardState.selected;
    final bool isAccentSelected = state == JeebCardState.accentSelected;
    final bool isSelected = isNavySelected || isAccentSelected;
    final JeebSurfaceToneData tone = switch (state) {
      JeebCardState.selected => JeebSurfaceToneData.navy(context),
      JeebCardState.accentSelected =>
        JeebSurfaceToneData.accentSelected(context),
      _ => JeebSurfaceToneData.light(context),
    };

    final Widget body = _body(tone);

    if (isNavySelected) {
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

    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final double stroke =
        isAccentSelected ? accentSelectedBorderWidth : borderWidth;
    // The board is `box-sizing: border-box`: the stroke sits OUTSIDE the 13/16
    // padding, so its width has to be folded in or content creeps under it.
    final EdgeInsetsGeometry contentPadding =
        padding.add(EdgeInsets.all(stroke));

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: isAccentSelected
            ? semantics.accentSelectedFill
            : semantics.glassFill,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ??
              (isAccentSelected
                  ? context.jeebRoles.accent
                  : semantics.glassBorder),
          width: stroke,
        ),
        // The lit state is the sole exception to "outlined cards carry no lift":
        // R9 draws a glow, not a shadow.
        boxShadow: isAccentSelected ? JeebShadows.accentSelected : null,
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
