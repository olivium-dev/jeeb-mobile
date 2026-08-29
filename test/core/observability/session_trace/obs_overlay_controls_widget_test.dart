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
import 'package:share_plus/share_plus.dart';

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

      await tester.tap(find.byKey(const Key('obs-overlay-recording-switch')));
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

      await tester.tap(find.byKey(const Key('obs-overlay-clear')));
      await tester.pump();
      expect(controller.totalBuffered, 0);
      expect(find.text('0 buffered'), findsOneWidget);

      await tester.tap(find.byKey(const Key('obs-overlay-recording-switch')));
      await tester.pumpAndSettle();
      expect(controller.recording, isFalse);

      await tester.tap(find.byKey(const Key('obs-overlay-export')));
      await tester.pumpAndSettle();
      expect(shares, 1);
      expect(controller.lastExportSucceeded, isTrue);
    },
    skip: !kObsCompiledIn,
  );
}
