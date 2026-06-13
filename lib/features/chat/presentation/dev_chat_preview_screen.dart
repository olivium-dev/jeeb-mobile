import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/dev_chat_fixture_gateway.dart';
import '../domain/delivery_chat_message.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import 'chat_screen.dart';
import 'widgets/chat_fee_banner.dart';
import 'widgets/confirm_delivery_action_sheet.dart';

/// Debug-only full-screen host that renders [ChatScreen] for one of the
/// designed chat states, backed by [DevChatFixtureGateway].
///
/// Reached only via the router's `JEEB_DEV_CHAT` seam (see `AppRouter`), which
/// extends the established `JEEB_DEV_*` dart-define pattern (pilot learning
/// #1) so the Figma chat frames can be captured deterministically on the
/// emulator. Never reachable in release.
///
/// Selectors:
///   `sending`               → client's just-sent initial request, pre-offers
///                             (Figma 56535:6469) — single outgoing bubble, no
///                             offer cards, composer present
///   `broadcasting`          → client offers feed (Figma 56535:6659)
///   `accepted` / *          → client accepted thread (Figma 56546:2382)
///   `dm`                    → delivery-man chat (Figma 56539:906)
///   `dm-order-picked`       → delivery-man chat, "Order picked" banner
///                             (Figma 56560:1605)
///   `dm-confirm-picking`    → delivery-man chat + confirm-picking sheet
///                             (Figma 56618:2751)
///   `dm-confirm-heading-off`→ delivery-man chat + heading-off sheet
///                             (Figma 56618:2852)
class DevChatPreviewScreen extends StatelessWidget {
  const DevChatPreviewScreen({super.key, required this.selector});

  final String selector;

  bool get _isDeliveryMan => selector.startsWith('dm');

  ChatFeeBannerTrailing get _bannerTrailing {
    if (selector == 'dm-order-picked') return ChatFeeBannerTrailing.orderPicked;
    if (selector == 'dm') return ChatFeeBannerTrailing.none;
    return ChatFeeBannerTrailing.dismiss;
  }

  DeliveryConfirmKind? get _autoSheet => switch (selector) {
        'dm-confirm-picking' => DeliveryConfirmKind.picking,
        'dm-confirm-heading-off' => DeliveryConfirmKind.headingOff,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    if (_isDeliveryMan) return _DeliveryManPreview(host: this);
    return _clientPreview();
  }

  Widget _clientPreview() {
    final sending = selector == 'sending';
    final broadcasting = selector == 'broadcasting';
    // `sending` and `broadcasting` share the request-feed header (centered
    // order id, no counterpart avatar) and the broadcasting phase semantics
    // (composer visible, no counterpart header). `sending` differs only in the
    // seeded thread: a single outgoing request with no offer cards yet.
    final requestFeed = sending || broadcasting;
    final phase = requestFeed
        ? ConversationPhase.broadcasting
        : ConversationPhase.accepted;
    // No bundled avatar bitmap (dev-only assets must not ship): the accepted
    // header falls back to the OMDS initials avatar, captured deterministically
    // and offline.
    return ChatScreen(
      deliveryId: 'dev-chat',
      counterpartName: requestFeed ? 'ORD-23748' : 'Kamal Hajj',
      gateway: DevChatFixtureGateway(phase: phase, sending: sending),
      pickerService: StubPhotoPickerService(),
    );
  }
}

/// Delivery-man chat preview: fee banner + price/time composer hint, with an
/// optional confirmation sheet auto-opened for the picking / heading-off
/// states so they can be captured without a tap.
class _DeliveryManPreview extends StatefulWidget {
  const _DeliveryManPreview({required this.host});

  final DevChatPreviewScreen host;

  @override
  State<_DeliveryManPreview> createState() => _DeliveryManPreviewState();
}

class _DeliveryManPreviewState extends State<_DeliveryManPreview> {
  static const String _feeAmount = r'$0.5';

  /// Backing delivery for this Jeeber-variant thread. Reused both as the chat
  /// channel id and as the path id for the active-delivery entry point so the
  /// "Start delivery" CTA opens the matching delivery.
  static const String _deliveryId = 'dev-chat-dm';

  @override
  void initState() {
    super.initState();
    final kind = widget.host._autoSheet;
    if (kind != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet(kind));
    }
  }

  Future<void> _openSheet(DeliveryConfirmKind kind) async {
    if (!mounted) return;
    await ConfirmDeliveryActionSheet.show(
      context,
      kind: kind,
      onConfirm: () async {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatScreen(
      deliveryId: _deliveryId,
      counterpartName: 'Sami Fawaz',
      composerHint: AppLocalizations.of(context).chatComposerHintPriceTime,
      feeNotice: ChatFeeNotice(
        amount: _feeAmount,
        trailing: widget.host._bannerTrailing,
        onDismiss: () {},
        onOrderPicked: () {},
      ),
      // ENTRY POINT (jeeber active-delivery): the Jeeber-variant chat is the
      // only place a jeeber-role [ChatScreen] is constructed (feeNotice !=
      // null). The production `/chat/:id` route builds the CLIENT variant via
      // ChatDetailScreen (currentUserId hardcoded to a client, feeNotice null,
      // and it resolves a conversation id rather than carrying the jeeber role
      // + delivery id), so it cannot cleanly supply both signals today. We
      // therefore gate the "Start delivery" CTA on the jeeber variant here,
      // where the delivery id is in scope, and push the active-delivery route.
      onStartActiveDelivery: () =>
          context.push('/jeeber/deliveries/$_deliveryId/active'),
      gateway: DevChatFixtureGateway(
        phase: ConversationPhase.accepted,
        deliveryMan: true,
      ),
      pickerService: StubPhotoPickerService(),
    );
  }
}
