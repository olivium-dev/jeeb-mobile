import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
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

/// A 1×1 transparent PNG, used to drive the [ChatAppBar.avatarImage] path
/// without depending on a bundled (release-shipped) asset.
final _transparentPng = MemoryImage(Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]));

void main() {
  setUpAll(_loadArbFromDisk);

  group('ChatAppBar — D1 avatar', () {
    testWidgets('renders a provided image as a circular photo, not a glyph',
        (tester) async {
      await tester.pumpWidget(_scaffold(
        ChatAppBar(
          title: 'Sami Fawaz',
          avatarImage: _transparentPng,
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

    // mob-avatar: the header photo now arrives as a URL off the delivery read
    // (`jeeberAvatarUrl` / `clientAvatarUrl`), not as bound bytes. Pin that the
    // url path reaches JeebAvatar and displaces the letter placeholder.
    testWidgets('a counterpart avatar URL renders the photo, not the initial',
        (tester) async {
      await tester.pumpWidget(_scaffold(
        const ChatAppBar(
          title: 'Sami Fawaz',
          avatarUrl: 'http://gw.test/api/users/u-1/avatar?v=abc',
          showAvatar: true,
        ),
        locale: const Locale('en'),
      ));
      await tester.pump();

      final avatar = tester.widget<JeebAvatar>(find.byType(JeebAvatar));
      expect(avatar.imageUrl, 'http://gw.test/api/users/u-1/avatar?v=abc');
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
      // redesign-2026-08: the leading circle is the kit's, and it resolves its
      // glyph through `DirectionalIcons.back` — `arrow_back`/`arrow_forward`
      // rather than the old chevrons. The DIRECTIONAL INTENT this test exists
      // for is unchanged and still asserted in both directions.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);

      await tester.pumpWidget(_scaffold(
        const ChatAppBar(title: 'Sami Fawaz', showAvatar: true),
        locale: const Locale('ar'),
      ));
      await tester.pump();
      // D3: `Icons.arrow_back` declares matchTextDirection, so the FRAMEWORK
      // mirrors it under RTL. The widget must keep the SAME glyph in both
      // locales — hand-picking `arrow_forward` here mirrored it twice.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });
  });

  group('ChatMessageBubble — D3 incoming timestamp (REVERSED)', () {
    testWidgets('BOTH bubbles show a time; only the sender carries a status',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_body(
        Column(
          children: [
            ChatMessageBubble(message: _text('them', ChatAuthor.them)),
            ChatMessageBubble(message: _text('me', ChatAuthor.me)),
          ],
        ),
      ));
      await tester.pump();

      // D3 IS REVERSED, on the design's authority: redesign-2026-08 screen 21
      // draws `9:24` on the incoming bubble (`21-order-chat.html`, tpl 1252).
      // The rule that survives is the narrower one — a timestamp is a fact
      // about any message, a DELIVERY STATUS is only ever a fact about your
      // own.
      expect(find.text('09:41'), findsNWidgets(2));
      expect(
        find.bySemanticsIdentifier('chat_detail_message_read'),
        findsOneWidget,
        reason: 'the read state belongs to the sender bubble alone',
      );
      handle.dispose();
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
        isSemantics(
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
