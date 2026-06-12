// Screen-13 fixture-data gap guard.
//
// Under the dev seam, tapping a Pending Requests row pushes `/chat/pen-1`.
// The committed Maestro flow (.maestro/flows/13-request-pending-requests-
// screen-user.yaml) then asserts `chat_detail_message_list` is visible —
// proving the pending item routes to a real, populated chat thread.
//
// Before the fix, ChatDetailScreen always resolved a DioChatGateway for that
// id; the mock returns 404 (no seeded conversation for `pen-1`), so the chat
// screen rendered _ChatEmptyState and the flow's terminal assertion was
// (correctly) false. The fix routes seeded dev-seam ids through the offline
// DevChatFixtureGateway — the SAME in-memory mechanism flows 02–07 use — so a
// populated thread mounts honestly offline.
//
// These tests assert the gap is closed at the unit + widget level (on-device
// re-verify is a separate later step):
//   1. DevChatDetailFixtures.resolveGateway returns an offline fixture gateway
//      for every reachable seeded id when the seam drives a home tab, and null
//      otherwise (no seam, unseeded id).
//   2. ChatDetailScreen for `pen-1` under the seam mounts the populated
//      message list (chat_detail_message_list), NOT the empty state.
//
// kDebugMode is true under `flutter test`, so the kDebugMode-gated resolver is
// live here exactly as it is in a debug capture build.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/features/chat/data/dev_chat_fixture_gateway.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/dev_chat_detail_fixtures.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  assert(kDebugMode, 'dev-seam fixture tests must run in debug');

  tearDown(DevSeam.debugReset);

  group('DevChatDetailFixtures.resolveGateway', () {
    test('returns an offline fixture gateway for every reachable seeded id '
        'when the seam drives a home tab', () {
      DevSeam.debugOverride(
        const DevSeamConfig(route: '/', homeTab: 'pending'),
      );
      const seededIds = <String>[
        'pen-1', 'pen-2', 'pen-3', // Pending Requests rows (screen 13)
        'ip-1', 'ip-2', 'ip-3', // In Progress rows
        'conv-rep-1', // Replies card conversation id
      ];
      for (final id in seededIds) {
        expect(
          DevChatDetailFixtures.resolveGateway(id),
          isA<DevChatFixtureGateway>(),
          reason: 'seeded id "$id" must resolve to the offline fixture gateway',
        );
      }
    });

    test('returns null when the seam is NOT driving a home tab (real path)',
        () {
      // No homeTab seeded → production resolution must be untouched.
      DevSeam.debugOverride(const DevSeamConfig(route: '/'));
      expect(DevChatDetailFixtures.resolveGateway('pen-1'), isNull);
    });

    test('returns null for an unseeded id even under the seam', () {
      DevSeam.debugOverride(
        const DevSeamConfig(route: '/', homeTab: 'pending'),
      );
      expect(DevChatDetailFixtures.resolveGateway('not-a-seed'), isNull);
    });
  });

  group('ChatDetailScreen under the dev seam (screen 13)', () {
    testWidgets(
      'opening /chat/pen-1 mounts the populated message list, not empty state',
      (tester) async {
        // Drive the seam exactly as the Maestro flow does (home_tab=pending).
        DevSeam.debugOverride(
          const DevSeamConfig(route: '/', homeTab: 'pending'),
        );

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              SyncAppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatDetailScreen(chatId: 'pen-1'),
          ),
        );
        await tester.pumpAndSettle();

        // The terminal Maestro assertion target: the populated message list,
        // addressed exactly as the flow does (by its semantics identifier).
        expect(
          find.byKey(ChatScreen.messageListKey),
          findsOneWidget,
          reason: 'pen-1 must mount the populated chat thread offline',
        );
        expect(
          find.bySemanticsIdentifier('chat_detail_message_list'),
          findsOneWidget,
          reason: 'the chat_detail_message_list semantics id must be present, '
              'matching the Maestro flow terminal assertion',
        );
        // And it must NOT be the empty state.
        expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);
      },
    );
  });
}
