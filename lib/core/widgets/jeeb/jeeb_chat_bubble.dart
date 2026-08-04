import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';
import 'jeeb_surface_tone.dart';

/// Which side of the thread a bubble belongs to (redesign-2026-08 §5 #16).
enum JeebChatBubbleSide {
  /// The counterpart. MIDNIGHT rest glass (`glassFill` + 1px `glassBorder`),
  /// tail at the bottom-START corner.
  incoming,

  /// The signed-in user. MIDNIGHT orange-tinted glass (`bubbleOutFill` + 1px
  /// `bubbleOutBorder`), tail at the bottom-END corner, flat.
  outgoing,
}

/// The trailing half of a bubble's meta line — `9:25 · Read` or `9:25 ✓✓`.
///
/// Two forms because the board draws two:
///  * [JeebChatStatus.text] — the **read** state, which on this board is the
///    literal word `Read` after a `·`, not a tick. `JeebSemanticColors.readTick`
///    (`#20F0FF`) has **zero occurrences board-wide** (§4.1) and no lane may
///    consume it.
///  * [JeebChatStatus.icon] — sending / sent / delivered / failed, a small glyph
///    in the meta ink with no separator.
///
/// The consumer owns the identifier and the key because the five status ids
/// (`chat_detail_message_sending|_sent|_delivered|_read|_failed`) and
/// `Key('chat-status-<id>')` are frozen (21 §7.1) and belong to the message,
/// not to the kit.
@immutable
class JeebChatStatus {
  /// A glyph status. [iconColor] defaults to the meta ink; pass
  /// `colorScheme.error` for the failed case.
  const JeebChatStatus.icon(
    this.icon, {
    this.iconColor,
    this.identifier,
    this.semanticLabel,
    this.nodeKey,
  })  : label = null,
        isText = false;

  /// The text status — rendered as `· <label>` in the same 10/w600 meta style.
  const JeebChatStatus.text(
    this.label, {
    this.identifier,
    this.semanticLabel,
    this.nodeKey,
  })  : icon = null,
        iconColor = null,
        isText = true;

  /// Glyph size for [JeebChatStatus.icon] — sized to sit on the 10px meta line.
  static const double iconSize = 12;

  /// The glyph, for the icon form.
  final IconData? icon;

  /// The localized word, for the text form.
  final String? label;

  /// Overrides the meta ink for the icon form (failed → `colorScheme.error`).
  final Color? iconColor;

  /// Maestro id for the status node, applied via an explicit `Semantics`.
  final String? identifier;

  /// Accessibility label for the status node.
  final String? semanticLabel;

  /// Widget key for the status node — `Key('chat-status-<messageId>')` is
  /// pinned by the existing chat tests.
  final Key? nodeKey;

  /// True for [JeebChatStatus.text]; drives the `·` separator.
  final bool isText;
}

/// The bubble's media slot (measured from 21, `tpl 1253-1267`).
///
/// **One or the other, never both.** The board draws a voice row and a photo
/// tile inside one bubble, but the wire cannot express that: `MessageKind` is
/// one-of, a voice row carries `voiceUrl/voiceDurationMs`, an image row carries
/// `imageUrl/photoBytes` (21 §4.4). Two consecutive same-author bubbles render
/// the design honestly; a `media` that could be both would invite a fake.
@immutable
class JeebChatMedia {
  /// Ø32 play disc + waveform + `0:06 · photo of the box` label.
  ///
  /// [waveform] is a slot, not an import: `JeebWaveform.inBubble` (kit §5 #14)
  /// ships from a different lane, and the bubble does not need to know how a
  /// waveform is drawn. Pass `const JeebWaveform.inBubble()` with **no
  /// arguments** — the bubble publishes [JeebSurfaceTone], so the mark re-inks
  /// itself white on an outgoing bubble and navy on an incoming one.
  ///
  /// [onPlay] defaults to **null and must stay null until a real audio player
  /// exists**. An inert disc renders with no `Semantics` and no identifier —
  /// adding a button id for a permanent no-op is exactly the B-04 defect
  /// (21 §4.4).
  const JeebChatMedia.voice({
    required this.waveform,
    required this.label,
    this.playIcon = Icons.play_arrow_rounded,
    this.onPlay,
    this.playIdentifier,
    this.playSemanticLabel,
  })  : photo = null,
        photoIcon = Icons.image_outlined,
        onPhotoTap = null,
        photoIdentifier = null,
        photoSemanticLabel = null,
        isVoice = true;

