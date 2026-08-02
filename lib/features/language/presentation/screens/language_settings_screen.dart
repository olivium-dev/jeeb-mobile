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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/language/language_settings_screen_preview_test.dart
// ===========================================================================
//
// [LanguageSettingsScreen] is two rows over the ambient [LocaleCubit]. There is
// no repository, no `cubit:` seam, nothing async and no failure path in the
// widget at all — so there is no loading state and no error state to preview,
// and saying so is the point rather than an omission (the "no feedback"
// note below is what fills that hole in the design, not in the harness).
// EVERY designed state below is therefore one thing: which locale
// `LocaleCubit._resolveInitial` landed on, reached through a different arm of
// that resolution.
//
// The cubits, the in-memory prefs behind them and the seating are NOT declared
// here. They live in
// `lib/devtool/catalog/fixtures/language_settings_screen_fixtures.dart`, shared
// with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_06_entries.dart`), so the designer's browser
// and this canvas cannot drift into showing two different "English selected".
// Nothing there can reach the network or the DI graph: a [LocaleCubit] with no
// `LanguagePreferenceRepository` never makes a call, and the prefs are a map.
// The guard in [jeebPreviewHost] is the net here, not the plan.
//
// Four things about this harness before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + OMDSAppBar` paints inside it. Same nesting the
//    Screen Catalog produces.
//  * **The device frame is pinned in the TREE, not just in `size:`.** `size:`
//    boxes the canvas only; calling a preview function from a render test gets
//    the tester's 800x600 desktop surface. [LanguageSettingsScreenPreviewHost]
//    pins the same box in the widget tree, so a measurement in the test is a
//    measurement of the card.
//  * **A [LocaleCubit] ancestor is mandatory, not optional.** `build` calls
//    `context.watch<LocaleCubit>()` unconditionally, so a bare
//    `LanguageSettingsScreen` throws in the canvas. The host provides one; the
//    reference state seeds it from the AMBIENT locale, which is how the AR card
//    of a matrix checks "العربية" rather than showing an Arabic screen with the
//    English row ticked.
//  * **Each card carries a caption** ([LanguageSettingsScreenCaptions]). Four
//    of the six states below put the SAME three strings on screen — the app-bar
//    title, "English", "العربية" — and differ only in which row carries a tick
//    and in how the cubit got there. Without a caption a render test cannot
//    tell them apart, and neither can a reviewer. Dev chrome, never shipped
//    copy, so it is deliberately un-localized, LTR and unscaled.
//
// What these previews surfaced in the screen — none of it changed here:
//
//  * **The UNSELECTED row shows a disclosure chevron.** `_LanguageRow` passes
//    `trailing: selected ? const Icon(Icons.check) : null`, and a null
//    `trailing` makes `OmdsSettingsRow` fall back to its default
//    `icon: Icons.chevron_right`. So a radio group the code itself declares
//    `inMutuallyExclusiveGroup: true` renders one row with a tick and the other
//    with the "tap to navigate somewhere" affordance every other settings row
//    on the app uses. It mirrors correctly in AR (`Icons.chevron_right` is
//    `matchTextDirection: true`), which only makes it a more convincing
//    disclosure arrow. `SettingsScreen._LanguageRow` is the same code and has
//    the same rendering.
//  * **There is no "follow system language" affordance, and picking a language
//    is one-way.** [LocaleCubit] ships `resetToDeviceLocale()`, which clears the
//    persisted key and returns to the device locale; nothing on this screen —
//    or on `SettingsScreen`, the other host of these rows — calls it. Before
//    the first tap the app follows the device ([languageSettingsScreenColdStart]
//    below is that state); after it, the choice is written and a user cannot
//    get back to following the device from the UI at all.
//  * **Selecting is fire-and-forget: no in-flight, no success, no failure.**
//    `setLocale` emits, awaits `prefs.setString`, then mirrors the choice to the
//    remote preferences store — and `_pushRemote` swallows every failure by
//    design (offline-first). The screen renders nothing for any of it, so a user
//    whose language never reached the server sees exactly what a user whose
//    language did sees. That is the whole reason there is no loading or error
//    card below: those states exist in the cubit and have no rendering.
//  * **"Language" is painted twice, 24 pt apart.** The `OMDSAppBar` title and
//    the only `OmdsSettingsSection` header below it are both
//    `l10n.settingsLanguage`. On a screen with two rows that is a third of the
//    visible copy spent saying the same word twice. `SettingsScreen` hosts the
//    same section under an app bar that says "Settings", so this is specific to
//    the standalone route.
//  * **At 200% text the section header is BIGGER than the screen's title.**
//    `AppBar` wraps its title in
//    `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.34)`, so the app-bar
//    headline stops growing at ~1.34x while the section header — the same word
//    — keeps scaling to 2x. Measured on the ceiling card with the real faces:
//    the bar title is the taller of the two at 100% and the shorter at 200%.
//    Nothing overflows; the hierarchy just inverts.
//  * **Both back controls are live, and neither works in a preview.** The
//    `language_back` node carries `onTap:` and the [IconButton] it wraps in
//    `ExcludeSemantics` carries the same guarded pop again. Both call
//    `context.canPop()`, which needs a [GoRouter] above the widget; there is
//    none above a preview card, so pressing back in the canvas throws. The rows
//    themselves are fully live — tap them and the tick moves.

