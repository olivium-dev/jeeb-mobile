import 'package:flutter/widgets.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/dev_chat_preview_screen.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';

import '../dev_screen_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Profiles, Reviews & Chat" — one catalog group covering the customer /
// delivery-man profiles, the reviews list, the order chat detail, and the
// debug-only dev chat preview. Each DevScreenState mirrors one `testWidgets`
// case in the matching integration_test/screens/<file>_test.dart (screenshot
// suffix → state id, locale → state locale, the pumped widget → the builder).
//
// All fakes/fixtures below are ported inline and privatised from those tests;
// nothing is imported from test/ or integration_test/.
// ─────────────────────────────────────────────────────────────────────────────

// ── reviews-list fakes (from reviews_list_test.dart) ─────────────────────────

/// Scripted [ReviewsRepository] serving one fixed page. The non-empty
/// `jeeberId` on [ReviewsListScreen] takes the direct build path, so no DI /
/// network is needed.
class _FakeReviewsRepo implements ReviewsRepository {
  const _FakeReviewsRepo(this._page);

  final ReviewsPage _page;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async =>
      _page;

  @override
  Future<void> reportReview(String reviewId) async {}
}

ReviewsListScreen _reviews(ReviewsPage page) => ReviewsListScreen(
      jeeberId: 'jeeber-001',
      repository: _FakeReviewsRepo(page),
    );

const _reviewRows = <ReviewItem>[
  ReviewItem(
    id: 'rev-1',
    reviewerFirstName: 'Sami',
    score: 5,
    timestamp: '2026-07-01T10:00:00Z',
    body: 'Super fast and careful with the package.',
  ),
  ReviewItem(
    id: 'rev-2',
    reviewerFirstName: 'Lina',
    score: 4,
    timestamp: '2026-06-28T18:30:00Z',
    body: 'Friendly and on time.',
  ),
  ReviewItem(
    id: 'rev-3',
    reviewerFirstName: 'Omar',
    score: 5,
    timestamp: '2026-06-25T09:15:00Z',
  ),
];

// ── delivery-man-profile fixtures (from delivery_man_profile_test.dart) ──────

DeliveryReviewData _dmReview(
  String id,
  String name,
  int rating,
  String body,
  int days,
) =>
    DeliveryReviewData(
      id: id,
      reviewerName: name,
      rating: rating.toDouble(),
      body: body,
      daysAgo: days,
      isVerified: true,
      helpfulCount: rating,
    );

const _dmName = 'Kamal Hajj';

// ── chat-detail fakes (from chat_detail_test.dart) ───────────────────────────

/// In-memory gateway serving a fixed accepted thread. No polling, empty event
/// stream — a live preview with zero runaway timers.
class _SeededChatGateway extends ChatGateway {
  _SeededChatGateway(this._history, this._phase);

  final List<DeliveryChatMessage> _history;
  final ConversationPhase _phase;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      List.of(_history);

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async => _phase;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}

/// A populated, accepted 1:1 conversation: incoming + outgoing bubbles plus the
/// system `offerAccepted` marker so the banner + composer render.
List<DeliveryChatMessage> _acceptedThread() => [
      DeliveryChatMessage.text(
        id: 'm-1',
        author: ChatAuthor.them,
        sentAt: DateTime.utc(2026, 5, 17, 12, 0),
        status: MessageStatus.delivered,
        text: 'Hi, I can bring your order in about 20 minutes.',
      ),
      DeliveryChatMessage.text(
        id: 'm-2',
        author: ChatAuthor.me,
        sentAt: DateTime.utc(2026, 5, 17, 12, 1),
        status: MessageStatus.read,
        text: 'Great, thank you Kamal!',
      ),
      DeliveryChatMessage.offerAccepted(
        id: 'sys-1',
        sentAt: DateTime.utc(2026, 5, 17, 12, 2),
        payload: const SystemOfferPayload(
          offerId: 'offer-1',
          jeeberId: 'jeeber-kamal',
          jeeberName: 'Kamal Hajj',
        ),
      ),
    ];

/// Builds a LIVE [ChatScreen] over a freshly-seeded [ChatCubit]. The
/// `ChatScreen(cubit:)` path does not call `load()`, so we kick it off here
/// (fire-and-forget — the cubit emits and the timeline populates on the next
/// frame). The gateway does not poll, so there are no pending timers.
Widget _chatDetail() {
  final cubit = ChatCubit(
    deliveryId: 'DLV-1',
    gateway: _SeededChatGateway(_acceptedThread(), ConversationPhase.accepted),
    pickerService: StubPhotoPickerService(),
  );
  cubit.load();
  return ChatScreen(
    deliveryId: 'DLV-1',
    counterpartName: 'Kamal Hajj',
    cubit: cubit,
  );
}

// ── the group ────────────────────────────────────────────────────────────────

