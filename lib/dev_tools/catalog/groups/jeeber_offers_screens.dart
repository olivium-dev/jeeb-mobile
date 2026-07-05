import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import 'package:jeeb_mobile/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offer.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offers_repository.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';

import '../dev_screen_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Jeeber & Offers" catalog group.
//
// Each entry mirrors one integration_test/screens/<file>_test.dart: every
// testWidgets there becomes one DevScreenState here (screenshot suffix → state
// id, locale → state locale, the pumped widget → the builder body). All fakes /
// fixtures are ported inline from those tests and privatised (leading `_`), so
// nothing leaks and there is no dependency on test/ or integration_test/. The
// dev flavor runs with GetIt UNconfigured (exactly like the tests), so every
// data/nav seam a test injected is injected here too; navigation callbacks are
// safe no-ops and poll/clock ticks are `const Stream.empty()`.
// ─────────────────────────────────────────────────────────────────────────────

// ── jeeber-request-detail ────────────────────────────────────────────────────
// The loader renders SYNCHRONOUSLY when `initial` is a non-null FeedRequest
// (cache hit — no fetch, no timers); the by-id `fetch` is a no-op.

const FeedRequest _detailRequest = FeedRequest(
  id: 'e30b7f2e-7914-402d-8dd3-e699e6775eae',
  shortLabel: 'Souq Waqif pickup',
  description: 'Two bags of groceries from the corner market, pay on pickup',
);

Widget _detail(FeedRequest request) => JeeberRequestDetailLoader(
      requestId: request.id,
      initial: request,
      fetch: () async => null,
      reportService: const ProhibitedItemReportService(),
      onDeclined: (_) {},
      onBack: () {},
    );

// ── jeeber-offer-submission ──────────────────────────────────────────────────
// The screen builds its OfferFormCubit from the injected `repository` seam and
// starts idle (no async in the constructor; submitOffer only fires on tap).

class _NoopOfferRepo implements OfferSubmissionRepository {
  const _NoopOfferRepo();

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async =>
      const OfferSubmissionResult(offerId: 'offer-1', conversationId: 'conv-1');
}

OfferSubmissionScreen _offerSubmissionScreen() => OfferSubmissionScreen(
      requestId: 'req-1',
      submissionService: const Object(),
      onWithdrawn: () {},
      repository: const _NoopOfferRepo(),
    );

// ── jeeber-onboarding ────────────────────────────────────────────────────────
// The three-step wizard shares one cubit; the screen exposes a `cubit` seam +
// `initialStep`, so we seed a DmOnboardingCubit over the StubPhotoPickerService
// + in-repo FakeDmOnboardingGateway and land directly on each step.

DmOnboardingCubit _onboardingCubit(DmOnboardingStep step) => DmOnboardingCubit(
      pickerService: StubPhotoPickerService(),
      gateway: FakeDmOnboardingGateway(),
      initialStep: step,
    );

Widget _onboardingScreen(DmOnboardingStep step) =>
    DmOnboardingScreen(cubit: _onboardingCubit(step));

// ── jeeber-active-delivery ───────────────────────────────────────────────────
// The screen creates its ActiveDeliveryCubit from the injected `repository`
// seam and calls loadDelivery() itself — landing on the AtDoor stage where the
// mark-delivered panel is surfaced. The in-memory repo touches no network.

const String _deliveryId = 'DLV-770001';

const DropOffAddress _dropOff = DropOffAddress(
  label: 'Verdun, Beirut',
  lat: 33.88,
  lng: 35.49,
  detail: 'Building 12, 3rd floor',
);

JeeberDelivery _delivery(JeeberDeliveryStatus status) => JeeberDelivery(
      id: _deliveryId,
      status: status,
      dropOff: _dropOff,
      clientName: 'Sami Fawaz',
      amountText: '10.00 USD',
    );

class _StaticActiveDeliveryRepository implements ActiveDeliveryRepository {
  _StaticActiveDeliveryRepository(this._snapshot);

  final JeeberDelivery _snapshot;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async => _snapshot;

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async =>
      to;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async =>
      JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required String filename,
  }) async =>
      'https://cdn.jeeb.app/proof/$deliveryId.jpg';
}

Widget _activeDeliveryScreen(JeeberDeliveryStatus status) =>
    ActiveDeliveryJeeberScreen(
      deliveryId: _deliveryId,
      onOpenChat: () {},
      repository: _StaticActiveDeliveryRepository(_delivery(status)),
    );

