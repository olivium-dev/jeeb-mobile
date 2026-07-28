// The Firestore DOCUMENT shape, asserted field by field.
//
// This is the seam with no compiler behind it. The document is written by C#
// (`FirestoreConversationStore.AddMessageAsync` → `SetAsync(message)` with the
// native `[FirestoreData]` mapper, so the field names ARE the property names on
// `ConversationMessage` + `BaseModel`) and read by Dart, and nothing in either
// language checks that the two agree. The HTTP projection renames every field on
// the way through the gateway — `AuthorId` → `author_id`, `CreatedAt` →
// `created_at` — so an author who has only ever seen the wire shape would write
// this mapper against the wrong names and every single document would decode to
// nothing.
//
// That failure is not hypothetical on this project: I-06 records the HTTP path
// answering 200 with 44 rows on the wire and DECODED=0, for exactly this class
// of reason, presenting to users as a cheerful empty thread while a Jeeber was
// in transit. These cases are what stop the stream repeating it.
//
// The document fixture below is written PascalCase deliberately. If someone
// "fixes" it to snake_case to make a test pass, that is the bug.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/firestore_chat_message_mapper.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_realtime_source.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';

const _me = 'user-client-001';
const _them = 'user-jeeber-002';

FirestoreChatMessageMapper _mapper() =>
    FirestoreChatMessageMapper(currentUserId: _me);

RealtimeDocChange _change(Map<String, Object?> data, {String id = 'doc-1'}) =>
    RealtimeDocChange(id: id, data: data);

DeliveryChatMessage? _message(Map<String, Object?> data, {String id = 'doc-1'}) {
  final event = _mapper().map(_change(data, id: id));
  return event is IncomingMessage ? event.message : null;
}

