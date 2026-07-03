// Widget tests for ClientHomeGreeting (P0-X06). Proves the personalized
// greeting:
//   - falls back to "Welcome back" + a "?" initials avatar with no ambient
//     GreetingProfileCubit and no name (preserving the prior contract);
//   - renders "Hello, {first name}" + the real avatar URL when an ambient
//     GreetingProfileCubit carries a live profile.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_greeting.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

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

Widget _harness({String? name, GreetingProfileState? profile}) {
  final child = ClientHomeGreeting(name: name, onAddPressed: () {});
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: profile == null
          ? child
          : BlocProvider<GreetingProfileCubit>(
              create: (_) => GreetingProfileCubit(seed: profile),
              child: child,
            ),
    ),
  );
}

OmdsProfileAvatar _avatar(WidgetTester tester) =>
    tester.widget<OmdsProfileAvatar>(
      find.byKey(const Key('client-home-greeting-avatar')),
    );

void main() {
  setUpAll(_loadArbs);

  group('ClientHomeGreeting (P0-X06)', () {
    testWidgets(
      'no ambient profile + null name → "Welcome back" + "?" avatar',
      (tester) async {
        await tester.pumpWidget(_harness());
        await tester.pumpAndSettle();

        expect(find.text('Welcome back'), findsOneWidget);
        expect(_avatar(tester).initial, '?');
        expect(_avatar(tester).profilePicUrl, isNull);
      },
    );

    testWidgets('cubit-fed name + avatar override the placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          profile: const GreetingProfileState(
            name: 'Sami Fawaz',
            avatarUrl: 'https://cdn/avatar.png',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First name only, and the real avatar URL (not "?").
      expect(find.text('Hello, Sami'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      expect(_avatar(tester).initial, 'S');
      expect(_avatar(tester).profilePicUrl, 'https://cdn/avatar.png');
    });

    testWidgets('ambient profile name wins over the passed name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          name: 'Stale',
          profile: const GreetingProfileState(name: 'Layla'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello, Layla'), findsOneWidget);
      expect(find.text('Hello, Stale'), findsNothing);
    });

    testWidgets(
      'synthetic jeeb-<hash> handle is suppressed → generic greeting (audit §T5)',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            profile: const GreetingProfileState(name: 'jeeb-e1a35ea8a520'),
          ),
        );
        await tester.pumpAndSettle();

        // The raw account handle must NOT appear anywhere on the header, and the
        // greeting degrades to the generic fallback + "?" avatar.
        expect(find.textContaining('jeeb-e1a35ea8a520'), findsNothing);
        expect(find.text('Welcome back'), findsOneWidget);
        expect(_avatar(tester).initial, '?');
      },
    );

    testWidgets(
      'internal @jeeb.internal email is suppressed → generic greeting',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            profile: const GreetingProfileState(
              name: 'phone-only+cb39e21caa82@jeeb.internal',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('@jeeb.internal'), findsNothing);
        expect(find.text('Welcome back'), findsOneWidget);
      },
    );

    testWidgets(
      'saved display name from the getMe re-pull greets "Hello, Ahmad" '
      '(profile-name lane: displayNameOrNull accepts a real name)',
      (tester) async {
        // The post-save state: the gateway mirrored PUT /api/User/profile
        // `username` into the projection, getMe returned "Ahmad", and the
        // greeting cubit re-pulled it. The suppression predicate must let a
        // real human name through — it only suppresses synthetic handles.
        await tester.pumpWidget(
          _harness(profile: const GreetingProfileState(name: 'Ahmad')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hello, Ahmad'), findsOneWidget);
        expect(find.text('Welcome back'), findsNothing);
        expect(_avatar(tester).initial, 'A');
      },
    );
  });
}
