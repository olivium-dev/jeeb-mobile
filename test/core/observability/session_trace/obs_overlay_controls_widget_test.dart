import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/obs_export_bundle.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/obs_overlay_controller.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/widgets/obs_overlay_control_bar.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/widgets/obs_overlay_export_button.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/session_logs/session_logs_page.dart';
import 'package:share_plus/share_plus.dart';
import '../../../support/sync_app_localizations.dart';

final class _FakeSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  String? get sessionFilePath => '/tmp/widget-session.jsonl';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  tearDown(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  testWidgets(
    'Start, Stop, Clear view, and Export invoke the local controller seams',
    (tester) async {
      var installs = 0;
      var shares = 0;
      Observability.instance.sink = _FakeSink();
      final controller = ObsOverlayController(
        install: () async {
          installs++;
          return true;
        },
        buildExportBundle: (_, _) async => const ObsExportBundle(
          obsPath: '/tmp/frozen-obs.jsonl',
          diagPath: '/tmp/frozen-diag.jsonl',
        ),
        share: (files, subject) async {
          shares++;
          expect(files, hasLength(2));
          return const ShareResult('shared', ShareResultStatus.success);
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => Column(
                children: <Widget>[
                  ObsOverlayControlBar(controller: controller),
                  ObsOverlayExportButton(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsIdentifier('devtool.session_logs.recording'),
      );
      await tester.pump();
      expect(controller.recording, isTrue);
      expect(installs, 1);

      Observability.instance.recordScreen(
        action: 'push',
        route: '/home',
        name: null,
      );
      await tester.pump();
      expect(find.text('1 buffered'), findsOneWidget);
      expect(find.text('Clear view'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);

      await tester.tap(
        find.bySemanticsIdentifier('devtool.session_logs.clear'),
      );
      await tester.pump();
      expect(controller.totalBuffered, 0);
      expect(find.text('0 buffered'), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('devtool.session_logs.recording'),
      );
      await tester.pumpAndSettle();
      expect(controller.recording, isFalse);

      await tester.tap(
        find.bySemanticsIdentifier('devtool.session_logs.export'),
      );
      await tester.pumpAndSettle();
      expect(shares, 1);
      expect(controller.lastExportSucceeded, isTrue);
      expect(
        find.bySemanticsIdentifier('devtool_session_logs_export_success'),
        findsOneWidget,
      );
    },
    skip: !kObsCompiledIn,
  );

  testWidgets('Export failure surfaces the error snack', (tester) async {
    final controller = ObsOverlayController(
      install: () async => true,
      buildExportBundle: (_, _) async => null,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapForTest(Scaffold(body: ObsOverlayExportButton(controller: controller))),
    );
    await tester.tap(find.bySemanticsIdentifier('devtool.session_logs.export'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('devtool_session_logs_export_error'),
      findsOneWidget,
    );
  }, skip: !kObsCompiledIn);

  testWidgets(
    'Session Logs exposes stable identifiers and 48dp action targets',
    (tester) async {
      final controller = ObsOverlayController(install: () async => true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          home: SessionLogsPage(controller: controller),
        ),
      );

      for (final identifier in const <String>[
        'devtool.session_logs.screen',
        'devtool.session_logs.recording',
        'devtool.session_logs.clear',
        'devtool.session_logs.export',
      ]) {
        expect(
          find.bySemanticsIdentifier(identifier),
          findsOneWidget,
          reason: identifier,
        );
      }

      final clearSize = tester.getSize(
        find.bySemanticsIdentifier('devtool.session_logs.clear'),
      );
      expect(clearSize.width, greaterThanOrEqualTo(48));
      expect(clearSize.height, greaterThanOrEqualTo(48));
    },
    skip: !kObsCompiledIn,
  );
}
