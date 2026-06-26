import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/locale/locale_cubit.dart';
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
        appBar: OMDSAppBar(
          title: l10n.settingsLanguage,
          showBackButton: false,
          leading: Semantics(
            identifier: 'language_back',
            button: true,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: ExcludeSemantics(
              child: IconButton(
                icon: const BackButtonIcon(),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            ),
          ),
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
                  identifier: 'language_english_option',
                  title: l10n.settingsLanguageEnglish,
                  languageCode: 'en',
                  selected: locale.languageCode == 'en',
                ),
                _LanguageRow(
                  rowKey: const Key('language-row-ar'),
                  identifier: 'language_arabic_option',
                  title: l10n.settingsLanguageArabic,
                  languageCode: 'ar',
                  selected: locale.languageCode == 'ar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.rowKey,
    required this.identifier,
    required this.title,
    required this.languageCode,
    required this.selected,
  });

  final Key rowKey;
  final String identifier;
  final String title;
  final String languageCode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      label: title,
      button: true,
      container: true,
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
