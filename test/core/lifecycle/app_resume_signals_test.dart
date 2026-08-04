import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';

/// b02 P0 regression: ONE `delivery` push produced 60 gateway reads on
/// `RFCX306JSRT` (diag session `2026-07-28T02-30-02-867Z-jeeber.jsonl`,
void main() {
  late DateTime now;
  late AppResumeSignals signals;

  setUp(() {
    now = DateTime.utc(2026, 7, 28, 2, 54, 57);
    signals = AppResumeSignals(
      minInterval: const Duration(seconds: 2),
      clock: () => now,
    );
  });

  tearDown(() async => signals.dispose());

  void resumed() =>
      signals.didChangeAppLifecycleState(AppLifecycleState.resumed);
  void paused() =>
      signals.didChangeAppLifecycleState(AppLifecycleState.paused);
  void inactive() =>
      signals.didChangeAppLifecycleState(AppLifecycleState.inactive);

  test('a genuine background trip emits exactly one signal', () async {
    var fired = 0;
    signals.stream.listen((_) => fired++);

    paused();
    resumed();
    await Future<void>.delayed(Duration.zero);

    expect(fired, 1);
  });

  test(
      'THE STORM: 20 consecutive resumed notifications with no intervening '
      'background state emit ONE signal, not 20', () async {
    var fired = 0;
    signals.stream.listen((_) => fired++);

    // The measured shape. `client_home_screen` — the one resume observer on
    paused();
    for (var i = 0; i < 20; i++) {
      resumed();
      now = now.add(const Duration(milliseconds: 105));
    }
    await Future<void>.delayed(Duration.zero);

    expect(fired, 1, reason: 'the first resume is real; the other 19 are not');
    expect(signals.suppressedCount, 19);
  });

  test('a transient focus loss (inactive → resumed) emits nothing', () async {
    var fired = 0;
    signals.stream.listen((_) => fired++);

    // A heads-up notification, the shade, a permission dialog, an edge panel.
    for (var i = 0; i < 5; i++) {
      inactive();
      resumed();
    }
    await Future<void>.delayed(Duration.zero);

    expect(fired, 0);
    expect(signals.suppressedCount, 5);
  });

  test('two genuine trips inside the window collapse to one leading signal '
      'plus one trailing catch-up — the second trip is never LOST', () async {
    final fakeAsync = <void>[];
    var fired = 0;
    signals.stream.listen((_) {
      fired++;
      fakeAsync.add(null);
    });

    paused();
    resumed(); // leading edge — emits immediately
    await Future<void>.delayed(Duration.zero);
    expect(fired, 1);

    // A second real trip 200 ms later: suppressed by the rate floor, but a
    now = now.add(const Duration(milliseconds: 200));
    paused();
    resumed();
    await Future<void>.delayed(Duration.zero);
    expect(fired, 1, reason: 'still inside the 2 s floor');

    // The trailing emission lands when the window closes.
    now = now.add(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    expect(fired, 2, reason: 'the suppressed trip is delivered, not dropped');
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('a trip AFTER the window emits immediately again', () async {
    var fired = 0;
    signals.stream.listen((_) => fired++);

    paused();
    resumed();
    now = now.add(const Duration(seconds: 5));
    paused();
    resumed();
    await Future<void>.delayed(Duration.zero);

    expect(fired, 2);
  });

  test('the very first resumed at cold start emits nothing', () async {
    // The app is already `resumed` at start-up and no notification fires for
    var fired = 0;
    signals.stream.listen((_) => fired++);

    resumed();
    await Future<void>.delayed(Duration.zero);

    expect(fired, 0);
  });
}
