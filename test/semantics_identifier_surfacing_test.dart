// Regression guards for Semantics auto-merge defects.

import 'dart:io';
import 'dart:typed_data';

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

import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart';
import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_service_area_step.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/jeeber_feed_card.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_man_meta_row.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_l10n.dart';
import 'package:jeeb_mobile/features/reviews/presentation/widgets/review_row.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';

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
  // Reset header expansion state between tests.
  setUp(ChatHeaderExpansionStore.instance.reset);
  setUpAll(_loadArbs);

  // Large viewport to prevent culling.
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

        expect(
          find.bySemanticsIdentifier('request_type_current_location_label'),
          findsOneWidget,
          reason: 'The current-location label identifier must remain queryable.',
        );
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
        final message = DeliveryChatMessage.text(
          id: 'm-42',
          author: ChatAuthor.me,
          sentAt: DateTime(2026, 6, 12, 10, 30),
          status: MessageStatus.read,
          text: 'on my way',
        );
        await tester.pumpWidget(_harness(ChatMessageBubble(message: message)));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('chat_detail_message_m-42'),
          findsOneWidget,
          reason: 'The per-message identifier must remain queryable.',
        );
        expect(
          find.bySemanticsIdentifier('chat_detail_message_read'),
          findsOneWidget,
          reason: 'The read double-tick identifier must surface as its own '
              'node (was merged into the per-message node before the fix).',
        );
      },
    );
  });

  group('A3 RepliesCard (screen 14 / JM-027)', () {
    testWidgets(
      'surfaces the avatar-stack id and BOTH JM-027 CTA ids '
      '(replies_check_offers_cta + replies_accept_cta) as distinct nodes',
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
          _harness(
            RepliesCard(
              request: request,
              onCheckOffers: () {},
              onAccept: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('orders_replies_avatar_stack_rep-7'),
          findsOneWidget,
          reason: 'The avatar-stack identifier must remain queryable.',
        );
        expect(
          find.bySemanticsIdentifier('replies_check_offers_cta'),
          findsOneWidget,
          reason: 'JM-027 replies_check_offers_cta must surface as its own '
              'node (explicitChildNodes boundary keeps it un-merged).',
        );
        expect(
          find.bySemanticsIdentifier('replies_accept_cta'),
          findsOneWidget,
          reason: 'JM-027 replies_accept_cta must surface as its own node.',
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

        expect(
          find.bySemanticsIdentifier('orders_active_card_act-3'),
          findsOneWidget,
          reason: 'The active-card identifier must remain queryable.',
        );
        expect(
          find.bySemanticsIdentifier('orders_track_order_button_act-3'),
          findsOneWidget,
          reason: 'The Track-order button identifier must surface as its own '
              'node (was merged into the card node before the fix).',
        );
      },
    );
  });

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

  group('A3 screen-level (ClientHomeScreen Replies tab / JM-027)', () {
    testWidgets(
      'replies_check_offers_cta + replies_accept_cta are queryable within '
      'the full Replies tab',
      (tester) async {
        await tester.pumpWidget(_clientHome(initialTab: ClientHomeTab.replies));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('orders_replies_avatar_stack_rep-1'),
          findsOneWidget,
        );
        // JM-027 AC1: Check Offers CTA addressable from the host screen.
        expect(
          find.bySemanticsIdentifier('replies_check_offers_cta'),
          findsOneWidget,
          reason: 'JM-027 replies_check_offers_cta must be addressable from '
              'the host ClientHomeScreen Replies tab, as the flow targets it.',
        );
        // JM-027 AC2: Accept CTA addressable from the host screen.
        expect(
          find.bySemanticsIdentifier('replies_accept_cta'),
          findsOneWidget,
          reason: 'JM-027 replies_accept_cta must be addressable from the '
              'host ClientHomeScreen Replies tab, as the flow targets it.',
        );
      },
    );
  });

  group('B1 DeliveryTrackingPanel stepper (screen 16 / Figma 56560:1772)', () {
    testWidgets(
      'surfaces BOTH the panel-root id and the progress-stepper id as '
      'distinct nodes',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const DeliveryTrackingPanel(
              info: DeliveryTrackingInfo(
                deliveryId: 'd-16',
                currentStage: TrackingStage.picked,
                stageTimestamps: {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('tracking_status_panel'),
          findsOneWidget,
          reason: 'The panel-root identifier must remain queryable.',
        );
        expect(
          find.bySemanticsIdentifier('tracking_progress_stepper'),
          findsOneWidget,
          reason: 'The progress-stepper identifier must surface as its own '
              'node (was folded into tracking_status_panel before the fix).',
        );
      },
    );
  });

  group('B2 RatingScreen footer (screen 17 / Figma 56614:20132)', () {
    testWidgets(
      'surfaces rating_root + rating_submit_cta and no skip control',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const RatingScreen(deliveryId: 'd-17', rateeName: 'Sara'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('rating_root'),
          findsOneWidget,
          reason: 'The screen signature id must surface on the /feedback '
              'variant too (AC4).',
        );
        expect(
          find.bySemanticsIdentifier('rating_submit_cta'),
          findsOneWidget,
          reason: 'The submit-button identifier must surface as its own node '
              '(explicit Semantics boundary, not folded into rating_root).',
        );
        expect(
          find.bySemanticsIdentifier('rating_skip_cta'),
          findsNothing,
          reason: 'The mandatory rating path must expose no skip control.',
        );
        expect(
          find.bySemanticsIdentifier('feedback_close_button'),
          findsNothing,
          reason: 'The close (X) affordance was removed (D56).',
        );
      },
    );
  });

  group('B3 DmOnboardingServiceAreaStep (screen 22 / Figma 56591:5337)', () {
    testWidgets(
      'surfaces the select-location row, location-value, and map-pin as '
      'distinct nodes',
      (tester) async {
        final cubit = DmOnboardingCubit(
          pickerService:
              StubPhotoPickerService(cameraPayload: Uint8List(8)),
          gateway: FakeDmOnboardingGateway(),
          initialStep: DmOnboardingStep.serviceArea,
        );
        addTearDown(cubit.close);
        await tester.pumpWidget(
          _harness(
            BlocProvider<DmOnboardingCubit>.value(
              value: cubit,
              child: const DmOnboardingServiceAreaStep(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('service_area_select_location'),
          findsOneWidget,
          reason: 'The select-location row identifier must remain queryable.',
        );
        expect(
          find.bySemanticsIdentifier('dm_onboarding_location_value'),
          findsOneWidget,
          reason: 'The location-value identifier must surface as its own node.',
        );
        expect(
          find.bySemanticsIdentifier('service_area_map_pin'),
          findsOneWidget,
          reason: 'The home-base map pin must surface as its own node.',
        );
        expect(
          find.bySemanticsIdentifier('dm_onboarding_distance_slider'),
          findsNothing,
          reason: 'The distance slider was removed (D51).',
        );
      },
    );
  });

  group('B4 JeeberFeedCard card + accepted action (screen 26 — lock)', () {
    testWidgets(
      'card id and accepted-action id are both independently queryable',
      (tester) async {
        final request = DeliveryRequest(
          id: 'feed-26',
          pickup:
              const RequestLocation(label: 'Hamra', latitude: 0, longitude: 0),
          dropoff:
              const RequestLocation(label: 'Verdun', latitude: 0, longitude: 0),
          tier: JeeberRequestTier.flash,
          estimatedDistanceKm: 3,
          potentialEarnings: 4,
          currency: 'USD',
          expiresAt: DateTime(2030),
          senderName: 'Sami Fawaz',
          feedStatus: JeeberFeedItemStatus.accepted,
          nextDeliveryAction: JeeberDeliveryAction.orderPicked,
        );
        await tester.pumpWidget(
          _harness(
            JeeberFeedCard(
              request: request,
              onTap: () {},
              onAdvanceStatus: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('jeeber_feed_request_card_feed-26'),
          findsOneWidget,
          reason: 'The card identifier must be queryable.',
        );
        expect(
          find.bySemanticsIdentifier('jeeber_feed_request_action_feed-26'),
          findsOneWidget,
          reason: 'The accepted-action identifier must surface as its own '
              'node alongside the card id (explicitChildNodes lock).',
        );
      },
    );
  });

  group('B5 DeliveryManMetaRow rating + availability (screen 27 — lock)', () {
    testWidgets(
      'rating-summary id and availability id are both independently queryable',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DeliveryManMetaRow(
                  icon: Icons.star,
                  text: '4.8 (12)',
                  semanticsId: 'delivery_man_profile_rating_summary',
                ),
                DeliveryManMetaRow(
                  icon: Icons.location_on,
                  text: 'Beirut · Available',
                  semanticsId: 'delivery_man_profile_availability',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('delivery_man_profile_rating_summary'),
          findsOneWidget,
          reason: 'The rating-summary identifier must be queryable.',
        );
        expect(
          find.bySemanticsIdentifier('delivery_man_profile_availability'),
          findsOneWidget,
          reason: 'The availability identifier must be queryable as its own '
              'node (identifier-only + container lock).',
        );
      },
    );
  });

  group('C1 OrderSummaryPinnedHeader leaves (screen 32 / JM-031)', () {
    testWidgets(
      'surfaces the root id AND every display-leaf field id as distinct nodes',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const OrderSummaryPinnedHeader(
              info: DeliveryTrackingInfo(
                deliveryId: 'd-32',
                currentStage: TrackingStage.inTransit,
                stageTimestamps: {},
                price: 12.5,
                currency: 'USD',
                jeeberName: 'Kamal',
                tier: 'express',
                etaMinutes: 8,
                itemSummary: 'painkillers',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('order_summary_pinned'),
          findsOneWidget,
          reason: 'The pinned-summary root id must remain queryable.',
        );
        for (final id in const [
          'order_summary_jeeber_name',
          'order_summary_price',
          'order_summary_tier',
          'order_summary_eta',
          'order_summary_cash_label',
        ]) {
          expect(
            find.bySemanticsIdentifier(id),
            findsOneWidget,
            reason: '$id is a display leaf — it must surface as its own node, '
                'not be folded into order_summary_pinned (JM-049 class).',
          );
        }
      },
    );
  });

  group('C2 ReviewRow attribution leaf (JM-068)', () {
    testWidgets(
      'surfaces the row id, the display-leaf reviewer-name id, and the '
      'report CTA id as distinct nodes',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            Builder(
              builder: (context) => ReviewRow(
                review: const ReviewItem(
                  id: 'rev-9',
                  reviewerFirstName: 'Sara',
                  score: 5,
                  timestamp: '2026-06-20T10:00:00Z',
                  body: 'Fast and friendly',
                ),
                copy: ReviewsL10n.of(context),
                onReport: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('review_rev-9'),
          findsOneWidget,
          reason: 'The per-row id must remain queryable.',
        );
        expect(
          find.bySemanticsIdentifier('review_rev-9_reviewer_name'),
          findsOneWidget,
          reason: 'The reviewer-name display leaf must surface as its own node '
              '(was folded into review_rev-9 before the fix).',
        );
        expect(
          find.bySemanticsIdentifier('review_rev-9_report_cta'),
          findsOneWidget,
          reason: 'The D27 report CTA must surface as its own node.',
        );
      },
    );
  });
}

/// Builds a ClientHomeScreen with Replies populated.
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
