// Render tests for the JeeberHomeGreeting previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. The shared suite asserts each preview renders
// ITS OWN state; the group below pins the two behaviours unique to the jeeber
// header — ambient-over-threaded precedence, and the avatar-less shape three of
// its call sites produce.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/previews/jeeber_home/jeeber_home_greeting_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberHomeGreeting',
    const <String, Widget Function()>{
      'Named + avatar': jeeberHomeGreetingNamedWithAvatar,
      'Generic fallback': jeeberHomeGreetingFallback,
      'Threaded name, no avatar': jeeberHomeGreetingThreadedNameOnly,
      'Ambient profile wins': jeeberHomeGreetingAmbientWins,
      'Synthetic handle suppressed': jeeberHomeGreetingSyntheticHandle,
      'Long name ellipsis': jeeberHomeGreetingLongName,
    },
    expectedText: const <String, String>{
      'Named + avatar': 'Hello, Sami',
      'Generic fallback': 'Welcome back',
      'Threaded name, no avatar': 'Hello, Kamal',
      'Ambient profile wins': 'Hello, Layla',
      // The two suppressed-name states below also render 'Welcome back' — that
      // IS the assertion — so the specifics group distinguishes them by what
      // the avatar does.
      'Synthetic handle suppressed': 'Welcome back',
      'Long name ellipsis': 'Hello, Abdulrahman',
    },
  );

  group('JeeberHomeGreeting preview specifics', () {
    testWidgets('greets the FIRST name only', (WidgetTester tester) async {
      await pumpPreview(tester, jeeberHomeGreetingNamedWithAvatar);

      expect(find.text('Hello, Sami'), findsOneWidget);
      expect(find.textContaining('Fawaz'), findsNothing);
    });

    testWidgets('ambient profile name beats the threaded name (P0-X06)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberHomeGreetingAmbientWins);

      expect(find.text('Hello, Layla'), findsOneWidget);
      expect(find.text('Hello, Kamal'), findsNothing);
    });

    testWidgets('never shows the raw synthetic handle (audit §T5)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberHomeGreetingSyntheticHandle);

      expect(find.textContaining('jeeb-e1a35ea8a520'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
      // Documents current behaviour, not desired behaviour: the ambient handle
      // wins precedence before suppression runs, so the threaded 'Rami' is
      // discarded rather than used as the fallback.
      expect(find.text('Hello, Rami'), findsNothing);
      // The picture still resolves, but the initial degrades to '?' because it
      // is derived from the suppressed name.
      final OmdsProfileAvatar avatar = tester.widget<OmdsProfileAvatar>(
        find.byType(OmdsProfileAvatar),
      );
      expect(avatar.initial, '?');
      expect(avatar.profilePicUrl, 'https://cdn.jeeb.app/avatars/anon.png');
    });

    testWidgets('renders no avatar at all when no avatarUrl resolves', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        jeeberHomeGreetingFallback,
        jeeberHomeGreetingThreadedNameOnly,
      ]) {
        await pumpPreview(tester, preview);
        expect(find.byType(OmdsProfileAvatar), findsNothing);
      }
    });
  });
}
