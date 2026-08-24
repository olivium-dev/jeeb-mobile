import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/domain/notification_deep_link.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';

NotificationMessage _msg({
  required NotificationCategory category,
  Map<String, String> data = const {},
}) {
  return NotificationMessage(
    id: 'm-1',
    category: category,
    title: 't',
    body: 'b',
    receivedAt: DateTime.utc(2026, 5, 17),
    data: data,
  );
}

void main() {
  group('deepLinkForMessage', () {
    test('delivery routes to /orders/<delivery_id>', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.delivery,
          data: const {'delivery_id': 'd-42'},
        ),
      );
      expect(path, '/orders/d-42');
    });

    test('delivery falls back to order_id when delivery_id is missing', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.delivery,
          data: const {'order_id': 'o-9'},
        ),
      );
      expect(path, '/orders/o-9');
    });

    test('delivery without any id returns null (no crash)', () {
      final path = deepLinkForMessage(
        _msg(category: NotificationCategory.delivery),
      );
      expect(path, isNull);
    });

    test('delivery (not offer) with ONLY requestId still routes to '
        '/orders/<requestId> (delivery id == request id)', () {
      // A real `type=delivery` push can carry ONLY `requestId` — no
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.delivery,
          data: const {'requestId': 'req-77'},
        ),
      );
      expect(path, '/orders/req-77');
    });

    test('delivery uses snake_case request_id when it is the only id', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.delivery,
          data: const {'request_id': 'req-88'},
        ),
      );
      expect(path, '/orders/req-88');
    });

    test('delivery prefers an explicit delivery_id over requestId', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.delivery,
          data: const {'delivery_id': 'd-1', 'requestId': 'req-99'},
        ),
      );
      expect(path, '/orders/d-1');
    });

    test('chat routes to /chat/<id>', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.chat,
          data: const {'chat_id': 'c-1'},
        ),
      );
      expect(path, '/chat/c-1');
    });

    test('chat prefers requestId over conversationId (correlationKey == '
        'request id, so the GET /v1/conversations?correlationKey lookup '
        'resolves 200 instead of 404)', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.chat,
          data: const {
            'conversationId': 'conv-abc',
            'requestId': 'req-xyz',
            'type': 'chat',
          },
        ),
      );
      expect(path, '/chat/req-xyz');
    });

    test('chat uses snake_case request_id when present', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.chat,
          data: const {'conversation_id': 'conv-1', 'request_id': 'req-1'},
        ),
      );
      expect(path, '/chat/req-1');
    });

    test(
      'chat falls back to conversationId when no request id is present '
      '(the chat-detail messages probe then resolves it — no regression)',
      () {
        final path = deepLinkForMessage(
          _msg(
            category: NotificationCategory.chat,
            data: const {'conversationId': 'conv-only'},
          ),
        );
        expect(path, '/chat/conv-only');
      },
    );

    test('chat without any id returns null (no crash)', () {
      final path = deepLinkForMessage(
        _msg(category: NotificationCategory.chat),
      );
      expect(path, isNull);
    });

    test('kyc routes to /profile/kyc regardless of payload', () {
      final path = deepLinkForMessage(_msg(category: NotificationCategory.kyc));
      expect(path, '/profile/kyc');
    });

    test('rating routes to /orders/<id>/rate', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.rating,
          data: const {'delivery_id': 'd-77'},
        ),
      );
      expect(path, '/orders/d-77/rate');
    });

    test('settings routes to /settings/notifications', () {
      final path = deepLinkForMessage(
        _msg(category: NotificationCategory.settings),
      );
      expect(path, '/settings/notifications');
    });

    test('other category returns null (banner with no destination)', () {
      final path = deepLinkForMessage(
        _msg(category: NotificationCategory.other),
      );
      expect(path, isNull);
    });

    test('new_request routes to /jeeber/requests/<requestId>', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.newRequest,
          data: const {'requestId': 'req-1'},
        ),
      );
      expect(path, '/jeeber/requests/req-1');
    });

    test('new_request uses snake_case request_id when it is the only id', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.newRequest,
          data: const {'request_id': 'req-1'},
        ),
      );
      expect(path, '/jeeber/requests/req-1');
    });

    test('new_request without any id returns null (no crash)', () {
      final path = deepLinkForMessage(
        _msg(category: NotificationCategory.newRequest),
      );
      expect(path, isNull);
    });

    test('offer_accepted routes to the jeeber ACTIVE-DELIVERY screen for the '
        'won request (run-23 CHECK B fix: NOT the pending-offers list, which '
        'is empty once the offer is decided)', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.offerAccepted,
          data: const {'offerId': 'off-1', 'requestId': 'req-1'},
        ),
      );
      expect(path, '/jeeber/deliveries/req-1/active');
    });

    test('offer_accepted uses snake_case request_id when it is the only id '
        '(gateway carries both variants)', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.offerAccepted,
          data: const {'request_id': 'req-2', 'offerId': 'off-1'},
        ),
      );
      expect(path, '/jeeber/deliveries/req-2/active');
    });

    test(
      'offer_accepted prefers an explicit delivery id over the request id',
      () {
        expect(
          deepLinkForMessage(
            _msg(
              category: NotificationCategory.offerAccepted,
              data: const {'delivery_id': 'd-1', 'requestId': 'req-1'},
            ),
          ),
          '/jeeber/deliveries/d-1/active',
        );
        expect(
          deepLinkForMessage(
            _msg(
              category: NotificationCategory.offerAccepted,
              data: const {'deliveryId': 'd-2', 'requestId': 'req-1'},
            ),
          ),
          '/jeeber/deliveries/d-2/active',
        );
      },
    );

    test('offer_accepted does NOT route on the offerId alone — the active '
        'delivery is keyed by request/delivery id, not offer id', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.offerAccepted,
          data: const {'offerId': 'off-9'},
        ),
      );
      expect(path, '/jeeber/pending-offers');
    });

    test('offer_accepted WITHOUT any id still routes (pending-offers '
        'last-resort — never a silent no-op)', () {
      expect(
        deepLinkForMessage(_msg(category: NotificationCategory.offerAccepted)),
        '/jeeber/pending-offers',
      );
    });

    test('offer_lost routes to the shell feed — NOT pending-offers (empty '
        'once decided) and NOT /jeeber/requests/:id (its accepted-delivery '
        'probe would redirect the LOSER into the winner\'s delivery)', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.offerLost,
          data: const {'offerId': 'off-1', 'requestId': 'req-1'},
        ),
      );
      expect(path, '/');
    });

    test('offer_lost routes even WITHOUT any id (constant surface, never a '
        'silent no-op)', () {
      expect(
        deepLinkForMessage(_msg(category: NotificationCategory.offerLost)),
        '/',
      );
    });

    // ---- P2 (b01-20260725) ------------------------------------------------

    // A4: the reported bug. A jeeber's BID on a customer's still-open request
    test('newOffer routes to /requests/<requestId>/offers (P2: the '
        'offer-review list, not the phantom order hub)', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.newOffer,
          data: const {'requestId': 'req-1'},
        ),
      );
      expect(path, '/requests/req-1/offers');
    });

    // A5
    test('newOffer uses snake_case request_id when it is the only id', () {
      final path = deepLinkForMessage(
        _msg(
          category: NotificationCategory.newOffer,
          data: const {'request_id': 'req-2'},
        ),
      );
      expect(path, '/requests/req-2/offers');
    });

    // A6
    test('newOffer with NO id falls back to the shell — never null, never an '
        '/orders/ path', () {
      final path = deepLinkForMessage(
        _msg(category: NotificationCategory.newOffer),
      );
      expect(path, '/');
      expect(path, isNotNull);
      expect(path!.startsWith('/orders/'), isFalse);
    });

    // A10
    test('requestExpired with NO id falls back to the shell', () {
      expect(
        deepLinkForMessage(_msg(category: NotificationCategory.requestExpired)),
        '/',
      );
    });

    test('requestExpired routes to /requests/<requestId>/waiting', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.requestExpired,
            data: const {'requestId': 'req-w'},
          ),
        ),
        '/requests/req-w/waiting',
      );
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.requestExpired,
            data: const {'request_id': 'req-w2'},
          ),
        ),
        '/requests/req-w2/waiting',
      );
    });
  });

  // F5 role guard (FIX-REQUESTS.md:35): a jeeber-scoped destination handed to a
  group('deepLinkForMessage role guard (F5)', () {
    // A11
    test('a CLIENT tapping a new_request is refused to the shell (never '
        '/jeeber/requests/:id → 403)', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.newRequest,
            data: const {'requestId': 'R'},
          ),
          role: UserRole.client,
        ),
        '/',
      );
    });

    // A12
    test('a CLIENT is refused every jeeber-scoped destination', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.offerAccepted,
            data: const {'requestId': 'R'},
          ),
          role: UserRole.client,
        ),
        '/',
      );
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.offerLost,
            data: const {'requestId': 'R'},
          ),
          role: UserRole.client,
        ),
        '/',
      );
      expect(
        deepLinkForMessage(
          _msg(category: NotificationCategory.offerAccepted),
          role: UserRole.client,
        ),
        '/',
      );
    });

    // A13a — must NOT over-refuse (plan risk R7).
    test('a JEEBER still reaches /jeeber/requests/:id', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.newRequest,
            data: const {'requestId': 'R'},
          ),
          role: UserRole.jeeber,
        ),
        '/jeeber/requests/R',
      );
    });

    // A13b — legacy role-blind behaviour for callers with no role context
    test('role: null (the default) keeps the legacy role-blind behaviour', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.newRequest,
            data: const {'requestId': 'R'},
          ),
        ),
        '/jeeber/requests/R',
      );
    });

    // A13c
    test('a JEEBER still reaches /jeeber/deliveries/:id/active', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.offerAccepted,
            data: const {'requestId': 'R'},
          ),
          role: UserRole.jeeber,
        ),
        '/jeeber/deliveries/R/active',
      );
    });

    // A13d — a client-directed target is NEVER refused.
    test('a CLIENT tapping a newOffer still reaches the offer-review list', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.newOffer,
            data: const {'requestId': 'R'},
          ),
          role: UserRole.client,
        ),
        '/requests/R/offers',
      );
    });

    // A13e
    test('a CLIENT tapping a chat still reaches /chat/:requestId', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.chat,
            data: const {'requestId': 'R'},
          ),
          role: UserRole.client,
        ),
        '/chat/R',
      );
    });

    test(
      'a CLIENT tapping a requestExpired still reaches the waiting screen',
      () {
        expect(
          deepLinkForMessage(
            _msg(
              category: NotificationCategory.requestExpired,
              data: const {'requestId': 'R'},
            ),
            role: UserRole.client,
          ),
          '/requests/R/waiting',
        );
      },
    );
  });

  group('NotificationCategory.fromKey', () {
    test('maps known keys', () {
      expect(
        NotificationCategory.fromKey('delivery'),
        NotificationCategory.delivery,
      );
      expect(NotificationCategory.fromKey('chat'), NotificationCategory.chat);
      expect(NotificationCategory.fromKey('kyc'), NotificationCategory.kyc);
      expect(
        NotificationCategory.fromKey('rating'),
        NotificationCategory.rating,
      );
      expect(
        NotificationCategory.fromKey('settings'),
        NotificationCategory.settings,
      );
      expect(
        NotificationCategory.fromKey('new_request'),
        NotificationCategory.newRequest,
      );
      expect(
        NotificationCategory.fromKey('offer_accepted'),
        NotificationCategory.offerAccepted,
      );
      expect(
        NotificationCategory.fromKey('offer_lost'),
        NotificationCategory.offerLost,
      );
    });

    test('fromData resolves the offer-lifecycle type discriminator', () {
      expect(
        NotificationCategory.fromData(const {
          'type': 'offer_accepted',
          'offerId': 'off-9',
        }),
        NotificationCategory.offerAccepted,
      );
      expect(
        NotificationCategory.fromData(const {
          'type': 'offer_lost',
          'offerId': 'off-9',
        }),
        NotificationCategory.offerLost,
      );
    });

    test('unknown / null fall back to other', () {
      expect(NotificationCategory.fromKey(null), NotificationCategory.other);
      expect(
        NotificationCategory.fromKey('marketing'),
        NotificationCategory.other,
      );
    });

    // A1 (P2): `offer` is the auction-phase new-bid event, NOT a delivery.
    test('offer maps to newOffer (P2 — no longer bucketed as delivery)', () {
      expect(
        NotificationCategory.fromKey('offer'),
        NotificationCategory.newOffer,
      );
    });

    // A2 fence: `accept` did NOT move — both still resolve to the order surface.
    test('delivery and accept both still map to delivery (fence)', () {
      expect(
        NotificationCategory.fromKey('delivery'),
        NotificationCategory.delivery,
      );
      expect(
        NotificationCategory.fromKey('accept'),
        NotificationCategory.delivery,
      );
    });

    // A3 (P2/F3): both expiry events carry a legacy `category: "delivery"`;
    test('request_expired and try_expand_tier map to requestExpired', () {
      expect(
        NotificationCategory.fromKey('request_expired'),
        NotificationCategory.requestExpired,
      );
      expect(
        NotificationCategory.fromKey('try_expand_tier'),
        NotificationCategory.requestExpired,
      );
    });
  });

  group('NotificationCategory.fromData (type-wins-over-legacy-category)', () {
    // The run-19 push-D gap: NewRequestPushNotifier fans out to the
    test('EXACT run-19 dual-stamped payload → newRequest, deep-links to the '
        'request screen (a KNOWN type wins over the legacy category)', () {
      const data = <String, String>{
        'type': 'new_request',
        'category': 'delivery',
        'requestId': 'req-run19',
        'request_id': 'req-run19',
        'tierId': 'tier-gold',
        'title': 'New request nearby',
        'body': 'A customer needs a jeeber',
      };
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.newRequest);
      expect(
        deepLinkForMessage(_msg(category: category, data: data)),
        '/jeeber/requests/req-run19',
      );
    });

    test('no type, legacy category=delivery → delivery, routes to /orders/<id> '
        '(pre-sprint-009 payload shape unchanged)', () {
      const data = <String, String>{
        'category': 'delivery',
        'delivery_id': 'd-legacy',
      };
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.delivery);
      expect(
        deepLinkForMessage(_msg(category: category, data: data)),
        '/orders/d-legacy',
      );
    });

    test(
      'type=offer + legacy category=delivery → newOffer (the KNOWN type wins; '
      'auction phase ≠ delivery)',
      () {
        const data = <String, String>{
          'type': 'offer',
          'category': 'delivery',
          'requestId': 'req-offer',
        };
        final category = NotificationCategory.fromData(data);
        expect(category, NotificationCategory.newOffer);
        expect(
          deepLinkForMessage(_msg(category: category, data: data)),
          '/requests/req-offer/offers',
        );
      },
    );

    test('type=chat → chat route unchanged (no regression from the precedence '
        'flip)', () {
      const data = <String, String>{
        'type': 'chat',
        'conversationId': 'conv-1',
        'requestId': 'req-chat',
      };
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.chat);
      expect(
        deepLinkForMessage(_msg(category: category, data: data)),
        '/chat/req-chat',
      );
    });

    test('unknown type falls back to category=kyc → kyc route (fallback path '
        'preserved when the type is unrecognized)', () {
      const data = <String, String>{'type': 'promo_v2', 'category': 'kyc'};
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.kyc);
      expect(
        deepLinkForMessage(_msg(category: category, data: data)),
        '/profile/kyc',
      );
    });

    test('EXACT run-23 offer_accepted payload (type=offer_accepted + legacy '
        'category=delivery + flat requestId/offerId/deepLink) → the winner '
        'lands on the ACTIVE delivery, not the empty pending-offers list', () {
      // Mirrors the gateway's OfferPushNotifier.SendLifecycleAsync payload and
      const data = <String, String>{
        'type': 'offer_accepted',
        'category': 'delivery',
        'requestId': 'req-run23',
        'request_id': 'req-run23',
        'offerId': 'off-run23',
        'deepLink': 'jeeb://offers/off-run23',
        'title': 'Offer accepted',
        'body': 'Your offer was accepted',
      };
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.offerAccepted);
      expect(
        deepLinkForMessage(_msg(category: category, data: data)),
        '/jeeber/deliveries/req-run23/active',
      );
    });

    test('gateway-shaped offer_lost payload (type=offer_lost + legacy '
        'category=delivery) → the loser lands on the shell feed, never a '
        'dead end', () {
      const data = <String, String>{
        'type': 'offer_lost',
        'category': 'delivery',
        'requestId': 'req-run23',
        'request_id': 'req-run23',
        'offerId': 'off-loser',
        'deepLink': 'jeeb://offers/off-loser',
      };
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.offerLost);
      expect(deepLinkForMessage(_msg(category: category, data: data)), '/');
    });

    // A7 — the EXACT live gateway byte-shape of the new-offer push
    test('EXACT gateway new-offer payload (type=offer + legacy '
        'category=delivery + requestId/request_id/offerId) → newOffer, lands '
        'on the offer-review list', () {
      const data = <String, String>{
        'title': 'New offer on your request',
        'body': r'You received a new offer for $9. Tap to review.',
        'type': 'offer',
        'category': 'delivery',
        'requestId': 'R',
        'request_id': 'R',
        'offerId': 'O',
      };
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.newOffer);
      expect(
        deepLinkForMessage(_msg(category: category, data: data)),
        '/requests/R/offers',
      );
    });

    // A8 — the EXACT expiry byte-shape
    test('EXACT gateway request_expired payload → requestExpired, lands on '
        'the waiting screen (never the phantom order hub)', () {
      const data = <String, String>{
        'type': 'request_expired',
        'category': 'delivery',
        'requestId': 'R',
        'request_id': 'R',
        'language': 'en',
        'title': 'No jeeber yet',
        'body': 'We are still looking',
      };
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.requestExpired);
      expect(
        deepLinkForMessage(_msg(category: category, data: data)),
        '/requests/R/waiting',
      );
    });

    // A9 — same shape, the tier-expansion nudge.
    test('EXACT gateway try_expand_tier payload → requestExpired, lands on '
        'the waiting screen', () {
      const data = <String, String>{
        'type': 'try_expand_tier',
        'category': 'delivery',
        'requestId': 'R',
        'request_id': 'R',
        'language': 'en',
        'title': 'Expand your search?',
        'body': 'No jeeber in this tier',
      };
      final category = NotificationCategory.fromData(data);
      expect(category, NotificationCategory.requestExpired);
      expect(
        deepLinkForMessage(_msg(category: category, data: data)),
        '/requests/R/waiting',
      );
    });
  });

  group('push-type → route mapping table (regression pins, all 5 wire types '
      '+ unknown fallback)', () {
    // One assertion per LIVE gateway push type, resolving category from the
    String? routeFor(Map<String, String> data) {
      final category = NotificationCategory.fromData(data);
      return deepLinkForMessage(_msg(category: category, data: data));
    }

    test(
      'new_request → /jeeber/requests/:id (proven run-22/23 — do not break)',
      () {
        expect(
          routeFor(const {
            'type': 'new_request',
            'category': 'delivery',
            'requestId': 'req-1',
          }),
          '/jeeber/requests/req-1',
        );
      },
    );

    test('offer → /requests/:id/offers (P2: the offer-review list, not the '
        'phantom order hub)', () {
      expect(
        routeFor(const {
          'type': 'offer',
          'category': 'delivery',
          'requestId': 'req-1',
        }),
        '/requests/req-1/offers',
      );
    });

    test('chat → /chat/:requestId (proven sprint-008 — do not break)', () {
      expect(
        routeFor(const {
          'type': 'chat',
          'conversationId': 'conv-1',
          'requestId': 'req-1',
        }),
        '/chat/req-1',
      );
    });

    test('offer_accepted → /jeeber/deliveries/:id/active (this fix)', () {
      expect(
        routeFor(const {
          'type': 'offer_accepted',
          'category': 'delivery',
          'requestId': 'req-1',
          'offerId': 'off-1',
        }),
        '/jeeber/deliveries/req-1/active',
      );
    });

    test('offer_lost → / (shell feed; this fix)', () {
      expect(
        routeFor(const {
          'type': 'offer_lost',
          'category': 'delivery',
          'requestId': 'req-1',
          'offerId': 'off-1',
        }),
        '/',
      );
    });

    test('unknown type with no category → null (banner only, no navigation, '
        'no crash)', () {
      expect(routeFor(const {'type': 'promo_v9'}), isNull);
    });
  });

  group('dispute and support notifications', () {
    test('dispute update routes to its read-only status timeline', () {
      const data = <String, String>{
        'type': 'jeeb.dispute.updated',
        'caseId': 'dsp-1',
      };
      expect(NotificationCategory.fromData(data), NotificationCategory.dispute);
      expect(
        deepLinkForMessage(
          _msg(category: NotificationCategory.fromData(data), data: data),
        ),
        '/disputes/dsp-1',
      );
    });

    test('support reply routes directly to its ticket thread', () {
      const data = <String, String>{
        'type': 'jeeb.support.replied',
        'caseId': 'ticket-1',
      };
      expect(NotificationCategory.fromData(data), NotificationCategory.support);
      expect(
        deepLinkForMessage(
          _msg(category: NotificationCategory.fromData(data), data: data),
        ),
        '/support/tickets/ticket-1',
      );
    });

    test(
      'support update without an id safely opens the existing support route',
      () {
        expect(
          deepLinkForMessage(_msg(category: NotificationCategory.support)),
          '/support',
        );
      },
    );
  });

  // W6-T3 / CONTRACT §3 — the guard-2 withdraw push lands on the wallet, and
  // the client role guard must never divert it to the shell.
  group('wallet notifications route to the wallet, role-independently', () {
    test('a wallet push routes to /wallet with no role', () {
      expect(
        deepLinkForMessage(_msg(category: NotificationCategory.wallet)),
        '/wallet',
      );
    });

    test('a wallet push routes to /wallet for a jeeber', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.wallet,
            data: const {
              'type': 'offer_withdrawn_insufficient_balance',
              'offerId': 'o1',
              'requestId': 'r1',
            },
          ),
          role: UserRole.jeeber,
        ),
        '/wallet',
      );
    });

    test('a wallet push routes to /wallet for a client too (the role guard '
        'covers newRequest/offerAccepted/offerLost only)', () {
      expect(
        deepLinkForMessage(
          _msg(
            category: NotificationCategory.wallet,
            data: const {
              'type': 'offer_withdrawn_insufficient_balance',
              'requestId': 'r1',
            },
          ),
          role: UserRole.client,
        ),
        '/wallet',
      );
    });
  });

  // A15 (P2) — the assertion that would have caught the original bug, and the
  group('negative fence: no non-delivery type may resolve onto /orders/', () {
    const orderSurfaceTypes = <String>{'delivery', 'accept'};
    const wireTypes = <String>[
      'offer',
      'offer_accepted',
      'offer_lost',
      'new_request',
      'chat',
      'try_expand_tier',
      'request_expired',
      'delivery',
      'accept',
      'promo_v9',
    ];

    for (final type in wireTypes) {
      test('type=$type + legacy category=delivery + requestId only', () {
        final data = <String, String>{
          'type': type,
          'category': 'delivery',
          'requestId': 'R',
        };
        final path = deepLinkForMessage(
          _msg(category: NotificationCategory.fromData(data), data: data),
        );
        if (orderSurfaceTypes.contains(type)) {
          expect(path, '/orders/R', reason: '$type IS an order-surface event');
        } else if (type == 'promo_v9') {
          // An UNKNOWN type is not a gateway event — `fromData` deliberately
          expect(path, '/orders/R');
        } else {
          expect(
            path?.startsWith('/orders/') ?? false,
            isFalse,
            reason:
                '$type must never launder a request id into /orders/ '
                '(resolved: $path)',
          );
        }
      });
    }
  });
}
