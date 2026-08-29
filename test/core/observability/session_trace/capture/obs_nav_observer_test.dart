import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/capture/obs_nav_observer.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/secret_redactor.dart';

/// Requires `flutter test --dart-define=JEEB_DEVTOOL_ENABLED=true …` to
/// exercise the `skip:`-guarded group below — [kObsCompiledIn] is a hard
String get _needsDevtoolDefine =>
    'requires --dart-define=JEEB_DEVTOOL_ENABLED=true';

class _FakeSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  String? get sessionFilePath => null;
}

Route<void> route(String name, {Object? arguments}) => MaterialPageRoute<void>(
  builder: (_) => const SizedBox.shrink(),
  settings: RouteSettings(name: name, arguments: arguments),
);

void main() {
  late _FakeSink sink;
  late ObsNavObserver observer;

  setUp(() {
    sink = _FakeSink();
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
    Observability.instance.sink = sink;
    observer = ObsNavObserver();
  });

  tearDown(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  test('emits nothing when the tool is not recording (zero-cost no-op)', () {
    observer.didPush(route('/orders/:id'), null);
    expect(sink.events, isEmpty);
    if (kObsCompiledIn) {
      expect(Observability.instance.currentScreen, '/orders/:id');
    }
  });

  test('a null new-route (didReplace with nothing to report) is a no-op', () {
    ObservabilityConfig.instance.enabled = true;
    observer.didReplace(newRoute: null, oldRoute: route('/x'));
    expect(sink.events, isEmpty);
  });

  group('recording behaviour (compiled-in)', () {
    setUp(() {
      ObservabilityConfig.instance.enabled = true;
    });

    test(
      'didPush emits an ObsScreenEvent with route/name/prev/path params',
      () {
        observer.didPush(
          route('/orders/:id', arguments: <String, Object?>{'id': 'd-42'}),
          route('/home'),
        );

        expect(sink.events, hasLength(1));
        final event = sink.events.single as ObsScreenEvent;
        expect(event.action, 'push');
        expect(event.route, '/orders/:id');
        expect(event.name, '/orders/:id');
        expect(event.previousRoute, '/home');
        expect(event.params, {'id': SecretRedactor.redacted});
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'didReplace emits action=replace for the new route',
      () {
        observer.didReplace(newRoute: route('/wallet'), oldRoute: route('/'));

        final event = sink.events.single as ObsScreenEvent;
        expect(event.action, 'replace');
        expect(event.route, '/wallet');
        expect(event.previousRoute, '/');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test('didPop reports the destination as "route" and the popped screen as '
        '"previousRoute"', () {
      observer.didPop(route('/orders/:id/otp'), route('/orders/:id'));

      final event = sink.events.single as ObsScreenEvent;
      expect(event.action, 'pop');
      expect(event.route, '/orders/:id');
      expect(event.previousRoute, '/orders/:id/otp');
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test('query tokens on a raw-location route name are stripped from both '
        'route and name', () {
      observer.didPush(route('/set-password?resetToken=SECRET123'), null);

      final event = sink.events.single as ObsScreenEvent;
      expect(event.route, '/set-password');
      expect(event.name, '/set-password');
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test(
      'a sensitive key in path params is fully redacted, never logged raw',
      () {
        observer.didPush(
          route('/x', arguments: <String, Object?>{'token': 'raw-token-9999'}),
          null,
        );

        final event = sink.events.single as ObsScreenEvent;
        final token = event.params['token'] as String;
        expect(token, isNot(contains('raw-token-9999')));
        expect(token, SecretRedactor.redacted);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test('a long bare digit run in a non-sensitive-keyed path param is still '
        'redacted by the non-disableable policy', () {
      observer.didPush(
        route('/x', arguments: <String, Object?>{'phone': '5551234567'}),
        null,
      );

      final event = sink.events.single as ObsScreenEvent;
      expect(event.params['phone'], '<redacted>');
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test('a nameless route keeps the previous currentScreen instead of nulling '
        'it out', () {
      observer.didPush(route('/home'), null);
      expect(Observability.instance.currentScreen, '/home');

      observer.didPush(route(''), null);
      expect(Observability.instance.currentScreen, '/home');
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test(
      'didPop updates currentScreen to the destination route',
      () {
        observer.didPush(route('/orders/:id'), null);
        observer.didPop(route('/orders/:id'), route('/home'));
        expect(Observability.instance.currentScreen, '/home');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'captureScreens=false suppresses the event (per-signal toggle)',
      () {
        ObservabilityConfig.instance.captureScreens = false;
        observer.didPush(route('/orders/:id'), null);
        expect(sink.events, isEmpty);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );
  });
}
