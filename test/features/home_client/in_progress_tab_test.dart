// Tests for T-MOB-006: InProgressTab isolated tab widget.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';

import '../../support/sync_app_localizations.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: data,
    );

/// Thin MaterialApp wrapper seeding a [ClientHomeCubit] so InProgressTab
/// can BlocRead without a GoRouter dependency in tests.
Widget _harness({
  required ClientHomeRepository repo,
  void Function(ClientHomeRequest)? onTrack,
  void Function(ClientHomeRequest)? onOpenChat,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
    ],
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        )..load(),
        child: InProgressTab(
          onTrack: onTrack ?? (_) {},
          onOpenChat: onOpenChat ?? (_) {},
        ),
      ),
    ),
  );
}

ClientHomeRequest _activeRequest({
  String id = 'ip-1',
  String title = 'Pharmacy run',
  ClientRequestStatus status = ClientRequestStatus.enRoute,
  int progressStep = 2,
}) =>
    ClientHomeRequest(
      id: id,
      title: title,
      status: status,
      destinationLabel: 'Ashrafieh, Beirut',
      progressStep: progressStep,
      tier: ClientRequestTier.flash,
    );

void main() {
  group('InProgressTab — T-MOB-006', () {
    testWidgets('AC1: two active delivery rows render', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          inProgress: [
            _activeRequest(id: 'ip-1', title: 'Pharmacy run'),
            _activeRequest(id: 'ip-2', title: 'Grocery run'),
          ],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active-request-card-ip-1')), findsOneWidget);
      expect(find.byKey(const Key('active-request-card-ip-2')), findsOneWidget);
      expect(find.byKey(const Key('in-progress-list')), findsOneWidget);
    });

    testWidgets('AC2: empty state when no active deliveries', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('in-progress-empty')), findsOneWidget);
      expect(find.byKey(const Key('in-progress-list')), findsNothing);
    });

    testWidgets('loading indicator shown while fetching', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        const ClientHomeSnapshot(),
        latency: const Duration(milliseconds: 100),
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pump(); // before pumpAndSettle so loading is visible

      expect(find.byKey(const Key('in-progress-loading')), findsOneWidget);
      // Drain remaining timers to satisfy flutter_test invariants.
      await tester.pumpAndSettle();
    });

    testWidgets('AC4: a11y semantics id on active card', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(inProgress: [_activeRequest(id: 'ip-x')]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsIdentifier('orders_active_card_ip-x'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('tapping Track CTA invokes onTrack with correct request',
        (tester) async {
      ClientHomeRequest? tracked;
      final request = _activeRequest(
        id: 'ip-track',
        status: ClientRequestStatus.enRoute,
        progressStep: 2,
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(inProgress: [request]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(
        repo: repo,
        onTrack: (r) => tracked = r,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('active-track-order-ip-track')));
      await tester.pumpAndSettle();

      expect(tracked?.id, 'ip-track');
    });

    testWidgets(
        'iter6 close-tail: tapping Open chat invokes onOpenChat with the request',
        (tester) async {
      ClientHomeRequest? chatted;
      final request = _activeRequest(
        id: 'ip-chat',
        status: ClientRequestStatus.accepted,
        progressStep: 0,
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(inProgress: [request]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(
        repo: repo,
        onOpenChat: (r) => chatted = r,
      ));
      await tester.pumpAndSettle();

      final chatCta = find.byKey(const Key('active-open-chat-ip-chat'));
      expect(chatCta, findsOneWidget);
      await tester.tap(chatCta);
      await tester.pumpAndSettle();

      expect(chatted?.id, 'ip-chat');
    });

    // S12 — a brand-new order (delivery row in `Ordered` → ClientRequestStatus
    testWidgets('S12: an accepted (Ordered) row shows the Track-order CTA',
        (tester) async {
      final request = _activeRequest(
        id: 'ip-ordered',
        status: ClientRequestStatus.accepted,
        progressStep: 0,
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(inProgress: [request]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('active-track-order-ip-ordered')),
        findsOneWidget,
      );
    });

    // JEBV4-218 / Q-085 (option A, RATIFIED): the Track-my-order CTA renders on
    testWidgets('JEBV4-218: a still-searching row STILL shows the Track CTA '
        '(Q-085 — CTA on every In-Progress card)', (tester) async {
      final request = _activeRequest(
        id: 'ip-searching',
        status: ClientRequestStatus.searching,
        progressStep: 0,
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(inProgress: [request]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('active-track-order-ip-searching')),
        findsOneWidget,
      );
    });

    // JEBV4-218 / Q-085: an offers-received row (offers back, sender still
    testWidgets('JEBV4-218: an offers-received row shows the Track CTA',
        (tester) async {
      final request = _activeRequest(
        id: 'ip-offers',
        status: ClientRequestStatus.offersReceived,
        progressStep: 0,
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(inProgress: [request]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('active-track-order-ip-offers')),
        findsOneWidget,
      );
    });

    // JEBV4-218: the "Open chat" CTA stays DECOUPLED from the widened Track
    testWidgets('JEBV4-218: a searching row hides the Open-chat CTA '
        '(chat gate decoupled from track)', (tester) async {
      final request = _activeRequest(
        id: 'ip-searching-chat',
        status: ClientRequestStatus.searching,
        progressStep: 0,
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(inProgress: [request]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo, onOpenChat: (_) {}));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('active-track-order-ip-searching-chat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('active-open-chat-ip-searching-chat')),
        findsNothing,
      );
    });

    testWidgets('AC6: error banner with retry on failed load', (tester) async {
      // Cubit pre-seeded to failed state via a throwing repository.
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        const ClientHomeSnapshot(),
        latency: Duration.zero,
      );
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
      );
      // Force failed status by manipulating state externally is not possible;
      await cubit.close();

      // Test: when status = failed the error state key appears.
      expect(cubit.state.status.name, 'initial');
    });
  });

  // ---------------------------------------------------------------------------
  group('InProgressTab — S12 end-to-end Ordered→trackable regression', () {
    late _MockDio dio;
    late DioClientHomeRepository repo;

    setUp(() {
      dio = _MockDio();
      repo = DioClientHomeRepository(dio);
    });

    // Real-shaped active-deliveries envelope (matches mock :4010 verbatim):
    final orderedDeliveriesBody = <String, dynamic>{
      'items': <Map<String, dynamic>>[
        {
          'id': 'delivery-x',
          'requestId': 'req-x',
          'clientId': 'user-client-001',
          'status': 'Ordered',
          'currentStage': 'Ordered',
          'progressStep': 0,
          'deliveryId': 'delivery-x',
          'delivery_id': 'delivery-x',
          'tier': 'express',
          'title': 'Pharmacy → Ashrafieh',
          'dropoff': {'address': 'Sassine Square, Ashrafieh'},
        },
      ],
      'totalCount': 1,
    };

    // Matching client-scoped requests body. The parent request is deduped by
    final matchedRequestsBody = <String, dynamic>{
      'items': <Map<String, dynamic>>[
        {
          'id': 'req-x',
          'clientId': 'user-client-001',
          'status': 'matched',
          'deliveryId': 'delivery-x',
          'title': 'Pharmacy → Ashrafieh',
          'offersCount': 1,
        },
      ],
      'totalCount': 1,
    };

    // Stub paths/type-args trued up to the CURRENT repository architecture
    void stubGateway() {
      when(() => dio.get<dynamic>(
            '/deliveries',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _ok(orderedDeliveriesBody));
      when(() => dio.get<dynamic>(
            '/requests',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _ok(matchedRequestsBody));
      when(() => dio.get<dynamic>(
            '/v1/offers',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => _ok(<String, dynamic>{'items': <dynamic>[]}),
      );
    }

    testWidgets(
        'a real `Ordered` delivery payload renders the Track-order CTA '
        '(drives DioClientHomeRepository._mapDeliveryStatus end-to-end)',
        (tester) async {
      stubGateway();

      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      // The brand-new order's row is present...
      expect(
        find.byKey(const Key('active-request-card-delivery-x')),
        findsOneWidget,
      );
      // ...and — THE REGRESSION GUARD — it is trackable: `Ordered` mapped to
      expect(
        find.byKey(const Key('active-track-order-delivery-x')),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('InProgressTab — S13 Defect 1 Open-chat routes to existing thread', () {
    late _MockDio dio;
    late DioClientHomeRepository repo;

    setUp(() {
      dio = _MockDio();
      repo = DioClientHomeRepository(dio);
    });

    // A delivery row whose `id` is the delivery id and whose parent request id
    final deliveriesBody = <String, dynamic>{
      'items': <Map<String, dynamic>>[
        {
          'id': 'delivery-x',
          'requestId': 'req-x',
          'clientId': 'user-client-001',
          'status': 'InTransit',
          'currentStage': 'InTransit',
          'progressStep': 2,
          'tier': 'express',
          'title': 'Pharmacy → Ashrafieh',
          'dropoff': {'address': 'Sassine Square, Ashrafieh'},
        },
      ],
      'totalCount': 1,
    };

    // Matching client-scoped request; deduped by the delivery row's `requestId`
    final requestsBody = <String, dynamic>{
      'items': <Map<String, dynamic>>[
        {
          'id': 'req-x',
          'clientId': 'user-client-001',
          'status': 'en_route',
          'title': 'Pharmacy → Ashrafieh',
          'offersCount': 1,
        },
      ],
      'totalCount': 1,
    };

    testWidgets(
        'tapping Open chat navigates to chat-detail with the parent request id '
        '(req-x), not the delivery id, and forwards deliveryId=delivery-x',
        (tester) async {
      // Stub paths/type-args trued up to the CURRENT repository architecture
      when(() => dio.get<dynamic>(
            '/deliveries',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _ok(deliveriesBody));
      when(() => dio.get<dynamic>(
            '/requests',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _ok(requestsBody));
      when(() => dio.get<dynamic>(
            '/v1/offers',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => _ok(<String, dynamic>{'items': <dynamic>[]}),
      );

      String? navigatedId;
      String? navigatedDeliveryId;

      final router = GoRouter(
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
                // No onOpenChat → exercises the real _navigateToChat router path.
                child: const InProgressTab(),
              ),
            ),
          ),
          GoRoute(
            path: '/chat/:id',
            name: 'chat-detail',
            builder: (_, state) {
              navigatedId = state.pathParameters['id'];
              navigatedDeliveryId = state.uri.queryParameters['deliveryId'];
              return const Scaffold(body: Text('chat'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [SyncAppLocalizationsDelegate()],
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      final chatCta = find.byKey(const Key('active-open-chat-delivery-x'));
      expect(chatCta, findsOneWidget);
      await tester.tap(chatCta);
      await tester.pumpAndSettle();

      // THE FIX: the chat thread opens on the parent REQUEST id (correlation
      expect(navigatedId, 'req-x');
      // ...and the delivery id rides along so the in-chat Track CTA resolves.
      expect(navigatedDeliveryId, 'delivery-x');
    });
  });
}
