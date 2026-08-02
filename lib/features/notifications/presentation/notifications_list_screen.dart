import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/notifications/domain/notification_deep_link.dart';
import '../../../core/notifications/domain/notification_message.dart';
import '../../../core/role/role_cubit.dart';
import '../application/notifications_list_cubit.dart';
import '../application/notifications_list_state.dart';
import '../data/empty_notifications_repository.dart';
import '../domain/notifications_repository.dart';
import 'notifications_l10n.dart';
import 'widgets/notification_row.dart';

class NotificationsListScreen extends StatelessWidget {
  const NotificationsListScreen({super.key, this.repository});

  final NotificationsRepository? repository;

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
                return OmdsPullToRefresh(
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

  void _onRowTap(BuildContext context, NotificationItem item) {
    context.read<NotificationsListCubit>().markRead(item.id);
    _dispatch(context, item);
  }

  void _dispatch(BuildContext context, NotificationItem item) {
    final ref = item.ref;
    switch (item.kind) {
      case NotificationKind.lowBalance:
      case NotificationKind.feeWon:
      case NotificationKind.refundPenalty:
      case NotificationKind.topup:
        context.goNamed('wallet');
        break;

      case NotificationKind.offerAccepted:
        if (ref != null) {
          context.goNamed('chat-detail', pathParameters: {'id': ref});
        } else {
          context.goNamed('shell');
        }
        break;

      case NotificationKind.status:
        if (ref != null) {
          context.goNamed('chat-detail', pathParameters: {'id': ref});
        }
        break;

      case NotificationKind.offer:
        if (ref == null) {
          context.goNamed('shell');
          break;
        }
        final offerTarget = deepLinkForMessage(NotificationMessage(
          id: item.id,
          category: NotificationCategory.newOffer,
          title: item.title,
          body: item.body,
          receivedAt: DateTime.now(),
          data: {'requestId': ref},
        ));
        if (offerTarget != null) context.push(offerTarget);
        break;

      case NotificationKind.kycApproved:
        context.goNamed('shell');
        break;

      case NotificationKind.kycRejected:
        context.goNamed('kyc-rejected');
        break;

      case NotificationKind.requestExpired:
        if (ref != null) {
          context.goNamed('waiting-no-coverage', pathParameters: {'id': ref});
        }
        break;

      case NotificationKind.confirmReceipt:
        if (ref != null) {
          context.goNamed('delivered-receipt', pathParameters: {'id': ref});
        }
        break;

      case NotificationKind.marketing:
        context.goNamed('shell');
        break;

      // `/jeeber/requests/:id` already handles cache recovery + graceful
      case NotificationKind.newRequest:
        if (ref == null) break;
        final target = deepLinkForMessage(
          NotificationMessage(
            id: item.id,
            category: NotificationCategory.newRequest,
            title: item.title,
            body: item.body,
            receivedAt: DateTime.now(),
            data: {'requestId': ref},
          ),
          role: context.read<RoleCubit>().state,
        );
        if (target != null) context.push(target);
        break;

      case NotificationKind.unknown:
        break;
    }
  }
}