// ── jeeber-pending-offers ────────────────────────────────────────────────────
// The screen builds a SubmittedOffersCubit off the `repository` seam and calls
// load(), so injecting a scripted in-memory list avoids DI/network.

class _FakePendingRepository implements SubmittedOffersRepository {
  _FakePendingRepository({List<SubmittedOffer>? offers})
      : _offers = List<SubmittedOffer>.of(offers ?? const <SubmittedOffer>[]);

  final List<SubmittedOffer> _offers;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async => _offers;

  @override
  Future<bool> withdraw(String offerId) async => true;
}

SubmittedOffer _pendingOffer(
  String id, {
  int? eta = 25,
  double price = 12.5,
  OfferStatus status = OfferStatus.submitted,
}) =>
    SubmittedOffer(
      id: id,
      requestId: 'req-$id',
      price: price,
      currency: 'USD',
      etaMinutes: eta,
      status: status,
    );

final List<SubmittedOffer> _pendingOffers = <SubmittedOffer>[
  _pendingOffer('open-1', price: 12.5, eta: 25),
  _pendingOffer('open-2', price: 8.0, eta: 15),
  _pendingOffer('accepted-1', price: 9.0, status: OfferStatus.accepted),
];

JeeberPendingOffersScreen _pendingScreen({List<SubmittedOffer>? offers}) =>
    JeeberPendingOffersScreen(
      jeeberId: 'user-jeeber-002',
      repository: _FakePendingRepository(offers: offers),
    );

// ── offer-kyc-gate ───────────────────────────────────────────────────────────
// The screen self-provides an OfferKycGateCubit from the injected `gateway`, so
// we script the gateway to drive the optional live status line.

OfferKycGateScreen _offerKycGate(KycStatus status) => OfferKycGateScreen(
      gateway: FakeKycGateway(initial: KycSubmission(status: status)),
    );

// ── onboarding-funding ───────────────────────────────────────────────────────
// The static starter-credit explainer is enriched with a live wallet snapshot
// read from the `repository` seam (resolved eagerly), so we inject an in-memory
// fake rather than fall through to unconfigured DI.

class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository(this._balance, {this.throws = false});

  final WalletBalance _balance;
  final bool throws;

  @override
  Future<WalletBalance> fetchBalance() async {
    if (throws) throw const WalletRepositoryException(WalletFailure.network);
    return _balance;
  }
}

const WalletBalance _fundingBalance = WalletBalance(
  availableBalance: 25.00,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 3.00,
  giftCredit: 10.00,
  currency: 'USD',
);

OnboardingFundingScreen _fundingScreen({bool throws = false}) =>
    OnboardingFundingScreen(
      repository: _FakeWalletRepository(_fundingBalance, throws: throws),
    );

// ── kyc-status (KYC Wizard) ──────────────────────────────────────────────────
// The screen takes a `cubit` seam and hosts its own BlocProvider.value. We seed
// a KycWizardCubit over the in-memory FakeKycGateway: `loadSchema()` lands on
// the identity-capture step, while a gateway seeded with a terminal `initial:`
// submission + `loadStatus()` lands on the KycStatusView for that decision.

Uint8List _bytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = 0x42;
  }
  return out;
}

KycWizardCubit _kycCubit(KycGateway gateway) => KycWizardCubit(
      pickerService: StubPhotoPickerService(cameraPayload: _bytes(1024)),
      gateway: gateway,
    );

Widget _kycWizard(KycWizardCubit cubit) =>
    KycWizardScreen(cubit: cubit, onSubmitted: (_) {});

Widget _kycIdentity() => _kycWizard(_kycCubit(FakeKycGateway())..loadSchema());

Widget _kycTerminal(KycStatus status, {KycRejectionReason? rejectionReason}) {
  final gateway = FakeKycGateway(
    initial: KycSubmission(
      status: status,
      rejectionReason: rejectionReason,
      submittedAt: DateTime.utc(2026, 7, 1, 10),
    ),
  );
  return _kycWizard(_kycCubit(gateway)..loadStatus());
}

// ── kyc-rejected ─────────────────────────────────────────────────────────────
// The screen owns its BlocProvider + resolves the `gateway` seam. The default
// FakeKycGateway returns a non-rejected stored submission (generic FINAL copy);
// an `initial:` rejected submission surfaces the structured reason notice.

