import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../application/push_notification_handler.dart';
import '../data/push_transport.dart';
import '../domain/notification_message.dart';
import 'notification_permission_prompt.dart';

/// Stacks an in-app banner above [child] whenever the handler emits a
/// foreground message.
///
/// Implemented as an overlay rather than via `ScaffoldMessenger` so the
/// banner is visible regardless of which screen the user is on (the
/// shell + onboarding screens don't all share the same Scaffold key).
///
/// The banner auto-dismisses after [autoDismiss] elapses unless the
/// user taps it; tapping invokes [onBannerTap] with the underlying
/// message so the host can deep-link via the dispatcher.
///
/// When [showPermissionPrompt] is true the host also overlays a branded
/// [NotificationPermissionPrompt] while the handler reports a non-granted
/// [PushPermissionStatus] and no foreground banner is on screen. This is the
/// in-app, capturable priming affordance for `POST_NOTIFICATIONS`; it is
/// opt-in (default `false`) so callers that only want the foreground banner —
/// and the existing widget tests — are unaffected. The host never races the
/// first-run OS dialog: it surfaces the priming card only after the handler
/// has resolved a non-granted status (e.g. a prior denial), and **Enable**
/// hands back to [onEnablePermission] rather than requesting inline.
class PushBannerHost extends StatefulWidget {
  const PushBannerHost({
    super.key,
    required this.handler,
    required this.child,
    this.onBannerTap,
    this.autoDismiss = const Duration(seconds: 5),
    this.showPermissionPrompt = false,
    this.onEnablePermission,
    this.onDismissPermission,
  });

  final PushNotificationHandler handler;
  final Widget child;
  final void Function(NotificationMessage message)? onBannerTap;
  final Duration autoDismiss;

  /// Opt-in: render the [NotificationPermissionPrompt] overlay when the
  /// handler reports a non-granted permission status. Defaults to `false`.
  final bool showPermissionPrompt;

  /// Invoked when the user taps **Enable** on the priming prompt. The app
  /// wires this to `PushNotificationHandler.bootstrap()` (which surfaces the
  /// system prompt or deep-links to settings after a prior denial).
  final VoidCallback? onEnablePermission;

  /// Invoked when the user taps **Not now** on the priming prompt.
  final VoidCallback? onDismissPermission;

  @override
  State<PushBannerHost> createState() => _PushBannerHostState();
}

class _PushBannerHostState extends State<PushBannerHost> {
  Timer? _dismissTimer;
  String? _lastBannerId;

  /// Session-local: once the user taps "Not now" we stop re-surfacing the
  /// priming prompt until the host is rebuilt fresh, so it doesn't nag.
  bool _promptDismissed = false;

  void _onDismissPrompt() {
    setState(() => _promptDismissed = true);
    widget.onDismissPermission?.call();
  }

  bool _shouldShowPrompt(PushNotificationState state) {
    return widget.showPermissionPrompt &&
        !_promptDismissed &&
        state.banner == null &&
        state.permission != PushPermissionStatus.granted &&
        state.permission != PushPermissionStatus.notDetermined;
  }

  void _scheduleDismiss(NotificationMessage message) {
    _dismissTimer?.cancel();
    if (widget.autoDismiss == Duration.zero) return;
    _dismissTimer = Timer(widget.autoDismiss, () {
      if (!mounted) return;
      // Only dismiss if the same banner is still on screen — a newer
      // notification arriving mid-timer should reset the clock, not get
      // wiped by the previous one's expiry.
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
    // StreamBuilder rather than BlocConsumer here: the host is constructed
    // in app.dart with the handler as a plain field (not a BlocProvider),
    // and StreamBuilder's behaviour around initialData + subscription
    // setup is the cleanest way to keep the host self-contained — it
    // doesn't matter whether a BlocProvider lives above us.
    return StreamBuilder<PushNotificationState>(
      stream: widget.handler.stream,
      initialData: widget.handler.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.handler.state;
        final banner = state.banner;
        if (banner != null && banner.id != _lastBannerId) {
          _lastBannerId = banner.id;
          // Schedule outside the build phase so the timer doesn't get
          // attributed to this frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scheduleDismiss(banner);
          });
        }
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (banner != null)
              PositionedDirectional(
                top: MediaQuery.of(context).padding.top + Spacing.xSmall,
                start: Spacing.small,
                end: Spacing.small,
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
            if (_shouldShowPrompt(state))
              PositionedDirectional(
                bottom: MediaQuery.of(context).padding.bottom + Spacing.medium,
                start: Spacing.medium,
                end: Spacing.medium,
                child: SafeArea(
                  top: false,
                  child: NotificationPermissionPrompt(
                    onEnable: widget.onEnablePermission ?? () {},
                    onDismiss: _onDismissPrompt,
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
    // Capturable boundary: the device-driven demo + Maestro assert on the
    // `push_banner` identifier (and the per-field keys below) rather than on
    // visible copy, so the foreground-push screenshots are addressable in
    // both directions of the chat run.
    return Semantics(
      identifier: 'push_banner',
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        elevation: UIConstants.elevationLarge,
        borderRadius: OmdsBorderRadius.uiMedium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.small,
              Spacing.small,
              Spacing.xSmall,
              Spacing.small,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconForCategory(message.category),
                    color: colorScheme.primary),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // For chat pushes the title carries the sender name and
                      // the body carries the message text (the gateway sends
                      // title=sender, body=message); the banner renders them
                      // verbatim so foreground parity matches the tray.
                      Text(
                        message.title.isEmpty ? 'Notification' : message.title,
                        key: const Key('push_banner_title'),
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (message.body.isNotEmpty) ...[
                        const SizedBox(height: Spacing.twoXSmall),
                        Text(
                          message.body,
                          key: const Key('push_banner_body'),
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('push_banner_dismiss'),
                  // NO `tooltip:` here. PushBannerHost is mounted ABOVE the
                  // Navigator in app.dart, so there is no `Overlay` ancestor.
                  // Since Flutter 3.10 `Tooltip` builds an `OverlayPortal`,
                  // which calls `Overlay.of(context)` during build and throws
                  // "No Overlay widget found" when none exists — that crash
                  // (caught upstream) silently dropped the entire foreground
                  // banner on device (sprint-05 push-proof §1d). The dismiss
                  // control keeps its accessible label via `Icon.semanticLabel`
                  // (a Semantics node, not an Overlay), so screen readers still
                  // announce "Dismiss" with no Overlay dependency.
                  icon: const Icon(Icons.close, semanticLabel: 'Dismiss'),
                  onPressed: onDismiss,
                ),
              ],
            ),
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
      case NotificationCategory.other:
        return Icons.notifications_outlined;
    }
  }
}
