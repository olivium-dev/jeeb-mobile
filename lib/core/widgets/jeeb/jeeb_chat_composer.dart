import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import '../../theme/jeeb_text_styles.dart';

/// The single-pill chat composer (redesign-2026-08 §5 #18).
///
/// One frosted-glass pill holds the field and both actions:
/// `[field] [19px attach glyph] [Ø38 orange send disc]`.
///
/// MIDNIGHT: `glassFillEmphasis` + 1px `glassBorderStrong`, pre-baked (no
/// `BackdropFilter` — the ≤2-per-screen blur budget belongs to the screen).
///
/// **The circle is SEND, never a mic (B-04).** The board draws no send button
/// at all — its mic occupies the send slot — so shipping the mic would be
/// "replace send with a mic", not "add a mic". `chat_composer_no_mic_b04_test`
/// asserts `Icons.mic_none` is absent and the Dart test wins over the render
/// (21 §9). Four stale Maestro flows still assert `chat_detail_voice_button`;
/// they belong to the E2E owner, not to this kit.
///
/// Presentation-only: no cubit, no repository. `isAttaching`, `onSend == null`
/// (disabled) and the text all arrive from the caller.
///
/// **Why the field is a bare [TextField] and not `OmdsTextField(suffixIcon:)`:**
/// 21 §5.5 flags that the two actions inside an `InputDecoration.suffixIcon`
/// may not stay hit-testable at 48dp, and instructs the fallback — one pill
/// container with the field made transparent and the actions as real siblings.
/// That is what this builds, so the 48dp targets are structural.
class JeebChatComposer extends StatelessWidget {
  const JeebChatComposer({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
    this.onSend,
    this.onAttach,
    this.isAttaching = false,
    this.minLines = 1,
    this.maxLines = 5,
    this.padding = defaultPadding,
    this.useSafeArea = true,
    this.fieldKey,
    this.attachKey,
    this.sendKey,
    this.inputIdentifier,
    this.attachIdentifier,
    this.sendIdentifier,
    this.inputSemanticLabel,
    this.attachSemanticLabel,
    this.sendSemanticLabel,
    this.attachIcon = Icons.image_outlined,
    this.sendIcon = Icons.send,
  });

  /// `height: 52` (`tpl 1277`) — a **minimum**, so a growing field grows the
  /// pill instead of clipping.
  static const double pillHeight = 52;

  /// 1px, every glass surface (token sheet §4).
  static const double pillBorderWidth = 1;

  /// 19px attach glyph (`tpl 1279`).
  static const double attachGlyphSize = 19;

  /// Ø38 send circle (`tpl 1281`).
  static const double sendDiameter = 38;

  /// 18px send glyph (`tpl 1282`).
  static const double sendGlyphSize = 18;

  /// Minimum tap target. 21 §5.5: "Do not shrink the tap targets below 48dp to
  /// fit the design's 19px glyph — pad it."
  static const double tapTargetSize = 48;

  /// `gap: 10` between the field and the first action (`tpl 1277`).
  static const double fieldGap = 10;

  /// Pill inset. The board says `0 8px 0 18px`; the end is **3** because the
  /// Ø38 circle is centred inside a 48dp tap box, so `3 + (48−38)/2 = 8` puts
  /// the circle's visible edge exactly where the board puts it.
  static const EdgeInsetsGeometry pillPadding =
      EdgeInsetsDirectional.only(start: 18, end: 3);

  /// `padding: 10px 24px 30px` (`tpl 1276`) — the 24 is the universal gutter and
  /// the 30 is the home-indicator area, supplied by [useSafeArea] instead.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.fromSTEB(24, 10, 24, 10);

  /// Fade applied to the send circle when [onSend] is null. Functional state,
  /// deliberately kept from the pre-redesign composer (21 §2).
  static const double disabledOpacity = 0.38;

  /// The composer text. Owned by the caller (a `ChatCubit` listener today).
  final TextEditingController controller;

  /// Placeholder — `body` in periwinkle.
  final String hintText;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Text-change callback.
  final ValueChanged<String>? onChanged;

  /// Send handler. **Null disables** the circle (fade + `Semantics.enabled`).
  final VoidCallback? onSend;

  /// Attach handler. Null disables the glyph.
  final VoidCallback? onAttach;

  /// Swaps the attach glyph for a spinner while a pick is in flight.
  final bool isAttaching;

  /// Field min lines.
  final int minLines;

  /// Field max lines before it scrolls.
  final int maxLines;

  /// Padding around the pill.
  final EdgeInsetsGeometry padding;

  /// Wraps the bar in `SafeArea(top: false)` so the pill clears the home
  /// indicator without the consumer remembering.
  final bool useSafeArea;

  /// Key on the text field — pass `ChatComposer.textFieldKey`.
  final Key? fieldKey;

  /// Key on the attach target — pass `ChatComposer.attachButtonKey`
  /// (`chat_picker_binding_test` taps it).
  final Key? attachKey;

  /// Key on the send target — pass `ChatComposer.sendButtonKey`.
  final Key? sendKey;

  /// `chat_detail_message_input` / `order_chat_composer_input`.
  final String? inputIdentifier;

