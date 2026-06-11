import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) =>
      _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(
      locale,
      _arbByTag[locale.languageCode]!,
    );
  }

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _harness({
  required ClientHomeRepository repo,
  String? greetingName,
  void Function(ClientHomeRequest)? onOpenRequest,
  VoidCallback? onCreateRequest,
  Locale locale = const Locale('en'),
  ClientHomeTab initialTab = ClientHomeTab.inProgress,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
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
          greetingNameProvider: () => greetingName,
        ),
        child: ClientHomeScreen(
          initialTab: initialTab,
          onOpenRequest: onOpenRequest,
          onCreateRequest: onCreateRequest,
        ),
      ),
    ),
  );
}

/// Snapshot covering all three My Orders tabs, mirroring the Figma mock data
/// for screens 13/14/15.
ClientHomeRepository _threeTabRepo() {
  return InMemoryClientHomeRepository.fromSnapshot(
    const ClientHomeSnapshot(
      inProgress: [
        ClientHomeRequest(
          id: 'ip-1',
          title: 'Kamal Hajj',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.enRoute,
          tier: ClientRequestTier.flash,
          progressStep: 3,
        ),
      ],
      pending: [
        ClientHomeRequest(
          id: 'pen-1',
          title: 'ORD-23470',
          displayId: 'ORD-23470',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.searching,
          tier: ClientRequestTier.express,
        ),
      ],
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
}

void main() {
  setUpAll(_loadArbs);

  // Zero-orders hero empty state (Figma node 56535:1514). When the client has
  // no requests across every tab, the screen swaps the populated layout for
  // the [ClientHomeEmptyView] hero: greeting (no add button), illustration,
  // "No orders yet" + body, and a full-width "New Order" CTA.
  group('ClientHomeScreen empty state (Figma 56535:1514)', () {
    // The hero pins its CTA near the bottom of a full-height column, so the
    // default 800x600 test surface clips it. Use a phone-sized window
    // (logical 440x956, matching the Figma frame) for on-screen hit testing.
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher
          .implicitView!;
      view.physicalSize = const Size(440 * 3, 956 * 3);
      view.devicePixelRatio = 3.0;
    });

    tearDown(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher
          .implicitView!;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    testWidgets(
        'renders greeting, "No orders yet", body, and "New Order" CTA '
        'when no requests exist', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(
        _harness(
          repo: repo,
          greetingName: 'Layla',
          onCreateRequest: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello, Layla'), findsOneWidget);
      expect(find.text('Everything, One Place'), findsOneWidget);
      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.text('Everything you order shows up here.'), findsOneWidget);
      expect(find.text('New Order'), findsOneWidget);
    });

    testWidgets('exposes a stable Semantics identifier on the New Order CTA',
        (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(repo: repo, onCreateRequest: () {}));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsIdentifier('_request_empty_state_new_order_button'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('falls back to generic greeting when no name is provided',
        (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('"New Order" CTA invokes onCreateRequest', (tester) async {
      var taps = 0;
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(
        repo: repo,
        onCreateRequest: () => taps += 1,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Order'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('ClientHomeScreen populated state', () {
    testWidgets(
        'renders an active request card with title, destination, and progress labels',
        (tester) async {
      final repo = InMemoryClientHomeRepository(
        latency: Duration.zero,
        seedActive: const [
          ClientHomeRequest(
            id: 'r-7',
            title: 'Pharmacy run',
            destinationLabel: 'Ashrafieh, Beirut',
            status: ClientRequestStatus.enRoute,
            etaMinutes: 8,
            jeeberName: 'Karim',
          ),
        ],
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('active-request-card-r-7')),
        findsOneWidget,
      );
      expect(find.text('Pharmacy run'), findsOneWidget);
      expect(find.text('Ashrafieh, Beirut'), findsOneWidget);
      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('Picked'), findsOneWidget);
      expect(find.text('In Transit'), findsOneWidget);
    });

    testWidgets('tapping "Track my order" invokes onOpenRequest with that request',
        (tester) async {
      ClientHomeRequest? opened;
      final repo = InMemoryClientHomeRepository(
        latency: Duration.zero,
        seedActive: const [
          ClientHomeRequest(
            id: 'r-1',
            title: 'Grocery pickup',
            destinationLabel: 'Hamra',
            status: ClientRequestStatus.accepted,
          ),
        ],
      );
      await tester.pumpWidget(_harness(
        repo: repo,
        onOpenRequest: (r) => opened = r,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Track my order'));
      await tester.pumpAndSettle();

      expect(opened?.id, 'r-1');
    });

    // Recent deliveries section ("Order again" / "Re-order") was removed in
    // the tabbed redesign. The home screen now shows In Progress / Pending
    // Requests / Replies tabs instead.
  });

  group('ClientHomeScreen i18n', () {
    testWidgets('renders Arabic empty-state strings under ar locale',
        (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(
        repo: repo,
        locale: const Locale('ar'),
        onCreateRequest: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد طلبات بعد'), findsOneWidget);
      expect(find.text('كل ما تطلبه يظهر هنا.'), findsOneWidget);
      expect(find.text('طلب جديد'), findsOneWidget);
    });
  });

  // The three client "My Orders" filter variants render off one screen
  // (Figma 56535:1525 / 1783 / 2251). initialTab selects which list shows.
  group('ClientHomeScreen My Orders filter variants', () {
    testWidgets(
        'In Progress (screen 15) shows the jeeber name, items summary, tier '
        'badge, stage labels, and Track CTA', (tester) async {
      await tester.pumpWidget(_harness(repo: _threeTabRepo()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active-request-card-ip-1')), findsOneWidget);
      expect(find.text('Kamal Hajj'), findsOneWidget);
      expect(
        find.text('1 kilo potato, water gallon, coffee blend'),
        findsOneWidget,
      );
      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('Track my order'), findsOneWidget);
    });

    testWidgets(
        'Pending Requests (screen 13) shows the order id + items + tier with '
        'no avatar / progress / CTA', (tester) async {
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.pendingRequests),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-requests-list')), findsOneWidget);
      expect(find.text('ORD-23470'), findsOneWidget);
      expect(find.text('Express'), findsOneWidget);
      expect(find.text('Track my order'), findsNothing);
      expect(find.text('Ordered'), findsNothing);
    });

    testWidgets(
        'Replies (screen 14) shows the order id, +N overflow, and Check '
        'Offers CTA', (tester) async {
      ClientHomeRequest? opened;
      await tester.pumpWidget(_harness(
        repo: _threeTabRepo(),
        initialTab: ClientHomeTab.replies,
        onOpenRequest: (r) => opened = r,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
      expect(find.text('+6'), findsOneWidget);
      expect(find.text('Check Offers'), findsOneWidget);

      await tester.tap(find.text('Check Offers'));
      await tester.pumpAndSettle();
      expect(opened?.id, 'rep-1');
    });

    testWidgets('filter chips carry stable Semantics identifiers',
        (tester) async {
      await tester.pumpWidget(_harness(repo: _threeTabRepo()));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsIdentifier('orders_filter_inProgress'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('orders_filter_pendingRequests'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('orders_filter_replies'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
