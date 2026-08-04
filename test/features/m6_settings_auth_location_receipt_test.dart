// MIDNIGHT M6 — settings / cancel_request / auth / location / delivery_receipt.
//
// Goldens are evidence, not gates (the comparator tolerates 5% pixel diff and a
// real ink swap once moved 0.097%), so every value this lane moved is read back
// off the built widget here. Each assertion was proved discriminating by
// reverting the production value and confirming red.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/map/jeeb_map_style.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/theme/jeeb_scrim.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/features/auth/social/social_collision_sheet.dart';
import 'package:jeeb_mobile/features/cancel_request/data/fake_cancel_request_repository.dart';
import 'package:jeeb_mobile/features/cancel_request/presentation/cancel_request_sheet.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/widgets/proof_photo_viewer.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/location_search_bar.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/google_map_capture_view.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/map_capture_controller.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/settings/domain/account_session_terminator.dart';

import '../support/sync_app_localizations.dart';

/// The pale periwinkle the pass-1 sheets barriered on: `onSecondaryContainer`
/// (`#B9C0F0`) at `opacityHigh`. Named so the L8 assertions can say what they
/// are ruling OUT, not merely what they expect.
final Color _kPass1Scrim =
    JeebMidnight.inkSoft.withValues(alpha: UIConstants.opacityHigh);

/// The one modal dim, resolved from the ratified theme rather than re-derived.
final Color _kBarrier = AppTheme.midnightScheme.scrim.withValues(
  alpha: JeebScrim.barrierAlpha,
);

class _NoopTerminator implements AccountSessionTerminator {
  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

Widget _harness(Widget home) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

/// Mounts a screen whose only job is to open [open] from a tap, so the barrier
/// is the REAL one `showModalBottomSheet` / `showGeneralDialog` installed.
class _Opener extends StatelessWidget {
  const _Opener(this.open);

  final void Function(BuildContext) open;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (inner) => Center(
          child: ElevatedButton(
            onPressed: () => open(inner),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

/// The colour the route actually installed behind the modal.
///
/// Read off `ModalBarrier.color` rather than off the call site: the call site
/// is the thing under test, and a `barrierColor:` that never reaches the route
/// (wrong overload, shadowed by a theme) would still pass a source-level check.
Color _barrierColor(WidgetTester tester) {
  final Iterable<ModalBarrier> barriers = tester
      .widgetList<ModalBarrier>(find.byType(ModalBarrier))
      .where((ModalBarrier b) => b.color != null);
  expect(barriers, isNotEmpty, reason: 'no coloured ModalBarrier was mounted');
  return barriers.last.color!;
}

Future<void> _openAndSettle(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  // ── L8 · the pale-periwinkle sheet scrim ────────────────────────────────
  //
  // `onSecondaryContainer` at 87% is `#B9C0F0` — under Midnight that veil
  // LIGHTENS the field instead of dimming it. All three sheets now defer to the
  // one app-wide decision (`JeebScrim`), so the dim is not re-picked per sheet.
  group('L8 — sheet scrim', () {
    testWidgets('cancel_request barriers on JeebScrim, not pale periwinkle',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Opener((BuildContext c) {
        CancelRequestSheet.show(
          c,
          requestId: 'req-1',
          repository: FakeCancelRequestRepository(),
        );
      })));
      await _openAndSettle(tester);

      final Color barrier = _barrierColor(tester);
      expect(barrier, _kBarrier);
      expect(barrier, isNot(_kPass1Scrim));
      // The defect in one line: the scrim must be DARKER than the page it
      // covers, never lighter.
      expect(barrier.computeLuminance(),
          lessThan(JeebMidnight.page.computeLuminance()));
      expect(_kPass1Scrim.computeLuminance(),
          greaterThan(JeebMidnight.page.computeLuminance()));
    });

    testWidgets('logout/delete barriers on JeebScrim',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Opener((BuildContext c) {
        LogoutDeleteConfirmSheet.show(
          c,
          mode: LogoutDeleteMode.logout,
          terminator: _NoopTerminator(),
        );
      })));
      await _openAndSettle(tester);

      expect(_barrierColor(tester), _kBarrier);
      expect(_barrierColor(tester), isNot(_kPass1Scrim));
    });

