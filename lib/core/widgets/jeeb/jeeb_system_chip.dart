import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_text_styles.dart';

/// The three realized tones of a centred timeline chip (redesign-2026-08 §5 #17
/// plus 21 §2's countdown row).
enum JeebSystemChipTone {
  /// A **settled fact** — `Offer accepted · 9:12`. `surfaceContainerHigh` fill,
  /// pad `4/12`, ink periwinkle (`tpl 1249`). Also the date separator.
  filled,

  /// A **live / progress event** — `Karim is on the way · ETA 20 min`.
  /// `1.5px colorScheme.outline`, pad `5/13`, ink `onSurfaceVariant`
  /// (`tpl 1271`).
  outlined,

  /// **What is expiring right now** — the broadcast-window countdown.
  /// [outlined]'s geometry in `jeebRoles.accent` (21 §2, R5). The plan's table
  /// lists two tones; this third one is the row 21 §2 requires, kept here so the
  /// TTL indicator does not hand-roll a fourth pill.
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

  /// A settled fact: filled `surfaceContainerHigh`, pad `4/12`.
  const JeebSystemChip.filled({
    super.key,
    required this.label,
    this.identifier,
    this.semanticLabel,
    this.center = true,
  }) : tone = JeebSystemChipTone.filled;

  /// A live event: `1.5px colorScheme.outline`, pad `5/13`.
  const JeebSystemChip.outlined({
    super.key,
    required this.label,
    this.identifier,
    this.semanticLabel,
    this.center = true,
  }) : tone = JeebSystemChipTone.outlined;

  /// A countdown: [JeebSystemChip.outlined] in `jeebRoles.accent`.
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

  /// `1.5px` — the board's universal outline weight.
  static const double borderWidth = 1.5;

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
  /// `onSecondaryContainer` **is** the periwinkle (§4.1), which is why the
  /// filled chip does not read `JeebSemanticColors.mutedText` — that token is
  /// decorative-only and a chip label is text (21 §2.1).
  static Color inkOf(BuildContext context, JeebSystemChipTone tone) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    switch (tone) {
      case JeebSystemChipTone.filled:
        return scheme.onSecondaryContainer;
      case JeebSystemChipTone.outlined:
        return scheme.onSurfaceVariant;
      case JeebSystemChipTone.accent:
        return context.jeebRoles.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool filled = tone == JeebSystemChipTone.filled;

    final Color? border = filled
        ? null
        : tone == JeebSystemChipTone.accent
            ? context.jeebRoles.accent
            : scheme.outline;

    // The board is `box-sizing: border-box`, so the 1.5px stroke sits outside
    // the 5/13 inset. `Container` adds `decoration.padding` (the border
    // dimensions) on top of ours, so the correction is already made — folding
    // it in by hand here would double-count it.
    Widget chip = Container(
      padding: filled ? filledPadding : outlinedPadding,
      decoration: ShapeDecoration(
        color: filled ? scheme.surfaceContainerHigh : null,
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
