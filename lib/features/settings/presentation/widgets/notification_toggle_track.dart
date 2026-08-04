import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';

/// The board's notification toggle (MIDNIGHT R22 `tpl 1382`/`tpl 1392`) — an
/// orange track under a white knob with a `0 0 12px` bloom when on.
///
/// Shared by R22's NOTIFICATIONS card and the notification-preferences screen,
/// which draw the same control. It is painted rather than themed because
/// `OmdsSettingsSwitchRow` forwards only `activeColor` — the *thumb* — so the
/// selected TRACK resolves off `SwitchThemeData.trackColor`
/// (`JeebMidnight.inkMuted`, periwinkle) and the orange is unreachable.
class NotificationToggleTrack extends StatelessWidget {
  const NotificationToggleTrack({super.key, required this.value});

  /// 46×26 track, Ø20 knob inset 3 on every side.
  static const double trackWidth = 46;
  static const double trackHeight = 26;
  static const double knobDiameter = 20;
  static const double knobInset = 3;

  /// `0 0 12px rgba(215,59,0,.5)` — the ON bloom.
  static const double glowBlur = 12;
  static const double glowAlpha = 0.5;

  final bool value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roles = context.jeebRoles;
    final semantics = Theme.of(context).extension<JeebSemanticColors>()!;

    return SizedBox(
      width: trackWidth,
      height: trackHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: value ? roles.accent : semantics.glassFillPressed,
          borderRadius: OmdsBorderRadius.pill,
          boxShadow: value
              ? <BoxShadow>[
                  BoxShadow(
                    color: roles.accent.withValues(alpha: glowAlpha),
                    blurRadius: glowBlur,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(knobInset),
          child: Align(
            // Directional so the knob travels to the reading-end when on, and
            // mirrors with the layout instead of pinning itself to the right.
            alignment: value
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: SizedBox(
              width: knobDiameter,
              height: knobDiameter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.onPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
