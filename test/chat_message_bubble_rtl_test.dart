import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Directional bubble-alignment regression test.
///
/// Round-1 shipped non-directional `Alignment.centerRight/centerLeft`, so the
/// self bubble stayed pinned to the physical RIGHT even in Arabic/RTL —
/// violating Figma `design-spec.md` §4/§7-10 ("full mirror … trailing/leading,
/// not right/left"). The fix routes alignment through
/// `AlignmentDirectional.centerEnd/centerStart`; these tests assert the row
/// actually flips between LTR and RTL.
class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _host(Widget child, {required Locale locale}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

DeliveryChatMessage _msg(String id, ChatAuthor author) =>
    DeliveryChatMessage.text(
      id: id,
      author: author,
      sentAt: DateTime(2026, 6, 11, 9, 41),
      status: MessageStatus.read,
      text: 'hello',
    );

/// Centre-x of the bubble container relative to the screen centre.
/// Positive → bubble sits on the right half; negative → left half.
double _bubbleOffsetFromCentre(WidgetTester tester, String id) {
  final rect = tester.getRect(find.byKey(Key('chat-bubble-$id')));
  final screenCentre = tester.getRect(find.byType(Scaffold)).center.dx;
  return rect.center.dx - screenCentre;
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets('LTR: self bubble hugs the right, counterpart hugs the left',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            ChatMessageBubble(message: _msg('self', ChatAuthor.me)),
            ChatMessageBubble(message: _msg('them', ChatAuthor.them)),
          ],
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(_bubbleOffsetFromCentre(tester, 'self'), greaterThan(0));
    expect(_bubbleOffsetFromCentre(tester, 'them'), lessThan(0));
  });

  testWidgets('RTL mirrors: self bubble hugs the left, counterpart the right',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            ChatMessageBubble(message: _msg('self', ChatAuthor.me)),
            ChatMessageBubble(message: _msg('them', ChatAuthor.them)),
          ],
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    // The whole row must flip vs LTR — this is the round-1 regression.
    expect(_bubbleOffsetFromCentre(tester, 'self'), lessThan(0));
    expect(_bubbleOffsetFromCentre(tester, 'them'), greaterThan(0));
  });
}
