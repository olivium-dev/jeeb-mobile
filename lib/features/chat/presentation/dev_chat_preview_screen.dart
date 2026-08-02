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
    final requestFeed = sending || broadcasting;
    final phase = requestFeed
        ? ConversationPhase.broadcasting
        : ConversationPhase.accepted;
    return ChatScreen(
      deliveryId: 'dev-chat',
      counterpartName: requestFeed ? 'ORD-23748' : 'Kamal Hajj',
      gateway: DevChatFixtureGateway(phase: phase, sending: sending),
      pickerService: StubPhotoPickerService(),
    );
  }
}

class _DeliveryManPreview extends StatefulWidget {
  const _DeliveryManPreview({required this.host});

  final DevChatPreviewScreen host;

  @override
  State<_DeliveryManPreview> createState() => _DeliveryManPreviewState();
}

class _DeliveryManPreviewState extends State<_DeliveryManPreview> {
  static const String _feeAmount = r'$0.5';

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
