// The client-home create surface (redesign-2026-08 screen 04).
//
// The capsule body is the tap-only create-order button and carries
// `orders_create_request_button` (frozen: jm-023/jm-024, flows 08/13/14/15,
// client_home_429_tolerant_test); the Ø56 mic carries `client_home_mic_cta`,
// floats bottom-end over the scroll body and records in place on press-and-hold.
// Both must hold on EVERY load phase, not just the happy one — a customer who
// cannot start a request because the list is loading or the gateway 429'd is
// the defect these pin.
//
// Plus the two negative pins the July "single create entry point" directive
// left behind, which the hero must NOT revive, and an RTL smoke test.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_glass_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_mic_hero.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_request_hero.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_typed_hint.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';

/// Never completes — pins the screen in its loading layout.
class _HangingRepo implements ClientHomeRepository {
  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// Always throws — pins the screen in its failed layout.
class _FailingRepo implements ClientHomeRepository {
  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw StateError('offline');
}

Widget _harness({
  required ClientHomeRepository repo,
  Locale locale = const Locale('en'),
  double bottomInset = 0,
  double textScale = 1.0,
  void Function(Tier?)? onCreateRequest,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion.
    builder: (context, child) {
      final data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
          // What the shell's `_NavBarContentInset` feeds the pill nav's height
          // into; `scrollBodyBottomInset` reads exactly this.
          viewPadding: data.viewPadding.copyWith(bottom: bottomInset),
        ),
        child: child!,
      );
    },
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Lina',
        ),
        child: ClientHomeScreen(
          initialTab: ClientHomeTab.pendingRequests,
          onCreateRequest: onCreateRequest ?? (_) {},
        ),
      ),
    ),
  );
}

/// The pinned half on its own, with the ticker left running. The screen-level
/// harness pins `disableAnimations: true`, which is exactly what a rotating
/// hint must NOT be tested under.
Widget _heroOnly({
  Locale locale = const Locale('en'),
  bool firstRequest = false,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: ClientHomeRequestHero(
          onCreateRequest: () {},
          showPrompt: false,
          firstRequest: firstRequest,
        ),
      ),
    ),
  );
}

/// The capsule run as a reader sees it, caret stripped.
String _capsuleRun(WidgetTester tester) {
  final Text text = tester.widget<Text>(
    find
        .descendant(
          of: find.byType(ClientHomeRequestHero),
          matching: find.byType(Text),
        )
        .last,
  );
  final String plain = text.data ?? text.textSpan!.toPlainText();
  return plain.replaceAll(ClientHomeTypedHint.caretGlyph, '');
}

const _reply = ClientHomeRequest(
  id: 'rep-1',
  title: 'ORD-23470',
  displayId: 'ORD-23470',
  destinationLabel: 'Spinneys Achrafieh',
  itemsSummary: 'Groceries',
  status: ClientRequestStatus.offersReceived,
  tier: ClientRequestTier.onTheWay,
  offerCount: 3,
  offerAvatarUrls: <String>['a', 'b', 'c'],
);

