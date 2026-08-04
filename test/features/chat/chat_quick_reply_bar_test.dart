/// redesign-2026-08 screen 21 — the quick-reply row.
///
/// The row is a NET-NEW affordance whose pill LABEL is the message it sends,
/// so the gate is the subject of this file as much as the send is: three of the
/// four states in which it must NOT appear are states where a one-tap canned
/// line would do real damage or speak in the wrong voice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_redesign_l10n.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import 'chat_header_support.dart';

const _row = 'order_chat_quick_reply_row';

Future<void> _pump(
  WidgetTester tester, {
  ConversationPhase phase = ConversationPhase.accepted,
  bool viewerIsJeeber = false,
  Future<bool> Function(String, String)? onFirstMessageBroadcast,
  Locale locale = const Locale('en'),
}) async {
  final gateway = FakeChatGateway(phase: phase, history: sampleThread());
  addTearDown(gateway.dispose);
  await tester.pumpWidget(themedHost(
    ChatScreen(
      deliveryId: 'd-1',
      counterpartName: 'Karim',
      gateway: gateway,
      pickerService: StubPhotoPickerService(),
      viewerIsJeeber: viewerIsJeeber,
      onFirstMessageBroadcast: onFirstMessageBroadcast,
    ),
    locale: locale,
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadArb);

  group('when the row renders', () {
    testWidgets('the accepted CLIENT thread shows all three pills',
        (tester) async {
      await _pump(tester);

      expect(find.bySemanticsIdentifier(_row), findsOneWidget);
      for (final id in const [
        'order_chat_quick_reply_home',
        'order_chat_quick_reply_door',
        'order_chat_quick_reply_thanks',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
    });

    testWidgets('the Arabic pill renders un-mirrored inside an English thread',
        (tester) async {
      // The row deliberately mixes scripts and is never force-LTR; this is the
      // screen-level smoke over the kit's own widget-level RTL coverage.
      await _pump(tester);

      const l10n = ChatRedesignL10n(isArabic: false);
      expect(find.text(l10n.quickReplyThanks), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.text(l10n.quickReplyThanks)),
        ),
        TextDirection.ltr,
        reason: 'the row inherits the thread direction; the LABEL shapes '
            'itself — nothing forces a direction on it',
      );
    });
  });

  group('when the row must NOT render', () {
    testWidgets('the JEEBER leg — the canned lines are client-voice',
        (tester) async {
      await _pump(tester, viewerIsJeeber: true);
      expect(find.bySemanticsIdentifier(_row), findsNothing);
    });

    testWidgets('the broadcasting phase — there is no counterpart yet',
        (tester) async {
      await _pump(tester, phase: ConversationPhase.broadcasting);
      expect(find.bySemanticsIdentifier(_row), findsNothing);
    });

    testWidgets(
        'the COMPOSE state — a tapped pill would become the request itself',
        (tester) async {
      // Load-bearing, not cosmetic: in compose the first outgoing message
      // broadcasts the request AND becomes its description, so a one-tap "I'm
      // home" would create a request described "I'm home".
      await _pump(
        tester,
        onFirstMessageBroadcast: (_, _) async => true,
      );
      expect(find.bySemanticsIdentifier(_row), findsNothing);
    });
  });

  testWidgets('tapping a pill sends exactly one message and leaves the '
      'composer empty', (tester) async {
    await _pump(tester);
    const l10n = ChatRedesignL10n(isArabic: false);

    final ChatCubit cubit = BlocProvider.of<ChatCubit>(
      tester.element(find.bySemanticsIdentifier(_row)),
    );
    final before = cubit.state.messages.length;

    await tester.tap(find.bySemanticsIdentifier('order_chat_quick_reply_home'));
    await tester.pumpAndSettle();

    final mine = cubit.state.messages
        .where((m) => m.isMine && m.text == l10n.quickReplyImHome);
    expect(mine, hasLength(1), reason: 'one tap is one message, never two');
    expect(cubit.state.messages.length, before + 1);
    expect(
      cubit.state.composerText,
      isEmpty,
      reason: 'the canned line must not be left sitting in the input',
    );
  });

  group('ChatCubit.sendQuickReply', () {
    test('appends one outgoing text and clears the composer', () async {
      final gateway = FakeChatGateway(phase: ConversationPhase.accepted);
      addTearDown(gateway.dispose);
      final cubit = ChatCubit(
        deliveryId: 'd-1',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
      );
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.sendQuickReply("I'm home");

      expect(cubit.state.messages, hasLength(1));
      expect(cubit.state.messages.single.text, "I'm home");
      expect(cubit.state.messages.single.isMine, isTrue);
      expect(cubit.state.messages.single.kind, MessageKind.text);
      expect(cubit.state.composerText, isEmpty);
    });
  });
}
