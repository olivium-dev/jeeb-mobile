import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import 'jeeb_surface_tone.dart';

/// The four realized waveform marks (redesign-2026-08 §5 #14).
///
/// These are **not** one mark at four sizes: bar count, bar width, gap,
/// baseline alignment and ink family all differ. Picking a mode is picking a
/// measured board element, which is why there is no geometry knob on
/// [JeebWaveform].
enum JeebWaveformMode {
  /// The small orange signature beside a voice request's title.
  /// 4 bars w3 gap 2, h 8/14/10/15, container h16, last bar at α.4.
  /// Measured on 04 `tpl 189-193`. Consumers: 01, 04, 10, 16.
  cardMark,

  /// The wider mark that sits at the end of 04's navy request hero.
  /// 5 bars w3 gap 3, h 9/17/11/20/10, container h24, white α.4/.55 with the
  /// two middle bars in accent. Measured on 04 `tpl 176-181`.
  onNavy,

  /// The voice-message mark inside a chat bubble.
  /// 5 bars w2.5 gap 2, h 8/14/10/15/9, container h16, navy at α.4–.7
  /// (white at the same alphas when [JeebWaveform.outgoing]).
  /// Measured on 21 `tpl 1258-1263`.
  inBubble,

  /// The recording mark above 05's timer readout.
  /// 10 bars w4 gap 4, h 12–38, container h40, **bottom-aligned**, accent with
  /// an alpha tail at both ends. Measured on 05 `tpl 257-267`.
  live,
}

/// The Jeeb voice mark (redesign-2026-08 §5 #14).
///
/// A static, purely decorative bar cluster. It renders exactly the four
/// measured profiles in [JeebWaveformMode] and exposes **no geometry
/// parameters** — bar count, width, gap and heights are the drift vector the
/// plan warns about, and every board deviation found so far (16's 3-bar mark,
/// 10's 7-bar mark, 01's 1px-shorter mark) is a board slip rather than a real
/// variant. See the note on 16/10 in the kit report.
///
/// **Static by design.** `live` does not animate. The app has no amplitude
/// source (05's cubit exposes `elapsed`, not levels), and a repeating ticker
/// would make `pumpAndSettle` hang in every consumer's existing widget test.
/// Motion, if it ever lands, belongs behind a real amplitude stream.
///
/// **RTL:** the bars are a plain [Row], so `Directionality` mirrors the run and
/// the faded tail always lands at the reading-end. Nothing here is positioned.
///
/// Emits no semantics node unless [identifier] or [semanticLabel] is given —
/// 05 and 04 own their own node around it (05 labels it, 04 excludes it).
class JeebWaveform extends StatelessWidget {
  const JeebWaveform({
    super.key,
    required this.mode,
    this.outgoing,
    this.identifier,
    this.semanticLabel,
  });

  /// 4-bar orange mark, container h16 — 01, 04, 10, 16.
  const JeebWaveform.cardMark({
    super.key,
    this.identifier,
    this.semanticLabel,
  })  : mode = JeebWaveformMode.cardMark,
        outgoing = null;

  /// 5-bar white/orange mark, container h24 — 04's navy request hero.
  const JeebWaveform.onNavy({
    super.key,
    this.identifier,
    this.semanticLabel,
  })  : mode = JeebWaveformMode.onNavy,
        outgoing = null;

  /// 5-bar mark inside a chat bubble, container h16 — 21.
  ///
  /// Leave [outgoing] null to inherit from [JeebSurfaceTone]; pass it only when
  /// the bubble does not publish a tone.
  const JeebWaveform.inBubble({
    super.key,
    this.outgoing,
    this.identifier,
    this.semanticLabel,
  }) : mode = JeebWaveformMode.inBubble;

  /// 10-bar recording mark, container h40, bottom-aligned — 05.
  const JeebWaveform.live({
    super.key,
    this.identifier,
    this.semanticLabel,
  })  : mode = JeebWaveformMode.live,
        outgoing = null;

  /// Container height for [JeebWaveformMode.cardMark] (04 `tpl 189`).
  static const double cardMarkHeight = 16;

  /// Container height for [JeebWaveformMode.onNavy] (04 `tpl 176`).
  static const double onNavyHeight = 24;

  /// Container height for [JeebWaveformMode.inBubble] (21 `tpl 1258`).
  static const double inBubbleHeight = 16;

  /// Container height for [JeebWaveformMode.live] (05 `tpl 257`).
  static const double liveHeight = 40;

  /// Bar corner radius — 9 on every bar of every mode, i.e. always a stadium.
  static const double barRadius = 9;

  /// Which measured mark to draw.
  final JeebWaveformMode mode;

  /// [JeebWaveformMode.inBubble] only: white ink instead of navy.
  ///
  /// Null (the default) resolves from `JeebSurfaceTone.of(context).onNavy`, so
  /// a bubble that publishes the navy tone re-inks its waveform with nothing
  /// for the consumer to remember. An explicit value always wins.
  final bool? outgoing;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// [Semantics] wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label. The mark is decorative; supply this only when the
  /// waveform *is* the thing being described (05's recording indicator).
  final String? semanticLabel;

  /// The laid-out height of [mode], for consumers reserving space.
  static double heightOf(JeebWaveformMode mode) => _specOf(mode).containerHeight;

