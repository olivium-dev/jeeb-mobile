// UX-39: a null repository reported `saved` for a PUT nobody issued, and
// `on Object` threw the classification away so every failure read alike.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/features/profile_name/application/display_name_cubit.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';
import 'package:jeeb_mobile/features/profile_name/presentation/display_name_setup_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _RejectingRepository implements DisplayNameRepository {
  const _RejectingRepository(this.failure);

  final DisplayNameFailure failure;

  @override
  Future<void> submitDisplayName(String name) async =>
      throw DisplayNameRepositoryException(failure);
}

/// Throws something the typed exception cannot express.
class _RawThrowingRepository implements DisplayNameRepository {
  const _RawThrowingRepository();

  @override
  Future<void> submitDisplayName(String name) async => throw DioException(
    requestOptions: RequestOptions(path: '/api/User/profile'),
    type: DioExceptionType.connectionError,
  );
}

void main() {
  test('a null repository is unavailable, never saved', () async {
    final DisplayNameCubit cubit = DisplayNameCubit();
    await cubit.submit('Ahmad');
    expect(cubit.state.status, DisplayNameStatus.unavailable);
    expect(cubit.state.status, isNot(DisplayNameStatus.saved));
    await cubit.close();
  });

  for (final DisplayNameFailure failure in DisplayNameFailure.values) {
    test('a thrown ${failure.name} is carried on the state', () async {
      final DisplayNameCubit cubit = DisplayNameCubit(
        repository: _RejectingRepository(failure),
      );
      await cubit.submit('Ahmad');
      expect(cubit.state.status, DisplayNameStatus.failure);
      expect(cubit.state.failure, failure);
      await cubit.close();
    });
  }

  test('an untyped throw is classified into appFailure', () async {
    final DisplayNameCubit cubit = DisplayNameCubit(
      repository: const _RawThrowingRepository(),
    );
    await cubit.submit('Ahmad');
    expect(cubit.state.status, DisplayNameStatus.failure);
    expect(cubit.state.failure, isNull);
    expect(cubit.state.appFailure, isA<NetworkFailure>());
    await cubit.close();
  });

  group('the screen copy', () {
    Future<AppLocalizations> pumpAfterSubmit(
      WidgetTester tester,
      DisplayNameCubit cubit,
      Locale locale,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          DisplayNameSetupScreen(cubit: cubit, onDone: () {}),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-name.field')),
        'Ahmad',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-name.submit')));
      await tester.pumpAndSettle();
      return AppLocalizations.of(
        tester.element(find.byType(DisplayNameSetupScreen)),
      );
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final String tag = locale.languageCode;

      for (final online in [true, false]) {
        testWidgets(
          'legacy name-save network failure follows reachability $online ($tag)',
          (tester) async {
            NetworkReachabilitySignals.instance.debugObserve(online: online);
            addTearDown(NetworkReachabilitySignals.debugReset);
            final cubit = DisplayNameCubit(
              repository: const _RejectingRepository(
                DisplayNameFailure.network,
              ),
            );
            addTearDown(cubit.close);
            final l10n = await pumpAfterSubmit(tester, cubit, locale);
            expect(
              find.bySemanticsIdentifier('profile_name_save_error_snack'),
              findsOneWidget,
            );
            expect(
              find.text(
                online ? l10n.errorUnreachableBody : l10n.errorNetworkBody,
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                online ? l10n.errorNetworkBody : l10n.errorUnreachableBody,
              ),
              findsNothing,
            );
          },
        );
      }

      testWidgets('an unauthorized save says sign in again ($tag)', (
        tester,
      ) async {
        final DisplayNameCubit cubit = DisplayNameCubit(
          repository: const _RejectingRepository(
            DisplayNameFailure.unauthorized,
          ),
        );
        addTearDown(cubit.close);
        final AppLocalizations l10n = await pumpAfterSubmit(
          tester,
          cubit,
          locale,
        );

        expect(
          find.bySemanticsIdentifier('profile_name_save_error_snack'),
          findsOneWidget,
        );
        expect(find.text(l10n.displayNameErrorUnauthorized), findsOneWidget);
        expect(find.text(l10n.profileNameStepError), findsNothing);
      });

      testWidgets('a 5xx says server, not connection ($tag)', (tester) async {
        final DisplayNameCubit cubit = DisplayNameCubit(
          repository: const _RejectingRepository(
            DisplayNameFailure.serverError,
          ),
        );
        addTearDown(cubit.close);
        final AppLocalizations l10n = await pumpAfterSubmit(
          tester,
          cubit,
          locale,
        );

        expect(find.text(l10n.errorServerBody), findsOneWidget);
        expect(find.text(l10n.errorNetworkBody), findsNothing);
      });
    }

    testWidgets('an unavailable step never reports a save', (tester) async {
      final DisplayNameCubit cubit = DisplayNameCubit();
      addTearDown(cubit.close);
      var done = 0;
      await tester.pumpWidget(
        wrapForTest(DisplayNameSetupScreen(cubit: cubit, onDone: () => done++)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-name.field')),
        'Ahmad',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-name.submit')));
      await tester.pumpAndSettle();

      expect(done, 0);
      expect(
        find.bySemanticsIdentifier('profile_name_save_error_snack'),
        findsOneWidget,
      );
    });
  });
}
