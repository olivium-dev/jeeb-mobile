import 'package:flutter/material.dart';

import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';

/// One canned reply in a [JeebQuickReplyRow].
///
/// Identifiers are **intent-keyed, not index-keyed**
/// (`order_chat_quick_reply_home` / `_door` / `_thanks`), so they survive
/// reordering and locale changes (21 §7.2).
@immutable
class JeebQuickReply {
  const JeebQuickReply({
    required this.label,
    this.onTap,
    this.identifier,
    this.semanticLabel,
  });

  /// The canned string. May be Arabic inside an English thread — that is the
  /// whole point of the row, and why it is never force-LTR.
  final String label;

  /// One-tap send. Null renders the pill disabled-looking but inert.
  final VoidCallback? onTap;

  /// Maestro id, applied via an explicit `Semantics` wrapper.
  final String? identifier;

  /// Overrides the announced text; defaults to [label] merging up.
  final String? semanticLabel;
}

/// The quick-reply row (redesign-2026-08 §5 #26) — net new on screen 21.
///
/// Horizontally scrollable rest-glass pills: pad `8/13`, `glassFill` + 1px
/// `glassBorder`, 12.5/w600 ink, gap 8, `nowrap`, container pad `10/24/0`.
///
/// **Never force-LTR.** The row deliberately mixes an Arabic pill into an
/// English thread, so it inherits the ambient [Directionality] and lets each
/// label shape itself. `SingleChildScrollView` already starts at the leading
/// edge under RTL — do **not** add `reverse: true` (21 §8-5).
///
/// **Why this does not delegate to `JeebSelectChip.quickReply` (§5 #6):** that
/// widget is a selection control with a selected/unselected state machine, and
/// it ships from a different lane in the same wave. A quick reply is never
/// selected — it fires and disappears — so it would be pinned to
/// `selected: false` forever. The measured geometry is exposed as statics here
/// so the two pills can be reconciled without guessing at the numbers.
class JeebQuickReplyRow extends StatelessWidget {
  const JeebQuickReplyRow({
    super.key,
    required this.replies,
    this.padding = defaultPadding,
    this.identifier,
    this.semanticLabel,
  });

  /// `padding: 8px 13px` (`tpl 1273`).
  static const EdgeInsetsGeometry pillPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 8);

  /// 1px, every glass surface (token sheet §4) — the light era drew 1.5.
  static const double borderWidth = 1;

  /// `gap: 8` (`tpl 1272`).
  static const double gap = 8;

  /// `padding: 10px 24px 0` (`tpl 1272`) — inside the scroll view, so the pills
  /// scroll under the gutter instead of being clipped by it.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.fromSTEB(24, 10, 24, 0);

  /// The canned replies, in display order.
  final List<JeebQuickReply> replies;

  /// Row padding.
  final EdgeInsetsGeometry padding;

  /// `order_chat_quick_reply_row`. Emitted with `container: true` +
  /// `explicitChildNodes: true` so the per-pill ids are not merged away.
  final String? identifier;

  /// Accessibility label for the row ("Quick replies").
  final String? semanticLabel;

  /// `jeebText.bodySmall` (12.5/w600) in the primary ink — a glass pill takes
  /// the white ink; `colorScheme.primary` is orange and out of budget here.
  static TextStyle labelStyleOf(BuildContext context) =>
      context.jeebText.bodySmall
          .copyWith(color: Theme.of(context).colorScheme.onSurface);

  @override
  Widget build(BuildContext context) {
    Widget row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < replies.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: gap),
            _QuickReplyPill(reply: replies[i]),
          ],
        ],
      ),
    );

    if (identifier != null || semanticLabel != null) {
      row = Semantics(
        identifier: identifier,
        label: semanticLabel,
        container: true,
        explicitChildNodes: true,
        child: row,
      );
    }
    return row;
  }
}

class _QuickReplyPill extends StatelessWidget {
  const _QuickReplyPill({required this.reply});

  final JeebQuickReply reply;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();

    Widget pill = Container(
      // border-box: the 1px stroke sits outside the 8/13 inset. `Container`
      // adds `decoration.padding` (the border dimensions) itself, so the
      // correction lands without double-counting it here.
      padding: JeebQuickReplyRow.pillPadding,
      decoration: ShapeDecoration(
        color: semantics.glassFill,
        shape: StadiumBorder(
          side: BorderSide(
            color: semantics.glassBorder,
            width: JeebQuickReplyRow.borderWidth,
          ),
        ),
      ),
      child: Text(
        reply.label,
        style: JeebQuickReplyRow.labelStyleOf(context),
        maxLines: 1,
        // `white-space: nowrap` — the row scrolls instead of wrapping.
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (reply.onTap != null) {
      pill = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: reply.onTap,
          customBorder: const StadiumBorder(),
          child: pill,
        ),
      );
    }

    if (reply.identifier != null || reply.semanticLabel != null) {
      pill = Semantics(
        identifier: reply.identifier,
        label: reply.semanticLabel,
        button: true,
        enabled: reply.onTap != null,
        child: pill,
      );
    }
    return pill;
  }
}
