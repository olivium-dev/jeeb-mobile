// Tests for T-MOB-001: new repo/gateway registrations.

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
import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';
import 'package:jeeb_mobile/features/notifications/data/local_merging_notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/order_summary/data/dio_order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary_repository.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/reviews/data/dio_reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/support/data/dio_support_repository.dart';
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
  test('ProhibitedItemReportService is registered and resolves', () {
    expect(GetIt.I.isRegistered<ProhibitedItemReportService>(), isTrue);
    expect(() => GetIt.I<ProhibitedItemReportService>(), returnsNormally);
    expect(
      GetIt.I<ProhibitedItemReportService>(),
      isA<ProhibitedItemReportService>(),
    );
  });

  // ── WAVE 3 (S2): wallet balance + ledger + transaction — all REAL Dio now

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

  test('NotificationsRepository binds the G3 local-merging decorator (over '
      'REAL Dio + the durable LocalPushInbox)', () {
    expect(GetIt.I.isRegistered<NotificationsRepository>(), isTrue);
    expect(() => GetIt.I<NotificationsRepository>(), returnsNormally);
    // G3: the inbox now UNIONS the server inbox with the on-device push store so
    expect(
      GetIt.I<NotificationsRepository>(),
      isA<LocalMergingNotificationsRepository>(),
    );
    // The durable store is registered as a shared singleton so the merging repo
    expect(GetIt.I.isRegistered<LocalPushInbox>(), isTrue);
    expect(() => GetIt.I<LocalPushInbox>(), returnsNormally);
  });

  test('DisputeStatusRepository is registered and binds REAL Dio (LIVE)', () {
    expect(GetIt.I.isRegistered<DisputeStatusRepository>(), isTrue);
    expect(() => GetIt.I<DisputeStatusRepository>(), returnsNormally);
    expect(
      GetIt.I<DisputeStatusRepository>(),
      isA<DioDisputeStatusRepository>(),
    );
  });

  test('SupportRepository is registered and binds REAL Dio (S1 live, gateway #200)',
      () {
    expect(GetIt.I.isRegistered<SupportRepository>(), isTrue);
    expect(() => GetIt.I<SupportRepository>(), returnsNormally);
    expect(GetIt.I<SupportRepository>(), isA<DioSupportRepository>());
  });

  test('ReviewsRepository is registered and binds REAL Dio (R1m live)', () {
    expect(GetIt.I.isRegistered<ReviewsRepository>(), isTrue);
    expect(() => GetIt.I<ReviewsRepository>(), returnsNormally);
    expect(GetIt.I<ReviewsRepository>(), isA<DioReviewsRepository>());
  });

  // BUG-6 create-payload regression: the compose controller MUST be registered
  test('ComposeRequestController is registered and resolves (BUG-6)', () {
    expect(GetIt.I.isRegistered<ComposeRequestController>(), isTrue);
    expect(() => GetIt.I<ComposeRequestController>(), returnsNormally);
    expect(GetIt.I<ComposeRequestController>(), isA<ComposeRequestController>());
  });

  // JEBV4-285: the `view summary` → order-summary screen fell back to the
  test('OrderSummaryRepository is registered and binds REAL Dio (JEBV4-285)',
      () {
    expect(GetIt.I.isRegistered<OrderSummaryRepository>(), isTrue);
    expect(() => GetIt.I<OrderSummaryRepository>(), returnsNormally);
    expect(
      GetIt.I<OrderSummaryRepository>(),
      isA<DioOrderSummaryRepository>(),
    );
  });
}