void main() {
  group('ClientHomeRequestHero is reachable on every load phase', () {
    for (final entry in <String, ClientHomeRepository Function()>{
      'ready': () => InMemoryClientHomeRepository(latency: Duration.zero),
      'loading': _HangingRepo.new,
      'failed': _FailingRepo.new,
    }.entries) {
      testWidgets('${entry.key} layout exposes both hero ids', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness(repo: entry.value()));
        // No pumpAndSettle: the loading layout never settles by design.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.bySemanticsIdentifier('orders_create_request_button'),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(
                find.bySemanticsIdentifier('orders_create_request_button'),
              )
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'a create surface with no tap handler is the guarded defect',
        );
        expect(
          find.bySemanticsIdentifier('client_home_mic_cta'),
          findsOneWidget,
        );

        // The retired ids stay retired — the hero is a NEW surface, not the
        // revival of the deleted voice CTA.
        expect(
          find.bySemanticsIdentifier('client_home_voice_request'),
          findsNothing,
        );
        expect(find.byKey(const Key('client-home-voice-cta')), findsNothing);
        handle.dispose();
      });
    }
  });

  testWidgets('exactly one create surface exists on the ready screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    // The July directive's intent: one create SURFACE — and one question. The
    // hero prompt is time-of-day; the E1 tile must not ask it a second time.
    expect(find.textContaining('What do you need'), findsOneWidget);
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.byType(JeebMicHero), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('ar: the screen mirrors and the mic sits at the end edge', (
    tester,
  ) async {
    final repo = InMemoryClientHomeRepository.fromSnapshot(
      const ClientHomeSnapshot(replies: [_reply]),
      latency: Duration.zero,
    );
    await tester.pumpWidget(_harness(repo: repo, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(JeebMicHero))),
      TextDirection.rtl,
    );
    // End edge under RTL is the LEFT edge: the floating disc must mirror there.
    final micLeft = tester.getTopLeft(find.byType(JeebMicHero)).dx;
    final screenWidth = tester.getSize(find.byType(ClientHomeScreen)).width;
    expect(
      micLeft,
      lessThan(screenWidth / 2),
      reason: 'the floating mic must mirror to the end (left) edge under ar',
    );
    // The whole screen laid out without an overflow (the tester turns those
    // into test failures automatically, so simply arriving here is the pin).
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mic floats over the scroll body, not inside the capsule', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    final mic = find.byType(JeebMicHero);
    expect(
      find.descendant(of: find.byType(ClientHomeRequestHero), matching: mic),
      findsNothing,
      reason: 'the capsule keeps only its create body now',
    );
    // The prompt half scrolls; the capsule half is pinned beside the mic.
    expect(find.byType(ClientHomeRequestHero), findsNWidgets(2));
    expect(
      find.ancestor(of: mic, matching: find.byType(ListView)),
      findsNothing,
      reason: 'a pinned action must not scroll away',
    );

    // Bottom-end: below and after the capsule it replaced.
    final micRect = tester.getRect(mic);
    final screen = tester.getSize(find.byType(ClientHomeScreen));
    expect(micRect.center.dy, greaterThan(screen.height / 2));
    expect(micRect.center.dx, greaterThan(screen.width / 2));
    expect(
      screen.height - micRect.bottom,
      greaterThanOrEqualTo(Spacing.xLarge),
      reason: 'the disc must keep air under it for the shell pill nav',
    );
  });

  testWidgets('the floating mic clears the nav inset the shell hands it', (
    tester,
  ) async {
    // The pill nav's painted height, as `_NavBarContentInset` reports it.
    const navInset = 96.0;
    await tester.pumpWidget(
      _harness(
        repo: InMemoryClientHomeRepository(latency: Duration.zero),
        bottomInset: navInset,
      ),
    );
    await tester.pumpAndSettle();

    final micRect = tester.getRect(find.byType(JeebMicHero));
    final screen = tester.getSize(find.byType(ClientHomeScreen));
    expect(
      screen.height - micRect.bottom,
      greaterThanOrEqualTo(navInset + Spacing.xLarge),
      reason: 'a disc resting on the pill nav is the defect this pins',
    );
  });

  testWidgets('the create surface is tap-only', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    final data = tester
        .getSemantics(
          find.bySemanticsIdentifier('orders_create_request_button'),
        )
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(
      data.hasAction(SemanticsAction.longPress),
      isFalse,
      reason: 'the duplicate voice door on the create surface stays deleted',
    );
    handle.dispose();
  });

  testWidgets('the create surface routes through the host callback only', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        repo: InMemoryClientHomeRepository(latency: Duration.zero),
        onCreateRequest: (_) => taps += 1,
      ),
    );
    await tester.pumpAndSettle();

    final cta = find.bySemanticsIdentifier('orders_create_request_button');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    // The host owns the destination (`home_tab.dart` → `client-location`); a
    // button that navigated itself would leave this at zero.
    expect(taps, 1);
  });

  testWidgets('the floating mic keeps a >=48dp thumb target and holds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    final micSize = tester.getSize(find.byType(JeebMicHero));
    expect(micSize.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(micSize.height, greaterThanOrEqualTo(kMinInteractiveDimension));

    final mic = tester.widget<JeebMicHero>(find.byType(JeebMicHero));
    expect(mic.onPressStart, isNotNull);
    expect(mic.onPressEnd, isNotNull);
    expect(mic.onSlideCancel, isNotNull);
    expect(mic.onTap, isNull);
    expect(mic.onLongPress, isNull);
    expect(
      find.descendant(
        of: find.byType(JeebMicHero),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
      reason: 'a discrete tap would record a sub-second clip on every touch',
    );
  });

  testWidgets('the mic is operable by a screen reader, not pointer-only', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    // Hold and slide-to-cancel are raw pointer; touch exploration eats the
    // pointer stream, so a tap ACTION is the only assistive way in.
    final mic = tester.widget<JeebMicHero>(find.byType(JeebMicHero));
    expect(mic.onSemanticTap, isNotNull);
    expect(mic.semanticTapHint, isNotNull);

    final data = tester
        .getSemantics(find.bySemanticsIdentifier('client_home_mic_cta'))
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('the deleted caption leaves the hold gesture on the mic node', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('client-home-hold-hint')), findsNothing);
    expect(find.text('Or hold the mic to speak your order'), findsNothing);

    // The caption is gone, so the mic node is the surviving carrier for AT.
    final mic = tester.widget<JeebMicHero>(find.byType(JeebMicHero));
    expect(mic.semanticLabel, 'Hold to speak');
    expect(mic.semanticTapHint, isNotNull);
  });

  Finder heroCapsule() => find.descendant(
    of: find.byType(ClientHomeRequestHero),
    matching: find.byType(JeebGlassCard),
  );

  testWidgets('the create capsule is 48dp and carries no subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    expect(heroCapsule(), findsOneWidget);
    expect(tester.getSize(heroCapsule()).height, kMinInteractiveDimension);
    expect(find.text('Choose a delivery type and address'), findsNothing);
    expect(find.text('First order'), findsOneWidget);
    expect(
      find.descendant(of: heroCapsule(), matching: find.byType(Text)),
      findsOneWidget,
      reason: 'the single-line row is title-only now',
    );
  });

  testWidgets('the create capsule is pinned and never scrolls away', (
    tester,
  ) async {
    final repo = InMemoryClientHomeRepository.fromSnapshot(
      ClientHomeSnapshot(
        pending: <ClientHomeRequest>[
          for (var i = 0; i < 12; i++)
            ClientHomeRequest(
              id: 'pen-$i',
              title: 'ORD-$i',
              displayId: 'ORD-$i',
              destinationLabel: 'Achrafieh',
              itemsSummary: 'Groceries',
              status: ClientRequestStatus.searching,
              tier: ClientRequestTier.express,
            ),
        ],
      ),
      latency: Duration.zero,
    );
    await tester.pumpWidget(_harness(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(of: heroCapsule(), matching: find.byType(ListView)),
      findsNothing,
      reason: 'a create door inside the list is one the thumb can lose',
    );
    final firstCard = find.byKey(const Key('pending-countdown-card-pen-0'));
    final before = tester.getRect(heroCapsule());
    final cardBefore = tester.getRect(firstCard).top;
    await tester.drag(
      find.byKey(const Key('client-home-ready-list')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(firstCard).top, lessThan(cardBefore - 100));
    expect(tester.getRect(heroCapsule()), before);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode}: the pinned capsule shares the mic band',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            repo: InMemoryClientHomeRepository(latency: Duration.zero),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        final capsule = tester.getRect(heroCapsule());
        final disc = tester.getRect(find.byType(JeebMicHero));
        expect(
          capsule.center.dy,
          closeTo(disc.center.dy, 0.01),
          reason: 'the capsule must be centred ON the disc, not above it',
        );

        final bool ltr = locale.languageCode == 'en';
        // The disc's HIT box is the Ø56 core, centred in its reserved extent.
        final double discStart = ltr
            ? disc.center.dx - JeebMicHero.sizeCompact / 2
            : disc.center.dx + JeebMicHero.sizeCompact / 2;
        final double capsuleEnd = ltr ? capsule.right : capsule.left;
        expect(
          (discStart - capsuleEnd).abs(),
          closeTo(Spacing.small, 0.5),
          reason: 'the two doors read as one band only at a token-sized gap',
        );
        expect(capsule.height, kMinInteractiveDimension);
        // The gutter side is the reading START edge in both directions.
        final double gutter = ltr
            ? capsule.left
            : tester.getSize(find.byType(ClientHomeScreen)).width -
                  capsule.right;
        expect(gutter, Spacing.xLarge);
      },
    );
  }

  testWidgets('applying a filter moves neither capsule nor headline', (
    tester,
  ) async {
    final repo = InMemoryClientHomeRepository.fromSnapshot(
      const ClientHomeSnapshot(
        pending: <ClientHomeRequest>[
          ClientHomeRequest(
            id: 'pen-1',
            title: 'ORD-1',
            displayId: 'ORD-1',
            status: ClientRequestStatus.searching,
            destinationLabel: 'Hamra',
          ),
        ],
        replies: <ClientHomeRequest>[
          ClientHomeRequest(
            id: 'rep-1',
            title: 'ORD-2',
            displayId: 'ORD-2',
            status: ClientRequestStatus.offersReceived,
            destinationLabel: 'Hamra',
            offerCount: 2,
            offerAvatarUrls: <String>['a', 'b'],
          ),
        ],
      ),
      latency: Duration.zero,
    );
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(repo: repo));
    await tester.pumpAndSettle();

    // The time-of-day headline's own tagline — the en slogan; ar keeps its own.
    final tagline = find.text('Jeeb me anything');
    final taglineBefore = tester.getRect(tagline);
    final capsuleBefore = tester.getRect(heroCapsule());

    await tester.tap(find.bySemanticsIdentifier('orders_home_replies_tab'));
    await tester.pumpAndSettle();

    expect(
      tagline,
      findsOneWidget,
      reason: 'a filter tap used to vanish the headline with the capsule',
    );
    expect(tester.getRect(tagline), taglineBefore);
    expect(tester.getRect(heroCapsule()), capsuleBefore);
    expect(
      find.bySemanticsIdentifier('orders_create_request_button'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the capsule height is invariant across locale and width', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;

    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(heroCapsule()).height,
      kMinInteractiveDimension,
      reason: 'the S22 width used to wrap the subtitle to 74.82dp',
    );

    await tester.pumpWidget(
      _harness(
        repo: InMemoryClientHomeRepository(latency: Duration.zero),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(heroCapsule()).height,
      kMinInteractiveDimension,
      reason: 'Baloo line metrics used to push the Arabic capsule to 74.5dp',
    );
  });

  // Narrowing the capsule to the mic's band left ~150dp of text slot on a
  // 360dp phone. LAST in the file on purpose: `FontLoader` is process-wide, so
  // the real faces must not re-measure the geometry pins above.
  for (final (Locale locale, String label) in const <(Locale, String)>[
    (Locale('en'), 'First order'),
    (Locale('ar'), 'طلبك الأول'),
  ]) {
    for (final double width in const <double>[360, 384]) {
      for (final double scale in const <double>[1.0, 1.3]) {
        testWidgets(
          '${locale.languageCode} @${width.toInt()}dp ×$scale: the first-run '
          'title is not truncated',
          (tester) async {
            await tester.runAsync(loadCatalogCaptureFonts);
            addTearDown(tester.view.reset);
            tester.view.physicalSize = Size(width * 3, 800 * 3);
            tester.view.devicePixelRatio = 3;

            await tester.pumpWidget(
              _harness(
                repo: InMemoryClientHomeRepository(latency: Duration.zero),
                locale: locale,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            final RenderParagraph title = tester.renderObject<RenderParagraph>(
              find.text(label),
            );
            expect(
              title.didExceedMaxLines,
              isFalse,
              reason:
                  'the pinned capsule ellipsized its own label — the E1 title '
                  'must fit the slot the mic band leaves it',
            );
          },
        );
      }
    }
  }

  testWidgets('the pinned capsule is OPAQUE, not 10% white over the list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    final ThemeData theme = Theme.of(tester.element(heroCapsule()));
    final JeebSemanticColors glass = theme.extension<JeebSemanticColors>()!;
    final BoxDecoration fill = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: heroCapsule(),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((BoxDecoration d) => d.border != null);

    expect(
      fill.color!.a,
      1.0,
      reason:
          'card text under the pinned capsule used to read straight '
          'through it',
    );
    expect(
      fill.color,
      Color.alphaBlend(glass.glassFillEmphasis, theme.colorScheme.surface),
      reason:
          'the base is a theme token under the SAME glass fill, so the '
          'midnight look survives being made opaque',
    );
    // The rest of the §4 recipe is untouched.
    expect(fill.border, isNotNull);
    expect(fill.borderRadius, BorderRadius.circular(JeebRadii.capsule));
    expect(
      tester.widget<JeebGlassCard>(heroCapsule()).shadow,
      JeebShadows.overlay,
    );
  });

  testWidgets('the leading + glyph is gone and the run keeps its own band', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ClientHomeRequestHero),
        matching: find.byIcon(Icons.add),
      ),
      findsNothing,
      reason: 'the disc ate the width the hint needs',
    );
    // The whole capsule stays the one tappable create surface.
    expect(
      find.bySemanticsIdentifier('orders_create_request_button'),
      findsOneWidget,
    );
  });

  testWidgets('the hint rotates while the accessible name stays put', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_heroOnly());
    // NEVER pumpAndSettle here: the hint loops forever with motion on.
    await tester.pump();

    String label() => tester
        .getSemantics(
          find.bySemanticsIdentifier('orders_create_request_button'),
        )
        .getSemanticsData()
        .label;

    final String first = _capsuleRun(tester);
    expect(label(), 'Type it');

    await tester.pump(const Duration(milliseconds: 280));
    final String typed = _capsuleRun(tester);
    expect(typed.length, greaterThan(first.length));
    expect(typed, startsWith(first));
    expect(
      label(),
      'Type it',
      reason: 'Voice Control cannot say a run that has already been deleted',
    );

    // Past the first example's whole round, onto the second.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 30));
    expect(label(), 'Type it');
    expect(
      find.bySemanticsIdentifier('orders_create_request_button'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the first-run capsule animates the typed hints too', (
    tester,
  ) async {
    await tester.pumpWidget(_heroOnly(firstRequest: true));
    // NEVER pumpAndSettle: with motion on the hint loops forever.
    await tester.pump();

    expect(find.byType(ClientHomeTypedHint), findsOneWidget);
    final String first = _capsuleRun(tester);
    await tester.pump(const Duration(milliseconds: 280));
    expect(_capsuleRun(tester).length, greaterThan(first.length));
    expect(
      find.bySemanticsIdentifier('_request_empty_state_new_order_button'),
      findsOneWidget,
    );
  });

  testWidgets('the first-run capsule pins its title under reduce motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _heroOnly(firstRequest: true, disableAnimations: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('First order'), findsOneWidget);
    expect(find.byType(ClientHomeTypedHint), findsOneWidget);
  });

  testWidgets('reduce motion pins the stable label, not an example', (
    tester,
  ) async {
    await tester.pumpWidget(_heroOnly(disableAnimations: true));
    // No ticker under reduce motion, so the tree settles.
    await tester.pumpAndSettle();

    expect(find.text('Type it'), findsOneWidget);
    expect(find.text('2 kg of tomatoes'), findsNothing);
  });
}
