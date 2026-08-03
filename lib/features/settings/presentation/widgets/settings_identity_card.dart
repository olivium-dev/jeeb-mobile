import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_state.dart';

/// The navy identity card at the top of Settings (redesign-2026-08 §3.3).
///
/// This is the ONLY shadowed surface on the screen — every other card is
/// outline-over-shadow (R7), so `JeebShadows.ctaNavy` appears exactly once.
class SettingsIdentityCard extends StatelessWidget {
  const SettingsIdentityCard({super.key, required this.state});

  /// Card radius — 18 (board `tpl 1171`), between the 16 of the cards below it
  /// and the 20 of the stat heroes elsewhere.
  static const double radius = 18;

  /// Avatar diameter (board `tpl 1172`). Odd sizes use `JeebAvatar`'s unnamed
  /// constructor; its measured initial size for Ø50 is the board's 18px.
  static const double avatarDiameter = 50;

  /// Trailing chevron size + opacity (board `tpl 1176`).
  static const double chevronSize = 18;
  static const double chevronOpacity = 0.7;

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final muted = Theme.of(context).extension<JeebSemanticColors>()!.mutedText;
    final displayName = state.profile.name ?? l10n.profileNamePlaceholder;

    return JeebNavySurfaceCard(
      key: const Key('settings-row-profile'),
      radius: radius,
      shadow: JeebShadows.ctaNavy,
      identifier: 'settings-profile-row',
      onTap: () => context.pushNamed('settings-profile'),
      child: Row(
        children: [
          JeebAvatar(
            initial: displayName,
            diameter: avatarDiameter,
            imageUrl: state.profile.photoUrl,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.jeebText.cardTitle.copyWith(
                    color: cs.onPrimary,
                  ),
                ),
                // One Text on purpose: `find.textContaining` has to resolve the
                // phone even though it shares the line with the edit action.
                Text(
                  _subtitle(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.jeebText.bodySmall.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.small),
          Icon(
            DirectionalIcons.disclosure(context),
            size: chevronSize,
            color: cs.onPrimary.withValues(alpha: chevronOpacity),
          ),
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    if (state.profile.phoneE164.isEmpty) return l10n.profileEditSubtitle;
    return l10n.settingsIdentitySubtitle(
      phone: _ltrIsolate(state.profile.phoneE164),
      action: l10n.profileEditTitle,
    );
  }

  /// U+2066 LEFT-TO-RIGHT ISOLATE — opens an LTR-directional run.
  static const String _lri = '\u2066';

  /// U+2069 POP DIRECTIONAL ISOLATE — closes the run opened by [_lri].
  static const String _pdi = '\u2069';

  /// Keeps an E.164 number's `+` on its left inside an RTL line. Same escape
  /// pair as the existing precedent in `money_format.dart:25-26`.
  static String _ltrIsolate(String value) => '$_lri$value$_pdi';
}
