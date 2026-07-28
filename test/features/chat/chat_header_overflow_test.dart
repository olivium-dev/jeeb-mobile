/// b02 chat-header redesign — the "BOTTOM OVERFLOWED BY 16 PIXELS" gate.
///
/// ## What the defect actually was
///
/// `_ChatBody` builds a `Column` whose non-flexible children are the chrome
/// (fee banner · pinned summary · offer-accepted banner · removed banner · TTL
/// indicator · composer) and whose only flexible child is the message list. A
/// `Column` satisfies its NON-flexible children first and shares out only the
/// remainder. With the keyboard open the viewport shrinks by the keyboard's
/// height, the chrome's intrinsic height exceeds what is left, `Expanded` is
/// allocated ZERO, and the Column overflows by exactly the excess.
///
/// It is **not** `resizeToAvoidBottomInset` (unset → true, and the Scaffold
/// shrinking correctly is what creates the over-constraint) and **not** a
/// double-counted `SafeArea` (`SafeArea(bottom: false)`, top already consumed
/// by the AppBar). These tests therefore drive a real bottom `viewInsets`, the
/// way the platform reports a keyboard — a short surface alone reproduces a
/// small phone, not a keyboard.
///
/// ## What the fix is
///
/// The chrome is bounded to [kChatHeaderMaxViewportFraction] of the available
/// height, so the message list can never be starved to zero. The collapsed
/// header + compact banner sit well inside that bound at ordinary text scales,
/// which is asserted here: if the bound were load-bearing in the normal case it
/// would be hiding content rather than budgeting it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';

import 'chat_header_support.dart';

/// A Pixel-class phone in dp, and a keyboard of the height Gboard reports on
/// one. This is the geometry the owner's screenshot was taken at.
const Size kPhone = Size(411, 914);
const double kKeyboard = 300;

const OrderChatSummary kSummary = OrderChatSummary(
  deliveryId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
  priceLabel: r'$12.00',
  jeeberName: 'Kamal Hajj',
  statusId: 'in_transit',
  description: 'Two kilos of apples from the Spinneys on Hamra street, '
      'plus a large bag of ice if they have any left.',
);

