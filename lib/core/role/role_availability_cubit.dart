import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoleAvailabilityCubit extends Cubit<RoleAvailability> {
  RoleAvailabilityCubit([super.initial = const RoleAvailability()]);

  void setAvailableRoles(List<String> roles) {
    final next = RoleAvailability(roles: List<String>.unmodifiable(roles));
    if (next == state) return;
    emit(next);
  }
}

class RoleAvailability extends Equatable {
  const RoleAvailability({this.roles = const <String>[]});

  final List<String> roles;

  bool get isDualRole => roles.contains('client') && roles.contains('jeeber');

  @override
  List<Object?> get props => [roles];
}
