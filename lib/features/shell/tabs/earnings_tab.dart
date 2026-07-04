import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../earnings/application/earnings_cubit.dart';
import '../../earnings/domain/earnings_repository.dart';
import '../../earnings/presentation/earnings_dashboard_screen.dart';

class EarningsTab extends StatelessWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _sessionUserId(),
      builder: (context, snapshot) {
        final userId = snapshot.data;
        if (userId != null && userId.isNotEmpty) {
          return BlocProvider<EarningsCubit>(
            create: (_) => EarningsCubit(
              repository: sl<EarningsRepository>(),
              jeeberId: userId,
            ),
            child: const EarningsDashboardScreen(),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: OmdsLoadingState());
        }
        return const Center(child: Text('Unable to load earnings account.'));
      },
    );
  }

  /// The REAL authenticated session id from [AuthTokenStore] — never a
  /// hardcoded fixture id (S0-OAD-03). In the mock lane the session seam /
  /// login flow seeds the store's userId, so the same lookup serves both
  /// lanes. FAIL CLOSED: with no session id we render the explicit
  /// "Unable to load earnings account." state instead of silently binding
  /// another user's earnings.
  Future<String?> _sessionUserId() async {
    if (sl.isRegistered<AuthTokenStore>()) {
      final id = await sl<AuthTokenStore>().userId;
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }
}
