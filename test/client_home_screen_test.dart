import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:omds/omds.dart';

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
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

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
  void Function(Tier?)? onCreateRequest,
  Locale locale = const Locale('en'),
  ClientHomeTab initialTab = ClientHomeTab.inProgress,
}) {
  final screen = ClientHomeScreen(
    initialTab: initialTab,
    onOpenRequest: onOpenRequest,
    onTrack: onTrack,
    onCreateRequest: onCreateRequest,
  );
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
        child: screen,
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
      offerStatusRequests: [
        ClientHomeRequest(
          id: 'status-1',
          title: 'Status-filtered request',
          displayId: 'ORD-STATUS',
          destinationLabel: 'Hamra',
          itemsSummary: 'Documents for delivery',
          status: ClientRequestStatus.searching,
          offerStatuses: {
            ClientOfferStatus.pending,
            ClientOfferStatus.submitted,
            ClientOfferStatus.edited,
            ClientOfferStatus.accepted,
            ClientOfferStatus.withdrawn,
            ClientOfferStatus.expired,
            ClientOfferStatus.superseded,
          },
        ),
      ],
    ),
    latency: Duration.zero,
  );
}

/// Opens the sheet, stages [status], commits it — the sequence that replaced
/// the old "More segment pops with a status" shortcut.
Future<void> _applyStatus(WidgetTester tester, ClientOfferStatus status) async {
  await tester.tap(find.bySemanticsIdentifier('orders_filter_open'));
  await tester.pumpAndSettle();
  final row = find.bySemanticsIdentifier('offer_status_filter_${status.name}');
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsIdentifier('orders_filter_apply'));
  await tester.pumpAndSettle();
}

