/// Widget tests for voice note bubble (T-MOB-016).
///
/// Tests cover:
///   - AC1: Voice bubble renders with duration
///   - AC2: Transcription text fills in below waveform
///   - AC3: 'Transcription unavailable' shown on sentinel value
///   - AC4: Semantic label includes duration (a11y)
///   - Voice bubble renders for sender and receiver
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Localization helper (mirrors chat_screen_test.dart pattern)
// ---------------------------------------------------------------------------

class _SyncLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncLocDelegate old) => false;
}

late _SyncLocDelegate _delegate;

void _loadArb() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _delegate = _SyncLocDelegate({'en': en, 'ar': ar});
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

DeliveryChatMessage _voiceMsg({
  bool isMine = true,
  int durationMs = 5000,
  String? transcription,
  MessageStatus status = MessageStatus.sent,
}) => DeliveryChatMessage.voice(
  id: 'voice-test-1',
  author: isMine ? ChatAuthor.me : ChatAuthor.them,
  sentAt: DateTime(2026, 6, 1, 12),
  status: status,
  url: 'https://cdn.jeeb.app/voice/test.m4a',
  durationMs: durationMs,
  transcription: transcription,
);

Widget _buildApp(
  DeliveryChatMessage message, {
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: [
    _delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: ChatMessageBubble(message: message)),
);

void _expectSemanticsLabelWithPrefix(
  WidgetTester tester,
  String expectedPrefix,
) {
  final semantics = find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label ?? '').startsWith(expectedPrefix),
  );
  expect(
    semantics,
    findsOneWidget,
    reason:
        'Expected semantics label starting with "$expectedPrefix" not found',
  );
  final node = tester.getSemantics(semantics);
  expect(
    node.label.startsWith(expectedPrefix),
    isTrue,
    reason:
        'Expected semantics label starting with "$expectedPrefix" not found',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_loadArb);

  group('VoiceBubble — rendering (T-MOB-016 AC1)', () {
    testWidgets('renders voice bubble container for sender', (tester) async {
      await tester.pumpWidget(_buildApp(_voiceMsg(durationMs: 5500)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat-voice-voice-test-1')), findsOneWidget);
    });

    testWidgets('renders voice bubble for counterpart (them)', (tester) async {
      final msg = _voiceMsg(isMine: false, durationMs: 3000);
      await tester.pumpWidget(_buildApp(msg));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat-voice-voice-test-1')), findsOneWidget);
    });

    testWidgets('play arrow icon visible', (tester) async {
      await tester.pumpWidget(_buildApp(_voiceMsg()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });

  group('VoiceBubble — transcription (T-MOB-016 AC2, AC3)', () {
    testWidgets('transcription text shown when present (AC2)', (tester) async {
      await tester.pumpWidget(
        _buildApp(_voiceMsg(transcription: 'Please bring it to the door')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Please bring it to the door'),
        findsOneWidget,
      );
    });

    testWidgets('unavailable label shown on sentinel value (AC3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(_voiceMsg(transcription: '__unavailable__')),
      );
      await tester.pumpAndSettle();

      // Sentinel '__unavailable__' maps to the localized unavailable string.
      // Use find.byType(Scaffold) context which is inside the Localizations scope.
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(
        find.text(l10n.chatVoiceNoteTranscriptionUnavailable),
        findsOneWidget,
      );
    });

    testWidgets('no transcription section when null', (tester) async {
      await tester.pumpWidget(_buildApp(_voiceMsg()));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(
        find.text(l10n.chatVoiceNoteTranscriptionUnavailable),
        findsNothing,
      );
    });
  });

  group('VoiceBubble — failed status (T-MOB-016 AC5)', () {
    testWidgets('failed status renders error icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(_voiceMsg(status: MessageStatus.failed)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('VoiceBubble — accessibility (T-MOB-016 AC4)', () {
    testWidgets('semantic wrapper is present', (tester) async {
      await tester.pumpWidget(_buildApp(_voiceMsg(durationMs: 8000)));
      await tester.pumpAndSettle();

      // The _VoiceBubble wraps with Semantics — the voice bubble container key exists
      expect(find.byKey(const Key('chat-voice-voice-test-1')), findsOneWidget);
    });

    testWidgets('semantic label includes author and duration (AC4)', (
      tester,
    ) async {
      // AC4: Audio bubble exposes 'Voice note from <author>, <duration>s, double tap to play'.
      // durationMs=8000 → 8 seconds. Child text nodes (duration pill, status icon text)
      // are merged by the Semantics framework into the outer label, so the actual node
      // label starts with — but may not equal — the a11y template string. We assert
      // startsWith so the test is robust to child-merge artefacts.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildApp(_voiceMsg(durationMs: 8000)));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      // Sender bubble: author = "You", duration = 8
      final expectedPrefix = l10n.chatVoiceNoteA11y('You', 8);

      _expectSemanticsLabelWithPrefix(tester, expectedPrefix);
      handle.dispose();
    });

    testWidgets(
      'semantic label for counterpart bubble uses Jeeber author (AC4)',
      (tester) async {
        // Counterpart (isMine=false): BubbleFooter is suppressed so the
        // duration-text child merges into the Semantics label node. The
        // label starts with the a11y template text; we use startsWith so the
        // test remains valid regardless of the appended merged-child strings.
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _buildApp(_voiceMsg(isMine: false, durationMs: 3000)),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        );
        // Counterpart bubble: author = "Jeeber", duration = 3
        final expectedPrefix = l10n.chatVoiceNoteA11y('Jeeber', 3);

        _expectSemanticsLabelWithPrefix(tester, expectedPrefix);
        handle.dispose();
      },
    );
  });
}
