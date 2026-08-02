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
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

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
  void Function(ClientHomeRequest)? onTrack,
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
          onTrack: onTrack,
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

  group('ClientHomeScreen pending empty state', () {
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
      view.physicalSize = const Size(440 * 3, 956 * 3);
      view.devicePixelRatio = 3.0;
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    testWidgets('keeps Requests chrome and renders the branded first CTA', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          repo: repo,
          greetingName: 'Layla',
          onCreateRequest: () {},
          initialTab: ClientHomeTab.pendingRequests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello, Layla'), findsOneWidget);
      expect(find.text('Everything, One Place'), findsNothing);
      expect(
        find.bySemanticsIdentifier('orders_create_request_button'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('client-home-greeting-add')), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('orders_filter_pendingRequests'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('orders_filter_replies'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('_request_empty_state_root'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('_request_empty_state_avatar'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('_request_empty_state_new_order_button'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('orders_home_new_order_fab'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('client_home_voice_request'),
        findsNothing,
      );
      expect(find.bySemanticsIdentifier('orders_search_bar'), findsNothing);
      handle.dispose();

      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Replies'), findsOneWidget);
      expect(find.text('What do you need?'), findsOneWidget);
      expect(
        find.text('No pending requests — broadcast a new one to get offers.'),
        findsOneWidget,
      );
      expect(find.text('Create your first request'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/illustrations/empty_orders.png',
        ),
        findsOneWidget,
      );

      expect(find.text('No orders yet'), findsNothing);
      expect(find.text('New Order'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const Key('client-home-voice-cta')), findsNothing);
      expect(find.byKey(const Key('client-home-search-bar')), findsNothing);
    });

    testWidgets('falls back to generic greeting when no name is provided', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(
        _harness(repo: repo, initialTab: ClientHomeTab.pendingRequests),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('"Create your first request" invokes onCreateRequest', (
      tester,
    ) async {
      var taps = 0;
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(
        _harness(
          repo: repo,
          onCreateRequest: () => taps += 1,
          initialTab: ClientHomeTab.pendingRequests,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create your first request'));
      await tester.tap(find.text('Create your first request'));
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
        expect(find.text('Create your first request'), findsNothing);
      },
    );

    testWidgets('tapping "Track my order" invokes onTrack with that request', (
      tester,
    ) async {
      ClientHomeRequest? tracked;
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
      await tester.pumpWidget(
        _harness(repo: repo, onTrack: (r) => tracked = r),
      );
      await tester.pumpAndSettle();

      // Card + Track CTA carry stable Semantics identifiers so Maestro can
      expect(
        tester.getSemantics(find.byKey(const Key('active-request-card-r-1'))),
        containsSemantics(identifier: 'orders_active_card_r-1'),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('active-track-order-r-1'))),
        containsSemantics(
          identifier: 'orders_track_order_button_r-1',
          isButton: true,
        ),
      );

      await tester.tap(find.byKey(const Key('active-track-order-r-1')));
      await tester.pumpAndSettle();

      expect(tracked?.id, 'r-1');
    });

    // Recent deliveries section ("Order again" / "Re-order") was removed in
  });

  group('ClientHomeScreen i18n', () {
    testWidgets('renders Arabic empty-state strings under ar locale', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(
        _harness(
          repo: repo,
          locale: const Locale('ar'),
          onCreateRequest: () {},
          initialTab: ClientHomeTab.pendingRequests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ماذا تحتاج؟'), findsOneWidget);
      expect(
        find.text('لا توجد طلبات معلّقة — أنشئ طلبًا جديدًا لتلقّي العروض.'),
        findsOneWidget,
      );
      expect(find.text('أنشئ أول طلب لك'), findsOneWidget);
    });
  });

  // The three client "My Orders" filter variants render off one screen
  group('ClientHomeScreen My Orders filter variants', () {
    testWidgets(
      'In Progress (screen 15) shows the jeeber name, items summary, tier '
      'badge, stage labels, and Track CTA',
      (tester) async {
        await tester.pumpWidget(_harness(repo: _threeTabRepo()));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('active-request-card-ip-1')),
          findsOneWidget,
        );
        expect(find.text('Kamal Hajj'), findsOneWidget);
        expect(
          find.text('1 kilo potato, water gallon, coffee blend'),
          findsOneWidget,
        );
        expect(find.text('Flash'), findsOneWidget);
        expect(find.text('Ordered'), findsOneWidget);
        expect(find.text('Track my order'), findsOneWidget);
      },
    );

    testWidgets(
      'Pending Requests (screen 13) shows the order id + items + tier with '
      'no avatar / progress / CTA',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            repo: _threeTabRepo(),
            initialTab: ClientHomeTab.pendingRequests,
          ),
        );
        await tester.pumpAndSettle();

        // Key updated: home screen now delegates to PendingRequestsTab which uses
        expect(
          find.byKey(const Key('pending-requests-tab-list')),
          findsOneWidget,
        );
        expect(find.text('ORD-23470'), findsOneWidget);
        expect(find.text('Express'), findsOneWidget);
        expect(find.text('Track my order'), findsNothing);
        expect(find.text('Ordered'), findsNothing);
      },
    );

    testWidgets(
      'Replies (screen 14 / JM-027) shows the order id, +N overflow, and '
      'BOTH CTAs (Check Offers + Accept) with contract identifiers',
      (tester) async {
        await tester.pumpWidget(
          _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.replies),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
        expect(find.text('+6'), findsOneWidget);
        expect(find.text('Check Offers'), findsOneWidget);
        // JM-027 added the per-card Accept CTA (→ offer-accept-confirm, JM-029).
        expect(find.byKey(const Key('replies-accept-rep-1')), findsOneWidget);

        // JM-027 AC1/AC2: both CTAs carry the contract Semantics identifiers.
        final handle = tester.ensureSemantics();
        expect(
          find.bySemanticsIdentifier('replies_check_offers_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('replies_accept_cta'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'filter chips carry stable Semantics identifiers — Pending + Replies '
      'only (JEBV4-298: In-Progress relocated to Delivery tab)',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            repo: _threeTabRepo(),
            initialTab: ClientHomeTab.pendingRequests,
          ),
        );
        await tester.pumpAndSettle();

        final handle = tester.ensureSemantics();
        // E24/Q-086: the Requests tab is on-hold only. The accepted-onward
        expect(
          find.bySemanticsIdentifier('orders_filter_inProgress'),
          findsNothing,
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
      },
    );
  });

  // JEBV4-298 (E24/Q-086): the Requests bottom-nav tab is the ON-HOLD surface
  group('ClientHomeScreen Requests = on-hold only (JEBV4-298)', () {
    testWidgets('widget default landing tab is Pending Requests', (
      tester,
    ) async {
      // The production host (HomeTab) leaves initialTab at the widget default;
      expect(
        const ClientHomeScreen().initialTab,
        ClientHomeTab.pendingRequests,
      );
    });

    testWidgets(
      'Requests tab bar omits the In-Progress chip and renders Pending first',
      (tester) async {
        // Pump with the widget default (Pending) landing tab and a snapshot that
        await tester.pumpWidget(
          _harness(
            repo: _threeTabRepo(),
            initialTab: ClientHomeTab.pendingRequests,
          ),
        );
        await tester.pumpAndSettle();

        // No In-Progress chip on the Requests tab bar.
        expect(
          find.byKey(const Key('client-home-tab-inProgress')),
          findsNothing,
        );
        // Only the two on-hold chips are present.
        expect(
          find.byKey(const Key('client-home-tab-pendingRequests')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('client-home-tab-replies')),
          findsOneWidget,
        );
        // Default landing surface is the Pending list, NOT an active-request card.
        expect(
          find.byKey(const Key('pending-requests-tab-list')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('active-request-card-ip-1')), findsNothing);
      },
    );

    testWidgets(
      'with an empty Pending list the Requests tab advances to Replies '
      '(never to the relocated In-Progress surface)',
      (tester) async {
        // Only In-Progress + Replies populated; Pending empty. The one-shot
        final repo = InMemoryClientHomeRepository.fromSnapshot(
          const ClientHomeSnapshot(
            inProgress: [
              ClientHomeRequest(
                id: 'ip-1',
                title: 'Kamal Hajj',
                destinationLabel: 'items',
                status: ClientRequestStatus.enRoute,
                tier: ClientRequestTier.flash,
                progressStep: 3,
              ),
            ],
            replies: [
              ClientHomeRequest(
                id: 'rep-1',
                title: 'ORD-23470',
                displayId: 'ORD-23470',
                destinationLabel: 'items',
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
        await tester.pumpWidget(
          _harness(repo: repo, initialTab: ClientHomeTab.pendingRequests),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
        expect(find.byKey(const Key('active-request-card-ip-1')), findsNothing);
      },
    );
  });

  // UX-parity regressions for client-home screens 13/14/15 (Figma 56535:1783 /
  group('ClientHomeScreen UX parity (screens 13/14/15)', () {
    // DEFECT 2 — AR tier-label l10n leak. Under `ar` the pending-request tier
    testWidgets(
      'Pending tier badge renders the Arabic tier label under ar locale',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            repo: _threeTabRepo(),
            locale: const Locale('ar'),
            initialTab: ClientHomeTab.pendingRequests,
          ),
        );
        await tester.pumpAndSettle();

        // Arabic value present, English value absent — proves the badge reads the
        expect(find.text('إكسبرس'), findsOneWidget);
        expect(find.text('Express'), findsNothing);
      },
    );

    testWidgets(
      'In Progress tier badge is localized to Arabic (Flash → سريع)',
      (tester) async {
        await tester.pumpWidget(
          _harness(repo: _threeTabRepo(), locale: const Locale('ar')),
        );
        await tester.pumpAndSettle();

        expect(find.text('سريع'), findsOneWidget);
        expect(find.text('Flash'), findsNothing);
      },
    );

    // DEFECT 3 — Check Offers CTA must be a content-hugging pill pinned to the
    testWidgets('Replies Check Offers CTA is content-hugging and end-aligned', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.replies),
      );
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('replies-check-offers-rep-1'));
      final card = find.byKey(const Key('replies-card-rep-1'));
      final btnSize = tester.getSize(btn);
      final cardSize = tester.getSize(card);

      // Hugs content: clearly narrower than the full card width (it was
      expect(
        btnSize.width < cardSize.width * 0.6,
        isTrue,
        reason:
            'Check Offers must hug content, got '
            '${btnSize.width} of ${cardSize.width}',
      );

      // End-aligned: right edge sits at the trailing gutter, flush with the
      final btnRight = tester.getTopRight(btn).dx;
      final cardRight = tester.getTopRight(card).dx;
      expect(
        (cardRight - btnRight) < 24,
        isTrue,
        reason:
            'Check Offers right edge should sit at the trailing gutter; '
            'cardRight=$cardRight btnRight=$btnRight',
      );

      // Still wrapped in an Align(centerEnd) — structural guard against a
      expect(
        find.ancestor(of: btn, matching: find.byType(IntrinsicWidth)),
        findsOneWidget,
      );
    });

    testWidgets('Active Track CTA is content-hugging and end-aligned', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(repo: _threeTabRepo()));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('active-track-order-ip-1'));
      final card = find.byKey(const Key('active-request-card-ip-1'));
      final btnSize = tester.getSize(btn);
      final cardSize = tester.getSize(card);

      expect(
        btnSize.width < cardSize.width * 0.6,
        isTrue,
        reason:
            'Track CTA must hug content, got '
            '${btnSize.width} of ${cardSize.width}',
      );
      expect(
        find.ancestor(of: btn, matching: find.byType(IntrinsicWidth)),
        findsOneWidget,
      );
    });

    // DEFECT 1 — the create-request top plus must be the filled-navy CTA with a
    testWidgets('top create-request plus uses primary fill + onPrimary icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), onCreateRequest: () {}),
      );
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byKey(const Key('client-home-greeting-add')),
      );
      final scheme = Theme.of(context).colorScheme;

      final iconButton = tester.widget<IconButton>(
        find.byKey(const Key('client-home-greeting-add')),
      );
      final style = iconButton.style!;
      const lightStates = <WidgetState>{};
      final bg = style.backgroundColor!.resolve(lightStates);
      final fg = style.foregroundColor!.resolve(lightStates);

      // Navy fill from primary, white icon from onPrimary — matches Figma.
      expect(bg, scheme.primary);
      expect(fg, scheme.onPrimary);
      // And NOT the muted-purple onSecondaryContainer the reviewer proposed.
      expect(fg, isNot(scheme.onSecondaryContainer));
    });
  });
}