/// Entries sorted by title: Chat, Customer Profile, Delivery Man Profile,
/// Dev Chat Preview, Reviews List.
final List<DevScreenEntry> profilesChatScreens = <DevScreenEntry>[
  // Chat (order-chat / chat-detail).
  DevScreenEntry(
    id: 'chat-detail',
    title: 'Chat',
    group: 'Profiles, Reviews & Chat',
    keywords: const <String>[
      'chat',
      'messages',
      'conversation',
      'thread',
      'order chat',
      'composer',
      'delivery',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Populated accepted thread (EN)',
        locale: const Locale('en'),
        builder: (_) => _chatDetail(),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Populated accepted thread (AR)',
        locale: const Locale('ar'),
        builder: (_) => _chatDetail(),
      ),
    ],
  ),

  // Customer Profile — pure view-data screen, no cubit/repo.
  DevScreenEntry(
    id: 'customer-profile',
    title: 'Customer Profile',
    group: 'Profiles, Reviews & Chat',
    keywords: const <String>[
      'profile',
      'customer',
      'account',
      'verified',
      'rating',
      'email',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'rated-en',
        label: 'Rated verified customer (EN)',
        locale: const Locale('en'),
        builder: (_) => const CustomerProfileScreen(
          data: CustomerProfileViewData(
            name: 'Sami Fawaz',
            email: 'sami@example.com',
            isVerified: true,
            rating: 4.8,
            ratingCount: 42,
          ),
        ),
      ),
      DevScreenState(
        id: 'jeeber-ar',
        label: 'Jeeber customer (AR)',
        locale: const Locale('ar'),
        builder: (_) => const CustomerProfileScreen(
          data: CustomerProfileViewData(
            name: 'Kamal Hajj',
            email: 'kamal@example.com',
            isVerified: true,
            isJeeber: true,
            rating: 4.9,
            ratingCount: 130,
          ),
        ),
      ),
    ],
  ),

  // Delivery Man Profile — pure view-data screen, no cubit/repo.
  DevScreenEntry(
    id: 'delivery-man-profile',
    title: 'Delivery Man Profile',
    group: 'Profiles, Reviews & Chat',
    keywords: const <String>[
      'profile',
      'jeeber',
      'delivery man',
      'driver',
      'reviews',
      'availability',
      'rating',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'with-reviews-en',
        label: 'With reviews (EN)',
        locale: const Locale('en'),
        builder: (_) => DeliveryManProfileScreen(
          data: DeliveryManProfileViewData(
            name: _dmName,
            rating: 4.3,
            reviewCount: 3,
            location: 'Hamra, Beirut',
            isAvailable: true,
            jeeberId: 'user-jeeber-002',
            reviews: [
              _dmReview('r1', 'Sami', 5, 'Fast and polite. Great delivery!', 2),
              _dmReview('r2', 'Nadia', 4, 'On time, package intact.', 5),
              _dmReview('r3', 'Omar', 4, 'Good communication throughout.', 9),
            ],
          ),
        ),
      ),
      DevScreenState(
        id: 'no-reviews-ar',
        label: 'No reviews / cold-start (AR)',
        locale: const Locale('ar'),
        builder: (_) => const DeliveryManProfileScreen(
          data: DeliveryManProfileViewData(
            name: _dmName,
            rating: 0,
            reviewCount: 0,
            location: 'Hamra, Beirut',
            isAvailable: false,
            jeeberId: 'user-jeeber-002',
            reviews: [],
          ),
        ),
      ),
    ],
  ),

  // Dev Chat Preview — debug-only Figma chat states host.
  DevScreenEntry(
    id: 'dev-chat',
    title: 'Dev Chat Preview',
    group: 'Profiles, Reviews & Chat',
    keywords: const <String>[
      'chat',
      'preview',
      'figma',
      'broadcasting',
      'accepted',
      'delivery man',
      'design',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'broadcasting-en',
        label: 'Broadcasting offers feed (EN)',
        locale: const Locale('en'),
        builder: (_) => const DevChatPreviewScreen(selector: 'broadcasting'),
      ),
      DevScreenState(
        id: 'accepted-en',
        label: 'Accepted client thread (EN)',
        locale: const Locale('en'),
        builder: (_) => const DevChatPreviewScreen(selector: 'accepted'),
      ),
      DevScreenState(
        id: 'delivery-man-en',
        label: 'Delivery-man thread (EN)',
        locale: const Locale('en'),
        builder: (_) => const DevChatPreviewScreen(selector: 'dm'),
      ),
    ],
  ),

  // Reviews List (JM-068) — self-owned BlocProvider + scripted repo seam.
  DevScreenEntry(
    id: 'reviews-list',
    title: 'Reviews List',
    group: 'Profiles, Reviews & Chat',
    keywords: const <String>[
      'reviews',
      'ratings',
      'aggregate',
      'cold start',
      'new badge',
      'feedback',
      'JM-068',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Populated with aggregate (EN)',
        locale: const Locale('en'),
        builder: (_) => _reviews(const ReviewsPage(
          reviews: _reviewRows,
          page: 1,
          totalPages: 1,
          reviewCount: 37,
          averageScore: 4.7,
        )),
      ),
      DevScreenState(
        id: 'cold-start-en',
        label: 'Cold-start New badge, hidden score (EN)',
        locale: const Locale('en'),
        builder: (_) => _reviews(const ReviewsPage(
          reviews: [
            ReviewItem(
              id: 'rev-1',
              reviewerFirstName: 'Sami',
              score: 5,
              timestamp: '2026-07-01T10:00:00Z',
              body: 'First delivery, went great!',
            ),
          ],
          page: 1,
          totalPages: 1,
          coldStart: true,
          reviewCount: 3,
        )),
      ),
      DevScreenState(
        id: 'empty-ar',
        label: 'Empty state (AR)',
        locale: const Locale('ar'),
        builder: (_) => _reviews(const ReviewsPage(
          reviews: [],
          page: 1,
          totalPages: 1,
          reviewCount: 0,
        )),
      ),
    ],
  ),
];
