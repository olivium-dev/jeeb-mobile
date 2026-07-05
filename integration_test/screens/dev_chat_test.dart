// Isolated native UI test — dev-chat (DevChatPreviewScreen). The debug-only
// preview host builds ChatScreen over an in-memory DevChatFixtureGateway that
// seeds one of the designed Figma chat states, so we pump it directly per
// selector. The gateway drives its own (empty) broadcast stream and does not
// poll, so there are no pending timers. We avoid the `dm-confirm-*` selectors
// (they auto-open a modal sheet) and screenshot the three static threads.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/dev_chat_preview_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dev-chat: broadcasting offers feed (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const DevChatPreviewScreen(selector: 'broadcasting'),
      'dev-chat__broadcasting',
    );
  });

  testWidgets('dev-chat: accepted client thread (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const DevChatPreviewScreen(selector: 'accepted'),
      'dev-chat__accepted',
    );
  });

  testWidgets('dev-chat: delivery-man thread (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const DevChatPreviewScreen(selector: 'dm'),
      'dev-chat__delivery-man',
    );
  });
}
