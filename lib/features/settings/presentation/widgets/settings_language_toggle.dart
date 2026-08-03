import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../core/widgets/jeeb/jeeb_segmented_toggle.dart';
import '../../../../l10n/app_localizations.dart';

/// LANGUAGE label + the two-up EN/AR pill (redesign-2026-08 §3.5).
///
/// JEBV4-204 note kept from the section this replaces: the in-app *role* switch
/// was removed and never comes back here — this pill is a locale control only.
class SettingsLanguageToggle extends StatelessWidget {
  const SettingsLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.settingsLanguage),
        const SizedBox(height: Spacing.xSmall),
        JeebSegmentedToggle(
          // Driven by the locale, never by a positional guess — an unlisted
          // locale selects nothing instead of lighting up "English".
          selectedIndex: locale.languageCode == 'ar' ? 1 : 0,
          onChanged: (index) => context
              .read<LocaleCubit>()
              .setLocale(Locale(index == 0 ? 'en' : 'ar')),
          segments: [
            JeebSegment(
              key: const Key('settings-row-language-en'),
              identifier: 'settings_language_en_option',
              label: l10n.settingsLanguageEnglish,
            ),
            JeebSegment(
              key: const Key('settings-row-language-ar'),
              identifier: 'settings_language_ar_option',
              label: l10n.settingsLanguageArabic,
            ),
          ],
        ),
      ],
    );
  }
}
