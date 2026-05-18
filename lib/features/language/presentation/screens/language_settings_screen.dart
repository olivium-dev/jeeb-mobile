import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/locale/locale_cubit.dart';
import '../../../../l10n/app_localizations.dart';

/// Settings → Language picker (T-mobile-044 / JEEB-135).
///
/// The actual locale persistence and resolution lives in [LocaleCubit] — this
/// screen is a thin presentational view that drives the cubit. Selection is
/// instant (no app restart): the root [MaterialApp] watches the cubit and
/// rebuilds with the new [Locale], including the RTL flip when Arabic is
/// picked.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const routeName = '/settings/language';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;

    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.settingsLanguage,
        showBackButton: true,
      ),
      body: ListView(
        key: const Key('language-settings-list'),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
        children: [
          OmdsSettingsSection(
            title: l10n.settingsLanguage,
            children: [
              _LanguageRow(
                rowKey: const Key('language-row-en'),
                title: l10n.settingsLanguageEnglish,
                languageCode: 'en',
                selected: locale.languageCode == 'en',
              ),
              _LanguageRow(
                rowKey: const Key('language-row-ar'),
                title: l10n.settingsLanguageArabic,
                languageCode: 'ar',
                selected: locale.languageCode == 'ar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.rowKey,
    required this.title,
    required this.languageCode,
    required this.selected,
  });

  final Key rowKey;
  final String title;
  final String languageCode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: ExcludeSemantics(
        child: OmdsSettingsRow(
          key: rowKey,
          title: title,
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: () =>
              context.read<LocaleCubit>().setLocale(Locale(languageCode)),
        ),
      ),
    );
  }
}
