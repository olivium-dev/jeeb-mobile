import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';

/// Local harness — the card lane's shared harness is a sibling file being
/// written concurrently, so this lane keeps its own.
Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: SizedBox(width: 400, child: child)),
    ),
  );
}

Finder _inBar(Finder matching) =>
    find.descendant(of: find.byType(JeebTopBar), matching: matching);

BoxDecoration _circleDecoration(WidgetTester tester, {int at = 0}) {
  final DecoratedBox box =
      tester.widgetList<DecoratedBox>(_inBar(find.byType(DecoratedBox)))
          .elementAt(at);
  return box.decoration as BoxDecoration;
}

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void _noop() {}

void main() {
  group('JeebTopBar — back mode', () {
    testWidgets('renders the tonal circle, 20px back glyph and an h2 title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar(leading: JeebTopBarLeading.back, title: 'Offers'),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebTopBar));
      final ColorScheme scheme = Theme.of(context).colorScheme;

      final BoxDecoration decoration = _circleDecoration(tester);
      expect(decoration.color, scheme.surfaceContainerHigh);
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.boxShadow, isNull);

      final SizedBox box = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: _inBar(find.byType(DecoratedBox)).first,
              matching: find.byType(SizedBox),
            ),
          )
          .first;
      expect(box.width, JeebTopBar.circleDiameter);
      expect(box.height, JeebTopBar.circleDiameter);

      final Icon glyph = tester.widget<Icon>(_inBar(find.byType(Icon)));
      expect(glyph.icon, Icons.arrow_back);
      expect(glyph.size, JeebTopBar.backGlyphSize);
      expect(glyph.color, scheme.primary);

      final TextStyle title = _styleOf(tester, 'Offers');
      expect(title.fontSize, context.jeebText.h2.fontSize);
      expect(title.fontWeight, context.jeebText.h2.fontWeight);
      expect(title.color, scheme.primary);
    });

    testWidgets('the VISIBLE circle sits on the board 14/24 inset',
        (WidgetTester tester) async {
      // The public default is the board's `14px 24px 0`; the widget then
      // subtracts JeebTopBar.tapOverhang so the 48dp target can grow without
      // pushing the visible Ø40 circle off the gutter.
      expect(
        JeebTopBar.defaultPadding,
        const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 0),
      );

      await tester.pumpWidget(_wrap(const JeebTopBar(title: 'Offers')));

      final Rect circle = tester.getRect(_inBar(find.byType(DecoratedBox)));
      final Rect bar = tester.getRect(find.byType(JeebTopBar));
      expect(circle.left - bar.left, closeTo(24, 0.01));
      expect(circle.top - bar.top, closeTo(14, 0.01));
      expect(circle.width, JeebTopBar.circleDiameter);
    });

    testWidgets('the visible gap from circle to title is the board 14',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebTopBar(title: 'Offers')));

      final Rect circle = tester.getRect(_inBar(find.byType(DecoratedBox)));
      final Rect title = tester.getRect(find.text('Offers'));
      expect(title.left - circle.right, closeTo(14, 0.01));
    });

    testWidgets('identifier lands on the leading circle and fires onLeading',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          JeebTopBar(
            title: 'Offers',
            identifier: 'offer_review_back',
            onLeadingPressed: () => taps++,
          ),
        ),
      );

      final Finder back = find.bySemanticsIdentifier('offer_review_back');
      expect(back, findsOneWidget);
      final SemanticsNode node = tester.getSemantics(back);
      expect(node.flagsCollection.isButton, isTrue);

      await tester.tap(back, warnIfMissed: false);
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('with no callback the back circle pops guardedly',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: Text('root')),
        ),
      );

      unawaited(
        tester.state<NavigatorState>(find.byType(Navigator)).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: JeebTopBar(title: 'Pushed', identifier: 'x_back'),
                ),
              ),
            ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pushed'), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('x_back'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('Pushed'), findsNothing);
      expect(find.text('root'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('with no Navigator above, the guarded default cannot throw',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: AppTheme.light(),
            child: const Material(
              child: JeebTopBar(title: 'Bare', identifier: 'bare_back'),
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsIdentifier('bare_back'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('title: null renders the bare circle (screen 03)',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const JeebTopBar(identifier: 'phone_otp_back_cta')),
      );

      expect(_inBar(find.byType(Text)), findsNothing);
      expect(find.bySemanticsIdentifier('phone_otp_back_cta'), findsOneWidget);
      handle.dispose();
    });
  });

  group('JeebTopBar — close mode', () {
    testWidgets('renders an 18px close glyph and the Material close tooltip',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.close(
            title: 'Your offer',
            identifier: 'offer_composer_close_cta',
          ),
        ),
      );

      final Icon glyph = tester.widget<Icon>(_inBar(find.byType(Icon)));
      expect(glyph.icon, Icons.close);
      expect(glyph.size, JeebTopBar.closeGlyphSize);

      final BuildContext context = tester.element(find.byType(JeebTopBar));
      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('offer_composer_close_cta'),
            )
            .label,
        MaterialLocalizations.of(context).closeButtonTooltip,
      );
      handle.dispose();
    });

    testWidgets('leadingTooltip overrides the default label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.close(
            title: 'Your offer',
            identifier: 'close_cta',
            leadingTooltip: 'Discard offer',
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsIdentifier('close_cta')).label,
        'Discard offer',
      );
      handle.dispose();
    });
  });

  group('JeebTopBar — subtitle', () {
    testWidgets('a String subtitle is bodySmall in mutedText',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.back(
            title: 'Offers',
            subtitle: 'Medicine - Pharmacie du Musee',
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebTopBar));
      final TextStyle style = _styleOf(tester, 'Medicine - Pharmacie du Musee');
      expect(style.fontSize, context.jeebText.bodySmall.fontSize);
      expect(style.fontWeight, context.jeebText.bodySmall.fontWeight);
      expect(
        style.color,
        Theme.of(context).extension<JeebSemanticColors>()!.mutedText,
      );
    });

    testWidgets('subtitleIdentifier wraps the line as a header node',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.close(
            title: 'Your offer',
            subtitle: 'ORD-9C37B6',
            subtitleIdentifier: 'offer_composer_order_ref',
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('offer_composer_order_ref'),
      );
      expect(node.identifier, 'offer_composer_order_ref');
      expect(node.flagsCollection.isHeader, isTrue);
      handle.dispose();
    });

    testWidgets('subtitleSlot renders a widget subtitle (screen 12)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.back(
            title: 'Medicine',
            titleScale: JeebTopBarTitleScale.compact,
            subtitleSlot: Row(
              children: <Widget>[Text('Flash'), Text(r'$8 cash')],
            ),
          ),
        ),
      );

      expect(find.text('Flash'), findsOneWidget);
      expect(find.text(r'$8 cash'), findsOneWidget);
    });

    testWidgets('compact scale drops the title to titleProminent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.back(
            title: 'Medicine',
            titleScale: JeebTopBarTitleScale.compact,
            subtitle: 'Flash',
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebTopBar));
      expect(
        _styleOf(tester, 'Medicine').fontSize,
        context.jeebText.titleProminent.fontSize,
      );
    });
  });

  group('JeebTopBar — trailing action', () {
    testWidgets('renders a second circle carrying its own identifier',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      var opened = 0;
      await tester.pumpWidget(
        _wrap(
          JeebTopBar.back(
            title: 'Medicine',
            identifier: 'tracking_back',
            trailing: JeebTopBarAction(
              icon: Icons.chat_bubble,
              identifier: 'order_summary_open_chat',
              onPressed: () => opened++,
            ),
          ),
        ),
      );

      expect(_inBar(find.byType(DecoratedBox)), findsNWidgets(2));
      await tester.tap(
        find.bySemanticsIdentifier('order_summary_open_chat'),
        warnIfMissed: false,
      );
      expect(opened, 1);
      expect(tester.widget<Icon>(find.byIcon(Icons.chat_bubble)).size, 19);
      handle.dispose();
    });

    testWidgets('the trailing circle sits at the end edge in LTR and RTL',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      const JeebTopBar bar = JeebTopBar(
        title: 'Medicine',
        identifier: 'tracking_back',
        trailing: JeebTopBarAction(
          icon: Icons.chat_bubble,
          identifier: 'order_summary_open_chat',
          onPressed: _noop,
        ),
      );

      await tester.pumpWidget(_wrap(bar));
      expect(
        tester.getCenter(find.bySemanticsIdentifier('tracking_back')).dx,
        lessThan(
          tester
              .getCenter(find.bySemanticsIdentifier('order_summary_open_chat'))
              .dx,
        ),
      );

      await tester.pumpWidget(_wrap(bar, direction: TextDirection.rtl));
      expect(
        tester.getCenter(find.bySemanticsIdentifier('tracking_back')).dx,
        greaterThan(
          tester
              .getCenter(find.bySemanticsIdentifier('order_summary_open_chat'))
              .dx,
        ),
      );
      handle.dispose();
    });
  });

  group('JeebTopBar — identity mode', () {
    testWidgets('renders back circle, avatar slot, cardTitle name, caption sub',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.identity(
            identifier: 'chat_detail_back_button',
            avatar: SizedBox.square(
              dimension: JeebTopBar.identityAvatarDiameter,
              child: Text('K'),
            ),
            avatarIdentifier: 'chat_detail_avatar',
            title: 'Karim',
            subtitle: '4.9',
            trailing: JeebTopBarAction(
              icon: Icons.phone,
              identifier: 'order_chat_open_dispute',
              onPressed: _noop,
              iconSize: 18,
            ),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebTopBar));
      expect(
        find.bySemanticsIdentifier('chat_detail_back_button'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('chat_detail_avatar'), findsOneWidget);
      expect(
        _styleOf(tester, 'Karim').fontSize,
        context.jeebText.cardTitle.fontSize,
      );
      expect(
        _styleOf(tester, '4.9').fontSize,
        context.jeebText.caption.fontSize,
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.phone)).size, 18);
      handle.dispose();
    });

    testWidgets('onAvatarPressed makes the avatar slot tappable',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          JeebTopBar.identity(
            title: 'Karim',
            avatar: const SizedBox.square(dimension: 42),
            avatarIdentifier: 'chat_detail_avatar',
            onAvatarPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsIdentifier('chat_detail_avatar'),
        warnIfMissed: false,
      );
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a null avatar is legal — 21 gates it on showAvatar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebTopBar.identity(title: 'Karim')));

      expect(find.text('Karim'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('JeebTopBar — floating treatment (screen 09 W2)', () {
    testWidgets('paints surface + floatPill instead of surfaceContainerHigh',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar(
            leadingTreatment: JeebTopBarLeadingTreatment.floating,
            identifier: 'capture_location_back',
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebTopBar));
      final BoxDecoration decoration = _circleDecoration(tester);
      expect(decoration.color, Theme.of(context).colorScheme.surface);
      expect(decoration.boxShadow, JeebShadows.floatPill);
    });
  });

  group('JeebTopBar — semantics hygiene', () {
    testWidgets('emits no identifier when the consumer owns the ids',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const JeebTopBar.back(title: 'Offers', subtitle: 'Medicine')),
      );

      // The circle still exposes a button node (a11y), it just carries no id —
      // screens like 23 nest the bar inside their own identified container.
      final SemanticsNode node =
          tester.getSemantics(_inBar(find.byType(MinTapTarget)).first);
      expect(node.identifier, isEmpty);
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('the leading circle reaches the 48dp minimum tap target',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebTopBar(title: 'Offers')));

      final Size size =
          tester.getSize(_inBar(find.byType(MinTapTarget)).first);
      expect(size.width, greaterThanOrEqualTo(A11y.minTapTargetSize));
      expect(size.height, greaterThanOrEqualTo(A11y.minTapTargetSize));
    });
  });

  group('JeebTopBar — RTL smoke', () {
    testWidgets('back glyph mirrors and the circle moves to the right edge',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.back(title: 'Offers', identifier: 'offers_back'),
          direction: TextDirection.rtl,
        ),
      );

      expect(
        tester.widget<Icon>(_inBar(find.byType(Icon))).icon,
        Icons.arrow_forward,
      );
      expect(
        tester.getCenter(find.bySemanticsIdentifier('offers_back')).dx,
        greaterThan(tester.getCenter(find.text('Offers')).dx),
      );
      handle.dispose();
    });

    testWidgets('identity orders back > avatar > text inward from the end',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.identity(
            identifier: 'chat_detail_back_button',
            avatar: SizedBox.square(dimension: 42),
            avatarIdentifier: 'chat_detail_avatar',
            title: 'Karim',
          ),
          direction: TextDirection.rtl,
        ),
      );

      final double back = tester
          .getCenter(find.bySemanticsIdentifier('chat_detail_back_button'))
          .dx;
      final double avatar =
          tester.getCenter(find.bySemanticsIdentifier('chat_detail_avatar')).dx;
      final double name = tester.getCenter(find.text('Karim')).dx;
      expect(back, greaterThan(avatar));
      expect(avatar, greaterThan(name));
      handle.dispose();
    });

    testWidgets('the board padding mirrors: start inset lands on the right',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebTopBar.back(title: 'Offers'),
          direction: TextDirection.rtl,
        ),
      );

      final Rect circle = tester.getRect(_inBar(find.byType(DecoratedBox)));
      final Rect bar = tester.getRect(find.byType(JeebTopBar));
      // 24 gutter minus the 4dp the 48dp target overhangs the O40 circle.
      expect(bar.right - circle.right, closeTo(24, 0.01));
    });
  });
}
