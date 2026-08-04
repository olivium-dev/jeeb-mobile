import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accessibility/accessibility.dart';
import '../../theme/app_theme.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import '../../theme/jeeb_text_styles.dart';
import '../directional_icons.dart';

/// The three realized leading treatments of the in-body top bar
/// (redesign-2026-08 §5 #1). **A mode, never a bool** — `close` is not
/// "back with a different glyph", and `identity` adds a whole avatar block.
enum JeebTopBarLeading {
  /// Ø40 glass circle + 19px ink `DirectionalIcons.back`
  /// (05 06 07 08 09 10 11 12 13 18 20 22 23).
  back,

  /// Same circle, 18px ink `×` (17 — the only consumer).
  close,

  /// Back circle **plus** a Ø42 avatar and a name/sub stack (21).
  identity,
}

/// How the leading/trailing circles are painted.
enum JeebTopBarLeadingTreatment {
  /// Glass fill + 1px glass stroke, no shadow. The board default.
  tonal,

  /// The same glass + [JeebShadows.overlay] — a circle floating over a map
  /// (09's `/capture-location`, 12's map surface).
  floating,
}

/// The two realized title scales of the `back`/`close` bar.
///
/// `identity` has its own scale and ignores this.
enum JeebTopBarTitleScale {
  /// Title `jeebText.h2` (20/w700), subtitle 12/w600 — 08 11 17 18 20 22 23.
  standard,

  /// Title `jeebText.titleProminent` (17/w700), subtitle 12/w600 — 12 only,
  /// whose title is a long item summary sharing the row with a trailing
  /// action and must ellipsize. Named in the plan's own type table
  /// ("two-line bar titles") so this is not a fork.
  compact,
}

/// A Ø40 circular action in the top bar's **real trailing slot**
/// (12's chat glyph, 21's phone glyph).
@immutable
class JeebTopBarAction {
  const JeebTopBarAction({
    required this.icon,
    required this.onPressed,
    this.identifier,
    this.semanticLabel,
    this.iconSize = 19,
  });

  /// Glyph. Mirror-sensitive glyphs must be resolved by the caller through
  /// `DirectionalIcons` — the kit cannot know which ones are directional.
  final IconData icon;

  /// Tap handler.
  final VoidCallback onPressed;

  /// Maestro id, applied via an explicit `Semantics(identifier: …)` wrapper
  /// (12 `order_summary_open_chat`).
  final String? identifier;

  /// Accessibility label for the circle.
  final String? semanticLabel;

  /// 19px on 12, 18px on 21.
  final double iconSize;
}

/// The in-body top bar (redesign-2026-08 §5 #1) — the header shape on 17 of
/// the 24 screens, and the owner of the `<screen>_back` identifier contract.
///
/// It is a **body row**, not a Material app bar: no elevation, no surface
/// tint, no centred title. Mount it as the first child of the screen's
/// `Column` and set `Scaffold(appBar: null)`.
///
/// Back behaviour is **guarded by default**: with no [onLeadingPressed] the
/// bar calls `Navigator.maybeOf(context)?.maybePop()`. An unguarded
/// `Navigator.pop` once shipped a blank surface
/// (`test/core/router/back_button_blank_surface_test.dart`), so the guard is
/// the kit's default rather than 17 lanes' responsibility. The kit never
/// imports go_router — screens with a router fallback
/// (`canPop ? pop : go('/')`) pass their own callback.
///
/// **04, 16 and 19 do not use this widget.** 04/16 use [JeebProfileHeader];
/// 19 is a bare padded title (its own doc refuses a fourth leading mode).
///
/// ## It also owns the status-bar chrome (M6 L15)
///
/// Because this is a body row and not an `AppBar`, `appBarTheme.
/// systemOverlayStyle` never reaches the ~44 screens that mount it — they were
/// shipping whatever chrome the previous route left behind. The bar therefore
/// publishes [AppTheme.systemOverlayStyle] itself through an unsized
/// [AnnotatedRegion], so white status glyphs over navy come with the widget
/// instead of with 44 call-site edits. See [overlayStyle].
class JeebTopBar extends StatelessWidget {
  const JeebTopBar({
    super.key,
    this.leading = JeebTopBarLeading.back,
    this.leadingTreatment = JeebTopBarLeadingTreatment.tonal,
    this.title,
    this.titleSlot,
    this.titleScale = JeebTopBarTitleScale.standard,
    this.subtitle,
    this.subtitleSlot,
    this.subtitleIdentifier,
    this.avatar,
    this.avatarIdentifier,
    this.onAvatarPressed,
    this.trailing,
    this.identifier,
    this.leadingTooltip,
    this.onLeadingPressed,
    this.padding = defaultPadding,
    this.gap,
  })  : assert(
          title == null || titleSlot == null,
          'Pass title (String) or titleSlot (Widget), never both.',
        ),
        assert(
          subtitle == null || subtitleSlot == null,
          'Pass subtitle (String) or subtitleSlot (Widget), never both.',
        ),
        assert(
          avatar == null || leading == JeebTopBarLeading.identity,
          'The avatar slot belongs to JeebTopBarLeading.identity only.',
        );

