// b02 fg-suppression — the decision table for "may this foreground push
// interrupt the user?".
//
// Two owner requirements collide in this one predicate and BOTH must hold:
//   (a) a SILENT/refresh push produces NO shade entry, foreground included;
//   (b) a CHAT message for a thread the user is NOT viewing MUST still show,
//       foreground included ("whether the app is in forground or background or
//       even closed").
// So the condition is NOT `!silent`. Every group below exists to pin one row of
// that table, and the `NEGATIVE CONTROL` group exists so a blanket-suppression
// regression cannot make this file pass for the wrong reason.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/domain/foreground_push_display.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

Map<String, String> _chat({
  String? conversationId,
  String? requestId,
  String? silent,
}) =>
    <String, String>{
      'type': 'chat',
      'conversationId': ?conversationId,
      'requestId': ?requestId,
      'silent': ?silent,
    };

bool _show(
  Map<String, String> data, {
  NotificationCategory category = NotificationCategory.chat,
  Set<String> open = const <String>{},
}) =>
    shouldShowForegroundPush(
      category: category,
      data: data,
      openChatThreadIds: open,
    );

void main() {
  group('isSilentPush — mirrors the push service\'s _SILENT_FALSE_STRINGS', () {
    // The service ships `data = {k: str(v) for ...}`, so a Python `True`
    // arrives as the STRING "True". Getting the casing wrong here is the
    // difference between a silent push and a buzz.
    for (final truthy in <String>['True', 'true', 'TRUE', '1', 'yes', 'on']) {
      test('"$truthy" is silent', () {
        expect(isSilentPush(<String, String>{'silent': truthy}), isTrue);
      });
    }

    for (final falsey in <String>[
      'False',
      'false',
      '0',
      'no',
      'off',
      'null',
      'none',
      '',
      '   ',
    ]) {
      test('"$falsey" is NOT silent', () {
        expect(isSilentPush(<String, String>{'silent': falsey}), isFalse);
      });
    }

    test('an ABSENT silent key is NOT silent (fails closed)', () {
      // Every push that predates the silent switch lands here. None may go
      // quiet.
      expect(isSilentPush(const <String, String>{'type': 'chat'}), isFalse);
    });
  });

  group('silent suppresses regardless of category or open thread', () {
    test('silent newRequest (a refresh push) does not show', () {
      expect(
        _show(
          <String, String>{'type': 'new_request', 'silent': 'True'},
          category: NotificationCategory.newRequest,
        ),
        isFalse,
      );
    });

    test('silent delivery (a refresh push) does not show', () {
      expect(
        _show(
          <String, String>{'type': 'delivery', 'silent': 'true'},
          category: NotificationCategory.delivery,
        ),
        isFalse,
      );
    });

    test('a silent CHAT push does not show even for a closed thread', () {
      expect(
        _show(_chat(conversationId: 'conv-1', silent: 'true'), open: const {}),
        isFalse,
      );
    });
  });

  group('chat — suppress ONLY the thread that is on screen', () {
    test('open thread matched by conversationId ⇒ suppressed', () {
      expect(
        _show(_chat(conversationId: 'conv-1'), open: {'conv-1'}),
        isFalse,
      );
    });

    test('open thread matched by requestId ⇒ suppressed', () {
      // `/chat/:id` may have been opened with the REQUEST id while the push
      // carries the conversation id, and vice versa. Either id identifies the
      // same thread.
      expect(
        _show(
          _chat(conversationId: 'conv-1', requestId: 'req-1'),
          open: {'req-1'},
        ),
        isFalse,
      );
    });

    test(
      'DIFFERENT thread open ⇒ SHOWS (the owner requirement, foreground)',
      () {
        expect(
          _show(_chat(conversationId: 'conv-2'), open: {'conv-1'}),
          isTrue,
        );
      },
    );

    test('no chat open at all ⇒ SHOWS', () {
      expect(_show(_chat(conversationId: 'conv-1')), isTrue);
    });

    test(
      'chat push carrying NO usable thread id ⇒ SHOWS even with a thread open',
      () {
        // Unidentifiable must never be silenced: a spurious banner is
        // recoverable, a swallowed message is the failure the owner called out.
        expect(
          _show(const <String, String>{'type': 'chat'}, open: {'conv-1'}),
          isTrue,
        );
      },
    );
  });

  group('NEGATIVE CONTROL — the suppression is not blanket', () {
    // If these ever go false the suppression has inverted into "hide
    // everything", and every test above would still pass.
    test('a normal visible chat push shows', () {
      expect(_show(_chat(conversationId: 'conv-9')), isTrue);
    });

    for (final category in <NotificationCategory>[
      NotificationCategory.delivery,
      NotificationCategory.kyc,
      NotificationCategory.rating,
      NotificationCategory.newRequest,
      NotificationCategory.newOffer,
      NotificationCategory.offerAccepted,
      NotificationCategory.offerLost,
      NotificationCategory.requestExpired,
      NotificationCategory.settings,
      NotificationCategory.other,
    ]) {
      test(
        'a NON-silent ${category.name} push shows even while a chat is open',
        () {
          // A chat thread being on screen must not silence unrelated traffic —
          // the open-thread rule is scoped to the chat category alone.
          expect(
            _show(
              <String, String>{'requestId': 'conv-1'},
              category: category,
              open: {'conv-1'},
            ),
            isTrue,
          );
        },
      );
    }
  });
}
