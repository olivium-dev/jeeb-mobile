// Render tests for the ClientLocationOptionCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. The shared suite below asserts each preview
// renders ITS OWN state; the specifics group pins the three layout facts the
// previews were written to expose — the card never grows past one line, the row
// mirrors in Arabic, and the selected/unselected pair really do differ.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/client_location_option_card.dart';
import 'package:jeeb_mobile/features/request_type/presentation/selectable_radio_glyph.dart';

import '../preview_test_harness.dart';

const String _longLabel =
    'Sassine Square, Ashrafieh — Building 12, 3rd floor, blue door';
const String _unbreakableLabel =
    'W2CH+8XBeirutGovernorateLebanonPlusCodeIdentifier';
const String _rtlLabel = 'ساسين، الأشرفية (مبنى 12)';

/// Pumps a preview at the phone width the previews are sized for (390pt), so
/// the label has the same 350pt card to fit into that the canvas gives it.
/// At the 800pt default test surface nothing truncates and the layout facts
/// below would all pass vacuously.
Future<void> _pumpAtPhoneWidth(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await pumpPreview(tester, preview, locale: locale);
}

Finder _labelParagraphs() => find.descendant(
      of: find.byType(ClientLocationOptionCard),
      matching: find.byType(RichText),
    );

bool _labelTruncated(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(_labelParagraphs().first)
        .didExceedMaxLines;

Color? _cardFill(WidgetTester tester, {int index = 0}) => tester
    .widgetList<Material>(
      find.descendant(
        of: find.byType(ClientLocationOptionCard),
        matching: find.byType(Material),
      ),
    )
    .elementAt(index)
    .color;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ClientLocationOptionCard',
    const <String, Widget Function()>{
      'Unselected': clientLocationOptionCardUnselected,
      'Selected': clientLocationOptionCardSelected,
      'Long label truncates': clientLocationOptionCardLongLabel,
      'Unbreakable label': clientLocationOptionCardUnbreakableLabel,
      'RTL label under EN locale': clientLocationOptionCardRtlLabel,
      'Pair in one group': clientLocationOptionCardPair,
    },
    expectedText: const <String, String>{
      'Unselected': 'New Location',
      'Selected': 'Current Location',
      'Long label truncates': _longLabel,
      'Unbreakable label': _unbreakableLabel,
      'RTL label under EN locale': _rtlLabel,
      'Pair in one group': 'Office',
    },
  );

  group('ClientLocationOptionCard preview specifics', () {
    testWidgets('the option labels come from the ARB, not from the preview', (
      WidgetTester tester,
    ) async {
      // Both production states read their label through AppLocalizations, so a
      // preview that stopped localizing (or an ARB key that lost its Arabic)
      // shows up here rather than in the canvas.
      await pumpPreview(
        tester,
        clientLocationOptionCardSelected,
        locale: const Locale('ar'),
      );

      expect(find.text('Current Location'), findsNothing);
      expect(find.text('الموقع الحالي'), findsOneWidget);
    });

    testWidgets('selected and unselected are different cards, not one', (
      WidgetTester tester,
    ) async {
      final ColorScheme scheme = AppTheme.light().colorScheme;

      await _pumpAtPhoneWidth(tester, clientLocationOptionCardSelected);
      expect(_cardFill(tester), scheme.primary);

      await _pumpAtPhoneWidth(tester, clientLocationOptionCardUnselected);
      expect(_cardFill(tester), scheme.surface);
    });

    testWidgets('a label that does not fit is truncated, never wrapped', (
      WidgetTester tester,
    ) async {
      // `_Label` sets `overflow: ellipsis` with no `maxLines`, and the card has
      // no height constraint of its own — so the only reason a long label does
      // not push the card taller is that the ellipsis clamps it to one line.
      // Both long previews exist to make that visible; this pins it.
      await _pumpAtPhoneWidth(tester, clientLocationOptionCardSelected);
      final double baseline =
          tester.getSize(find.byType(ClientLocationOptionCard)).height;
      expect(_labelTruncated(tester), isFalse);

      for (final Widget Function() preview in <Widget Function()>[
        clientLocationOptionCardLongLabel,
        clientLocationOptionCardUnbreakableLabel,
      ]) {
        await _pumpAtPhoneWidth(tester, preview);
        expect(_labelTruncated(tester), isTrue);
        expect(
          tester.getSize(find.byType(ClientLocationOptionCard)).height,
          baseline,
        );
      }
    });

    testWidgets('the row mirrors in Arabic — radio leads, label follows', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, clientLocationOptionCardSelected);
      final double enLabel = tester.getRect(_labelParagraphs().first).left;
      final double enRadio =
          tester.getRect(find.byType(SelectableRadioGlyph)).left;
      expect(enRadio, greaterThan(enLabel));

      await _pumpAtPhoneWidth(
        tester,
        clientLocationOptionCardSelected,
        locale: const Locale('ar'),
      );
      final double arLabel = tester.getRect(_labelParagraphs().first).left;
      final double arRadio =
          tester.getRect(find.byType(SelectableRadioGlyph)).left;
      expect(arRadio, lessThan(arLabel));
    });

    testWidgets('the group preview shows two cards in one exclusive group', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpAtPhoneWidth(tester, clientLocationOptionCardPair);

      expect(find.byType(ClientLocationOptionCard), findsNWidgets(2));
      expect(_cardFill(tester), AppTheme.light().colorScheme.primary);
      expect(_cardFill(tester, index: 1), AppTheme.light().colorScheme.surface);

      // The reuse hazard this preview exposes: the semantics identifier is
      // hardcoded inside the widget, so BOTH cards publish
      // `client_location_option_current` — the id
      // test/delivery_create_screens_test.dart asserts `findsOneWidget` on. If
      // this expectation ever fails because only one node carries it, the fix
      // (making the identifier a parameter) has landed; update this to match.
      expect(
        find.bySemanticsIdentifier('client_location_option_current'),
        findsNWidgets(2),
      );
      handle.dispose();
    });
  });
}
