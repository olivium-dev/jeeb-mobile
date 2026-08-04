import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/domain/push_audience.dart';

void main() {
  test('a jeeber-audience push does not match a client-only session', () {
    expect(
      isPushAudienceMatch(
        const {'audience_role': 'driver'},
        const {'client'},
      ),
      isFalse,
    );
  });

  test('a dual-role session (client + jeeber) matches a jeeber-audience push',
      () {
    expect(
      isPushAudienceMatch(
        const {'audience_role': 'driver'},
        const {'client', 'jeeber'},
      ),
      isTrue,
    );
  });

  test('the canonicaliser accepts both the opaque and the contract role form',
      () {
    expect(
      isPushAudienceMatch(
        const {'audience_role': 'driver'},
        const {'driver'},
      ),
      isTrue,
    );
    expect(
      isPushAudienceMatch(
        const {'audience_role': 'driver'},
        const {'jeeber'},
      ),
      isTrue,
    );
  });

  test('a payload with no audience key at all fails open (chat/offer push)',
      () {
    expect(
      isPushAudienceMatch(const {'delivery_id': 'd-1'}, const {'client'}),
      isTrue,
    );
  });

  test('an unknown audience token fails open, never suppresses', () {
    expect(
      isPushAudienceMatch(
        const {'audience_role': 'wizard'},
        const {'client'},
      ),
      isTrue,
    );
  });

  test('empty local roles (getMe not yet landed) fails open', () {
    expect(
      isPushAudienceMatch(const {'audience_role': 'driver'}, const {}),
      isTrue,
    );
  });

  test('the plural `audience` key (jeebers/clients) is honoured', () {
    expect(
      isPushAudienceMatch(
        const {'audience': 'jeebers'},
        const {'client'},
      ),
      isFalse,
    );
  });

  test('canonicalAudienceRole prefers audience_role over audienceRole over '
      'audience', () {
    expect(
      canonicalAudienceRole(const {
        'audience_role': 'driver',
        'audienceRole': 'customer',
        'audience': 'clients',
      }),
      kAudienceRoleJeeber,
    );
  });

  test('canonicalAudienceRole falls back through audienceRole then audience',
      () {
    expect(
      canonicalAudienceRole(const {'audienceRole': 'customer'}),
      kAudienceRoleClient,
    );
    expect(
      canonicalAudienceRole(const {'audience': 'clients'}),
      kAudienceRoleClient,
    );
    expect(canonicalAudienceRole(const {}), isNull);
  });

  test('a legacy topic-name token still canonicalises', () {
    expect(
      isPushAudienceMatch(
        const {'audience_role': 'jeeb_jeeber'},
        const {'client'},
      ),
      isFalse,
    );
    expect(
      isPushAudienceMatch(
        const {'audience_role': 'jeeb_client'},
        const {'jeeber'},
      ),
      isFalse,
    );
  });
}