KycRejectedScreen _kycRejected({KycRejectionReason? reason}) => KycRejectedScreen(
      gateway: reason == null
          ? FakeKycGateway()
          : FakeKycGateway(
              initial: KycSubmission(
                status: KycStatus.rejected,
                rejectionReason: reason,
                submittedAt: DateTime.utc(2026, 7, 1, 10),
              ),
            ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// The catalog group — entries sorted alphabetically by title.
// ─────────────────────────────────────────────────────────────────────────────
final List<DevScreenEntry> jeeberOffersScreens = <DevScreenEntry>[
  // Active Delivery (Jeeber)
  DevScreenEntry(
    id: 'jeeber-active-delivery',
    title: 'Active Delivery (Jeeber)',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'mark delivered',
      'proof of delivery',
      'drop off',
      'at door',
      'courier',
      'jeeber',
      'JM-051',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'at-door-en',
        label: 'At Door — Mark Delivered (EN)',
        locale: const Locale('en'),
        builder: (_) => _activeDeliveryScreen(JeeberDeliveryStatus.atDoor),
      ),
      DevScreenState(
        id: 'at-door-ar',
        label: 'At Door — Mark Delivered (AR)',
        locale: const Locale('ar'),
        builder: (_) => _activeDeliveryScreen(JeeberDeliveryStatus.atDoor),
      ),
    ],
  ),

  // Delivery Register Prompt
  DevScreenEntry(
    id: 'delivery-register-prompt',
    title: 'Delivery Register Prompt',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'register',
      'become a jeeber',
      'sign up',
      'prompt',
      'onboarding',
      'JM-044',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'default-en',
        label: 'Prompt (EN)',
        locale: const Locale('en'),
        builder: (_) => const DeliveryRegisterPromptScreen(),
      ),
      DevScreenState(
        id: 'default-ar',
        label: 'Prompt (AR)',
        locale: const Locale('ar'),
        builder: (_) => const DeliveryRegisterPromptScreen(),
      ),
    ],
  ),

  // Jeeber Onboarding
  DevScreenEntry(
    id: 'jeeber-onboarding',
    title: 'Jeeber Onboarding',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'onboarding',
      'wizard',
      'photo',
      'address',
      'service area',
      'jeeber',
      'JM-037',
      'JM-038',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'photo-en',
        label: 'Photo Step (EN)',
        locale: const Locale('en'),
        builder: (_) => _onboardingScreen(DmOnboardingStep.photo),
      ),
      DevScreenState(
        id: 'address-en',
        label: 'Address Step (EN)',
        locale: const Locale('en'),
        builder: (_) => _onboardingScreen(DmOnboardingStep.address),
      ),
      DevScreenState(
        id: 'service-area-en',
        label: 'Service-Area Step (EN)',
        locale: const Locale('en'),
        builder: (_) => _onboardingScreen(DmOnboardingStep.serviceArea),
      ),
      DevScreenState(
        id: 'service-area-ar',
        label: 'Service-Area Step (AR)',
        locale: const Locale('ar'),
        builder: (_) => _onboardingScreen(DmOnboardingStep.serviceArea),
      ),
    ],
  ),

  // Jeeber Request Detail
  DevScreenEntry(
    id: 'jeeber-request-detail',
    title: 'Jeeber Request Detail',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'request detail',
      'make offer',
      'decline',
      'pickup',
      'feed',
      'jeeber',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'loaded-en',
        label: 'Loaded Detail (EN)',
        locale: const Locale('en'),
        builder: (_) => _detail(_detailRequest),
      ),
      DevScreenState(
        id: 'unavailable-en',
        label: 'Unavailable Fallback (EN)',
        locale: const Locale('en'),
        builder: (_) => JeeberRequestUnavailableScreen(
          requestId: _detailRequest.id,
          onBack: () {},
        ),
      ),
      DevScreenState(
        id: 'loaded-ar',
        label: 'Loaded Detail (AR)',
        locale: const Locale('ar'),
        builder: (_) => _detail(_detailRequest),
      ),
    ],
  ),

  // KYC Rejected
  DevScreenEntry(
    id: 'kyc-rejected',
    title: 'KYC Rejected',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'kyc',
      'rejected',
      'verification',
      'identity',
      'reason',
      'JM-043',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'generic-en',
        label: 'Generic Final Copy (EN)',
        locale: const Locale('en'),
        builder: (_) => _kycRejected(),
      ),
      DevScreenState(
        id: 'reason-en',
        label: 'Structured Reason (EN)',
        locale: const Locale('en'),
        builder: (_) => _kycRejected(reason: KycRejectionReason.idUnreadable),
      ),
      DevScreenState(
        id: 'reason-ar',
        label: 'Structured Reason (AR)',
        locale: const Locale('ar'),
        builder: (_) => _kycRejected(reason: KycRejectionReason.selfieMismatch),
      ),
    ],
  ),

  // KYC Wizard
  DevScreenEntry(
    id: 'kyc-status',
    title: 'KYC Wizard',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'kyc',
      'wizard',
      'identity',
      'verification',
      'approved',
      'rejected',
      'JM-040',
      'JM-042',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'identity-en',
        label: 'Identity Capture Step (EN)',
        locale: const Locale('en'),
        builder: (_) => _kycIdentity(),
      ),
      DevScreenState(
        id: 'approved-en',
        label: 'Approved Terminal (EN)',
        locale: const Locale('en'),
        builder: (_) => _kycTerminal(KycStatus.approved),
      ),
      DevScreenState(
        id: 'rejected-ar',
        label: 'Rejected Terminal (AR)',
        locale: const Locale('ar'),
        builder: (_) => _kycTerminal(
          KycStatus.rejected,
          rejectionReason: KycRejectionReason.selfieMismatch,
        ),
      ),
    ],
  ),

  // Offer KYC Gate
  DevScreenEntry(
    id: 'offer-kyc-gate',
    title: 'Offer KYC Gate',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'kyc',
      'gate',
      'offer',
      'pending',
      'rejected',
      'verification',
      'JM-044',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'pending-en',
        label: 'Pending Status (EN)',
        locale: const Locale('en'),
        builder: (_) => _offerKycGate(KycStatus.pending),
      ),
      DevScreenState(
        id: 'rejected-en',
        label: 'Rejected Status (EN)',
        locale: const Locale('en'),
        builder: (_) => _offerKycGate(KycStatus.rejected),
      ),
      DevScreenState(
        id: 'pending-ar',
        label: 'Pending Status (AR)',
        locale: const Locale('ar'),
        builder: (_) => _offerKycGate(KycStatus.pending),
      ),
    ],
  ),

  // Offer Submission
  DevScreenEntry(
    id: 'jeeber-offer-submission',
    title: 'Offer Submission',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'offer',
      'submit',
      'composer',
      'price',
      'eta',
      'bid',
      'jeeber',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Composer Idle (EN)',
        locale: const Locale('en'),
        builder: (_) => _offerSubmissionScreen(),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Composer Idle (AR)',
        locale: const Locale('ar'),
        builder: (_) => _offerSubmissionScreen(),
      ),
    ],
  ),

  // Onboarding Funding
  DevScreenEntry(
    id: 'onboarding-funding',
    title: 'Onboarding Funding',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'funding',
      'starter credit',
      'wallet',
      'gift credit',
      'balance',
      'onboarding',
      'JM-041',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Enriched Explainer (EN)',
        locale: const Locale('en'),
        builder: (_) => _fundingScreen(),
      ),
      DevScreenState(
        id: 'static-en',
        label: 'Fail-Safe Static Explainer (EN)',
        locale: const Locale('en'),
        builder: (_) => _fundingScreen(throws: true),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Enriched Explainer (AR)',
        locale: const Locale('ar'),
        builder: (_) => _fundingScreen(),
      ),
    ],
  ),

  // Pending Offers
  DevScreenEntry(
    id: 'jeeber-pending-offers',
    title: 'Pending Offers',
    group: 'Jeeber & Offers',
    keywords: const <String>[
      'pending offers',
      'submitted',
      'awaiting',
      'withdraw',
      'jeeber',
      'JM-047',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Populated List (EN)',
        locale: const Locale('en'),
        builder: (_) => _pendingScreen(offers: _pendingOffers),
      ),
      DevScreenState(
        id: 'empty-en',
        label: 'Empty List (EN)',
        locale: const Locale('en'),
        builder: (_) => _pendingScreen(offers: const <SubmittedOffer>[]),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Populated List (AR)',
        locale: const Locale('ar'),
        builder: (_) => _pendingScreen(offers: _pendingOffers),
      ),
    ],
  ),
];
