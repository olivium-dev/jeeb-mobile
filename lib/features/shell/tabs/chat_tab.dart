import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/directional_icons.dart';
import '../../../l10n/app_localizations.dart';

/// Entry-point for the chat experience.
///
/// Lists active conversations backed by the mock backend. Each card
/// corresponds to a delivery or request that has a linked conversation.
/// Tapping navigates to `/chat/:id` (handled by [ChatDetailScreen]).
class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  static const Key activeDeliveryCardKey = Key('chat-tab-active-delivery');

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  List<_ConversationSummary> _conversations = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final dio = getIt<Dio>();
      final response = await dio.get<Map<String, dynamic>>(
        '/v1/requests',
        queryParameters: {'status': 'active', 'page': 1, 'pageSize': 20},
      );
      final items = response.data?['items'] as List? ?? [];
      final summaries = <_ConversationSummary>[];
      for (final raw in items) {
        if (raw is Map<String, dynamic>) {
          final convId = raw['conversationId'] as String?;
          if (convId == null || convId.isEmpty) continue;
          summaries.add(_ConversationSummary(
            requestId: raw['id'] as String? ?? '',
            conversationId: convId,
            title: raw['title'] as String? ?? 'Delivery',
            status: raw['status'] as String? ?? '',
            tier: raw['tier'] as String? ?? '',
          ));
        }
      }
      if (mounted) {
        setState(() {
          _conversations = summaries;
          _loading = false;
        });
      }
    } on DioException {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: OmdsLoadingState());
    }
    if (_conversations.isEmpty) {
      return Center(
        child: OmdsEmptyState(
          key: const Key('chat-tab-empty'),
          icon: Icons.chat_bubble_outline,
          title: l10n.chatTitle,
          subtitle: l10n.chatEmpty,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Spacing.small),
      itemCount: _conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return InkWell(
          key: index == 0 ? ChatTab.activeDeliveryCardKey : null,
          onTap: () => GoRouter.of(context).pushNamed(
            'chat-detail',
            pathParameters: {'id': conv.chatRouteId},
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.medium,
              vertical: Spacing.medium,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: Spacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        conv.status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(DirectionalIcons.disclosure(context)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConversationSummary {
  const _ConversationSummary({
    required this.requestId,
    required this.conversationId,
    required this.title,
    required this.status,
    required this.tier,
  });

  /// Request id (== correlationKey). Empty when the gateway omits it.
  final String requestId;
  final String conversationId;
  final String title;
  final String status;
  final String tier;

  /// BUG-18 client side: prefer the request id (== correlationKey) over the
  /// conversation id. Chat-detail resolves correlationKey-first, so routing by
  /// requestId avoids a guaranteed 404 probe; fall back to the conversationId
  /// only when the gateway omitted the request id.
  String get chatRouteId => requestId.isNotEmpty ? requestId : conversationId;
}
