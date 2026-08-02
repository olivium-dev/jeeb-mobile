import 'dart:async';

import 'package:flutter/material.dart';

import '../application/push_notification_handler.dart';
import '../domain/notification_message.dart';

class PushBannerHost extends StatefulWidget {
  const PushBannerHost({
    super.key,
    required this.handler,
    required this.child,
    this.onBannerTap,
    this.autoDismiss = const Duration(seconds: 5),
  });

  final PushNotificationHandler handler;
  final Widget child;
  final void Function(NotificationMessage message)? onBannerTap;
  final Duration autoDismiss;

  @override
  State<PushBannerHost> createState() => _PushBannerHostState();
}

class _PushBannerHostState extends State<PushBannerHost> {
  Timer? _dismissTimer;
  String? _lastBannerId;

  void _scheduleDismiss(NotificationMessage message) {
    _dismissTimer?.cancel();
    if (widget.autoDismiss == Duration.zero) return;
    _dismissTimer = Timer(widget.autoDismiss, () {
      if (!mounted) return;
      if (widget.handler.state.banner?.id == message.id) {
        widget.handler.dismissBanner();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PushNotificationState>(
      stream: widget.handler.stream,
      initialData: widget.handler.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.handler.state;
        final banner = state.banner;
        if (banner != null && banner.id != _lastBannerId) {
          _lastBannerId = banner.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scheduleDismiss(banner);
          });
        }
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (banner != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: _BannerCard(
                    key: ValueKey(banner.id),
                    message: banner,
                    onTap: () {
                      widget.handler.tapBanner();
                      widget.onBannerTap?.call(banner);
                    },
                    onDismiss: widget.handler.dismissBanner,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    super.key,
    required this.message,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationMessage message;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHigh,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconForCategory(message.category),
                  color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title.isEmpty ? 'Notification' : message.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message.body,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.delivery:
        return Icons.local_shipping_outlined;
      case NotificationCategory.chat:
        return Icons.chat_bubble_outline;
      case NotificationCategory.kyc:
        return Icons.verified_user_outlined;
      case NotificationCategory.rating:
        return Icons.star_outline;
      case NotificationCategory.settings:
        return Icons.settings_outlined;
      case NotificationCategory.newRequest:
        return Icons.assignment_outlined;
      case NotificationCategory.newOffer:
      case NotificationCategory.offerAccepted:
      case NotificationCategory.offerLost:
        return Icons.local_offer_outlined;
      case NotificationCategory.requestExpired:
        return Icons.timer_off_outlined;
      case NotificationCategory.other:
        return Icons.notifications_outlined;
    }
  }
}
