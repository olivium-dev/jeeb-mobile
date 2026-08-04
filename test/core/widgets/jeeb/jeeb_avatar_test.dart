import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';
import 'package:omds/omds.dart';

import 'jeeb_avatar_test_harness.dart';

/// MIDNIGHT token sheet §1–§3 — the expected values, not a read-back.
const Color _surfaceHigh = Color(0xFF10175E);
const Color _surfaceHighest = Color(0xFF151C69);
const Color _ink = Color(0xFFEDEFFC);
const Color _inkMuted = Color(0xFF8A93D8);
const Color _page = Color(0xFF070C33);
const Color _orange = Color(0xFFD73B00);
const Color _white = Color(0xFFFFFFFF);
const Color _success = Color(0xFF3BB273);

void main() {
  group('JeebAvatar — composition contract', () {
    testWidgets('composes OmdsProfileAvatar and forwards avatarKey', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatar.header(
            initial: 'Lina',
            avatarKey: Key('client-home-greeting-avatar'),
          ),
        ),
      );

      // Five shipped tests cast to OmdsProfileAvatar by key; the composed
      // avatar must be the thing the key lands on, not the JeebAvatar.
      final OmdsProfileAvatar avatar = tester.widget<OmdsProfileAvatar>(
        find.byKey(const Key('client-home-greeting-avatar')),
      );
      expect(avatar.initial, 'L');
    });

    testWidgets('a full name and its letter resolve identically', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapAvatar(
          const Row(
            children: <Widget>[
              JeebAvatar.thread(initial: 'Nour'),
              JeebAvatar.thread(initial: 'n'),
            ],
          ),
        ),
      );

      final Iterable<OmdsProfileAvatar> avatars =
          tester.widgetList<OmdsProfileAvatar>(
        find.byType(OmdsProfileAvatar),
      );
      expect(avatars.map((OmdsProfileAvatar a) => a.initial), <String>['N', 'N']);
    });

    testWidgets('no name and no photo degrade to "?" and a null url', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapAvatar(const JeebAvatar.thread(initial: '  ', imageUrl: '   ')),
      );

      final OmdsProfileAvatar avatar =
          composedAvatar(tester, find.byType(JeebAvatar));
      expect(avatar.initial, '?');
      expect(avatar.profilePicUrl, isNull, reason: 'blank url is not a url');
    });

    test('initialFrom matches the shipped _GreetingAvatar derivation', () {
      expect(JeebAvatar.initialFrom(null), '?');
      expect(JeebAvatar.initialFrom('   '), '?');
      expect(JeebAvatar.initialFrom(' omar'), 'O');
      expect(JeebAvatar.initialFrom('كريم'), 'ك');
    });
  });

  group('JeebAvatar — the four realized sizes', () {
    const Map<String, List<double>> expected = <String, List<double>>{
      'stack': <double>[30, 11],
      'thread': <double>[42, 15],
      'header': <double>[46, 17],
      'hero': <double>[74, 26],
    };

    testWidgets('each named constructor pins Ø and the initial size', (
      tester,
    ) async {
      const Map<String, JeebAvatar> avatars = <String, JeebAvatar>{
        'stack': JeebAvatar.stack(initial: 'K'),
        'thread': JeebAvatar.thread(initial: 'K'),
        'header': JeebAvatar.header(initial: 'K'),
        'hero': JeebAvatar.hero(initial: 'K'),
      };

      for (final MapEntry<String, JeebAvatar> entry in avatars.entries) {
        await tester.pumpWidget(wrapAvatar(entry.value));
        final OmdsProfileAvatar avatar =
            composedAvatar(tester, find.byType(JeebAvatar));
        expect(avatar.size, expected[entry.key]![0], reason: entry.key);
        expect(
          avatar.initialFontSize,
          expected[entry.key]![1],
          reason: entry.key,
        );
      }
    });

    test('initialSizeFor is exact on the board sizes, ratio elsewhere', () {
      expect(JeebAvatar.initialSizeFor(30), 11);
      expect(JeebAvatar.initialSizeFor(42), 15);
      expect(JeebAvatar.initialSizeFor(46), 17);
      expect(JeebAvatar.initialSizeFor(74), 26);
      // 16's Ø44 → 16 and 20's Ø50 → 18, both off-table but on the board.
      expect(JeebAvatar.initialSizeFor(44), closeTo(16, 0.2));
      expect(JeebAvatar.initialSizeFor(50), 18);
    });
  });

  group('JeebAvatar — fills', () {
    // Captured as data, never as a BuildContext: the element is deactivated by
    // the next pump.
    late ThemeData theme;
    late JeebRoles roles;

    Future<OmdsProfileAvatar> pumpFill(
      WidgetTester tester,
      JeebAvatarFill fill, {
      JeebSurfaceToneData Function(BuildContext)? tone,
    }) async {
      await tester.pumpWidget(
        wrapAvatar(
          ContextProbe(
            onContext: (BuildContext context) {
              theme = Theme.of(context);
              roles = context.jeebRoles;
            },
            child: Builder(
              builder: (BuildContext context) {
                final Widget avatar =
                    JeebAvatar.thread(initial: 'K', fill: fill);
                if (tone == null) return avatar;
                return JeebSurfaceTone(tone: tone(context), child: avatar);
              },
            ),
          ),
        ),
      );
      return composedAvatar(tester, find.byType(JeebAvatar));
    }

    testWidgets('the rotation is navy → periwinkle → orange', (tester) async {
      expect(
        JeebAvatarFill.rotation,
        <JeebAvatarFill>[
          JeebAvatarFill.primary,
          JeebAvatarFill.muted,
          JeebAvatarFill.accent,
        ],
      );
      expect(JeebAvatarFill.forIndex(3), JeebAvatarFill.primary);

      // Navy is the RAISED navy, never `colorScheme.primary`: under MIDNIGHT
      // that slot is the brand orange and the rotation would go all-orange.
      final OmdsProfileAvatar primary =
          await pumpFill(tester, JeebAvatarFill.primary);
      final ColorScheme scheme = theme.colorScheme;
      expect(primary.backgroundColor, _surfaceHigh);
      expect(primary.backgroundColor, scheme.surfaceContainerHigh);
      expect(primary.backgroundColor, isNot(scheme.primary));
      expect(primary.initialColor, _ink);

      final OmdsProfileAvatar muted =
          await pumpFill(tester, JeebAvatarFill.muted);
      expect(muted.backgroundColor, _inkMuted);
      expect(muted.backgroundColor, roles.info);
      // Page navy, not white: white on #8A93D8 is 2.9:1 and fails AA.
      expect(muted.initialColor, _page);
      expect(muted.initialColor, roles.onInfo);

      final OmdsProfileAvatar accent =
          await pumpFill(tester, JeebAvatarFill.accent);
      expect(accent.backgroundColor, _orange);
      expect(accent.backgroundColor, roles.accent);
      expect(accent.initialColor, _white);
    });

    testWidgets('dormant is surfaceContainerHighest + periwinkle ink', (
      tester,
    ) async {
      final OmdsProfileAvatar avatar =
          await pumpFill(tester, JeebAvatarFill.dormant);
      expect(avatar.backgroundColor, _surfaceHighest);
      expect(avatar.backgroundColor, theme.colorScheme.surfaceContainerHighest);
      expect(avatar.initialColor, _inkMuted);
      expect(
        avatar.initialColor,
        theme.extension<JeebSemanticColors>()!.mutedText,
      );
    });

    testWidgets('onAccent is the 20% white disc on 13\'s orange banner', (
      tester,
    ) async {
      final OmdsProfileAvatar avatar =
          await pumpFill(tester, JeebAvatarFill.onAccent);
      expect(
        avatar.backgroundColor,
        _white.withValues(alpha: 0.2),
      );
      expect(avatar.initialColor, roles.onAccent);
    });

    test('glass is ADDITIVE — the stack rotation is untouched', () {
      // Wave-B ruling 3 adds a rung; it must not join the 04 stack rotation.
      expect(JeebAvatarFill.rotation.length, 3);
      expect(JeebAvatarFill.rotation, isNot(contains(JeebAvatarFill.glass)));
      expect(JeebAvatarFill.forIndex(3), JeebAvatarFill.primary);
      expect(JeebAvatar.glassFillAlpha, 0.22);
    });

    testWidgets('glass is white @22% with a WHITE initial', (tester) async {
      final OmdsProfileAvatar avatar =
          await pumpFill(tester, JeebAvatarFill.glass);
      expect(
        avatar.backgroundColor,
        _white.withValues(alpha: JeebAvatar.glassFillAlpha),
      );
      expect(avatar.initialColor, _white);
      expect(avatar.initialColor, roles.onAccent);
      // The two rungs it exists because of: primary is opaque navy, dormant
      // forces periwinkle ink — neither reads on the Midnight field.
      expect(avatar.backgroundColor, isNot(_surfaceHigh));
      expect(avatar.initialColor, isNot(_inkMuted));
    });

    testWidgets('glass stays translucent on a navy card', (tester) async {
      // Unlike primary, it must NOT re-tone: the field has to show through.
      final OmdsProfileAvatar avatar = await pumpFill(
        tester,
        JeebAvatarFill.glass,
        tone: (BuildContext context) => JeebSurfaceToneData.navy(context),
      );
      expect(avatar.backgroundColor!.a, closeTo(0.22, 0.001));
      expect(avatar.initialColor, _white);
    });

    testWidgets('R15 mounts it at Ø74 with the completion badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatar.hero(
            initial: 'Karim',
            fill: JeebAvatarFill.glass,
            badge: JeebAvatarBadge.completed,
          ),
        ),
      );

      final OmdsProfileAvatar avatar =
          composedAvatar(tester, find.byType(JeebAvatar));
      expect(avatar.size, JeebAvatar.heroDiameter);
      expect(avatar.initial, 'K');
      expect(avatar.initialColor, _white);
      expect(find.byKey(JeebAvatar.badgeKey), findsOneWidget);
    });

    testWidgets('primary re-tones on a navy surface instead of vanishing', (
      tester,
    ) async {
      late JeebSurfaceToneData navy;
      final OmdsProfileAvatar avatar = await pumpFill(
        tester,
        JeebAvatarFill.primary,
        tone: (BuildContext context) => navy = JeebSurfaceToneData.navy(context),
      );
      // Read from the published tone, not a copy of its alphas: the card lane
      // owns those values and this widget's contract is to inherit them.
      expect(avatar.backgroundColor, navy.chipFill);
      expect(avatar.initialColor, navy.chipInk);
      expect(avatar.backgroundColor, isNot(_surfaceHigh));
    });

    testWidgets('a bare ThemeData.light() theme does not crash the read', (
      tester,
    ) async {
      // `wrapForTest` and several feature harnesses theme with ThemeData.light(),
      // where JeebSemanticColors is absent — a bare `!` would throw.
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatar.thread(
            initial: 'K',
            fill: JeebAvatarFill.dormant,
          ),
          theme: ThemeData.light(),
        ),
      );
      expect(tester.takeException(), isNull);
      // `.light()` is a MIDNIGHT alias now, so the fallback ink is periwinkle.
      expect(
        composedAvatar(tester, find.byType(JeebAvatar)).initialColor,
        _inkMuted,
      );
      expect(JeebSemanticColors.light().mutedText, _inkMuted);
    });
  });

  group('JeebAvatar — rings, dots and badges', () {
    testWidgets('the ring is painted outside the disc', (tester) async {
      await tester.pumpWidget(wrapAvatar(const JeebAvatar.stack(initial: 'K')));

      // Ø30 fill + a 2px ring on each side = a 34px footprint; the stack's
      // −9 overlap is measured against this box, not against 30.
      expect(tester.getSize(find.byType(JeebAvatar)), const Size(34, 34));
      expect(composedAvatar(tester, find.byType(JeebAvatar)).size, 30);
    });

    testWidgets('presence is green at the bottom-END, unread orange at top', (
      tester,
    ) async {
      late JeebRoles roles;
      await tester.pumpWidget(
        wrapAvatar(
          ContextProbe(
            onContext: (BuildContext context) => roles = context.jeebRoles,
            child: const JeebAvatar.thread(
              initial: 'K',
              dot: JeebAvatarDot.presence,
            ),
          ),
        ),
      );

      final PositionedDirectional presence = tester.widget(
        find.ancestor(
          of: find.byKey(JeebAvatar.dotKey),
          matching: find.byType(PositionedDirectional),
        ),
      );
      expect(presence.end, JeebAvatar.dotOffset);
      expect(presence.bottom, JeebAvatar.dotOffset);
      expect(presence.top, isNull);
      expect(
        _discFill(tester, JeebAvatar.dotKey),
        _success,
        reason: 'sprint-009 §G2 forbids an ad-hoc presence green',
      );
      expect(_discFill(tester, JeebAvatar.dotKey), roles.success);
      expect(tester.getSize(find.byKey(JeebAvatar.dotKey)), const Size(16, 16));

      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatar.header(initial: 'L', dot: JeebAvatarDot.unread),
        ),
      );
      final PositionedDirectional unread = tester.widget(
        find.ancestor(
          of: find.byKey(JeebAvatar.dotKey),
          matching: find.byType(PositionedDirectional),
        ),
      );
      expect(unread.end, JeebAvatar.dotOffset);
      expect(unread.top, JeebAvatar.dotOffset);
      expect(unread.bottom, isNull);
      // Live/unread state is a sanctioned orange (master plan §2.2).
      expect(_discFill(tester, JeebAvatar.dotKey), _orange);
      expect(_discFill(tester, JeebAvatar.dotKey), roles.accent);
    });

    testWidgets('the completed badge is Ø26 orange + a check at bottom-END', (
      tester,
    ) async {
      late JeebRoles roles;
      await tester.pumpWidget(
        wrapAvatar(
          ContextProbe(
            onContext: (BuildContext context) => roles = context.jeebRoles,
            child: const JeebAvatar.hero(
              initial: 'Karim',
              badge: JeebAvatarBadge.completed,
            ),
          ),
        ),
      );

      final PositionedDirectional badge = tester.widget(
        find.ancestor(
          of: find.byKey(JeebAvatar.badgeKey),
          matching: find.byType(PositionedDirectional),
        ),
      );
      expect(badge.end, JeebAvatar.badgeOffset);
      expect(badge.bottom, JeebAvatar.badgeOffset);
      expect(_discFill(tester, JeebAvatar.badgeKey), _orange);
      expect(_discFill(tester, JeebAvatar.badgeKey), roles.accent);
      // 26 + a 3px surface ring on each side.
      expect(tester.getSize(find.byKey(JeebAvatar.badgeKey)), const Size(32, 32));

      final Icon check = tester.widget(find.byIcon(Icons.check));
      expect(check.size, JeebAvatar.badgeGlyphSize);
      expect(check.color, _white);
      expect(check.color, roles.onAccent);
    });

    test('a dot and a badge cannot share the corner', () {
      expect(
        () => JeebAvatar(
          initial: 'K',
          dot: JeebAvatarDot.presence,
          badge: JeebAvatarBadge.completed,
        ),
        throwsAssertionError,
      );
    });
  });

  group('JeebAvatar — semantics', () {
    testWidgets('no identifier, label or onTap adds no node', (tester) async {
      await tester.pumpWidget(wrapAvatar(const JeebAvatar.thread(initial: 'K')));
      expect(
        find.descendant(
          of: find.byType(JeebAvatar),
          matching: find.byType(Semantics),
        ),
        findsNothing,
        reason: 'a bare avatar must not swallow ids the consumer owns',
      );
    });

    testWidgets('identifier surfaces as an image node', (tester) async {
      await tester.pumpWidget(
        wrapAvatar(
          const JeebAvatar.hero(
            initial: 'Karim',
            identifier: 'mutual_rating_ratee_avatar',
            semanticLabel: 'Karim',
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('mutual_rating_ratee_avatar'),
        findsOneWidget,
      );
      final Semantics node = tester.widget(
        find.descendant(
          of: find.byType(JeebAvatar),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(node.properties.image, isTrue);
      expect(node.properties.label, 'Karim');
    });

    testWidgets('onTap makes it a button and fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapAvatar(
          JeebAvatar.thread(
            initial: 'K',
            identifier: 'chat_detail_avatar',
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(JeebAvatar));
      expect(taps, 1);

      final Semantics node = tester.widget(
        find.descendant(
          of: find.byType(JeebAvatar),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(node.properties.button, isTrue);
      expect(node.properties.image, isFalse);
    });
  });

  group('JeebAvatar — RTL', () {
    testWidgets('the dot mirrors to the start edge under ar', (tester) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapAvatar(
            const JeebAvatar.header(initial: 'L', dot: JeebAvatarDot.unread),
            direction: direction,
          ),
        );

        final double disc = tester.getCenter(find.byType(JeebAvatar)).dx;
        final double dot = tester.getCenter(find.byKey(JeebAvatar.dotKey)).dx;
        if (direction == TextDirection.ltr) {
          expect(dot, greaterThan(disc), reason: 'END is right in ltr');
        } else {
          expect(dot, lessThan(disc), reason: 'END is left in rtl');
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders in both directions without overflow', (tester) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapAvatar(
            const JeebAvatar.hero(
              initial: 'كريم',
              badge: JeebAvatarBadge.completed,
            ),
            direction: direction,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('ك'), findsOneWidget);
      }
    });
  });
}

/// The fill of the inner disc under [key] (the outer box paints the ring).
Color? _discFill(WidgetTester tester, Key key) {
  final Container inner = tester.widget<Container>(
    find.descendant(of: find.byKey(key), matching: find.byType(Container)).last,
  );
  return (inner.decoration! as BoxDecoration).color;
}
