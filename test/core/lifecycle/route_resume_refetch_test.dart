import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
import 'package:jeeb_mobile/core/lifecycle/route_resume_refetch.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';

/// `AppResumeSignals` coalesces at a 2 s floor and re-emits on the TRAILING
/// edge, so a second resume inside one test body lands 2 s later rather than
/// immediately. Every assertion here is taken after pumping past that window,
/// so it measures the settled number of callbacks instead of racing the timer.
const _resumeSettle = Duration(seconds: 3);

/// Legal `AppLifecycleState` transition into the background, mirroring
/// `test/features/jeeber_active_deliveries/active_deliveries_lifecycle_test.dart`.
Future<void> _driveToBackground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> _driveToForeground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

/// One genuine background → foreground trip, settled.
Future<void> _resume(WidgetTester tester) async {
  await _driveToBackground(tester);
  await _driveToForeground(tester);
  await tester.pump(_resumeSettle);
  await tester.pump();
}

class _Host extends StatelessWidget {
  const _Host({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RouteResumeRefetch(
        onResume: (_) => onResume(),
        child: const Scaffold(body: Text('base route')),
      ),
    );
  }
}

/// Hosts the widget inside a shell tab, exactly as `ShellScreen` does — an
/// `IndexedStack` child wrapped in a [TabVisibility]. Every tab stays MOUNTED
/// across a bottom-nav switch, which is the whole reason the tab term is
/// needed: a background tab's lifecycle never re-runs, so without consulting
/// [TabVisibility] it would happily refetch on resume while off-screen.
class _TabHost extends StatelessWidget {
  const _TabHost({required this.onResume, required this.isVisible});

  final VoidCallback onResume;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: IndexedStack(
          index: isVisible ? 0 : 1,
          children: [
            TabVisibility(
              isVisible: isVisible,
              child: RouteResumeRefetch(
                onResume: (_) => onResume(),
                child: const Text('tab body'),
              ),
            ),
            const Text('other tab'),
          ],
        ),
      ),
    );
  }
}

Future<void> _pushOnTop(WidgetTester tester) async {
  final context = tester.element(find.byType(RouteResumeRefetch));
  // Deliberately not awaited: the pushed route outlives this call.
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('route on top')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _popTop(WidgetTester tester) async {
  final context = tester.element(find.text('route on top'));
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() async {
    // The resume one-shot rides the process-wide `AppResumeSignals` singleton,
    // whose coalescing window and `_sawBackground` latch would otherwise bleed
    // between cases and make a resume look dropped.
    await AppResumeSignals.debugReset();
  });

  testWidgets('a genuine resume on a visible route fires exactly ONE one-shot', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(_Host(onResume: () => fired++));
    await tester.pumpAndSettle();
    expect(fired, 0, reason: 'mounting is not a resume');

    await _resume(tester);

    expect(fired, 1);
  });

  testWidgets('a resume on a BACKGROUND shell tab fires nothing', (
    tester,
  ) async {
    // The hazard this closes: the shell keeps every tab mounted in an
    // IndexedStack, so an off-screen tab is alive and receives the resume.
    // Without the TabVisibility term it would refetch for a tab the user
    // cannot see — re-creating the read amplification the visibility gating
    // removed (10 wire reads per push down to 1).
    var fired = 0;
    await tester.pumpWidget(
      _TabHost(onResume: () => fired++, isVisible: false),
    );
    await tester.pumpAndSettle();

    await _resume(tester);

    expect(fired, 0, reason: 'a background tab must not read on resume');
  });

  testWidgets('a resume on the SELECTED shell tab still fires', (
    tester,
  ) async {
    // The other half: gating must not silence the visible tab. Without this
    // the previous test would also pass with the callback wired to nothing.
    var fired = 0;
    await tester.pumpWidget(
      _TabHost(onResume: () => fired++, isVisible: true),
    );
    await tester.pumpAndSettle();

    await _resume(tester);

    expect(fired, 1);
  });

  testWidgets('a resume while the route is BURIED fires nothing', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(_Host(onResume: () => fired++));
    await tester.pumpAndSettle();

    await _pushOnTop(tester);
    await _resume(tester);

    expect(
      fired,
      0,
      reason: 'pixels nobody can see must not cost a read — mirrors the '
          'DeferredRefreshGate rule the dashboard card already respects',
    );
  });

  testWidgets(
    'the buried resume is DEFERRED, not dropped: returning pays exactly ONE',
    (tester) async {
      var fired = 0;
      await tester.pumpWidget(_Host(onResume: () => fired++));
      await tester.pumpAndSettle();

      await _pushOnTop(tester);
      await _resume(tester);
      expect(fired, 0);

      await _popTop(tester);

      expect(
        fired,
        1,
        reason: 'dropping it would leave the screen on a pre-resume snapshot '
            'with no error — invisible on the device and in a screenshot',
      );
    },
  );

  // THE DISCRIMINATOR. Without this case the test above is also passed by a
  // widget that simply refetches whenever a route pops — which would be a new,
  // unbounded read source rather than a resume backstop.
  testWidgets('returning to the route WITHOUT a resume fires nothing', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(_Host(onResume: () => fired++));
    await tester.pumpAndSettle();

    await _pushOnTop(tester);
    await _popTop(tester);

    expect(
      fired,
      0,
      reason: 'becoming visible is not itself an event; only an OWED resume is',
    );
  });

  testWidgets('N resumes while buried collapse onto ONE payment', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(_Host(onResume: () => fired++));
    await tester.pumpAndSettle();

    await _pushOnTop(tester);
    await _resume(tester);
    await _resume(tester);
    await _resume(tester);
    expect(fired, 0);

    await _popTop(tester);

    expect(
      fired,
      1,
      reason: 'the debt is a BOOLEAN: three missed resumes describe one '
          'snapshot to catch up to, not three reads',
    );
  });

  testWidgets('an inactive→resumed focus flap is not a resume', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_Host(onResume: () => fired++));
    await tester.pumpAndSettle();

    // A heads-up notification / the shade / a permission dialog: the app never
    // left the foreground, so nothing may refetch.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(_resumeSettle);
    await tester.pump();

    expect(fired, 0);

    // POSITIVE CONTROL — the same harness, the same widget, a real trip.
    // Without it the zero above is unreadable: a dead observer scores it too.
    await _resume(tester);
    expect(fired, 1);
  });
}
