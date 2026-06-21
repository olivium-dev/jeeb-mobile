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
      // DEFECT-B (§6B): no hardcoded `jeeberId`. The live gateway
      // `GET /v1/jeeb/earnings` resolves the owner from the bearer token's `sub`
      // and IGNORES any `?jeeberId=` param (the prior hardcoded
      // `user-jeeber-002` mock id was both wrong and ignored). The cubit/repo
      // omit the param, so the tiles bind the authenticated user's real
      // totalNet/rowCount/entries (PR #57 fixed the response parsing).
      create: (_) =>
          EarningsCubit(repository: sl<EarningsRepository>()),
      child: const EarningsDashboardScreen(),
    );
  }
}
