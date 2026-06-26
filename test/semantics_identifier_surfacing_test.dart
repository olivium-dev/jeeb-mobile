// Regression guards for the Semantics auto-merge defects
// (screens 09/12/14/15 — original CAP-1 set; 16/17/22/26/27 — this batch).
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

// --- This-batch defects (screens 16/17/22/26/27) ---
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

// --- Sprint-6 a11y sweep (JM-049 class) additions ---
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_l10n.dart';
import 'package:jeeb_mobile/features/reviews/presentation/widgets/review_row.dart';

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

        // Avatar-stack id (the one that previously survived the auto-merge).
        expect(
          find.bySemanticsIdentifier('orders_replies_avatar_stack_rep-7'),
          findsOneWidget,
          reason: 'The avatar-stack identifier must remain queryable.',
        );
        // JM-027 AC1: Check Offers CTA surfaces as its own node.
        expect(
          find.bySemanticsIdentifier('replies_check_offers_cta'),
          findsOneWidget,
          reason: 'JM-027 replies_check_offers_cta must surface as its own '
              'node (explicitChildNodes boundary keeps it un-merged).',
        );
        // JM-027 AC2: Accept CTA surfaces as its own node.
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

  // B1 (screen 16) — REPRODUCING swallow. On the pre-fix source the
  // `_TrackingStepper` Semantics has no `container: true`, so the multi-child
  // OMDSLabeledStepperProgress labels fold the `tracking_progress_stepper`
  // identifier up into the `tracking_status_panel` node and it is swallowed.
  // (Verified: `findsNothing` pre-fix → `findsOneWidget` post-fix.)
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

        // Outer panel id preserved (already had container: true).
        expect(
          find.bySemanticsIdentifier('tracking_status_panel'),
          findsOneWidget,
          reason: 'The panel-root identifier must remain queryable.',
        );
        // Previously-swallowed stepper id now surfaces.
        expect(
          find.bySemanticsIdentifier('tracking_progress_stepper'),
          findsOneWidget,
          reason: 'The progress-stepper identifier must surface as its own '
              'node (was folded into tracking_status_panel before the fix).',
        );
      },
    );
  });

  // B2 (screen 17) — JM-034: the legacy `/feedback` RatingScreen is now the
  // mandatory-compliant variant. It surfaces the W1 contract ids `rating_root`
  // + `rating_submit_cta` as distinct boundary nodes (the footer Semantics is
  // an explicit boundary so the submit id does not fold into `rating_root`),
  // and per D56 it exposes NO skip/close control (`rating_skip_cta` absent).
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
        // AC1/D56: mandatory path exposes no skip/dismiss control.
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

  // B3 (screen 22 / JM-038) — surfacing lock on the service-area step. The
  // `_SelectLocationRow` Semantics (button + label) is a merge boundary; the
  // `container + explicitChildNodes` guard keeps the nested
  // `dm_onboarding_location_value` node from being folded in, and the required
  // home-base `service_area_map_pin` must surface as its own node (JM-038 AC2).
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

        // Select-location row id surfaces.
        expect(
          find.bySemanticsIdentifier('service_area_select_location'),
          findsOneWidget,
          reason: 'The select-location row identifier must remain queryable.',
        );
        // Nested value id is not swallowed by the button-row merge boundary.
        expect(
          find.bySemanticsIdentifier('dm_onboarding_location_value'),
          findsOneWidget,
          reason: 'The location-value identifier must surface as its own node.',
        );
        // The required home-base pin surfaces (JM-038 AC2).
        expect(
          find.bySemanticsIdentifier('service_area_map_pin'),
          findsOneWidget,
          reason: 'The home-base map pin must surface as its own node.',
        );
        // D51: the distance slider is gone.
        expect(
          find.bySemanticsIdentifier('dm_onboarding_distance_slider'),
          findsNothing,
          reason: 'The distance slider was removed (D51).',
        );
      },
    );
  });

  // B4 (screen 26) — HARDENING LOCK (not a reproducing failure).
  //
  // HONESTY NOTE: in a Flutter widget test BOTH ids are ALREADY distinct nodes
  // on the pre-fix source — `Semantics(button: true)` does NOT imply
  // `mergeAllDescendantsIntoThisNode`, so the action node stays a separate
  // child of the card node and `find.bySemanticsIdentifier` finds both
  // before AND after the fix. This test therefore does NOT fail pre-fix; it
  // LOCKS IN the independent-addressability the `explicitChildNodes: true`
  // hardening guarantees, guarding against a future change that turns the
  // card into a real merge boundary (e.g. wrapping it in MergeSemantics).
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

  // B5 (screen 27) — HARDENING LOCK (not a reproducing failure).
  //
  // HONESTY NOTE: in a Flutter widget test BOTH meta-row ids are ALREADY
  // distinct nodes on the pre-fix source — the wrapper `label: text` does not
  // fold the identifier because the row Semantics is not a merge boundary, so
  // `find.bySemanticsIdentifier` finds both before AND after. The fix aligns
  // `DeliveryManMetaRow` with the proven identifier-only `_NameText` pattern
  // (drops the duplicate wrapper label, adds container: true). This test LOCKS
  // IN the independent addressability rather than reproducing a failure.
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

  // ── Sprint-6 a11y sweep (JM-049 class) ─────────────────────────────────
  //
  // C1 (screen 32 live-tracking / JM-031+JM-032) — REPRODUCING swallow.
  // `OrderSummaryPinnedHeader` wraps a `container: true` root
  // (`order_summary_pinned`) around DISPLAY-LEAF `Semantics(identifier:)`
  // nodes (`order_summary_price` / `_eta` / `_tier` / `_jeeber_name` /
  // `_cash_label`) that have NO `container: true` of their own. On the
  // pre-fix source the root container (lacking `explicitChildNodes`) folds
  // every leaf id up into the `order_summary_pinned` node, so each leaf id
  // is swallowed (`findsNothing`). The Sprint-6 fix adds
  // `explicitChildNodes: true` to the root so each leaf surfaces as its own
  // queryable node. (Verified: `findsNothing` pre-fix → `findsOneWidget`
  // post-fix for the display leaves.)
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

        // Root container id preserved.
        expect(
          find.bySemanticsIdentifier('order_summary_pinned'),
          findsOneWidget,
          reason: 'The pinned-summary root id must remain queryable.',
        );
        // Previously-swallowed display-leaf ids now surface (no container of
        // their own; recovered only by the root explicitChildNodes boundary).
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

  // C2 (JM-068 reviews) — REPRODUCING swallow. The per-row `container: true`
  // root (`review_<id>`) wraps a DISPLAY-LEAF attribution node
  // (`review_<id>_reviewer_name`, a bare `Semantics` over `Text`). Pre-fix the
  // row container folds it in (`findsNothing`); the Sprint-6
  // `explicitChildNodes: true` boundary keeps it queryable. The report CTA
  // (`review_<id>_report_cta`) wraps a real button, so it survives either way —
  // asserted here as a co-located lock.
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
        // Previously-swallowed display-leaf attribution id now surfaces.
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
