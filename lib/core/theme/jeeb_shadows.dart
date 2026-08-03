import 'package:flutter/material.dart';

/// The Jeeb redesign elevation set (redesign-2026-08 §4.5).
///
/// Static consts rather than a `ThemeExtension`: the redesign is light-only
/// (§9.4), so every value here is brightness-independent and there is nothing
/// for a per-brightness variant to hold. Read them directly —
/// `boxShadow: JeebShadows.ctaNavy`.
///
/// The design is **outline-over-shadow**: an outlined card carries NO shadow,
/// ever. Shadows exist only on promoted navy / orange surfaces. If a surface
/// needs a border it uses `colorScheme.outline` at 1.5px instead of a lift.
///
/// Values are the realized screen values from the redesign board, which win
/// over `_ds/tokens/elevation.css` where the two disagree. Each entry maps
/// 1:1 onto its CSS source: `x y blur [spread] rgba(...)`.
class JeebShadows {
  JeebShadows._();

  /// `0 1px 3px rgba(11,19,81,.06)` + `0 1px 2px rgba(11,19,81,.04)` — the
  /// barely-there lift on the few resting cards that are not outlined.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.06),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.04),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// `0 4px 16px rgba(11,19,81,.10)` — sheet-adjacent raised bits.
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.10),
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// `0 -4px 24px rgba(11,19,81,.08)` — bottom sheets (lifts upward).
  static const List<BoxShadow> sheet = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.08),
      offset: Offset(0, -4),
      blurRadius: 24,
    ),
  ];

  /// `0 6px 20px rgba(11,19,81,.28)` — floating actions.
  static const List<BoxShadow> fab = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.28),
      offset: Offset(0, 6),
      blurRadius: 20,
    ),
  ];

  /// `0 10px 24px rgba(11,19,81,.28)` — the primary CTA pill and promoted
  /// navy cards.
  static const List<BoxShadow> ctaNavy = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.28),
      offset: Offset(0, 10),
      blurRadius: 24,
    ),
  ];

  /// `0 12px 28px rgba(11,19,81,.30)` — stat hero cards and code display tiles.
  static const List<BoxShadow> heroNavy = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.30),
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  /// `0 6px 16px rgba(11,19,81,.20)` — the outgoing chat bubble only.
  static const List<BoxShadow> bubbleOut = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.20),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  /// `0 6px 16px rgba(11,19,81,.18)` — the floating ETA pill over the map.
  static const List<BoxShadow> floatPill = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.18),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  /// `0 10px 24px rgba(215,59,0,.35)` — the at-door arrival banner, the one
  /// large orange fill the design allows.
  static const List<BoxShadow> accentBanner = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.35),
      offset: Offset(0, 10),
      blurRadius: 24,
    ),
  ];

  /// `0 0 0 5px rgba(215,59,0,.18)` — the halo around an active stepper node.
  /// Spread-only, so it reads as a ring rather than a drop shadow.
  static const List<BoxShadow> stepGlow = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.18),
      spreadRadius: 5,
    ),
  ];

  /// `0 0 0 3px rgba(119,127,192,.35)` — focused inputs. Spread-only ring.
  static const List<BoxShadow> focusRing = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(119, 127, 192, 0.35),
      spreadRadius: 3,
    ),
  ];
}
