import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';

void main() {
  group('normalizeChatDeepLink (S007-P1B)', () {
    test('custom scheme jeeb://chat/<id> → /chat/<id>', () {
      expect(
        normalizeChatDeepLink(Uri.parse('jeeb://chat/conv-123')),
        '/chat/conv-123',
      );
    });

    test('custom scheme with no id segment → null', () {
      expect(normalizeChatDeepLink(Uri.parse('jeeb://chat')), isNull);
      expect(normalizeChatDeepLink(Uri.parse('jeeb://chat/')), isNull);
    });

    test('in-app navigation path (host empty) is untouched', () {
      expect(normalizeChatDeepLink(Uri.parse('/chat/conv-123')), isNull);
      expect(normalizeChatDeepLink(Uri.parse('/orders/o-1')), isNull);
    });

    test('https App Link is left for go_router native path matching', () {
      // host == 'jeeb.app', path already '/chat/<id>' → no rewrite needed.
      expect(
        normalizeChatDeepLink(Uri.parse('https://jeeb.app/chat/conv-123')),
        isNull,
      );
    });

    test('other custom-scheme hosts are not hijacked', () {
      expect(normalizeChatDeepLink(Uri.parse('jeeb://orders/o-1')), isNull);
    });
  });

  group('normalizeJeebSchemeDeepLink (double-slash fold)', () {
    test('folds host into path: jeeb://jeeber/requests/abc/offer', () {
      expect(
        normalizeJeebSchemeDeepLink(
          Uri.parse('jeeb://jeeber/requests/abc/offer'),
        ),
        '/jeeber/requests/abc/offer',
      );
    });

    test('host with no trailing path → /<host>', () {
      expect(
        normalizeJeebSchemeDeepLink(Uri.parse('jeeb://orders')),
        '/orders',
      );
    });

    test('preserves the query string', () {
      expect(
        normalizeJeebSchemeDeepLink(
          Uri.parse('jeeb://jeeber/requests/abc/offer?from=push'),
        ),
        '/jeeber/requests/abc/offer?from=push',
      );
    });

    test('https App Links are left for go_router native matching → null', () {
      expect(
        normalizeJeebSchemeDeepLink(
          Uri.parse('https://jeeb.app/jeeber/requests/abc/offer'),
        ),
        isNull,
      );
    });

    test('host-less jeeb:/ URIs → null', () {
      expect(normalizeJeebSchemeDeepLink(Uri.parse('jeeb:/')), isNull);
      expect(normalizeJeebSchemeDeepLink(Uri.parse('jeeb:/requests/abc')),
          isNull);
    });
  });
}
