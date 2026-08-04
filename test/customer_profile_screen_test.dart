import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_status_block.dart';
import 'package:jeeb_mobile/features/rate_app/domain/app_review_launcher.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Recording [AppReviewLauncher] double — JM-064 test seam. Counts how many
/// times the Rate-app row asked the OS for a store-review sheet, without
/// touching any platform plugin.
class _RecordingAppReviewLauncher implements AppReviewLauncher {
  int requestCount = 0;

  @override
  Future<void> requestReview() async {
    requestCount++;
  }
}

/// Synchronous ARB-backed localizations delegate so widget tests render the
/// real strings without hitting the asset bundle.
class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) =>
      _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

// A rated, verified, not-yet-Jeeber customer.
const _ratedCustomer = CustomerProfileViewData(
  name: 'Sami Fawaz',
  email: 'kamalhaaj@gmail.com',
  isVerified: true,
  rating: 4.8,
  ratingCount: 42,
);

// An unrated customer (the seeded `user-client-001` carries no rating) — the
const _unratedCustomer = CustomerProfileViewData(
  name: 'Nadia Client',
  isVerified: true,
);

const _jeeberCustomer = CustomerProfileViewData(
  name: 'Kamal Hajj',
  isJeeber: true,
  rating: 4.9,
  ratingCount: 312,
);

/// No GoRouter is provided: the screen runs in fixture-only mode (GetIt is not
/// configured under test, so no live `getMe` fires), and the tests assert on
Widget _harness({
  CustomerProfileViewData data = _ratedCustomer,
  Locale locale = const Locale('en'),
  AppReviewLauncher? reviewLauncher,
  CustomerProfileRepository? repository,
}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: CustomerProfileScreen(
      data: data,
      reviewLauncher: reviewLauncher,
      repository: repository,
    ),
  );
}

/// A `getMe` that never lands — holds the cubit on `loading`.
class _PendingRepository implements CustomerProfileRepository {
  @override
  Future<CustomerProfileViewData> fetchProfile() =>
      Completer<CustomerProfileViewData>().future;
}

/// A `getMe` that fails, then succeeds on the retry.
class _FailThenSucceedRepository implements CustomerProfileRepository {
  int calls = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    calls++;
    if (calls == 1) {
      throw const CustomerProfileRepositoryException(
        CustomerProfileFailure.network,
      );
    }
    return _ratedCustomer;
  }
}

/// Router-backed harness for the row-navigation assertions. The profile rows
/// (password / language / contact / addresses) now `goNamed`/`pushNamed` REAL
Widget _stubRoot(String id) => Semantics(
      identifier: id,
      container: true,
      child: const Scaffold(body: SizedBox.expand()),
    );

