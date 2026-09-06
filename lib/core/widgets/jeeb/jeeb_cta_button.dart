import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import '../../theme/jeeb_text_styles.dart';

/// The six realized call-to-action treatments (redesign-2026-08 §5 #2).
enum JeebCtaVariant {
  /// MIDNIGHT: periwinkle `secondary` pill, navy `onSecondary`
  /// [JeebTextStyles.button], no lift. h56 (01 08 15 23) or h58 (10 14 17).
  primary,

  /// MIDNIGHT: solid `jeebRoles.accent` pill, `onAccent` ink, `ctaOrange` lift,
  /// `orangePressed` while held. Only where a tile draws the orange act
  /// (R9 `Continue`, R12 `Broadcast`) — never as a default.
  accent,

  /// MIDNIGHT: glass pill — `glassFill` + 1px `glassBorderStrong`, `onSurface`
  /// ink. h50 (12 18) or h54 (14).
  outline,

  /// MIDNIGHT: [outline]'s glass pill in the danger family — same fill, same
  /// hairline, same h50/h54 geometry, `colorScheme.onErrorContainer` ink.
  ///
  /// The terminal destructive act (11 `Cancel request`, the delete confirms).
  /// The board draws no destructive CTA, so nothing is copied: this is the R22
  /// ruling (destructive text is danger-SOFT `#FF7B7B`, never full-strength
  /// `error` `#FF5252`) lifted from R22's bare label onto pill geometry. No
  /// fill of its own and no lift — a solid `error` pill would out-shout the
  /// rationed accent CTA (§2.2), and glow belongs only where a tile draws it.
  danger,

  /// No pill at all — `colorScheme.onSurfaceVariant` ink (01 `Skip`,
  /// 12 `Report no-show`, 11 `Cancel request`).
  text,

  /// No pill, `jeebRoles.accent` ink — the orange link (23 `How fees work`).
  /// This is the **only** sanctioned orange text affordance (§4.1).
  accentText,
}

