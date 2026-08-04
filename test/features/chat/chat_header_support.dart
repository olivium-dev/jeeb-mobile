/// Shared harness for the b02 chat-header redesign tests.
/// Kept in one place so the contrast test, the overflow/budget test and the
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// WCAG 2.2 relative-luminance contrast ratio, in [1, 21].
/// `Color.computeLuminance()` is Flutter's implementation of the WCAG
double contrastRatio(Color fg, Color bg) {
  final l1 = fg.computeLuminance();
  final l2 = bg.computeLuminance();
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// Composites [fg] at [alpha] over [bg] — what the eye actually receives when a
/// foreground is faded, and therefore what must be measured. Measuring the
Color blend(Color fg, Color bg, double alpha) =>
    Color.alphaBlend(fg.withValues(alpha: alpha), bg);

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// WCAG 2.2 AA thresholds.
const double kAaBodyText = 4.5;
const double kAaLargeTextAndNonText = 3.0;

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

void loadArb() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _delegate = _SyncLocDelegate({'en': en, 'ar': ar});
}

/// Hosts [child] in the REAL app theme.
/// [keyboardInset] simulates an open soft keyboard the way the platform does —
Widget themedHost(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double keyboardInset = 0,
  double textScale = 1.0,
}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode:
          brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
          textScaler: TextScaler.linear(textScale),
        ),
        child: inner!,
      ),
      home: child,
    );

/// A chat gateway with a fixed phase and a fixed, non-empty history.
class FakeChatGateway extends ChatGateway {
  FakeChatGateway({required this.phase, this.history = const []});

  final ConversationPhase phase;
  final List<DeliveryChatMessage> history;
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<ConversationPhase> loadPhase(String id) async => phase;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => history;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;

  Future<void> dispose() => _controller.close();
}

/// A short, realistic thread so the message list renders real rows rather than
/// the empty state.
List<DeliveryChatMessage> sampleThread() => <DeliveryChatMessage>[
      DeliveryChatMessage.text(
        id: 'm1',
        author: ChatAuthor.them,
        sentAt: DateTime.utc(2026, 7, 28, 9),
        status: MessageStatus.delivered,
        text: 'On my way to the shop.',
      ),
      DeliveryChatMessage.text(
        id: 'm2',
        author: ChatAuthor.me,
        sentAt: DateTime.utc(2026, 7, 28, 9, 1),
        status: MessageStatus.sent,
        text: 'Great, thank you.',
      ),
    ];
