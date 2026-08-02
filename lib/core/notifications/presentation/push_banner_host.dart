import 'dart:async';

import 'package:flutter/material.dart';

import '../application/push_notification_handler.dart';
import '../domain/notification_message.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../application/badge_count_cubit.dart';
import '../data/push_transport.dart';
import '../../previews/jeeb_preview.dart';

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
        // sprint-009 offer-lifecycle: accept/lost banners carry the offer icon;
        // the tap routes to the pending-offers surface (see NotificationDeepLink).
        // P2: a customer's inbound new bid (`newOffer`) shares the offer icon.
        return Icons.local_offer_outlined;
      case NotificationCategory.requestExpired:
        // P2/F3: no-coverage / expiry nudge — the tap lands on the waiting
        // screen (see NotificationDeepLink).
        return Icons.timer_off_outlined;
      case NotificationCategory.other:
        return Icons.notifications_outlined;
    }
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/core/push_banner_host_preview_test.dart
// ===========================================================================
//
// Widget previews for [PushBannerHost] — run with
// `flutter widget-preview start`.
//
// [PushBannerHost] is a wrapper: it stacks an in-app banner over whatever
// screen is on show whenever [PushNotificationHandler] is holding a foreground
// message. So a preview has to supply two things — the screen underneath
// ([_AppUnderneath], a fixture) and a handler already holding the banner.
//
// **How the state is seeded, and why it is network-free.** The host takes a
// concrete [PushNotificationHandler] (not an interface), and that handler hard-codes
// its own initial state, so there is no `seed:` constructor to borrow the way
// `ClientHomeGreeting`'s previews borrow `GreetingProfileCubit(seed: …)`. The
// preview-local [_SeededPushHandler] closes that gap without touching production
// code: it feeds the real handler a [FakePushTransport] (an in-memory
// `StreamController`, the same one every `test/push_*.dart` injects) plus a bare
// [BadgeCountCubit] with no durable inbox, then emits the banner state directly.
// Nothing in that path can reach Dio, so these previews are network-free by
// construction rather than merely by the guard in [jeebPreviewHost].
//
// Seeding via `emit` rather than `transport.emitForeground(…)` is deliberate:
// the transport route is asynchronous (the handler subscribes to a stream), and
// a preview function must return a fully-formed widget synchronously. It also
// keeps the previews about the BANNER's rendering rather than about the
// handler's admission rules — audience-role suppression, id dedup and the
// open-thread silence in `shouldShowForegroundPush` are pinned in
// `test/core/notifications/push_banner_suppression_test.dart`, and none of them
// paint a pixel.
//
// **Every preview passes `autoDismiss: Duration.zero`.** The production default
// is 5 seconds, which in the canvas means a banner that erases itself while you
// are still looking at it — and in the render test, a pending [Timer] that
// outlives the widget tree. Zero is an explicitly handled branch of the widget
// (`_scheduleDismiss` returns before arming anything), not a value smuggled past
// it; `test/core/notifications/push_banner_host_overlay_test.dart` mounts it the
// same way for the same reason.
//
// The fixtures reuse the copy already in `test/push_banner_host_test.dart`
// ("New delivery" / "Order #42", clock 2026-05-17) so a reviewer comparing the
// two is looking at one set of values.

/// Phone width, with enough height below the banner to show that it is an
/// overlay on a screen rather than a page of its own.
const Size _pushBannerHostBannerBox = Size(390, 240);

/// Same width, taller: the two-line body and the wrapped 200%-text rendering
/// need the room, and clipping the evidence is the one thing a preview box must
/// not do.
const Size _pushBannerHostTallBannerBox = Size(390, 340);

/// A representative status-bar inset in logical pixels — the iPhone 14/15 value,
/// and close enough to a modern Android cutout. Seeded by
/// [pushBannerHostUnderStatusBar]; see that preview for why it is not zero.
const double _pushBannerHostStatusBarDp = 47;

/// Fixed clock, matching `test/push_banner_host_test.dart`. `receivedAt` is not
/// rendered by the banner, but a fixture that invents `DateTime.now()` makes two
/// runs of the same preview non-identical for no benefit.
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
    // mid-review and leave a pending timer in the render test.
    autoDismiss: Duration.zero,
    onBannerTap: (NotificationMessage _) {},
    child: _PushBannerHostAppUnderneath(label: screenLabel),
  );
  if (statusBarInset == 0) return host;
  return _PushBannerHostStatusBarInset(top: statusBarInset, child: host);
}