  /// The 120×74 r10 tile. [photo] is the resolved image widget (the chat lane
  /// keeps its bytes ▸ absolute http(s) ▸ placeholder precedence verbatim);
  /// when it is null the tile renders the 20px periwinkle placeholder glyph.
  const JeebChatMedia.photo({
    this.photo,
    this.photoIcon = Icons.image_outlined,
    this.onPhotoTap,
    this.photoIdentifier,
    this.photoSemanticLabel,
  })  : waveform = null,
        label = null,
        playIcon = Icons.play_arrow_rounded,
        onPlay = null,
        playIdentifier = null,
        playSemanticLabel = null,
        isVoice = false;

  /// Ø32 navy play disc (`tpl 1255`).
  static const double discDiameter = 32;

  /// 14px white ▶ inside the disc (`tpl 1256`).
  static const double playGlyphSize = 14;

  /// Gap between disc, waveform and label (`tpl 1254`).
  static const double rowGap = 9;

  /// 120×74 photo tile (`tpl 1265`).
  static const double photoWidth = 120;

  /// 120×74 photo tile (`tpl 1265`).
  static const double photoHeight = 74;

  /// The board's r10 photo tile, snapped to the ladder's `sm` rung (§5).
  static const double photoRadius = JeebRadii.sm;

  /// 20px placeholder glyph inside the tile (`tpl 1266`).
  static const double photoGlyphSize = 20;

  /// The waveform mark, for the voice form.
  final Widget? waveform;

  /// `0:06 · photo of the box` — 11/w700 in the meta ink.
  final String? label;

  /// Play glyph; `Icons.play_arrow_rounded` is pinned by
  /// `voice_note_bubble_widget_test`.
  final IconData playIcon;

  /// Play handler. **Null on every shipping surface today** (no audio player).
  final VoidCallback? onPlay;

  /// Only emitted when [onPlay] is non-null — an inert disc gets no id.
  final String? playIdentifier;

  /// Accessibility label for the play disc.
  final String? playSemanticLabel;

  /// The resolved image, for the photo form.
  final Widget? photo;

  /// Placeholder glyph when [photo] is null.
  final IconData photoIcon;

  /// Tap handler for the tile (full-screen viewer).
  final VoidCallback? onPhotoTap;

  /// Maestro id for the tile.
  final String? photoIdentifier;

  /// Accessibility label for the tile.
  final String? photoSemanticLabel;

  /// True for [JeebChatMedia.voice].
  final bool isVoice;
}

/// The chat bubble (redesign-2026-08 §5 #16) — screen 21's thread row.
///
/// Owns the four things the plan says must never be re-derived per screen: the
/// `18/6` directional tail, the 78% max width, the `11/14` padding and the meta
/// line. Everything else arrives through slots.
///
/// **Not composed on `JeebNavySurfaceCard`.** The outgoing bubble is an
/// emphasis surface, but its corner set is `topStart 18 · topEnd 18 ·
/// bottomStart 18 · bottomEnd 6` — three radii the card's single `radius`
/// parameter cannot express. Widening that parameter would mean editing a file
/// another lane owns, so the bubble paints its own decoration and instead
/// publishes [JeebSurfaceTone] like the cards do, so any kit child dropped
/// inside an outgoing bubble still re-tones itself.
///
/// MIDNIGHT (R20 measured): the thread reads by temperature — incoming stays
/// cool rest glass, outgoing is warm orange glass (24% fill / 45% stroke, white
/// body ink, `#FFB499` meta). The blur the board draws is the screen's to add.
class JeebChatBubble extends StatelessWidget {
  const JeebChatBubble({
    super.key,
    required this.side,
    this.text,
    this.child,
    this.media,
    this.time,
    this.status,
    this.padding = defaultPadding,
    this.maxWidthFraction = defaultMaxWidthFraction,
    this.onTap,
    this.bubbleKey,
    this.identifier,
    this.semanticLabel,
    this.semanticHint,
  }) : assert(
          text == null || child == null,
          'Pass text OR child, not both — child exists for AutoDirectionText '
          'and the location/offer shells.',
        );

  /// `max-width: 78%` of the thread column (`tpl 1250`). Measured against the
  /// incoming constraints, not the screen width, so the 24px gutters count.
  static const double defaultMaxWidthFraction = 0.78;

