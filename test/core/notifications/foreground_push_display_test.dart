// b02 fg-suppression — the decision table for "may this foreground push

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
  Set<String>? roles,
}) =>
    shouldShowForegroundPush(
      category: category,
      data: data,
      openChatThreadIds: open,
      localRoles: roles,
    );

void main() {
  group('isSilentPush — mirrors the push service\'s _SILENT_FALSE_STRINGS', () {
    // The service ships `data = {k: str(v) for ...}`, so a Python `True`
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
        expect(
          _show(const <String, String>{'type': 'chat'}, open: {'conv-1'}),
          isTrue,
        );
      },
    );
  });

  group('audience gate — reuses isPushAudienceMatch, fails open', () {
    const driverNewRequest = <String, String>{
      'type': 'new_request',
      'requestId': 'req-1',
      'audience_role': 'driver',
    };

    test('client-only roles + audience_role=driver ⇒ suppressed', () {
      expect(
        _show(
          driverNewRequest,
          category: NotificationCategory.newRequest,
          roles: const {'client'},
        ),
        isFalse,
      );
    });

    test('jeeber roles ⇒ shows (driver canonicalises to jeeber)', () {
      expect(
        _show(
          driverNewRequest,
          category: NotificationCategory.newRequest,
          roles: const {'jeeber'},
        ),
        isTrue,
      );
    });

    test('dual-role ⇒ shows', () {
      expect(
        _show(
          driverNewRequest,
          category: NotificationCategory.newRequest,
          roles: const {'client', 'jeeber'},
        ),
        isTrue,
      );
    });

    test('null roles (no resolver wired) ⇒ shows — behaviour unchanged', () {
      expect(
        _show(driverNewRequest, category: NotificationCategory.newRequest),
        isTrue,
      );
    });

    test('EMPTY roles ⇒ shows (matcher fails open on unknown roles)', () {
      expect(
        _show(
          driverNewRequest,
          category: NotificationCategory.newRequest,
          roles: const <String>{},
        ),
        isTrue,
      );
    });

    test('no audience key ⇒ shows for any roles (fails open)', () {
      expect(
        _show(
          const <String, String>{'type': 'new_request', 'requestId': 'r'},
          category: NotificationCategory.newRequest,
          roles: const {'client'},
        ),
        isTrue,
      );
    });

    test('a matching audience does NOT bypass the silent gate', () {
      expect(
        _show(
          const <String, String>{
            'type': 'new_request',
            'silent': 'True',
            'audience_role': 'driver',
          },
          category: NotificationCategory.newRequest,
          roles: const {'jeeber'},
        ),
        isFalse,
      );
    });

    test('audience mismatch also gates a chat push (category-independent)', () {
      expect(
        _show(_chat(conversationId: 'conv-1'), roles: const {'jeeber'}),
        isTrue,
        reason: 'no audience key on the chat payload ⇒ untouched',
      );
      expect(
        _show(
          <String, String>{
            ..._chat(conversationId: 'conv-1'),
            'audience_role': 'client',
          },
          roles: const {'jeeber'},
        ),
        isFalse,
      );
    });
  });

  group('NEGATIVE CONTROL — the suppression is not blanket', () {
    // If these ever go false the suppression has inverted into "hide
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