  /// `leading: back` — the dominant form.
  const JeebTopBar.back({
    super.key,
    this.title,
    this.titleSlot,
    this.titleScale = JeebTopBarTitleScale.standard,
    this.subtitle,
    this.subtitleSlot,
    this.subtitleIdentifier,
    this.trailing,
    this.identifier,
    this.leadingTooltip,
    this.onLeadingPressed,
    this.leadingTreatment = JeebTopBarLeadingTreatment.tonal,
    this.padding = defaultPadding,
    this.gap,
  })  : leading = JeebTopBarLeading.back,
        avatar = null,
        avatarIdentifier = null,
        onAvatarPressed = null,
        assert(
          title == null || titleSlot == null,
          'Pass title (String) or titleSlot (Widget), never both.',
        ),
        assert(
          subtitle == null || subtitleSlot == null,
          'Pass subtitle (String) or subtitleSlot (Widget), never both.',
        );

  /// `leading: close` — 17's `×`, the only consumer on the board.
  const JeebTopBar.close({
    super.key,
    this.title,
    this.titleSlot,
    this.titleScale = JeebTopBarTitleScale.standard,
    this.subtitle,
    this.subtitleSlot,
    this.subtitleIdentifier,
    this.trailing,
    this.identifier,
    this.leadingTooltip,
    this.onLeadingPressed,
    this.leadingTreatment = JeebTopBarLeadingTreatment.tonal,
    this.padding = defaultPadding,
    this.gap,
  })  : leading = JeebTopBarLeading.close,
        avatar = null,
        avatarIdentifier = null,
        onAvatarPressed = null,
        assert(
          title == null || titleSlot == null,
          'Pass title (String) or titleSlot (Widget), never both.',
        ),
        assert(
          subtitle == null || subtitleSlot == null,
          'Pass subtitle (String) or subtitleSlot (Widget), never both.',
        );

  /// `leading: identity` — 21's chat header: back circle + Ø42 avatar +
  /// name 16/w700 + sub 11.5/w600 + a trailing circle.
  const JeebTopBar.identity({
    super.key,
    this.title,
    this.titleSlot,
    this.subtitle,
    this.subtitleSlot,
    this.subtitleIdentifier,
    this.avatar,
    this.avatarIdentifier,
    this.onAvatarPressed,
    this.trailing,
    this.identifier,
    this.leadingTooltip,
    this.onLeadingPressed,
    this.leadingTreatment = JeebTopBarLeadingTreatment.tonal,
    this.padding = defaultPadding,
    this.gap,
  })  : leading = JeebTopBarLeading.identity,
        titleScale = JeebTopBarTitleScale.standard,
        assert(
          title == null || titleSlot == null,
          'Pass title (String) or titleSlot (Widget), never both.',
        ),
        assert(
          subtitle == null || subtitleSlot == null,
          'Pass subtitle (String) or subtitleSlot (Widget), never both.',
        );

