import 'dart:async';

import 'package:flutter/material.dart';

import '../application/push_notification_handler.dart';
import '../domain/notification_message.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../application/badge_count_cubit.dart';
import '../data/push_transport.dart';
import '../../previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, with enough height below the banner to show that it is an
/// overlay on a screen rather than a page of its own.
const Size _pushBannerHostBannerBox = Size(390, 240);

/// Same width, taller: the two-line body and the wrapped 200%-text rendering
/// need the room, and clipping the evidence is the one thing a preview box must
const Size _pushBannerHostTallBannerBox = Size(390, 340);

/// A representative status-bar inset in logical pixels — the iPhone 14/15 value,
/// and close enough to a modern Android cutout. Seeded by
const double _pushBannerHostStatusBarDp = 47;

/// Fixed clock, matching `test/push_banner_host_test.dart`. `receivedAt` is not
/// rendered by the banner, but a fixture that invents `DateTime.now()` makes two
final DateTime _pushBannerHostReceivedAt = DateTime.utc(2026, 5, 17, 12, 0);

NotificationMessage _pushBannerHostMessage({
  required String id,
  required NotificationCategory category,
  required String title,
  required String body,
  Map<String, String> data = const <String, String>{},
}) =>
    NotificationMessage(
      id: id,
      category: category,
      title: title,
      body: body,
      receivedAt: _pushBannerHostReceivedAt,
      data: data,
    );

Widget _pushBannerHostHosted({
  NotificationMessage? banner,
  String screenLabel = 'App content',
  double statusBarInset = 0,
}) {
  final Widget host = PushBannerHost(
    handler: _PushBannerHostSeededHandler(banner: banner),
    // See the library doc: the 5s production default would erase the banner
    autoDismiss: Duration.zero,
    onBannerTap: (NotificationMessage _) {},
    child: _PushBannerHostAppUnderneath(label: screenLabel),
  );
  if (statusBarInset == 0) return host;
  return _PushBannerHostStatusBarInset(top: statusBarInset, child: host);
}

/// The state the host is in for almost all of its life: no foreground message,
/// so it must be invisible.
@JeebPreview(group: 'core', name: 'Idle · no banner', size: _pushBannerHostBannerBox)
Widget pushBannerHostIdle() => _pushBannerHostHosted(screenLabel: 'Idle, no banner');

/// The happy path, with the fixture from `test/push_banner_host_test.dart`: a
/// `delivery` push over the screen the user was already on.
@JeebPreview(group: 'core', name: 'Delivery banner', size: _pushBannerHostBannerBox)
Widget pushBannerHostDelivery() => _pushBannerHostHosted(
      banner: _pushBannerHostMessage(
        id: 'a',
        category: NotificationCategory.delivery,
        title: 'New delivery',
        body: 'Order #42',
        data: const <String, String>{'delivery_id': 'd-1'},
      ),
    );

/// A push with a body and NO title.
/// The banner substitutes the literal `'Notification'` for an empty title
@JeebPreview(group: 'core', name: 'Empty title fallback', size: _pushBannerHostBannerBox)
Widget pushBannerHostEmptyTitle() => _pushBannerHostHosted(
      banner: _pushBannerHostMessage(
        id: 'kyc-empty-title',
        category: NotificationCategory.kyc,
        title: '',
        body: 'Your ID check was approved',
      ),
    );

/// The mirror case: a title and NO body.
/// The body block is wrapped in `if (message.body.isNotEmpty)`, so this is the
@JeebPreview(group: 'core', name: 'Title only', size: _pushBannerHostBannerBox)
Widget pushBannerHostTitleOnly() => _pushBannerHostHosted(
      banner: _pushBannerHostMessage(
        id: 'settings-1',
        category: NotificationCategory.settings,
        title: 'Payout method updated',
        body: '',
      ),
    );

/// Layout ceiling: the longest title and body a real push produces.
/// Chat pushes carry the sender's full name plus the message text, neither of
@JeebPreview(group: 'core', name: 'Long title and body', size: _pushBannerHostTallBannerBox)
Widget pushBannerHostLongCopy() => _pushBannerHostHosted(
      banner: _pushBannerHostMessage(
        id: 'chat-long',
        category: NotificationCategory.chat,
        title: 'Abdulrahman Al-Muhandis sent you a message about your Beirut '
            'to Tripoli delivery',
        body: 'Hi! I am at the pickup point but the shop is closed — should I '
            'wait ten more minutes, or would you prefer I collect the parcel '
            'from the branch on Hamra Street instead?',
        data: const <String, String>{'conversationId': 'conv-2'},
      ),
      screenLabel: 'Chat list',
    );

/// The production geometry, and the one state that shows the banner sitting too
/// far down the screen.
@JeebPreview(group: 'core', name: 'Under a status bar', size: _pushBannerHostTallBannerBox)
Widget pushBannerHostUnderStatusBar() => _pushBannerHostHosted(
      banner: _pushBannerHostMessage(
        id: 'accept-1',
        category: NotificationCategory.offerAccepted,
        title: 'Jeeber accepted your request',
        body: 'Sami is on the way to the pickup point',
        data: const <String, String>{'offerId': 'o-1'},
      ),
      screenLabel: 'Request tracking',
      statusBarInset: _pushBannerHostStatusBarDp,
    );

/// A real [PushNotificationHandler] whose state is pre-set, with no live
/// transport behind it.
/// The handler's own constructor pins its initial state to
class _PushBannerHostSeededHandler extends PushNotificationHandler {
  _PushBannerHostSeededHandler({NotificationMessage? banner})
      : super(
          transport: FakePushTransport(),
          badgeCount: BadgeCountCubit(),
          openChatThreadIds: _noOpenThreads,
        ) {
    if (banner != null) {
      emit(PushNotificationState(banner: banner));
    }
  }

  static Set<String> _noOpenThreads() => const <String>{};
}

/// Stand-in for the screen the banner covers.
/// Deliberately opaque and full-bleed: the banner is an overlay, and an overlay
/// reviewed against an empty white box tells you nothing about whether its fill
class _PushBannerHostAppUnderneath extends StatelessWidget {
  const _PushBannerHostAppUnderneath({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Restores the status-bar inset that [jeebPreviewHost]'s [SafeArea] consumed.
/// Written as a widget over the ambient [MediaQuery] rather than a replacement
/// for it, so everything else the canvas configured (text scale, size, platform
class _PushBannerHostStatusBarInset extends StatelessWidget {
  const _PushBannerHostStatusBarInset({required this.top, required this.child});

  final double top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        padding: data.padding.copyWith(top: top),
        viewPadding: data.viewPadding.copyWith(top: top),
      ),
      child: child,
    );
  }
}
