import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/app/jeeb_bootstrap.dart';
import 'package:jeeb_mobile/app/app_restarter.dart';
import 'package:jeeb_mobile/core/dev_flags.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/devtool_shell.dart';
import 'package:jeeb_mobile/devtool/shake/devtool_shake.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_demo_user.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_service.dart';

/// Wall clock stand-in so the debounce window is asserted deterministically
/// instead of with real sleeps. This fakes TIME, never the code under test:
/// the channel, the handler, the gate and the widget tree are all real.
class _FakeClock {
  DateTime value = DateTime(2026, 8, 26, 12);

  DateTime call() => value;

  void advance(Duration delta) => value = value.add(delta);
}

const Key _layerContentKey = ValueKey<String>('test-dev-tool-layer-content');

/// Stands in for an already-registered `SuperLoginService` so the idempotent
/// re-registration can be shown NOT to clobber it.
class _StubSuperLoginService implements SuperLoginService {
  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async => const SuperLoginFailure(SuperLoginError.network);
}

/// Delivers a real native→Dart platform message on the shake channel, exactly
/// as `AppDelegate.motionEnded` does through `invokeMethod`.
Future<ByteData?> _deliverShake(
  WidgetTester tester, {
  String method = kDevToolShakeOpenMethod,
}) => _deliverNativeOpen(
  tester,
  channelName: kDevToolShakeChannelName,
  method: method,
);

Future<ByteData?> _deliverLauncherOpen(WidgetTester tester) =>
    _deliverNativeOpen(tester, channelName: kDevToolLauncherChannelName);

Future<ByteData?> _deliverNativeOpen(
  WidgetTester tester, {
  required String channelName,
  String method = kDevToolShakeOpenMethod,
}) async {
  final ByteData? reply = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
        null,
      );
  await tester.pump();
  return reply;
}

// The real product theme: the Dev Tool layer deliberately inherits it rather
// than building its own MaterialApp, and it pins `InkRipple.splashFactory`
// (app_theme.dart:175) — the default M3 InkSparkle shader cannot be compiled
// in the test environment.
//
// TOPOLOGY MATTERS, so this harness mirrors production exactly: `app/app.dart`
// mounts the host in `MaterialApp.router`'s `builder`, i.e. ABOVE the app's
// Navigator — which is the app's only `Overlay`. Mounting it under `home:`
// instead (below the Navigator) hands the layer an `Overlay` ancestor that a
// real build never has, and silently certifies a layer that throws on open.
/// Counts how many times the product subtree has been mounted, so a test can
/// tell a genuine remount (what a restart does) from merely hiding the layer.
class _ProductProbe extends StatefulWidget {
  const _ProductProbe();

  static int generations = 0;

  @override
  State<_ProductProbe> createState() => _ProductProbeState();
}

class _ProductProbeState extends State<_ProductProbe> {
  @override
  void initState() {
    super.initState();
    _ProductProbe.generations++;
  }

  @override
  Widget build(BuildContext context) => const Text('PRODUCT UI');
}

Widget _hostUnderTest(
  _FakeClock clock, {
  bool initiallyOpen = false,
  bool shakeEnabled = true,
}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => DevToolShakeHost(
    initiallyOpen: initiallyOpen,
    shakeEnabled: shakeEnabled,
    clock: clock.call,
    layerBuilder: (_) => const Scaffold(
      body: Center(child: Text('DEV TOOL', key: _layerContentKey)),
    ),
    child: child!,
  ),
  home: const Scaffold(body: Center(child: _ProductProbe())),
);

