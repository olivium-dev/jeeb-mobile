// Shared dev-only fixtures for `LanguageSettingsScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_06_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/language/presentation/screens/language_settings_screen.dart`.
//
// The screen has no repository, no cubit seam and nothing async: it is two rows
// over the ambient [LocaleCubit], and the ONLY thing that varies between its
// designed states is which locale that cubit resolved to. So a "fixture" here
// is a [LocaleCubit] built over a seeded in-memory [SharedPreferences] and a
// pinned device-locale provider — one per way the resolution in
// `LocaleCubit._resolveInitial` can land.
//
// Two deliberate changes came with the extraction from the catalog entry:
//
//  * **The prefs are in-memory.** The catalog built its cubit over
//    `sl<SharedPreferences>()` — the app's REAL prefs, already bootstrapped on
//    the device the catalog runs on. Two consequences, both fixed here:
//
//      1. It was not deterministic. `_resolveInitial` reads the persisted
//         `app.locale.languageCode` BEFORE it consults `deviceLocaleProvider`,
//         so on a device where the tester had ever picked Arabic, the catalog's
//         "English selected" state rendered with the Arabic row checked. The
//         entry's own doc comment claimed the opposite.
//      2. It wrote to the user's real prefs. Every row on this screen is
//         tappable and `setLocale` persists, so tapping "العربية" while
//         browsing the catalog changed the app's language on the next cold
//         start. [LanguageSettingsScreenInMemoryPrefs] answers from a plain
//         map, so a tap in a dev surface stays in that dev surface.
//
//    It also drops the `sl<...>` resolution, which a preview cannot perform at
//    all: `flutter widget-preview start` never builds the DI graph.
//
//  * **Each state seeds the PERSISTED choice, not the device locale**, except
//    the two that exist to exercise the fallback arms. That is the branch a
//    real user reaches — they picked a language once and it was written — and
//    it is the only one that cannot be perturbed by the host device.
//
// NOT deterministic even here, and not fixable from a fixture: `_resolveInitial`
// consults `DevSeam.current.forcedLocale` first in DEBUG builds. Both dev
// surfaces run in debug, so a `--dart-define=JEEB_FORCE_LOCALE=ar` (or a
// `jeeb.locale` seam JSON) collapses every state below onto that one locale.
// `flutter test` sets neither, so the render tests are unaffected.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';

/// The key [LocaleCubit] persists the user's choice under.
///
/// Private to the cubit, so it is repeated here rather than imported — the same
/// literal `test/language_settings_screen_test.dart` asserts against.
const String _kLanguageSettingsScreenLocalePrefKey = 'app.locale.languageCode';

/// An in-memory stand-in for [SharedPreferences].
///
/// [LocaleCubit] REQUIRES a `SharedPreferences`, and the real one is async
/// (`getInstance()`) and platform-channel backed — neither of which a
/// synchronous `Widget Function()` preview can have. This answers from a plain
/// map, so construction is synchronous and a write in the canvas or the catalog
/// is a map write that dies with the card.
class LanguageSettingsScreenInMemoryPrefs implements SharedPreferences {
  LanguageSettingsScreenInMemoryPrefs([Map<String, Object>? seed])
      : _store = <String, Object>{...?seed};

  /// Prefs holding a previously-saved language [code] — the branch a returning
  /// user is always on.
  factory LanguageSettingsScreenInMemoryPrefs.saved(String code) =>
      LanguageSettingsScreenInMemoryPrefs(<String, Object>{
        _kLanguageSettingsScreenLocalePrefKey: code,
      });

  final Map<String, Object> _store;

  @override
  Object? get(String key) => _store[key];

  @override
  bool? getBool(String key) => _store[key] as bool?;

  @override
  double? getDouble(String key) => _store[key] as double?;

  @override
  int? getInt(String key) => _store[key] as int?;

  @override
  String? getString(String key) => _store[key] as String?;

  @override
  List<String>? getStringList(String key) =>
      (_store[key] as List<String>?)?.toList();

  @override
  Set<String> getKeys() => _store.keys.toSet();

  @override
  bool containsKey(String key) => _store.containsKey(key);

  @override
  Future<bool> setBool(String key, bool value) => _put(key, value);

  @override
  Future<bool> setDouble(String key, double value) => _put(key, value);

  @override
  Future<bool> setInt(String key, int value) => _put(key, value);