/// The phone this screen is designed against.
const Size _languageSettingsScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports (iPhone SE 1st gen and the small
/// Android estate) — and roughly what an Android multi-window split leaves a
/// foreground app.
const Size _languageSettingsScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist: four of these six states put NO distinguishing production copy on
/// screen. Dev chrome, never shipped copy.
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
            // one latin line and the 200% card does not spend a third of the
            // device on a label.
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
/// as in the shipped app (the root `MaterialApp` watches this same cubit, so
/// the ticked row and the copy on screen can never disagree there).
///
/// Matrixed because this screen is nothing but directional chrome: a leading
/// back control, two rows whose trailing slot mirrors, and a section header.
/// Read the AR card for the mirroring and for the fact that the language names
/// are ENDONYMS — "English" and "العربية" are the same two strings in both
/// locales, so the Arabic screen carries one Latin row and the English screen
/// carries one Arabic row, in every rendering. The 200% card is where the row
/// titles stop being trivially short.
///
/// This is also the card that shows the chevron on the unticked row (see the
/// section prose): at 100% text the tick and the chevron sit in the same slot,
/// one row apart.
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
///
/// Worth its own card next to the reference because the resolution arm is
/// different — the persisted key is read BEFORE the device locale — and because
/// in the AR rendering the render test pumps, it is the divergent reading the
/// catalog itself produces: an Arabic, RTL screen with the English row ticked.
/// The shipped app cannot show that (one cubit drives both), a dev surface that
/// pins the cubit without pinning the app locale always can.
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
///
/// In the EN card this is the mirror image of [languageSettingsScreenEnglishSaved]'s
/// AR card — an English, LTR screen with the Arabic row ticked. In the AR card
/// the render test pumps it is the coherent Arabic reading.
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
/// arms to its hard `en` default.
///
/// Pixel-identical to [languageSettingsScreenEnglishSaved] and reached by a
/// completely different path — which is exactly the state the screen cannot
/// express. This user has never chosen anything and is still following their
/// device; the screen tells them they have "selected" English, and there is no
/// affordance that would take them back to following the device once they touch
/// either row (`LocaleCubit.resetToDeviceLocale()` has no caller).
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
/// device locale — Arabic here.
///
/// The one card that would catch a regression passing the saved string straight
/// to `Locale(saved)`: that build renders `de`, neither row matches, and BOTH
/// rows lose their tick while the mutually-exclusive semantics claim nothing is
/// selected. There is no other way to see it — the screen has no error state,
/// so a bad pref is either invisible or catastrophic.
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
///
/// The user data on this screen is a fixed pair of endonyms, so the ceiling
/// here is not "the longest name someone typed" — it is the localized chrome at
/// 200% text on the narrowest frame the app supports. Nothing on this screen
/// carries a `maxLines` or an `overflow`: `OmdsSettingsRow` and
/// `OmdsSettingsSection` hand bare `Text` to a `Column`, so copy that stopped
/// fitting would WRAP and grow the row — and the body is a [ListView], so the
/// growth is absorbed by scrolling rather than overflowing.
///
/// Measured with the real Inter/Noto faces (the numbers under the 1-em test
/// face are ~2x inflated and mean nothing): nothing wraps and nothing overflows
/// at 100% or 200%, in either locale. What the 200% card DOES show is the
/// hierarchy inverting — `AppBar` clamps its title's text scaling at 1.34x
/// while the section header directly below it scales the whole way, so the
/// header ends up bigger than the screen's own title. The render test pins all
/// of it.
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
