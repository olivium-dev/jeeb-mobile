import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cubit owning the "first-launch onboarding" flag.
///
/// The flag is persisted to [SharedPreferences] so the onboarding flow only
/// appears once per install. Calling [complete] sets the flag and emits `true`;
/// the router listens to that state to redirect away from `/onboarding`.
class OnboardingCubit extends Cubit<bool> {
  OnboardingCubit({required SharedPreferences prefs})
      : _prefs = prefs,
        super(prefs.getBool(completedKey) ?? false);

  /// SharedPreferences key for the onboarding-complete flag. Public so the
  /// debug-only [SessionSeamBootstrap] seeds the SAME key this cubit reads in
  /// its constructor (single source of truth — no parallel onboarding flag).
  static const String completedKey = 'app.onboarding.completed';

  final SharedPreferences _prefs;

  bool get isCompleted => state;

  Future<void> complete() async {
    if (state) return;
    emit(true);
    await _prefs.setBool(completedKey, true);
  }

  /// Re-show onboarding (used by debug/QA tooling — not exposed in UI yet).
  Future<void> reset() async {
    emit(false);
    await _prefs.remove(completedKey);
  }
}
