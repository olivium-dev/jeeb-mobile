import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/widgets/mark_delivered_panel.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final online in [true, false]) {
      testWidgets(
        'door OTP transport failure follows reachability $online · $locale',
        (tester) async {
          useReduceMotion(tester);
          NetworkReachabilitySignals.instance.debugObserve(online: online);
          addTearDown(NetworkReachabilitySignals.debugReset);
          await tester.pumpWidget(
            wrapForTest(
              Scaffold(
                body: SingleChildScrollView(
                  child: Builder(
                    builder: (context) => MarkDeliveredPanel(
                      delivery: const JeeberDelivery(
                        id: 'request-test',
                        status: JeeberDeliveryStatus.atDoor,
                        dropOff: DropOffAddress(
                          label: 'Test destination',
                          lat: 0,
                          lng: 0,
                        ),
                      ),
                      proofPhotoStatus: ProofPhotoStatus.none,
                      isMarking: false,
                      onCaptureProof: () {},
                      onNoteChanged: (_) {},
                      onMarkDelivered: () {},
                      l10n: AppLocalizations.of(context),
                      otpRequired: true,
                      otpErrorKind: ActiveDeliveryFailure.network,
                    ),
                  ),
                ),
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(MarkDeliveredPanel)),
          );
          expect(
            find.bySemanticsIdentifier('mark_delivered_otp_input'),
            findsOneWidget,
          );
          expect(
            find.text(
              online ? l10n.errorUnreachableBody : l10n.errorNetworkBody,
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              online ? l10n.errorNetworkBody : l10n.errorUnreachableBody,
            ),
            findsNothing,
          );
        },
      );
    }
  }
}