  /// The board's `padding: 14px 24px 0`, directional.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.fromSTEB(24, 14, 24, 0);

  /// The visible circle diameter (`tpl 649/719/987/1233`).
  static const double circleDiameter = 40;

  /// The Ø42 avatar the `identity` slot expects (`tpl 1236`).
  static const double identityAvatarDiameter = 42;

  /// Back glyph size (R7/R10/R11/R13/R20 all draw 19).
  static const double backGlyphSize = 19;

  /// Close glyph size (`tpl 988` — 18, not 20).
  static const double closeGlyphSize = 18;

  /// The 1px glass stroke every circle carries (token sheet §4).
  static const double glassBorderWidth = 1;

  /// The chrome the bar publishes — the app's one ratified overlay style.
  static const SystemUiOverlayStyle overlayStyle = AppTheme.systemOverlayStyle;

  /// How far the 48dp tap target overhangs the Ø40 circle on each side.
  ///
  /// The bar lifts every circle to [A11y.minTapTargetSize] and then subtracts
  /// this from the gutter and the neighbouring gap, so the *visible* geometry
  /// still measures the board's `14/24/0` and 12–14 gaps. Consumers therefore
  /// pass the design numbers and get both.
  static const double tapOverhang =
      (A11y.minTapTargetSize - circleDiameter) / 2;

  /// Which leading treatment this bar renders.
  final JeebTopBarLeading leading;

  /// Tonal (default) or floating-over-a-map.
  final JeebTopBarLeadingTreatment leadingTreatment;

  /// Title copy. Nullable — 03 renders the bare back circle with no title.
  /// Mutually exclusive with [titleSlot].
  final String? title;

  /// Title as a widget, for the rare rich title. Mutually exclusive with
  /// [title].
  final Widget? titleSlot;

  /// Which title/subtitle scale to use. Ignored by `identity`.
  final JeebTopBarTitleScale titleScale;

  /// Subtitle copy — the "two-line variant". Mutually exclusive with
  /// [subtitleSlot].
  final String? subtitle;

  /// Subtitle as a widget. 12's subtitle is five semantics leaves, not one
  /// `Text`, and 21's is a `★ 4.9 · …` run — hence a real slot.
  final Widget? subtitleSlot;

  /// Maestro id for the subtitle, rendered with `header: true`
  /// (17 `offer_composer_order_ref`).
  final String? subtitleIdentifier;

  /// Ø42 avatar widget for `identity` mode (kit `JeebAvatar`). Null is legal —
  /// 21 gates it on its existing `showAvatar` flag.
  final Widget? avatar;

  /// Maestro id for the avatar slot (21 `chat_detail_avatar`).
  final String? avatarIdentifier;

  /// Makes the avatar slot tappable (21's `onAvatarTap`). Null leaves the slot
  /// inert so a consumer can own its own gesture.
  final VoidCallback? onAvatarPressed;

  /// The real trailing slot: one Ø40 circular action.
  final JeebTopBarAction? trailing;

  /// Maestro id for the **leading circle** — the `<screen>_back` contract.
  /// Reuse the screen's existing value; never rename one.
  final String? identifier;

  /// Tooltip/label for the leading circle. Defaults to the Material
  /// back/close tooltip for the active locale.
  final String? leadingTooltip;

  /// Leading tap handler. Null falls back to the guarded
  /// `Navigator.maybeOf(context)?.maybePop()`.
  final VoidCallback? onLeadingPressed;

  /// Row padding. Directional; defaults to [defaultPadding].
  final EdgeInsetsGeometry padding;

