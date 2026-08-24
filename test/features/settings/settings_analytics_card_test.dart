import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/analytics/clarity/application/clarity_controller.dart';
import 'package:jeeb_mobile/core/analytics/clarity/domain/clarity_analytics_port.dart';
import 'package:jeeb_mobile/core/analytics/clarity/domain/clarity_consent.dart';
import 'package:jeeb_mobile/core/analytics/clarity/domain/clarity_consent_store.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/settings_analytics_card.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  Widget harness(ClarityController controller, Locale locale) => wrapForTest(
    Scaffold(body: SettingsAnalyticsCard(controller: controller)),
    locale: locale,
  );

  testWidgets('unknown is off; disclosure grants or records denial', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = _Store();
    final controller = ClarityController(
      available: true,
      consentStore: store,
      analytics: _Analytics(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(controller, const Locale('en')));
    await controller.loadConsent();
    await tester.pump();

    final toggle = find.bySemanticsIdentifier(
      SettingsAnalyticsCard.toggleIdentifier,
    );
    expect(toggle, findsOneWidget);
    expect(
      tester.getSemantics(toggle).flagsCollection.isToggled,
      Tristate.isFalse,
    );
    await tester.tap(
      find.bySemanticsIdentifier(SettingsAnalyticsCard.toggleIdentifier),
    );
    await tester.pumpAndSettle();
    expect(find.text('Allow privacy-safe analytics?'), findsOneWidget);
    expect(find.textContaining('Microsoft Clarity'), findsOneWidget);
    expect(find.text("Don't allow"), findsOneWidget);
    await tester.tap(find.text("Don't allow"));
    await tester.pumpAndSettle();
    expect(store.value, ClarityConsent.denied);

    await tester.tap(
      find.bySemanticsIdentifier(SettingsAnalyticsCard.toggleIdentifier),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(store.value, ClarityConsent.granted);
    expect(
      tester
          .getSemantics(
            find.bySemanticsIdentifier(SettingsAnalyticsCard.toggleIdentifier),
          )
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('Arabic disclosure is localized', (tester) async {
    final controller = ClarityController(
      available: true,
      consentStore: _Store(),
      analytics: _Analytics(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(controller, const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('الخصوصية والتحليلات'), findsOneWidget);
    await tester.tap(
      find.bySemanticsIdentifier(SettingsAnalyticsCard.toggleIdentifier),
    );
    await tester.pumpAndSettle();
    expect(find.text('السماح بتحليلات تحافظ على الخصوصية؟'), findsOneWidget);
    expect(find.textContaining('Microsoft Clarity'), findsOneWidget);
  });

  testWidgets('failed privacy mutation remains visible and actionable', (
    tester,
  ) async {
    final store = _Store()..value = ClarityConsent.granted;
    final controller = ClarityController(
      available: true,
      consentStore: store,
      analytics: _Analytics(),
    );
    addTearDown(controller.dispose);
    await controller.loadConsent();
    await tester.pumpWidget(harness(controller, const Locale('en')));
    store.writeSucceeds = false;

    await tester.tap(
      find.bySemanticsIdentifier(SettingsAnalyticsCard.toggleIdentifier),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("We couldn't apply this privacy change. Try again."),
      findsOneWidget,
    );
  });
}

final class _Store implements ClarityConsentStore {
  ClarityConsent value = ClarityConsent.unknown;
  bool writeSucceeds = true;

  @override
  Future<ClarityConsent> read() async => value;

  @override
  Future<bool> write(ClarityConsent consent) async {
    if (!writeSucceeds) return false;
    value = consent;
    return true;
  }

  @override
  Future<bool> clear() async {
    value = ClarityConsent.unknown;
    return true;
  }
}

final class _Analytics implements ClarityAnalyticsPort {
  bool paused = false;

  @override
  bool setSessionStartedCallback(VoidCallback onSessionStarted) {
    onSessionStarted();
    return true;
  }

  @override
  bool consent({required bool adsStorage, required bool analyticsStorage}) =>
      true;

  @override
  bool initialize(BuildContext context) => true;

  @override
  bool pause() {
    paused = true;
    return true;
  }

  @override
  bool isPaused() => paused;

  @override
  bool resume() {
    paused = false;
    return true;
  }

  @override
  bool setScreenName(String? screenName) => true;

  @override
  bool startNewSession() => true;
}
