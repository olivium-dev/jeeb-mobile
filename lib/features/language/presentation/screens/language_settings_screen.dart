import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/locale/locale_cubit.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../devtool/catalog/fixtures/language_settings_screen_fixtures.dart';
import '../../../../core/previews/jeeb_preview.dart';

/// Settings → Language picker (T-mobile-044 / JEEB-135; registered as
/// `language-settings` at `/settings/language` in W4-INT, JM-059).
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone this screen is designed against.
const Size _languageSettingsScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports (iPhone SE 1st gen and the small
/// Android estate) — and roughly what an Android multi-window split leaves a
const Size _languageSettingsScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
final class LanguageSettingsScreenCaptions {
  LanguageSettingsScreenCaptions._();

  /// Nothing saved; the device reports whatever the card is rendering in.
  static const String followsAppLocale =
      'preview · no choice saved · device = app locale';

  /// The Screen Catalog's "English selected".
  static const String englishSaved = 'preview · saved choice: en';

  /// The Screen Catalog's "Arabic selected".
  static const String arabicSaved = 'preview · saved choice: ar';

  /// First launch on an unsupported device locale — the hard English default.
  static const String coldStart = 'preview · first launch · device = de';

  /// A persisted language the app no longer ships.
  static const String unsupportedSavedValue =
      'preview · saved choice: de (unsupported)';

  /// The layout ceiling: 320x568.
  static const String compactCeiling = 'preview · 320 x 568 ceiling';
}

/// Puts a dev caption above the device frame, so a card that is pixel-identical
/// to its neighbour still says which state it is.
class _LanguageSettingsScreenCaptioned extends StatelessWidget {
  const _LanguageSettingsScreenCaptioned({
    required this.caption,
    required this.child,
  });

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            caption,
            // Dev chrome: LTR and unscaled, so the AR card still reads it as
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(child: child),
      ],
    );
  }
}

/// Seats [LanguageSettingsScreen] over a fixture cubit at a pinned device box.
Widget _languageSettingsScreenHosted(
  LanguageSettingsScreenCubitFactory create,
  String caption, {
  Size box = _languageSettingsScreenPhoneBox,
}) =>
    _LanguageSettingsScreenCaptioned(
      caption: caption,
      child: LanguageSettingsScreenPreviewHost(
        create: create,
        box: box,
        child: const LanguageSettingsScreen(),
      ),
    );

/// The reference reading: no choice saved yet, so the cubit resolves to the
/// device locale — which here IS the locale the card is rendering in, exactly
@JeebPreview(
  group: 'language',
  name: 'Reference · follows the app locale',
  size: _languageSettingsScreenPhoneBox,
  matrix: true,
)
Widget languageSettingsScreenFollowsAppLocale() => _languageSettingsScreenHosted(
      LanguageSettingsScreenPreviewFixtures.followsAmbient,
      LanguageSettingsScreenCaptions.followsAppLocale,
    );

/// The Screen Catalog's "English selected": a returning user whose choice is
/// already persisted.
@JeebPreview(
  group: 'language',
  name: 'English saved',
  size: _languageSettingsScreenPhoneBox,
)
Widget languageSettingsScreenEnglishSaved() => _languageSettingsScreenHosted(
      LanguageSettingsScreenPreviewFixtures.englishSaved,
      LanguageSettingsScreenCaptions.englishSaved,
    );

/// The Screen Catalog's "Arabic selected", and the JM-059 AC state: the tick is
/// on `language_arabic_option`.
@JeebPreview(
  group: 'language',
  name: 'Arabic saved',
  size: _languageSettingsScreenPhoneBox,
)
Widget languageSettingsScreenArabicSaved() => _languageSettingsScreenHosted(
      LanguageSettingsScreenPreviewFixtures.arabicSaved,
      LanguageSettingsScreenCaptions.arabicSaved,
    );

/// First launch on a device the app does not ship a language for: nothing
/// persisted, the device says `de`, so `_resolveInitial` falls through both
@JeebPreview(
  group: 'language',
  name: 'Cold start · unsupported device locale',
  size: _languageSettingsScreenPhoneBox,
)
Widget languageSettingsScreenColdStart() => _languageSettingsScreenHosted(
      LanguageSettingsScreenPreviewFixtures.unsupportedDeviceLocale,
      LanguageSettingsScreenCaptions.coldStart,
    );

/// The robustness reading: the persisted value is a language the app no longer
/// ships (`de`), so `_isSupported` rejects it and resolution continues to the
@JeebPreview(
  group: 'language',
  name: 'Unsupported saved value · falls through',
  size: _languageSettingsScreenPhoneBox,
)
Widget languageSettingsScreenUnsupportedSavedValue() =>
    _languageSettingsScreenHosted(
      LanguageSettingsScreenPreviewFixtures.unsupportedSavedValue,
      LanguageSettingsScreenCaptions.unsupportedSavedValue,
    );

/// Layout ceiling: the narrowest supported phone, 320x568.
/// The user data on this screen is a fixed pair of endonyms, so the ceiling
@JeebPreview(
  group: 'language',
  name: 'Compact 320x568 · layout ceiling',
  size: _languageSettingsScreenCompactBox,
  matrix: true,
)
Widget languageSettingsScreenCompactCeiling() => _languageSettingsScreenHosted(
      LanguageSettingsScreenPreviewFixtures.englishSaved,
      LanguageSettingsScreenCaptions.compactCeiling,
      box: _languageSettingsScreenCompactBox,
    );
