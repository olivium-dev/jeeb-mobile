// Regression guards for the Semantics auto-merge defects (screens 09/12/14/15).
//
// Each of the four cards below wraps an OUTER `Semantics(identifier:)` (or a
// Row/Column) around a NESTED `Semantics(identifier:)` for an interactive
// element. Without an explicit Semantics *boundary* the ambient auto-merge
// folds the inner node into the outer one, so only the OUTER identifier
// survives and the INNER (test- and accessibility-facing) identifier is
// swallowed — Maestro and screen readers can no longer address it.
//
// The fix adds `explicitChildNodes: true` (and `container: true` where the
// boundary is itself an identified wrapper) so BOTH identifiers surface as
// their own queryable `SemanticsNode`. These tests assert exactly that: each
// pair is independently findable via `find.bySemanticsIdentifier`. They FAIL
// on the pre-fix source (inner id swallowed → `findsNothing`) and PASS after.
//
// The repo's canonical Semantics-identifier finder is Flutter's built-in
// `find.bySemanticsIdentifier(...)` (see test/delivery_create_screens_test.dart
// and test/client_home_screen_test.dart).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/active_request_card.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/replies_card.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_location_row.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  setUpAll(_loadArbs);

  // A tall, wide surface so nothing is laid out off-screen / culled.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('A1 RequestLocationRow (screen 12 / Figma 56535:2392)', () {
    testWidgets(
      'surfaces BOTH the current-location label id and the change-location '
      'button id as distinct nodes',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            RequestLocationRow(
              currentLabel: 'Current Location',
              changeLabel: 'Change Location',
              onChange: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Outer id preserved.
        expect(
          find.bySemanticsIdentifier('request_type_current_location_label'),
          findsOneWidget,
          reason: 'The current-location label identifier must remain queryable.',
        );
        // Previously-swallowed inner button id now surfaces.
        expect(
          find.bySemanticsIdentifier('request_type_change_location_button'),
          findsOneWidget,
          reason: 'The change-location button identifier must surface as its '
              'own node (was merged into the label node before the fix).',
        );
      },
    );
  });

  group('A2 ChatMessageBubble (screen 09 read-receipt)', () {
    testWidgets(
      'surfaces BOTH the per-message id and the read double-tick id as '
      'distinct nodes',
      (tester) async {
        // `author: me` + `status: read` → routes through `_TextBubble`, whose
        // sender footer renders the read double-tick carrying the inner id.
        final message = DeliveryChatMessage.text(
          id: 'm-42',
          author: ChatAuthor.me,
          sentAt: DateTime(2026, 6, 12, 10, 30),
          status: MessageStatus.read,
          text: 'on my way',
        );
        await tester.pumpWidget(_harness(ChatMessageBubble(message: message)));
        await tester.pumpAndSettle();

        // Outer per-message id preserved.
        expect(
          find.bySemanticsIdentifier('chat_detail_message_m-42'),
          findsOneWidget,
          reason: 'The per-message identifier must remain queryable.',
        );
        // Previously-swallowed read double-tick id now surfaces.
        expect(
          find.bySemanticsIdentifier('chat_detail_message_read'),
          findsOneWidget,
          reason: 'The read double-tick identifier must surface as its own '
              'node (was merged into the per-message node before the fix).',
        );
      },
    );
  });

  group('A3 RepliesCard (screen 14)', () {
    testWidgets(
      'surfaces BOTH the avatar-stack id and the check-offers button id as '
      'distinct nodes',
      (tester) async {
        const request = ClientHomeRequest(
          id: 'rep-7',
          title: 'ORD-23748',
          status: ClientRequestStatus.offersReceived,
          destinationLabel: 'Pharmacy run',
          itemsSummary: 'painkillers, vitamins',
          displayId: 'ORD-23748',
          offerCount: 6,
          offerAvatarUrls: <String>['a.png', 'b.png', 'c.png'],
        );
        await tester.pumpWidget(
          _harness(RepliesCard(request: request, onCheckOffers: () {})),
        );
        await tester.pumpAndSettle();

        // Avatar-stack id (the one that previously survived).
        expect(
          find.bySemanticsIdentifier('orders_replies_avatar_stack_rep-7'),
          findsOneWidget,
          reason: 'The avatar-stack identifier must remain queryable.',
        );
        // Previously-swallowed check-offers button id now surfaces.
        expect(
          find.bySemanticsIdentifier('orders_replies_check_offers_rep-7'),
          findsOneWidget,
          reason: 'The Check-Offers button identifier must surface as its own '
              'node (was merged with the avatar-stack node before the fix).',
        );
      },
    );
  });

  group('A4 ActiveOrderCard (screen 15)', () {
    testWidgets(
      'surfaces BOTH the active-card id and the track-order button id as '
      'distinct nodes',
      (tester) async {
        const request = ClientHomeRequest(
          id: 'act-3',
          title: 'Kamal Hajj',
          status: ClientRequestStatus.enRoute,
          destinationLabel: '1 kilo potato, water gallon',
          itemsSummary: '1 kilo potato, water gallon',
          tier: ClientRequestTier.express,
          progressStep: 2,
        );
        await tester.pumpWidget(
          _harness(ActiveOrderCard(request: request, onTap: () {})),
        );
        await tester.pumpAndSettle();

        // Outer card id preserved.
        expect(
          find.bySemanticsIdentifier('orders_active_card_act-3'),
          findsOneWidget,
          reason: 'The active-card identifier must remain queryable.',
        );
        // Previously-swallowed track-order button id now surfaces. The Track
        // CTA renders only for accepted/atPickup/enRoute — enRoute above.
        expect(
          find.bySemanticsIdentifier('orders_track_order_button_act-3'),
          findsOneWidget,
          reason: 'The Track-order button identifier must surface as its own '
              'node (was merged into the card node before the fix).',
        );
      },
    );
  });

  // SCREEN-LEVEL guards. The Maestro flows exercise these cards inside their
  // host screens (RequestTypeScreen, ClientHomeScreen) — not in isolation — so
  // these tests render the real screen and assert the previously-swallowed
  // inner identifiers surface there too. They also localize the A1/A3
  // reproduction to the exact context the live flow addresses.
  group('A1 screen-level (RequestTypeScreen Location section)', () {
    testWidgets(
      'change-location button id is queryable within the full screen',
      (tester) async {
        await tester.pumpWidget(
          _harness(const RequestTypeScreen(repository: FakeTierRepository())),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('request_type_current_location_label'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('request_type_change_location_button'),
          findsOneWidget,
          reason: 'The change-location button id must be addressable from the '
              'host RequestTypeScreen, as the Maestro flow targets it.',
        );
      },
    );
  });

  group('A3 screen-level (ClientHomeScreen Replies tab)', () {
    testWidgets(
      'check-offers button id is queryable within the full Replies tab',
      (tester) async {
        await tester.pumpWidget(_clientHome(initialTab: ClientHomeTab.replies));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('orders_replies_avatar_stack_rep-1'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('orders_replies_check_offers_rep-1'),
          findsOneWidget,
          reason: 'The Check-Offers button id must be addressable from the '
              'host ClientHomeScreen Replies tab, as the flow targets it.',
        );
      },
    );
  });
}

/// Builds a `ClientHomeScreen` on the requested tab over a snapshot that
/// populates the Replies tab (rep-1, +9 offers) so the Replies card renders.
Widget _clientHome({required ClientHomeTab initialTab}) {
  final ClientHomeRepository repo =
      InMemoryClientHomeRepository.fromSnapshot(
    const ClientHomeSnapshot(
      replies: [
        ClientHomeRequest(
          id: 'rep-1',
          title: 'ORD-23470',
          displayId: 'ORD-23470',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.offersReceived,
          tier: ClientRequestTier.express,
          offerCount: 9,
          offerAvatarUrls: ['', '', ''],
          conversationId: 'conv-rep-1',
        ),
      ],
    ),
    latency: Duration.zero,
  );
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => null,
        ),
        child: ClientHomeScreen(initialTab: initialTab),
      ),
    ),
  );
}
