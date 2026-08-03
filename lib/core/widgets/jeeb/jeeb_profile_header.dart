import 'package:flutter/material.dart';

import '../../accessibility/accessibility.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';

/// What 04 and 16 have **instead of** a top bar (redesign-2026-08 §5 #23).
///
/// `[Ø46 avatar] [eyebrow 13/w600 muted / name 19/w700 navy] [trailing]`.
/// The trailing is either a 24px navy glyph (04's bell) or a rating pill
/// (`surfaceContainerHigh`, `★ 4.8`) — and **the star inherits navy**: it is
/// not `omdsColorTokens.starRatingColor`, because §4.1 rations the one warm
/// ink on this board and this pill is not a rating *stat*.
///
/// Screen 19 is listed as a consumer by §5 #23 and 02 §3.2; measured, it is
/// not one (`19-earnings.html:15` is a bare 20/w700 title). Its own reviewed
/// doc states this outright. **19 must not consume this widget.**
///
/// [padding] defaults to **zero**: both real consumers already wrap the header
/// in their own `Padding` (16 needs `key: rootKey` on it). [defaultPadding]
/// carries the board value for anyone mounting it bare.
class JeebProfileHeader extends StatelessWidget {
  const JeebProfileHeader({
    super.key,
    required this.name,
    this.eyebrow,
    this.avatar,
    this.avatarIdentifier,
    this.onAvatarPressed,
    this.trailing,
    this.trailingReserve,
    this.ratingLabel,
    this.ratingIdentifier,
    this.ratingSemanticLabel,
    this.identifier,
    this.padding = EdgeInsetsDirectional.zero,
    this.gap = 14,
  }) : assert(
          trailing == null || ratingLabel == null,
          'The trailing slot holds a glyph OR the rating pill, never both.',
        );

  /// The board's `padding: 16px 24px 0` (04 `tpl 158`), directional. Not the
  /// default — see the class doc.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.fromSTEB(24, 16, 24, 0);

  /// The avatar slot's expected diameter (04 `tpl 159`). 16's HTML draws 44;
  /// 16's own review says take the kit default and do not fork.
  static const double avatarDiameter = 46;

  /// 04's bell is a 24px navy glyph.
  static const double trailingGlyphSize = 24;

  /// The greeting/name line — 19/w700 navy, one line, ellipsized.
  final String name;

  /// The muted line above [name] ("Good morning", "Jeeber dashboard").
  final String? eyebrow;

  /// Ø46 avatar widget (kit `JeebAvatar`). The avatar is **unconditional** on
  /// both consumers: the initial disc is the `avatarUrl == null` case, which
  /// is what makes 16's `jeeber_home_avatar` emit on the live path.
  final Widget? avatar;

  /// Maestro id for the avatar slot (16 `jeeber_home_avatar`, 04
  /// `_request_empty_state_avatar`), applied via an explicit `Semantics`
  /// wrapper.
  final String? avatarIdentifier;

  /// Makes the avatar slot tappable. Null leaves it inert.
  final VoidCallback? onAvatarPressed;

  /// End-side widget — 04's bell glyph. Mutually exclusive with [ratingLabel].
  final Widget? trailing;

  /// Width reserved at the end edge when [trailing] is null. 04 passes
  /// `Spacing.fourXLarge * 2` so a long name cannot run under the shell's
  /// overlaid wallet chip + bell (`shell_screen.dart:301-325`).
  final double? trailingReserve;

  /// Pre-formatted, already-localized rating (e.g. `'4.8'`). Renders the
  /// `★ 4.8` pill in the trailing slot.
  final String? ratingLabel;

  /// Maestro id for the rating pill.
  final String? ratingIdentifier;

  /// Accessibility label for the rating pill — pass the localized sentence,
  /// never the bare glyph (`★` reads as garbage to TalkBack).
  final String? ratingSemanticLabel;

  /// Optional id for the whole header node. Usually null: both consumers own
  /// their own root wrapper.
  final String? identifier;

  /// Row padding. Zero by default; see the class doc.
  final EdgeInsetsGeometry padding;

  /// Avatar-to-text gap (04 `tpl 158` = 14).
  final double gap;

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = <Widget>[];

    if (avatar != null) {
      row
        ..add(_avatarSlot())
        ..add(SizedBox(width: gap));
    }
    row.add(Expanded(child: _textBlock(context)));

    final Widget? end = _trailing(context);
    if (end != null) {
      row
        ..add(SizedBox(width: gap))
        ..add(end);
    } else if (trailingReserve != null) {
      row.add(SizedBox(width: trailingReserve));
    }

    Widget header = Padding(
      padding: padding,
      child: Row(children: row),
    );

    if (identifier != null) {
      header = Semantics(
        identifier: identifier,
        container: true,
        explicitChildNodes: true,
        child: header,
      );
    }
    return header;
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

  Widget _textBlock(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebTextStyles text = context.jeebText;
    final JeebSemanticColors semantics = _semantics(context);

    final Widget nameLine = Text(
      name,
      // 19/w700: `h2` is 20/w700, a full px away, so the design-exact size
      // rides on the token rather than replacing it (§4.4 two-tier rule —
      // legal inside the kit, banned in lib/features).
      style: text.h2.copyWith(fontSize: 19, color: scheme.primary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (eyebrow == null) {
      return nameLine;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      // Directional: resolves to the right edge under RTL.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow!,
          // 13/w600 on `bodySmall`'s 12/w600.
          style: text.bodySmall
              .copyWith(fontSize: 13, color: semantics.mutedText),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        nameLine,
      ],
    );
  }

  Widget? _trailing(BuildContext context) {
    if (trailing != null) {
      return IconTheme.merge(
        data: IconThemeData(
          size: trailingGlyphSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        child: trailing!,
      );
    }
    if (ratingLabel == null) return null;
    return _ratingPill(context);
  }

  Widget _ratingPill(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebTextStyles text = context.jeebText;

    final Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Navy, deliberately. Tinting this yellow is the §4.1 defect.
            Icon(Icons.star_rounded, size: 13, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              ratingLabel!,
              // 12/w700 on `bodySmall`'s 12/w600 — same size, one weight step.
              style: text.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );

    if (ratingIdentifier == null && ratingSemanticLabel == null) {
      return pill;
    }
    return Semantics(
      identifier: ratingIdentifier,
      label: ratingSemanticLabel,
      container: true,
      // The `★` glyph must not reach the screen reader as a child leaf.
      excludeSemantics: ratingSemanticLabel != null,
      child: pill,
    );
  }
}

/// `JeebSemanticColors` is read defensively: a bare `!` crashes under test
/// harnesses that theme with `ThemeData.light()`.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.light();