/// The Jeeb call-to-action (redesign-2026-08 §5 #2) — 13 screens.
///
/// Presentation-only: everything arrives by constructor. The widget owns the
/// pill geometry, the fill/border per [variant], the disabled and loading
/// treatments, and the RTL-correct glyph placement. Consumers own the label
/// string, the callback and (usually) the `Semantics` identifier.
///
/// **Semantics contract** — matching the card primitives: this widget adds a
/// `Semantics` node **only** when [identifier] or [semanticLabel] is set. Every
/// board screen already wraps its CTA in its own
/// `Semantics(identifier: '<screen>_cta', button: true)` (14 additionally wraps
/// the child in `ExcludeSemantics`), and a kit-emitted id inside that would
/// either duplicate or be swallowed. Unlike the cards this node does **not**
/// set `explicitChildNodes` — a button's label must merge into its own node,
/// whereas a card contains other separately addressable ids.
///
/// **Never** OMDS's `identifier:` parameter (§5) — an explicit wrapper only.
///
/// Note for tests: [isLoading] renders a [CircularProgressIndicator], whose
/// animation never settles. Drive those cases with `pump()`, not
/// `pumpAndSettle()`.
class JeebCtaButton extends StatelessWidget {
  /// The general form — [variant] chosen at runtime (06 selects this way).
  const JeebCtaButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = JeebCtaVariant.primary,
    this.isEnabled = true,
    this.isLoading = false,
    this.height,
    this.expand,
    this.labelStyle,
    this.leadingIcon,
    this.trailingIcon,
    this.iconSize,
    this.iconSpacing = 10,
    this.mirrorIcons = false,
    this.shrinkLabelToFit = false,
    this.wrapLabel = false,
    this.contentPadding,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  });

  /// Periwinkle pill (08 10 14 15 17 23). Pass `height: primaryHeightTall` for
  /// the h58 screens.
  const JeebCtaButton.primary({
    super.key,
    required this.label,
    this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.height,
    this.expand,
    this.labelStyle,
    this.leadingIcon,
    this.trailingIcon,
    this.iconSize,
    this.iconSpacing = 10,
    this.mirrorIcons = false,
    this.shrinkLabelToFit = false,
    this.wrapLabel = false,
    this.contentPadding,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  }) : variant = JeebCtaVariant.primary;

  /// Orange pill — the tile-drawn act (R9 `Continue`, R12 `Broadcast`).
  ///
  /// Carries [JeebShadows.ctaOrange] while interactive and drops it when
  /// disabled: a glow under a dimmed pill reads as an enabled button.
  const JeebCtaButton.accent({
    super.key,
    required this.label,
    this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.height,
    this.expand,
    this.labelStyle,
    this.leadingIcon,
    this.trailingIcon,
    this.iconSize,
    this.iconSpacing = 10,
    this.mirrorIcons = false,
    this.shrinkLabelToFit = false,
    this.wrapLabel = false,
    this.contentPadding,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  }) : variant = JeebCtaVariant.accent;

  /// Glass pill (12 14 18).
  const JeebCtaButton.outline({
    super.key,
    required this.label,
    this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.height,
    this.expand,
    this.labelStyle,
    this.leadingIcon,
    this.trailingIcon,
    this.iconSize,
    this.iconSpacing = 10,
    this.mirrorIcons = false,
    this.shrinkLabelToFit = false,
    this.wrapLabel = false,
    this.contentPadding,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  }) : variant = JeebCtaVariant.outline;

  /// Destructive glass pill — [JeebCtaVariant.danger].
  ///
  /// Identical to [JeebCtaButton.outline] in every dimension except the ink, so
  /// `height: outlineHeightTall` and the h50 label override apply unchanged.
  const JeebCtaButton.danger({
    super.key,
    required this.label,
    this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.height,
    this.expand,
    this.labelStyle,
    this.leadingIcon,
    this.trailingIcon,
    this.iconSize,
    this.iconSpacing = 10,
    this.mirrorIcons = false,
    this.shrinkLabelToFit = false,
    this.wrapLabel = false,
    this.contentPadding,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  }) : variant = JeebCtaVariant.danger;

  /// Bare `onSurfaceVariant` label (01 11 12).
  const JeebCtaButton.text({
    super.key,
    required this.label,
    this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.height,
    this.expand,
    this.labelStyle,
    this.leadingIcon,
    this.trailingIcon,
    this.iconSize,
    this.iconSpacing = 10,
    this.mirrorIcons = false,
    this.shrinkLabelToFit = false,
    this.wrapLabel = false,
    this.contentPadding,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  }) : variant = JeebCtaVariant.text;

  /// Bare orange link (23).
  const JeebCtaButton.accentText({
    super.key,
    required this.label,
    this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.height,
    this.expand,
    this.labelStyle,
    this.leadingIcon,
    this.trailingIcon,
    this.iconSize,
    this.iconSpacing = 10,
    this.mirrorIcons = false,
    this.shrinkLabelToFit = false,
    this.wrapLabel = false,
    this.contentPadding,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  }) : variant = JeebCtaVariant.accentText;

  /// h56 — 01 `tpl 57`, 08 `tpl 506`, 15 `tpl 890`, 23 `tpl 1382`.
  static const double primaryHeight = 56;

  /// h58 — 10 `tpl 623`, 14 `tpl 847`, 17 `tpl 1031`.
  static const double primaryHeightTall = 58;

  /// h50 — 12 `tpl 782-783`, 18 `tpl 1086-1092`.
  static const double outlineHeight = 50;

  /// h54 — 14 `tpl 850`.
  static const double outlineHeightTall = 54;

  /// Bare text buttons carry no pill, so the height is purely the tap target.
  /// 48 is the a11y minimum; 01 passes [primaryHeight] to match its `Next` pill
  /// and 12 passes [outlineHeight] to match its `Open dispute` pill.
  static const double textHeight = 48;

  /// The board's `border-radius: 999px`.
  static const double pillRadius = JeebRadii.pill;

  /// The glass pill's hairline — board `1px solid rgba(255,255,255,.16)`.
  static const double outlineBorderWidth = 1;

  /// Disabled alphas, deliberately identical to `OmdsPrimaryButton`'s (its
  /// P0-X01 fix) so a Jeeb CTA and an OMDS CTA disable the same way: the fill
  /// dims to .45 but the label stays legible at .9. The board draws no disabled
  /// state, so matching the app is the safest reading.
  static const double disabledFillOpacity = 0.45;

  /// See [disabledFillOpacity].
  static const double disabledLabelOpacity = 0.9;

  /// The visible label. Named (not positional) on every constructor.
  final String label;

  /// Tap callback. `null` disables the button just as `isEnabled: false` does.
  final VoidCallback? onTap;

  /// Which of the four treatments to paint.
  final JeebCtaVariant variant;

  /// Consumer-controlled enablement (07 `hasSelection`, 08 `state.canConfirm`,
  /// 15 `stars > 0`, 06). Read it back in tests via
  /// `tester.widget<JeebCtaButton>(find.byKey(k)).isEnabled`.
  final bool isEnabled;

  /// Swaps the whole content for a spinner and ignores taps, keeping the
  /// height and the pill (10/14/17 render `state.isSubmitting` here — the
  /// guard against double-submits).
  final bool isLoading;

  /// Design-exact px are legal inside the kit (§4.4). Defaults per [variant];
  /// see [primaryHeight] / [outlineHeight] and their `Tall` siblings.
  final double? height;

  /// Fill the available width. Defaults to true for pill variants and false for
  /// the bare text variants (01's `Skip` is intrinsic; 12's is `Expanded` by
  /// the footer). Only pass `true` where the width is bounded — inside an
  /// `Expanded`, a stretched `Column`, or a `SizedBox`.
  final bool? expand;

  /// Overrides the per-variant label style. The board realizes the bare and
  /// outline labels at 13.5–15.5px depending on the pill height, so 12 (14/w600
  /// at h50) and 14 (15.5/w600 at h54) set this from a `jeebText` token —
  /// never a raw `fontSize:`. Typography only — its `color` is always replaced
  /// by the [variant]'s ink, which is what keeps orange rationed to §4.1.
  final TextStyle? labelStyle;

  /// Leading glyph — 23's `＋` (19px), 10's `wifi_tethering` (20px), 14's
  /// `check` (19px), 18's per-action glyph (16px).
  final IconData? leadingIcon;

  /// Trailing glyph — 01's `Next →` arrow (18px).
  final IconData? trailingIcon;

  /// Glyph size; defaults to [_defaultIconSize].
  final double? iconSize;

  /// Gap between glyph and label. 10 on 10/14/23, 9 on 01, 8 on 18.
  final double iconSpacing;

  /// Horizontally flips the glyphs under RTL.
  ///
  /// [leadingIcon]/[trailingIcon] already swap *sides* (the row is
  /// directional), but the glyph itself does not turn around: `Icon` ignores
  /// direction unless the `IconData` opts in, and `DirectionalIcons` has no
  /// forward-arrow member. Set this for directional glyphs such as 01's arrow;
  /// leave it false for symmetric ones (`+`, `check`, `lock`).
  final bool mirrorIcons;

  /// Scales the label down instead of ellipsizing it when the pill is too
  /// narrow. Opt-in: only the split footers that halve the width need it.
  final bool shrinkLabelToFit;

  /// Lets accessible-size labels wrap and grow the pill above its minimum
  /// height. Opt-in so existing single-line button layouts remain unchanged.
  final bool wrapLabel;

  /// Horizontal inset around the content. Defaults per [variant]; 01's `Skip`
  /// measures `0/22`.
  final EdgeInsetsGeometry? contentPadding;

  /// Maestro / `find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper. Leave null when the consumer owns the id (10 12 14).
  final String? identifier;

  /// Accessibility label, when the visible [label] is not the spoken one.
  final String? semanticLabel;

  /// Accessibility hint.
  final String? semanticHint;

  /// Whether a tap will actually fire — the single source of truth for the
  /// disabled paint, the suppressed callback and the reported semantics.
  bool get isInteractive => isEnabled && !isLoading && onTap != null;

  bool get _isPill =>
      variant == JeebCtaVariant.primary ||
      variant == JeebCtaVariant.accent ||
      _isGlassPill;

  /// `outline` and `danger` share the entire glass construction — fill, border,
  /// height, glyph size, label style — and differ in the label ink alone.
  bool get _isGlassPill =>
      variant == JeebCtaVariant.outline || variant == JeebCtaVariant.danger;

  double get _defaultHeight {
    switch (variant) {
      case JeebCtaVariant.primary:
      case JeebCtaVariant.accent:
        return primaryHeight;
      case JeebCtaVariant.outline:
      case JeebCtaVariant.danger:
        return outlineHeight;
      case JeebCtaVariant.text:
      case JeebCtaVariant.accentText:
        return textHeight;
    }
  }

  double get _defaultIconSize => _isGlassPill ? 16 : 19;

  EdgeInsetsGeometry get _defaultContentPadding => _isPill
      ? const EdgeInsetsDirectional.symmetric(horizontal: 20)
      : const EdgeInsetsDirectional.symmetric(horizontal: 22);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final JeebSemanticColors semantics =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final JeebTextStyles text = context.jeebText;
    final bool live = isInteractive;

    final JeebRoles roles = context.jeebRoles;
    final bool isAccent = variant == JeebCtaVariant.accent;
    final Color ink = _ink(roles, scheme, live);
    final TextStyle style = (labelStyle ?? _defaultLabelStyle(text)).copyWith(
      color: ink,
    );
    final BorderRadius radius = BorderRadius.circular(pillRadius);

    Widget content = isLoading
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ink),
            ),
          )
        : _label(context, style, ink);

    content = Padding(
      padding: contentPadding ?? _defaultContentPadding,
      child: content,
    );
    if (wrapLabel) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: content,
      );
    }

    Widget button = SizedBox(
      // `expand` must stay opt-out: 01's `Skip` sits in an unbounded Row slot,
      // where `double.infinity` would throw.
      width: (expand ?? _isPill) ? double.infinity : null,
      height: wrapLabel ? null : (height ?? _defaultHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _fill(roles, scheme, semantics, live),
          borderRadius: radius,
          border: _isGlassPill
              ? Border.all(
                  color: _alpha(semantics.glassBorderStrong, live),
                  // The board is `box-sizing: border-box`, and so is a Flutter
                  // decoration border on a fixed-height box: h50 stays h50.
                  width: outlineBorderWidth,
                )
              : null,
          boxShadow: isAccent && live ? JeebShadows.ctaOrange : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            // Transparent Material keeps the splash above the fill without
            // asking the consumer to supply one.
            type: MaterialType.transparency,
            child: InkWell(
              onTap: live ? onTap : null,
              borderRadius: radius,
              // The accent pill's held state is a FILL SWAP to `orangePressed`,
              // so the ripple is suppressed and the highlight covers the fill.
              splashColor: isAccent ? Colors.transparent : null,
              highlightColor: isAccent ? semantics.orangePressed : null,
              child: Center(heightFactor: wrapLabel ? 1 : null, child: content),
            ),
          ),
        ),
      ),
    );

    if (wrapLabel) {
      button = ConstrainedBox(
        constraints: BoxConstraints(minHeight: height ?? _defaultHeight),
        child: button,
      );
    }

    if (identifier != null || semanticLabel != null) {
      button = Semantics(
        identifier: identifier,
        label: semanticLabel,
        hint: semanticHint,
        button: true,
        enabled: live,
        container: true,
        child: button,
      );
    }

    return button;
  }

  Widget _label(BuildContext context, TextStyle style, Color ink) {
    Widget labelText = Text(
      label,
      style: style,
      textAlign: TextAlign.center,
      maxLines: wrapLabel ? null : 1,
      overflow: wrapLabel ? TextOverflow.visible : TextOverflow.ellipsis,
    );
    if (shrinkLabelToFit) {
      labelText = FittedBox(fit: BoxFit.scaleDown, child: labelText);
    }
    if (leadingIcon == null && trailingIcon == null) {
      return labelText;
    }
    final double glyph = iconSize ?? _defaultIconSize;
    final SizedBox gap = SizedBox(width: iconSpacing);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (leadingIcon != null) ...<Widget>[
          _glyph(context, leadingIcon!, glyph, ink),
          gap,
        ],
        Flexible(child: labelText),
        if (trailingIcon != null) ...<Widget>[
          gap,
          _glyph(context, trailingIcon!, glyph, ink),
        ],
      ],
    );
  }

  Widget _glyph(BuildContext context, IconData icon, double size, Color ink) {
    final Widget glyph = Icon(icon, size: size, color: ink);
    if (!mirrorIcons) {
      return glyph;
    }
    return Transform.flip(
      flipX: Directionality.of(context) == TextDirection.rtl,
      child: glyph,
    );
  }

  TextStyle _defaultLabelStyle(JeebTextStyles text) {
    switch (variant) {
      case JeebCtaVariant.primary:
      case JeebCtaVariant.accent:
        // 17/w600 — the board's CTA label on every h56/h58 pill.
        return text.button;
      case JeebCtaVariant.outline:
      case JeebCtaVariant.danger:
        // 14.5/w600 — the board's glass CTA label; h50 draws 13.5 (override).
        return text.body.copyWith(fontWeight: FontWeight.w600);
      case JeebCtaVariant.text:
        // 15.5/w600 — 01 `tpl 56`; 11 measures 14.5, 12 measures 14.
        return text.cardTitle.copyWith(fontWeight: FontWeight.w600);
      case JeebCtaVariant.accentText:
        // 13.5/w700 — 23 `tpl 1385` measures 13.
        return text.body.copyWith(fontWeight: FontWeight.w700);
    }
  }

  Color? _fill(
    JeebRoles roles,
    ColorScheme scheme,
    JeebSemanticColors semantics,
    bool live,
  ) {
    switch (variant) {
      case JeebCtaVariant.primary:
        return _alpha(scheme.secondary, live);
      case JeebCtaVariant.accent:
        return _alpha(roles.accent, live);
      case JeebCtaVariant.outline:
      case JeebCtaVariant.danger:
        return _alpha(semantics.glassFill, live);
      case JeebCtaVariant.text:
      case JeebCtaVariant.accentText:
        return null;
    }
  }

  Color _ink(JeebRoles roles, ColorScheme scheme, bool live) {
    switch (variant) {
      case JeebCtaVariant.primary:
        return live
            ? scheme.onSecondary
            : scheme.onSecondary.withValues(alpha: disabledLabelOpacity);
      case JeebCtaVariant.accent:
        return live
            ? roles.onAccent
            : roles.onAccent.withValues(alpha: disabledLabelOpacity);
      case JeebCtaVariant.outline:
        return _alpha(scheme.onSurface, live);
      case JeebCtaVariant.danger:
        // R22: danger-SOFT. `error` #FF5252 is the harsher ink on this glass
        // (5.10:1 vs 6.48:1) and is reserved for strokes and glyphs.
        return _alpha(scheme.onErrorContainer, live);
      case JeebCtaVariant.text:
        return _alpha(scheme.onSurfaceVariant, live);
      case JeebCtaVariant.accentText:
        return _alpha(roles.accent, live);
    }
  }

  /// Multiplicative so the glass tokens dim instead of jumping to 45% opaque.
  Color _alpha(Color color, bool live) =>
      live ? color : color.withValues(alpha: color.a * disabledFillOpacity);
}
