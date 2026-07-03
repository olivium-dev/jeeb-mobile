import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/notifications/domain/notification_deep_link.dart';
import '../../../core/notifications/domain/notification_message.dart';
import '../application/notifications_list_cubit.dart';
import '../application/notifications_list_state.dart';
import '../data/empty_notifications_repository.dart';
import '../domain/notifications_repository.dart';
import 'notifications_l10n.dart';
import 'widgets/notification_row.dart';

/// notifications-list (JM-057). The shared inbox reached from the header bell
/// (`orders_home_bell` / `delivery_tab_bell` / `customer_profile_bell`, wired by
/// the integrator to `goNamed('notifications')`).
///
/// Renders the 4-state machine (40_GUARDRAILS_ARCH §3): loading / failed /
/// loaded(+empty). Each typed `notif_row_<id>` shows the category, payload
/// title/body and a relative timestamp; tapping a row (a) marks it read
/// optimistically and (b) dispatches the D84 deep-link for its kind.
///
/// D84 per-row dispatch (30_BACKLOG JM-057 AC; 21_NAV_PLAN §C):
///   offer                      → my-orders          (Replies sub-tab → `shell`)
///   offer_accepted / status    → order-chat         (`chat-detail`, ref=conv/req)
///   low_balance / fee_won /
///     refund_penalty / topup   → wallet-hub         (`wallet`)
///   kyc_approved               → jeeber-requests-home (Dashboard tab → `shell`)
///   kyc_rejected               → kyc-rejected
///   request_expired            → waiting-no-coverage (`/requests/:id/waiting`)
///   confirm_receipt            → delivered-receipt   (`/orders/:id/receipt`)
///   marketing                  → customer-orders-home (Requests tab → `shell`)
///   new_request (G3)           → the request screen, via the SAME resolver
///                                the push tap uses (`deepLinkForMessage` →
///                                `/jeeber/requests/:id`) so a dismissed push
///                                keeps a persistent, tappable inbox trail
///   unknown / missing-ref      → no nav (mark-read only; AP-9 honesty — never
///                                fabricate a target the row can't address)
///
/// Tabs are NOT routes (21_NAV_PLAN §A): the tab-landing kinds route to `shell`
/// and rely on the shell's role/sub-tab default. Reads the LIVE
/// notification-service via `sl<NotificationsRepository>()` (DioNotificationsRepository;
/// list+read mock-ready on :4010 — 42_GUARDRAILS_MOCK §4). [repository] is a
/// constructor test seam (§5.4) — production leaves it null.
///
/// Semantics identifiers exposed (EXACT — 30_BACKLOG JM-057, 41_GUARDRAILS_TESTING):
///   `notifications_root`             — screen host container (bell nav target)
///   `notif_row_<id>`                 — per-notification row (dynamic), tap → D84
///   `notif_row_<id>_timestamp`       — per-row relative timestamp
///   `notif_row_<id>_unread_badge`    — per-row unread dot (accessibility)
class NotificationsListScreen extends StatelessWidget {
  const NotificationsListScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final NotificationsRepository? repository;

  /// Resolves the repo: an explicit override (tests) → the registered LIVE
  /// `DioNotificationsRepository` → an empty fallback when GetIt is not
  /// configured (router-resolution widget tests). Mirrors
  /// `ClientOffersScreen._resolveRepository()`.
  NotificationsRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<NotificationsRepository>()) {
      return sl<NotificationsRepository>();
    }
    return const EmptyNotificationsRepository();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsListCubit>(
      create: (_) =>
          NotificationsListCubit(repository: _resolveRepository())..load(),
      child: const _NotificationsListView(),
    );
  }
}

class _NotificationsListView extends StatelessWidget {
  const _NotificationsListView();

  @override
  Widget build(BuildContext context) {
    final copy = NotificationsL10n.of(context);
    return Semantics(
      identifier: 'notifications_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.title,
          showBackButton: true,
          // The bell reaches this screen via stack-REPLACING `goNamed(
          // 'notifications')`, so there is usually nothing to pop. Pop when we
          // can (pushed entry), else return to the shell — never pop the last
          // page (which would leave an empty Navigator → black surface).
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: BlocBuilder<NotificationsListCubit, NotificationsListState>(
          builder: (context, state) {
            switch (state.status) {
              case NotificationsListStatus.initial:
              case NotificationsListStatus.loading:
                return const OmdsLoadingState();
              case NotificationsListStatus.failed:
                return OmdsErrorState(
                  message: _errorCopy(copy, state.error),
                  retryLabel: copy.retry,
                  onRetry: () =>
                      context.read<NotificationsListCubit>().refresh(),
                );
              case NotificationsListStatus.loaded:
                return RefreshIndicator(
                  onRefresh: () =>
                      context.read<NotificationsListCubit>().refresh(),
                  child: !state.hasItems
                      ? _EmptyBody(copy: copy)
                      : _LoadedList(items: state.items, copy: copy),
                );
            }
          },
        ),
      ),
    );
  }

  static String _errorCopy(NotificationsL10n copy, NotificationsFailure? f) {
    switch (f) {
      case NotificationsFailure.network:
        return copy.networkError;
      case NotificationsFailure.unauthorized:
      case NotificationsFailure.unknown:
      case null:
        return copy.loadError;
    }
  }
}

