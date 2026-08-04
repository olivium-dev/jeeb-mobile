import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_semantic_colors.dart';

/// Which Jeeb card surface a subtree is painted on (MIDNIGHT sheet §4).
enum JeebSurfaceKind {
  /// Rest glass: `glassFill` + 1px `glassBorder`. The app-wide default.
  /// (Named `light` for API stability — nothing is light in Midnight.)
  light,

  /// Emphasis glass: `glassFillEmphasis` + `glassBorderStrong` — heroes, strips
  /// and the *selected* state of an outlined card.
  navy,
}

/// The resolved ink/fill set a Jeeb card imposes on everything inside it.
///
/// Why this exists: an emphasis surface has to **re-tone every internal chip**,
/// or the first lane that forgets ships a solid-navy chip on a raised surface
/// it cannot be seen against. The two cards publish their tone and the kit's
/// children read it — the re-tone is structural, not remembered.
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
    this.accentSelected = false,
  });

  /// The rest-glass tone: ink `onSurface`, meta `mutedText`, chip = solid
  /// deep-navy pill (kit ruling #4 — chips on navy are never glass).
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

  /// The emphasis-glass tone. `inkSoft` is the board's meta ink on every raised
  /// surface (R9's selected tier, R22's lit frame); chips step up to white 14%.
  factory JeebSurfaceToneData.navy(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics = _semantics(context);
    return JeebSurfaceToneData(
      kind: JeebSurfaceKind.navy,
      titleInk: scheme.onSurface,
      mutedInk: semantics.inkSoft,
      chipFill: semantics.glassFillPressed,
      chipInk: scheme.onSurface,
      meterFill: scheme.onSurface,
      meterEmpty: scheme.onSurface.withValues(alpha: 0.25),
      dividerInk: scheme.outlineVariant,
    );
  }

  /// R9's accent-selected tone: [navy]'s inks (white title, `inkSoft` meta) on
  /// the orange-20% fill, and `kind: navy` so `onNavy` still reads true.
  factory JeebSurfaceToneData.accentSelected(BuildContext context) {
    final JeebSurfaceToneData navy = JeebSurfaceToneData.navy(context);
    return JeebSurfaceToneData(
      kind: navy.kind,
      titleInk: navy.titleInk,
      mutedInk: navy.mutedInk,
      chipFill: navy.chipFill,
      chipInk: navy.chipInk,
      meterFill: navy.meterFill,
      meterEmpty: navy.meterEmpty,
      dividerInk: navy.dividerInk,
      accentSelected: true,
    );
  }

  /// The surface this tone describes.
  final JeebSurfaceKind kind;

  /// Card titles, leading glyphs and any primary ink.
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

  /// True on R9's lit fill only. `kind` stays navy (so `onNavy` and every ink
  /// are unchanged); this discriminates the one case that must not re-tone.
  final bool accentSelected;

  /// True when the subtree sits on the emphasis surface.
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
          other.dividerInk == dividerInk &&
          other.accentSelected == accentSelected;

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
        accentSelected,
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
