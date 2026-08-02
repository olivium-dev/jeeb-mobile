import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Repository that returns ONE in-progress order on the first pull and TWO on
/// every subsequent pull, while counting calls. Lets us prove a tab-refocus
/// re-pulls (call #2) and that the freshly-accepted order surfaces.
class _SequencedRepo implements ClientHomeRepository {
  int calls = 0;

  static const _orderA = ClientHomeRequest(
    id: 'ip-1',
    title: 'Kamal Hajj',
    destinationLabel: '1 kilo potato',
    status: ClientRequestStatus.enRoute,
    tier: ClientRequestTier.flash,
    progressStep: 3,
  );

  // The order that becomes active only after the client accepts an offer —
  static const _orderB = ClientHomeRequest(
    id: 'ip-2',
    title: 'Nadia Saab',
    destinationLabel: 'Pharmacy run',
    status: ClientRequestStatus.accepted,
    tier: ClientRequestTier.express,
    progressStep: 1,
  );

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    calls += 1;
    return ClientHomeSnapshot(
      inProgress: calls == 1
          ? const [_orderA]
          : const [_orderA, _orderB],
    );
  }
}

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

/// Hosts [ClientHomeScreen] under a controllable [TabVisibility] whose
/// `isVisible` is driven by [visible]. The [BlocProvider] sits ABOVE the
Widget _harness({
  required ClientHomeRepository repo,
  required ValueListenable<bool> visible,
}) {
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
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        ),
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          // JEBV4-298: the In-Progress live-tracking list was relocated off
          builder: (_, isVisible, _) => TabVisibility(
            isVisible: isVisible,
            child: const ClientHomeScreen(
              initialTab: ClientHomeTab.inProgress,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadArbs);

  group('ClientHomeScreen auto-refresh on Requests tab refocus (S13)', () {
    testWidgets(
        're-pulls the In-Progress source when the tab regains focus so a '
        'newly-accepted order appears without a manual pull-to-refresh',
        (tester) async {
      final repo = _SequencedRepo();
      final visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);

      await tester.pumpWidget(_harness(repo: repo, visible: visible));
      await tester.pumpAndSettle();

      // First load (initState) shows only the original active order.
      expect(repo.calls, 1);
      expect(find.text('Kamal Hajj'), findsOneWidget);
      expect(find.text('Nadia Saab'), findsNothing);

      // User leaves the Requests tab (e.g. taps an offer to accept it)...
      visible.value = false;
      await tester.pumpAndSettle();

      // ...and returns to Requests. Re-focusing must silently re-pull.
      visible.value = true;
      await tester.pumpAndSettle();

      // The tab re-fetched (call #2) and the freshly-accepted order is shown,
      expect(repo.calls, 2);
      expect(find.text('Kamal Hajj'), findsOneWidget);
      expect(find.text('Nadia Saab'), findsOneWidget);
    });

    testWidgets(
        'the refocus re-pull is a background refresh — the list never blanks '
        'to a full-screen loader and the existing card stays on screen',
        (tester) async {
      final repo = _SequencedRepo();
      final visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);

      await tester.pumpWidget(_harness(repo: repo, visible: visible));
      await tester.pumpAndSettle();

      ClientHomeCubit cubit() => tester
          .element(find.byType(ClientHomeScreen))
          .read<ClientHomeCubit>();

      expect(cubit().state.status, ClientHomeStatus.ready);

      visible.value = false;
      await tester.pumpAndSettle();
      visible.value = true;

      // Drive frames one at a time across the in-flight refresh and assert the
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        expect(cubit().state.status, ClientHomeStatus.ready);
        // Prior data stays painted throughout the refresh.
        expect(find.text('Kamal Hajj'), findsOneWidget);
      }
      await tester.pumpAndSettle();

      expect(repo.calls, 2);
      expect(find.text('Nadia Saab'), findsOneWidget);
    });
  });
}