/// Empty = `loaded` + an empty list (NOT a fifth status, §3). Wrapped in a
/// scrollable so the pull-to-refresh still works on an empty inbox.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.copy});

  final NotificationsL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        OmdsEmptyState(
          icon: Icons.notifications_none_outlined,
          title: copy.emptyTitle,
          subtitle: copy.emptyBody,
        ),
      ],
    );
  }
}

class _LoadedList extends StatelessWidget {
  const _LoadedList({required this.items, required this.copy});

  final List<NotificationItem> items;
  final NotificationsL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return NotificationRow(
          item: item,
          copy: copy,
          onTap: () => _onRowTap(context, item),
        );
      },
    );
  }

  /// (a) mark read (optimistic; cubit owns the flag), then (b) dispatch the
  /// D84 deep-link. Side-effect navigation lives here (the InkWell callback),
  /// never in a `builder` (40_GUARDRAILS_ARCH §3 nav-in-listener rule — this is
  /// an explicit user gesture, not a rebuild).
  void _onRowTap(BuildContext context, NotificationItem item) {
    context.read<NotificationsListCubit>().markRead(item.id);
    _dispatch(context, item);
  }

  void _dispatch(BuildContext context, NotificationItem item) {
    final ref = item.ref;
    switch (item.kind) {
      // Wallet money rows → wallet-hub (`wallet`).
      case NotificationKind.lowBalance:
      case NotificationKind.feeWon:
      case NotificationKind.refundPenalty:
      case NotificationKind.topup:
        context.goNamed('wallet');
        break;

      // Offer-accepted + order-status + (dispute) → the conversation thread.
      // `ref` carries the conversationId / requestId to address the chat.
      case NotificationKind.offerAccepted:
      case NotificationKind.status:
        if (ref != null) {
          context.goNamed('chat-detail', pathParameters: {'id': ref});
        }
        break;

      // A fresh offer → my-orders (Replies sub-tab) — a shell tab, not a route.
      case NotificationKind.offer:
        context.goNamed('shell');
        break;

      // KYC approved → jeeber-requests-home (Dashboard tab) — a shell tab.
      case NotificationKind.kycApproved:
        context.goNamed('shell');
        break;

      // KYC rejected → the appeal-only rejected screen (D52/D87).
      case NotificationKind.kycRejected:
        context.goNamed('kyc-rejected');
        break;

      // Request expired → waiting / no-coverage (`/requests/:id/waiting`).
      case NotificationKind.requestExpired:
        if (ref != null) {
          context.goNamed('waiting-no-coverage', pathParameters: {'id': ref});
        }
        break;

      // Confirm-receipt → the delivered-receipt prompt (`/orders/:id/receipt`);
      // `ref` is the deliveryId.
      case NotificationKind.confirmReceipt:
        if (ref != null) {
          context.goNamed('delivered-receipt', pathParameters: {'id': ref});
        }
        break;

      // Marketing → customer-orders-home (Requests tab) — a shell tab.
      case NotificationKind.marketing:
        context.goNamed('shell');
        break;

      // G3: new_request → the request screen. CONSUME the push-tap resolver
      // (deepLinkForMessage, fix/push-tap-routing) rather than re-mapping the
      // route here, so the inbox row and the push tap can never diverge —
      // `/jeeber/requests/:id` already handles cache recovery + graceful
      // fallback for taken/expired requests. Pushed (not go) so back returns
      // to the inbox.
      case NotificationKind.newRequest:
        if (ref == null) break;
        final target = deepLinkForMessage(NotificationMessage(
          id: item.id,
          category: NotificationCategory.newRequest,
          title: item.title,
          body: item.body,
          receivedAt: DateTime.now(),
          data: {'requestId': ref},
        ));
        if (target != null) context.push(target);
        break;

      // Unknown / unmapped — mark-read only, stay on the inbox (AP-9: never
      // fabricate a destination the row can't address).
      case NotificationKind.unknown:
        break;
    }
  }
}
