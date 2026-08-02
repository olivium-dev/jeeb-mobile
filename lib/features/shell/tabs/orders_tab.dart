import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../order_history/application/order_history_cubit.dart';
import '../../order_history/data/dio_order_repository.dart';
import '../../order_history/domain/order_repository.dart';
import '../../order_history/presentation/order_history_screen.dart';
import '../../order_history/presentation/orders_resume_refetcher.dart';

/// Container for the bottom-nav Delivery tab. Wires the cubit + Dio-backed
/// repository so the screen itself can stay BlocProvider-free in tests.
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key, this.repository});

  final OrderRepository? repository;

  @override
  Widget build(BuildContext context) {
    final actingAsJeeber = _actingAsJeeber(context);
    return BlocProvider<OrderHistoryCubit>(
      key: ValueKey('orders-tab-${actingAsJeeber ? 'jeeber' : 'client'}'),
      create: (_) =>
          OrderHistoryCubit(repository: _resolveRepository(actingAsJeeber)),
      child: const OrdersResumeRefetcher(child: OrderHistoryScreen()),
    );
  }

  bool _actingAsJeeber(BuildContext context) {
    return context.watch<RoleCubit?>()?.state == UserRole.jeeber;
  }

  OrderRepository _resolveRepository(bool actingAsJeeber) {
    if (repository != null) return repository!;
    if (!actingAsJeeber && sl.isRegistered<OrderRepository>()) {
      return sl<OrderRepository>();
    }
    final dio = sl.isRegistered<Dio>() ? sl<Dio>() : Dio();
    return DioOrderRepository(dio, asJeeber: actingAsJeeber);
  }
}
