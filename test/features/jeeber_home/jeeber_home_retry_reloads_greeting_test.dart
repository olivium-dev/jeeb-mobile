import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThenSucceeds implements CustomerProfileRepository {
  int reads = 0;
  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    if (++reads == 1) throw const NetworkFailure(offline: true);
    return const CustomerProfileViewData(name: 'Karim TestJeeber');
  }
}

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final hasGreeting in [true, false]) {
      testWidgets('${locale.languageCode}: dashboard retry with greeting '
          'provider=$hasGreeting', (tester) async {
        useReduceMotion(tester);
        final availability = AvailabilityCubit(
          gateway: const FailingAvailabilityGateway(
            NetworkFailure(offline: true),
          ),
          tickerFactory: () => const Stream<DateTime>.empty(),
        );
        addTearDown(availability.close);
        final repo = _ThenSucceeds();
        final greeting = GreetingProfileCubit(repository: repo);
        addTearDown(greeting.close);
        if (hasGreeting) await greeting.load();
        Widget child = BlocProvider<AvailabilityCubit>.value(
          value: availability,
          child: const JeeberHomeScreen(),
        );
        if (hasGreeting) {
          child = BlocProvider<GreetingProfileCubit>.value(
            value: greeting,
            child: child,
          );
        }
        await tester.pumpWidget(wrapForTest(child, locale: locale));
        await availability.load();
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier('jeeber_home_load_error_retry_cta'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (hasGreeting) {
          expect(repo.reads, 2);
          expect(greeting.state.status, GreetingProfileStatus.resolved);
          expect(greeting.state.name, 'Karim TestJeeber');
        } else {
          expect(repo.reads, 0);
        }
      });
    }
  }
}