ClientHomeRepository _expiredStatusRepo() {
  return InMemoryClientHomeRepository.fromSnapshot(
    const ClientHomeSnapshot(
      // One pending row so the filter chrome is disclosed at all.
      pending: [
        ClientHomeRequest(
          id: 'pen-x',
          title: 'ORD-90001',
          displayId: 'ORD-90001',
          destinationLabel: 'Hamra',
          itemsSummary: 'Milk',
          status: ClientRequestStatus.searching,
          tier: ClientRequestTier.express,
        ),
      ],
      offerStatusRequests: [
        ClientHomeRequest(
          id: 'expired-short',
          title: 'Short',
          displayId: 'ORD-1',
          destinationLabel: 'A',
          itemsSummary: 'Milk',
          status: ClientRequestStatus.searching,
          offerStatuses: {ClientOfferStatus.expired},
        ),
        ClientHomeRequest(
          id: 'expired-medium',
          title: 'Medium expired request',
          displayId: 'ORD-22222',
          destinationLabel: 'Hamra',
          itemsSummary: 'Documents and groceries',
          status: ClientRequestStatus.searching,
          offerStatuses: {ClientOfferStatus.expired},
        ),
        ClientHomeRequest(
          id: 'expired-long',
          title: 'Very long expired request title',
          displayId: 'ORD-333333333',
          destinationLabel: 'Ashrafieh to Hamra',
          itemsSummary: 'One large parcel and several fragile items',
          status: ClientRequestStatus.searching,
          offerStatuses: {ClientOfferStatus.expired},
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
          onCreateRequest: (_) {},
          initialTab: ClientHomeTab.all,
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
      expect(find.bySemanticsIdentifier('client_home_mic_cta'), findsOneWidget);
      // Progressive disclosure: nothing to filter, so the whole filter row is
      // absent — the create hero owns the screen.
      expect(find.bySemanticsIdentifier('orders_filter_open'), findsNothing);
      expect(
        find.bySemanticsIdentifier('orders_home_replies_tab'),
        findsNothing,
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

      expect(find.text('Your requests'), findsNothing);
      expect(find.byKey(const Key('client-home-requests-header')), findsNothing);
      expect(find.byKey(const Key('client-home-filter-pills')), findsNothing);
      // NOT the hero prompt's question: the prompt is permanent now, so an
      // E1 tile that repeated it would print the same words twice.
      expect(find.text('Ready when you are'), findsOneWidget);
      expect(find.text('What do you need?'), findsNothing);
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
          onCreateRequest: (_) => taps += 1,
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
        isSemantics(identifier: 'orders_active_card_r-1'),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('active-track-order-r-1'))),
        isSemantics(
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
          onCreateRequest: (_) {},
          initialTab: ClientHomeTab.pendingRequests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('جاهزون متى ما أردت'), findsOneWidget);
      expect(find.text('ماذا تحتاج؟'), findsNothing);
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
        // D3 bidi: card titles render inside a first-strong isolate, so the
        // raw id is a SUBSTRING of the rendered text.
        expect(find.textContaining('ORD-23470'), findsOneWidget);
        expect(find.text('Express'), findsOneWidget);
        expect(find.text('Track my order'), findsNothing);
        expect(find.text('Ordered'), findsNothing);
      },
    );

    testWidgets(
      'Replies (screen 14 / JM-027) shows the order id, +N overflow, and the '
      'View-offers + Accept pills with both contract identifiers',
      (tester) async {
        await tester.pumpWidget(
          _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.replies),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
        expect(find.text('+6'), findsOneWidget);
        expect(find.text('View offers'), findsOneWidget);
        // D6: Accept is a REAL button again — the invisible card-wide accept
        // was a mis-tap hazard on a money action.
        expect(find.byKey(const Key('replies-accept-rep-1')), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);

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
      'the section header carries the filter disc and the frozen replies id',
      (tester) async {
        await tester.pumpWidget(
          _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.all),
        );
        await tester.pumpAndSettle();

        final handle = tester.ensureSemantics();
        // The three shape-shifting segments are gone; one disc replaces them.
        for (final id in const <String>[
          'orders_filter_inProgress',
          'orders_filter_pendingRequests',
          'orders_filter_replies',
          'orders_filter_more',
        ]) {
          expect(find.bySemanticsIdentifier(id), findsNothing);
        }
        expect(find.bySemanticsIdentifier('orders_filter_open'), findsOneWidget);
        expect(find.text('Your requests'), findsOneWidget);
        // JM-023 / JM-027's coined alias, re-homed onto the replies badge.
        expect(
          find.bySemanticsIdentifier('orders_home_replies_tab'),
          findsOneWidget,
        );
        expect(find.text('1 reply'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('the replies badge is tappable and applies the replies bucket', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.all),
      );
      await tester.pumpAndSettle();

      final badge = find.bySemanticsIdentifier('orders_home_replies_tab');
      expect(
        tester.getSemantics(badge).getSemanticsData().hasAction(
          SemanticsAction.tap,
        ),
        isTrue,
      );
      // Both lists are on screen before the tap.
      expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
      expect(find.byKey(const Key('pending-requests-tab-list')), findsOneWidget);

      await tester.tap(badge);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
      expect(find.byKey(const Key('pending-requests-tab-list')), findsNothing);
      expect(find.text('Has replies'), findsOneWidget);
      handle.dispose();
    });
  });

  // JEBV4-298 (E24/Q-086): the Requests bottom-nav tab is the ON-HOLD surface
  // only. The accepted-onward In-Progress live-tracking surface was relocated
  // to the Delivery tab (its Active order detail exposes map/ETA/Track via
  // `/orders/:id/tracking`). These lock the residual literal-DoD fix.
  group('ClientHomeScreen Requests = on-hold only (JEBV4-298)', () {
    testWidgets('widget default landing bucket is the merged list', (
      tester,
    ) async {
      // One list means nothing to land on: the default is the merged bucket,
      // never the relocated In-Progress surface.
      expect(const ClientHomeScreen().initialTab, ClientHomeTab.all);
    });

    testWidgets(
      'the merged list renders replies above pending, with no legacy chips',
      (tester) async {
        await tester.pumpWidget(
          _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.all),
        );
        await tester.pumpAndSettle();

        for (final key in const <Key>[
          Key('client-home-tab-inProgress'),
          Key('client-home-tab-pendingRequests'),
          Key('client-home-tab-replies'),
          Key('client-home-tab-more'),
          Key('client-home-filter-row'),
          Key('client-home-filter-clear'),
        ]) {
          expect(find.byKey(key), findsNothing);
        }

        // Both halves on one list, replies pinned first — they need action.
        final replies = find.byKey(const Key('replies-card-rep-1'));
        final pending = find.byKey(const Key('pending-requests-tab-list'));
        expect(replies, findsOneWidget);
        expect(pending, findsOneWidget);
        expect(
          tester.getRect(replies).top,
          lessThan(tester.getRect(pending).top),
        );
        // The accepted-onward surface still belongs to the Delivery tab.
        expect(find.byKey(const Key('active-request-card-ip-1')), findsNothing);
      },
    );

    testWidgets('the filter disc opens the complete offer-status guide', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.all),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('orders_filter_open'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('offer_status_info_sheet'),
        findsOneWidget,
      );
      expect(find.text('Filter requests'), findsWidgets);
      // The bucket row sits above the unchanged status groups.
      for (final label in <String>['All', 'Awaiting offers', 'Has replies']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Show'), findsOneWidget);
      for (final status in <String>[
        'Pending',
        'Submitted',
        'Edited',
        'Accepted',
        'Withdrawn',
        'Expired',
        'Not selected',
      ]) {
        expect(find.text(status), findsWidgets);
      }
      expect(
        find.text(
          'Another offer was accepted, so this offer was not selected.',
        ),
        findsOneWidget,
      );
      expect(find.text('Superseded'), findsNothing);
      expect(find.text('A newer version replaced this offer.'), findsNothing);

      final withdrawn = find.bySemanticsIdentifier(
        'offer_status_filter_withdrawn',
      );
      await tester.ensureVisible(withdrawn);
      await tester.pumpAndSettle();
      await tester.tap(withdrawn);
      await tester.pumpAndSettle();

      // Staged, not committed: the sheet stays up until the apply CTA fires.
      expect(
        find.bySemanticsIdentifier('offer_status_info_sheet'),
        findsOneWidget,
      );
      expect(find.text('Show 1 request'), findsOneWidget);
      await tester.tap(find.bySemanticsIdentifier('orders_filter_apply'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('offer_status_info_sheet'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('offer_status_request_status-1'),
        findsOneWidget,
      );
      expect(find.text('Withdrawn'), findsWidgets);
      expect(find.byKey(const Key('pending-requests-tab-list')), findsNothing);

      // D7: the applied pill's ✕ is the always-visible way back out.
      await tester.tap(
        find.bySemanticsIdentifier('orders_filter_pill_status_clear'),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pending-requests-tab-list')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_status_request_status-1'),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('populated status lists reserve bottom navigation clearance', (
      tester,
    ) async {
      const navInset = 48.0;
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: navInset * dpr);
      tester.view.padding = FakeViewPadding(bottom: navInset * dpr);
      addTearDown(tester.view.reset);

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.all),
      );
      await tester.pumpAndSettle();

      await _applyStatus(tester, ClientOfferStatus.expired);
      handle.dispose();

      final list = tester.widget<ListView>(
        find.byKey(const Key('client-home-ready-list')),
      );
      // Nav inset + the tail that clears BOTH pinned surfaces: the mic's halo
      // box and the create capsule, plus a Spacing.medium breather.
      final micExtent = JeebMicHero.extentFor(
        size: JeebMicHero.sizeCompact,
        halo: true,
        arc: true,
      );
      final tailReserve =
          math.max(
            Spacing.xLarge +
                JeebMicHero.sizeCompact +
                (micExtent - JeebMicHero.sizeCompact) / 2,
            Spacing.xLarge +
                (JeebMicHero.sizeCompact - kMinInteractiveDimension) / 2 +
                kMinInteractiveDimension +
                2,
          ) +
          Spacing.medium;
      expect(
        list.padding?.resolve(TextDirection.ltr).bottom,
        navInset + tailReserve,
      );
    });

    testWidgets('expired status cards stretch to consistent list width', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(repo: _expiredStatusRepo(), initialTab: ClientHomeTab.all),
      );
      await tester.pumpAndSettle();

      await _applyStatus(tester, ClientOfferStatus.expired);

      final widths = [
        for (final id in ['expired-short', 'expired-medium', 'expired-long'])
          tester
              .getSize(find.bySemanticsIdentifier('offer_status_request_$id'))
              .width,
      ];
      expect(widths.toSet(), hasLength(1));
      handle.dispose();
    });

    testWidgets(
      'the applied "Not selected" pill renders in full at 384dp in Arabic',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(384, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _harness(
            repo: _threeTabRepo(),
            locale: const Locale('ar'),
            initialTab: ClientHomeTab.all,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsIdentifier('orders_filter_open'));
        await tester.pumpAndSettle();
        expect(find.text('غير مختار'), findsOneWidget);
        expect(
          find.text('تم قبول عرض آخر، لذلك لم يتم اختيار هذا العرض.'),
          findsOneWidget,
        );
        expect(find.text('مُستبدل'), findsNothing);
        final row = find.bySemanticsIdentifier('offer_status_filter_superseded');
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsIdentifier('orders_filter_apply'));
        await tester.pumpAndSettle();

        final rowRect = tester.getRect(
          find.byKey(const Key('client-home-filter-pills')),
        );
        final pillLabel = find.descendant(
          of: find.bySemanticsIdentifier('orders_filter_pill_status'),
          matching: find.text('غير مختار'),
        );
        final labelWidget = tester.widget<Text>(pillLabel);
        final naturalLabel = TextPainter(
          text: TextSpan(text: labelWidget.data, style: labelWidget.style),
          textDirection: TextDirection.rtl,
          maxLines: 1,
        )..layout();
        final pillRect = tester.getRect(
          find.bySemanticsIdentifier('orders_filter_pill_status'),
        );
        expect(pillRect.left, greaterThanOrEqualTo(rowRect.left));
        expect(pillRect.right, lessThanOrEqualTo(rowRect.right));
        expect(
          tester.getSize(pillLabel).width,
          greaterThanOrEqualTo(naturalLabel.width),
          reason: 'the applied status must render in full, without ellipsis',
        );
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'with an empty Pending list the merged list still shows the replies '
      '(never the relocated In-Progress surface, and with no tab hop)',
      (tester) async {
        // Pending empty: one merged list means there is nothing to advance
        // to — the replies are simply there.
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
          _harness(repo: repo, initialTab: ClientHomeTab.all),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
        expect(find.byKey(const Key('active-request-card-ip-1')), findsNothing);
        // No pending half at all, and no empty state standing in for it.
        expect(find.byKey(const Key('pending-empty')), findsNothing);
        expect(
          find.byKey(const Key('pending-requests-tab-list')),
          findsNothing,
        );
      },
    );
  });

  // The headline rule: the filter only exists once there is something to
  // filter.
  group('ClientHomeScreen progressive disclosure', () {
    testWidgets('nothing to list → no header, no disc, no pills', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          repo: InMemoryClientHomeRepository(latency: Duration.zero),
          initialTab: ClientHomeTab.all,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('client-home-requests-header')), findsNothing);
      expect(find.bySemanticsIdentifier('orders_filter_open'), findsNothing);
      expect(find.byKey(const Key('client-home-filter-pills')), findsNothing);
      // The create hero owns the screen instead.
      expect(
        find.bySemanticsIdentifier('_request_empty_state_root'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('one request → header, total count and the disc appear', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.all),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('client-home-requests-header')),
        findsOneWidget,
      );
      expect(find.text('Your requests'), findsOneWidget);
      // One reply + one pending = two rows in the merged list.
      expect(
        tester.widget<Text>(find.byKey(const Key('client-home-requests-count'))).data,
        '2',
      );
      expect(find.bySemanticsIdentifier('orders_filter_open'), findsOneWidget);
      // Nothing applied yet, so the strip carries no pill at all.
      expect(
        find.bySemanticsIdentifier('orders_filter_pill_bucket'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('orders_filter_pill_status'),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets(
      'orders_home_request_row_0 stays the FIRST PENDING row of the merged list',
      (tester) async {
        // Frozen QA contract (JM-023). Replies paint above it and must NOT
        // renumber it.
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.all),
        );
        await tester.pumpAndSettle();

        final row0 = find.bySemanticsIdentifier('orders_home_request_row_0');
        expect(row0, findsOneWidget);
        expect(
          find.descendant(
            of: row0,
            matching: find.bySemanticsIdentifier(
              'pending_requests_item_pen-1',
            ),
          ),
          findsOneWidget,
          reason: 'row 0 must wrap the pending card, never the replies card',
        );
        expect(
          find.descendant(
            of: row0,
            matching: find.byKey(const Key('replies-card-rep-1')),
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('orders_home_request_row_1'),
          findsNothing,
          reason: 'the numbering is scoped to the pending slice alone',
        );
        handle.dispose();
      },
    );

    testWidgets('a bucket filter narrows the list; its ✕ restores it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), initialTab: ClientHomeTab.all),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('orders_filter_open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsIdentifier('orders_filter_bucket_pendingRequests'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Show 1 request'), findsOneWidget);
      await tester.tap(find.bySemanticsIdentifier('orders_filter_apply'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-requests-tab-list')), findsOneWidget);
      expect(find.byKey(const Key('replies-card-rep-1')), findsNothing);
      expect(find.text('Awaiting offers'), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('orders_filter_pill_bucket_clear'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-requests-tab-list')), findsOneWidget);
      expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('orders_filter_pill_bucket'),
        findsNothing,
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
      final accept = find.byKey(const Key('replies-accept-rep-1'));
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

      // D6: Accept is now the END-most pill; View offers sits just before it.
      // The budget is the redesign's screen gutter (24) + the outlined card's
      // own padding + stroke (16 + 1.5) = 41.5. A centered or start-aligned
      // pair lands ~300px away, which is what this still catches.
      const trailingGutterBudget = 42.0;
      final acceptRight = tester.getTopRight(accept).dx;
      final btnRight = tester.getTopRight(btn).dx;
      final cardRight = tester.getTopRight(card).dx;
      expect(
        (cardRight - acceptRight) < trailingGutterBudget,
        isTrue,
        reason:
            'Accept right edge should sit at the trailing gutter; '
            'cardRight=$cardRight acceptRight=$acceptRight',
      );
      expect(
        btnRight < tester.getTopLeft(accept).dx + 1,
        isTrue,
        reason: 'View offers must precede Accept in the action row',
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
    // be the frosted-glass capsule and the floating mic must stay ORANGE, never
    // a low-emphasis slab or a disabled gray.
    testWidgets('create capsule uses hero glass; floating mic stays accent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(repo: _threeTabRepo(), onCreateRequest: (_) {}),
      );
      await tester.pumpAndSettle();

      // Two halves now: the prompt scrolls, the capsule is pinned by the mic.
      final heroFinder = find.byType(ClientHomeRequestHero);
      expect(heroFinder, findsNWidgets(2));
      final context = tester.element(heroFinder.first);
      final accent = context.jeebRoles.accent;
      final glass = Theme.of(context).extension<JeebSemanticColors>()!;

      expect(
        find.descendant(of: heroFinder, matching: find.byType(JeebGlassCard)),
        findsOneWidget,
      );
      // §4 budget: the screen now draws NO BackdropFilter at all — the header
      // actions became opaque glass circles and the pinned capsule never blurred.
      expect(
        find.descendant(of: heroFinder, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(find.byType(BackdropFilter), findsNothing);
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
        contains(
          Color.alphaBlend(
            glass.glassFillEmphasis,
            Theme.of(context).colorScheme.surface,
          ),
        ),
        reason:
            'the create capsule keeps the hero glass fill — now over an '
            'opaque surface base, so scrolled card text cannot read through '
            'the pinned capsule',
      );

      // The mic disc is the one rationed orange on this screen; it is a Stack
      // sibling of the hero, so this finder is screen-wide.
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
