// LANG-01: `_pushRemote` swallowed its failure, then the next `syncFromServer`
// read the server's STALE value and reverted the user's offline choice.
// LANG-02: an unauthorized preference write belongs on the session lane.

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/language_preference_repository.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/session/auth_loss_signals.dart';

class _FakeRemote implements LanguagePreferenceRepository {
  _FakeRemote({this.fetchValue, this.saveFailure});

  String? fetchValue;
  LanguagePreferenceFailure? saveFailure;
  final List<String> saved = <String>[];
  int fetches = 0;

  @override
  Future<String?> fetch() async {
    fetches += 1;
    return fetchValue;
  }

  @override
  Future<void> save(String languageCode) async {
    final LanguagePreferenceFailure? failure = saveFailure;
    if (failure != null) throw LanguagePreferenceException(failure);
    saved.add(languageCode);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AuthLossSignals.instance.clearReason();
  });

  tearDown(() => AuthLossSignals.instance.clearReason());

  Future<LocaleCubit> build(_FakeRemote remote) async => LocaleCubit(
        prefs: await SharedPreferences.getInstance(),
        deviceLocaleProvider: () => const Locale('en'),
        remote: remote,
      );

  test('a failed push raises the pending flag', () async {
    final _FakeRemote remote = _FakeRemote(
      saveFailure: LanguagePreferenceFailure.network,
    );
    final LocaleCubit cubit = await build(remote);

    expect(cubit.hasPendingLanguagePush, isFalse);
    await cubit.setLocale(const Locale('ar'));

    expect(cubit.state.languageCode, 'ar');
    expect(cubit.hasPendingLanguagePush, isTrue);
    await cubit.close();
  });

  test('syncFromServer does NOT revert while a push is owed', () async {
    final _FakeRemote remote = _FakeRemote(
      fetchValue: 'en',
      saveFailure: LanguagePreferenceFailure.network,
    );
    final LocaleCubit cubit = await build(remote);
    await cubit.setLocale(const Locale('ar'));
    expect(cubit.hasPendingLanguagePush, isTrue);

    await cubit.syncFromServer();

    // The stale server copy would have flipped this back to `en`.
    expect(cubit.state.languageCode, 'ar');
    expect(remote.fetches, 0, reason: 'the read must not even be attempted');
    await cubit.close();
  });

  test('the retry rides on syncFromServer and clears the flag', () async {
    final _FakeRemote remote = _FakeRemote(
      fetchValue: 'en',
      saveFailure: LanguagePreferenceFailure.network,
    );
    final LocaleCubit cubit = await build(remote);
    await cubit.setLocale(const Locale('ar'));

    remote.saveFailure = null;
    await cubit.syncFromServer();

    expect(remote.saved, <String>['ar']);
    expect(cubit.hasPendingLanguagePush, isFalse);
    expect(cubit.state.languageCode, 'ar');
    await cubit.close();
  });

  test('once cleared, syncFromServer resumes reading the server', () async {
    final _FakeRemote remote = _FakeRemote(fetchValue: 'ar');
    final LocaleCubit cubit = await build(remote);

    await cubit.syncFromServer();

    expect(remote.fetches, 1);
    expect(cubit.state.languageCode, 'ar');
    await cubit.close();
  });

  test('the listenable mirrors the flag for the screen note', () async {
    final _FakeRemote remote = _FakeRemote(
      saveFailure: LanguagePreferenceFailure.network,
    );
    final LocaleCubit cubit = await build(remote);
    final List<bool> seen = <bool>[];
    void listener() => seen.add(cubit.languagePushPending.value);
    cubit.languagePushPending.addListener(listener);

    await cubit.setLocale(const Locale('ar'));
    expect(seen, <bool>[true]);

    remote.saveFailure = null;
    await cubit.syncFromServer();
    expect(seen, <bool>[true, false]);

    cubit.languagePushPending.removeListener(listener);
    await cubit.close();
  });

  // §5.10: unauthorized is a session problem, not a language one.
  test('an unauthorized write signals the session lane', () async {
    final _FakeRemote remote = _FakeRemote(
      saveFailure: LanguagePreferenceFailure.unauthorized,
    );
    final LocaleCubit cubit = await build(remote);
    final List<AuthLossReason> signals = <AuthLossReason>[];
    final StreamSubscription<AuthLossReason> sub =
        AuthLossSignals.instance.stream.listen(signals.add);

    await cubit.setLocale(const Locale('ar'));

    expect(signals, <AuthLossReason>[AuthLossReason.sessionExpired]);
    expect(AuthLossSignals.instance.lastReason, AuthLossReason.sessionExpired);
    await sub.cancel();
    await cubit.close();
  });

  // The owed push is retried on EVERY sync; each signal flips SessionCubit to
  // unauthenticated, so the signal is latched to one per cubit.
  test('a repeated unauthorized write signals the session lane ONCE', () async {
    final _FakeRemote remote = _FakeRemote(
      saveFailure: LanguagePreferenceFailure.unauthorized,
    );
    final LocaleCubit cubit = await build(remote);
    final List<AuthLossReason> signals = <AuthLossReason>[];
    final StreamSubscription<AuthLossReason> sub =
        AuthLossSignals.instance.stream.listen(signals.add);

    await cubit.setLocale(const Locale('ar'));
    await cubit.syncFromServer();
    await cubit.syncFromServer();

    expect(signals, <AuthLossReason>[AuthLossReason.sessionExpired]);
    await sub.cancel();
    await cubit.close();
  });

  test('a network write signals NOTHING on the session lane', () async {
    final _FakeRemote remote = _FakeRemote(
      saveFailure: LanguagePreferenceFailure.network,
    );
    final LocaleCubit cubit = await build(remote);
    final List<AuthLossReason> signals = <AuthLossReason>[];
    final StreamSubscription<AuthLossReason> sub =
        AuthLossSignals.instance.stream.listen(signals.add);

    await cubit.setLocale(const Locale('ar'));

    expect(signals, isEmpty);
    await sub.cancel();
    await cubit.close();
  });
}
