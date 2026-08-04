import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';

/// The three realized tones of a centred timeline chip (redesign-2026-08 §5 #17
/// plus 21 §2's countdown row).
enum JeebSystemChipTone {
  /// A **settled fact** — `Offer accepted · 9:12`. Solid `surfaceContainerHigh`
  /// (kit ruling 4: chips on navy are solid, not glass), pad `4/12`, ink
  /// `inkSoft`. Also the date separator.
  filled,

  /// A **live / progress event** — `Karim is on the way · ETA 20 min`.
  /// Fill-less, 1px `colorScheme.outline`, pad `5/13`, ink `onSurfaceVariant`.
  outlined,

  /// **What is expiring right now** — the broadcast-window countdown.
  /// [outlined]'s geometry in the orange quartet: `accentTint` fill,
  /// `accentRing` stroke, `onAccentContainer` ink — orange as a live accent is
  /// budgeted (§2.2), but orange *ink* on navy is ~2.5:1 and is refused.
  accent,
}

/// The centred system chip (redesign-2026-08 §5 #17).
///
/// Consumers on 21: `system_message_bubble.dart` ([JeebSystemChip.outlined]),
/// the offer-accepted / offer-rejected rows and `chat_date_separator.dart`
/// ([JeebSystemChip.filled]), and `broadcast_ttl_indicator.dart`
/// ([JeebSystemChip.accent]).
///
/// The chip is **not** tone-aware ([JeebSurfaceTone]): it lives in the thread,
/// never inside a card, and its measured periwinkle ink deliberately differs
/// from the tone's `chipInk`.
class JeebSystemChip extends StatelessWidget {
  /// Pick the tone at runtime — `chat_message_bubble.dart` chooses between a
  /// settled fact and a live event from `MessageKind`.
  const JeebSystemChip({
    super.key,
    required this.label,
    required this.tone,
    this.identifier,
    this.semanticLabel,
    this.center = true,
  });

  /// A settled fact: solid `surfaceContainerHigh`, pad `4/12`.
  const JeebSystemChip.filled({
    super.key,
    required this.label,
    this.identifier,
    this.semanticLabel,
    this.center = true,
  }) : tone = JeebSystemChipTone.filled;

  /// A live event: `1px colorScheme.outline`, pad `5/13`.
  const JeebSystemChip.outlined({
    super.key,
    required this.label,
    this.identifier,
    this.semanticLabel,
    this.center = true,
  }) : tone = JeebSystemChipTone.outlined;

  /// A countdown: [JeebSystemChip.outlined]'s geometry in the orange quartet.
  const JeebSystemChip.accent({
    super.key,
    required this.label,
    this.identifier,
    this.semanticLabel,
    this.center = true,
  }) : tone = JeebSystemChipTone.accent;

  /// `padding: 4px 12px` (`tpl 1249`).
  static const EdgeInsetsGeometry filledPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 4);

  /// `padding: 5px 13px` (`tpl 1271`).
  static const EdgeInsetsGeometry outlinedPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 5);

  /// 1px — the Midnight stroke weight (token sheet §4); the light era drew 1.5.
  static const double borderWidth = 1;

  /// The chip copy. Build `"{event} · {time}"` at the call site and only when
  /// the message really has a server timestamp (21 §5.3).
  final String label;

  /// Which tone to paint.
  final JeebSystemChipTone tone;

  /// Maestro id, applied via an explicit `Semantics` wrapper.
  final String? identifier;

  /// Overrides the announced text; defaults to [label] merging up.
  final String? semanticLabel;

  /// Centres the chip in its parent (`align-self: center`). Pass false when the
  /// chip is placed inside a Row that already positions it.
  final bool center;

  /// 10.5/w700 — `jeebText.label` in the tone's ink.
  static TextStyle styleOf(BuildContext context, JeebSystemChipTone tone) =>
      context.jeebText.label.copyWith(color: inkOf(context, tone));

  /// The label ink for [tone].
  ///
  /// The accent chip reads `onAccentContainer` (`#FFB499`), not the accent
  /// itself: `#D73B00` as text on navy measures ~2.5:1 (token sheet §9).
  static Color inkOf(BuildContext context, JeebSystemChipTone tone) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    switch (tone) {
      case JeebSystemChipTone.filled:
        return _semanticsOf(context).inkSoft;
      case JeebSystemChipTone.outlined:
        return scheme.onSurfaceVariant;
      case JeebSystemChipTone.accent:
        return context.jeebRoles.onAccentContainer;
    }
  }

  /// The chip fill for [tone]; null on [JeebSystemChipTone.outlined].
  static Color? fillOf(BuildContext context, JeebSystemChipTone tone) {
    switch (tone) {
      case JeebSystemChipTone.filled:
        return Theme.of(context).colorScheme.surfaceContainerHigh;
      case JeebSystemChipTone.outlined:
        return null;
      case JeebSystemChipTone.accent:
        return _semanticsOf(context).accentTint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool filled = tone == JeebSystemChipTone.filled;

    final Color? border = filled
        ? null
        : tone == JeebSystemChipTone.accent
            ? _semanticsOf(context).accentRing
            : scheme.outline;

    // The board is `box-sizing: border-box`, so the 1px stroke sits outside
    // the 5/13 inset. `Container` adds `decoration.padding` (the border
    // dimensions) on top of ours, so the correction is already made — folding
    // it in by hand here would double-count it.
    Widget chip = Container(
      padding: filled ? filledPadding : outlinedPadding,
      decoration: ShapeDecoration(
        color: fillOf(context, tone),
        shape: border == null
            ? const StadiumBorder()
            : StadiumBorder(
                side: BorderSide(color: border, width: borderWidth),
              ),
      ),
      child: Text(
        label,
        style: styleOf(context, tone),
        textAlign: TextAlign.center,
      ),
    );

    if (identifier != null || semanticLabel != null) {
      chip = Semantics(
        identifier: identifier,
        label: semanticLabel,
        child: chip,
      );
    }

    if (!center) {
      return chip;
    }
    return Align(alignment: AlignmentDirectional.center, child: chip);
  }
}

/// Read defensively: harnesses that theme with a bare `ThemeData` carry no
/// extension, and a bare `!` would crash them.
JeebSemanticColors _semanticsOf(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
