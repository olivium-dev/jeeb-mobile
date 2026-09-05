import '../network/app_failure.dart';

/// The catch every cubit forgets: anything a typed `on X catch` misses would
/// strand the screen in-flight, so classify it and always have one to render.
Future<void> guarded(
  Future<void> Function() body,
  void Function(AppFailure failure) onFailure,
) async {
  try {
    await body();
  } catch (error) {
    onFailure(AppFailure.of(error));
  }
}

/// [guarded] for a read that produces a value: returns null on failure, after
/// handing the classified failure to [onFailure].
Future<T?> guardedValue<T>(
  Future<T> Function() body,
  void Function(AppFailure failure) onFailure,
) async {
  try {
    return await body();
  } catch (error) {
    onFailure(AppFailure.of(error));
    return null;
  }
}
