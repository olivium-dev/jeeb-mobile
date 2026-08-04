// Guard for the wave-B/C harness lesson (02-STUDY-NOTES §Wave-C review rulings):
// a harness that mounts ShellScreen and calls pumpAndSettle MUST reduce motion.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// The ONE sanctioned wrapper. `MediaQuery.of(context).copyWith` (not a bare
/// `MediaQueryData`) so the harness keeps the real view metrics.
Widget _sanctionedBuilder(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child!,
);

Widget _shellHarness(SharedPreferences prefs, {required bool reduceMotion}) =>
    MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider(
          create: (_) => LocaleCubit(
            prefs: prefs,
            deviceLocaleProvider: () => const Locale('en'),
          ),
        ),
        BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
        BlocProvider(create: (_) => RoleEligibilityCubit()),
      ],
      child: MaterialApp(
        theme: AppTheme.midnight(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ShellScreen(),
        builder: reduceMotion ? _sanctionedBuilder : null,
      ),
    );

/// A CONSTRUCTOR call, so `find.byType(ShellScreen)` in a test that only
/// asserts on someone else's tree is not mistaken for mounting one.
final RegExp _mountsShell = RegExp(r'\bShellScreen\s*\(');

const String _fixSnippet = '''
        // JeebEmptyState's E1 illustration loops by design; the reduce-motion
        // rest frame is the only state pumpAndSettle can terminate on.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),''';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('reduce-motion wrapper is load-bearing for ShellScreen', () {
    testWidgets('WITHOUT it the shell never settles', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_shellHarness(prefs, reduceMotion: false));

      Object? thrown;
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 16),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 1),
        );
      } catch (error) {
        thrown = error;
      }

      expect(
        thrown,
        isA<FlutterError>(),
        reason:
            'ShellScreen settled without reduce motion. If the infinite '
            'illustration loop was removed on purpose, this whole convention '
            '(and the 15 harness wrappers) can be retired — see '
            'docs/redesign-midnight/03-MOTION-NOTES.md.',
      );
      expect('$thrown', contains('pumpAndSettle timed out'));
    });

    testWidgets('WITH it the shell settles', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_shellHarness(prefs, reduceMotion: true));
      await tester.pumpAndSettle();

      expect(find.byType(ShellScreen), findsOneWidget);
    });
  });

  // The behavioural pair above proves the mechanism but can only speak for
  // itself; this is the half that sees a harness written tomorrow.
  test('every ShellScreen-mounting harness that settles reduces motion', () {
    final offenders = <String>[];
    final scanned = <String>[];

    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      final source = entity.readAsStringSync();
      if (!_mountsShell.hasMatch(source)) continue;
      if (!source.contains('pumpAndSettle')) continue;
      scanned.add(entity.path);
      if (!source.contains('disableAnimations')) offenders.add(entity.path);
    }

    expect(
      scanned,
      isNotEmpty,
      reason:
          'The scan matched nothing, so it is guarding nothing. ShellScreen '
          'was probably renamed — update _mountsShell in this file.',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'These harnesses mount ShellScreen and call pumpAndSettle without '
          'reducing motion, so they will hang and report a "pumpAndSettle '
          'timed out" that reads like a product bug:\n'
          '  ${offenders.join('\n  ')}\n'
          'Add the sanctioned MaterialApp builder:\n$_fixSnippet\n'
          'A FakeAccessibilityFeatures(disableAnimations: true) on '
          'tester.platformDispatcher satisfies this guard too.',
    );
  });
}
