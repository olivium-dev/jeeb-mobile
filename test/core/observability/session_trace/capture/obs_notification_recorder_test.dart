import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/observability/session_trace/capture/obs_notification_recorder.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';

/// Requires `flutter test --dart-define=JEEB_DEVTOOL_ENABLED=true …` to
/// exercise the `skip:`-guarded groups below — `kObsCompiledIn` is a hard
/// compile-time const with no test override by design (mirrors
/// `observability_test.dart` / `kDevToolEnabled`). The unconditional group
/// still proves the "compiled out / disabled ⇒ zero-cost no-op" guarantee in
/// a plain run.
String get _needsDevtoolDefine =>
    'requires --dart-define=JEEB_DEVTOOL_ENABLED=true';

const String _fakeJwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1LTEiLCJleHAiOjk5OTk5OTk5OTl9.S3cReTtOkEnLeAk';

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

NotificationMessage _message({
  String id = 'm-1',
  NotificationCategory category = NotificationCategory.delivery,
  String title = 'Order update',
  String body = 'Your order is on the way',
  Map<String, String> data = const <String, String>{},
}) {
  return NotificationMessage(
    id: id,
    category: category,
    title: title,
    body: body,
    receivedAt: DateTime.utc(2026, 7, 18),
    data: data,
  );
}

void main() {
  setUp(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  tearDown(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  group('compile/runtime gate (runs in ANY invocation)', () {
    test(
      'recordReceived/recordShown/recordOpened are no-ops when not recording',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;
        ObservabilityConfig.instance.enabled = false; // forces !recording

        ObsNotificationRecorder.recordReceived(_message(), mode: 'foreground');
        ObsNotificationRecorder.recordShown(_message());
        ObsNotificationRecorder.recordOpened(
          _message(),
          deepLink: '/orders/1',
        );

        expect(fake.events, isEmpty);
      },
    );
  });

  group('recording behaviour (compiled-in)', () {
    setUp(() {
      ObservabilityConfig.instance.enabled = true;
    });

    test(
      'recordReceived emits a notification event stamped fcm/foreground',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordReceived(
          _message(id: 'm-42', category: NotificationCategory.chat),
          mode: 'foreground',
        );

        expect(fake.events, hasLength(1));
        final event = fake.events.single as ObsNotificationEvent;
        expect(event.channel, 'fcm');
        expect(event.mode, 'foreground');
        expect(event.messageId, 'm-42');
        expect(event.category, 'chat');
        expect(event.deepLink, isNull);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'recordShown emits a local/foreground event for the rendered banner',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordShown(_message(id: 'm-7'));

        expect(fake.events, hasLength(1));
        final event = fake.events.single as ObsNotificationEvent;
        expect(event.channel, 'local');
        expect(event.mode, 'foreground');
        expect(event.messageId, 'm-7');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'recordShown honors a caller-supplied channel override',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordShown(_message(), channel: 'other');

        final event = fake.events.single as ObsNotificationEvent;
        expect(event.channel, 'other');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'recordOpened emits an opened event carrying the resolved deep link',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordOpened(
          _message(id: 'm-9', category: NotificationCategory.delivery),
          deepLink: '/orders/d-1',
        );

        expect(fake.events, hasLength(1));
        final event = fake.events.single as ObsNotificationEvent;
        expect(event.channel, 'fcm');
        expect(event.mode, 'opened');
        expect(event.messageId, 'm-9');
        expect(event.deepLink, '/orders/d-1');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'recordOpened records a null deepLink when the payload had no '
      'actionable destination',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordOpened(_message());

        final event = fake.events.single as ObsNotificationEvent;
        expect(event.deepLink, isNull);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'seq/id/sessionId/timestamp are stamped by the shared Observability '
      'facade, not re-implemented here',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;
        Observability.instance.clock = () => DateTime.utc(2026, 7, 18, 9);

        ObsNotificationRecorder.recordReceived(_message(), mode: 'foreground');

        final event = fake.events.single as ObsNotificationEvent;
        expect(event.id, '1-notification');
        expect(event.seq, 1);
        expect(event.timestampUtc, DateTime.utc(2026, 7, 18, 9));
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'title/body pass through untouched when they carry no secret shape',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordReceived(
          _message(title: 'Order update', body: 'On the way'),
          mode: 'foreground',
        );

        final event = fake.events.single as ObsNotificationEvent;
        expect(event.title, 'Order update');
        expect(event.body, 'On the way');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'title/body are redacted at capture time (hard floor over a '
      'secret-shaped pattern embedded in free text)',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordReceived(
          _message(
            title: 'Auth via Bearer $_fakeJwt',
            body: 'token=$_fakeJwt failed',
          ),
          mode: 'foreground',
        );

        final event = fake.events.single as ObsNotificationEvent;
        expect(event.title, isNot(contains(_fakeJwt)));
        expect(event.body, isNot(contains(_fakeJwt)));
        expect(event.title, isNot(contains('Bearer ')));
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'the FCM data map redacts known-sensitive keys to a correlation '
      'handle while passing non-sensitive keys through verbatim',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordReceived(
          _message(data: const <String, String>{
            'fcmToken': 'fcm-registration-abcdef123456',
            'requestId': 'req-1',
          }),
          mode: 'foreground',
        );

        final event = fake.events.single as ObsNotificationEvent;
        expect(event.data['fcmToken'], startsWith('tok:'));
        expect(event.data['fcmToken'], isNot(contains('abcdef123456')));
        expect(event.data['requestId'], 'req-1');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'a bearer/JWT-shaped value nested in a non-sensitive data key is '
      'still caught by the pattern floor',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        ObsNotificationRecorder.recordReceived(
          _message(data: <String, String>{'note': 'Bearer $_fakeJwt'}),
          mode: 'foreground',
        );

        final event = fake.events.single as ObsNotificationEvent;
        expect(event.data['note'], isNot(contains(_fakeJwt)));
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'redactionEnabled=false still never exposes a sensitive-keyed data '
      'value (the hard floor cannot be lowered by the toggle)',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;
        ObservabilityConfig.instance.redactionEnabled = false;

        ObsNotificationRecorder.recordReceived(
          _message(data: const <String, String>{'deviceToken': 'raw-device-token-value'}),
          mode: 'foreground',
        );

        final event = fake.events.single as ObsNotificationEvent;
        expect(event.data['deviceToken'], startsWith('tok:'));
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'a per-signal toggle OFF (captureNotifications=false) suppresses '
      'emission even though the master switch is on',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;
        ObservabilityConfig.instance.captureNotifications = false;

        ObsNotificationRecorder.recordReceived(_message(), mode: 'foreground');

        expect(fake.events, isEmpty);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'received -> shown -> opened for the same message share one '
      'monotonic seq order and the same messageId',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;
        final message = _message(id: 'm-100');

        ObsNotificationRecorder.recordReceived(message, mode: 'foreground');
        ObsNotificationRecorder.recordShown(message);
        ObsNotificationRecorder.recordOpened(message, deepLink: '/orders/1');

        expect(fake.events, hasLength(3));
        expect(fake.events.map((e) => e.seq), [1, 2, 3]);
        final notifications = fake.events.cast<ObsNotificationEvent>();
        expect(notifications.every((e) => e.messageId == 'm-100'), isTrue);
        expect(notifications.map((e) => e.channel), ['fcm', 'local', 'fcm']);
        expect(
          notifications.map((e) => e.mode),
          ['foreground', 'foreground', 'opened'],
        );
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );
  });
}
