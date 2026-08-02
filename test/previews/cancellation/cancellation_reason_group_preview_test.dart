// Render tests for the CancellationReasonGroup previews.

// `Tristate`/`CheckedState` are the types `SemanticsFlags` now uses and are not
import 'dart:ui' as ui show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/cancellation/presentation/widgets/cancellation_reason_group.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded reason breaks the test instead of silently
/// unpinning the preview.
const String _changedMind = 'Changed my mind';
const String _waitTooLong = 'Taking too long';
const String _wrongAddress = 'Wrong address';
const String _other = 'Other';
const String _cantComplete = 'Cannot complete delivery';
const String _prohibited = 'Prohibited item detected';
const String _wrongAddressAr = 'عنوان خاطئ';

/// Fixture copy from the long-label preview, character for character — this is
/// the string that state exists to lay out.
const String _longLabel =
    'The package contains items I am not allowed to carry, such as '
    'flammable liquids, medication or anything the courier terms '
    'list as prohibited';
const String _longLabelSibling = 'Something else, described below';

/// Pumps a preview into a phone-WIDTH box, the way the canvas renders it.
/// The width is load-bearing for every measurement below: at the 800 dp default
Future<void> _pumpAtPhoneWidth(
  WidgetTester tester,
  Widget Function() preview, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// The `ListTile` that carries [label] — i.e. one whole row of the group.
Finder _rowOf(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(ListTile),
    );

/// Labels of every semantics node BELOW [node], flattened.
List<String> _descendantLabels(SemanticsNode node) {
  final List<String> labels = <String>[];
  node.visitChildren((SemanticsNode child) {
    labels.add(child.label);
    labels.addAll(_descendantLabels(child));
    return true;
  });
  return labels;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CancellationReasonGroup',
    const <String, Widget Function()>{
      'Client · nothing selected': cancellationReasonGroupClientUnselected,
      'Client · "Other" selected': cancellationReasonGroupOtherSelected,
      'Jeeber · prohibited item selected': cancellationReasonGroupJeeber,
      'Long label · wraps to several lines': cancellationReasonGroupLongLabel,
      'No reasons · renders nothing': cancellationReasonGroupEmpty,
    },
    expectedText: const <String, String>{
      // Client-only copy; the Jeeber and long-label states render neither.
      'Client · nothing selected': _waitTooLong,
      'Client · "Other" selected': _wrongAddress,
      // Jeeber-only copy.
      'Jeeber · prohibited item selected': _cantComplete,
      // Fixture copy that exists in no ARB.
      'Long label · wraps to several lines': _longLabel,
      // 'No reasons · renders nothing' renders no text by design — it is pinned
    },
  );

  group('CancellationReasonGroup preview specifics', () {
    testWidgets('the default client state has FOUR rows and NOTHING selected', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupClientUnselected);

      for (final String label in const <String>[
        _changedMind,
        _waitTooLong,
        _wrongAddress,
        _other,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // The submit button on the screen stays disabled until one of these is
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
    });

    testWidgets('"Other" selected checks exactly one row — the last one', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupOtherSelected);

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
      // The checked glyph must sit inside the "Other" row, not merely exist.
      expect(
        tester.getRect(_rowOf(_other)).contains(
              tester.getCenter(find.byIcon(Icons.radio_button_checked)),
            ),
        isTrue,
      );
      // It is the LAST row, which is what puts the free-text field it reveals
      expect(
        tester.getRect(_rowOf(_other)).top,
        greaterThan(tester.getRect(_rowOf(_changedMind)).top),
      );
    });

    testWidgets('the canvas host is live: tapping a row moves the radio', (
      WidgetTester tester,
    ) async {
      // The previews seed a selection and then own it, so a reviewer can click
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupClientUnselected);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);

      await tester.tap(find.text(_wrongAddress));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        tester.getRect(_rowOf(_wrongAddress)).contains(
              tester.getCenter(find.byIcon(Icons.radio_button_checked)),
            ),
        isTrue,
      );
    });

    testWidgets('the Jeeber list is a different list, not a relabelled one', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupJeeber);

      expect(find.byType(ListTile), findsNWidgets(5));
      expect(find.text(_cantComplete), findsOneWidget);
      expect(find.text(_prohibited), findsOneWidget);
      // `other` is the only code the two roles share.
      expect(find.text(_other), findsOneWidget);
      expect(find.text(_changedMind), findsNothing);
      expect(find.text(_wrongAddress), findsNothing);
      expect(
        tester.getRect(_rowOf(_prohibited)).contains(
              tester.getCenter(find.byIcon(Icons.radio_button_checked)),
            ),
        isTrue,
      );
    });

    testWidgets('a long label WRAPS instead of truncating, and grows the row', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupLongLabel);

      // No `maxLines` and no `overflow` on the tile's title, so the whole
      final Text title = tester.widget<Text>(find.text(_longLabel));
      expect(title.maxLines, isNull);
      expect(title.overflow, isNull);

      // It wraps to at least three lines, and the row grows to hold them.
      final double longText = tester.getRect(find.text(_longLabel)).height;
      final double shortText =
          tester.getRect(find.text(_longLabelSibling)).height;
      expect(longText, greaterThan(shortText * 2.5));
      expect(
        tester.getRect(_rowOf(_longLabel)).height,
        greaterThan(tester.getRect(_rowOf(_longLabelSibling)).height),
      );
      // The short row still clears the 48 dp minimum tap target.
      expect(
        tester.getRect(_rowOf(_longLabelSibling)).height,
        greaterThanOrEqualTo(48.0),
      );

      // `ListTile` centres its leading slot unless `isThreeLine` is set, and
      final Rect glyph =
          tester.getRect(find.byIcon(Icons.radio_button_checked));
      final Rect label = tester.getRect(find.text(_longLabel));
      expect((glyph.center.dy - label.center.dy).abs(), lessThan(2.0));
      expect(glyph.center.dy, greaterThan(label.top + glyph.height));
    });

    testWidgets('an empty reason list renders NOTHING — no rows, no glyphs', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupEmpty);

      expect(find.byType(CancellationReasonGroup), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
      // A zero-height Column: the screen degrades to its prompt above a blank
      expect(
        tester.getSize(find.byType(CancellationReasonGroup)).height,
        0.0,
      );
    });

    testWidgets('AR mirrors the row and renders the shipping Arabic', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(
        tester,
        cancellationReasonGroupOtherSelected,
        locale: const Locale('ar'),
      );

      expect(find.text(_wrongAddressAr), findsOneWidget);
      expect(find.text(_wrongAddress), findsNothing);
      final Element group = tester.element(
        find.byType(CancellationReasonGroup),
      );
      expect(Directionality.of(group), TextDirection.rtl);
      // `ListTile` mirrors its own leading slot, so the radio must land to the
      expect(
        tester.getRect(find.byIcon(Icons.radio_button_checked)).left,
        greaterThan(tester.getRect(find.text('أخرى')).right),
      );
    });

    testWidgets('every row carries its backend reason code as its identifier', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupOtherSelected);

      // The id is built from the CODE, not the label, so it survives i18n and
      for (final String code in const <String>[
        'changed_mind',
        'wait_too_long',
        'wrong_address',
        'other',
      ]) {
        expect(
          find.bySemanticsIdentifier('cancellation_reason_$code'),
          findsOneWidget,
          reason: code,
        );
      }

      final SemanticsFlags selected = tester
          .getSemantics(find.bySemanticsIdentifier('cancellation_reason_other'))
          .getSemanticsData()
          .flagsCollection;
      expect(selected.isSelected, ui.Tristate.isTrue);

      final SemanticsFlags unselected = tester
          .getSemantics(
            find.bySemanticsIdentifier('cancellation_reason_changed_mind'),
          )
          .getSemanticsData()
          .flagsCollection;
      expect(unselected.isSelected, ui.Tristate.isFalse);

      handle.dispose();
    });
  });

  // The defects the previews exposed, held as assertions so they cannot regress
  group('CancellationReasonGroup defects', () {
    testWidgets('the radio glyph never grows with the label it marks', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupOtherSelected);
      final Size glyphAt100 =
          tester.getSize(find.byIcon(Icons.radio_button_checked));
      final double labelAt100 = tester.getRect(find.text(_other)).height;

      await _pumpAtPhoneWidth(
        tester,
        cancellationReasonGroupOtherSelected,
        textScale: 2.0,
      );
      final Size glyphAt200 =
          tester.getSize(find.byIcon(Icons.radio_button_checked));
      final double labelAt200 = tester.getRect(find.text(_other)).height;

      expect(glyphAt100, const Size(24.0, 24.0));
      expect(labelAt200, greaterThan(labelAt100 * 1.9));
      expect(
        glyphAt200,
        glyphAt100,
        reason: 'the ONLY visual difference between a chosen and an unchosen '
            'reason is this 24 dp glyph, and `Icon` does not apply text '
            'scaling by default — so at the 200% accessibility ceiling the '
            'selection indicator stays 24 dp while its label doubles',
      );
    });

    testWidgets('each row is announced TWICE — container label over tile label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupOtherSelected);

      final SemanticsNode row = tester.getSemantics(
        find.bySemanticsIdentifier('cancellation_reason_other'),
      );
      // `_ReasonTile` wraps `OmdsSettingsRow` in `Semantics(container: true,
      expect(row.label, _other);
      expect(_descendantLabels(row), contains(_other));

      // The outer node claims a button role it cannot service: `onTap` was
      final SemanticsData data = row.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(
        data.hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'the identified, button-flagged node is not the tappable one',
      );

      handle.dispose();
    });

    testWidgets('a radio group announces as four unrelated BUTTONS', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpAtPhoneWidth(tester, cancellationReasonGroupOtherSelected);

      final SemanticsFlags flags = tester
          .getSemantics(find.bySemanticsIdentifier('cancellation_reason_other'))
          .getSemanticsData()
          .flagsCollection;
      // The widget's own doc promises the selected reason is announced, and
      expect(flags.isSelected, ui.Tristate.isTrue);
      // But nothing marks these four rows as ONE mutually exclusive choice, and
      expect(
        flags.isInMutuallyExclusiveGroup,
        isFalse,
        reason: 'AC4 calls this a reason GROUP; the semantics say four buttons',
      );
      expect(flags.isChecked, ui.CheckedState.none);

      handle.dispose();
    });
  });
}
