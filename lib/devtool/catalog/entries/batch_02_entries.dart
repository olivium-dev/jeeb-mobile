import 'package:flutter/widgets.dart';

import '../../../features/cancellation/domain/cancellation_repository.dart';
import '../../../features/cancellation/domain/cancellation_result.dart';
import '../../../features/cancellation/presentation/cancellation_screen.dart';
import '../../../features/chat/data/dev_chat_fixture_gateway.dart';
import '../../../features/chat/domain/chat_gateway.dart';
import '../../../features/chat/domain/delivery_chat_message.dart';
import '../../../features/chat/presentation/chat_screen.dart';
import '../../../features/client_offers/data/fake_offers_repository.dart';
import '../../../features/client_offers/domain/offers_repository.dart';
import '../../../features/client_offers/presentation/client_offers_screen.dart';
import '../../../features/customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../../features/customer_profile/domain/customer_profile_view_data.dart';
import '../../../features/customer_profile/presentation/customer_profile_screen.dart';
import '../../../features/deep_link_targets/delivery_detail_screen.dart';
import '../../../features/deep_link_targets/kyc_status_screen.dart';
import '../../../features/deep_link_targets/rating_prompt_screen.dart';
import '../../../features/delivery_man_profile/data/dev_delivery_man_profile_fixtures.dart';
import '../../../features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import '../../../features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../catalog_models.dart';

/// Batch 02 — cancellation, chat, client_offers, customer_profile,
/// deep_link_targets, delivery_man_profile.
///
/// `deep_link_targets/chat_detail_screen.dart` (`ChatDetailScreen`) is
/// deliberately NOT cataloged here: it resolves its own [ChatGateway] inside
/// `initState` straight off the global `GetIt.instance<Dio>()` (falling back
/// to the offline dev-fixture gateway only when the app-wide `DevSeam` is
/// already driving a seeded client-home tab AND the id is one of its seeded
/// rows). There is no constructor seam to inject a local fake, so mounting it
/// here would either hit the live gateway or require mutating global
/// `DevSeam`/`kDebugMode` state as a side effect of opening the catalog —
/// exactly the "heavy infra" case the task tells us to skip rather than fake.
List<CatalogEntry> get batch02Entries => <CatalogEntry>[
      const CatalogEntry(
        feature: 'cancellation',
        screen: 'CancellationScreen',
        states: [
          CatalogState('Client reasons', _cancellationClient),
          CatalogState('Jeeber reasons', _cancellationJeeber),
        ],
      ),
      const CatalogEntry(
        feature: 'chat',
        screen: 'ChatScreen',
        states: [
          CatalogState('Broadcasting (offers arriving)', _chatBroadcasting),
          CatalogState('Accepted 1:1 thread', _chatAccepted),
          CatalogState('Sending initial request', _chatSending),
          CatalogState('Delivery-man (Jeeber) thread', _chatDeliveryMan),
          CatalogState('Empty (no messages yet)', _chatEmpty),
        ],
      ),
      const CatalogEntry(
        feature: 'client_offers',
        screen: 'ClientOffersScreen',
        states: [
          CatalogState('Loaded (3 offers)', _clientOffersLoaded),
          CatalogState('Empty (no offers yet)', _clientOffersEmpty),
          CatalogState('Error (network)', _clientOffersError),
        ],
      ),
      const CatalogEntry(
        feature: 'customer_profile',
        screen: 'CustomerProfileScreen',
        states: [
          CatalogState('Verified customer (rated)', _customerProfileRated),
          CatalogState(
            'New Jeeber (no rating yet)',
            _customerProfileUnrated,
          ),
        ],
      ),
      const CatalogEntry(
        feature: 'deep_link_targets',
        screen: 'DeliveryDetailScreen',
        states: [
          CatalogState('Order actions hub', _deliveryDetailHub),
        ],
      ),
      const CatalogEntry(
        feature: 'deep_link_targets',
        screen: 'KycStatusScreen',
        states: [
          CatalogState('Coming soon placeholder', _kycStatusPlaceholder),
        ],
      ),
      const CatalogEntry(
        feature: 'deep_link_targets',
        screen: 'RatingPromptScreen',
        states: [
          CatalogState('Coming soon placeholder', _ratingPromptPlaceholder),
        ],
      ),
      const CatalogEntry(
        feature: 'delivery_man_profile',
        screen: 'DeliveryManProfileScreen',
        states: [
          CatalogState(
            'Populated (rated, two reviews)',
            _deliveryManProfilePopulated,
          ),
          CatalogState(
            'Cold start (fewer than 5 reviews)',
            _deliveryManProfileColdStart,
          ),
        ],
      ),
    ];

// ─────────────────────────── cancellation ───────────────────────────────

/// The screen's initial build is always [CancellationIdle] regardless of the
/// repository (the repo is only hit on submit), so the meaningful designed
/// variance here is the reason list, which is driven by [isJeeber].
class _FakeCancellationRepository implements CancellationRepository {
  const _FakeCancellationRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async =>
      const CancellationResult(
        deliveryId: 'demo-delivery-001',
        feeApplied: 0,
        weeklyCount: 1,
      );
}

Widget _cancellationClient(BuildContext _) => const CancellationScreen(
      deliveryId: 'demo-delivery-001',
      isJeeber: false,
      repository: _FakeCancellationRepository(),
    );

Widget _cancellationJeeber(BuildContext _) => const CancellationScreen(
      deliveryId: 'demo-delivery-002',
      isJeeber: true,
      repository: _FakeCancellationRepository(),
    );

