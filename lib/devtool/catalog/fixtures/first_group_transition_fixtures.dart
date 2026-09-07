import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../features/customer_profile/application/customer_profile_cubit.dart';
import '../../../features/customer_profile/application/customer_profile_state.dart';
import '../../../features/delivery_receipt/application/delivery_receipt_cubit.dart';
import '../../../features/delivery_receipt/application/delivery_receipt_state.dart';
import '../../../features/dispute_status/application/dispute_status_cubit.dart';
import '../../../features/dispute_status/application/dispute_status_state.dart';
import '../../../features/earnings/application/earnings_cubit.dart';
import '../../../features/earnings/application/earnings_state.dart';
import '../../../features/goods_cost/application/goods_cost_cubit.dart';
import '../../../features/jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../../features/jeeber_request_feed/cubit/submitted_offers_state.dart';
import '../../../features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'catalog_transition_host.dart';

Element? _byId(Element root, String id) =>
    CatalogTransitionHost.find<Semantics>(
      root,
      (w) => w.properties.identifier == id,
    );

/// The final step verifies the real rendered failure, including listener snacks.
/// The operation itself is not repeated while waiting for the rendered result.
Widget _drive(
  Widget child,
  String rootId,
  bool Function(Element) act,
  String resultId,
) => CatalogTransitionHost(
  steps: [
    (root) {
      final element = _byId(root, rootId);
      return element != null && act(element);
    },
    (root) {
      if (_byId(root, resultId) != null) return true;
      final element = _byId(root, rootId);
      if (element == null) return false;
      final overlay = Navigator.maybeOf(element)?.overlay;
      return overlay != null &&
          _byId(overlay.context as Element, resultId) != null;
    },
  ],
  child: child,
);

Widget catalogProfileRefresh(Widget child) =>
    _drive(child, 'customer_profile_root', (element) {
      final cubit = element.read<CustomerProfileCubit>();
      if (cubit.state.status != CustomerProfileStatus.loaded) return false;
      unawaited(cubit.refresh());
      return true;
    }, 'customer_profile_refresh_error');

Widget catalogProfileRateApp(Widget child) => _drive(
  Scaffold(body: child),
  'customer_profile_root',
  (element) {
    final row = CatalogTransitionHost.find<JeebListRow>(
      element,
      (w) => w.identifier == 'customer_profile_rate_app_row',
    );
    if (row == null) return false;
    (row.widget as JeebListRow).onTap!();
    return true;
  },
  'customer_profile_rate_app_unavailable',
);

Widget catalogReceiptRefresh(Widget child) =>
    _drive(child, 'receipt_prompt', (element) {
      final cubit = element.read<DeliveryReceiptCubit>();
      if (cubit.state.status != DeliveryReceiptStatus.loaded) return false;
      unawaited(cubit.refresh());
      return true;
    }, 'receipt_refresh_failed');

Widget catalogDisputeRefresh(Widget child) =>
    _drive(child, 'dispute_status_root', (element) {
      final cubit = element.read<DisputeStatusCubit>();
      if (cubit.state.status != DisputeStatusViewStatus.loaded) return false;
      unawaited(cubit.refresh());
      return true;
    }, 'dispute_status_refresh_error');

Widget catalogEarningsFailure(Widget child, {bool export = false}) => _drive(
  child,
  'earnings_dashboard_root',
  (element) {
    final cubit = element.read<EarningsCubit>();
    if (cubit.state.mode != EarningsViewMode.ready) return false;
    unawaited(export ? cubit.exportPdf() : cubit.refresh());
    return true;
  },
  export ? 'earnings_export_error_snack' : 'earnings_refresh_failed_note',
);

Widget catalogGoodsUnconfirmed(Widget child) =>
    _drive(child, 'goods_cost_root', (element) {
      final cubit = element.read<GoodsCostCubit>();
      if (cubit.state.currency == null) return false;
      final field = CatalogTransitionHost.find<TextField>(element);
      if (field == null) return false;
      final input = field.widget as TextField;
      input.controller!.text = '42';
      input.onChanged?.call('42');
      unawaited(cubit.submit(42));
      return true;
    }, 'goods_cost_error_note');

Widget catalogWithdrawFailure(Widget child) =>
    _drive(child, 'jeeber_pending_offers_root', (element) {
      final cubit = element.read<SubmittedOffersCubit>();
      if (cubit.state.status != SubmittedOffersStatus.ready ||
          cubit.state.offers.isEmpty) {
        return false;
      }
      unawaited(cubit.withdraw(cubit.state.offers.first.id));
      return true;
    }, 'pending_offers_withdraw_failed_snack');

Widget catalogPendingRefresh(Widget child) =>
    _drive(child, 'jeeber_pending_offers_root', (element) {
      final cubit = element.read<SubmittedOffersCubit>();
      if (cubit.state.status != SubmittedOffersStatus.ready ||
          cubit.state.offers.isEmpty) {
        return false;
      }
      unawaited(cubit.load());
      return true;
    }, 'pending_offers_refresh_failed_note');

Widget catalogProofPhotoFailure(Widget child) =>
    _drive(child, 'mark_delivered_root', (element) {
      final cubit = element.read<ActiveDeliveryCubit>();
      if (cubit.state.mode != ActiveDeliveryMode.ready) return false;
      unawaited(cubit.captureProofPhoto());
      return true;
    }, 'active_delivery_proof_photo_error');

Widget catalogActiveRefresh(Widget child) =>
    _drive(child, 'mark_delivered_root', (element) {
      final cubit = element.read<ActiveDeliveryCubit>();
      if (cubit.state.mode != ActiveDeliveryMode.ready) return false;
      unawaited(cubit.refresh());
      return true;
    }, 'active_delivery_refresh_failed');
