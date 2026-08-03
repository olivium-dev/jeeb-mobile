import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_state.dart';
import 'logout_delete_confirm_sheet.dart';

/// Docked account footer (redesign-2026-08 §3.8) — the JM-062
/// `logout-delete-account` host.
///
/// Both affordances open [LogoutDeleteConfirmSheet], whose
/// `logout_confirm_cta` / `delete_confirm_cta` clear the local session and route
/// to splash (`/` → first-run gate → `/login`, D5). The section root keeps the
/// `logout_delete_account_root` identifier so the surface stays addressable and
/// the `account-status` (JM-066) sign-out CTA still lands somewhere real.
class SettingsFooter extends StatelessWidget {
  const SettingsFooter({
    super.key,
    required this.state,
    required this.appVersion,
  });

  /// Exit glyph size on the sign-out row (board `tpl 1217`).
  static const double signOutGlyphSize = 18;

  final SettingsState state;

  /// Human-readable app version rendered in the centred version line.
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    assert(
      _signOutGlyph.codePoint == Icons.logout.codePoint,
      'Icons.logout changed codepoint — update _signOutGlyph.',
    );
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).extension<JeebSemanticColors>()!.mutedText;
    final captionStyle = context.jeebText.caption.copyWith(color: muted);

    return Semantics(
      identifier: 'logout_delete_account_root',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        // The board's `0 24px 30px`; the screen owns the horizontal gutter, and
        // the top inset keeps the docked block off the scrolling content.
        padding: const EdgeInsetsDirectional.only(
          top: Spacing.medium,
          bottom: Spacing.twoXLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JeebOutlinedCard.grouped(
              children: [
                JeebListRow(
                  key: const Key('settings-row-sign-out'),
                  identifier: 'settings_sign_out_row',
                  icon: _signOutGlyph,
                  iconSize: signOutGlyphSize,
                  title: l10n.appBarSignOut,
                  titleStyle: context.jeebText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  // It acts in place rather than navigating, so no chevron.
                  showChevron: false,
                  padding: JeebOutlinedCard.defaultPadding,
                  isEnabled: !state.isSigningOut,
                  onTap: () => _confirmSignOut(context),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            Semantics(
              identifier: 'settings_delete_account_row',
              button: true,
              child: TextButton(
                key: const Key('settings-row-delete-account'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  textStyle: context.jeebText.bodySmall,
                ),
                onPressed: (!state.deletionPending && !state.isDeletingAccount)
                    ? () => _confirmDeleteAccount(context)
                    : null,
                child: Text(l10n.accountDeleteRow),
              ),
            ),
            if (state.deletionPending)
              Text(
                l10n.accountDeletePending,
                textAlign: TextAlign.center,
                style: captionStyle,
              ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.settingsVersionFooter(appVersion),
              textAlign: TextAlign.center,
              style: captionStyle,
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the delete-account confirm sheet (`delete_confirm_cta`). On confirm
  /// the sheet clears the session and routes to splash (D5).
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    await LogoutDeleteConfirmSheet.show(
      context,
      mode: LogoutDeleteMode.delete,
    );
  }

  /// Opens the sign-out confirm sheet (`logout_confirm_cta`). On confirm the
  /// sheet clears the session and routes to splash (D5).
  Future<void> _confirmSignOut(BuildContext context) async {
    await LogoutDeleteConfirmSheet.show(
      context,
      mode: LogoutDeleteMode.logout,
    );
  }
}

/// `Icons.logout` ships with `matchTextDirection: false`, so its arrow keeps
/// pointing at the LTR end edge inside an Arabic layout. This is the same glyph
/// with the flag on, which is what `Icon` reads to mirror itself — no
/// `Transform` at the call site, and `Icons.login` is NOT a substitute (that is
/// a different glyph, an arrow going *in*).
///
/// The codepoint is repeated because `IconData` only accepts const arguments;
/// [SettingsFooter.build]'s assert fails loudly if a Flutter upgrade moves it.
const IconData _signOutGlyph = IconData(
  0xe3b3,
  fontFamily: 'MaterialIcons',
  matchTextDirection: true,
);
