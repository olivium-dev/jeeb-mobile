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

      // Card + Track CTA carry stable Semantics identifiers so Maestro can
      // target them by id (recon KNOWN DEBT #1 — no localized-text taps).
      expect(
        tester.getSemantics(find.byKey(const Key('active-request-card-r-1'))),
        containsSemantics(identifier: 'orders_active_card_r-1'),
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('active-track-order-r-1'))),
        containsSemantics(
          identifier: 'orders_track_order_button_r-1',
          isButton: true,
        ),
      );

      await tester.tap(find.byKey(const Key('active-track-order-r-1')));
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

  // UX-parity regressions for client-home screens 13/14/15 (Figma 56535:1783 /
  // 56535:2251). Each test locks one independently-reviewed defect.
  group('ClientHomeScreen UX parity (screens 13/14/15)', () {
    // DEFECT 2 — AR tier-label l10n leak. Under `ar` the pending-request tier
    // badge must render the Arabic ARB value (إكسبرس), NOT the leaked English
    // "Express". Tier labels are localizable copy, not dynamic data.
    testWidgets(
        'Pending tier badge renders the Arabic tier label under ar locale',
        (tester) async {
      await tester.pumpWidget(_harness(
        repo: _threeTabRepo(),
        locale: const Locale('ar'),
        initialTab: ClientHomeTab.pendingRequests,
      ));
      await tester.pumpAndSettle();

      // Arabic value present, English value absent — proves the badge reads the
      // localized getter and that the AR ARB is actually translated.
      expect(find.text('إكسبرس'), findsOneWidget);
      expect(find.text('Express'), findsNothing);
    });

    testWidgets('In Progress tier badge is localized to Arabic (Flash → سريع)',
        (tester) async {
      await tester.pumpWidget(_harness(
        repo: _threeTabRepo(),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('سريع'), findsOneWidget);
      expect(find.text('Flash'), findsNothing);
    });

    // DEFECT 3 — Check Offers CTA must be a content-hugging pill pinned to the
    // END, not full-width. `OmdsPrimaryButton` (an AnimatedContainer) expands
    // to fill bounded width, so the card wraps it in IntrinsicWidth + Align so
    // it hugs the label and sits at the trailing gutter.
    testWidgets('Replies Check Offers CTA is content-hugging and end-aligned',
        (tester) async {
      await tester.pumpWidget(_harness(
        repo: _threeTabRepo(),
        initialTab: ClientHomeTab.replies,
      ));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('replies-check-offers-rep-1'));
      final card = find.byKey(const Key('replies-card-rep-1'));
      final btnSize = tester.getSize(btn);
      final cardSize = tester.getSize(card);

      // Hugs content: clearly narrower than the full card width (it was
      // measured at 768/800 px — full-width — before the IntrinsicWidth fix).
      expect(
        btnSize.width < cardSize.width * 0.6,
        isTrue,
        reason: 'Check Offers must hug content, got '
            '${btnSize.width} of ${cardSize.width}',
      );

      // End-aligned: right edge sits at the trailing gutter, flush with the
      // card's right edge minus the horizontal padding.
      final btnRight = tester.getTopRight(btn).dx;
      final cardRight = tester.getTopRight(card).dx;
      expect(
        (cardRight - btnRight) < 24,
        isTrue,
        reason: 'Check Offers right edge should sit at the trailing gutter; '
            'cardRight=$cardRight btnRight=$btnRight',
      );

      // Still wrapped in an Align(centerEnd) — structural guard against a
      // regression back to a Center/stretch layout.
      expect(
        find.ancestor(of: btn, matching: find.byType(IntrinsicWidth)),
        findsOneWidget,
      );
    });

    testWidgets('Active Track CTA is content-hugging and end-aligned',
        (tester) async {
      await tester.pumpWidget(_harness(repo: _threeTabRepo()));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('active-track-order-ip-1'));
      final card = find.byKey(const Key('active-request-card-ip-1'));
      final btnSize = tester.getSize(btn);
      final cardSize = tester.getSize(card);

      expect(
        btnSize.width < cardSize.width * 0.6,
        isTrue,
        reason: 'Track CTA must hug content, got '
            '${btnSize.width} of ${cardSize.width}',
      );
      expect(
        find.ancestor(of: btn, matching: find.byType(IntrinsicWidth)),
        findsOneWidget,
      );
    });

    // DEFECT 1 — the create-request "+" FAB must be the filled-navy CTA with a
    // WHITE icon (Figma 56535:1783), NOT a low-emphasis gray circle. The button
    // is correct-as-is: it derives fill from colorScheme.primary (navy #0B1351)
    // and the icon from colorScheme.onPrimary (white) via
    // OmdsButtonStyles.iconButtonFilled. This locks that role choice so a future
    // edit to secondaryContainer/onSecondaryContainer (which would render a
    // muted-purple icon) is caught.
    testWidgets('Create-request "+" FAB uses navy primary fill + white icon',
        (tester) async {
      await tester.pumpWidget(_harness(
        repo: _threeTabRepo(),
        onCreateRequest: () {},
      ));
      await tester.pumpAndSettle();

      final context =
          tester.element(find.byKey(const Key('client-home-greeting-add')));
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
      expect(scheme.onPrimary, const Color(0xFFFFFFFF));
      // And NOT the muted-purple onSecondaryContainer the reviewer proposed.
      expect(fg, isNot(scheme.onSecondaryContainer));
    });
  });
}
