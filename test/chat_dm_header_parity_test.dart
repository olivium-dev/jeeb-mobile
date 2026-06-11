import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_fee_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Round-2 UX-fix regression pins for the DM chat header (Figma 56560:1605):
///   D1 — peer avatar renders as a circular image (never a bare glyph).
///   D2 — the back chevron mirrors with the ambient text direction.
///   D3 — the incoming (counterpart) bubble shows NO timestamp; only the
///        sender's bubble carries the time + ticks meta row.
///   pill — the "Order picked" action exposes its OWN semantics node so
///        Maestro/TalkBack can target it (the banner no longer merges it).
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

Widget _scaffold(PreferredSizeWidget appBar, {required Locale locale}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(appBar: appBar, body: const SizedBox.shrink()),
  );
}

Widget _body(Widget child, {Locale locale = const Locale('en')}) {
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

DeliveryChatMessage _text(String id, ChatAuthor author) =>
    DeliveryChatMessage.text(
      id: id,
      author: author,
      sentAt: DateTime(2026, 6, 11, 9, 41),
      status: author == ChatAuthor.me
          ? MessageStatus.read
          : MessageStatus.delivered,
      text: 'hello',
    );

void main() {
  setUpAll(_loadArbFromDisk);

  group('ChatAppBar — D1 avatar', () {
    testWidgets('renders a provided image as a circular photo, not a glyph',
        (tester) async {
      await tester.pumpWidget(_scaffold(
        const ChatAppBar(
          title: 'Sami Fawaz',
          avatarImage: AssetImage('assets/dev/peer_avatar_sample.jpg'),
          showAvatar: true,
        ),
        locale: const Locale('en'),
      ));
      await tester.pump();

      // A real circular image avatar — ClipOval + Image — not a bare initial.
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('S'), findsNothing);
    });

    testWidgets('falls back to an initial inside a circle when no image/url',
        (tester) async {
      await tester.pumpWidget(_scaffold(
        const ChatAppBar(title: 'Sami Fawaz', showAvatar: true),
        locale: const Locale('en'),
      ));
      await tester.pump();

      // Fallback is still a circular avatar carrying the initial — never a
      // bare glyph floating in the bar.
      expect(find.bySemanticsIdentifier('chat_detail_avatar'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
    });
  });

  group('ChatAppBar — D2 RTL header', () {
    testWidgets('back chevron points back in LTR and mirrors in RTL',
        (tester) async {
      await tester.pumpWidget(_scaffold(
        const ChatAppBar(title: 'Sami Fawaz', showAvatar: true),
        locale: const Locale('en'),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);

      await tester.pumpWidget(_scaffold(
        const ChatAppBar(title: 'Sami Fawaz', showAvatar: true),
        locale: const Locale('ar'),
      ));
      await tester.pump();
      // RTL: the chevron mirrors so it still reads as "back" (points to the
      // start/right edge) — no stray forward-arrow leaks into the header.
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    });
  });

  group('ChatMessageBubble — D3 incoming timestamp', () {
    testWidgets('incoming bubble shows no timestamp; outgoing shows one',
        (tester) async {
      await tester.pumpWidget(_body(
        Column(
          children: [
            ChatMessageBubble(message: _text('them', ChatAuthor.them)),
            ChatMessageBubble(message: _text('me', ChatAuthor.me)),
          ],
        ),
      ));
      await tester.pump();

      // Exactly one "09:41" — the sender's. The counterpart slot is empty
      // (Figma 56560:1605 leaves the incoming timestamp blank).
      expect(find.text('09:41'), findsOneWidget);
    });
  });

  group('ChatFeeBanner — Order-picked pill semantics', () {
    testWidgets('pill is an independently targetable button node (not merged)',
        (tester) async {
      final handle = tester.ensureSemantics();
      var picked = false;
      await tester.pumpWidget(_body(ChatFeeBanner(
        amount: r'$0.5',
        trailing: ChatFeeBannerTrailing.orderPicked,
        onOrderPicked: () => picked = true,
      )));
      await tester.pumpAndSettle();

      final pill = find.bySemanticsIdentifier('chat_dm_order_picked_button');
      expect(pill, findsOneWidget);
      expect(
        tester.getSemantics(pill),
        containsSemantics(
          identifier: 'chat_dm_order_picked_button',
          isButton: true,
        ),
      );
      // The banner host id stays addressable alongside the pill.
      expect(find.bySemanticsIdentifier('chat_dm_fee_banner'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-fee-banner-order-picked')));
      expect(picked, isTrue);
      handle.dispose();
    });
  });
}