void main() {
  group('shake-to-Dev-Tool compile gate', () {
    // `defaultDevToolShakeLayer` registers the Dev Tool's Super Login
    // dependencies in the shared GetIt instance whenever the gate is ON, so
    // the gate-ON branch below would otherwise leak that registration into
    // every later group in this file.
    tearDown(sl.reset);

    test('defaults on, but only inside a Dev Tool build', () {
      const requested = bool.fromEnvironment(
        'JEEB_DEVTOOL_SHAKE',
        defaultValue: true,
      );

      expect(kShakeToDevToolRequested, requested);
      expect(kShakeToDevToolEnabled, kDevToolEnabled && requested);
      expect(
        kShakeToDevToolEnabled && !kDebugMode,
        isFalse,
        reason: 'a release build must never compile the shake wiring in',
      );
    });

    test('hard-locks the shake gate to the Dev Tool gate', () {
      final source = File('lib/core/dev_flags.dart').readAsStringSync();

      expect(
        source,
        contains(
          'const bool kShakeToDevToolEnabled = '
          'kDevToolEnabled && kShakeToDevToolRequested;',
        ),
        reason: 'a release supplied with the define must remain locked',
      );
    });

    testWidgets('the default layer follows the strict gate, not debug '
        'affordances', (tester) async {
      // `DevToolShell` hard-asserts `kDevToolEnabled`, so the default layer
      // must resolve to an empty box whenever the gate is off — that is what
      // lets the shell (and its `Super Login` literals) tree-shake away.
      Widget? layer;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            layer = defaultDevToolShakeLayer(context);
            return const SizedBox.shrink();
          },
        ),
      );

      if (kDevToolEnabled) {
        expect(layer, isNot(isA<SizedBox>()));
      } else {
        expect(layer, isA<SizedBox>());
      }
    });

    test(
      'the product app keeps the host in context behind the strict gate',
      () {
        final source = File('lib/app/app.dart').readAsStringSync();
        final guardedHost = RegExp(
          r"kDevToolEnabled\s*\?\s*DevToolShakeHost\(\s*"
          r"initiallyOpen:\s*widget\.consumeDevToolInitialOpen\?\.call\(\)\s*"
          r"\?\?\s*false,\s*shakeEnabled:\s*kShakeToDevToolEnabled,",
        );

        expect(
          source,
          contains("import '../devtool/shake/devtool_shake.dart';"),
        );
        expect(
          guardedHost.hasMatch(source),
          isTrue,
          reason:
              'initial launch must remain independent of the optional shake '
              'channel while the whole host stays behind the strict gate',
        );
        expect(source, isNot(contains('PlatformDispatcher.instance')));
        expect(
          source,
          contains('final maskedProduct = ClarityMask(child: productUi);'),
          reason: 'the Dev Tool must stay inside the Clarity privacy mask',
        );
      },
    );

    test('the native half is gated independently of the Dart half', () {
      final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(swift, contains('#if JEEB_DEV'));
      expect(swift, contains('override func motionEnded('));
      expect(swift, contains('com.olivium.jeeb/devtool_shake'));
      expect(
        swift,
        contains('applicationSupportsShakeToEdit = false'),
        reason: 'otherwise iOS shows its "Undo Typing" alert on every shake',
      );
      expect(
        swift,
        isNot(matches(RegExp(r'^\s*#if\s+DEBUG', multiLine: true))),
        reason:
            'the Runner target defines JEEB_DEV WITHOUT DEBUG, so a DEBUG '
            'gate would compile the feature into nothing',
      );
    });
  });

  group('pre-bootstrap launcher selection', () {
    test(
      'the neutral main entrypoint passes the route to the root factory',
      () {
        final source = File('lib/main.dart').readAsStringSync();

        expect(
          RegExp(
            r'runApp\(\s*buildJeebRootForInitialRoute\(\s*'
            r'WidgetsBinding\.instance\.platformDispatcher\.defaultRouteName,?'
            r'\s*\),?\s*\)',
          ).hasMatch(source),
          isTrue,
        );
        expect(source.toLowerCase(), isNot(contains('devtool')));
        expect(source, isNot(contains("'/devtool'")));
      },
    );

    test('the factory selects before constructing JeebRoot', () {
      final source = File('lib/app/jeeb_bootstrap.dart').readAsStringSync();
      final factoryStart = source.indexOf('buildJeebRootForInitialRoute');
      final selection = source.indexOf('shouldLaunchDevTool(', factoryStart);
      final rootConstruction = source.indexOf('return JeebRoot(', factoryStart);

      expect(factoryStart, greaterThanOrEqualTo(0));
      expect(selection, greaterThan(factoryStart));
      expect(rootConstruction, greaterThan(selection));
      expect(
        source.indexOf('GoRouter', factoryStart),
        anyOf(-1, greaterThan(rootConstruction)),
      );
    });

    test('the factory preserves exact matching and the compile gate', () {
      final exact = buildJeebRootForInitialRoute('/devtool') as JeebRoot;
      expect(exact.devToolInitiallyPending, kDevToolEnabled);

      for (final route in <String>[
        '/',
        '',
        '/devtool/',
        '/devtool?source=launcher',
        '/devtools',
        '/DevTool',
        'devtool',
      ]) {
        final root = buildJeebRootForInitialRoute(route) as JeebRoot;
        expect(root.devToolInitiallyPending, isFalse, reason: route);
      }
    });

    test('the product router keeps its exact fail-closed fallback', () {
      final source = File('lib/core/router/app_router.dart').readAsStringSync();

      expect(
        source,
        contains("if (state.matchedLocation == '/devtool') return '/';"),
      );
    });
  });

  group('Dev Tool Super Login dependencies', () {
    tearDown(sl.reset);

    test(
      'registration covers exactly what the sheet resolves out of GetIt',
      () {
        expect(sl.isRegistered<SuperLoginService>(), isFalse);
        expect(sl.isRegistered<SuperLoginDemoUserService>(), isFalse);

        registerDevToolSuperLoginDependencies();

        expect(
          sl.isRegistered<SuperLoginService>(),
          isTrue,
          reason: 'super_login_sheet.dart resolves sl<SuperLoginService>()',
        );
        expect(
          sl.isRegistered<SuperLoginDemoUserService>(),
          isTrue,
          reason:
              'super_login_picker.dart resolves '
              'sl<SuperLoginDemoUserService>()',
        );
      },
    );

    test('is idempotent, so both Dev Tool entry points may call it', () {
      // GetIt has `allowReassignment` off (never set anywhere in lib/), so a
      // guardless second registration would throw ArgumentError — and both
      // entry points can run in one process on a dev build.
      final existing = _StubSuperLoginService();
      sl.registerSingleton<SuperLoginService>(existing);

      registerDevToolSuperLoginDependencies();
      registerDevToolSuperLoginDependencies();

      expect(
        identical(sl<SuperLoginService>(), existing),
        isTrue,
        reason: 'an existing registration must survive untouched',
      );
      expect(sl.isRegistered<SuperLoginDemoUserService>(), isTrue);
    });

    testWidgets('building the default layer actually performs that '
        'registration', (tester) async {
      // Behavioural counterpart to the source-text ordering check below: with
      // the gate ON, asking for the layer must leave Super Login resolvable
      // out of GetIt; with the gate OFF the layer is an empty box and must
      // stay side-effect free.
      expect(sl.isRegistered<SuperLoginService>(), isFalse);

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            defaultDevToolShakeLayer(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(
        sl.isRegistered<SuperLoginService>(),
        kDevToolEnabled,
        reason: kDevToolEnabled
            ? 'Dev Tool > Super Login resolves sl<SuperLoginService>()'
            : 'the gate-off branch must register nothing',
      );
      expect(sl.isRegistered<SuperLoginDemoUserService>(), kDevToolEnabled);
    });

    test('the shake layer registers them before it builds the shell', () {
      // The shake path never runs Bootstrap.minimal and product DI does not
      // register these, so without this call Dev Tool > Super Login throws.
      final source = File(
        'lib/devtool/shake/devtool_shake.dart',
      ).readAsStringSync();

      final int registerAt = source.indexOf(
        'registerDevToolSuperLoginDependencies();',
      );
      final int shellAt = source.indexOf('return const DevToolShell();');

      expect(registerAt, greaterThan(-1));
      expect(shellAt, greaterThan(-1));
      expect(
        registerAt,
        lessThan(shellAt),
        reason: 'the shell must never be built before its GetIt dependencies',
      );
    });
  });

  group('DevToolShakeGate', () {
    test('opens on the first delivery', () {
      final gate = DevToolShakeGate();

      expect(gate.shouldOpen(alreadyOpen: false, now: DateTime(2026)), isTrue);
    });

    test('suppresses a repeat delivery inside the debounce window', () {
      final gate = DevToolShakeGate(window: const Duration(seconds: 1));
      final start = DateTime(2026);

      expect(gate.shouldOpen(alreadyOpen: false, now: start), isTrue);
      for (final millis in <int>[1, 100, 500, 999]) {
        expect(
          gate.shouldOpen(
            alreadyOpen: false,
            now: start.add(Duration(milliseconds: millis)),
          ),
          isFalse,
          reason: 'delta=${millis}ms',
        );
      }
    });

    test('opens again once the window has elapsed', () {
      final gate = DevToolShakeGate(window: const Duration(seconds: 1));
      final start = DateTime(2026);

      expect(gate.shouldOpen(alreadyOpen: false, now: start), isTrue);
      expect(
        gate.shouldOpen(
          alreadyOpen: false,
          now: start.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('is a no-op while the Dev Tool is already on top', () {
      final gate = DevToolShakeGate(window: const Duration(seconds: 1));
      final start = DateTime(2026);

      expect(gate.shouldOpen(alreadyOpen: true, now: start), isFalse);
      // The rejected delivery must not have started the debounce window: the
      // window measures accepted opens, not delivered shakes.
      expect(gate.shouldOpen(alreadyOpen: false, now: start), isTrue);
    });
  });

  group('DevToolShakeHost', () {
    testWidgets('initiallyOpen mounts the Dev Tool over the product UI', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostUnderTest(_FakeClock(), initiallyOpen: true),
      );

      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);
      expect(find.byKey(_layerContentKey), findsOneWidget);
      expect(find.text('PRODUCT UI'), findsOneWidget);
    });

    testWidgets('initiallyOpen defaults false and keeps only product UI', (
      tester,
    ) async {
      await tester.pumpWidget(_hostUnderTest(_FakeClock()));

      expect(find.byKey(kDevToolShakeLayerKey), findsNothing);
      expect(find.byKey(_layerContentKey), findsNothing);
      expect(find.text('PRODUCT UI'), findsOneWidget);
    });

    testWidgets('updating initiallyOpen does not close an open host', (
      tester,
    ) async {
      final clock = _FakeClock();
      await tester.pumpWidget(_hostUnderTest(clock, initiallyOpen: true));
      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);

      await tester.pumpWidget(_hostUnderTest(clock));

      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);
      expect(find.text('PRODUCT UI'), findsOneWidget);
    });

    testWidgets('initial launch works with the shake channel disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostUnderTest(_FakeClock(), initiallyOpen: true, shakeEnabled: false),
      );

      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);
      await tester.tap(find.byKey(kDevToolShakeCloseKey));
      await tester.pumpAndSettle();
      expect(await _deliverShake(tester), isNull);
      expect(find.byKey(kDevToolShakeLayerKey), findsNothing);
    });

    testWidgets('launcher reopens while the shake channel is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostUnderTest(_FakeClock(), initiallyOpen: true, shakeEnabled: false),
      );
      await tester.tap(find.byKey(kDevToolShakeCloseKey));
      await tester.pumpAndSettle();

      expect(await _deliverLauncherOpen(tester), isNotNull);
      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);
    });

    testWidgets('a native shake mounts the Dev Tool over the product UI', (
      tester,
    ) async {
      final clock = _FakeClock();
      await tester.pumpWidget(_hostUnderTest(clock));

      expect(find.byKey(kDevToolShakeLayerKey), findsNothing);
      expect(find.text('PRODUCT UI'), findsOneWidget);

      await _deliverShake(tester);

      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);
      expect(find.byKey(_layerContentKey), findsOneWidget);
    });

    testWidgets('a second shake while open is a no-op', (tester) async {
      final clock = _FakeClock();
      await tester.pumpWidget(_hostUnderTest(clock));

      await _deliverShake(tester);
      clock.advance(const Duration(seconds: 10));
      await _deliverShake(tester);

      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);
      expect(find.byKey(_layerContentKey), findsOneWidget);
    });

    testWidgets('the debounce suppresses a rapid re-open after closing', (
      tester,
    ) async {
      final clock = _FakeClock();
      await tester.pumpWidget(_hostUnderTest(clock));

      await _deliverShake(tester);
      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);

      await tester.tap(find.byKey(kDevToolShakeCloseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(kDevToolShakeLayerKey), findsNothing);

      // Same instant: one physical shake can deliver motionEnded twice.
      await _deliverShake(tester);
      expect(
        find.byKey(kDevToolShakeLayerKey),
        findsNothing,
        reason: 'a repeat delivery inside the window must not re-open',
      );

      clock.advance(const Duration(seconds: 2));
      await _deliverShake(tester);
      expect(
        find.byKey(kDevToolShakeLayerKey),
        findsOneWidget,
        reason: 'a genuine later shake must still open the tool',
      );
    });

    testWidgets('an unknown method is ignored', (tester) async {
      final clock = _FakeClock();
      await tester.pumpWidget(_hostUnderTest(clock));

      await _deliverShake(tester, method: 'somethingElse');

      expect(find.byKey(kDevToolShakeLayerKey), findsNothing);
    });

    testWidgets('a same-frame host swap leaves the shake alive', (
      tester,
    ) async {
      // Regression: `dispose` used to clear the channel-name-global handler
      // unconditionally. Flutter runs the NEW host's `initState` before the
      // OLD host's `dispose`, so a swap of an ancestor widget type — what
      // `app/app.dart` does when it rebuilds `ClarityMask` into
      // `ClarityWidget` on Clarity consent — left the handler null and shake
      // silently dead for the rest of the process.
      final clock = _FakeClock();
      final host = DevToolShakeHost(
        clock: clock.call,
        layerBuilder: (_) => const Scaffold(
          body: Center(child: Text('DEV TOOL', key: _layerContentKey)),
        ),
        child: const Scaffold(body: Center(child: Text('PRODUCT UI'))),
      );
      Widget tree({required bool swapped}) => MaterialApp(
        theme: AppTheme.light(),
        home: swapped
            ? ColoredBox(color: const Color(0xFF000000), child: host)
            : DecoratedBox(decoration: const BoxDecoration(), child: host),
      );

      await tester.pumpWidget(tree(swapped: false));
      final State first = tester.state(find.byType(DevToolShakeHost));

      await tester.pumpWidget(tree(swapped: true));
      final State second = tester.state(find.byType(DevToolShakeHost));

      // Positive controls: the ancestor swap really did re-inflate the host,
      // and the superseded state really was disposed — so the ordering this
      // test exists to cover was genuinely exercised.
      expect(
        identical(first, second),
        isFalse,
        reason: 'the ancestor type change must re-inflate the host',
      );
      expect(
        first.mounted,
        isFalse,
        reason: "the superseded host's dispose must have run",
      );

      await _deliverShake(tester);

      expect(
        find.byKey(kDevToolShakeLayerKey),
        findsOneWidget,
        reason:
            "the old host's teardown must not clear its successor's "
            'handler',
      );
    });

    testWidgets('the channel handler is torn down on dispose', (tester) async {
      final clock = _FakeClock();
      await tester.pumpWidget(_hostUnderTest(clock));

      // Positive control: a handler IS registered while mounted, so the
      // messenger returns an encoded reply envelope.
      expect(await _deliverShake(tester), isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        await _deliverShake(tester),
        isNull,
        reason: 'dispose must clear the method-call handler',
      );
    });
  });

  // Regression group for the two ways the layer can be built into a tree that
  // cannot support it. BOTH only reproduce when the host is mounted where
  // production mounts it — inside `MaterialApp`'s `builder`, ABOVE the app's
  // Navigator. Under `home:` the layer inherits an `Overlay` and a private
  // hero scope it never has in a real build, and both defects vanish.
  group('DevToolShakeHost survives the production topology', () {
    testWidgets(
      'the harness really is Overlay-less and hero-shared above the host',
      (tester) async {
        await tester.pumpWidget(_hostUnderTest(_FakeClock()));

        // Control for the two tests below: assert the harness reproduces the
        // hostile ancestry rather than merely passing. If a future edit moves
        // the host back under `home:`, this fails and the regressions below
        // stop being meaningful silently.
        final BuildContext hostContext = tester.element(
          find.byType(DevToolShakeHost),
        );
        expect(
          hostContext.findAncestorWidgetOfExactType<Overlay>(),
          isNull,
          reason:
              'production mounts the host above the app Navigator, which '
              'is the app\'s only Overlay',
        );
        expect(
          HeroControllerScope.of(hostContext),
          isNotNull,
          reason:
              "MaterialApp publishes its hero controller above `builder`, "
              'so a nested Navigator would adopt the app\'s controller',
        );
      },
    );

    testWidgets('opening the layer throws nothing', (tester) async {
      await tester.pumpWidget(_hostUnderTest(_FakeClock()));
      await _deliverShake(tester);

      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'no Overlay assert and no shared-HeroController assert',
      );
      expect(
        find.byType(ErrorWidget),
        findsNothing,
        reason:
            'a thrown assert would replace the close button with a red '
            'ErrorWidget',
      );
    });

    testWidgets(
      'Apply & Restart restarts the app so Dev Tool settings take effect',
      (tester) async {
        // The Server URL is saved to SharedPreferences but `Dio` is a LAZY
        // singleton built over `DevBaseUrl.read(prefs)` — already resolved by
        // the time the Dev Tool opens. Without a restart the new URL is inert,
        // which is why `dev_settings_page` tells the user to restart. Closing
        // must therefore rebuild the tree, not merely hide the layer.
        final clock = _FakeClock();
        await tester.pumpWidget(AppRestarter(child: _hostUnderTest(clock)));
        final int firstGeneration = _ProductProbe.generations;

        await _deliverShake(tester);
        expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);

        await tester.tap(find.byKey(kDevToolShakeApplyKey));
        // Three pumps: hide the layer, commit the teardown frame the restart
        // awaits via `endOfFrame`, then mount the new generation.
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          _ProductProbe.generations,
          greaterThan(firstGeneration),
          reason:
              'Apply must remount the app subtree, not just hide the '
              'Dev Tool — otherwise the already-resolved Dio keeps the old '
              'base URL and the saved setting never applies',
        );
        expect(find.byKey(kDevToolShakeLayerKey), findsNothing);
      },
    );

    testWidgets('Apply without an AppRestarter above is a harmless no-op', (
      tester,
    ) async {
      // Production compiles the wrap out (`kDevToolEnabled` is a const
      // false), and widget tests do not install one. Close must still work
      // rather than throwing at a user who just tapped it.
      final clock = _FakeClock();
      await tester.pumpWidget(_hostUnderTest(clock));

      await _deliverShake(tester);
      await tester.tap(find.byKey(kDevToolShakeApplyKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(kDevToolShakeLayerKey), findsNothing);
    });

    testWidgets(
      'X closes from a pushed Dev Tool page, it is not a Back button',
      (tester) async {
        // Regression: `X` used to pop one level of the Dev Tool's own stack
        // when it could, so a user several pages deep tapped "close" and stayed
        // inside the tool. Back within the tool is the AppBar's job.
        final clock = _FakeClock();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => DevToolShakeHost(
              clock: clock.call,
              layerBuilder: (_) => Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: Center(child: Text('DEEP DEV TOOL PAGE')),
                          ),
                        ),
                      ),
                      child: const Text('go deeper'),
                    ),
                  ),
                ),
              ),
              child: child!,
            ),
            home: const Scaffold(body: Center(child: _ProductProbe())),
          ),
        );

        await _deliverShake(tester);
        await tester.tap(find.text('go deeper'));
        await tester.pumpAndSettle();
        expect(find.text('DEEP DEV TOOL PAGE'), findsOneWidget);

        await tester.tap(find.byKey(kDevToolShakeCloseKey));
        await tester.pumpAndSettle();

        expect(
          find.byKey(kDevToolShakeLayerKey),
          findsNothing,
          reason:
              'ONE tap on X must leave the Dev Tool entirely, however deep '
              'the user has navigated inside it',
        );
        expect(find.text('PRODUCT UI'), findsOneWidget);
      },
    );

    testWidgets(
      'X closes WITHOUT restarting, so an accidental shake costs nothing',
      (tester) async {
        // The Dev Tool opens on a physical gesture that fires by accident, so
        // the universal "dismiss" control must be genuinely free: no cold
        // start, no lost screen state.
        final clock = _FakeClock();
        await tester.pumpWidget(AppRestarter(child: _hostUnderTest(clock)));
        final int firstGeneration = _ProductProbe.generations;

        await _deliverShake(tester);
        expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);

        await tester.tap(find.byKey(kDevToolShakeCloseKey));
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byKey(kDevToolShakeLayerKey), findsNothing);
        expect(
          _ProductProbe.generations,
          firstGeneration,
          reason:
              'X must not remount the app — restarting on an accidental '
              'open is exactly the cost this control exists to avoid',
        );
      },
    );

    testWidgets('the close affordance really closes the layer', (tester) async {
      await tester.pumpWidget(_hostUnderTest(_FakeClock()));
      await _deliverShake(tester);
      expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);

      await tester.tap(find.byKey(kDevToolShakeCloseKey));
      await tester.pumpAndSettle();

      // iOS has no hardware back button and the layer's root route has no
      // AppBar, so this button is the ONLY exit. If it is an ErrorWidget the
      // tap is inert and the tool can only be escaped by killing the app.
      expect(
        find.byKey(kDevToolShakeLayerKey),
        findsNothing,
        reason: 'the close FAB is the only way out of the Dev Tool on iOS',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the close affordance keeps an accessible name', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(_hostUnderTest(_FakeClock()));
      await _deliverShake(tester);

      // Dropping `tooltip:` removed the FAB's only accessible label; the
      // replacement must genuinely reach the semantics tree.
      expect(
        tester.getSemantics(find.byKey(kDevToolShakeCloseKey)),
        matchesSemantics(
          label: 'Close Dev Tool without restarting',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );

      handle.dispose();
    });
  });
}