  /// `padding: 11px 14px` (`tpl 1250`). 21's voice bubble draws `10/14`; pass
  /// it explicitly if that 1px matters.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 11);

  /// The three round corners — the `lg` rung of the ratified ladder.
  static const double cornerRadius = JeebRadii.lg;

  /// 1px, every glass surface (token sheet §4).
  static const double borderWidth = 1;

  /// The tail corner.
  static const double tailRadius = 6;

  /// Gap between the body and the media slot (`margin-top: 8`, `tpl 1265`).
  static const double mediaTopGap = 8;

  /// Gap above the meta line (`margin-top: 4`, `tpl 1252`).
  static const double metaTopGap = 4;

  /// Gap either side of the `·` in `9:25 · Read`.
  static const double metaSeparatorGap = 4;

  /// The separator the board draws between the clock and the read state.
  static const String metaSeparator = '·';

  /// `18 18 18 6` — tail at the bottom-START corner. Directional, so it mirrors.
  static const BorderRadiusDirectional incomingRadius =
      BorderRadiusDirectional.only(
    topStart: Radius.circular(cornerRadius),
    topEnd: Radius.circular(cornerRadius),
    bottomEnd: Radius.circular(cornerRadius),
    bottomStart: Radius.circular(tailRadius),
  );

  /// `18 18 6 18` — the mirror of [incomingRadius].
  static const BorderRadiusDirectional outgoingRadius =
      BorderRadiusDirectional.only(
    topStart: Radius.circular(cornerRadius),
    topEnd: Radius.circular(cornerRadius),
    bottomEnd: Radius.circular(tailRadius),
    bottomStart: Radius.circular(cornerRadius),
  );

  /// Which side of the thread this bubble sits on.
  final JeebChatBubbleSide side;

  /// Convenience body: rendered as a plain [Text] in the resolved body style.
  /// Mutually exclusive with [child].
  final String? text;

  /// Arbitrary body — pass `AutoDirectionText(message.text)` (no style: the
  /// bubble installs the right `DefaultTextStyle`), or a location/offer shell.
  final Widget? child;

  /// The measured media slot; voice **or** photo, never both.
  final JeebChatMedia? media;

  /// Formatted clock, e.g. `9:25`. Rendered inside an LTR isolate so the digits
  /// never reorder under Arabic.
  final String? time;

  /// Read state or delivery glyph. Omit for a counterpart bubble that should
  /// carry a time only.
  final JeebChatStatus? status;

  /// Bubble padding.
  final EdgeInsetsGeometry padding;

  /// Fraction of the available width the bubble may occupy.
  final double maxWidthFraction;

  /// Makes the whole bubble tappable (retry, open photo).
  final VoidCallback? onTap;

  /// Key on the painted bubble box — `Key('chat-bubble-<messageId>')` is asserted
  /// by `chat_message_bubble_rtl_test`. Kept separate from [key] so the widget
  /// key stays free.
  final Key? bubbleKey;

  /// Maestro id (`chat_detail_message_<id>`), applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label for the bubble node.
  final String? semanticLabel;

  /// Accessibility hint.
  final String? semanticHint;

  /// The bubble fill for [side] — rest glass in, orange 24% out.
  static Color fillOf(BuildContext context, JeebChatBubbleSide side) {
    final JeebSemanticColors semantics = _semanticsOf(context);
    return side == JeebChatBubbleSide.outgoing
        ? semantics.bubbleOutFill
        : semantics.glassFill;
  }

  /// The 1px border for [side] — glass in, orange 45% out.
  static Color borderInkOf(BuildContext context, JeebChatBubbleSide side) {
    final JeebSemanticColors semantics = _semanticsOf(context);
    return side == JeebChatBubbleSide.outgoing
        ? semantics.bubbleOutBorder
        : semantics.glassBorder;
  }

