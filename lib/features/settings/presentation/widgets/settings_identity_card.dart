import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_state.dart';

/// The glass identity card at the top of Settings (MIDNIGHT R22 `tpl 1354`).
///
/// Emphasis glass — white 9 % over a white 18 % stroke on the board — and
/// **no shadow**: the caption's "stacked glass" is the fill step and the
/// stroke, not a lift.
class SettingsIdentityCard extends StatelessWidget {
  const SettingsIdentityCard({super.key, required this.state});

  /// Card radius. The board draws 20; `lg` is the ladder rung inside the
  /// ±2 tolerance, and every other card on this screen is `lg`.
  static const double radius = JeebRadii.lg;

  /// `15px 16px` (board `tpl 1354`).
  static const EdgeInsetsGeometry padding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 15);

  /// Avatar diameter (board `tpl 1355`). Ø50's initial resolves to 18px, and
  /// `primary` re-tones on this card to the board's white-14 % disc.
  static const double avatarDiameter = 50;

  /// Gap between the disc, the text block and the chevron (board `gap:13`).
  static const double gap = 13;

  /// Trailing chevron (board `tpl 1360`: 18px, `#8A93D8`).
  static const double chevronSize = 18;

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final muted = (Theme.of(context).extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight()).mutedText;
    final displayName = state.profile.name ?? l10n.profileNamePlaceholder;

    return JeebNavySurfaceCard(
      key: const Key('settings-row-profile'),
      radius: radius,
      padding: padding,
      identifier: 'settings-profile-row',
      onTap: () => context.pushNamed('settings-profile'),
      child: Row(
        children: [
          JeebAvatar(
            initial: displayName,
            diameter: avatarDiameter,
            imageUrl: state.profile.photoUrl,
          ),
          const SizedBox(width: gap),
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
                    color: cs.onSurface,
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
          const SizedBox(width: gap),
          Icon(
            DirectionalIcons.disclosure(context),
            size: chevronSize,
            color: muted,
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