  /// Inter-element gap. Null resolves to the measured value: 12 when the row
  /// carries an identity block or a trailing action (12 `tpl 718`,
  /// 21 `tpl 1232`), else 14 (11 `tpl 648`, 17 `tpl 986`).
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final double resolvedGap = gap ??
        (leading == JeebTopBarLeading.identity || trailing != null ? 12 : 14);
    final bool hasTitleBlock = title != null ||
        titleSlot != null ||
        subtitle != null ||
        subtitleSlot != null;
    final bool avatarIsTappable =
        leading == JeebTopBarLeading.identity && onAvatarPressed != null;

    final List<Widget> row = <Widget>[_leadingCircle(context)];

    if (leading == JeebTopBarLeading.identity && avatar != null) {
      row
        ..add(_gapBox(resolvedGap - tapOverhang))
        ..add(_avatarSlot())
        ..add(
          _gapBox(resolvedGap - (avatarIsTappable ? tapOverhang : 0)),
        );
      if (hasTitleBlock) {
        row.add(Expanded(child: _titleBlock(context)));
      } else {
        row.add(const Spacer());
      }
    } else if (hasTitleBlock) {
      row
        ..add(_gapBox(resolvedGap - tapOverhang))
        ..add(Expanded(child: _titleBlock(context)));
    } else {
      // 03 renders the circle alone; the spacer still pushes any trailing
      // action to the end edge.
      row.add(const Spacer());
    }

    if (trailing != null) {
      row
        ..add(_gapBox(resolvedGap - tapOverhang))
        ..add(_actionCircle(context, trailing!));
    }

