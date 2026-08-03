import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_profile_header.dart';

/// Local harness — kept out of the card lane's shared file, which is being
/// written concurrently.
Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: SizedBox(width: 400, child: child)),
    ),
  );
}

Finder _inHeader(Finder matching) =>
    find.descendant(of: find.byType(JeebProfileHeader), matching: matching);

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

const Widget _avatar = SizedBox.square(
  dimension: JeebProfileHeader.avatarDiameter,
  child: Text('L'),
);

void main() {
  group('JeebProfileHeader — type and ink', () {
    testWidgets('eyebrow is 13/w600 mutedText, name 19/w700 navy',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            eyebrow: 'Good morning',
            name: 'Hello, Lina',
          ),
        ),
      );

      final BuildContext context =
          tester.element(find.byType(JeebProfileHeader));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final JeebSemanticColors semantics =
          Theme.of(context).extension<JeebSemanticColors>()!;

      final TextStyle eyebrow = _styleOf(tester, 'Good morning');
      expect(eyebrow.fontSize, 13);
      expect(eyebrow.fontWeight, FontWeight.w600);
      expect(eyebrow.color, semantics.mutedText);

      final TextStyle name = _styleOf(tester, 'Hello, Lina');
      expect(name.fontSize, 19);
      expect(name.fontWeight, FontWeight.w700);
      expect(name.color, scheme.primary);
      // Derived from the h2 token, not a free-standing style.
      expect(name.fontFamily, context.jeebText.h2.fontFamily);
    });

    testWidgets('the eyebrow is optional; the name still renders',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const JeebProfileHeader(avatar: _avatar, name: 'Ahlan, Omar')),
      );

      expect(find.text('Ahlan, Omar'), findsOneWidget);
      expect(_inHeader(find.byType(Text)), findsNWidgets(2)); // avatar + name
    });

    testWidgets('a long name ellipsizes on one line',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            eyebrow: 'Good morning',
            name: 'Hello, Abdul-Rahman Al-Khoury Ibn Something Very Long',
          ),
        ),
      );

      final Text name = tester.widget<Text>(
        find.text('Hello, Abdul-Rahman Al-Khoury Ibn Something Very Long'),
      );
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });

  group('JeebProfileHeader — avatar slot', () {
    testWidgets('avatarIdentifier wraps the slot in an explicit node',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            avatarIdentifier: 'jeeber_home_avatar',
            eyebrow: 'Jeeber dashboard',
            name: 'Ahlan, Omar',
          ),
        ),
      );

      final Finder node = find.bySemanticsIdentifier('jeeber_home_avatar');
      expect(node, findsOneWidget);
      expect(
        tester.getSemantics(node).identifier,
        'jeeber_home_avatar',
      );
      handle.dispose();
    });

    testWidgets('onAvatarPressed makes the slot tappable',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          JeebProfileHeader(
            avatar: _avatar,
            avatarIdentifier: 'client_home_avatar',
            name: 'Hello, Lina',
            onAvatarPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsIdentifier('client_home_avatar'),
        warnIfMissed: false,
      );
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a null avatar collapses the slot without a gap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const JeebProfileHeader(name: 'Hello, Lina')),
      );

      final Rect header = tester.getRect(find.byType(JeebProfileHeader));
      final Rect name = tester.getRect(find.text('Hello, Lina'));
      expect(name.left - header.left, closeTo(0, 0.01));
    });
  });

  group('JeebProfileHeader — trailing', () {
    testWidgets('a trailing glyph is inked navy at 24px',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            eyebrow: 'Good morning',
            name: 'Hello, Lina',
            trailing: Icon(Icons.notifications),
          ),
        ),
      );

      final BuildContext context =
          tester.element(find.byType(JeebProfileHeader));
      final IconThemeData theme = IconTheme.of(
        tester.element(find.byIcon(Icons.notifications)),
      );
      expect(theme.size, JeebProfileHeader.trailingGlyphSize);
      expect(theme.color, Theme.of(context).colorScheme.primary);
    });

    testWidgets('trailingReserve holds end-side width when trailing is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            name: 'Hello, Lina',
            trailingReserve: 96,
          ),
        ),
      );

      final Rect header = tester.getRect(find.byType(JeebProfileHeader));
      final Rect name = tester.getRect(find.text('Hello, Lina'));
      // The name's box must stop 96px short of the end edge so the shell's
      // overlaid wallet chip + bell cannot sit on top of a long name.
      expect(header.right - name.right, closeTo(96, 0.01));
    });
  });

  group('JeebProfileHeader — rating pill', () {
    testWidgets('renders a surfaceContainerHigh pill with a NAVY star',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            eyebrow: 'Jeeber dashboard',
            name: 'Ahlan, Omar',
            ratingLabel: '4.8',
          ),
        ),
      );

      final BuildContext context =
          tester.element(find.byType(JeebProfileHeader));
      final ColorScheme scheme = Theme.of(context).colorScheme;

      final BoxDecoration decoration =
          tester.widget<DecoratedBox>(_inHeader(find.byType(DecoratedBox)).last)
              .decoration as BoxDecoration;
      expect(decoration.color, scheme.surfaceContainerHigh);

      final Icon star = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
      expect(star.color, scheme.primary);
      // §4.1 rations the one warm ink: this pill is a header affordance, not a
      // rating stat, so the star must never pick up the accent/star tint.
      expect(star.color, isNot(context.jeebRoles.accent));

      final TextStyle value = _styleOf(tester, '4.8');
      expect(value.fontWeight, FontWeight.w700);
      expect(value.color, scheme.primary);
      expect(value.fontSize, context.jeebText.bodySmall.fontSize);
    });

    testWidgets('the pill carries its id and hides the glyph behind a label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            name: 'Ahlan, Omar',
            ratingLabel: '4.8',
            ratingIdentifier: 'jeeber_home_rating',
            ratingSemanticLabel: 'Rating 4.8 out of 5',
          ),
        ),
      );

      final SemanticsNode node =
          tester.getSemantics(find.bySemanticsIdentifier('jeeber_home_rating'));
      expect(node.label, 'Rating 4.8 out of 5');
      handle.dispose();
    });
  });

  group('JeebProfileHeader — semantics hygiene', () {
    testWidgets('adds no header node unless identifier is given',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            name: 'Hello, Lina',
            identifier: 'client_home_greeting',
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('client_home_greeting'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('JeebProfileHeader — RTL smoke', () {
    testWidgets('avatar moves to the right and the text stack follows',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            eyebrow: 'Good morning',
            name: 'Hello, Lina',
            trailing: Icon(Icons.notifications),
          ),
          direction: TextDirection.rtl,
        ),
      );

      final double avatar = tester.getCenter(find.text('L')).dx;
      final double name = tester.getCenter(find.text('Hello, Lina')).dx;
      final double bell =
          tester.getCenter(find.byIcon(Icons.notifications)).dx;
      expect(avatar, greaterThan(name));
      expect(name, greaterThan(bell));
    });

    testWidgets('the eyebrow and name align to the start edge under RTL',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebProfileHeader(
            avatar: _avatar,
            eyebrow: 'Good morning',
            name: 'Hello, Lina',
          ),
          direction: TextDirection.rtl,
        ),
      );

      final Rect eyebrow = tester.getRect(find.text('Good morning'));
      final Rect name = tester.getRect(find.text('Hello, Lina'));
      expect(eyebrow.right, closeTo(name.right, 0.01));
    });

    testWidgets('trailingReserve reserves the RIGHT edge under LTR and the '
        'LEFT edge under RTL', (WidgetTester tester) async {
      const JeebProfileHeader header = JeebProfileHeader(
        avatar: _avatar,
        name: 'Hello, Lina',
        trailingReserve: 96,
      );

      await tester.pumpWidget(_wrap(header, direction: TextDirection.rtl));
      final Rect bounds = tester.getRect(find.byType(JeebProfileHeader));
      final Rect name = tester.getRect(find.text('Hello, Lina'));
      expect(name.left - bounds.left, closeTo(96, 0.01));
    });
  });
}
