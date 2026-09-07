import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/diag.dart';
import '../network/app_failure.dart';

class OnboardingCubit extends Cubit<bool> {
  OnboardingCubit({required SharedPreferences prefs})
      : _prefs = prefs,
        super(prefs.getBool(completedKey) ?? false);

  /// Public for SessionSeamBootstrap to seed (single source of truth).
  static const String completedKey = 'app.onboarding.completed';

  final SharedPreferences _prefs;

  bool get isCompleted => state;

  /// Writes FIRST, then emits unconditionally: a failing write must never
  /// throw into the carousel, and must never leave an in-memory-only "done".
  Future<void> complete() async {
    if (state) return;
    try {
      await _prefs.setBool(completedKey, true);
    } catch (e) {
      Diag.event('onboarding_complete_persist_failed', {
        'kind': AppFailure.of(e).kind.name,
      });
    }
    emit(true);
  }

  /// Debug/QA tool; not exposed in UI yet.
  Future<void> reset() async {
    try {
      await _prefs.remove(completedKey);
    } catch (e) {
      Diag.event('onboarding_reset_persist_failed', {
        'kind': AppFailure.of(e).kind.name,
      });
    }
    emit(false);
  }
}
