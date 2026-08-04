import 'package:flutter/material.dart';

import '../../theme/jeeb_text_styles.dart';
import 'jeeb_surface_tone.dart';

/// The four-dot relative-price mark with its caption beneath
/// (redesign-2026-08 §5 #21).
///
/// `4 × Ø7` dots at gap 3, filled left-to-right, over a `10.5/w700` caption —
/// end-aligned, column gap 3 (08 `tpl 424-430`). It is split out of
/// `JeebTierRow` because its **on-navy inversion is where the bugs are**: on
/// the selected tier the dots become white / `rgba(255,255,255,.25)` and the
/// caption `rgba(255,255,255,.7)` (08 `tpl 457-463`).
///
/// That inversion is **not** a parameter. The widget reads
/// [JeebSurfaceTone] — which `JeebOutlinedCard`/`JeebNavySurfaceCard` publish
/// themselves — so a meter that moves onto a navy card re-tones structurally
/// and a lane cannot forget. There is deliberately no colour override.
///
/// The dots are excluded from semantics: they encode exactly what [caption]
/// says, and four unlabelled nodes per tier is noise. **The caption is the
/// accessibility signal**, which is why it is required.
class JeebPriceMeter extends StatelessWidget {
  const JeebPriceMeter({
    super.key,
    required this.level,
    required this.caption,
    this.dotCount = 4,
    this.dotSize = 7,
    this.dotGap = 3,
    this.captionGap = 3,
    this.identifier,
  });

  /// How many leading dots are filled, clamped to `0..dotCount`. 08's lexicon
  /// carries this as a per-tier `priceLevel` (flash 4 … eco 1).
  final int level;

  /// The relative-price wording (`Highest price`, `Balanced price`, …). Always
  /// an l10n string — it is the only thing a screen reader gets here.
  final String caption;

  /// Dot count. 4 on the board; a parameter only so the widget does not lie
  /// about being fixed at four.
  final int dotCount;

  /// Dot diameter (7).
  final double dotSize;

  /// Gap between dots (3).
  final double dotGap;

  /// Gap between the dot row and the caption (3).
  final double captionGap;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    final int lit = level.clamp(0, dotCount);

    final List<Widget> dots = <Widget>[];
    for (var index = 0; index < dotCount; index++) {
      if (index > 0) {
        dots.add(SizedBox(width: dotGap));
      }
      dots.add(
        SizedBox(
          width: dotSize,
          height: dotSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: index < lit ? tone.meterFill : tone.meterEmpty,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    final Widget meter = Column(
      mainAxisSize: MainAxisSize.min,
      // Directional: end is the right edge in LTR, the left edge in RTL.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // A plain Row, so the filled dots grow from the start edge and the
        // whole mark mirrors under RTL without any positional maths.
        ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: dots),
        ),
        SizedBox(height: captionGap),
        Text(
          caption,
          style: context.jeebText.label.copyWith(color: tone.mutedInk),
          textAlign: TextAlign.end,
        ),
      ],
    );

    if (identifier == null) {
      return meter;
    }
    return Semantics(
      identifier: identifier,
      container: true,
      child: meter,
    );
  }
}
