// MIDNIGHT · M3-45 — the row's finding, pinned: `VoiceRequestScreen` is a
// pass-through onto M2-03's `VoiceRecordingScreen`, so this row ships no diff.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_request_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Chrome the wrapper must never grow: each of these is the delegate's to own.
const List<Type> _forbiddenBetween = <Type>[
  JeebMidnightField,
  JeebTopBar,
  Scaffold,
  AppBar,
  DecoratedBox,
  ColoredBox,
  Padding,
  SafeArea,
];

Widget _harness({
  VoiceSentCallback? onSent,
  VoidCallback? onSwitchToTyping,
}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: VoiceRequestScreen(
      onSent: onSent,
      onSwitchToTyping: onSwitchToTyping,
    ),
  );
}

/// The widget types mounted strictly between the wrapper and its delegate.
List<Type> _chainBetween(WidgetTester tester) {
  final chain = <Type>[];
  var reachedWrapper = false;
  tester.element(find.byType(VoiceRecordingScreen)).visitAncestorElements((
    element,
  ) {
    if (element.widget is VoiceRequestScreen) {
      reachedWrapper = true;
      return false;
    }
    chain.add(element.widget.runtimeType);
    return true;
  });
  expect(
    reachedWrapper,
    isTrue,
    reason: 'the delegate must be mounted BY the wrapper, not beside it',
  );
  return chain;
}

VoiceRecordingScreen _delegate(WidgetTester tester) =>
    tester.widget<VoiceRecordingScreen>(find.byType(VoiceRecordingScreen));

void main() {
  setUp(() {
    sl
      ..registerSingleton<VoiceRecorder>(FakeVoiceRecorder())
      ..registerSingleton<VoicePlayer>(FakeVoicePlayer())
      ..registerSingleton<VoiceRecordingRepository>(
        FakeVoiceRecordingRepository(),
      );
  });

  tearDown(() async => sl.reset());

  testWidgets('the wrapper renders the real voice-recording surface', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(VoiceRecordingScreen), findsOneWidget);
  });

  testWidgets('it contributes no chrome of its own', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    final chain = _chainBetween(tester);
    for (final Type forbidden in _forbiddenBetween) {
      expect(
        chain,
        isNot(contains(forbidden)),
        reason: '$forbidden between the wrapper and the delegate would double '
            "M2-03's chrome",
      );
    }
    expect(
      chain,
      isEmpty,
      reason: 'M3-45 ships as a pure pass-through: NOTHING may sit between the '
          'wrapper and the delegate, or this row acquires a surface of its own',
    );
  });

  testWidgets('the Midnight field and top bar are mounted exactly once', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(
      find.byType(JeebMidnightField),
      findsOneWidget,
      reason: 'the delegate owns the one field; a second one means the wrapper '
          'started painting',
    );
    expect(find.byType(JeebTopBar), findsOneWidget);
  });

  testWidgets('both callbacks reach the delegate by identity', (tester) async {
    void onSent(
      String id,
      String? transcript, {
      String? localAudioPath,
      Duration duration = Duration.zero,
    }) {}
    void onSwitchToTyping() {}

    await tester.pumpWidget(
      _harness(onSent: onSent, onSwitchToTyping: onSwitchToTyping),
    );
    await tester.pump();

    final delegate = _delegate(tester);
    expect(
      identical(delegate.onSent, onSent),
      isTrue,
      reason: 'the router bridges /voice-request and /compose-dictation through '
          'this callback; re-wrapping it would break both',
    );
    expect(identical(delegate.onSwitchToTyping, onSwitchToTyping), isTrue);
  });

  testWidgets('a null typing handoff stays null on the delegate', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(
      _delegate(tester).onSwitchToTyping,
      isNull,
      reason: 'null is what hides the Type satellite; a defaulted no-op would '
          'mount a dead control',
    );
    expect(_delegate(tester).onSent, isNull);
  });
}
