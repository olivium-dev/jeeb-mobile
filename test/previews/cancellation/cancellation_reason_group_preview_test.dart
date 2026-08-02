// Render tests for the CancellationReasonGroup previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
//
// Four of the five previews are the SAME widget told apart only by their reason
// list and which row is selected, and two of them render the identical four
// client labels. So `expectedText` pins a string that appears in NO other state
// where one exists, and the selection — the thing text cannot express — is
// pinned separately below by counting checked/unchecked glyphs. The empty
// preview renders no text at all; it is pinned by absence, which is the only
// assertion a zero-height Column can carry.
//
// The last group is not preview hygiene. It is what these previews exposed: a
// 24 dp selection indicator that does not grow at the 200% accessibility
// ceiling, and a per-row Semantics container that duplicates the label of the
// ListTile underneath it while advertising a button role it has no tap action
// for.

// `Tristate`/`CheckedState` are the types `SemanticsFlags` now uses and are not
// re-exported by `package:flutter/semantics.dart`.
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
///
/// The width is load-bearing for every measurement below: at the 800 dp default
/// test surface no label wraps, so the state whose whole point is wrapping would
/// be reviewed at a width the app never uses. The height is generous because the
/// group grows rather than overflowing (production scrolls it), so a short box
/// would only produce a render-overflow exception that says nothing about the
/// widget.
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
      // by absence in `preview specifics` instead. A string here would be a lie.
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
      // tapped, so a checked ring here would be a one-tap cancellation of a
      // delivery the user never picked a reason for.
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
      // below the fold on a short phone.
      expect(
        tester.getRect(_rowOf(_other)).top,
        greaterThan(tester.getRect(_rowOf(_changedMind)).top),
      );
    });

    testWidgets('the canvas host is live: tapping a row moves the radio', (
      WidgetTester tester,
    ) async {
      // The previews seed a selection and then own it, so a reviewer can click
      // in the canvas instead of reading a frozen picture. If this breaks, the
      // canvas silently becomes a set of dead images.
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
      // string is laid out rather than clipped with an ellipsis.
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
      // `OmdsSettingsRow` never sets it — so the radio floats at the MIDDLE of
      // a multi-line label rather than beside the first line the reader starts
      // on. Worth knowing before a longer reason ships.
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
      // gap and a submit button that can never enable.
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
      // RIGHT of the label it marks.
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
      // reordering — that is what the Maestro suite addresses rows by.
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
  // unnoticed — and so that FIXING them fails this file loudly rather than
  // leaving a stale claim behind.
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
      // label: label, button: true)`, and the `ListTile` underneath publishes
      // its own labelled, tappable node. Both are focusable, so swiping through
      // four reasons costs eight stops and says "Other" twice.
      expect(row.label, _other);
      expect(_descendantLabels(row), contains(_other));

      // The outer node claims a button role it cannot service: `onTap` was
      // passed to the row, not to the Semantics wrapper, so the node that owns
      // the identifier has no tap action of its own.
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
      // `selected:` does deliver that much.
      expect(flags.isSelected, ui.Tristate.isTrue);
      // But nothing marks these four rows as ONE mutually exclusive choice, and
      // nothing gives them a checked state, so a screen-reader user hears
      // "Other, selected, button" with no signal that picking it unpicked
      // another row — the flags `Radio` sets for exactly this shape.
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
