// Tests for T-MOB-001: new repo/gateway registrations.
//
// Verifies that every repository mandated by the guardrail is resolvable from
// GetIt after [configureDependencies] runs. No screen may self-construct
// these outside DI in release builds.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/observability/crash_reporter.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/dispute_status/data/dio_dispute_status_repository.dart';
import 'package:jeeb_mobile/features/dispute_status/domain/dispute_status_repository.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/notifications/data/dio_notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/reviews/data/dio_reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/support/data/stub_support_repository.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/wallet/data/dio_wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/data/dio_wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/data/dio_wallet_transaction_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_transaction_repository.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockCrashReporter extends Mock implements CrashReporter {}

void main() {
  late SharedPreferences mockPrefs;
  late CrashReporter mockReporter;

  setUp(() {
    GetIt.I.reset();
    mockPrefs = _MockSharedPreferences();
    mockReporter = _MockCrashReporter();
    configureDependencies(
      sharedPreferences: mockPrefs,
      crashReporter: mockReporter,
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  test('TierRepository is registered and resolves', () {
    expect(GetIt.I.isRegistered<TierRepository>(), isTrue);
    expect(() => GetIt.I<TierRepository>(), returnsNormally);
    expect(GetIt.I<TierRepository>(), isA<DioTierRepository>());
  });

  test('OffersRepository is registered and resolves', () {
    expect(GetIt.I.isRegistered<OffersRepository>(), isTrue);
    expect(() => GetIt.I<OffersRepository>(), returnsNormally);
  });

  test('ChatGateway factory is registered and resolves', () {
    expect(GetIt.I.isRegistered<ChatGateway>(), isTrue);
    expect(() => GetIt.I<ChatGateway>(), returnsNormally);
  });

  test('RequestFeedRepository is registered and resolves', () {
    expect(GetIt.I.isRegistered<RequestFeedRepository>(), isTrue);
    expect(() => GetIt.I<RequestFeedRepository>(), returnsNormally);
  });

  test('KycGateway is registered and resolves', () {
    expect(GetIt.I.isRegistered<KycGateway>(), isTrue);
    expect(() => GetIt.I<KycGateway>(), returnsNormally);
  });

  test('RatingRepository is registered and resolves', () {
    expect(GetIt.I.isRegistered<RatingRepository>(), isTrue);
    expect(() => GetIt.I<RatingRepository>(), returnsNormally);
  });

  test('AvailabilityGateway is registered and resolves', () {
    expect(GetIt.I.isRegistered<AvailabilityGateway>(), isTrue);
    expect(() => GetIt.I<AvailabilityGateway>(), returnsNormally);
  });

  test('NotificationPrefsRepository is registered and resolves', () {
    expect(GetIt.I.isRegistered<NotificationPrefsRepository>(), isTrue);
    expect(() => GetIt.I<NotificationPrefsRepository>(), returnsNormally);
  });

  // T-MOB-FIX-001: the jeeber-request-detail route builder resolves
  // ProhibitedItemReportService from GetIt. It was never registered, so
  // tapping a Jeeber feed card threw `Bad state: GetIt: Object/factory with
  // type ProhibitedItemReportService is not registered inside GetIt.` and
  // red-screened the whole Jeeber leg. This pins the registration.
  test('ProhibitedItemReportService is registered and resolves', () {
    expect(GetIt.I.isRegistered<ProhibitedItemReportService>(), isTrue);
    expect(() => GetIt.I<ProhibitedItemReportService>(), returnsNormally);
    expect(
      GetIt.I<ProhibitedItemReportService>(),
      isA<ProhibitedItemReportService>(),
    );
  });

  // ── WAVE 3 (S2): wallet balance + ledger + transaction — all REAL Dio now
  //    that gateway PR #196 added GET /v1/jeeb/wallet, /ledger, /ledger/:id. ──

  test('WalletRepository is registered and binds REAL Dio (gateway #196 live)',
      () {
    expect(GetIt.I.isRegistered<WalletRepository>(), isTrue);
    expect(() => GetIt.I<WalletRepository>(), returnsNormally);
    expect(
      GetIt.I<WalletRepository>(),
      isA<DioWalletRepository>(),
    );
  });

  test('WalletLedgerRepository is registered and binds REAL Dio (W2m live)',
      () {
    expect(GetIt.I.isRegistered<WalletLedgerRepository>(), isTrue);
    expect(() => GetIt.I<WalletLedgerRepository>(), returnsNormally);
    expect(
      GetIt.I<WalletLedgerRepository>(),
      isA<DioWalletLedgerRepository>(),
    );
  });

  test(
      'WalletTransactionRepository is registered and binds REAL Dio '
      '(gateway #196 live)', () {
    expect(GetIt.I.isRegistered<WalletTransactionRepository>(), isTrue);
    expect(() => GetIt.I<WalletTransactionRepository>(), returnsNormally);
    expect(
      GetIt.I<WalletTransactionRepository>(),
      isA<DioWalletTransactionRepository>(),
    );
  });

  // ── WAVE 4 (S2): notifications (real Dio, LIVE) + dispute-status (real Dio,
  //    LIVE) + support (stub, S1 not live) + reviews (stub, R1m not live). ────

  test('NotificationsRepository is registered and binds REAL Dio (LIVE)', () {
    expect(GetIt.I.isRegistered<NotificationsRepository>(), isTrue);
    expect(() => GetIt.I<NotificationsRepository>(), returnsNormally);
    expect(
      GetIt.I<NotificationsRepository>(),
      isA<DioNotificationsRepository>(),
    );
  });

  test('DisputeStatusRepository is registered and binds REAL Dio (LIVE)', () {
    expect(GetIt.I.isRegistered<DisputeStatusRepository>(), isTrue);
    expect(() => GetIt.I<DisputeStatusRepository>(), returnsNormally);
    expect(
      GetIt.I<DisputeStatusRepository>(),
      isA<DioDisputeStatusRepository>(),
    );
  });

  test('SupportRepository is registered and binds the INTEGRATOR-STUB (S1 gap)',
      () {
    expect(GetIt.I.isRegistered<SupportRepository>(), isTrue);
    expect(() => GetIt.I<SupportRepository>(), returnsNormally);
    expect(GetIt.I<SupportRepository>(), isA<StubSupportRepository>());
  });

  test('ReviewsRepository is registered and binds REAL Dio (R1m live)', () {
    expect(GetIt.I.isRegistered<ReviewsRepository>(), isTrue);
    expect(() => GetIt.I<ReviewsRepository>(), returnsNormally);
    expect(GetIt.I<ReviewsRepository>(), isA<DioReviewsRepository>());
  });
}