/// The state the host is in for almost all of its life: no foreground message,
/// so it must be invisible.
///
/// Worth a preview precisely because it renders nothing of its own — the host
/// wraps the ENTIRE app (`app.dart` mounts it as the `MaterialApp.router`
/// builder, above the Navigator), so any stray padding, tint or intercepted
/// pointer it adds while idle is paid on every screen of the product. What you
/// should see here is the fixture screen, edge to edge, unaltered.
@JeebPreview(group: 'core', name: 'Idle · no banner', size: _pushBannerHostBannerBox)
Widget pushBannerHostIdle() => _pushBannerHostHosted(screenLabel: 'Idle, no banner');

/// The happy path, with the fixture from `test/push_banner_host_test.dart`: a
/// `delivery` push over the screen the user was already on.
///
/// This is the reference reading for the three renderings of the matrix — the
/// card's elevation and `surfaceContainerHigh` fill have to separate it from
/// whatever is behind it in BOTH themes, and the leading icon is tinted
/// `colorScheme.primary` against that fill rather than the theme's `onSurface`
/// pair.
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
///
/// The banner substitutes the literal `'Notification'` for an empty title
/// (`push_banner_host.dart` line 145). That fallback is a hardcoded English
/// string with no ARB key behind it, so the **AR RTL dark** rendering of this
/// state shows an English word in an otherwise Arabic banner — which is the
/// whole reason this state has a preview. The payload is reachable: the gateway
/// flattens data-only pushes into the FCM `data` map, and a message that carries
/// no `notification` block parses to an empty title.
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
///
/// The body block is wrapped in `if (message.body.isNotEmpty)`, so this is the
/// only state that exercises the one-line card — a single [Text] between a
/// 24px icon and a 48px [IconButton]. It is the shortest card the widget can
/// produce, and therefore the one where the fixed-size trailing control most
/// visibly out-measures the content it sits beside at 200% text.
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
///
/// Chat pushes carry the sender's full name plus the message text, neither of
/// which the gateway truncates, so this is not a strawman — it is what a normal
/// two-sentence message looks like on the wire. The card clamps to 1 title line
/// and 2 body lines with [TextOverflow.ellipsis], and this is the state that
/// proves the clamp holds once the 200% rendering has doubled the type and the
/// AR rendering has swapped the reading direction under a `Positioned` that is
/// pinned with `left`/`right` rather than `start`/`end`.
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
///
/// [PushBannerHost] positions the card at `MediaQuery.padding.top + 8` and then
/// wraps it in `SafeArea(bottom: false)`, which pads by `MediaQuery.padding.top`
/// AGAIN — the status-bar inset is reserved twice, so on a 47pt notch the card
/// lands ~102pt from the top instead of ~55pt. `app.dart` mounts the host as the
/// `MaterialApp.router` builder, i.e. above the Navigator and above any
/// [SafeArea], so nothing upstream has consumed that padding on a real device
/// and the doubling is live in production.
///
/// The seed is needed because [jeebPreviewHost] wraps every preview in a
/// [SafeArea] that has already zeroed `padding.top` by the time the widget under
/// review sees it; [_PushBannerHostStatusBarInset] restores the inset BELOW that wrapper so the
/// canvas models the real mount point. The render test pins the doubled offset
/// rather than these previews hiding it.
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
///
/// The handler's own constructor pins its initial state to
/// `const PushNotificationState()`, so a subclass emitting once is the smallest
/// seam that seeds a banner without editing production code. [FakePushTransport]
/// is inert until something calls `emitForeground`, which nothing here does, and
/// [BadgeCountCubit] with no [LocalPushInbox] is pure in-memory — so constructing
/// this touches no platform channel, no storage and no socket.
///
/// `openChatThreadIds` is supplied explicitly to avoid the default
/// `ActiveChatThread.instance` singleton: a preview must not read, let alone
/// depend on, app-wide mutable state.
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
///
/// Deliberately opaque and full-bleed: the banner is an overlay, and an overlay
/// reviewed against an empty white box tells you nothing about whether its fill
/// and elevation actually separate it from the page. The label names the
/// scenario and is intentionally unlocalized — seeing English here in the AR RTL
/// rendering is expected, and is how a reviewer tells fixture copy from the
/// banner's own strings.
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
///
/// Written as a widget over the ambient [MediaQuery] rather than a replacement
/// for it, so everything else the canvas configured (text scale, size, platform
/// brightness) survives. `viewPadding` is seeded alongside `padding` because a
/// device where the two disagree does not exist.
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