  @override
  Future<bool> setString(String key, String value) => _put(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _put(key, value);

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _store.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {}

  Future<bool> _put(String key, Object value) async {
    _store[key] = value;
    return true;
  }
}

/// Builds the [LocaleCubit] one designed state is seated on.
///
/// Takes the AMBIENT locale — the one the surrounding `MaterialApp` is already
/// rendering in — so a fixture can either follow it (the coherent reading, and
/// the only one the shipped app can produce) or deliberately ignore it.
typedef LanguageSettingsScreenCubitFactory = LocaleCubit Function(Locale
    ambient);

/// The designed states both dev surfaces render, as [LocaleCubit] factories.
///
/// Every one of these is a static tear-off rather than a closure factory, on
/// purpose: the host below keys its provider on the factory's identity, and a
/// `pinned(const Locale('ar'))`-style closure would be a new object on every
/// build and rebuild the cubit under the surface every frame.
///
/// Nothing here touches the network, the DI graph or the device's real prefs.
abstract final class LanguageSettingsScreenPreviewFixtures {
  /// An unsupported language code, used by the two fallback states. `de` is
  /// deliberately plausible — the app ships `en` and `ar` only, so every other
  /// locale on earth lands on one of these two arms.
  static const String unsupportedCode = 'de';

  /// A returning user who picked English. The persisted branch, which is what
  /// makes this state independent of the device the surface runs on.
  static LocaleCubit englishSaved(Locale _) => _cubit(
        prefs: LanguageSettingsScreenInMemoryPrefs.saved('en'),
        device: const Locale('en'),
      );

  /// A returning user who picked Arabic.
  static LocaleCubit arabicSaved(Locale _) => _cubit(
        prefs: LanguageSettingsScreenInMemoryPrefs.saved('ar'),
        device: const Locale('ar'),
      );

  /// No choice ever saved, and the device reports the locale the app is already
  /// rendering in — the coherent reading, and the one the shipped app produces
  /// (the root `MaterialApp` watches this same cubit, so the checked row and
  /// the copy on screen can never disagree there).
  static LocaleCubit followsAmbient(Locale ambient) => _cubit(
        prefs: LanguageSettingsScreenInMemoryPrefs(),
        device: ambient,
      );

  /// First launch on a device whose locale the app does not ship: nothing
  /// persisted, `de` unsupported, so `_resolveInitial` falls all the way
  /// through to its hard `en` default.
  ///
  /// Pixel-identical to [englishSaved] and reached by a completely different
  /// path, which is why the preview section captions its card.
  static LocaleCubit unsupportedDeviceLocale(Locale _) => _cubit(
        prefs: LanguageSettingsScreenInMemoryPrefs(),
        device: const Locale(unsupportedCode),
      );

  /// A persisted value the app can no longer honour — a language that was
  /// dropped from the catalog, or a pref file written by another build.
  ///
  /// `_isSupported` rejects it and resolution continues to the device locale
  /// (Arabic here), so the screen must still show exactly one checked row. A
  /// regression that passed the saved string straight to `Locale(saved)` would
  /// leave BOTH rows unchecked, and this is the only fixture that would catch
  /// it.
  static LocaleCubit unsupportedSavedValue(Locale _) => _cubit(
        prefs: LanguageSettingsScreenInMemoryPrefs.saved(unsupportedCode),
        device: const Locale('ar'),
      );

  static LocaleCubit _cubit({
    required SharedPreferences prefs,
    required Locale device,
  }) =>
      LocaleCubit(prefs: prefs, deviceLocaleProvider: () => device);
}

/// Seats a previewed [child] the way the app seats it, minus the app.
///
/// Supplies the ambient [LocaleCubit] the screen watches unconditionally
/// (`context.watch<LocaleCubit>()` on every build, so a bare
/// `LanguageSettingsScreen` throws), and optionally pins a device frame.
///
/// [child] is taken rather than built here so the CALLER constructs the screen:
/// `tool/preview_coverage.dart` counts a screen as covered only when its own
/// preview section literally constructs it.
class LanguageSettingsScreenPreviewHost extends StatelessWidget {
  const LanguageSettingsScreenPreviewHost({
    super.key,
    required this.create,
    required this.child,
    this.box,
  });

  /// Builds the cubit under review, given the ambient locale.
  final LanguageSettingsScreenCubitFactory create;

  /// The surface under the cubit — `const LanguageSettingsScreen()` at both
  /// call sites.
  final Widget child;

  /// Device frame to pin, or `null` to take whatever the host offers (the
  /// Screen Catalog runs full-bleed inside the device it is already on).
  final Size? box;

  @override
  Widget build(BuildContext context) {
    // Read the ambient locale HERE, in a build: a `Localizations.maybeLocaleOf`
    // inside the provider's `create` would register an inherited dependency in
    // a callback that never runs again, which `provider` rejects outright.
    final Locale ambient =
        Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final Widget seated = BlocProvider<LocaleCubit>(
      // Keyed on the ambient locale AND the fixture: `create` runs once per
      // element, so without this a card re-rendered in the other locale would
      // keep the cubit seeded from the first one, and a render test pumping two
      // fixtures in a row into the same tree position would go on showing the
      // first one's state under the second one's name.
      key: ValueKey<(Locale, Object)>((ambient, create)),
      create: (_) => create(ambient),
      child: child,
    );
    final Size? frame = box;
    if (frame == null) return seated;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: frame.width, height: frame.height, child: seated),
    );
  }
}
