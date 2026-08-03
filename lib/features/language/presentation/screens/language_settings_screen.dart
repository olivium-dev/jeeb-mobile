import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/layout/bottom_inset.dart';
import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../core/widgets/jeeb/jeeb_segmented_toggle.dart';
import '../../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../../l10n/app_localizations.dart';

/// Settings → Language picker (T-mobile-044 / JEEB-135; registered as
/// `language-settings` at `/settings/language` in W4-INT, JM-059).
///
/// The actual locale persistence and resolution lives in [LocaleCubit] — this
/// screen is a thin presentational view that drives the cubit. Selection is
/// instant (no app restart): the root [MaterialApp] watches the cubit and
/// rebuilds with the new [Locale], including the RTL flip when Arabic is
/// picked.
///
/// redesign-2026-08: re-skinned onto the Jeeb design system. The Material app
/// bar became the in-body [JeebTopBar] and the two check-marked settings rows
/// became the one two-up [JeebSegmentedToggle] screen 20 draws for the same
/// choice — selection is a navy fill swap, not a trailing glyph. The band is
/// deliberately the only content: the empty lower two-thirds is the board's
/// `flex: 1`, never filled.
///
/// Directionality is the point of this screen, so nothing here is positional:
/// the toggle's `selectedIndex` is derived from the locale (not from which
/// segment sits on the leading edge), and the segments mirror for free under
/// the RTL flip they themselves trigger.
///
/// W4-INT (JM-059): canonical Semantics ids added while registering the route
/// (40_GUARDRAILS_ARCH §8 — touch a widget for a JM, add its `identifier:`):
/// `language_settings_root`, `language_english_option`, `language_arabic_option`
/// (the JM-059 AC names `language_arabic_option` for the instant RTL flip), and
/// `language_back` on the app-bar back control.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const routeName = '/settings/language';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;

    return Semantics(
      identifier: 'language_settings_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: SafeArea(
          // The list reserves the nav-bar inset itself, so it may scroll under
          // the soft buttons in edge-to-edge mode.
          bottom: false,
          child: Column(
            children: [
              JeebTopBar.back(
                title: l10n.settingsLanguage,
                identifier: 'language_back',
                // Reachable with an empty Navigator stack (deep link), so pop
                // only when we can — popping the last page shows a blank
                // surface.
                onLeadingPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(
                child: ListView(
                  key: const Key('language-settings-list'),
                  padding: EdgeInsetsDirectional.fromSTEB(
                    Spacing.xLarge,
                    0,
                    Spacing.xLarge,
                    context.scrollBodyBottomInset,
                  ),
                  children: [
                    // Same first-band offset the sibling `/settings` list uses
                    // under its own JeebTopBar, so the two screens line up.
                    const SizedBox(height: Spacing.medium),
                    JeebSectionLabel(l10n.settingsLanguage),
                    const SizedBox(height: Spacing.xSmall),
                    JeebSegmentedToggle(
                      // Driven by the locale, never by a positional guess — an
                      // unlisted locale selects nothing rather than lighting up
                      // "English".
                      selectedIndex: locale.languageCode == 'ar' ? 1 : 0,
                      onChanged: (index) => context
                          .read<LocaleCubit>()
                          .setLocale(Locale(index == 0 ? 'en' : 'ar')),
                      segments: [
                        JeebSegment(
                          key: const Key('language-row-en'),
                          identifier: 'language_english_option',
                          label: l10n.settingsLanguageEnglish,
                        ),
                        JeebSegment(
                          key: const Key('language-row-ar'),
                          identifier: 'language_arabic_option',
                          label: l10n.settingsLanguageArabic,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
