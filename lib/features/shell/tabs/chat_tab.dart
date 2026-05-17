import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat/presentation/chat_screen.dart';

/// Entry-point for the chat experience.
///
/// MVP behaviour: the tab shows a single placeholder conversation card for
/// the active delivery. Tapping it pushes the WhatsApp-style 1:1 chat
/// (T-mobile-016). A later ticket replaces the placeholder with a real
/// "your active deliveries" feed wired to `jeeb-gateway`.
class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  static const String _placeholderDeliveryId = 'demo-delivery';
  static const Key activeDeliveryCardKey = Key('chat-tab-active-delivery');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Spacing.small),
      children: [
        InkWell(
          key: activeDeliveryCardKey,
          onTap: () => _openChat(context, l10n),
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
                        l10n.chatActiveDeliveryTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        l10n.chatActiveDeliverySubtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: OmdsEmptyState(
            key: const Key('chat-tab-empty'),
            icon: Icons.chat_bubble_outline,
            title: l10n.chatTitle,
            subtitle: l10n.chatEmpty,
          ),
        ),
      ],
    );
  }

  void _openChat(BuildContext context, AppLocalizations l10n) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          deliveryId: _placeholderDeliveryId,
          counterpartName: l10n.chatPlaceholderCounterpartName,
        ),
      ),
    );
  }
}
