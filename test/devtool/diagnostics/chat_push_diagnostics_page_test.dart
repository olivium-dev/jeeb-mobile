import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/config/dev_base_url.dart';
import 'package:jeeb_mobile/core/diagnostics/chat_diagnostics.dart';
import 'package:jeeb_mobile/devtool/diagnostics/chat_push_diagnostics_page.dart';
import 'package:jeeb_mobile/devtool/diagnostics/dev_base_url_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Answers the dev-seam channel so the page never reaches a real platform.
MethodChannel _seamChannelReturning(String? payload) {
  const channel = MethodChannel('test/dev_seam');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => payload);
  return channel;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ChatDiagnostics.resetForTest();
    ChatDiagnostics.sink = (_) {};
    PushRegistrationDiagnostics.resetForTest();
  });

  tearDown(() async {
    ChatDiagnostics.resetForTest();
    PushRegistrationDiagnostics.resetForTest();
    await GetIt.instance.reset();
  });

  // Tall surface: the page is one ListView and the seam/degradation sections
  // sit below a phone fold, so they would not be built at all.
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the page names the base URL and the layer it came from', (
    tester,
  ) async {
    final prefs = await _prefsWith(<String, Object>{});
    GetIt.instance.registerSingleton<SharedPreferences>(prefs);

    await pump(
      tester,
      ChatPushDiagnosticsPage(seamChannel: _seamChannelReturning(null)),
    );

    expect(find.text('REST base URL'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Realtime socket (compile-time only)'), findsOneWidget);
    expect(find.text('Firestore'), findsOneWidget);
    expect(find.text('Database id'), findsOneWidget);
    // No override persisted ⇒ no override banner and no clear button.
    expect(find.text('Server URL override is ACTIVE'), findsNothing);
    expect(
      find.byKey(const ValueKey('devtool.diagnostics.clearOverride')),
      findsNothing,
    );
  });

  testWidgets('an active override is shown and can be cleared in one tap', (
    tester,
  ) async {
    final prefs = await _prefsWith(<String, Object>{
      'dev.base_url_override': 'https://msi.olivium.space/gateway',
    });
    GetIt.instance.registerSingleton<SharedPreferences>(prefs);

    await pump(
      tester,
      ChatPushDiagnosticsPage(seamChannel: _seamChannelReturning(null)),
    );

    expect(find.text('Server URL override is ACTIVE'), findsOneWidget);
    final clear = find.byKey(
      const ValueKey('devtool.diagnostics.clearOverride'),
    );
    expect(clear, findsOneWidget);

    await tester.tap(clear);
    await tester.pump();

    expect(DevBaseUrl.read(prefs), isNull);
    expect(prefs.getString('dev.base_url_override'), isNull);
  });

  testWidgets('the socket mismatch is called out, not left implicit', (
    tester,
  ) async {
    final prefs = await _prefsWith(<String, Object>{
      'dev.base_url_override': 'https://msi.olivium.space/gateway',
    });
    GetIt.instance.registerSingleton<SharedPreferences>(prefs);

    await pump(
      tester,
      ChatPushDiagnosticsPage(seamChannel: _seamChannelReturning(null)),
    );

    expect(find.text('Matches REST host'), findsOneWidget);
    expect(
      find.textContaining('does not match REST host'),
      findsOneWidget,
    );
  });

  testWidgets('recorded chat degradations are listed', (tester) async {
    final prefs = await _prefsWith(<String, Object>{});
    GetIt.instance.registerSingleton<SharedPreferences>(prefs);
    ChatDiagnostics.degraded(
      stage: ChatDiagStage.mint,
      reason: 'no_token',
      status: 503,
    );

    await pump(
      tester,
      ChatPushDiagnosticsPage(seamChannel: _seamChannelReturning(null)),
    );

    expect(find.text('Chat degradations (1)'), findsOneWidget);
    expect(
      find.textContaining(
        'JEEB-CHAT-DEGRADED stage=mint reason=no_token status=503',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a present dev-seam file is reported as a trap, not a detail', (
    tester,
  ) async {
    final prefs = await _prefsWith(<String, Object>{});
    GetIt.instance.registerSingleton<SharedPreferences>(prefs);

    await pump(
      tester,
      ChatPushDiagnosticsPage(
        seamChannel: _seamChannelReturning('{"jeeb.seam.session":"x"}'),
      ),
    );

    expect(find.textContaining('PRESENT'), findsOneWidget);
    expect(find.textContaining('survives uninstall'), findsOneWidget);
  });

  group('DevBaseUrlBanner', () {
    testWidgets('stays invisible with no override', (tester) async {
      final prefs = await _prefsWith(<String, Object>{});
      await pump(tester, DevBaseUrlBanner(preferences: prefs));
      expect(
        find.byKey(const ValueKey('devtool.baseUrlOverrideBanner')),
        findsNothing,
      );
    });

    testWidgets('shows the override and the build default it replaced', (
      tester,
    ) async {
      final prefs = await _prefsWith(<String, Object>{
        'dev.base_url_override': 'https://msi.olivium.space/gateway',
      });
      await pump(tester, DevBaseUrlBanner(preferences: prefs));
      expect(
        find.byKey(const ValueKey('devtool.baseUrlOverrideBanner')),
        findsOneWidget,
      );
      expect(
        find.textContaining('https://msi.olivium.space/gateway'),
        findsOneWidget,
      );
      expect(find.textContaining('Survives reinstall'), findsOneWidget);
    });

    // The Dev Tool shell can open before DI bootstrap registers prefs.
    testWidgets('renders nothing when GetIt has no SharedPreferences', (
      tester,
    ) async {
      expect(GetIt.instance.isRegistered<SharedPreferences>(), isFalse);
      await pump(tester, const DevBaseUrlBanner());
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('devtool.baseUrlOverrideBanner')),
        findsNothing,
      );
    });

    testWidgets('reads the override out of GetIt when registered', (
      tester,
    ) async {
      final prefs = await _prefsWith(<String, Object>{
        DevBaseUrl.prefsKey: 'https://msi.olivium.space/gateway',
      });
      GetIt.instance.registerSingleton<SharedPreferences>(prefs);
      await pump(tester, const DevBaseUrlBanner());
      expect(
        find.byKey(const ValueKey('devtool.baseUrlOverrideBanner')),
        findsOneWidget,
      );
      expect(
        find.textContaining('https://msi.olivium.space/gateway'),
        findsOneWidget,
      );
    });
  });
}
