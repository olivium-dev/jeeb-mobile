import 'package:flutter/material.dart';

import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';
import 'jeeb_surface_tone.dart';

/// The delivery tiers, as the *kit* names them (§5 #7).
///
/// The app has six feature-local tier enums (`TierId`, `OrderTier`,
/// `ClientRequestTier`, `JeeberRequestTier`, `DeliveryTier`,
/// `JeeberTierFilter`) and the kit must import none of them. Features map their
/// own enum onto this one — usually `JeebTier.fromId(theirs.name)` — and pass
/// the **localized** label separately.
///
/// The ⚡🚀🟦🤝🌿 lexicon lives here and nowhere else (plan risk 7).
enum JeebTier {
  /// ⚡ Flash.
  flash('⚡'),

  /// 🚀 Express.
  express('🚀'),

  /// 🟦 Standard.
  standard('🟦'),

  /// 🤝 On-the-Way.
  onTheWay('🤝'),

  /// 🌿 Eco.
  eco('🌿'),

  /// An unseen server tier. Renders **no emoji at all** — 04 §6.5 requires the
  /// render-nothing branch so an unknown tier still cannot break a card.
  unknown('');

  const JeebTier(this.emoji);

  /// The one emoji for this tier, or `''` for [unknown].
  final String emoji;

  /// Resolves a server slug / enum `name` onto a tier.
  ///
  /// Case- and separator-insensitive, so `onTheWay`, `on_the_way`,
  /// `ON-THE-WAY` and `ontheway` all land on [onTheWay]. Anything unrecognised
  /// (including `null`) is [unknown] — never a throw.
  static JeebTier fromId(String? tierId) {
    if (tierId == null) {
      return JeebTier.unknown;
    }
    final String normalized =
        tierId.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    switch (normalized) {
      case 'flash':
        return JeebTier.flash;
      case 'express':
        return JeebTier.express;
      case 'standard':
        return JeebTier.standard;
      case 'ontheway':
        return JeebTier.onTheWay;
      case 'eco':
        return JeebTier.eco;
      default:
        return JeebTier.unknown;
    }
  }
}

/// The tier meta chip (§5 #7) — `⚡ Flash` on a [JeebSurfaceTone]-toned pill.
///
/// Pad `4/10`, [JeebRadii.pill], label 11.5/w700 — all three confirmed on the
/// Midnight board. One treatment for **all five** tiers (16 §5, 24 §5).
///
/// **The emoji and the label are two separate `Text` children, never one
/// string.** `find.text('Flash')`, `find.text('سريع')` and `find.text('إكسبرس')`
/// are pinned in `client_home_screen_test.dart:577-607` and 10's route test, and
/// a concatenated `'⚡ Flash'` breaks all of them.
///
/// **It re-tones itself on navy.** Reading `JeebSurfaceTone` is what makes 08's
/// SLA chip flip to `rgba(255,255,255,.14)` + white ink inside the selected
/// navy tier (08 `tpl 32`) without the consumer remembering. Do not add an
/// `onNavy` parameter.
///
/// Three entry points:
///  * unnamed — a [JeebTier] plus a localized label (04 10 16 21);
///  * [JeebTierChip.custom] — raw `(emoji, label)` strings, for features whose
///    own enum must not be mapped (24 WR-3);
///  * [JeebTierChip.meta] — the same pill with **no emoji**: 06's language
///    chip, 08's SLA band, 11's `Fastest` (06 wiring request W4). It exists so
///    nobody has to add a sixth [JeebChipRole] for a non-interactive chip.
class JeebTierChip extends StatelessWidget {
  const JeebTierChip({
    super.key,
    required this.tier,
    required this.label,
    this.identifier,
    this.semanticLabel,
    this.glass = false,
  }) : emojiOverride = null;

  /// 24 WR-3: `OrderTier` is `order_history`'s own enum and must not be mapped
  /// through a shared type, so the emoji arrives as a string. Pass
  /// `JeebTierChip.emojiFor(slug)` to keep the lexicon central.
  const JeebTierChip.custom({
    super.key,
    required String emoji,
    required this.label,
    this.identifier,
    this.semanticLabel,
    this.glass = false,
  })  : emojiOverride = emoji,
        tier = JeebTier.unknown;

  /// The emoji-less meta chip (06 W4): 08's `≤ 1 hr`, 06's
  /// `Lebanese Arabic · auto-detected`, 11's `Fastest`. Non-interactive.
  const JeebTierChip.meta({
    super.key,
    required this.label,
    this.identifier,
    this.semanticLabel,
    this.glass = false,
  })  : emojiOverride = '',
        tier = JeebTier.unknown;

  /// Content padding — `4/10`, unchanged from pass 1 and re-measured on the
  /// Midnight board (R1/R11/R24 all draw `padding:4px 10px`).
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(vertical: 4, horizontal: 10);

  static const BorderRadius _pillRadius =
      BorderRadius.all(Radius.circular(JeebRadii.pill));

  /// Gap between emoji and label. The board writes `'⚡ Flash'` as one run; 4px
  /// is that space rendered as real layout so the two stay separate `Text`s.
  static const double emojiSpacing = 4;

  /// The tier whose emoji to draw. Ignored by [JeebTierChip.custom] and
  /// [JeebTierChip.meta].
  final JeebTier tier;

  /// The **localized** tier name. The kit has no l10n access by design; every
  /// consumer already owns the string (`l10n.tierFlashTitle`, `_tierLabel`, …).
  final String label;

  /// Maestro id, applied via an explicit `Semantics` wrapper. Adds no node when
  /// null (24 and 04 wrap the chip themselves).
  final String? identifier;

  /// Accessibility label when the visible [label] is not enough.
  final String? semanticLabel;

  /// Set by [JeebTierChip.custom] / [JeebTierChip.meta]; `null` means "use
  /// [tier]'s emoji".
  final String? emojiOverride;

  /// Wave-A: R12's ticket draws its chips GLASS (`glassFillEmphasis` + 1px
  /// `glassBorder`), not the toned opaque pill. Opt-in — M1 ruling 4's solid
  /// treatment (R1) stays the default everywhere else.
  final bool glass;

  /// The R12 glass hairline (sheet §4 — 1px on every glass surface).
  static const double glassBorderWidth = 1;

  /// The kit-owned emoji for a server slug — 12 needs only this, because its
  /// tier line is plain text, not a pill (12 §3).
  static String emojiFor(String? tierId) => JeebTier.fromId(tierId).emoji;

  @override
  Widget build(BuildContext context) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    final String emoji = emojiOverride ?? tier.emoji;
    // 11.5/w700 — the ramp has 11.5/w600 (`caption`), so only the weight is an
    // override; the size is a real token.
    final TextStyle style = context.jeebText.caption.copyWith(
      fontWeight: FontWeight.w700,
      color: tone.chipInk,
    );

    final JeebSemanticColors semantics = _semantics(context);

    Widget chip = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? semantics.glassFillEmphasis : tone.chipFill,
        borderRadius: _pillRadius,
        border: glass
            ? Border.all(
                color: semantics.glassBorder,
                width: glassBorderWidth,
              )
            : null,
      ),
      child: Padding(
        padding: defaultPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (emoji.isNotEmpty) ...<Widget>[
              Text(emoji, style: style),
              const SizedBox(width: emojiSpacing),
            ],
            Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (identifier != null || semanticLabel != null) {
      chip = Semantics(
        identifier: identifier,
        label: semanticLabel,
        container: true,
        explicitChildNodes: true,
        child: chip,
      );
    }

    return chip;
  }
}

/// A bare `!` read crashes under harnesses themed with `ThemeData.light()`.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
