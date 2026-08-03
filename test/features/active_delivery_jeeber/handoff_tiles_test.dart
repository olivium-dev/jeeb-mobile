// redesign-2026-08 screen 18: the two h86 evidence tiles inside the handoff
// card. The 180px photo placeholder and the always-open note field are gone; a
// jeeber at a door now sees two compact tiles and opts in to the editor.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_l10n.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/widgets/handoff_tiles.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../../support/sync_app_localizations.dart';

/// A 1×1 transparent PNG — enough for `Image.memory` to decode.
final _pngBytes = Uint8List.fromList(<int>[
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

JeeberDelivery _delivery({String? proofPhotoUrl}) => JeeberDelivery(
  id: 'd1',
  status: JeeberDeliveryStatus.atDoor,
  dropOff: const DropOffAddress(label: 'Rue Monot 42', lat: 33.9, lng: 35.5),
  proofPhotoUrl: proofPhotoUrl,
);

Future<void> _pump(
  WidgetTester tester, {
  required ProofPhotoStatus status,
  JeeberDelivery? delivery,
  Uint8List? bytes,
  VoidCallback? onCapture,
  ValueChanged<String>? onNoteChanged,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => SizedBox(
            width: 342,
            child: HandoffTiles(
              delivery: delivery ?? _delivery(),
              proofPhotoStatus: status,
              proofPhotoBytes: bytes,
              onCaptureProof: onCapture ?? () {},
              onNoteChanged: onNoteChanged ?? (_) {},
              l10n: AppLocalizations.of(context),
              copy: ActiveDeliveryJeeberL10n.of(context),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('proof-photo tile', () {
    testWidgets('none: camera glyph + label, tappable', (tester) async {
      var captures = 0;
      await _pump(
        tester,
        status: ProofPhotoStatus.none,
        onCapture: () => captures += 1,
      );

      expect(
        find.bySemanticsIdentifier('mark_delivered_proof_photo'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.photo_camera), findsOneWidget);
      expect(find.text('Proof photo'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await tester.tap(find.byIcon(Icons.photo_camera));
      expect(captures, 1);
    });

    testWidgets('uploading: spinner replaces the glyph, tap is inert', (
      tester,
    ) async {
      var captures = 0;
      await _pump(
        tester,
        status: ProofPhotoStatus.uploading,
        onCapture: () => captures += 1,
      );

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera), findsNothing);

      await tester.tap(
        find.bySemanticsIdentifier('mark_delivered_proof_photo'),
        warnIfMissed: false,
      );
      expect(captures, isZero, reason: 'an upload in flight is not re-tappable');
    });

    testWidgets('captured: the thumbnail survives (JEBV4-200) with a check', (
      tester,
    ) async {
      await _pump(
        tester,
        status: ProofPhotoStatus.captured,
        delivery: _delivery(proofPhotoUrl: 'https://cdn.jeeb.app/p.jpg'),
        bytes: _pngBytes,
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera), findsNothing);
    });
  });

  group('note tile', () {
    testWidgets('mark_delivered_note_field is emitted collapsed AND expanded', (
      tester,
    ) async {
      await _pump(tester, status: ProofPhotoStatus.none);

      expect(
        find.bySemanticsIdentifier('mark_delivered_note_field'),
        findsOneWidget,
      );
      expect(find.byType(OmdsTextField), findsNothing);

      await tester.tap(
        find.bySemanticsIdentifier('mark_delivered_note_tile'),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('mark_delivered_note_field'),
        findsOneWidget,
        reason: 'the id must survive the collapsed → expanded flip',
      );
      expect(find.byType(OmdsTextField), findsOneWidget);
    });

    testWidgets('the editor reports through onNoteChanged and stays open', (
      tester,
    ) async {
      String? note;
      await _pump(
        tester,
        status: ProofPhotoStatus.none,
        onNoteChanged: (v) => note = v,
      );

      await tester.tap(
        find.bySemanticsIdentifier('mark_delivered_note_tile'),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Left with the guard');
      await tester.pump();

      expect(note, 'Left with the guard');
      expect(
        find.byType(OmdsTextField),
        findsOneWidget,
        reason: 'a note the jeeber is typing must never collapse under them',
      );
    });

    testWidgets('collapsed tile is localized (ar)', (tester) async {
      await _pump(
        tester,
        status: ProofPhotoStatus.none,
        locale: const Locale('ar'),
      );

      expect(find.text('ملاحظة (اختياري)'), findsOneWidget);
      expect(find.text('صورة الإثبات'), findsOneWidget);
    });
  });
}