Widget _routerHarness({
  CustomerProfileViewData data = _ratedCustomer,
  Locale locale = const Locale('en'),
}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => CustomerProfileScreen(data: data),
      ),
      GoRoute(
        path: '/password-security',
        name: 'password-security',
        builder: (context, state) => _stubRoot('password_security_root'),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.midnight(),
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(440 * 3, 1400 * 3);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('CustomerProfileScreen (JM-035)', () {
    testWidgets('renders identity (name) for a customer', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(find.text('Sami Fawaz'), findsOneWidget);
      expect(find.text('kamalhaaj@gmail.com'), findsOneWidget);
    });

    testWidgets('shows the Register pill for a non-Jeeber customer',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('hides the Register row once the customer is a Jeeber',
        (tester) async {
      await tester.pumpWidget(_harness(data: _jeeberCustomer));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('customer_profile_register_delivery_row'),
        findsNothing,
      );
      expect(find.text('Register'), findsNothing);
    });

    testWidgets(
        'exposes the EXACT JM-035 Semantics identifiers on header + every row',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // §2.15 contract — header (wallet chip + bell are shell-owned, NOT here).
      for (final id in const [
        'customer_profile_avatar',
        'customer_profile_name',
        'customer_profile_rating',
        'customer_profile_register_delivery_row',
        'customer_profile_password_row',
        'customer_profile_notifications_row',
        'customer_profile_language_row',
        'customer_profile_contact_row',
        'customer_profile_rate_app_row',
        'customer_profile_logout_row',
        'customer_profile_addresses_row',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      handle.dispose();
    });

    testWidgets(
        'rating chip renders (with its id) for an unrated customer too',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(data: _unratedCustomer));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('customer_profile_rating'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('does NOT render the shell-owned wallet chip / bell ids',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      // These are painted by ShellHeaderActions (the shell), never by the
      expect(
        find.bySemanticsIdentifier('customer_profile_wallet_chip'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('customer_profile_bell'),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets(
        'password row navigates to the registered password-security route',
        (tester) async {
      // W3/W4 cross-wave: password-security now EXISTS and is registered, so the
      await tester.pumpWidget(_routerHarness());
      await tester.pumpAndSettle();

      // The tab root hosts the row before the tap.
      expect(find.byKey(CustomerProfileScreen.rootKey), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('customer_profile_password_row'),
      );
      await tester.pumpAndSettle();

      // Navigated honestly to the registered password-security screen — never an
      expect(
        find.bySemanticsIdentifier('password_security_root'),
        findsOneWidget,
      );
    });

    testWidgets(
        'rate-app row invokes the native review launcher + keeps the tab root '
        'alive (JM-064)', (tester) async {
      final launcher = _RecordingAppReviewLauncher();
      await tester.pumpWidget(_harness(reviewLauncher: launcher));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('customer_profile_rate_app_row'),
      );
      await tester.pump(); // let the fire-and-forget request resolve

      // The OS store-review sheet was requested exactly once (JM-064 AC).
      expect(launcher.requestCount, 1);
      // Returns to Profile — the tab root survives (no route, no crash; AP-9).
      expect(find.byKey(CustomerProfileScreen.rootKey), findsOneWidget);
    });

    testWidgets('renders mirrored Arabic strings under ar locale',
        (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('الحساب'), findsOneWidget); // Account section header
      expect(find.text('الدعم'), findsOneWidget); // Support section header
      expect(
        Directionality.of(
          tester.element(find.byKey(CustomerProfileScreen.rootKey)),
        ),
        TextDirection.rtl,
      );
    });
  });

  // MIDNIGHT M3-07. Per-element reads, NOT goldens: the capture comparator
  // tolerates 5% pixel diff, so a token re-point on a small element passes a
  // golden unchanged.
  group('CustomerProfileScreen — MIDNIGHT M3-07 adoption', () {
    testWidgets('mounts the still content field with R22\'s top-end glow',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R22 declares no periwinkle, and it is board-still.
      expect(field.washPlacement, isNull);
      expect(field.animateDecor, isFalse);
      // The field must be visible: a painted Scaffold would cover it.
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
    });

    testWidgets('identity card is R22 geometry with NO lift', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final card = tester.widget<JeebNavySurfaceCard>(
        find.byType(JeebNavySurfaceCard).first,
      );
      expect(card.radius, JeebRadii.lg);
      expect(card.shadow, isEmpty, reason: 'theme ruling 1 retires ctaNavy');
      expect(
        card.padding,
        const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 15),
      );
    });

    testWidgets('name ink is onSurface (#EDEFFC), never onPrimary (#FFFFFF)',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final scheme = AppTheme.midnight().colorScheme;
      final nameStyle = tester.widget<Text>(find.text('Sami Fawaz')).style!;
      expect(nameStyle.color, scheme.onSurface);
      expect(nameStyle.color, isNot(scheme.onPrimary));
    });

    testWidgets('an earned rating star is amber', (tester) async {
      final semantics = AppTheme.midnight().extension<JeebSemanticColors>()!;
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final star = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
      expect(star.color, semantics.amber);
      expect(star.color, isNot(semantics.mutedText));
    });

    testWidgets('an unearned rating star stays muted, never a dim amber',
        (tester) async {
      final semantics = AppTheme.midnight().extension<JeebSemanticColors>()!;
      await tester.pumpWidget(_harness(data: _unratedCustomer));
      await tester.pumpAndSettle();

      final star = tester.widget<Icon>(find.byIcon(Icons.star_border_rounded));
      expect(star.color, semantics.mutedText);
      expect(star.color, isNot(semantics.amber));
    });

    testWidgets('the one lit frame carries R22\'s accentTint fill',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final frame = tester.widget<JeebAccentFrameCard>(
        find.byType(JeebAccentFrameCard),
      );
      expect(frame.fill, JeebAccentFrameFill.accentTint);
    });

    testWidgets('an account with no name gets the dormant disc, not a fake '
        'initial', (tester) async {
      await tester.pumpWidget(_harness(data: const CustomerProfileViewData()));
      await tester.pumpAndSettle();

      final avatar = tester.widget<JeebAvatar>(find.byType(JeebAvatar));
      expect(avatar.fill, JeebAvatarFill.dormant);
      // R22's twin ships the same placeholder for the same null.
      expect(find.text('Add your name'), findsOneWidget);
    });

    testWidgets('the list reserves the floating pill nav inset', (tester) async {
      const navInset = 48.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: navInset),
          ),
          child: _harness(),
        ),
      );
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(
        find.byKey(CustomerProfileScreen.rootKey),
      );
      expect(
        list.padding,
        const EdgeInsetsDirectional.fromSTEB(24, 56, 24, 32 + navInset),
      );
    });

    testWidgets('a read in flight draws the radar loading block, keeping the '
        'identity ids and every row', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _harness(
          data: const CustomerProfileViewData(),
          repository: _PendingRepository(),
        ),
      );
      await tester.pump();

      final block = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(block.variant, JeebEmptyStateVariant.radar);
      expect(block.status, JeebEmptyStateStatus.loading);
      expect(block.compact, isTrue);
      // Signing out has to survive a read that never lands.
      expect(
        find.bySemanticsIdentifier('customer_profile_logout_row'),
        findsOneWidget,
      );
      for (final id in const [
        'customer_profile_avatar',
        'customer_profile_name',
        'customer_profile_rating',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      handle.dispose();
    });

    testWidgets('a failed read draws the danger-tinted block and its Retry '
        're-runs the fetch', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final repository = _FailThenSucceedRepository();

      await tester.pumpWidget(
        _harness(
          data: const CustomerProfileViewData(),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      final block = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(block.variant, JeebEmptyStateVariant.radar);
      expect(block.status, JeebEmptyStateStatus.error);
      expect(repository.calls, 1);

      await tester.tap(
        find.bySemanticsIdentifier(CustomerProfileStatusBlock.retryIdentifier),
      );
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.byType(JeebEmptyState), findsNothing);
      expect(find.text('Sami Fawaz'), findsOneWidget);
    });

    testWidgets('a resolved profile draws no state block', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(find.byType(JeebEmptyState), findsNothing);
    });
  });
}
