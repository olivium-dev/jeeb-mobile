import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/wallet/application/whatsapp_top_up_launcher.dart';

void main() {
  group('WhatsAppTopUpLink.build', () {
    test('strips formatting characters from the destination number', () {
      final uri = WhatsAppTopUpLink.build(
        supportPhoneE164: '+961 (3) 000-077',
        baseMessage: 'Hi',
      );
      expect(uri.host, 'wa.me');
      expect(uri.path, '/9613000077');
    });

    test('scheme is https and includes only digits in the path', () {
      final uri = WhatsAppTopUpLink.build(
        supportPhoneE164: '+9613000077',
        baseMessage: 'Hi',
      );
      expect(uri.scheme, 'https');
      expect(uri.path, '/9613000077');
    });

    test('omits the account-phone sentence when null', () {
      final uri = WhatsAppTopUpLink.build(
        supportPhoneE164: '+9613000077',
        baseMessage: 'Hi, I would like to top up my Jeeb wallet.',
      );
      final message = uri.queryParameters['text'];
      expect(message, 'Hi, I would like to top up my Jeeb wallet.');
    });

    test('omits the account-phone sentence when empty string', () {
      final uri = WhatsAppTopUpLink.build(
        supportPhoneE164: '+9613000077',
        baseMessage: 'Hi.',
        accountPhoneSentence: '',
      );
      expect(uri.queryParameters['text'], 'Hi.');
    });

    test('appends the account-phone sentence when provided', () {
      final uri = WhatsAppTopUpLink.build(
        supportPhoneE164: '+9613000077',
        baseMessage: 'Hi.',
        accountPhoneSentence: 'My account phone number is +96170123456.',
      );
      expect(
        uri.queryParameters['text'],
        'Hi. My account phone number is +96170123456.',
      );
    });

    test('percent-encodes spaces as %20, never as a literal +', () {
      final uri = WhatsAppTopUpLink.build(
        supportPhoneE164: '+9613000077',
        baseMessage: 'Hi there friend',
      );
      expect(uri.query, contains('%20'));
      expect(uri.query, isNot(contains('+')));
      expect(uri.toString(), contains('%20'));
      expect(
        uri.toString().replaceFirst('https://wa.me/9613000077?text=', ''),
        isNot(contains('+')),
      );
    });

    test('round-trips an Arabic message correctly', () {
      const arabic = 'مرحباً، أرغب في شحن محفظة جيب الخاصة بي.';
      final uri = WhatsAppTopUpLink.build(
        supportPhoneE164: '+9613000077',
        baseMessage: arabic,
      );
      expect(uri.queryParameters['text'], arabic);
    });
  });
}
