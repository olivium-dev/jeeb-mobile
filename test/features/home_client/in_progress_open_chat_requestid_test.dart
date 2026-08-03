// BUG-17 fix (a1) — In-Progress "Open chat" routes by the REQUEST/correlation

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Captures what the `chat-detail` route resolved from a tapped "Open chat".
String? _navigatedId;
String? _navigatedDeliveryId;

GoRouter _router(ClientHomeRepository repo) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: BlocProvider(
            create: (_) => ClientHomeCubit(
              repository: repo,
              greetingNameProvider: () => 'Sami',
            )..load(),
            // No onOpenChat override → exercises the REAL _navigateToChat path.
            child: const InProgressTab(),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        name: 'chat-detail',
        builder: (_, state) {
          _navigatedId = state.pathParameters['id'];
          _navigatedDeliveryId = state.uri.queryParameters['deliveryId'];
          return const Scaffold(body: Text('chat'));
        },
      ),
    ],
  );
}

Widget _app(GoRouter router) => MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [SyncAppLocalizationsDelegate()],
    );

ClientHomeRequest _activeRequest({
  required String id,
  String? conversationId,
  String? chatCorrelationId,
  String? deliveryId,
}) =>
    ClientHomeRequest(
      id: id,
      conversationId: conversationId,
      chatCorrelationId: chatCorrelationId,
      deliveryId: deliveryId,
      title: 'Pharmacy run',
      status: ClientRequestStatus.enRoute,
      destinationLabel: 'Ashrafieh, Beirut',
      progressStep: 2,
      tier: ClientRequestTier.flash,
    );

void main() {
  setUp(() {
    _navigatedId = null;
    _navigatedDeliveryId = null;
  });

  group('In-Progress "Open chat" — routes by requestId, not conversationId '
      '(BUG-17)', () {
    testWidgets(
      'routes chat by the request id (chatThreadId==id) and forwards the '
      'delivery id — even when a conversationId is present it is NOT used',
      (tester) async {
        final repo = InMemoryClientHomeRepository.fromSnapshot(
          ClientHomeSnapshot(
            inProgress: [
              _activeRequest(
                id: 'req-123',
                // A phantom conversationId that MUST NOT be routed with.
                conversationId: 'conv-should-not-be-used',
                deliveryId: 'delivery-777',
              ),
            ],
          ),
          latency: Duration.zero,
        );
        await tester.pumpWidget(_app(_router(repo)));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('active-open-chat-req-123')));
        await tester.pumpAndSettle();

        // THE FIX: chat opens on the REQUEST/correlation id, never the phantom
        expect(_navigatedId, 'req-123');
        expect(_navigatedId, isNot('conv-should-not-be-used'));
        // ...and the delivery id rides along for the in-chat Track CTA.
        expect(_navigatedDeliveryId, 'delivery-777');
      },
    );

    testWidgets(
      'when the delivery row id diverges from the parent request, routes chat '
      'by chatCorrelationId (the parent request id), tracking by the delivery',
      (tester) async {
        final repo = InMemoryClientHomeRepository.fromSnapshot(
          ClientHomeSnapshot(
            inProgress: [
              _activeRequest(
                id: 'delivery-x',
                chatCorrelationId: 'req-x',
                deliveryId: 'delivery-x',
              ),
            ],
          ),
          latency: Duration.zero,
        );
        await tester.pumpWidget(_app(_router(repo)));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('active-open-chat-delivery-x')));
        await tester.pumpAndSettle();

        expect(_navigatedId, 'req-x');
        expect(_navigatedId, isNot('delivery-x'));
        expect(_navigatedDeliveryId, 'delivery-x');
      },
    );
  });
}
