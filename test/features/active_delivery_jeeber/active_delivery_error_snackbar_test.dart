// P6 (UT-13) — the transition-failure snackbar is LOCALIZED and KIND-SPECIFIC.
//
// Ranked cause #3 of the 2026-07-25 incident was "one message for three
// failures": every transition rejection rendered the same hardcoded English
// "That transition is not allowed". The screen now resolves
// `state.transitionErrorKind` to its own ARB string, in the active locale.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _dropOff = DropOffAddress(label: 'Verdun', lat: 33.88, lng: 35.49);

class _InertRepo implements ActiveDeliveryRepository {
  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async =>
      const JeeberDelivery(
        id: 'DLV-770001',
        status: JeeberDeliveryStatus.inTransit,
        dropOff: _dropOff,
      );

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async => to;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => 'https://cdn.jeeb.app/proof/$deliveryId.jpg';
}

Widget _host(ActiveDeliveryCubit cubit, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ActiveDeliveryJeeberScreen(
        deliveryId: 'DLV-770001',
        cubit: cubit,
        onOpenChat: () {},
      ),
    );

ActiveDeliveryCubit _seededCubit() => ActiveDeliveryCubit(
      repository: _InertRepo(),
      deliveryId: 'DLV-770001',
      // Long enough that the background poll never fires mid-test.
      refreshSignals: const Stream<void>.empty(),
    )..emit(const ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: JeeberDelivery(
          id: 'DLV-770001',
          status: JeeberDeliveryStatus.inTransit,
          dropOff: _dropOff,
        ),
      ));

Future<void> _raise(
  WidgetTester tester,
  ActiveDeliveryCubit cubit,
  ActiveDeliveryFailure kind,
) async {
  cubit.emit(cubit.state.copyWith(
    // The cubit's English literal — the screen must PREFER the localized copy.
    transitionError: 'That transition is not allowed',
    transitionErrorKind: kind,
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('invalidTransition renders the invalid-transition ARB copy',
      (tester) async {
    final cubit = _seededCubit();
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    await _raise(tester, cubit, ActiveDeliveryFailure.invalidTransition);

    expect(
      find.text('That step isn’t available yet. Pull to refresh and try '
          'again.'),
      findsOneWidget,
    );
    // The hardcoded literal never reaches the user.
    expect(find.text('That transition is not allowed'), findsNothing);
    await cubit.close();
  });

  testWidgets('badRequest renders its OWN copy — different from '
      'invalidTransition (P6/B4)', (tester) async {
    final cubit = _seededCubit();
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    await _raise(tester, cubit, ActiveDeliveryFailure.badRequest);

    expect(
      find.text('We couldn’t apply that update. Try again, or contact '
          'support if it keeps happening.'),
      findsOneWidget,
    );
    expect(
      find.text('That step isn’t available yet. Pull to refresh and try '
          'again.'),
      findsNothing,
    );
    await cubit.close();
  });

  testWidgets('the copy is genuinely localized — Arabic renders the Arabic '
      'string (RTL l10n gate)', (tester) async {
    final cubit = _seededCubit();
    await tester.pumpWidget(_host(cubit, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    await _raise(tester, cubit, ActiveDeliveryFailure.invalidTransition);

    expect(
      find.text('هذه الخطوة غير متاحة بعد. حدّث الصفحة وحاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl);
    await cubit.close();
  });
}
