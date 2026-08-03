import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_footer.dart';

import 'jeeb_cta_test_harness.dart';

void main() {
  group('JeebCtaFooter.single', () {
    testWidgets('pads 0/24/32 and stretches its child', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.single(
            child: JeebCtaButton.primary(label: 'Confirm tier', onTap: () {}),
          ),
        ),
      );

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebCtaFooter),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, JeebCtaFooter.docked);
      // 320 gutter box minus the two 24px gutters.
      expect(tester.getSize(find.byType(JeebCtaButton)).width, 320 - 48);
    });

    testWidgets('stacks `below` under the pill at `spacing`', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.single(
            padding: JeebCtaFooter.inline,
            below: JeebCtaButton.accentText(
              label: 'How fees work',
              onTap: () {},
            ),
            child: JeebCtaButton.primary(
              label: 'Top up wallet',
              leadingIcon: Icons.add,
              onTap: () {},
            ),
          ),
        ),
      );

      final double pillBottom =
          tester.getRect(find.text('Top up wallet')).bottom;
      expect(
        tester.getRect(find.text('How fees work')).top,
        greaterThan(pillBottom),
      );
      expect(
        tester
            .widget<Padding>(
              find
                  .descendant(
                    of: find.byType(JeebCtaFooter),
                    matching: find.byType(Padding),
                  )
                  .first,
            )
            .padding,
        JeebCtaFooter.inline,
      );
    });

    testWidgets('renders the child alone when `below` is null', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.single(
            child: JeebCtaButton.primary(label: 'Confirm', onTap: () {}),
          ),
        ),
      );

      expect(find.byType(Column), findsNothing);
      expect(find.byType(JeebCtaButton), findsOneWidget);
    });
  });

  group('JeebCtaFooter.split', () {
    testWidgets('01: intrinsic leading + expanded trailing', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.split(
            leading: JeebCtaButton.text(
              label: 'Skip',
              height: JeebCtaButton.primaryHeight,
              onTap: () {},
            ),
            trailing: JeebCtaButton.primary(
              label: 'Next',
              trailingIcon: Icons.arrow_forward,
              mirrorIcons: true,
              onTap: () {},
            ),
          ),
        ),
      );

      final double skipWidth =
          tester.getSize(find.ancestor(
            of: find.text('Skip'),
            matching: find.byType(JeebCtaButton),
          )).width;
      final double nextWidth =
          tester.getSize(find.ancestor(
            of: find.text('Next'),
            matching: find.byType(JeebCtaButton),
          )).width;

      expect(nextWidth, greaterThan(skipWidth));
      // 320 - 48 gutters - 12 gap.
      expect(skipWidth + nextWidth, closeTo(320 - 48 - 12, 0.01));
    });

    testWidgets('12: expandLeading splits the row in half', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.split(
            expandLeading: true,
            leading: JeebCtaButton.text(
              label: 'Report no-show',
              height: JeebCtaButton.outlineHeight,
              onTap: () {},
            ),
            trailing: JeebCtaButton.outline(
              label: 'Open dispute',
              onTap: () {},
            ),
          ),
        ),
      );

      final double leadingWidth =
          tester.getSize(find.ancestor(
            of: find.text('Report no-show'),
            matching: find.byType(JeebCtaButton),
          )).width;
      final double trailingWidth =
          tester.getSize(find.ancestor(
            of: find.text('Open dispute'),
            matching: find.byType(JeebCtaButton),
          )).width;

      expect(leadingWidth, closeTo(trailingWidth, 0.01));
      expect(leadingWidth, closeTo((320 - 48 - 12) / 2, 0.01));
    });

    testWidgets('accepts an arbitrary widget as leading (01 OmdsSkipButton)',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.split(
            leading: const Text('Skip'),
            trailing: JeebCtaButton.primary(label: 'Next', onTap: () {}),
          ),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('JeebCtaFooter.textStack', () {
    testWidgets('11: accent 12/w700 note over a bare action, no pill',
        (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.textStack(
            note: 'Accept only one offer.',
            action: JeebCtaButton.text(label: 'Cancel request', onTap: () {}),
          ),
        ),
      );

      final Finder noteFinder = find.text('Accept only one offer.');
      final BuildContext context = tester.element(noteFinder);
      final Text note = tester.widget<Text>(noteFinder);

      expect(note.style!.color, context.jeebRoles.accent);
      expect(note.style!.fontWeight, FontWeight.w700);
      expect(note.style!.fontSize, context.jeebText.bodySmall.fontSize);
      expect(note.textAlign, TextAlign.center);
      expect(
        tester.getRect(find.text('Cancel request')).top,
        greaterThan(tester.getRect(noteFinder).bottom),
      );
      // No pill anywhere in this form.
      expect(
        ctaDecorationOf(tester, find.byType(JeebCtaButton)).color,
        isNull,
      );
    });

    testWidgets('the action stays tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.textStack(
            note: 'Accept only one offer.',
            action: JeebCtaButton.text(
              label: 'Cancel request',
              onTap: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel request'));
      expect(taps, 1);
    });
  });

  group('JeebCtaFooter RTL smoke', () {
    testWidgets('split mirrors: leading sits at the start edge', (tester) async {
      Future<double> leadingCentre(TextDirection direction) async {
        await tester.pumpWidget(
          wrapCta(
            JeebCtaFooter.split(
              leading: JeebCtaButton.text(label: 'Skip', onTap: () {}),
              trailing: JeebCtaButton.primary(label: 'Next', onTap: () {}),
            ),
            direction: direction,
          ),
        );
        return tester.getCenter(find.text('Skip')).dx;
      }

      final double ltr = await leadingCentre(TextDirection.ltr);
      final double rtl = await leadingCentre(TextDirection.rtl);
      expect(rtl, greaterThan(ltr));
    });

    testWidgets('the 24px gutters mirror', (tester) async {
      Future<Rect> pillRect(TextDirection direction) async {
        await tester.pumpWidget(
          wrapCta(
            JeebCtaFooter.single(
              child: JeebCtaButton.primary(label: 'تأكيد', onTap: () {}),
            ),
            direction: direction,
          ),
        );
        return tester.getRect(find.byType(JeebCtaButton));
      }

      // Symmetric gutters, so the box is identical — what must not happen is a
      // hardcoded `EdgeInsets.only(left:)` shifting it.
      expect(await pillRect(TextDirection.rtl),
          await pillRect(TextDirection.ltr));
    });

    testWidgets('textStack renders in RTL', (tester) async {
      await tester.pumpWidget(
        wrapCta(
          JeebCtaFooter.textStack(
            note: 'اقبل عرضًا واحدًا فقط.',
            action: JeebCtaButton.text(label: 'إلغاء الطلب', onTap: () {}),
          ),
          direction: TextDirection.rtl,
        ),
      );

      expect(find.text('اقبل عرضًا واحدًا فقط.'), findsOneWidget);
      expect(find.text('إلغاء الطلب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
