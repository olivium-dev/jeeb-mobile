// ONB-01: `complete()` emitted `true` BEFORE the write, and the write was
// unguarded — a failing SharedPreferences left an in-memory-only "completed"
// and threw into the carousel.
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the write order and can be scripted to fail.
class _ScriptedPrefs extends Fake implements SharedPreferences {
  _ScriptedPrefs({this.writeThrows = false});

  final bool writeThrows;
  final Map<String, Object> store = <String, Object>{};
  final List<String> calls = <String>[];

  @override
  bool? getBool(String key) => store[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    calls.add('setBool');
    if (writeThrows) throw StateError('disk full');
    store[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    calls.add('remove');
    if (writeThrows) throw StateError('disk full');
    store.remove(key);
    return true;
  }
}

void main() {
  test('complete() writes BEFORE it emits', () async {
    final prefs = _ScriptedPrefs();
    final cubit = OnboardingCubit(prefs: prefs);
    addTearDown(cubit.close);

    final emitted = <bool>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.complete();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(prefs.store[OnboardingCubit.completedKey], isTrue);
    expect(emitted, <bool>[true]);
  });

  test('a throwing write never propagates, and the carousel still advances',
      () async {
    final prefs = _ScriptedPrefs(writeThrows: true);
    final cubit = OnboardingCubit(prefs: prefs);
    addTearDown(cubit.close);

    await expectLater(cubit.complete(), completes);

    expect(prefs.calls, <String>['setBool']);
    expect(cubit.state, isTrue);
  });

  test('reset() has the same write-first, never-throw shape', () async {
    final prefs = _ScriptedPrefs(writeThrows: true);
    final cubit = OnboardingCubit(prefs: prefs);
    addTearDown(cubit.close);

    await expectLater(cubit.reset(), completes);

    expect(cubit.state, isFalse);
  });

  test('complete() is a no-op once already completed', () async {
    final prefs = _ScriptedPrefs()
      ..store[OnboardingCubit.completedKey] = true;
    final cubit = OnboardingCubit(prefs: prefs);
    addTearDown(cubit.close);

    await cubit.complete();

    expect(prefs.calls, isEmpty);
  });
}
