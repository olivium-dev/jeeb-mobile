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
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';

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
}
