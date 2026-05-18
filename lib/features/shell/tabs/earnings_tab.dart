import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../earnings/application/earnings_cubit.dart';
import '../../earnings/domain/earnings_repository.dart';
import '../../earnings/presentation/earnings_dashboard_screen.dart';

class EarningsTab extends StatelessWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EarningsCubit>(
      create: (_) => EarningsCubit(
        repository: sl<EarningsRepository>(),
        jeeberId: 'user-001',
      ),
      child: const EarningsDashboardScreen(),
    );
  }
}