  /// Body ink — `onSurface` on glass, pure white on the tinted fill (the board
  /// literal, and the AA pair `#FFFFFF` on `#D73B00` §9 already gates).
  static Color bodyInkOf(BuildContext context, JeebChatBubbleSide side) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return side == JeebChatBubbleSide.outgoing
        ? scheme.onPrimary
        : scheme.onSurface;
  }

  /// Meta / media-label ink — board literals: `mutedText` on glass (AA 5.9:1),
  /// `#FFB499` on the tinted fill.
  /// (R20 measured; the accent quartet's `onContainer` is that hex).
  static Color metaInkOf(BuildContext context, JeebChatBubbleSide side) =>
      side == JeebChatBubbleSide.outgoing
          ? context.jeebRoles.onAccentContainer
          : _semanticsOf(context).mutedText;

  /// 14.5/w500/lh21 in the body ink — `jeebText.body`.
  static TextStyle bodyStyleOf(BuildContext context, JeebChatBubbleSide side) =>
      context.jeebText.body.copyWith(color: bodyInkOf(context, side));

  /// 10/w600 in the meta ink. Derived from `jeebText.bodySmall` (12.5/w600) —
  /// the ramp has no 10px entry and the kit may use design-exact px (§4.4).
  static TextStyle metaStyleOf(BuildContext context, JeebChatBubbleSide side) =>
      context.jeebText.bodySmall
          .copyWith(fontSize: 10, color: metaInkOf(context, side));

  /// 11/w700 in the meta ink — the `0:06 · photo of the box` line (`tpl 1264`).
  static TextStyle mediaLabelStyleOf(
    BuildContext context,
    JeebChatBubbleSide side,
  ) =>
      context.jeebText.label
          .copyWith(fontSize: 11, color: metaInkOf(context, side));

  /// The directional corner set for [side].
  static BorderRadiusDirectional radiusOf(JeebChatBubbleSide side) =>
      side == JeebChatBubbleSide.outgoing ? outgoingRadius : incomingRadius;

  @override
  Widget build(BuildContext context) {
    final bool outgoing = side == JeebChatBubbleSide.outgoing;
    final BorderRadiusDirectional radius = radiusOf(side);

    // A navy bubble is a navy surface: publish the tone so any kit child
    // dropped inside re-tones itself, exactly as the two cards do.
    final Widget content = JeebSurfaceTone(
      tone: outgoing
          ? JeebSurfaceToneData.navy(context)
          : JeebSurfaceToneData.light(context),
      child: _column(context, outgoing),
    );

    final Widget padded = Padding(padding: padding, child: content);

    Widget bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: fillOf(context, side),
        borderRadius: radius,
        border: Border.all(
          color: borderInkOf(context, side),
          width: borderWidth,
        ),
        // `bubbleOut` is retired: the migration map maps it to none.
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: onTap == null
            ? padded
            // Splash above the fill, so consumers need no Material of their own.
            : Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, child: padded),
              ),
      ),
    );

    if (bubbleKey != null) {
      bubble = KeyedSubtree(key: bubbleKey, child: bubble);
    }

    if (identifier != null || semanticLabel != null || onTap != null) {
      bubble = Semantics(
        identifier: identifier,
        label: semanticLabel,
        hint: semanticHint,
        button: onTap != null,
        // Mandatory (21 §7.1): without both flags this node swallows the five
        // status ids the consumer nests inside.
        container: true,
        explicitChildNodes: true,
        child: bubble,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // `max-width: 78%` is a percentage of the containing block, so it is
        // measured against the thread column, not MediaQuery. The fallback
        // covers an unbounded parent (a horizontal scroll view).
        final double available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return Align(
          alignment: outgoing
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          // The ceiling sits INSIDE the Align on purpose: a list row arrives
          // with a *tight* width, and `ConstrainedBox` enforces the incoming
          // constraints, so an outer one would be clamped straight back to the
          // full column width. Align re-loosens first.
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: available * maxWidthFraction),
            child: bubble,
          ),
        );
      },
    );
  }

  Widget _column(BuildContext context, bool outgoing) {
    final List<Widget> parts = <Widget>[];

    final Widget? body = text != null ? Text(text!) : child;
    if (body != null) {
      // DefaultTextStyle rather than a styled Text, so the chat lane can pass
      // its own AutoDirectionText and still get the exact body ramp.
      parts.add(
        DefaultTextStyle(style: bodyStyleOf(context, side), child: body),
      );
    }

    if (media != null) {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(height: mediaTopGap));
      }
      parts.add(_MediaSlot(media: media!, side: side));
    }

    final Widget? meta = _meta(context);
    if (meta != null) {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(height: metaTopGap));
      }
      parts.add(meta);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      // Resolved against the ambient Directionality by RenderFlex, so the
      // outgoing meta hugs the bubble's trailing edge in both directions.
      crossAxisAlignment:
          outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: parts,
    );
  }

  Widget? _meta(BuildContext context) {
    if (time == null && status == null) {
      return null;
    }
    final TextStyle style = metaStyleOf(context, side);
    final List<Widget> parts = <Widget>[];

    if (time != null) {
      // The one LTR island: `9:25` must never render as `25:9`. The Row itself
      // stays directional, so the reading order is always time → status
      // (21 §8-4); only the digits are isolated, which is what keeps a
      // localized `Read` from being forced LTR.
      parts.add(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(time!, style: style),
        ),
      );
    }

    if (status != null) {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(width: metaSeparatorGap));
        if (status!.isText) {
          parts
            ..add(Text(metaSeparator, style: style))
            ..add(const SizedBox(width: metaSeparatorGap));
        }
      }
      parts.add(_statusNode(style));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }

  Widget _statusNode(TextStyle style) {
    final JeebChatStatus state = status!;
    Widget node = state.isText
        ? Text(state.label!, style: style)
        : Icon(
            state.icon,
            size: JeebChatStatus.iconSize,
            color: state.iconColor ?? style.color,
          );

    if (state.identifier != null || state.semanticLabel != null) {
      node = Semantics(
        identifier: state.identifier,
        label: state.semanticLabel,
        child: node,
      );
    }
    if (state.nodeKey != null) {
      node = KeyedSubtree(key: state.nodeKey, child: node);
    }
    return node;
  }
}

