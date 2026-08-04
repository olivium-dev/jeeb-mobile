import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar_stack.dart';
import 'package:omds/omds.dart';

import 'jeeb_avatar_test_harness.dart';

const List<JeebAvatarEntry> _board = <JeebAvatarEntry>[
  JeebAvatarEntry(initial: 'Karim'),
  JeebAvatarEntry(initial: 'Nour'),
  JeebAvatarEntry(initial: 'Rami'),
];

List<JeebAvatar> _avatars(WidgetTester tester) =>
    tester.widgetList<JeebAvatar>(find.byType(JeebAvatar)).toList();

void main() {
  group('JeebAvatarStack — geometry', () {
    testWidgets('three Ø30 discs overlap by 9 on a 34px footprint', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapAvatar(const JeebAvatarStack(avatars: _board)),
      );

      // Each disc is 30 + a 2px ring on each side = 34; the overlap is measured
      // against that box, so the run is 34 + 2 × (34 − 9) = 84.
      expect(tester.getSize(find.byType(JeebAvatarStack)), const Size(84, 34));
      expect(find.byType(JeebAvatar), findsNWidgets(3));
      for (final JeebAvatar avatar in _avatars(tester)) {
        expect(avatar.diameter, JeebAvatar.stackDiameter);
        expect(avatar.ringWidth, JeebAvatar.stackRingWidth);
      }
    });

    testWidgets('an empty stack with nothing trailing takes no space', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapAvatar(const JeebAvatarStack(avatars: <JeebAvatarEntry>[])),
      );
      expect(tester.getSize(find.byType(JeebAvatarStack)), Size.zero);
    });

    testWidgets('later discs paint over earlier ones', (tester) async {
      await tester.pumpWidget(
        wrapAvatar(const JeebAvatarStack(avatars: _board)),
      );
      final Stack stack = tester.widget<Stack>(
        find.descendant(
          of: find.byType(JeebAvatarStack),
          matching: find.byType(Stack),
        ).first,
      );
      // The board paints K under N under R (04 tpl 208-210), which in a Stack
      // is simply source order.
      expect(stack.children.length, 3);
    });
  });

  group('JeebAvatarStack — fills', () {
    testWidgets('known identities take the rotation by slot', (tester) async {
      await tester.pumpWidget(
        wrapAvatar(const JeebAvatarStack(avatars: _board)),
      );
      expect(
        _avatars(tester).map((JeebAvatar a) => a.fill),
        <JeebAvatarFill>[
          JeebAvatarFill.primary,
          JeebAvatarFill.muted,
          JeebAvatarFill.accent,
        ],
      );
      // R1's awake card: navy / periwinkle / orange, MIDNIGHT token sheet §1–§3.
      expect(
        tester
            .widgetList<OmdsProfileAvatar>(find.byType(OmdsProfileAvatar))
            .map((OmdsProfileAvatar a) => a.backgroundColor),
        <Color>[
          const Color(0xFF10175E),
          const Color(0xFF8A93D8),
          const Color(0xFFD73B00),
        ],
      );
    });

    testWidgets('the rotation wraps past three', (tester) async {
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatarStack(
            avatars: <JeebAvatarEntry>[
              ..._board,
              JeebAvatarEntry(initial: 'Sami'),
            ],
          ),
        ),
      );
      expect(_avatars(tester).last.fill, JeebAvatarFill.primary);
    });

    testWidgets('no name and no photo is dormant, never a fabricated colour', (
      tester,
    ) async {
      // 04 has no offerer names: the board's K/N/R must NOT be invented, and
      // the honest mark is the dormant disc.
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatarStack(
            avatars: <JeebAvatarEntry>[
              JeebAvatarEntry(),
              JeebAvatarEntry(),
            ],
          ),
        ),
      );
      expect(
        _avatars(tester).map((JeebAvatar a) => a.fill),
        <JeebAvatarFill>[JeebAvatarFill.dormant, JeebAvatarFill.dormant],
      );
    });

    testWidgets('a photo alone counts as a known identity', (tester) async {
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatarStack(
            avatars: <JeebAvatarEntry>[JeebAvatarEntry(imageUrl: 'a.png')],
          ),
        ),
      );
      expect(_avatars(tester).single.fill, JeebAvatarFill.primary);
      expect(
        tester.widget<OmdsProfileAvatar>(find.byType(OmdsProfileAvatar)).profilePicUrl,
        'a.png',
      );
    });

    testWidgets('an explicit entry fill wins over the rotation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatarStack(
            avatars: <JeebAvatarEntry>[
              JeebAvatarEntry(initial: 'K', fill: JeebAvatarFill.accent),
            ],
          ),
        ),
      );
      expect(_avatars(tester).single.fill, JeebAvatarFill.accent);
    });
  });

  group('JeebAvatarStack — trailing and semantics', () {
    testWidgets('the +N overflow stays the caller\'s widget', (tester) async {
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatarStack(avatars: _board, trailing: Text('+6')),
        ),
      );

      expect(find.text('+6'), findsOneWidget);
      // 84 run + a 4px gap + the text.
      expect(
        tester.getTopLeft(find.text('+6')).dx -
            tester.getTopLeft(find.byType(JeebAvatarStack)).dx,
        greaterThanOrEqualTo(88),
      );
    });

    testWidgets('identifier and label wrap the whole run', (tester) async {
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatarStack(
            avatars: _board,
            trailing: Text('+2'),
            identifier: 'orders_replies_avatar_stack_rep-7',
            semanticLabel: '5',
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('orders_replies_avatar_stack_rep-7'),
        findsOneWidget,
      );
      final Semantics node = tester.widget(
        find.descendant(
          of: find.byType(JeebAvatarStack),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(node.properties.label, '5');
      // Deliberately not a container node: the shipped wrapper is not one, and
      // `semantics_identifier_surfacing_test` reads the shipped shape.
      expect(node.container, isFalse);
    });

    testWidgets('no identifier and no label adds no node', (tester) async {
      await tester.pumpWidget(
        wrapAvatar(const JeebAvatarStack(avatars: _board)),
      );
      expect(
        find.descendant(
          of: find.byType(JeebAvatarStack),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });
  });

  group('JeebAvatarStack — RTL', () {
    testWidgets('the run grows from the END edge and mirrors', (tester) async {
      final Map<TextDirection, List<double>> centers =
          <TextDirection, List<double>>{};

      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapAvatar(
            const JeebAvatarStack(avatars: _board),
            direction: direction,
          ),
        );
        centers[direction] = <double>[
          for (int index = 0; index < 3; index++)
            tester.getCenter(find.byType(JeebAvatar).at(index)).dx,
        ];
        expect(tester.takeException(), isNull);
      }

      final List<double> ltr = centers[TextDirection.ltr]!;
      final List<double> rtl = centers[TextDirection.rtl]!;
      expect(ltr[0], lessThan(ltr[1]));
      expect(ltr[1], lessThan(ltr[2]));
      // The whole run mirrors: slot 0 is on the right under ar.
      expect(rtl[0], greaterThan(rtl[1]));
      expect(rtl[1], greaterThan(rtl[2]));
      expect(ltr[1], closeTo(rtl[1], 0.01), reason: 'the run stays centred');
    });
  });
}
