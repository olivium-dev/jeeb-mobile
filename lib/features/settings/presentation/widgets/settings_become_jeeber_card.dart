import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../../l10n/app_localizations.dart';

/// The orange-framed growth card (redesign-2026-08 §3.4).
///
/// No role gate: today's screen offers this to everyone and the board does not
/// change that. The Ø38 disc is the screen's single orange FILL — the frame and
/// the `Start` word spend the rest of the R5 budget.
class SettingsBecomeJeeberCard extends StatelessWidget {
  const SettingsBecomeJeeberCard({super.key});

  /// Ø38 accent disc + 19px glyph (board `tpl 1179-1181`).
  static const double discDiameter = 38;
  static const double discGlyphSize = 19;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final roles = context.jeebRoles;
    final muted = Theme.of(context).extension<JeebSemanticColors>()!.mutedText;

    return JeebAccentFrameCard(
      key: const Key('settings-row-become-jeeber'),
      identifier: 'settings-row-become-jeeber',
      onTap: () => context.pushNamed('kyc-status'),
      child: Row(
        children: [
          Container(
            width: discDiameter,
            height: discDiameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: roles.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delivery_dining,
              size: discGlyphSize,
              color: roles.onAccent,
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.becomeJeeberCardTitle,
                  style: context.jeebText.cardTitle.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  l10n.settingsBecomeJeeberSubtitle,
                  style: context.jeebText.bodySmall.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.small),
          Text(
            l10n.settingsBecomeJeeberCta,
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: roles.accent,
            ),
          ),
        ],
      ),
    );
  }
}
