import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/role/role_availability_cubit.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../order_history/application/order_history_cubit.dart';
import '../../order_history/data/dio_order_repository.dart';
import '../../order_history/domain/order_repository.dart';
import '../../order_history/presentation/order_history_screen.dart';

/// Container for the bottom-nav Delivery tab. Wires the cubit + Dio-backed
/// repository so the screen itself can stay BlocProvider-free in tests.
///
/// ROLE-AWARE (JEBV4-280): the Delivery tab is SHARED by clients and jeebers in
/// the additive shell. For a pure customer it lists their own orders
/// (`GET /v1/requests`); for a jeeber it must list their assigned delivery JOBS
/// (`GET /v1/deliveries?role=jeeber`) — hitting the customer list as a jeeber
/// returned an empty page and stranded the tab on "No orders yet". The tab
/// resolves a customer- or jeeber-scoped [DioOrderRepository] from the active
/// role, key-gated so a late login→role sync rebuilds the cubit against the
/// right endpoint. A pure customer triggers neither jeeber signal, so their
/// Delivery view is completely unchanged.
///
/// The repository is fetched from the global GetIt container if one was
/// registered (so DI bootstrap can swap in a fake during integration tests),
/// and otherwise a one-shot Dio is used.
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key, this.repository});

  /// Optional override — primarily a hook for widget tests / the DT-04 catalog.
  /// When supplied it wins over the role-aware resolution below (the catalog
  /// seeds a fixed customer-shaped repo), so the shared screen renders without a
  /// live gateway.
  final OrderRepository? repository;

  @override
  Widget build(BuildContext context) {
    final actingAsJeeber = _actingAsJeeber(context);
    return BlocProvider<OrderHistoryCubit>(
      // Role-keyed so a client→jeeber role resolution (e.g. getMe active_role or
      // the capability sync landing after first build) tears down the customer
      // cubit and rebuilds it against `/v1/deliveries?role=jeeber`. A customer's
      // key never flips, so their cubit + list state are preserved untouched.
      key: ValueKey('orders-tab-${actingAsJeeber ? 'jeeber' : 'client'}'),
      create: (_) =>
          OrderHistoryCubit(repository: _resolveRepository(actingAsJeeber)),
      child: const OrderHistoryScreen(),
    );
  }

  /// True when the signed-in user is acting as a jeeber. Two signals, either of
  /// which is sufficient:
  ///  * the active [UserRole] is `jeeber` ([RoleCubit]) — persisted and known
  ///    SYNCHRONOUSLY at first build for a returning jeeber, so their Delivery
  ///    tab loads deliveries immediately with no customer-list flash; and
  ///  * the user holds the `jeeber` capability ([RoleAvailabilityCubit], from
  ///    getMe `available_roles`) — covers the dual-role user and a fresh login
  ///    whose active role resolves a beat after the shell first builds.
  ///
  /// A pure customer is neither (RoleSync only ever adopts `jeeber` when it is
  /// an allowed role), so [_resolveRepository] keeps the `/v1/requests` path.
  /// Nullable reads keep bare widget tests (no role providers wired) on the
  /// customer path instead of throwing a ProviderNotFound.
  bool _actingAsJeeber(BuildContext context) {
    if (context.watch<RoleCubit?>()?.state == UserRole.jeeber) return true;
    final roles = context.watch<RoleAvailabilityCubit?>()?.state.roles;
    return roles?.contains('jeeber') ?? false;
  }

  OrderRepository _resolveRepository(bool actingAsJeeber) {
    if (repository != null) return repository!;
    // Customer: the DI-registered repository when present (integration-test
    // seam), else a bare Dio one — unchanged from before. Jeeber: always the
    // delivery-scoped Dio repository (there is no jeeber OrderRepository in DI,
    // and the DI one is customer-scoped to `/v1/requests`).
    if (!actingAsJeeber && sl.isRegistered<OrderRepository>()) {
      return sl<OrderRepository>();
    }
    final dio = sl.isRegistered<Dio>() ? sl<Dio>() : Dio();
    return DioOrderRepository(dio, asJeeber: actingAsJeeber);
  }
}