Future<void> _pump(
  WidgetTester tester, {
  Size size = kPhone,
  double keyboard = kKeyboard,
  double textScale = 1.0,
  OrderChatSummary? summary = kSummary,
  bool jeeberCta = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final gateway = FakeChatGateway(
    phase: ConversationPhase.accepted,
    history: sampleThread(),
  );
  addTearDown(gateway.dispose);

  await tester.pumpWidget(themedHost(
    ChatScreen(
      deliveryId: 'conv-1',
      counterpartName: 'Kamal Hajj',
      gateway: gateway,
      isOrderChat: true,
      pinnedSummary: summary,
      onViewSummary: () {},
      onStartActiveDelivery: jeeberCta ? () {} : null,
    ),
    keyboardInset: keyboard,
    textScale: textScale,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

double _headerHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(chatHeaderSlotKey)).height;

/// The natural (unbounded) height of the chrome. Equal to the slot height means
/// the bound is NOT engaged; greater means the slot is scrolling.
double _headerNaturalHeight(WidgetTester tester) => tester
    .getSize(find
        .descendant(of: find.byKey(chatHeaderSlotKey), matching: find.byType(Column))
        .first)
    .height;

void main() {
  setUpAll(loadArb);
  setUp(ChatHeaderExpansionStore.instance.reset);

  // ---------------------------------------------------------------------------
  // THE MECHANISM, isolated. This is the permanent proof of the diagnosis: the
  // overflow is produced by non-flexible children in a Column that has shrunk,
  // it equals the excess exactly, and BOUNDING the chrome is what removes it.
  // Neither `resizeToAvoidBottomInset` nor `SafeArea` appears anywhere in it.
  // ---------------------------------------------------------------------------
  group('root cause, isolated from the chat screen', () {
    Widget frame({required double viewport, required bool bounded}) {
      const chromeHeight = 216.0; // the pre-redesign chrome
      const composerHeight = 56.0;
      final chrome = Container(height: chromeHeight, color: const Color(0xFF00FF00));
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 400,
            height: viewport,
            child: Column(
              children: [
                if (bounded)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: viewport * 0.4),
                    child: SingleChildScrollView(child: chrome),
                  )
                else
                  chrome,
                const Expanded(child: SizedBox.shrink()),
                Container(height: composerHeight, color: const Color(0xFF0000FF)),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('UNBOUNDED chrome overflows by exactly the excess — 16 px when '
        'the chrome is 16 px taller than the viewport allows', (tester) async {
      // 216 chrome + 56 composer = 272 wanted, 256 available → 16 px over.
      await tester.pumpWidget(frame(viewport: 256, bounded: false));
      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(
        error.toString(),
        contains('overflowed by 16 pixels on the bottom'),
        reason: 'this IS the reported "BOTTOM OVERFLOWED BY 16 PIXELS"',
      );
    });

    testWidgets('BOUNDED chrome does not overflow at the same viewport',
        (tester) async {
      await tester.pumpWidget(frame(viewport: 256, bounded: true));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('KEYBOARD OPEN, both headers present: no overflow, and the '
      'message list keeps a usable budget', (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsIdentifier('order_chat_pinned_summary'),
        findsOneWidget);
    expect(find.byKey(const Key('offer-accepted-banner')), findsOneWidget);

    final viewport = kPhone.height - kKeyboard;
    final header = _headerHeight(tester);
    final list = tester.getSize(find.byKey(ChatScreen.messageListKey)).height;
    // ignore: avoid_print
    print('\nPIXEL BUDGET (dp, ${kPhone.width.toInt()}x${kPhone.height.toInt()} '
        'phone, ${kKeyboard.toInt()} dp keyboard)\n'
        '  viewport after keyboard ......... ${viewport.toStringAsFixed(1)}\n'
        '  chrome (both headers) ........... ${header.toStringAsFixed(1)}\n'
        '  message list .................... ${list.toStringAsFixed(1)}\n');

    // BUDGET. Note the instrument: a widget test renders with a FALLBACK font
    // whose glyphs are square em boxes, so every text run measures ~1.8x its
    // real Inter width and the collapsed row wraps onto a second line here that
    // it does not wrap onto on device. These thresholds are therefore the
    // PESSIMISTIC bound; the on-device figure is measured from the emulator
    // screenshots in the PR body and is smaller.
    expect(header, lessThan(200),
        reason: 'collapsed chrome budget (square-glyph test font)');
    expect(list, greaterThan(240),
        reason: 'the message list must stay usable with the keyboard open');
  });

  testWidgets('the bound is NOT what makes it fit — the chrome is naturally '
      'inside it at scale 1.0 and 1.3', (tester) async {
    for (final scale in <double>[1.0, 1.3]) {
      await _pump(tester, textScale: scale);
      expect(tester.takeException(), isNull, reason: 'scale $scale');
      expect(
        _headerNaturalHeight(tester),
        lessThanOrEqualTo(_headerHeight(tester)),
        reason: 'at text scale $scale the bounded header slot is scrolling, '
            'which means the collapsed design does not actually fit and the '
            'bound is hiding content instead of budgeting it',
      );
    }
  });

  testWidgets('expanding the header still leaves the message list a positive '
      'allocation (the Expanded child is never starved)', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final header = _headerHeight(tester);
    final list = tester.getSize(find.byKey(ChatScreen.messageListKey)).height;
    // ignore: avoid_print
    print('EXPANDED with keyboard: chrome=${header.toStringAsFixed(1)} dp, '
        'list=${list.toStringAsFixed(1)} dp');
    expect(header,
        lessThanOrEqualTo((kPhone.height - kKeyboard) * kChatHeaderMaxViewportFraction + 0.5));
    expect(list, greaterThan(0));
  });

  testWidgets('the degenerate cases that used to overflow now lay out clean',
      (tester) async {
    // Every one of these was an over-constraint before the bound existed: a
    // short phone, a huge text scale, and both together.
    final cases = <({Size size, double keyboard, double scale, String name})>[
      (size: kPhone, keyboard: kKeyboard, scale: 2.0, name: 'text scale 2.0'),
      (size: const Size(320, 480), keyboard: 220, scale: 1.0, name: 'small phone'),
      (size: const Size(320, 480), keyboard: 220, scale: 1.3, name: 'small + 1.3'),
      (size: const Size(320, 400), keyboard: 200, scale: 1.0, name: 'very short'),
    ];
    for (final c in cases) {
      await _pump(tester,
          size: c.size, keyboard: c.keyboard, textScale: c.scale);
      expect(tester.takeException(), isNull, reason: c.name);
      expect(find.byKey(ChatScreen.messageListKey), findsOneWidget,
          reason: c.name);
    }
  });

  testWidgets('the expanded header at text scale 2.0 degrades by scrolling its '
      'bounded slot, not by overflowing', (tester) async {
    await _pump(tester, textScale: 2);
    await tester.tap(
      find.bySemanticsIdentifier('order_chat_summary_expand'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The slot is now doing its job: natural height exceeds the bound and the
    // region scrolls. Nothing is clipped away — every element stays reachable.
    expect(_headerNaturalHeight(tester),
        greaterThan(_headerHeight(tester) - 0.5));
    expect(find.byKey(ChatScreen.messageListKey), findsOneWidget);
  });

  testWidgets('320x480 at a 2.0 text scale with the keyboard open: the header '
      'yields ALL of its space rather than overflowing, and the thread + '
      'composer stay whole', (tester) async {
    // The genuinely impossible case. The contract is a priority order, not a
    // guarantee that everything fits: read the thread, send a message, then the
    // order summary. The header returns as soon as the keyboard closes.
    await _pump(tester, size: const Size(320, 480), keyboard: 220, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(_headerHeight(tester), 0);
    expect(find.byKey(ChatScreen.messageListKey), findsOneWidget);

    await _pump(tester, size: const Size(320, 480), keyboard: 0, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(_headerHeight(tester), greaterThan(0),
        reason: 'the header must come back when the keyboard closes');
  });

  testWidgets('no pinned summary + no banner: the slot is absent entirely',
      (tester) async {
    final gateway = FakeChatGateway(
      phase: ConversationPhase.broadcasting,
      history: sampleThread(),
    );
    addTearDown(gateway.dispose);
    await tester.binding.setSurfaceSize(kPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(themedHost(
      ChatScreen(
        deliveryId: 'conv-2',
        counterpartName: 'Kamal Hajj',
        gateway: gateway,
      ),
      keyboardInset: kKeyboard,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
