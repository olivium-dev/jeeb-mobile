import 'package:flutter/material.dart';

import '../data/dev_chat_fixture_gateway.dart';
import '../domain/delivery_chat_message.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import 'chat_screen.dart';

/// Debug-only full-screen host that renders [ChatScreen] for one of the two
/// designed client chat states, backed by [DevChatFixtureGateway].
///
/// Reached only via the router's `JEEB_DEV_CHAT` seam (see `AppRouter`), which
/// extends the established `JEEB_DEV_*` dart-define pattern (pilot learning
/// #1) so the two Figma chat frames (nodes 56535:6659 / 56546:2382) can be
/// captured deterministically on the emulator. Never reachable in release.
class DevChatPreviewScreen extends StatelessWidget {
  const DevChatPreviewScreen({super.key, required this.selector});

  /// `broadcasting` → Figma 02, anything else → `accepted` → Figma 03.
  final String selector;

  @override
  Widget build(BuildContext context) {
    final broadcasting = selector == 'broadcasting';
    final phase = broadcasting
        ? ConversationPhase.broadcasting
        : ConversationPhase.accepted;
    return ChatScreen(
      deliveryId: 'dev-chat',
      counterpartName: broadcasting ? 'ORD-23748' : 'Kamal Hajj',
      gateway: DevChatFixtureGateway(phase: phase),
      pickerService: StubPhotoPickerService(),
    );
  }
}
