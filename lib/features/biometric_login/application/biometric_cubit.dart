import 'package:flutter_bloc/flutter_bloc.dart';

enum BiometricState { initial, checking, available, unavailable, authenticated, failed }

/// STUB: no gateway is wired, so `available` is always reported and `failed`
/// is unreachable. The screen still renders every state (F38).
class BiometricCubit extends Cubit<BiometricState> {
  BiometricCubit() : super(BiometricState.initial);

  Future<void> checkAvailability() async {
    emit(BiometricState.checking);
    emit(BiometricState.available);
  }

  Future<void> authenticate() async {
    emit(BiometricState.checking);
    emit(BiometricState.authenticated);
  }
}
