import 'package:flutter/material.dart';

import 'jeeb_avatar.dart';

/// One identity in a [JeebAvatarStack].
///
/// Passing entries rather than built widgets is what keeps Ø30 / the 2px ring /
/// the −9 overlap / the fill rotation non-negotiable: a lane cannot half-adopt
/// the stack.
@immutable
class JeebAvatarEntry {
  const JeebAvatarEntry({this.initial = '', this.imageUrl, this.fill});

  /// The letter, or the display name to derive it from. Blank is legitimate —
  /// 04 has no offerer names and must NOT fabricate the board's `K N R`.
  final String initial;

  /// Profile photo; falls back to the initial disc.
  final String? imageUrl;

  /// Overrides the automatic fill. Null means: rotation when this identity is
  /// known, [JeebAvatarFill.dormant] when it is not.
  final JeebAvatarFill? fill;

  /// Whether anything is known about this person.
  bool get isKnown => initial.trim().isNotEmpty || (imageUrl?.trim().isNotEmpty ?? false);

  /// The fill for slot [index], honouring [fill] when the caller set one.
  JeebAvatarFill fillForIndex(int index) =>
      fill ?? (isKnown ? JeebAvatarFill.forIndex(index) : JeebAvatarFill.dormant);
}

/// The overlapped identity run (redesign-2026-08 §5 #9) — 04's replies card.
///
/// Ø30 discs, each with a 2px `colorScheme.surface` ring, overlapping by 9px
/// **directionally** (`PositionedDirectional`), so under `ar` the run grows from
/// the right and the later discs still paint on top.
///
/// The `+N` overflow stays the **caller's** widget in the [trailing] slot:
/// `replies_tab_test.dart:84/100` pin `+2` / `+6` against
/// `_OfferOverflowCount`, and the count is not the kit's to restyle.
class JeebAvatarStack extends StatelessWidget {
  const JeebAvatarStack({
    super.key,
    required this.avatars,
    this.diameter = JeebAvatar.stackDiameter,
    this.initialSize,
    this.overlap = JeebAvatar.stackOverlap,
    this.ringWidth = JeebAvatar.stackRingWidth,
    this.ringColor,
    this.trailing,
    this.trailingSpacing = defaultTrailingSpacing,
    this.identifier,
    this.semanticLabel,
  });

  /// `Spacing.twoXSmall` — the gap the shipped stack already puts before `+N`.
  static const double defaultTrailingSpacing = 4;

  /// The identities, in paint order: the last one sits on top.
  final List<JeebAvatarEntry> avatars;

  /// Disc diameter; 30 on the board.
  final double diameter;

  /// Initial font size; defaults to `JeebAvatar.initialSizeFor(diameter)`.
  final double? initialSize;

  /// How far each disc slides under its predecessor (04 `tpl 209`).
  final double overlap;

  /// Ring painted outside each disc.
  final double ringWidth;

  /// Ring ink; defaults to `colorScheme.surface`.
  final Color? ringColor;

  /// The caller's overflow widget (`+2`), laid out after the run.
  final Widget? trailing;

  /// Gap between the run and [trailing].
  final double trailingSpacing;

  /// Maestro/`find.bySemanticsIdentifier` id — 04 keeps
  /// `orders_replies_avatar_stack_$requestId` here.
  final String? identifier;

  /// Accessibility label; 04 keeps the total offer count.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget? overflow = trailing;
    if (avatars.isEmpty && overflow == null) return const SizedBox.shrink();

    final double outer = diameter + ringWidth * 2;
    final double step = outer - overlap;
    final double width =
        avatars.isEmpty ? 0 : outer + (avatars.length - 1) * step;

    Widget content = SizedBox(
      width: width,
      height: outer,
      child: Stack(
        children: <Widget>[
          for (int index = 0; index < avatars.length; index++)
            PositionedDirectional(
              start: index * step,
              child: JeebAvatar(
                initial: avatars[index].initial,
                imageUrl: avatars[index].imageUrl,
                fill: avatars[index].fillForIndex(index),
                diameter: diameter,
                initialSize: initialSize,
                ringWidth: ringWidth,
                ringColor: ringColor,
              ),
            ),
        ],
      ),
    );

    if (overflow != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          content,
          SizedBox(width: trailingSpacing),
          overflow,
        ],
      );
    }

    if (identifier == null && semanticLabel == null) return content;
    // Same shape as the shipped `_OfferAvatarStack` wrapper — no `container` /
    // `explicitChildNodes`, which is what `semantics_identifier_surfacing_test`
    // and `replies_tab_test` read today.
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      child: content,
    );
  }
}