  @override
  Widget build(BuildContext context) {
    final _JeebWaveformSpec spec = _specOf(mode);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = context.jeebRoles.accent;
    final bool onNavyBubble =
        outgoing ?? JeebSurfaceTone.of(context).onNavy;

    final List<Widget> bars = <Widget>[];
    for (int i = 0; i < spec.heights.length; i++) {
      if (i > 0) bars.add(SizedBox(width: spec.gap));
      bars.add(
        SizedBox(
          width: spec.barWidth,
          height: spec.heights[i],
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _inkFor(
                spec.inks[i],
                accent: accent,
                scheme: scheme,
                onNavyBubble: onNavyBubble,
              ).withValues(alpha: spec.alphas[i]),
              borderRadius: const BorderRadius.all(Radius.circular(barRadius)),
            ),
          ),
        ),
      );
    }

    Widget mark = SizedBox(
      height: spec.containerHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: spec.alignment,
        children: bars,
      ),
    );

    if (identifier != null || semanticLabel != null) {
      mark = Semantics(
        identifier: identifier,
        label: semanticLabel,
        // Mandatory pair (§7.5): without them this node would merge into
        // whatever the consumer wraps it in and lose its id.
        container: true,
        explicitChildNodes: true,
        child: mark,
      );
    }

    return mark;
  }

  Color _inkFor(
    _JeebBarInk ink, {
    required Color accent,
    required ColorScheme scheme,
    required bool onNavyBubble,
  }) {
    switch (ink) {
      case _JeebBarInk.accent:
        return accent;
      case _JeebBarInk.onPrimary:
        return scheme.onPrimary;
      case _JeebBarInk.bubble:
        return onNavyBubble ? scheme.onPrimary : scheme.primary;
    }
  }
}

/// Which token family a single bar is inked from.
enum _JeebBarInk {
  /// `jeebRoles.accent`.
  accent,

  /// `colorScheme.onPrimary` — the white bars of the on-navy mark.
  onPrimary,

  /// Navy or white depending on the bubble side / surface tone.
  bubble,
}

/// One measured mark profile. Private: exposing it would reopen the geometry
/// knob this widget exists to close.
@immutable
class _JeebWaveformSpec {
  const _JeebWaveformSpec({
    required this.containerHeight,
    required this.barWidth,
    required this.gap,
    required this.heights,
    required this.alphas,
    required this.inks,
    required this.alignment,
  });

  final double containerHeight;
  final double barWidth;
  final double gap;
  final List<double> heights;
  final List<double> alphas;
  final List<_JeebBarInk> inks;
  final CrossAxisAlignment alignment;
}

_JeebWaveformSpec _specOf(JeebWaveformMode mode) {
  switch (mode) {
    case JeebWaveformMode.cardMark:
      return _kCardMark;
    case JeebWaveformMode.onNavy:
      return _kOnNavy;
    case JeebWaveformMode.inBubble:
      return _kInBubble;
    case JeebWaveformMode.live:
      return _kLive;
  }
}

/// 04 `tpl 189-193` — `align-items: center`, gap 2, h16.
const _JeebWaveformSpec _kCardMark = _JeebWaveformSpec(
  containerHeight: JeebWaveform.cardMarkHeight,
  barWidth: 3,
  gap: 2,
  heights: <double>[8, 14, 10, 15],
  alphas: <double>[1, 1, 1, 0.4],
  inks: <_JeebBarInk>[
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
  ],
  alignment: CrossAxisAlignment.center,
);

/// 04 `tpl 176-181` — `align-items: center`, gap 3, h24. Bars 3 and 4 are the
/// accent pair; the rest are white at .4/.55.
const _JeebWaveformSpec _kOnNavy = _JeebWaveformSpec(
  containerHeight: JeebWaveform.onNavyHeight,
  barWidth: 3,
  gap: 3,
  heights: <double>[9, 17, 11, 20, 10],
  alphas: <double>[0.4, 0.55, 1, 1, 0.55],
  inks: <_JeebBarInk>[
    _JeebBarInk.onPrimary,
    _JeebBarInk.onPrimary,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.onPrimary,
  ],
  alignment: CrossAxisAlignment.center,
);

/// 21 `tpl 1258-1263` — `align-items: center`, gap 2, h16, navy α.5/.6/.7/.5/.4.
const _JeebWaveformSpec _kInBubble = _JeebWaveformSpec(
  containerHeight: JeebWaveform.inBubbleHeight,
  barWidth: 2.5,
  gap: 2,
  heights: <double>[8, 14, 10, 15, 9],
  alphas: <double>[0.5, 0.6, 0.7, 0.5, 0.4],
  inks: <_JeebBarInk>[
    _JeebBarInk.bubble,
    _JeebBarInk.bubble,
    _JeebBarInk.bubble,
    _JeebBarInk.bubble,
    _JeebBarInk.bubble,
  ],
  alignment: CrossAxisAlignment.center,
);

/// 05 `tpl 257-267` — `align-items: flex-end`, gap 4, h40. Ten bars, not the
/// plan's "~11"; the alpha tail is at both ends, solid through the middle five.
const _JeebWaveformSpec _kLive = _JeebWaveformSpec(
  containerHeight: JeebWaveform.liveHeight,
  barWidth: 4,
  gap: 4,
  heights: <double>[12, 22, 32, 18, 38, 26, 36, 16, 28, 12],
  alphas: <double>[0.35, 0.45, 1, 1, 1, 1, 1, 0.5, 0.4, 0.3],
  inks: <_JeebBarInk>[
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
    _JeebBarInk.accent,
  ],
  alignment: CrossAxisAlignment.end,
);
