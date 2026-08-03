// P4 + P5 (b01-20260725) — image/photo bubble RENDER-SOURCE precedence.
//
// TC-C14 / TC-C15 in docs/batches/b01-20260725/testcases/P45.md §C.
//
// Two independent defects lived here:
//
//   1. `_ImageBubble` handed `message.imageUrl` straight to `OmdsCachedImage`
//      whenever it was non-empty. But a chat attachment's `imageUrl` is a CDN
//      **object_ref** (`chat_attachment/<guid>.jpg`), NOT a fetchable URL — the
//      cached-image widget would issue a doomed, unauthenticated GET against a
//      relative path. Local bytes must win, and a bare ref must degrade to the
//      placeholder rather than to a network attempt.
//
//   2. `_PhotoBubble` dereferenced `message.photoBytes!`. A `photo` row with no
//      bytes — exactly what the pre-fix build persisted on the wire — threw. And
//      neither bubble passed `errorBuilder`, so undecodable bytes surfaced a red
//      `ErrorWidget` inside the thread.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arb);

  final Map<String, String> _arb;

  @override
  bool isSupported(Locale locale) => _arb.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arb[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _delegate;

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

/// A minimal, genuinely decodable 1×1 PNG so `Image.memory` succeeds.
final Uint8List _realPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Not an image in any format — exercises the `errorBuilder` path.
final Uint8List _garbage = Uint8List.fromList(List<int>.filled(64, 0x7F));

DeliveryChatMessage _image({
  required String url,
  Uint8List? bytes,
}) => DeliveryChatMessage.image(
      id: 'img-1',
      author: ChatAuthor.me,
      sentAt: DateTime(2026, 5, 17, 10, 30),
      status: MessageStatus.sent,
      url: url,
      bytes: bytes,
    );

DeliveryChatMessage _photo({Uint8List? bytes}) => DeliveryChatMessage.photo(
      id: 'ph-1',
      author: ChatAuthor.me,
      sentAt: DateTime(2026, 5, 17, 10, 30),
      status: MessageStatus.sent,
      // The pre-fix wire shape: a `photo` row with NO usable bytes.
      bytes: bytes ?? Uint8List(0),
      source: PhotoSource.camera,
    );

/// The bubble's "unavailable" fallback is the only `Icons.image_outlined` in
/// the subtree, so finding it is an unambiguous placeholder assertion.
final Finder _placeholder = find.byIcon(Icons.image_outlined);

void main() {
  setUpAll(() {
    _delegate = _SyncDelegate(<String, String>{
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    });
  });

  group('TC-C14 — _ImageBubble render-source precedence', () {
    testWidgets('local bytes win: Image.memory renders, no network widget',
        (tester) async {
      await tester.pumpWidget(_host(ChatMessageBubble(
        message: _image(url: 'chat_attachment/x.jpg', bytes: _realPng),
      )));
      await tester.pump();

      expect(find.byType(Image), findsWidgets);
      expect(
        find.byType(OmdsCachedImage),
        findsNothing,
        reason: 'held bytes must never trigger a round trip',
      );
      expect(_placeholder, findsNothing);
    });

    testWidgets('a bare CDN object_ref degrades to the placeholder — '
        'OmdsCachedImage is NOT constructed', (tester) async {
      await tester.pumpWidget(_host(ChatMessageBubble(
        message: _image(url: 'chat_attachment/x.jpg'),
      )));
      await tester.pump();

      expect(
        find.byType(OmdsCachedImage),
        findsNothing,
        reason: 'a cdn object_ref is not a fetchable URL — handing it to the '
            'cached-image widget issues a doomed unauthenticated GET',
      );
      expect(_placeholder, findsOneWidget);
    });

    testWidgets('an absolute https URL still routes to OmdsCachedImage',
        (tester) async {
      await tester.pumpWidget(_host(ChatMessageBubble(
        message: _image(url: 'https://cdn.example.test/a.jpg'),
      )));
      await tester.pump();

      expect(find.byType(OmdsCachedImage), findsOneWidget);
      // WAS a documented pre-existing defect, now FIXED by the redesign-2026-08
      // bubble: the old bubble handed OmdsCachedImage no width/height, and its
      // loading shimmer is an unconstrained Container, so under the bubble's
      // `mainAxisSize: min` Column it asserted "BoxConstraints forces an
      // infinite height" while the network image was still pending. The kit's
      // media slot draws a MEASURED 120×74 tile, so the shimmer is bounded and
      // the pending frame no longer throws. Asserted (not merely dropped) so a
      // regression to an unbounded tile reds this test.
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty url is the placeholder (the legacy `photo` decode)',
        (tester) async {
      await tester.pumpWidget(_host(ChatMessageBubble(message: _image(url: ''))));
      await tester.pump();

      expect(_placeholder, findsOneWidget);
      expect(find.byType(OmdsCachedImage), findsNothing);
    });
  });

  group('TC-C15 — undecodable / absent bytes never surface an ErrorWidget', () {
    testWidgets('_ImageBubble with garbage bytes falls back to the placeholder',
        (tester) async {
      await tester.pumpWidget(_host(ChatMessageBubble(
        message: _image(url: 'chat_attachment/x.jpg', bytes: _garbage),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorWidget), findsNothing);
      expect(_placeholder, findsOneWidget);
    });

    testWidgets('_PhotoBubble with garbage bytes falls back to the placeholder',
        (tester) async {
      await tester.pumpWidget(_host(ChatMessageBubble(
        message: _photo(bytes: _garbage),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorWidget), findsNothing);
      expect(_placeholder, findsOneWidget);
    });

    testWidgets('_PhotoBubble with NO bytes renders the placeholder, no crash',
        (tester) async {
      // Pre-fix this threw on `message.photoBytes!`.
      await tester.pumpWidget(_host(ChatMessageBubble(message: _photo())));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(_placeholder, findsOneWidget);
    });
  });
}
