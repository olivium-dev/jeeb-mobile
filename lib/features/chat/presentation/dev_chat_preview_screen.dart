import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/dev_chat_fixture_gateway.dart';
import '../domain/delivery_chat_message.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import 'chat_screen.dart';
import 'widgets/chat_fee_banner.dart';
import 'widgets/confirm_delivery_action_sheet.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/dev_chat_preview_screen_fixtures.dart';

/// Debug-only full-screen host that renders [ChatScreen] for one of the
/// designed chat states, backed by [DevChatFixtureGateway].
/// Reached only via the router's `JEEB_DEV_CHAT` seam (see `AppRouter`), which
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone the chat frames are designed against (Figma 56535:6659).
const Size _devChatPreviewScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app. The viewport that produced the
const Size _devChatPreviewScreenCompactBox = Size(320, 568);

/// Pins [child] to a device-sized frame inside whatever box the host gives it.
/// The `size:` on [JeebPreview] boxes the CANVAS; this boxes the WIDGET TREE,
Widget _devChatPreviewScreenFramed(
  Widget child, {
  Size box = _devChatPreviewScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: child),
  );
}

/// One selector, framed. The ordinary host.
Widget _devChatPreviewScreenHosted(
  String selector, {
  Size box = _devChatPreviewScreenPhoneBox,
}) =>
    _devChatPreviewScreenFramed(
      DevChatPreviewScreen(selector: selector),
      box: box,
    );

/// Host for the two selectors that auto-open a confirm sheet.
/// The local [Navigator] is the whole point: [ConfirmDeliveryActionSheet.show]
Widget _devChatPreviewScreenSheetHosted(String selector) {
  return _devChatPreviewScreenFramed(
    Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => DevChatPreviewScreen(selector: selector),
      ),
    ),
  );
}

/// Figma 56535:6469 — the request is sent and nothing has answered yet.
/// Shares the request-feed header with the broadcasting state (the centred
@JeebPreview(
  group: 'chat',
  name: 'Client · sending initial request',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenClientSending() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.clientSending,
    );

/// Figma 56535:6659 — offers are landing, and the most content this screen can
/// produce.
@JeebPreview(
  group: 'chat',
  name: 'Client · broadcasting offers',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenClientBroadcasting() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.clientBroadcasting,
    );

/// Figma 56546:2382 — the accepted 1:1 thread.
/// The selector flips the phase to `accepted` and the header name from the
@JeebPreview(
  group: 'chat',
  name: 'Client · accepted thread',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenClientAccepted() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.clientAccepted,
    );

/// The silent fallback, previewed on purpose.
/// `accepted-thread` is not a selector this screen knows. It renders anyway —
@JeebPreview(
  group: 'chat',
  name: 'Unrecognised selector · silent fallback',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenUnrecognisedSelector() =>
    _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.unrecognised,
    );

/// Figma 56539:906 — the Jeeber's side of the same thread.
/// The leg that carries the balance-deduction banner and the price/time
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · accepted thread',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenJeeberAccepted() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberAccepted,
    );

/// Figma 56560:1605 — the fee banner's trailing slot becomes an "Order picked"
/// pill.
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · order picked',
  size: _devChatPreviewScreenPhoneBox,
  matrix: true,
)
Widget devChatPreviewScreenJeeberOrderPicked() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberOrderPicked,
    );

/// Figma 56618:2751 — the confirm-picking sheet, auto-opened over the thread.
/// The composition only this screen produces, and the second matrix card: the
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · confirm picking sheet',
  size: _devChatPreviewScreenPhoneBox,
  matrix: true,
)
Widget devChatPreviewScreenJeeberConfirmPicking() =>
    _devChatPreviewScreenSheetHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberConfirmPicking,
    );

/// Figma 56618:2852 — the heading-off sheet, auto-opened over the thread.
/// Worth its own card precisely because it looks almost identical to the
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · confirm heading-off sheet',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenJeeberConfirmHeadingOff() =>
    _devChatPreviewScreenSheetHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberConfirmHeadingOff,
    );

/// The same order-picked state on the 320x568 floor.
/// The Jeeber leg stacks the most non-flexible chrome of any state here — fee
@JeebPreview(
  group: 'chat',
  name: 'Compact 320 pt · jeeber order picked',
  size: _devChatPreviewScreenCompactBox,
)
Widget devChatPreviewScreenCompactJeeber() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberOrderPicked,
      box: _devChatPreviewScreenCompactBox,
    );
