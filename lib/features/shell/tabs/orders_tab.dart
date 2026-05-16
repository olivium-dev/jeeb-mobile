import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../order_history/application/order_history_cubit.dart';
import '../../order_history/data/dio_order_repository.dart';
import '../../order_history/domain/order_repository.dart';
import '../../order_history/presentation/order_history_screen.dart';

/// Container for the bottom-nav Orders tab. Wires the cubit + Dio-backed
/// repository so the screen itself can stay BlocProvider-free in tests.
///
/// The repository is fetched from the global GetIt container if one was
/// registered (so DI bootstrap can swap in a fake during integration
/// tests), and otherwise a one-shot Dio is used.
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key, this.repository});

  /// Optional override — primarily a hook for widget tests.
  final OrderRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderHistoryCubit>(
      create: (_) => OrderHistoryCubit(repository: _resolveRepository()),
      child: const OrderHistoryScreen(),
    );
  }

  OrderRepository _resolveRepository() {
    if (repository != null) return repository!;
    if (sl.isRegistered<OrderRepository>()) return sl<OrderRepository>();
    final dio = sl.isRegistered<Dio>() ? sl<Dio>() : Dio();
    return DioOrderRepository(dio);
  }
}
