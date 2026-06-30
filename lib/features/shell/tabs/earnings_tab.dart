import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/dev_seam/session_seam_bootstrap.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/mock_gateway_client.dart';
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
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(child: Text('Unable to load earnings account.'));
      },
    );
  }

  Future<String?> _sessionUserId() async {
    if (sl.isRegistered<AuthTokenStore>()) {
      final id = await sl<AuthTokenStore>().userId;
      if (id != null && id.isNotEmpty) return id;
    }
    return MockGatewayClient.useMockPrefixes
        ? SessionSeamBootstrap.jeeberUserId
        : null;
  }
}