/// Read defensively: harnesses that theme with a bare `ThemeData` carry no
/// extension, and a bare `!` would crash them.
JeebSemanticColors _semanticsOf(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

/// The voice row or the photo tile — private, because "one or the other" is
/// enforced by [JeebChatMedia]'s two constructors, not by a flag here.
class _MediaSlot extends StatelessWidget {
  const _MediaSlot({required this.media, required this.side});

  final JeebChatMedia media;
  final JeebChatBubbleSide side;

  @override
  Widget build(BuildContext context) =>
      media.isVoice ? _voice(context) : _photo(context);

  Widget _voice(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Glass on glass: a play control is not one of §2.2's orange moments, so
    // the light era's primary/onPrimary inversion is gone.
    final Color discFill = _semanticsOf(context).glassFillEmphasis;
    final Color discInk = scheme.onSurface;

    Widget disc = Container(
      width: JeebChatMedia.discDiameter,
      height: JeebChatMedia.discDiameter,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(color: discFill, shape: BoxShape.circle),
      child: Icon(
        media.playIcon,
        size: JeebChatMedia.playGlyphSize,
        color: discInk,
      ),
    );

    if (media.onPlay != null) {
      disc = Semantics(
        identifier: media.playIdentifier,
        label: media.playSemanticLabel,
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: media.onPlay,
            child: disc,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        disc,
        const SizedBox(width: JeebChatMedia.rowGap),
        if (media.waveform != null) media.waveform!,
        if (media.waveform != null)
          const SizedBox(width: JeebChatMedia.rowGap),
        Flexible(
          child: Text(
            media.label!,
            style: JeebChatBubble.mediaLabelStyleOf(context, side),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _photo(BuildContext context) {
    final JeebSemanticColors semantics = _semanticsOf(context);

    Widget tile = Container(
      width: JeebChatMedia.photoWidth,
      height: JeebChatMedia.photoHeight,
      alignment: AlignmentDirectional.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: semantics.glassFillEmphasis,
        borderRadius: const BorderRadius.all(
          Radius.circular(JeebChatMedia.photoRadius),
        ),
      ),
      child: media.photo == null
          ? Icon(
              media.photoIcon,
              size: JeebChatMedia.photoGlyphSize,
              // Decorative placeholder glyph, not body ink.
              color: semantics.mutedText,
            )
          : SizedBox.expand(child: media.photo),
    );

    if (media.onPhotoTap != null) {
      tile = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: const BorderRadius.all(
            Radius.circular(JeebChatMedia.photoRadius),
          ),
          onTap: media.onPhotoTap,
          child: tile,
        ),
      );
    }

    if (media.photoIdentifier != null || media.photoSemanticLabel != null) {
      tile = Semantics(
        identifier: media.photoIdentifier,
        label: media.photoSemanticLabel,
        button: media.onPhotoTap != null,
        image: true,
        child: tile,
      );
    }

    return tile;
  }
}
