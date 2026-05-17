import 'package:flutter_bloc/flutter_bloc.dart';

/// Tracks the in-app unread-notification count surfaced as a badge on
/// the bell icon in the shell. Kept dead simple — every push that the
/// handler accepts increments by one; entering the inbox clears it.
///
/// The platform app-icon badge is owned by the OS / firebase_messaging
/// (`badge: true` in the notification payload), not this cubit; we only
/// model the in-app visual.
class BadgeCountCubit extends Cubit<int> {
  BadgeCountCubit({int initial = 0}) : super(initial);

  void increment() => emit(state + 1);

  void clear() {
    if (state == 0) return;
    emit(0);
  }
}
