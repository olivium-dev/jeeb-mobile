import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_semantic_colors.dart';

/// Which Jeeb card surface a subtree is painted on (redesign-2026-08 §5 #3/#4).
enum JeebSurfaceKind {
  /// White card, `1.5px colorScheme.outline`, flat. The app-wide default.
  light,

  /// `colorScheme.primary` fill — the *selected* state of an outlined card and
  /// every standalone navy hero/strip.
  navy,
}

/// The resolved ink/fill set a Jeeb card imposes on everything inside it.
///
/// Why this exists: §5 #4 requires the navy surface to **re-tone every internal
/// chip** (fill `rgba(255,255,255,.14)`, ink `rgba(255,255,255,.7)`, empty
/// meter dots `rgba(255,255,255,.25)`). Leaving that to each consumer means the
/// first lane that forgets ships a `surfaceContainerHigh` chip on navy. So the
/// two cards publish their tone and the kit's children read it — the re-tone is
/// structural, not remembered.
///
/// Read it with [JeebSurfaceTone.of]; it falls back to [light] when no Jeeb
/// card is above, so a chip works standalone too.
@immutable
class JeebSurfaceToneData {
  const JeebSurfaceToneData({
    required this.kind,
    required this.titleInk,
    required this.mutedInk,
    required this.chipFill,
    required this.chipInk,
    required this.meterFill,
    required this.meterEmpty,
    required this.dividerInk,
  });

  /// The white-card tone. Values are the measured light-surface readings
  /// (08 `tpl 420-435`): title navy, meta periwinkle, chip
  /// `surfaceContainerHigh` + navy w700, meter accent / `surfaceContainerHighest`.
  factory JeebSurfaceToneData.light(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics = _semantics(context);
    return JeebSurfaceToneData(
      kind: JeebSurfaceKind.light,
      titleInk: scheme.onSurface,
      mutedInk: semantics.mutedText,
      chipFill: scheme.surfaceContainerHigh,
      chipInk: scheme.onSurface,
      meterFill: context.jeebRoles.accent,
      meterEmpty: scheme.surfaceContainerHighest,
      dividerInk: scheme.outlineVariant,
    );
  }

  /// The navy-surface tone (08 `tpl 452-469`, the selected Standard tier).
  /// Every alpha here is measured, not invented.
  factory JeebSurfaceToneData.navy(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color onNavy = scheme.onPrimary;
    return JeebSurfaceToneData(
      kind: JeebSurfaceKind.navy,
      titleInk: onNavy,
      mutedInk: onNavy.withValues(alpha: 0.7),
      chipFill: onNavy.withValues(alpha: 0.14),
      chipInk: onNavy,
      meterFill: onNavy,
      meterEmpty: onNavy.withValues(alpha: 0.25),
      dividerInk: onNavy.withValues(alpha: 0.14),
    );
  }

  /// The surface this tone describes.
  final JeebSurfaceKind kind;

  /// Card titles and any primary ink (08's tier name).
  final Color titleInk;

  /// Subtitles, meta rows and meter captions.
  final Color mutedInk;

  /// Fill behind an internal pill/chip (SLA chip, tier chip).
  final Color chipFill;

  /// Ink on top of [chipFill].
  final Color chipInk;

  /// Filled meter dots / meter progress.
  final Color meterFill;

  /// Empty meter dots / meter track.
  final Color meterEmpty;

  /// The 1px inset rule between grouped rows.
  final Color dividerInk;

  /// True when the subtree sits on the navy surface.
  bool get onNavy => kind == JeebSurfaceKind.navy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JeebSurfaceToneData &&
          other.kind == kind &&
          other.titleInk == titleInk &&
          other.mutedInk == mutedInk &&
          other.chipFill == chipFill &&
          other.chipInk == chipInk &&
          other.meterFill == meterFill &&
          other.meterEmpty == meterEmpty &&
          other.dividerInk == dividerInk;

  @override
  int get hashCode => Object.hash(
        kind,
        titleInk,
        mutedInk,
        chipFill,
        chipInk,
        meterFill,
        meterEmpty,
        dividerInk,
      );
}

/// Publishes a [JeebSurfaceToneData] to a card's descendants.
///
/// `JeebOutlinedCard` and `JeebNavySurfaceCard` install this themselves — no
/// consumer should need to. Kit children read it via [JeebSurfaceTone.of].
class JeebSurfaceTone extends InheritedWidget {
  const JeebSurfaceTone({
    super.key,
    required this.tone,
    required super.child,
  });

  /// The tone imposed on [child].
  final JeebSurfaceToneData tone;

  /// The tone of the nearest enclosing Jeeb card, or the light tone when there
  /// is none — so a chip renders correctly outside a card too.
  static JeebSurfaceToneData of(BuildContext context) =>
      maybeOf(context) ?? JeebSurfaceToneData.light(context);

  /// The tone of the nearest enclosing Jeeb card, or null.
  static JeebSurfaceToneData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<JeebSurfaceTone>()?.tone;

  @override
  bool updateShouldNotify(JeebSurfaceTone oldWidget) => oldWidget.tone != tone;
}

/// `JeebSemanticColors` has no context accessor and a bare `!` read crashes
/// under harnesses that theme with `ThemeData.light()` (`wrapForTest`), so the
/// kit always reads it defensively.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.light();
