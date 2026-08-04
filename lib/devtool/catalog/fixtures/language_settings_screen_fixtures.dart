// Shared dev-only fixtures for `LanguageSettingsScreen`.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';

/// The key [LocaleCubit] persists the user's choice under.
/// Private to the cubit, so it is repeated here rather than imported — the same
const String _kLanguageSettingsScreenLocalePrefKey = 'app.locale.languageCode';

/// An in-memory stand-in for [SharedPreferences].
/// [LocaleCubit] REQUIRES a `SharedPreferences`, and the real one is async
/// (`getInstance()`) and platform-channel backed — neither of which a
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
/// Takes the AMBIENT locale — the one the surrounding `MaterialApp` is already
/// rendering in — so a fixture can either follow it (the coherent reading, and
typedef LanguageSettingsScreenCubitFactory = LocaleCubit Function(Locale
    ambient);

/// The designed states both dev surfaces render, as [LocaleCubit] factories.
/// Every one of these is a static tear-off rather than a closure factory, on
abstract final class LanguageSettingsScreenPreviewFixtures {
  /// An unsupported language code, used by the two fallback states. `de` is
  /// deliberately plausible — the app ships `en` and `ar` only, so every other
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
  static LocaleCubit followsAmbient(Locale ambient) => _cubit(
        prefs: LanguageSettingsScreenInMemoryPrefs(),
        device: ambient,
      );

  /// First launch on a device whose locale the app does not ship: nothing
  /// persisted, `de` unsupported, so `_resolveInitial` falls all the way
  static LocaleCubit unsupportedDeviceLocale(Locale _) => _cubit(
        prefs: LanguageSettingsScreenInMemoryPrefs(),
        device: const Locale(unsupportedCode),
      );

  /// A persisted value the app can no longer honour — a language that was
  /// dropped from the catalog, or a pref file written by another build.
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
/// Supplies the ambient [LocaleCubit] the screen watches unconditionally
/// (`context.watch<LocaleCubit>()` on every build, so a bare
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
    final Locale ambient =
        Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final Widget seated = BlocProvider<LocaleCubit>(
      // Keyed on the ambient locale AND the fixture: `create` runs once per
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
