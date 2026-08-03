import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';

import 'jeeb_cta_test_harness.dart';

/// Token sheet §1/§3 — the expected Midnight values, spelled out here rather
/// than read back off the implementation.
const Color _periwinkle = Color(0xFF8A93D8);
const Color _pageNavy = Color(0xFF070C33);
const Color _ink = Color(0xFFEDEFFC);
const Color _orange = Color(0xFFD73B00);
const Color _glassFill = Color(0x12FFFFFF);
const Color _glassBorderStrong = Color(0x29FFFFFF);

JeebSemanticColors _semanticsOf(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>()!;

void main() {
  group('JeebCtaButton.primary', () {
    testWidgets('is a periwinkle h56 pill with navy ink and no lift',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.primary(label: 'Confirm tier', onTap: () {})),
      );

      final BuildContext context = tester.element(find.text('Confirm tier'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));

      expect(decoration.color, scheme.secondary);
      expect(decoration.color, _periwinkle);
      expect(decoration.border, isNull);
      expect(
        decoration.boxShadow,
        isNull,
        reason: 'the Midnight lift belongs to orange fills only',
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(JeebCtaButton.pillRadius),
      );
      expect(
        tester.getSize(find.byType(JeebCtaButton)).height,
        JeebCtaButton.primaryHeight,
      );
      // `expand` defaults to true on pill variants.
      expect(tester.getSize(find.byType(JeebCtaButton)).width, 320);
    });

    testWidgets('labels in jeebText.button (17/w600) on navy ink',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.primary(label: 'Send offer', onTap: () {})),
      );

      final BuildContext context = tester.element(find.text('Send offer'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final Text label = tester.widget<Text>(find.text('Send offer'));

      expect(label.style!.fontSize, 17);
      expect(label.style!.fontSize, context.jeebText.button.fontSize);
      expect(label.style!.fontWeight, FontWeight.w600);
      expect(label.style!.color, scheme.onSecondary);
      expect(label.style!.color, _pageNavy);
    });

    testWidgets('takes the h58 override (10 14 17)', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Broadcast',
            height: JeebCtaButton.primaryHeightTall,
            onTap: () {},
          ),
        ),
      );

      expect(tester.getSize(find.byType(JeebCtaButton)).height, 58);
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.primary(label: 'Go', onTap: () => taps++)),
      );

      await tester.tap(find.byType(JeebCtaButton));
      expect(taps, 1);
    });
  });

  group('JeebCtaButton.outline', () {
    testWidgets('is a glass h50 pill: glassFill + 1px glassBorderStrong',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.outline(label: 'Open dispute', onTap: () {})),
      );

      final BuildContext context = tester.element(find.text('Open dispute'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final JeebSemanticColors semantics = _semanticsOf(context);
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));

      expect(decoration.color, semantics.glassFill);
      expect(decoration.color, _glassFill);
      expect(decoration.boxShadow, isNull, reason: 'glass never lifts');
      expect(
        (decoration.border! as Border).top.color,
        semantics.glassBorderStrong,
      );
      expect((decoration.border! as Border).top.color, _glassBorderStrong);
      expect((decoration.border! as Border).top.width, 1);
      expect(
        tester.getSize(find.byType(JeebCtaButton)).height,
        JeebCtaButton.outlineHeight,
      );
      expect(
        tester.widget<Text>(find.text('Open dispute')).style!.color,
        scheme.onSurface,
      );
      expect(tester.widget<Text>(find.text('Open dispute')).style!.color, _ink);
    });

    testWidgets('h54 override keeps the border (14)', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.outline(
            label: "Not yet — something's wrong",
            height: JeebCtaButton.outlineHeightTall,
            onTap: () {},
          ),
        ),
      );

      expect(tester.getSize(find.byType(JeebCtaButton)).height, 54);
      expect(
        ctaDecorationOf(tester, find.byType(JeebCtaButton)).border,
        isNotNull,
      );
    });
  });

  group('JeebCtaButton.text / .accentText', () {
    testWidgets('text carries no pill and onSurfaceVariant ink',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          Row(
            children: <Widget>[
              JeebCtaButton.text(label: 'Skip', onTap: () {}),
            ],
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Skip'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));

      expect(decoration.color, isNull);
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNull);
      expect(
        tester.widget<Text>(find.text('Skip')).style!.color,
        scheme.onSurfaceVariant,
      );
      expect(tester.widget<Text>(find.text('Skip')).style!.color, _periwinkle);
      // `expand` defaults to false, so it survives an unbounded Row slot.
      expect(tester.getSize(find.byType(JeebCtaButton)).width, lessThan(320));
    });

    testWidgets('accentText inks with jeebRoles.accent', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.accentText(
            label: 'How fees work — the 10%, explained',
            onTap: () {},
          ),
        ),
      );

      final Finder label = find.text('How fees work — the 10%, explained');
      final BuildContext context = tester.element(label);
      expect(
        tester.widget<Text>(label).style!.color,
        context.jeebRoles.accent,
      );
      expect(tester.widget<Text>(label).style!.color, _orange);
    });

    testWidgets('reads jeebRoles safely under a bare ThemeData.light()',
        (tester) async {
      // `wrapForTest` themes with ThemeData.light(); the extension must fall
      // back rather than crash (the pattern the card lane established).
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: JeebCtaButton.accentText(label: 'Link', onTap: () {}),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Link'), findsOneWidget);
    });
  });

  group('JeebCtaButton disabled', () {
    testWidgets('isEnabled: false dims the fill and drops the tap',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Confirm tier',
            isEnabled: false,
            onTap: () => taps++,
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Confirm tier'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));

      expect(
        decoration.color,
        scheme.secondary.withValues(alpha: JeebCtaButton.disabledFillOpacity),
      );
      // Height and pill are unchanged — only the ink moves.
      expect(
        tester.getSize(find.byType(JeebCtaButton)).height,
        JeebCtaButton.primaryHeight,
      );

      await tester.tap(find.byType(JeebCtaButton));
      expect(taps, 0);
    });

    testWidgets('a disabled glass pill dims multiplicatively, never opaquer',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.outline(
            label: 'Open dispute',
            isEnabled: false,
            onTap: () {},
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Open dispute'));
      final JeebSemanticColors semantics = _semanticsOf(context);
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));

      expect(
        decoration.color!.a,
        closeTo(semantics.glassFill.a * JeebCtaButton.disabledFillOpacity, 1e-6),
      );
      expect(decoration.color!.a, lessThan(semantics.glassFill.a));
    });

    testWidgets('a null onTap is disabled too', (tester) async {
      await tester.pumpWidget(
        wrapCta(const JeebCtaButton.primary(label: 'Confirm tier')),
      );

      final JeebCtaButton button =
          tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
      expect(button.isEnabled, isTrue);
      expect(button.isInteractive, isFalse);
    });

    testWidgets('exposes isEnabled for the 07/08 screen tests', (tester) async {
      const Key key = Key('request-type-continue');
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            key: key,
            label: 'Continue',
            isEnabled: false,
            onTap: () {},
          ),
        ),
      );

      expect(tester.widget<JeebCtaButton>(find.byKey(key)).isEnabled, isFalse);
    });
  });

  group('JeebCtaButton loading', () {
    testWidgets('swaps the content for a spinner and ignores taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Send offer',
            leadingIcon: Icons.check,
            isLoading: true,
            onTap: () => taps++,
          ),
        ),
      );
      // Never pumpAndSettle: the spinner animation does not settle.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Send offer'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
      // The pill itself is untouched — the height survives (14 §7).
      expect(
        tester.getSize(find.byType(JeebCtaButton)).height,
        JeebCtaButton.primaryHeight,
      );
      final BuildContext context = tester.element(find.byType(JeebCtaButton));
      expect(
        ctaDecorationOf(tester, find.byType(JeebCtaButton)).color,
        Theme.of(context)
            .colorScheme
            .secondary
            .withValues(alpha: JeebCtaButton.disabledFillOpacity),
        reason: 'loading is a disabled state, so the fill dims with it',
      );

      await tester.tap(find.byType(JeebCtaButton), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('JeebCtaButton glyphs', () {
    testWidgets('renders leading and trailing icons around the label',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Next',
            leadingIcon: Icons.add,
            trailingIcon: Icons.arrow_forward,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(Icons.add)).dx,
        lessThan(tester.getCenter(find.text('Next')).dx),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.arrow_forward)).dx,
        greaterThan(tester.getCenter(find.text('Next')).dx),
      );
    });

    testWidgets('glyph inherits the variant ink and the given size',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Top up wallet',
            leadingIcon: Icons.add,
            iconSize: 19,
            onTap: () {},
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Top up wallet'));
      final Icon glyph = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(glyph.size, 19);
      expect(glyph.color, Theme.of(context).colorScheme.onSecondary);
    });
  });

  group('JeebCtaButton semantics', () {
    testWidgets('surfaces the identifier when it owns one', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Send',
            identifier: 'offer_composer_send_cta',
            onTap: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('offer_composer_send_cta'),
        findsOneWidget,
      );
    });

    testWidgets('emits no identifier when the consumer owns it',
        (tester) async {
      // 14 wraps this widget in Semantics(id) + ExcludeSemantics; a kit-emitted
      // id inside that would duplicate or be swallowed.
      await tester.pumpWidget(
        wrapCta(
          Semantics(
            identifier: 'receipt_confirm_cta',
            button: true,
            child: ExcludeSemantics(
              child: JeebCtaButton.primary(label: 'Confirm', onTap: () {}),
            ),
          ),
        ),
      );

      final Iterable<Semantics> inner = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(JeebCtaButton),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        inner.every((Semantics s) => s.properties.identifier == null),
        isTrue,
      );
      expect(find.bySemanticsIdentifier('receipt_confirm_cta'), findsOneWidget);
    });

    testWidgets('reports the disabled state on its own node', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          const JeebCtaButton.primary(
            label: 'Confirm',
            identifier: 'tier_selection_confirm_cta',
            isEnabled: false,
          ),
        ),
      );

      final Semantics node = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(JeebCtaButton),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.properties.enabled, isFalse);
      expect(node.properties.button, isTrue);
    });
  });

  group('JeebCtaButton Midnight metrics', () {
    test('geometry consts are the ratified ladder values', () {
      expect(JeebCtaButton.pillRadius, JeebRadii.pill);
      expect(JeebCtaButton.pillRadius, 999);
      expect(JeebCtaButton.outlineBorderWidth, 1);
      expect(JeebCtaButton.primaryHeight, 56);
      expect(JeebCtaButton.primaryHeightTall, 58);
      expect(JeebCtaButton.outlineHeight, 50);
      expect(JeebCtaButton.textHeight, 48);
    });
  });

  group('JeebCtaButton RTL smoke', () {
    testWidgets('leading glyph sits at the start edge in both directions',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Next',
            leadingIcon: Icons.add,
            onTap: () {},
            expand: false,
          ),
        ),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.add)).dx,
        lessThan(tester.getCenter(find.text('Next')).dx),
      );

      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Next',
            leadingIcon: Icons.add,
            onTap: () {},
            expand: false,
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.add)).dx,
        greaterThan(tester.getCenter(find.text('Next')).dx),
        reason: 'the row is directional, so "leading" means start',
      );
    });

    testWidgets('mirrorIcons flips a directional glyph under RTL only',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Next',
            trailingIcon: Icons.arrow_forward,
            mirrorIcons: true,
            onTap: () {},
          ),
        ),
      );
      expect(_flipsHorizontally(tester), isFalse);

      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.primary(
            label: 'Next',
            trailingIcon: Icons.arrow_forward,
            mirrorIcons: true,
            onTap: () {},
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(_flipsHorizontally(tester), isTrue);
    });

    testWidgets('renders and stays tappable in RTL', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.outline(label: 'افتح نزاعًا', onTap: () => taps++),
          direction: TextDirection.rtl,
        ),
      );

      expect(find.text('افتح نزاعًا'), findsOneWidget);
      await tester.tap(find.byType(JeebCtaButton));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  });
}

/// True when the glyph is drawn through a horizontal flip.
bool _flipsHorizontally(WidgetTester tester) {
  final Iterable<Transform> transforms = tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(JeebCtaButton),
      matching: find.byType(Transform),
    ),
  );
  return transforms.any((Transform t) => t.transform.storage[0] == -1.0);
}
