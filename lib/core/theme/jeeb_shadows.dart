import 'package:flutter/material.dart';

/// The MIDNIGHT elevation / glow set (token sheet §7). On navy, depth is a
/// black drop shadow or a colored glow — never the light-era navy tint.
class JeebShadows {
  JeebShadows._();

  /// `0 14px 32px rgba(215,59,0,.45)` — the mic disc and orange CTAs.
  static const List<BoxShadow> ctaOrange = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.45),
      offset: Offset(0, 14),
      blurRadius: 32,
    ),
  ];

  /// `0 8px 20px rgba(215,59,0,.40)` — small orange pills (5×).
  static const List<BoxShadow> ctaOrangeSmall = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.40),
      offset: Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  /// `0 0 30px rgba(215,59,0,.18)` — halos at rest; the `jBreathe` target.
  static const List<BoxShadow> glowRest = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.18),
      blurRadius: 30,
    ),
  ];

  /// `0 0 10px rgba(215,59,0,.85)` — live / "Broadcasting" dots.
  static const List<BoxShadow> glowDot = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.85),
      blurRadius: 10,
    ),
  ];

  /// `0 0 14px rgba(59,178,115,.9)` — online / success dots.
  static const List<BoxShadow> glowDotSuccess = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(59, 178, 115, 0.90),
      blurRadius: 14,
    ),
  ];

  /// Recording mic: entry 0 is the spread-only ring, entry 1 is the lift.
  static const List<BoxShadow> micActive = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.20),
      spreadRadius: 10,
    ),
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.55),
      offset: Offset(0, 20),
      blurRadius: 46,
    ),
  ];

  /// `0 20px 46px rgba(0,0,0,.4)` — floating pill nav and sheets.
  static const List<BoxShadow> floatNav = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.40),
      offset: Offset(0, 20),
      blurRadius: 46,
    ),
  ];

  /// `0 2px 8px rgba(0,0,0,.4)` — small floating chips.
  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.40),
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  // LEGACY (§7/§10): navy-tinted, invisible on the field. Kept only because 29
  // kit/feature files still read them; M1 migrates and deletes each.

  /// LEGACY. `0 1px 3px rgba(11,19,81,.06)` + `0 1px 2px rgba(11,19,81,.04)`.
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

  /// LEGACY. `0 4px 16px rgba(11,19,81,.10)`.
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.10),
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// LEGACY. `0 -4px 24px rgba(11,19,81,.08)`.
  static const List<BoxShadow> sheet = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.08),
      offset: Offset(0, -4),
      blurRadius: 24,
    ),
  ];

  /// LEGACY. `0 6px 20px rgba(11,19,81,.28)`.
  static const List<BoxShadow> fab = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.28),
      offset: Offset(0, 6),
      blurRadius: 20,
    ),
  ];

  /// LEGACY. `0 10px 24px rgba(11,19,81,.28)`.
  static const List<BoxShadow> ctaNavy = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.28),
      offset: Offset(0, 10),
      blurRadius: 24,
    ),
  ];

  /// LEGACY. `0 12px 28px rgba(11,19,81,.30)`.
  static const List<BoxShadow> heroNavy = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.30),
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  /// LEGACY. `0 6px 16px rgba(11,19,81,.20)`.
  static const List<BoxShadow> bubbleOut = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.20),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  /// LEGACY. `0 6px 16px rgba(11,19,81,.18)`.
  static const List<BoxShadow> floatPill = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 19, 81, 0.18),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  /// LEGACY. `0 10px 24px rgba(215,59,0,.35)`.
  static const List<BoxShadow> accentBanner = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.35),
      offset: Offset(0, 10),
      blurRadius: 24,
    ),
  ];

  /// LEGACY. `0 0 0 5px rgba(215,59,0,.18)` — spread-only ring.
  static const List<BoxShadow> stepGlow = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(215, 59, 0, 0.18),
      spreadRadius: 5,
    ),
  ];

  /// LEGACY. `0 0 0 3px rgba(119,127,192,.35)` — the retired periwinkle.
  static const List<BoxShadow> focusRing = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(119, 127, 192, 0.35),
      spreadRadius: 3,
    ),
  ];
}
