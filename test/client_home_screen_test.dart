import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_glass_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_mic_hero.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_request_hero.dart';
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
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
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
      // The create surface is the mic hero's body now (the "+" icon button is
      // gone), but the frozen id — and a live tap handler on it — survive.
      expect(
        find.bySemanticsIdentifier('orders_create_request_button'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('orders_create_request_button'),
            )
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'the create surface must be tappable, not a decorative pane — a '
            'null host callback is the defect this guards',
      );
      // And the mic itself is its own, newly coined target.
      expect(
        find.bySemanticsIdentifier('client_home_mic_cta'),
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

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Replies'), findsOneWidget);
      expect(find.text('What do you need?'), findsOneWidget);
      expect(
        find.text(
          'No pending requests — say it, and offers from nearby Jeebers '
          'arrive in minutes.',
        ),
        findsOneWidget,
      );
      // MIDNIGHT E1: the CTA is the voice capsule, which now carries the empty
      // state's frozen identifier and its label. No button, no Lottie.
      expect(find.text('Create your first request'), findsNothing);
      expect(find.byType(JeebEmptyState), findsOneWidget);
      expect(find.byType(LottieBuilder), findsNothing);

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

      final cta = find.bySemanticsIdentifier(
        '_request_empty_state_new_order_button',
      );
      await tester.ensureVisible(cta);
      await tester.tap(cta);
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
      // target them by id (recon KNOWN DEBT #1 — no localized-text taps).
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
    // the tabbed redesign. The home screen now shows In Progress / Pending
    // Requests / Replies tabs instead.
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
        find.text(
          'لا توجد طلبات معلّقة — قلها، وستصلك عروض من جيبرز قريبين خلال دقائق.',
        ),
        findsOneWidget,
      );
      // The empty CTA is the capsule now; its Arabic label rides the frozen
      // Semantics node rather than a drawn button.
      expect(find.text('أنشئ أول طلب لك'), findsNothing);
      expect(
        find.bySemanticsIdentifier('_request_empty_state_new_order_button'),
        findsOneWidget,
      );
    });
  });

  // The three client "My Orders" filter variants render off one screen
  // (Figma 56535:1525 / 1783 / 2251). initialTab selects which list shows.
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
        // key 'pending-requests-tab-list' (aligned with T-MOB-007 dedicated widget).
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
      'Replies (screen 14 / JM-027) shows the order id, +N overflow, and the '
      'SINGLE View-offers pill with both contract identifiers',
      (tester) async {
        await tester.pumpWidget(
          _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.replies),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
        expect(find.text('+6'), findsOneWidget);
        expect(find.text('View offers'), findsOneWidget);
        // doc-13 P0-7: the second inline Accept button is gone; the board draws
        // one pill. `replies_accept_cta` is re-homed onto the card surface.
        expect(find.byKey(const Key('replies-accept-rep-1')), findsNothing);
        expect(find.text('Accept'), findsNothing);

        // JM-027 AC1/AC2: both CTAs carry the contract Semantics identifiers.
        // (No tap here — the Replies tab now navigates via GoRouter internally,
        // wired in the host shell; the nav legs are covered by the jm-027 Maestro
        // flow, not this MaterialApp-only widget harness.)
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
        // In-Progress live-tracking chip is no longer part of this tab bar.
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
        // JM-027's coined alias, re-homed off the kit segment (which carries
        // one identifier) onto its own node.
        expect(
          find.bySemanticsIdentifier('orders_home_replies_tab'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );
  });

  // JEBV4-298 (E24/Q-086): the Requests bottom-nav tab is the ON-HOLD surface
  // only. The accepted-onward In-Progress live-tracking surface was relocated
  // to the Delivery tab (its Active order detail exposes map/ETA/Track via
  // `/orders/:id/tracking`). These lock the residual literal-DoD fix.
  group('ClientHomeScreen Requests = on-hold only (JEBV4-298)', () {
    testWidgets('widget default landing tab is Pending Requests', (
      tester,
    ) async {
      // The production host (HomeTab) leaves initialTab at the widget default;
      // it must be Pending Requests, never the relocated In-Progress surface.
      expect(
        const ClientHomeScreen().initialTab,
        ClientHomeTab.pendingRequests,
      );
    });

    testWidgets(
      'Requests tab bar omits the In-Progress chip and renders Pending first',
      (tester) async {
        // Pump with the widget default (Pending) landing tab and a snapshot that
        // populates all three underlying lists.
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
        // "land where the content is" affordance must pick Replies, not the
        // relocated In-Progress surface.
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
  // 56535:2251). Each test locks one independently-reviewed defect.
  group('ClientHomeScreen UX parity (screens 13/14/15)', () {
    // DEFECT 2 — AR tier-label l10n leak. Under `ar` the pending-request tier
    // badge must render the Arabic ARB value (إكسبرس), NOT the leaked English
    // "Express". Tier labels are localizable copy, not dynamic data.
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
        // localized getter and that the AR ARB is actually translated.
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
    // END, not full-width. `OmdsPrimaryButton` (an AnimatedContainer) expands
    // to fill bounded width, so the card wraps it in IntrinsicWidth + Align so
    // it hugs the label and sits at the trailing gutter.
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
      // measured at 768/800 px — full-width — before the IntrinsicWidth fix).
      expect(
        btnSize.width < cardSize.width * 0.6,
        isTrue,
        reason:
            'Check Offers must hug content, got '
            '${btnSize.width} of ${cardSize.width}',
      );

      // End-aligned: right edge sits at the trailing gutter, flush with the
      // card's inner edge. `replies-card-<id>` keys the full-bleed row, so the
      // budget is the redesign's screen gutter (24) + the outlined card's own
      // padding + stroke (16 + 1.5) = 41.5. A centered or start-aligned CTA
      // lands ~300px away, which is what this still catches.
      const trailingGutterBudget = 42.0;
      final btnRight = tester.getTopRight(btn).dx;
      final cardRight = tester.getTopRight(card).dx;
      expect(
        (cardRight - btnRight) < trailingGutterBudget,
        isTrue,
        reason:
            'Check Offers right edge should sit at the trailing gutter; '
            'cardRight=$cardRight btnRight=$btnRight',
      );

      // Still wrapped in an Align(centerEnd) — structural guard against a
      // regression back to a Center/stretch layout.
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

    // DEFECT 1 (carried onto MIDNIGHT's voice capsule) — the create surface must
    // be the frosted-glass capsule with the ORANGE mic, never a low-emphasis
    // slab. The capsule fill is `glassFillEmphasis` and the mic disc is
    // `jeebRoles.accent`, so a disabled-gray regression is still caught.
    testWidgets('create-request capsule uses hero glass + accent mic', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), onCreateRequest: () {}),
      );
      await tester.pumpAndSettle();

      final heroFinder = find.byType(ClientHomeRequestHero);
      expect(heroFinder, findsOneWidget);
      final context = tester.element(heroFinder);
      final accent = context.jeebRoles.accent;
      final glass =
          Theme.of(context).extension<JeebSemanticColors>()!;

      expect(
        find.descendant(
          of: heroFinder,
          matching: find.byType(JeebGlassCapsule),
        ),
        findsOneWidget,
      );
      final fills = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: heroFinder,
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color)
          .toList();
      expect(
        fills,
        contains(glass.glassFillEmphasis),
        reason: 'the create capsule must render on the hero glass fill',
      );

      // The mic disc is the one rationed orange on this screen.
      // `DecoratedBox`, not `Container`: the kit's JeebMicHero paints the disc
      // with a bare DecoratedBox. Same assertion, current paint node.
      final micFills = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(JeebMicHero),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color)
          .toList();
      expect(
        micFills,
        contains(accent),
        reason: 'the mic disc must be jeebRoles.accent, not a disabled gray',
      );
    });
  });
}