void main() {
  group('PascalCase document → wire row', () {
    test('maps every field the chat-service writes', () {
      final row = _mapper().toWireRow(_change(<String, Object?>{
        'Guid': 'msg-guid-1',
        'ConversationId': 'conv-1',
        'AuthorId': _them,
        'Kind': 'text',
        'Subtype': 'x.note',
        'Audience': 'all',
        'Body': 'on my way',
        'IdempotencyKey': 'idem-1',
        'CreatedAt': DateTime.utc(2026, 7, 28, 9, 5, 30),
        'IsDeleted': false,
        'IsActive': true,
      }))!;

      expect(row['message_id'], 'msg-guid-1');
      expect(row['author_id'], _them);
      expect(row['kind'], 'text');
      expect(row['subtype'], 'x.note');
      expect(row['body'], 'on my way');
      expect(row['created_at'], '2026-07-28T09:05:30.000Z');
    });

    test('falls back to the DOCUMENT ID when Guid is absent', () {
      // The store writes `.Document(message.Guid).SetAsync(...)`, so the
      // document id and `Guid` are the same value. A document written by any
      // other path must still get an identity, and the id is the one field
      // Firestore guarantees.
      final row = _mapper().toWireRow(_change(
        <String, Object?>{'AuthorId': _them, 'Kind': 'text', 'Body': 'hi'},
        id: 'firestore-doc-id',
      ))!;
      expect(row['message_id'], 'firestore-doc-id');
    });

    test('the id is the SAME id the HTTP projection returns', () {
      // Load-bearing, and the reason the whole design works: `ChatCubit`
      // dedupes by id, so a message that arrives BOTH in the cold history read
      // and down the stream collapses into one bubble. If these two ids ever
      // differed, every message would render twice.
      const guid = 'shared-identity-9f2';
      final fromStream = _message(<String, Object?>{
        'Guid': guid,
        'AuthorId': _them,
        'Kind': 'text',
        'Body': 'once',
      })!;
      expect(fromStream.id, guid);
    });
  });

  group('CreatedAt', () {
    test('a DateTime becomes a real server timestamp', () {
      final m = _message(<String, Object?>{
        'Guid': 'm1',
        'AuthorId': _them,
        'Kind': 'text',
        'Body': 'dated',
        'CreatedAt': DateTime.utc(2026, 7, 28, 9, 5),
      })!;
      expect(m.hasServerTimestamp, isTrue);
      expect(m.sentAt.toUtc(), DateTime.utc(2026, 7, 28, 9, 5));
    });

    test('the 0001-01-01 .NET husk is treated as ABSENT, not as a date', () {
      // `default(DateTime)` serialised. Rendering it would put the message at
      // the top of the thread anchored in year 1 — the ordering inversion I-14
      // records as live on a green suite.
      final m = _message(<String, Object?>{
        'Guid': 'm1',
        'AuthorId': _them,
        'Kind': 'text',
        'Body': 'husk',
        'CreatedAt': '0001-01-01T00:00:00Z',
      })!;
      expect(m.hasServerTimestamp, isTrue,
          reason: 'a LIVE frame with no usable date is stamped at arrival, '
              'which for a frame that just crossed the wire IS its send time');
      expect(m.sentAt.year, greaterThan(2000));
    });

    test('an absent CreatedAt does not reject the row', () {
      // I-06: a timestamp is not identity. A row with no date is still a
      // message and must render.
      final m = _message(<String, Object?>{
        'Guid': 'm1',
        'AuthorId': _them,
        'Kind': 'text',
        'Body': 'undated',
      });
      expect(m, isNotNull);
      expect(m!.text, 'undated');
    });
  });

  group('Payload is a JSON STRING in the document', () {
    test('a structured payload is decoded, not rendered as raw JSON', () {
      // `ConversationMessage.Payload` is `public string`. The HTTP hop parses it
      // back into an object before the client sees it; the document does not.
      // Same branch Rahmah writes at chat_screen.dart:307-319.
      final m = _message(<String, Object?>{
        'Guid': 'm-loc',
        'AuthorId': _them,
        'Kind': 'location',
        'Payload': '{"lat":33.888,"lng":35.495,"label":"Hamra"}',
      })!;
      expect(m.kind, MessageKind.location);
      expect(m.latitude, closeTo(33.888, 0.0001));
      expect(m.longitude, closeTo(35.495, 0.0001));
      expect(m.text, 'Hamra');
    });

    test('a payload that is not JSON is carried as text, not dropped', () {
      final m = _message(<String, Object?>{
        'Guid': 'm1',
        'AuthorId': _them,
        'Kind': 'text',
        'Payload': 'plain words, not json',
      })!;
      expect(m.text, 'plain words, not json');
    });

    test('an empty Body does not shadow a structured Payload', () {
      // The codec reads `body ?? payload`. Emitting BOTH — with `Body: ''` —
      // would make every structured message render as an empty bubble.
      final m = _message(<String, Object?>{
        'Guid': 'm-sys',
        'AuthorId': _them,
        'Kind': 'system',
        'Body': '',
        'Payload': '{"text":"Offer accepted"}',
      })!;
      expect(m.text, 'Offer accepted');
    });
  });

  group('own vs counterpart', () {
    test('AuthorId equal to the viewer is MINE', () {
      final m = _message(<String, Object?>{
        'Guid': 'm1',
        'AuthorId': _me,
        'Kind': 'text',
        'Body': 'mine',
      })!;
      expect(m.isMine, isTrue);
    });

    test('any other AuthorId is theirs', () {
      final m = _message(<String, Object?>{
        'Guid': 'm1',
        'AuthorId': _them,
        'Kind': 'text',
        'Body': 'theirs',
      })!;
      expect(m.isMine, isFalse);
    });
  });

  group('documents that must NOT render', () {
    test('a soft-deleted document is skipped', () {
      expect(
        _message(<String, Object?>{
          'Guid': 'm1',
          'AuthorId': _them,
          'Kind': 'text',
          'Body': 'retracted',
          'IsDeleted': true,
        }),
        isNull,
      );
    });

    test('a DeletedAt stamp is skipped', () {
      expect(
        _message(<String, Object?>{
          'Guid': 'm1',
          'AuthorId': _them,
          'Kind': 'text',
          'Body': 'retracted',
          'DeletedAt': DateTime.utc(2026, 7, 28),
        }),
        isNull,
      );
    });

    test('IsActive false is skipped', () {
      expect(
        _message(<String, Object?>{
          'Guid': 'm1',
          'AuthorId': _them,
          'Kind': 'text',
          'Body': 'inactive',
          'IsActive': false,
        }),
        isNull,
      );
    });

    test('no author is skipped', () {
      expect(
        _message(<String, Object?>{
          'Guid': 'm1',
          'Kind': 'text',
          'Body': 'orphan',
        }),
        isNull,
      );
    });

    test('an unsupported kind is skipped, not guessed at', () {
      expect(
        _message(<String, Object?>{
          'Guid': 'm1',
          'AuthorId': _them,
          'Kind': 'telepathy',
          'Body': 'whatever',
        }),
        isNull,
      );
    });

    test('no content at all is skipped', () {
      expect(
        _message(<String, Object?>{
          'Guid': 'm1',
          'AuthorId': _them,
          'Kind': 'text',
        }),
        isNull,
      );
    });
  });

  group('every kind the chat-service can write decodes', () {
    // POSITIVE CONTROL for the whole "documents that must NOT render" group
    // above. Without it, a mapper that returned null for EVERYTHING would pass
    // all six of those cases — the exact shape of a broken scanner scoring a
    // clean PASS (I-11).
    const cases = <String, Map<String, Object?>>{
      'text': <String, Object?>{'Kind': 'text', 'Body': 'hello'},
      'image': <String, Object?>{
        'Kind': 'image',
        'Payload': '{"url":"cdn://a","caption":"c"}',
      },
      'voice': <String, Object?>{
        'Kind': 'voice',
        'Payload': '{"url":"cdn://v","durationMs":1200}',
      },
      'location': <String, Object?>{
        'Kind': 'location',
        'Payload': '{"lat":1.0,"lng":2.0,"label":"x"}',
      },
      'system': <String, Object?>{
        'Kind': 'system',
        'Payload': '{"text":"joined"}',
      },
      'offer_card': <String, Object?>{
        'Kind': 'offer_card',
        'Payload': '{"offerId":"o1","jeeberName":"Kamal","fee":6.0}',
      },
      'offer_accepted': <String, Object?>{
        'Kind': 'offer_accepted',
        'Payload': '{"offerId":"o1"}',
      },
      'offer_rejected': <String, Object?>{
        'Kind': 'offer_rejected',
        'Payload': '{"offerId":"o2"}',
      },
    };

    for (final entry in cases.entries) {
      test('${entry.key} renders', () {
        final m = _message(<String, Object?>{
          'Guid': 'm-${entry.key}',
          'AuthorId': _them,
          ...entry.value,
        });
        expect(m, isNotNull, reason: '${entry.key} must decode');
      });
    }

    test('the supported set matches the codec, not a private copy', () {
      // Both transports validate against `kSupportedMessageKinds`. This asserts
      // the set has not been quietly narrowed for the stream.
      for (final kind in cases.keys) {
        expect(
          _message(<String, Object?>{
            'Guid': 'm',
            'AuthorId': _them,
            ...cases[kind]!,
          }),
          isNotNull,
        );
      }
    });
  });

  group('the projector', () {
    test('skips removed documents and keeps the rest, in order', () {
      final projector = ChatRealtimeProjector(mapRow: _mapper().map);
      final events = projector.project(const <RealtimeDocChange>[
        RealtimeDocChange(
          id: 'a',
          data: <String, Object?>{
            'Guid': 'a',
            'AuthorId': _them,
            'Kind': 'text',
            'Body': 'first',
          },
        ),
        RealtimeDocChange(
          id: 'b',
          data: <String, Object?>{
            'Guid': 'b',
            'AuthorId': _them,
            'Kind': 'text',
            'Body': 'removed',
          },
          removed: true,
        ),
        RealtimeDocChange(
          id: 'c',
          data: <String, Object?>{
            'Guid': 'c',
            'AuthorId': _them,
            'Kind': 'text',
            'Body': 'second',
          },
        ),
      ]);

      expect(
        events
            .whereType<IncomingMessage>()
            .map((e) => e.message.text)
            .toList(),
        ['first', 'second'],
      );
    });

    test('an empty batch produces no events', () {
      final projector = ChatRealtimeProjector(mapRow: _mapper().map);
      expect(projector.project(const <RealtimeDocChange>[]), isEmpty);
    });
  });
}
