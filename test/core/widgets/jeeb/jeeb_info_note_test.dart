import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';

import 'jeeb_card_test_harness.dart';

/// Every `Semantics` node the note builds itself (InkWell's internal ones have
/// no identifier, so they never collide with these assertions).
Iterable<Semantics> _semanticsIn(WidgetTester tester) =>
    tester.widgetList<Semantics>(
      find.descendant(
        of: find.byType(JeebInfoNote),
        matching: find.byType(Semantics),
      ),
    );

Semantics? _nodeWithIdentifier(WidgetTester tester, String identifier) {
  for (final Semantics node in _semanticsIn(tester)) {
    if (node.properties.identifier == identifier) {
      return node;
    }
  }
  return null;
}

TextStyle _styleOf(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data)).style!;

// Token sheet §3, typed out rather than read back off the implementation.
const Color _glassFill = Color(0x12FFFFFF);
const Color _glassBorder = Color(0x1FFFFFFF);

void main() {
  group('JeebInfoNote — tones', () {
    testWidgets('muted paints a glass panel with muted ink (08)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.muted(
            icon: Icons.info,
            text: 'Jeebers set the price.',
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebInfoNote));
      final JeebSemanticColors semantics =
          Theme.of(context).extension<JeebSemanticColors>()!;

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebInfoNote));
      expect(decoration.color, _glassFill);
      final Border border = decoration.border! as Border;
      expect(border.top.color, _glassBorder);
      expect(border.top.width, JeebInfoNote.outlineWidth);
      expect(decoration.boxShadow, isNull, reason: 'glass never lifts');
      expect(
        decoration.borderRadius,
        BorderRadius.circular(JeebInfoNote.defaultRadius),
      );

      final TextStyle style = _styleOf(tester, 'Jeebers set the price.');
      expect(style.color, semantics.mutedText);
      expect(style.fontWeight, FontWeight.w500);
      // 12.5/w500 lh18 — the ramp's bodySmall, the board's line-height.
      expect(style.fontSize, context.jeebText.bodySmall.fontSize);
      expect(style.height, JeebInfoNote.bodyLineHeight);

      expect(tester.widget<Icon>(find.byType(Icon)).color, semantics.mutedText);
      expect(
        tester.widget<Icon>(find.byType(Icon)).size,
        JeebInfoNote.stripIconSize,
      );
    });

    testWidgets('accent inks the copy white and the link orange (17)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebInfoNote.accent(
            icon: Icons.account_balance_wallet,
            text: r'Wallet: $6.40 available',
            linkLabel: 'Top up',
            onLink: () {},
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebInfoNote));
      final ColorScheme scheme = Theme.of(context).colorScheme;

      expect(_styleOf(tester, r'Wallet: $6.40 available').color, scheme.onSurface);
      expect(
        _styleOf(tester, r'Wallet: $6.40 available').fontWeight,
        FontWeight.w600,
      );

      final TextStyle link = _styleOf(tester, 'Top up');
      expect(link.color, context.jeebRoles.accent);
      expect(link.fontWeight, FontWeight.w700);
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        scheme.onSurface,
        reason: 'R17 draws the wallet glyph white, not periwinkle',
      );
    });

    testWidgets('success uses the success role pair (23)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.success(
            icon: Icons.check_circle,
            title: "You're set to bid",
            text: 'Enough balance for the 10% reserve.',
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebInfoNote));
      final JeebRoles roles = context.jeebRoles;

      expect(
        decorationOf(tester, find.byType(JeebInfoNote)).color,
        roles.successContainer,
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        roles.onSuccessContainer,
        reason: 'R23 strokes the check #7BD9A4; deep green fails on its own '
            'container',
      );
      expect(
        _styleOf(tester, "You're set to bid").color,
        Theme.of(context).colorScheme.onSurface,
      );
      expect(_styleOf(tester, "You're set to bid").fontWeight, FontWeight.w700);
    });

    testWidgets('warning uses the warning role pair (23 16)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.warning(
            icon: Icons.warning_rounded,
            title: 'Top up to bid',
            text: 'Not enough for the reserve.',
          ),
        ),
      );

      final JeebRoles roles =
          tester.element(find.byType(JeebInfoNote)).jeebRoles;
      expect(
        decorationOf(tester, find.byType(JeebInfoNote)).color,
        roles.warningContainer,
      );
      expect(
        _styleOf(tester, 'Not enough for the reserve.').color,
        roles.onWarningContainer,
      );
    });

    testWidgets('outlined is a stroke with no fill at all (23)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.outlined(
            icon: Icons.lock,
            title: 'Reserved right now',
            text: "Released if you're not picked",
            trailing: Text(r'$0.80'),
          ),
        ),
      );

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebInfoNote));

      expect(decoration.color, Colors.transparent);
      expect(decoration.boxShadow, isNull);
      final Border border = decoration.border! as Border;
      expect(border.top.color, _glassBorder);
      expect(border.top.width, JeebInfoNote.outlineWidth);
      expect(find.text(r'$0.80'), findsOneWidget);
    });

    testWidgets('error uses Wave 0 soft errorContainer (11)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.error(
            icon: Icons.error_outline,
            text: 'Could not load offers.',
          ),
        ),
      );

      final ColorScheme scheme =
          Theme.of(tester.element(find.byType(JeebInfoNote))).colorScheme;
      expect(
        decorationOf(tester, find.byType(JeebInfoNote)).color,
        scheme.errorContainer,
      );
      expect(
        _styleOf(tester, 'Could not load offers.').color,
        scheme.onErrorContainer,
      );
    });

    testWidgets('named constructors resolve to their tone',
        (WidgetTester tester) async {
      const List<JeebInfoNote> notes = <JeebInfoNote>[
        JeebInfoNote.muted(text: 'a'),
        JeebInfoNote.accent(text: 'a'),
        JeebInfoNote.success(text: 'a'),
        JeebInfoNote.warning(text: 'a'),
        JeebInfoNote.outlined(text: 'a'),
        JeebInfoNote.error(text: 'a'),
      ];
      expect(
        notes.map((JeebInfoNote note) => note.tone).toList(),
        JeebInfoNoteTone.values,
      );
    });
  });

  group('JeebInfoNote — the two forms', () {
    testWidgets('strip form: pad 12/16 + stroke, gap 10, glyph 17',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.muted(icon: Icons.key, text: 'Door code'),
        ),
      );

      final Rect note = tester.getRect(find.byType(JeebInfoNote));
      final Rect glyph = tester.getRect(find.byType(Icon));
      final Rect copy = tester.getRect(find.text('Door code'));

      expect(glyph.left - note.left, 16 + JeebInfoNote.outlineWidth);
      expect(
        glyph.top - note.top,
        closeTo(12 + JeebInfoNote.outlineWidth, 0.51),
      );
      expect(copy.left - glyph.right, JeebInfoNote.stripGap);
      expect(glyph.width, JeebInfoNote.stripIconSize);
      // The strip is one line: the copy is vertically centred on the glyph.
      expect(copy.center.dy, closeTo(glyph.center.dy, 0.51));
    });

    testWidgets('a title switches the note to the stacked form: 13/16, gap 12, glyph 19',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.success(
            icon: Icons.check_circle,
            title: 'Title',
            text: 'Sub',
          ),
        ),
      );

      final JeebInfoNote note =
          tester.widget<JeebInfoNote>(find.byType(JeebInfoNote));
      expect(note.isStacked, isTrue);

      final Rect box = tester.getRect(find.byType(JeebInfoNote));
      final Rect glyph = tester.getRect(find.byType(Icon));
      final Rect title = tester.getRect(find.text('Title'));

      expect(glyph.left - box.left, 16);
      expect(title.left - glyph.right, JeebInfoNote.stackedGap);
      expect(glyph.width, JeebInfoNote.stackedIconSize);
      // Title above sub, both start-aligned.
      expect(tester.getRect(find.text('Sub')).top, greaterThan(title.top));
      expect(tester.getRect(find.text('Sub')).left, title.left);
      // The stacked sub-line drops the 18px line-height (23 sets none).
      expect(_styleOf(tester, 'Sub').height, isNull);
    });

    testWidgets('outlined folds its stroke into the padding (border-box)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.outlined(icon: Icons.lock, title: 'T', text: 'S'),
        ),
      );

      final Rect box = tester.getRect(find.byType(JeebInfoNote));
      final Rect glyph = tester.getRect(find.byType(Icon));
      // 16 padding + the stroke — the copy must not creep under the outline.
      expect(glyph.left - box.left, 16 + JeebInfoNote.outlineWidth);
    });

    testWidgets('explicit padding, gap, radius and glyph size win',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.muted(
            icon: Icons.info,
            text: 'x',
            padding: EdgeInsetsDirectional.fromSTEB(24, 6, 8, 6),
            gap: 4,
            radius: 22,
            iconSize: 30,
            iconColor: Color(0xFF00FF00),
          ),
        ),
      );

      final Rect box = tester.getRect(find.byType(JeebInfoNote));
      final Rect glyph = tester.getRect(find.byType(Icon));
      expect(glyph.left - box.left, 24 + JeebInfoNote.outlineWidth);
      expect(tester.getRect(find.text('x')).left - glyph.right, 4);
      expect(glyph.width, 30);
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        const Color(0xFF00FF00),
      );
      expect(
        decorationOf(tester, find.byType(JeebInfoNote)).borderRadius,
        BorderRadius.circular(22),
      );
    });

    testWidgets('the label widget slot replaces the kit-styled text (12)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.muted(
            icon: Icons.vpn_key_outlined,
            label: Text('own ink', style: TextStyle(color: Color(0xFF123456))),
            trailing: Text('2144'),
          ),
        ),
      );

      expect(_styleOf(tester, 'own ink').color, const Color(0xFF123456));
      expect(find.text('2144'), findsOneWidget);
    });

    testWidgets('the leading widget slot replaces the glyph (11 dot)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.accent(
            leading: SizedBox(key: Key('dot'), width: 8, height: 8),
            text: '3 offers in',
            trailing: SizedBox(key: Key('meter'), width: 70, height: 5),
          ),
        ),
      );

      expect(find.byType(Icon), findsNothing, reason: 'no IconData was given');
      final Rect dot = tester.getRect(find.byKey(const Key('dot')));
      final Rect meter = tester.getRect(find.byKey(const Key('meter')));
      // The kit imposes no size on either slot: 11 owns its Ø8 dot and 70×5
      // meter verbatim.
      expect(dot.size, const Size(8, 8));
      expect(meter.size, const Size(70, 5));
      expect(
        tester.getRect(find.text('3 offers in')).left - dot.right,
        JeebInfoNote.stripGap,
      );
      expect(dot.right, lessThan(meter.left));
    });
  });

  group('JeebInfoNote — interaction and semantics', () {
    testWidgets('onTap fires and paints the splash inside the note (12)',
        (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCard(
          JeebInfoNote.muted(
            icon: Icons.vpn_key_outlined,
            text: 'Door code',
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(JeebInfoNote));
      expect(taps, 1);
    });

    testWidgets(
        'no identifier and no label => the note adds NO Semantics node, even '
        'with onTap (12 owns tracking_handover_code_row)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebInfoNote.muted(
            icon: Icons.vpn_key_outlined,
            text: 'Door code',
            onTap: () {},
          ),
        ),
      );

      expect(
        _semanticsIn(tester).where(
          (Semantics node) =>
              node.properties.identifier != null ||
              node.properties.label != null,
        ),
        isEmpty,
      );
    });

    testWidgets('identifier is applied via an explicit Semantics wrapper',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebInfoNote.accent(
            icon: Icons.account_balance_wallet,
            text: r'Wallet: $6.40 available',
            linkLabel: 'Top up',
            onLink: () {},
            identifier: 'offer_composer_wallet_strip',
            linkIdentifier: 'offer_composer_wallet_topup_cta',
            semanticLabel: 'Wallet balance',
            semanticHint: 'Opens top up',
          ),
        ),
      );

      final Semantics? root =
          _nodeWithIdentifier(tester, 'offer_composer_wallet_strip');
      expect(root, isNotNull);
      expect(root!.container, isTrue);
      expect(
        root.explicitChildNodes,
        isTrue,
        reason: 'without it the root node swallows the link id',
      );
      expect(root.properties.label, 'Wallet balance');
      expect(root.properties.hint, 'Opens top up');
      expect(root.properties.button, isFalse, reason: 'no onTap on 17');

      // The nested link keeps its own frozen id.
      final Semantics? link =
          _nodeWithIdentifier(tester, 'offer_composer_wallet_topup_cta');
      expect(link, isNotNull);
      expect(link!.properties.button, isTrue);
    });

    testWidgets('the root node reports button:true when the note is tappable',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebInfoNote.muted(
            text: 'x',
            onTap: () {},
            identifier: 'note_root',
          ),
        ),
      );
      expect(_nodeWithIdentifier(tester, 'note_root')!.properties.button, isTrue);
    });

    testWidgets('tapping the link fires onLink, not onTap (17)',
        (WidgetTester tester) async {
      var links = 0;
      var taps = 0;
      await tester.pumpWidget(
        wrapCard(
          JeebInfoNote.accent(
            icon: Icons.account_balance_wallet,
            text: 'Wallet',
            linkLabel: 'Top up',
            onLink: () => links++,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Top up'));
      expect(links, 1);
      expect(taps, 0, reason: 'the link owns its own hit area');
    });
  });

  group('JeebInfoNote — RTL', () {
    testWidgets('smoke: the row mirrors — glyph at the end, trailing at the start',
        (WidgetTester tester) async {
      Future<List<double>> edges(TextDirection direction) async {
        await tester.pumpWidget(
          wrapCard(
            const JeebInfoNote.muted(
              icon: Icons.vpn_key_outlined,
              text: 'رمز الباب',
              trailing: Text('2144'),
            ),
            direction: direction,
          ),
        );
        return <double>[
          tester.getCenter(find.byType(Icon)).dx,
          tester.getCenter(find.text('2144')).dx,
        ];
      }

      final List<double> ltr = await edges(TextDirection.ltr);
      expect(ltr[0], lessThan(ltr[1]));

      final List<double> rtl = await edges(TextDirection.rtl);
      expect(
        rtl[0],
        greaterThan(rtl[1]),
        reason: 'the leading glyph must move to the visual right under RTL',
      );
    });

    testWidgets('directional padding resolves start/end, never left/right',
        (WidgetTester tester) async {
      const JeebInfoNote note = JeebInfoNote.muted(
        icon: Icons.info,
        text: 'ملاحظة',
        padding: EdgeInsetsDirectional.fromSTEB(30, 10, 6, 10),
      );

      await tester.pumpWidget(wrapCard(note));
      expect(
        tester.getRect(find.byType(Icon)).left -
            tester.getRect(find.byType(JeebInfoNote)).left,
        30 + JeebInfoNote.outlineWidth,
      );

      await tester.pumpWidget(wrapCard(note, direction: TextDirection.rtl));
      expect(
        tester.getRect(find.byType(JeebInfoNote)).right -
            tester.getRect(find.byType(Icon)).right,
        30 + JeebInfoNote.outlineWidth,
        reason: 'start padding must land on the right edge under RTL',
      );
    });

    testWidgets('the stacked column stays start-aligned under RTL',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebInfoNote.success(
            icon: Icons.check_circle,
            title: 'عنوان',
            text: 'نص',
          ),
          direction: TextDirection.rtl,
        ),
      );

      expect(
        tester.getRect(find.text('عنوان')).right,
        tester.getRect(find.text('نص')).right,
      );
    });
  });

  group('JeebInfoNote — theme resilience and re-tone', () {
    testWidgets('survives a theme with no JeebSemanticColors extension',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: JeebInfoNote.muted(icon: Icons.info, text: 'no extension'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        _styleOf(tester, 'no extension').color,
        JeebSemanticColors.light().mutedText,
      );
    });

    testWidgets('re-tones itself on navy via JeebSurfaceTone, with no onNavy flag',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard(
            state: JeebCardState.selected,
            child: JeebInfoNote.muted(icon: Icons.info, text: 'on navy'),
          ),
        ),
      );

      final JeebSemanticColors semantics =
          Theme.of(tester.element(find.byType(JeebInfoNote)))
              .extension<JeebSemanticColors>()!;
      // The panel keeps its glass recipe; only the ink follows the surface.
      expect(decorationOf(tester, find.byType(JeebInfoNote)).color, _glassFill);
      expect(_styleOf(tester, 'on navy').color, semantics.inkSoft);
    });

    testWidgets('a state tone keeps its role colours on navy — the state is the message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard(
            state: JeebCardState.selected,
            child: JeebInfoNote.success(title: 'ok', text: 'still green'),
          ),
        ),
      );

      final JeebRoles roles =
          tester.element(find.byType(JeebInfoNote)).jeebRoles;
      expect(
        decorationOf(tester, find.byType(JeebInfoNote)).color,
        roles.successContainer,
      );
    });
  });
}
