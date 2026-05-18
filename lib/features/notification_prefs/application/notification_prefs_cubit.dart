import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notification_prefs_store.dart';
import '../domain/notification_prefs_model.dart';

class NotificationPrefsCubit extends Cubit<NotificationPrefs> {
  NotificationPrefsCubit({required NotificationPrefsStore store})
      : _store = store,
        super(store.load());

  final NotificationPrefsStore _store;

  void togglePush(bool value) {
    final updated = state.copyWith(pushEnabled: value);
    emit(updated);
    _store.save(updated);
  }

  void toggleSms(bool value) {
    final updated = state.copyWith(smsEnabled: value);
    emit(updated);
    _store.save(updated);
  }

  void toggleEmail(bool value) {
    final updated = state.copyWith(emailEnabled: value);
    emit(updated);
    _store.save(updated);
  }

  void toggleDeliveryUpdates(bool value) {
    final updated = state.copyWith(deliveryUpdates: value);
    emit(updated);
    _store.save(updated);
  }

  void toggleOffers(bool value) {
    final updated = state.copyWith(offers: value);
    emit(updated);
    _store.save(updated);
  }

  void togglePromotions(bool value) {
    final updated = state.copyWith(promotions: value);
    emit(updated);
    _store.save(updated);
  }
}
