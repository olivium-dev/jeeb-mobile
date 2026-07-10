import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/dev_seam/session_seam_bootstrap.dart';
import '../../../core/di/injection_container.dart';
import '../../earnings/application/earnings_cubit.dart';
import '../../earnings/domain/earnings_repository.dart';
import '../../earnings/presentation/earnings_dashboard_screen.dart';

class EarningsTab extends StatelessWidget {
  const EarningsTab({super.key, this.repository, this.jeeberId});

  /// Test/preview seam: overrides the GetIt-resolved [EarningsRepository].
  /// Additive — when null the tab keeps resolving `sl<EarningsRepository>()`
  /// (DT-04 catalog hook, so a bare Dev Tool preview never fires the live
  /// earnings request).
  final EarningsRepository? repository;

  /// Test/preview seam: overrides the jeeber id passed to [EarningsCubit].
  /// Additive — when null the tab keeps its existing
  /// [SessionSeamBootstrap.jeeberUserId] default.
  final String? jeeberId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EarningsCubit>(
      create: (_) => EarningsCubit(
        repository: repository ?? sl<EarningsRepository>(),
        // JM-052: the earnings endpoint filters by `?jeeberId=` (not the bearer),
        // so it needs the current jeeber's id. There is no app-side session-
        // user-id provider yet (`SessionGate` exposes only a boolean), so this
        // defaults to the canonical seam id `user-jeeber-002` — exactly what the
        // `wallet_with_ledger` seam seeds + the Maestro flow expects, and the
        // same JM-047 precedent (see 50_ROUTE_REQUESTS "PO-jeeberid"). The
        // previous hardcoded `user-001` has no seeded earnings → empty dashboard.
        // Swap to the real `SessionUserId` when that provider lands; no screen
        // change.
        jeeberId: jeeberId ?? SessionSeamBootstrap.jeeberUserId,
      ),
      child: const EarningsDashboardScreen(),
    );
  }
}
