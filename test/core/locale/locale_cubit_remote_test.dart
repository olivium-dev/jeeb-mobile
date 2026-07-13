// Unit tests for LocaleCubit's server-persistence seam (JEBV4-205, E10).
//
// Covers the remote-user-preferences integration only (the widget-level
// switching/RTL behaviour lives in test/locale_switching_test.dart):
//   * setLocale mirrors the choice to the remote store.
//   * syncFromServer applies a server-held language over the local cache — the
//     "survives reinstall" case (local cache empty, server still holds it).
//   * a failing/offline remote never breaks a local switch (offline-first).
//   * an unsupported server value is ignored.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/language_preference_repository.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';

/// In-memory [LanguagePreferenceRepository] recording writes and serving a
/// scripted fetch value, with an optional throw to model an offline service.
class _FakeRemote implements LanguagePreferenceRepository {
  _FakeRemote({this.fetchValue, this.throwOnSave = false, this.throwOnFetch = false});

  String? fetchValue;
  bool throwOnSave;
  bool throwOnFetch;
  final List<String> saved = <String>[];

  @override
  Future<String?> fetch() async {
    if (throwOnFetch) {
      throw const LanguagePreferenceException(LanguagePreferenceFailure.network);
    }
    return fetchValue;
  }

  @override
  Future<void> save(String languageCode) async {
    if (throwOnSave) {
      throw const LanguagePreferenceException(LanguagePreferenceFailure.network);
    }
    saved.add(languageCode);
  }
}

void main() {
  const key = 'app.locale.languageCode';

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('setLocale mirrors the choice to the remote store', () async {
    final remote = _FakeRemote();
    final cubit = LocaleCubit(
      prefs: await prefs(),
      deviceLocaleProvider: () => const Locale('en'),
      remote: remote,
    );

    await cubit.setLocale(const Locale('ar'));

    expect(cubit.state.languageCode, 'ar');
    expect(remote.saved, <String>['ar']);
    await cubit.close();
  });

  test('offline remote (save throws) still switches + caches locally', () async {
    final remote = _FakeRemote(throwOnSave: true);
    final p = await prefs();
    final cubit = LocaleCubit(
      prefs: p,
      deviceLocaleProvider: () => const Locale('en'),
      remote: remote,
    );

    await cubit.setLocale(const Locale('ar'));

    expect(cubit.state.languageCode, 'ar');
    expect(p.getString(key), 'ar');
    await cubit.close();
  });

  test('syncFromServer applies the server language over an empty local cache '
      '(survives reinstall)', () async {
    // Fresh install: no local pref, device is English → boots English.
    final remote = _FakeRemote(fetchValue: 'ar');
    final p = await prefs();
    final cubit = LocaleCubit(
      prefs: p,
      deviceLocaleProvider: () => const Locale('en'),
      remote: remote,
    );
    expect(cubit.state.languageCode, 'en');

    await cubit.syncFromServer();

    expect(cubit.state.languageCode, 'ar');
    expect(p.getString(key), 'ar');
    await cubit.close();
  });

  test('syncFromServer ignores an unsupported server value', () async {
    final remote = _FakeRemote(fetchValue: 'fr');
    final cubit = LocaleCubit(
      prefs: await prefs(),
      deviceLocaleProvider: () => const Locale('en'),
      remote: remote,
    );

    await cubit.syncFromServer();

    expect(cubit.state.languageCode, 'en');
    await cubit.close();
  });

  test('syncFromServer swallows a failing remote (stays on current locale)',
      () async {
    final remote = _FakeRemote(throwOnFetch: true);
    final cubit = LocaleCubit(
      prefs: await prefs(),
      deviceLocaleProvider: () => const Locale('en'),
      remote: remote,
    );

    await cubit.syncFromServer();

    expect(cubit.state.languageCode, 'en');
    await cubit.close();
  });

  test('no remote → syncFromServer is an inert no-op', () async {
    final cubit = LocaleCubit(
      prefs: await prefs(),
      deviceLocaleProvider: () => const Locale('en'),
    );

    await cubit.syncFromServer();

    expect(cubit.state.languageCode, 'en');
    await cubit.close();
  });
}
