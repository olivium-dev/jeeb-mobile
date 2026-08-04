import 'dart:async';

import '../role/role_cubit.dart';
import '../role/user_role.dart';
import 'crash_reporter.dart';

class CrashContextBridge {
  CrashContextBridge({
    required CrashReporter reporter,
    required RoleCubit roleCubit,
  })  : _reporter = reporter,
        _subscription = roleCubit.stream.listen((role) {
          reporter.log('role:${_describe(role)}');
        });

  // ignore: unused_field
  final CrashReporter _reporter;
  final StreamSubscription<UserRole> _subscription;

  void dispose() {
    _subscription.cancel();
  }

  static String _describe(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'client';
      case UserRole.jeeber:
        return 'jeeber';
    }
  }
}
