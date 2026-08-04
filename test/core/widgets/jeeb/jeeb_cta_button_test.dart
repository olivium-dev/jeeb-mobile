import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';

import 'jeeb_cta_test_harness.dart';

/// Token sheet §1/§3 — the expected Midnight values, spelled out here rather
/// than read back off the implementation.
const Color _periwinkle = Color(0xFF8A93D8);
const Color _pageNavy = Color(0xFF070C33);
const Color _ink = Color(0xFFEDEFFC);
const Color _orange = Color(0xFFD73B00);
const Color _orangePressed = Color(0xFFC23300);
const Color _white = Color(0xFFFFFFFF);
const Color _glassFill = Color(0x12FFFFFF);
const Color _glassBorderStrong = Color(0x29FFFFFF);
const Color _dangerSoft = Color(0xFFFF7B7B);
const Color _danger = Color(0xFFFF5252);

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

  group('JeebCtaButton.accent', () {
    testWidgets('is a solid orange h56 pill with white ink and the ctaOrange lift',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.accent(label: 'Continue', onTap: () {})),
      );

      final BuildContext context = tester.element(find.text('Continue'));
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));

      expect(decoration.color, context.jeebRoles.accent);
      expect(decoration.color, _orange);
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, JeebShadows.ctaOrange);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(JeebCtaButton.pillRadius),
      );
      expect(
        tester.getSize(find.byType(JeebCtaButton)).height,
        JeebCtaButton.primaryHeight,
      );
      expect(
        tester.widget<Text>(find.text('Continue')).style!.color,
        context.jeebRoles.onAccent,
      );
      expect(tester.widget<Text>(find.text('Continue')).style!.color, _white);
    });

    testWidgets('holds at orangePressed and never ripples over the fill',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.accent(label: 'Broadcast', onTap: () {})),
      );

      final BuildContext context = tester.element(find.text('Broadcast'));
      final InkWell well = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(JeebCtaButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(well.highlightColor, _semanticsOf(context).orangePressed);
      expect(well.highlightColor, _orangePressed);
      expect(well.splashColor, Colors.transparent);
    });

    testWidgets('disabled dims the fill and DROPS the glow', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.accent(
            label: 'Continue',
            isEnabled: false,
            onTap: () => taps++,
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Continue'));
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));

      expect(
        decoration.color,
        context.jeebRoles.accent
            .withValues(alpha: JeebCtaButton.disabledFillOpacity),
      );
      expect(
        decoration.boxShadow,
        isNull,
        reason: 'a glow under a dimmed pill reads as enabled',
      );

      await tester.tap(find.byType(JeebCtaButton));
      expect(taps, 0);
    });

    testWidgets('reads jeebRoles safely under a bare ThemeData.light()',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: JeebCtaButton.accent(label: 'Continue', onTap: () {}),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Continue'), findsOneWidget);
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

  group('JeebCtaButton.danger', () {
    testWidgets('is outline geometry with danger-SOFT onErrorContainer ink',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.danger(label: 'Cancel request', onTap: () {})),
      );

      final BuildContext context = tester.element(find.text('Cancel request'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final JeebSemanticColors semantics = _semanticsOf(context);
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));
      final Text label = tester.widget<Text>(find.text('Cancel request'));

      // Ink is the whole delta — every other dimension matches `.outline`.
      expect(label.style!.color, scheme.onErrorContainer);
      expect(label.style!.color, _dangerSoft);
      expect(
        label.style!.color,
        isNot(scheme.error),
        reason: 'R22: destructive ink is danger-SOFT, never #FF5252',
      );
      expect(label.style!.color, isNot(_danger));
      expect(
        label.style!.color,
        isNot(scheme.onSurface),
        reason: 'Q-041: a destructive act must not render as a neutral one',
      );

      expect(decoration.color, semantics.glassFill);
      expect(decoration.color, _glassFill);
      expect((decoration.border! as Border).top.color, _glassBorderStrong);
      expect((decoration.border! as Border).top.width, 1);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(JeebCtaButton.pillRadius),
      );
      expect(
        decoration.boxShadow,
        isNull,
        reason: 'glow only where a tile draws it — no tile draws this act',
      );
      expect(
        tester.getSize(find.byType(JeebCtaButton)).height,
        JeebCtaButton.outlineHeight,
      );
      expect(tester.getSize(find.byType(JeebCtaButton)).width, 320);
    });

    testWidgets('never spends orange and never fills with error',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.danger(label: 'Delete account', onTap: () {})),
      );

      final BuildContext context = tester.element(find.text('Delete account'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));
      final InkWell well = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(JeebCtaButton),
          matching: find.byType(InkWell),
        ),
      );

      expect(decoration.color, isNot(scheme.error));
      expect(decoration.color, isNot(scheme.errorContainer));
      expect(decoration.color, isNot(context.jeebRoles.accent));
      expect(
        tester.widget<Text>(find.text('Delete account')).style!.color,
        isNot(context.jeebRoles.accent),
      );
      // The fill-swap press is the accent pill's alone; glass keeps its ripple.
      expect(well.highlightColor, isNot(_orangePressed));
      expect(well.splashColor, isNull);
    });

    testWidgets('matches .outline in every non-ink dimension', (tester) async {
      Future<void> pumpVariant(JeebCtaVariant variant) => tester.pumpWidget(
            wrapCta(
              JeebCtaButton(
                label: 'Stop',
                variant: variant,
                leadingIcon: Icons.close,
                onTap: () {},
              ),
            ),
          );

      await pumpVariant(JeebCtaVariant.outline);
      final Size outlineSize = tester.getSize(find.byType(JeebCtaButton));
      final BoxDecoration outlineBox =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));
      final TextStyle outlineStyle =
          tester.widget<Text>(find.text('Stop')).style!;
      final double outlineGlyph =
          tester.widget<Icon>(find.byIcon(Icons.close)).size!;

      await pumpVariant(JeebCtaVariant.danger);
      final BoxDecoration dangerBox =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));
      final TextStyle dangerStyle =
          tester.widget<Text>(find.text('Stop')).style!;

      expect(tester.getSize(find.byType(JeebCtaButton)), outlineSize);
      expect(dangerBox.color, outlineBox.color);
      expect(dangerBox.border, outlineBox.border);
      expect(dangerBox.borderRadius, outlineBox.borderRadius);
      expect(dangerBox.boxShadow, outlineBox.boxShadow);
      expect(dangerStyle.fontSize, outlineStyle.fontSize);
      expect(dangerStyle.fontWeight, outlineStyle.fontWeight);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.close)).size,
        outlineGlyph,
        reason: 'the glass glyph is 16 on both rungs',
      );
      expect(dangerStyle.color, isNot(outlineStyle.color));
    });

    testWidgets('glyph and spinner carry the destructive ink too',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.danger(
            label: 'Cancel request',
            leadingIcon: Icons.close,
            onTap: () {},
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Cancel request'));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.close)).color,
        Theme.of(context).colorScheme.onErrorContainer,
      );

      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.danger(
            label: 'Cancel request',
            isLoading: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      final CircularProgressIndicator spinner =
          tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      // Loading is a disabled state, so the ink arrives multiplicatively dimmed.
      expect(
        spinner.valueColor!.value,
        _dangerSoft.withValues(alpha: JeebCtaButton.disabledFillOpacity),
      );
    });

    testWidgets('h54 override and the disabled dim behave like .outline',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.danger(
            label: 'Cancel request',
            height: JeebCtaButton.outlineHeightTall,
            isEnabled: false,
            onTap: () {},
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Cancel request'));
      final JeebSemanticColors semantics = _semanticsOf(context);
      final BoxDecoration decoration =
          ctaDecorationOf(tester, find.byType(JeebCtaButton));

      expect(tester.getSize(find.byType(JeebCtaButton)).height, 54);
      expect(decoration.border, isNotNull);
      expect(
        decoration.color!.a,
        closeTo(semantics.glassFill.a * JeebCtaButton.disabledFillOpacity, 1e-6),
      );
      expect(
        tester.widget<Text>(find.text('Cancel request')).style!.color!.a,
        closeTo(JeebCtaButton.disabledFillOpacity, 1e-6),
      );
    });

    testWidgets('labelStyle sets typography but never the ink', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          Builder(
            builder: (BuildContext context) => JeebCtaButton.danger(
              label: 'Cancel request',
              labelStyle: context.jeebText.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: context.jeebRoles.accent,
              ),
              onTap: () {},
            ),
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Cancel request'));
      final Text label = tester.widget<Text>(find.text('Cancel request'));

      expect(label.style!.fontSize, context.jeebText.bodySmall.fontSize);
      expect(label.style!.fontWeight, FontWeight.w700);
      expect(
        label.style!.color,
        Theme.of(context).colorScheme.onErrorContainer,
        reason: 'a caller may not buy orange through labelStyle',
      );
      expect(label.style!.color, isNot(context.jeebRoles.accent));
    });

    testWidgets('reads the error roles safely under a bare ThemeData.light()',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: JeebCtaButton.danger(label: 'Cancel', onTap: () {}),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('fires onTap and drops it when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCta(JeebCtaButton.danger(label: 'Cancel', onTap: () => taps++)),
      );
      await tester.tap(find.byType(JeebCtaButton));
      expect(taps, 1);

      await tester.pumpWidget(
        wrapCta(
          JeebCtaButton.danger(
            label: 'Cancel',
            isEnabled: false,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(JeebCtaButton));
      expect(taps, 1);
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

    test('the variant set is the six ratified treatments', () {
      expect(JeebCtaVariant.values, <JeebCtaVariant>[
        JeebCtaVariant.primary,
        JeebCtaVariant.accent,
        JeebCtaVariant.outline,
        JeebCtaVariant.danger,
        JeebCtaVariant.text,
        JeebCtaVariant.accentText,
      ]);
    });

    test('the destructive ink traces to the ratified §1 danger rows', () {
      final ColorScheme scheme = AppTheme.midnight().colorScheme;
      expect(scheme.onErrorContainer, _dangerSoft);
      expect(scheme.error, _danger);
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