    testWidgets('social collision barriers on JeebScrim',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(const _Opener(showSocialCollisionSheet)));
      await _openAndSettle(tester);

      expect(_barrierColor(tester), _kBarrier);
      expect(_barrierColor(tester), isNot(_kPass1Scrim));
    });
  });

  // ── L11 · the opaque-black lightbox barrier ─────────────────────────────
  group('L11 — proof-photo lightbox', () {
    testWidgets('the barrier is a dim, not an opaque black slab',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Opener((BuildContext c) {
        showProofPhotoViewer(c, url: 'https://example.test/p.jpg',
            closeLabel: 'Close');
      })));
      // NOT pumpAndSettle: `OmdsCachedImage` spins a loading animation that
      // never settles behind the test HttpClient.
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final Color barrier = _barrierColor(tester);
      expect(barrier.a, JeebScrim.barrierAlpha,
          reason: 'a fully opaque barrier is a screen swap, not a lightbox');
      expect(barrier.a, lessThan(1.0));
    });
  });

  // ── L9 · OmdsSearchBar's hard-coded orange focus ring ───────────────────
  //
  // The ring is written into the widget's own `InputDecoration`, so
  // `app_theme`'s `inputDecorationTheme` can never reach it — only a scoped
  // re-point at the call site can. Same fix the jeeber feed lane landed.
  group('L9 — location search bar focus ring', () {
    testWidgets('focuses periwinkle, not orange', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(Scaffold(
        body: LocationSearchBar(
          hintText: 'Search',
          query: '',
          results: const <LocationPoint>[],
          isSearching: false,
          onChanged: (_) {},
          onResultSelected: (_) {},
        ),
      )));
      await tester.pumpAndSettle();

      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(OmdsSearchBar),
          matching: find.byType(TextField),
        ),
      );
      final Color ring =
          (field.decoration!.focusedBorder! as OutlineInputBorder)
              .borderSide
              .color;

      expect(ring, JeebMidnight.inkMuted);
      expect(ring, isNot(JeebMidnight.orange));
    });
  });

  // ── L10 · the light-default map flash ───────────────────────────────────
  //
  // `GoogleMap` paints its LIGHT default until a style JSON reaches it, and the
  // JSON is a `rootBundle` read. The process cache only covers the SECOND
  // mount; on the first one the white-and-beige rectangle is on screen for as
  // long as the read takes. A Midnight cover holds until the read settles —
  // including the failure path, where the cover must LIFT rather than strand a
  // navy rectangle over a working map.
  group('L10 — map style flash', () {
    setUp(JeebMapStyle.debugReset);
    tearDown(JeebMapStyle.debugReset);

    testWidgets('the first mount covers the map until the style settles',
        (WidgetTester tester) async {
      // Deliberately NOT followed by another pump: the bundle read resolves in
      // a microtask, so a second frame would already carry the settled style
      // and the race this guards would be invisible.
      await tester.pumpWidget(_harness(Scaffold(
        body: GoogleMapCaptureView(
          controller: MapCaptureController(
            initial: const LocationPoint(latitude: 33.89, longitude: 35.50),
          ),
        ),
      )));

      final Finder cover = find.byKey(mapStyleCoverKey);
      expect(cover, findsOneWidget,
          reason: 'the unstyled map was visible on the first frame');
      expect(
        tester.widget<ColoredBox>(
          find.descendant(of: cover, matching: find.byType(ColoredBox)),
        ).color,
        JeebMidnight.page,
      );

      // …and it must LIFT, or a working map ships under a navy rectangle.
      await tester.pumpAndSettle();
      expect(find.byKey(mapStyleCoverKey), findsNothing,
          reason: 'the cover must lift once the style read has settled');
    });
  });

  // ── Class 3b · cancel_request_sheet ─────────────────────────────────────
  group('3b — cancel request sheet', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(_harness(Scaffold(
        body: CancelRequestSheet(
          requestId: 'req-1',
          repository: FakeCancelRequestRepository(),
        ),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('the 6XL help glyph takes the info role, not the accent',
        (WidgetTester tester) async {
      await pump(tester);

      final Icon glyph = tester.widget<Icon>(
        find.byIcon(Icons.help_outline),
      );
      final JeebRoles roles =
          tester.element(find.byType(CancelRequestSheet)).jeebRoles;
      expect(glyph.color, roles.info);
      expect(glyph.color, JeebMidnight.inkMuted);
      expect(glyph.color, isNot(JeebMidnight.orange));
    });

    testWidgets('the drag handle takes the shared .22 glass rung',
        (WidgetTester tester) async {
      await pump(tester);

      // The handle is the sheet's only pill-shaped Container with a fixed
      // 32×4 box, so this cannot match the CTAs.
      final Iterable<Container> handles = tester
          .widgetList<Container>(find.byType(Container))
          .where((Container c) => c.constraints?.maxHeight == Spacing.twoXSmall);
      expect(handles, hasLength(1));
      final BoxDecoration box = handles.single.decoration! as BoxDecoration;

      expect(box.color, JeebSemanticColors.midnight().glassBorderVivid);
      expect(box.color, isNot(JeebMidnight.orange));
    });

    testWidgets('the keep CTA outlines periwinkle, not orange',
        (WidgetTester tester) async {
      await pump(tester);

      // `OmdsPrimaryButton.outlined` inks border AND label from
      // `colorScheme.primary`, so both are read.
      final BuildContext scoped = tester.element(
        find.descendant(
          of: find.byKey(const Key('cancel-request-keep-cta')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final ColorScheme scheme = Theme.of(scoped).colorScheme;
      expect(scheme.primary, JeebMidnight.inkMuted);
      expect(scheme.primary, isNot(JeebMidnight.orange));

      final AnimatedContainer pill = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('cancel-request-keep-cta')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final BoxDecoration box = pill.decoration! as BoxDecoration;
      expect(box.border!.top.color, JeebMidnight.inkMuted);
      expect(box.border!.top.color, isNot(JeebMidnight.orange));
    });

    testWidgets('the sheet paints the accent nowhere at all',
        (WidgetTester tester) async {
      await pump(tester);

      expect(
        tester
            .widgetList<Icon>(find.byType(Icon))
            .where((Icon i) => i.color == JeebMidnight.orange),
        isEmpty,
      );
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .where((Text t) => t.style?.color == JeebMidnight.orange),
        isEmpty,
      );
    });
  });

  // ── Class 3b · social_collision_sheet ───────────────────────────────────
  group('3b — social collision sheet', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(const Scaffold(body: SocialCollisionSheet())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the blocked-account glyph is the danger role',
        (WidgetTester tester) async {
      await pump(tester);

      final Icon glyph =
          tester.widget<Icon>(find.byIcon(Icons.person_off_outlined));
      expect(glyph.color, JeebMidnight.danger);
      expect(glyph.color, isNot(JeebMidnight.orange));
    });

    testWidgets('title and body carry explicit Midnight ink',
        (WidgetTester tester) async {
      await pump(tester);

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(SocialCollisionSheet)),
      );
      final Text title =
          tester.widget<Text>(find.text(l10n.registrationSocialCollisionTitle));
      final Text body =
          tester.widget<Text>(find.text(l10n.registrationSocialCollisionBody));

      expect(title.style?.color, JeebMidnight.ink);
      expect(body.style?.color, JeebMidnight.inkMuted);
    });
  });
}