// ─────────────────────────────── chat ────────────────────────────────────

/// Offline gateway for the "no messages yet" designed state — a broadcasting
/// conversation before any offer card has landed. [DevChatFixtureGateway]
/// (the shipped dev-seam gateway used by every other chat state below) has no
/// zero-message fixture, so this is a small private fake mirroring its shape.
class _EmptyChatGateway extends ChatGateway {
  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      const <DeliveryChatMessage>[];

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.broadcasting;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message;

  @override
  Stream<ChatEvent> subscribe(String conversationId) => const Stream.empty();
}

Widget _chatBroadcasting(BuildContext _) => ChatScreen(
      deliveryId: 'demo-delivery-broadcasting',
      counterpartName: 'Order request',
      gateway: DevChatFixtureGateway(phase: ConversationPhase.broadcasting),
      pickerService: StubPhotoPickerService(),
    );

Widget _chatAccepted(BuildContext _) => ChatScreen(
      deliveryId: 'demo-delivery-accepted',
      counterpartName: 'Kamal Hajj',
      gateway: DevChatFixtureGateway(phase: ConversationPhase.accepted),
      pickerService: StubPhotoPickerService(),
    );

Widget _chatSending(BuildContext _) => ChatScreen(
      deliveryId: 'demo-delivery-sending',
      counterpartName: 'Order request',
      gateway: DevChatFixtureGateway(
        phase: ConversationPhase.broadcasting,
        sending: true,
      ),
      pickerService: StubPhotoPickerService(),
    );

Widget _chatDeliveryMan(BuildContext _) => ChatScreen(
      deliveryId: 'demo-delivery-jeeber',
      counterpartName: 'Sami Fawaz',
      gateway: DevChatFixtureGateway(
        phase: ConversationPhase.accepted,
        deliveryMan: true,
      ),
      pickerService: StubPhotoPickerService(),
    );

Widget _chatEmpty(BuildContext _) => ChatScreen(
      deliveryId: 'demo-delivery-empty',
      counterpartName: 'Order request',
      gateway: _EmptyChatGateway(),
      pickerService: StubPhotoPickerService(),
    );

// ────────────────────────────  client_offers ─────────────────────────────

/// Repository that fails every fetch — [FakeOffersRepository] only scripts an
/// *accept* failure, so the load-error designed state needs its own minimal
/// fake.
class _FailingOffersRepository implements OffersRepository {
  const _FailingOffersRepository();

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    throw const OffersRepositoryException(OffersFailure.network);
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    throw const OffersRepositoryException(OffersFailure.network);
  }
}

Widget _clientOffersLoaded(BuildContext _) => ClientOffersScreen(
      requestId: 'demo-request-001',
      repository: FakeOffersRepository(),
    );

Widget _clientOffersEmpty(BuildContext _) => ClientOffersScreen(
      requestId: 'demo-request-002',
      repository: FakeOffersRepository(seed: const []),
    );

Widget _clientOffersError(BuildContext _) => const ClientOffersScreen(
      requestId: 'demo-request-003',
      repository: _FailingOffersRepository(),
    );

// ────────────────────────────  customer_profile ──────────────────────────

/// Echoes the seeded [CustomerProfileViewData] back so [load] never touches
/// the network and never overwrites the designed header we pass in.
class _FakeCustomerProfileRepository implements CustomerProfileRepository {
  const _FakeCustomerProfileRepository(this._data);

  final CustomerProfileViewData _data;

  @override
  Future<CustomerProfileViewData> fetchProfile() async => _data;
}

Widget _customerProfileRated(BuildContext _) => const CustomerProfileScreen(
      data: DevCustomerProfileFixtures.sample,
      repository: _FakeCustomerProfileRepository(
        DevCustomerProfileFixtures.sample,
      ),
    );

Widget _customerProfileUnrated(BuildContext _) {
  const data = CustomerProfileViewData(
    name: 'Jad Karam',
    email: 'jad.karam@example.com',
    isVerified: false,
    isJeeber: true,
  );
  return const CustomerProfileScreen(
    data: data,
    repository: _FakeCustomerProfileRepository(data),
  );
}

// ────────────────────────────  deep_link_targets ─────────────────────────

Widget _deliveryDetailHub(BuildContext _) =>
    const DeliveryDetailScreen(deliveryId: 'demo-delivery-001');

Widget _kycStatusPlaceholder(BuildContext _) => const KycStatusScreen();

Widget _ratingPromptPlaceholder(BuildContext _) =>
    const RatingPromptScreen(deliveryId: 'demo-delivery-001');

// ────────────────────────────  delivery_man_profile ──────────────────────

Widget _deliveryManProfilePopulated(BuildContext _) =>
    const DeliveryManProfileScreen(
      data: DevDeliveryManProfileFixtures.sample,
    );

Widget _deliveryManProfileColdStart(BuildContext _) =>
    const DeliveryManProfileScreen(
      data: DeliveryManProfileViewData(
        name: 'Rana Ahmad',
        rating: 5,
        reviewCount: 2,
        location: 'Lebanon',
        isAvailable: true,
        avatarUrl: 'https://i.pravatar.cc/150?img=47',
        reviews: [
          DeliveryReviewData(
            id: 'r1',
            reviewerName: 'Sami Fawaz',
            rating: 5,
            body: 'Fast and careful with the order.',
            daysAgo: 1,
          ),
        ],
      ),
    );