  /// `chat_detail_attach_button`.
  final String? attachIdentifier;

  /// `chat_detail_send_button` / `order_chat_composer_send`.
  final String? sendIdentifier;

  /// Accessibility label for the field.
  final String? inputSemanticLabel;

  /// Accessibility label for the attach action.
  final String? attachSemanticLabel;

  /// Accessibility label for the send action.
  final String? sendSemanticLabel;

  /// Attach glyph — the board draws the photo mark, not a `+` (`tpl 1279`).
  final IconData attachIcon;

  /// Send glyph. `Icons.send` carries `matchTextDirection: true`, so it mirrors
  /// itself under RTL.
  final IconData sendIcon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics = _semanticsOf(context);
    final TextStyle bodyStyle = context.jeebText.body;

    final Widget pill = DecoratedBox(
      decoration: ShapeDecoration(
        color: semantics.glassFillEmphasis,
        shape: StadiumBorder(
          side: BorderSide(
            color: semantics.glassBorderStrong,
            width: pillBorderWidth,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: pillHeight),
        child: Padding(
          // border-box: the 1px stroke sits outside the 0/8/0/18 inset.
          padding: pillPadding.add(const EdgeInsets.all(pillBorderWidth)),
          child: Row(
            children: <Widget>[
              Expanded(child: _field(context, scheme, bodyStyle)),
              const SizedBox(width: fieldGap),
              _attach(context, scheme),
              _send(context, scheme),
            ],
          ),
        ),
      ),
    );

    final Widget bar = Padding(padding: padding, child: pill);
    return useSafeArea ? SafeArea(top: false, child: bar) : bar;
  }

  Widget _field(
    BuildContext context,
    ColorScheme scheme,
    TextStyle bodyStyle,
  ) {
    final Widget field = TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      style: bodyStyle.copyWith(color: scheme.onSurface),
      // Theme ruling 4: the caret is periwinkle app-wide, never the orange.
      cursorColor: scheme.secondary,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        // No box-in-a-box: the glass pill IS the decoration.
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hintText,
        hintStyle:
            bodyStyle.copyWith(color: _semanticsOf(context).mutedText),
      ),
    );

    if (inputIdentifier == null && inputSemanticLabel == null) {
      return field;
    }
    return Semantics(
      identifier: inputIdentifier,
      label: inputSemanticLabel,
      textField: true,
      child: field,
    );
  }

  Widget _attach(BuildContext context, ColorScheme scheme) {
    // A secondary action reads in the muted ink, like R1's inactive nav icons.
    final Color ink = scheme.onSurfaceVariant;
    final Widget glyph = isAttaching
        ? SizedBox(
            width: attachGlyphSize,
            height: attachGlyphSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: ink),
          )
        : Icon(attachIcon, size: attachGlyphSize, color: ink);

    return _JeebComposerAction(
      nodeKey: attachKey,
      identifier: attachIdentifier,
      semanticLabel: attachSemanticLabel,
      onTap: isAttaching ? null : onAttach,
      child: glyph,
    );
  }

  Widget _send(BuildContext context, ColorScheme scheme) {
    final bool enabled = onSend != null;
    // R20 draws this disc orange — the composer's one budgeted orange moment.
    final JeebRoles roles = context.jeebRoles;
    return _JeebComposerAction(
      nodeKey: sendKey,
      identifier: sendIdentifier,
      semanticLabel: sendSemanticLabel,
      onTap: onSend,
      child: Container(
        width: sendDiameter,
        height: sendDiameter,
        alignment: AlignmentDirectional.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? roles.accent
              : roles.accent.withValues(alpha: disabledOpacity),
          boxShadow: enabled ? JeebShadows.ctaOrangeSmall : null,
        ),
        child: Icon(sendIcon, size: sendGlyphSize, color: roles.onAccent),
      ),
    );
  }
}

/// Read defensively: harnesses that theme with a bare `ThemeData` carry no
/// extension, and a bare `!` would crash them.
JeebSemanticColors _semanticsOf(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

/// A 48×48 tap target with the measured glyph centred inside it.
///
/// The design's `19 + 10 + 38 = 67` trailing cluster cannot hold two
/// non-overlapping 48dp targets (that needs 96), so the 10px gap between the
/// two actions is absorbed by their padding. The glyph and the circle keep
/// their measured sizes; only the whitespace between them grows.
class _JeebComposerAction extends StatelessWidget {
  const _JeebComposerAction({
    required this.child,
    this.onTap,
    this.nodeKey,
    this.identifier,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Key? nodeKey;
  final String? identifier;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget target = SizedBox(
      width: JeebChatComposer.tapTargetSize,
      height: JeebChatComposer.tapTargetSize,
      child: Align(alignment: AlignmentDirectional.center, child: child),
    );

    if (onTap != null) {
      target = Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: onTap,
          radius: JeebChatComposer.tapTargetSize / 2,
          child: target,
        ),
      );
    }

    if (identifier != null || semanticLabel != null) {
      target = Semantics(
        identifier: identifier,
        label: semanticLabel,
        button: true,
        enabled: onTap != null,
        child: target,
      );
    }

    return nodeKey == null
        ? target
        : KeyedSubtree(key: nodeKey, child: target);
  }
}
