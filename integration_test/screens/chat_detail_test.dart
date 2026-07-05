// Isolated native UI test — chat-detail (order-chat). ChatDetailScreen self-
// resolves its gateway through DI (GetIt/Dio) with no cubit seam, so — exactly
// like the ChatScreen widget tests (test/features/chat/chat_screen_m1plus_widget_test.dart)
// — we pump the ChatScreen it wraps directly with a seeded ChatCubit over an
// inline fake gateway. That renders a POPULATED accepted 1:1 thread (bubbles +
// accepted banner + composer) deterministically, in any build mode, with no
// network/DI and no pending timers (subscribe returns an empty stream; the
// in-memory gateway does not poll).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import '../support/screen_harness.dart';

/// In-memory gateway serving a fixed accepted thread. No polling, empty event
/// stream — the on-device binding is left with zero pending timers.
class _SeededChatGateway extends ChatGateway {
  _SeededChatGateway(this._history, this._phase);

  final List<DeliveryChatMessage> _history;
  final ConversationPhase _phase;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      List.of(_history);

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async => _phase;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}

/// A populated, accepted 1:1 conversation: an incoming + outgoing bubble and the
/// system `offerAccepted` marker so the OfferAcceptedBanner + composer render.
List<DeliveryChatMessage> _acceptedThread() => [
      DeliveryChatMessage.text(
        id: 'm-1',
        author: ChatAuthor.them,
        sentAt: DateTime.utc(2026, 5, 17, 12, 0),
        status: MessageStatus.delivered,
        text: 'Hi, I can bring your order in about 20 minutes.',
      ),
      DeliveryChatMessage.text(
        id: 'm-2',
        author: ChatAuthor.me,
        sentAt: DateTime.utc(2026, 5, 17, 12, 1),
        status: MessageStatus.read,
        text: 'Great, thank you Kamal!',
      ),
      DeliveryChatMessage.offerAccepted(
        id: 'sys-1',
        sentAt: DateTime.utc(2026, 5, 17, 12, 2),
        payload: const SystemOfferPayload(
          offerId: 'offer-1',
          jeeberId: 'jeeber-kamal',
          jeeberName: 'Kamal Hajj',
        ),
      ),
    ];

Future<ChatCubit> _seededCubit() async {
  final cubit = ChatCubit(
    deliveryId: 'DLV-1',
    gateway: _SeededChatGateway(_acceptedThread(), ConversationPhase.accepted),
    pickerService: StubPhotoPickerService(),
  );
  // The ChatScreen(cubit:) path does NOT call load(); seed the thread before we
  // pump so the populated timeline is on-screen at first frame.
  await cubit.load();
  return cubit;
}

Widget _chat(ChatCubit cubit) => ChatScreen(
      deliveryId: 'DLV-1',
      counterpartName: 'Kamal Hajj',
      cubit: cubit,
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat-detail: populated accepted thread (en)', (tester) async {
    final cubit = await _seededCubit();
    addTearDown(cubit.close);
    await pumpAndShoot(tester, binding, _chat(cubit), 'chat-detail__populated');
  });

  testWidgets('chat-detail: populated accepted thread (ar)', (tester) async {
    final cubit = await _seededCubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _chat(cubit),
      'chat-detail__populated-ar',
      locale: const Locale('ar'),
    );
  });
}
