import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingCubit extends Cubit<bool> {
  OnboardingCubit({required SharedPreferences prefs})
      : _prefs = prefs,
        super(prefs.getBool(completedKey) ?? false);

  /// Public for SessionSeamBootstrap to seed (single source of truth).
  static const String completedKey = 'app.onboarding.completed';

  final SharedPreferences _prefs;

  bool get isCompleted => state;

  Future<void> complete() async {
    if (state) return;
    emit(true);
    await _prefs.setBool(completedKey, true);
  }

  /// Debug/QA tool; not exposed in UI yet.
  Future<void> reset() async {
    emit(false);
    await _prefs.remove(completedKey);
  }
}
