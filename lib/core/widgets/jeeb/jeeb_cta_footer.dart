import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_text_styles.dart';

/// The three realized footer shapes (redesign-2026-08 §5 #2 / §02-3.3).
enum JeebCtaFooterForm {
  /// One pill, optionally with a line beneath it (10's cancel note, 23's
  /// orange fees link).
  single,

  /// Two affordances side by side — 01 `Skip` + `Next →`,
  /// 12 `Report no-show` + `Open dispute`.
  split,

  /// No pill at all: an orange note over a bare text action (11).
  textStack,
}

/// The docked call-to-action footer (redesign-2026-08 §5 #2).
///
/// 22 of 24 screens end in exactly one `flex: 1` spacer followed by this, so
/// the padding is the shared part — but the plan is explicit that this is
/// **three realized forms, not one padding**, and each has its own named
/// constructor.
///
/// Layout only: it holds no state, paints no background and adds no
/// `Semantics` node of its own (its children carry the ids). It also does
/// **not** apply a `SafeArea` — 08 wraps it in `SafeArea(top: false, …)` while
/// 23 places [inline] mid-scroll where a bottom inset would be wrong. Padding
/// is directional, so the 24px gutters mirror under RTL.
class JeebCtaFooter extends StatelessWidget {
  /// One affordance, optionally with [below] beneath it.
  ///
  /// 08 10 14 15 17 (docked pill) and 23 (`padding: JeebCtaFooter.inline`,
  /// `below: JeebCtaButton.accentText(...)`).
  /// [child] is declared **last** on purpose: `sort_child_properties_last` (in
  /// `flutter_lints`) fires at every call site that passes `below:` after
  /// `child:`, and 24 lanes should not each have to discover that.
  const JeebCtaFooter.single({
    super.key,
    this.below,
    this.spacing = 10,
    this.padding = docked,
    required this.child,
  })  : form = JeebCtaFooterForm.single,
        leading = null,
        trailing = null,
        action = null,
        note = null,
        expandLeading = false;

  /// Two affordances in a row, [spacing] apart.
  ///
  /// [leading] is an arbitrary widget, not a `JeebCtaButton` — 01 must pass its
  /// existing `OmdsSkipButton` (a test pins the type). [trailing] is always
  /// `Expanded`; [leading] only when [expandLeading] is set (01 `tpl 56` is
  /// intrinsic at pad `0/22`, 12 `tpl 782` is `flex: 1`).
  const JeebCtaFooter.split({
    super.key,
    required this.leading,
    required this.trailing,
    this.expandLeading = false,
    this.spacing = 12,
    this.padding = docked,
  })  : form = JeebCtaFooterForm.split,
        child = null,
        below = null,
        action = null,
        note = null;

  /// An orange note over a bare text action, both centred — 11 `tpl 705-707`.
  ///
  /// [note] is a `String`, not a widget: its 12/w700 accent styling is the
  /// whole reason this form is named, and the one screen that uses it must not
  /// be able to re-derive it.
  const JeebCtaFooter.textStack({
    super.key,
    required this.note,
    required this.action,
    this.spacing = 10,
    this.padding = docked,
  })  : form = JeebCtaFooterForm.textStack,
        child = null,
        below = null,
        leading = null,
        trailing = null,
        expandLeading = false;

  /// Docked: pad `0/24/32`.
  ///
  /// The board draws 30 on 11/12 and 32 on 14; §02-3.2 resolves it — "pick 32
  /// and note the divergence" — so every docked footer is 32.
  static const EdgeInsetsGeometry docked =
      EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32);

  /// Inline: pad `16/24/0` — 23 `tpl 1381`, the one CTA that is mid-flow rather
  /// than docked.
  static const EdgeInsetsGeometry inline =
      EdgeInsetsDirectional.fromSTEB(24, 16, 24, 0);

  /// Which of the three forms this is.
  final JeebCtaFooterForm form;

  /// The single form's affordance.
  final Widget? child;

  /// Optional line under the single form's affordance (10's cancel note at
  /// `spacing: Spacing.small`, 23's orange link at the default 10).
  final Widget? below;

  /// Split form: the start-side affordance.
  final Widget? leading;

  /// Split form: the end-side affordance, always `Expanded`.
  final Widget? trailing;

  /// Split form: whether [leading] is also `Expanded` (12 yes, 01 no).
  final bool expandLeading;

  /// Text-stack form: the accent note above [action].
  final String? note;

  /// Text-stack form: the affordance under [note].
  final Widget? action;

  /// Gap between the two stacked/side-by-side parts. 12 in [split],
  /// 10 elsewhere.
  final double spacing;

  /// Outer padding — [docked] or [inline], or a directional override.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: _content(context));
  }

  Widget _content(BuildContext context) {
    switch (form) {
      case JeebCtaFooterForm.single:
        if (below == null) {
          return child!;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            child!,
            SizedBox(height: spacing),
            below!,
          ],
        );

      case JeebCtaFooterForm.split:
        return Row(
          children: <Widget>[
            if (expandLeading) Expanded(child: leading!) else leading!,
            SizedBox(width: spacing),
            Expanded(child: trailing!),
          ],
        );

      case JeebCtaFooterForm.textStack:
        // 12/w700 accent — `jeebText.bodySmall` is already 12/w600, so only the
        // weight and the ink are added. No raw fontSize, no literal orange.
        final TextStyle noteStyle = context.jeebText.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          color: context.jeebRoles.accent,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(note!, style: noteStyle, textAlign: TextAlign.center),
            SizedBox(height: spacing),
            action!,
          ],
        );
    }
  }
}