    // `sized: false` is load-bearing: the bar sits BELOW the status bar, and
    // the sized form is only found when the query point lands inside its rect.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      sized: false,
      child: Padding(
        padding: _compensatedPadding(context),
        child: Row(children: row),
      ),
    );
  }

  /// The gaps and the gutter are quoted as **visible** distances, but the
  /// circles carry a [tapOverhang] of invisible 48dp tap target on each side.
  /// Subtracting it here is what keeps the Ø40 circle on the board's 24px
  /// gutter with a real 48dp target, instead of choosing one or the other.
  Widget _gapBox(double width) => SizedBox(width: width < 0 ? 0 : width);

  EdgeInsetsGeometry _compensatedPadding(BuildContext context) {
    final EdgeInsets resolved = padding.resolve(Directionality.of(context));
    // Bottom is left alone: the board draws no bottom padding, so the only
    // effect of the target is 4px of extra air under the bar.
    return EdgeInsets.fromLTRB(
      _atLeastZero(resolved.left - tapOverhang),
      _atLeastZero(resolved.top - tapOverhang),
      _atLeastZero(resolved.right - tapOverhang),
      resolved.bottom,
    );
  }

  static double _atLeastZero(double value) => value < 0 ? 0 : value;

  Widget _leadingCircle(BuildContext context) {
    final bool isClose = leading == JeebTopBarLeading.close;
    final MaterialLocalizations? l10n =
        Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
    final String? label = leadingTooltip ??
        (isClose ? l10n?.closeButtonTooltip : l10n?.backButtonTooltip);

    return _circle(
      context: context,
      icon: isClose ? Icons.close : DirectionalIcons.back(context),
      iconSize: isClose ? closeGlyphSize : backGlyphSize,
      onTap: () => _handleLeading(context),
      nodeIdentifier: identifier,
      semanticLabel: label,
      treatment: leadingTreatment,
    );
  }

  Widget _actionCircle(BuildContext context, JeebTopBarAction action) {
    return _circle(
      context: context,
      icon: action.icon,
      iconSize: action.iconSize,
      onTap: action.onPressed,
      nodeIdentifier: action.identifier,
      semanticLabel: action.semanticLabel,
      treatment: leadingTreatment,
    );
  }

  Widget _circle({
    required BuildContext context,
    required IconData icon,
    required double iconSize,
    required VoidCallback onTap,
    required String? nodeIdentifier,
    required String? semanticLabel,
    required JeebTopBarLeadingTreatment treatment,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors glass = _semantics(context);
    final bool floating = treatment == JeebTopBarLeadingTreatment.floating;

    final Widget circle = DecoratedBox(
      decoration: BoxDecoration(
        color: glass.glassFillEmphasis,
        shape: BoxShape.circle,
        border: Border.all(
          color: glass.glassBorderStrong,
          width: glassBorderWidth,
        ),
        boxShadow: floating ? JeebShadows.overlay : null,
      ),
      child: SizedBox.square(
        dimension: circleDiameter,
        child: Center(
          child: Icon(icon, size: iconSize, color: scheme.onSurface),
        ),
      ),
    );

    return Semantics(
      identifier: nodeIdentifier,
      label: semanticLabel,
      button: true,
      container: true,
      // MinTapTarget lifts the Ø40 circle to the 48dp minimum. It is the
      // repo's own idiom (`lib/core/accessibility/accessibility.dart`) and the
      // one screen 11's review prescribes by name.
      child: MinTapTarget(onTap: onTap, child: circle),
    );
  }

  Widget _avatarSlot() {
    Widget slot = avatar!;
    if (onAvatarPressed != null) {
      slot = MinTapTarget(onTap: onAvatarPressed!, child: slot);
    }
    if (avatarIdentifier == null) {
      return slot;
    }
    return Semantics(
      identifier: avatarIdentifier,
      container: true,
      explicitChildNodes: true,
      child: slot,
    );
  }

  Widget _titleBlock(BuildContext context) {
    final Widget? titleWidget = _title(context);
    final Widget? subtitleWidget = _subtitle(context);

    if (subtitleWidget == null) {
      return titleWidget ?? const SizedBox.shrink();
    }
    if (titleWidget == null) {
      return subtitleWidget;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      // `start` is directional: it resolves to the right edge under RTL.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[titleWidget, subtitleWidget],
    );
  }

  Widget? _title(BuildContext context) {
    if (titleSlot != null) return titleSlot;
    if (title == null) return null;

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebTextStyles text = context.jeebText;
    final TextStyle style = switch (leading) {
      // Identity: 16/w700. `cardTitle` is 15.5/w700 — inside the ≤0.5px
      // nearest-token band (§4.3), so the token ships verbatim.
      JeebTopBarLeading.identity => text.cardTitle,
      _ => titleScale == JeebTopBarTitleScale.compact
          ? text.titleProminent
          : text.h2,
    };

    return Text(
      title!,
      style: style.copyWith(color: scheme.onSurface),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget? _subtitle(BuildContext context) {
    Widget? line = subtitleSlot;
    if (line == null && subtitle != null) {
      final JeebSemanticColors semantics = _semantics(context);
      final JeebTextStyles text = context.jeebText;
      // Identity 11.5/w600 is exactly `caption`; the back/close bars want
      // 12.5/w600 and `bodySmall` is 12/w600 — inside the nearest-token band.
      final TextStyle style = leading == JeebTopBarLeading.identity
          ? text.caption
          : text.bodySmall;
      line = Text(
        subtitle!,
        style: style.copyWith(color: semantics.mutedText),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (line == null) return null;

    if (subtitleIdentifier != null) {
      line = Semantics(
        identifier: subtitleIdentifier,
        // 17 re-homes `offer_composer_order_ref`, which is a header today.
        header: true,
        container: true,
        explicitChildNodes: true,
        child: line,
      );
    }
    return line;
  }

  void _handleLeading(BuildContext context) {
    final VoidCallback? handler = onLeadingPressed;
    if (handler != null) {
      handler();
      return;
    }
    // Guarded default (screen 06's W5): never an unguarded pop, and never a
    // go_router import inside the kit.
    Navigator.maybeOf(context)?.maybePop();
  }
}

/// `JeebSemanticColors` is read defensively: a bare `!` crashes under test
/// harnesses that theme with a bare `ThemeData`.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
