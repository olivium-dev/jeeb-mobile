import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

const _searchQuery = 'lane-a33';
const _exactRequestId = 'exact-first-character-match';
const _droppedRequestId = 'dropped-first-character-decoy';

DeliveryRequest _request({required String id, required String senderName}) {
  return DeliveryRequest(
    id: id,
    pickup: const RequestLocation(
      label: 'Pickup',
      latitude: 33.8,
      longitude: 35.5,
    ),
    dropoff: const RequestLocation(
      label: 'Dropoff',
      latitude: 33.9,
      longitude: 35.6,
    ),
    tier: JeeberRequestTier.flash,
    estimatedDistanceKm: 1.2,
    potentialEarnings: 5,
    currency: 'USD',
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    senderName: senderName,
  );
}

/// Pumps the board and opens the filter sheet, returning the sheet's search
/// field. Search is a facet of the sheet now — the board carries no input.
Future<Finder> _pumpFeedAndOpenSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ticker = StreamController<DateTime>.broadcast();
  addTearDown(ticker.close);
  final availabilityCubit = AvailabilityCubit(
    gateway: InMemoryAvailabilityGateway(
      initial: AvailabilityStatus.initial.copyWith(
        state: AvailabilityState.online,
      ),
    ),
    tickerFactory: () => ticker.stream,
  );
  addTearDown(availabilityCubit.close);
  final feedCubit = RequestFeedCubit(
    repository: SeededRequestFeedRepository([
      _request(id: _exactRequestId, senderName: _searchQuery),
      _request(id: _droppedRequestId, senderName: 'ane-a33'),
    ]),
  );
  addTearDown(feedCubit.close);

  await availabilityCubit.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<AvailabilityCubit>.value(value: availabilityCubit),
            BlocProvider<RequestFeedCubit>.value(value: feedCubit),
          ],
          child: const JeeberFeedTabView(),
        ),
      ),
    ),
  );
  await feedCubit.refresh();
  await tester.pumpAndSettle();

  await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_open'));
  await tester.pumpAndSettle();

  return find.descendant(
    of: find.byKey(JeeberFeedTabView.searchBarKey),
    matching: find.byType(EditableText),
  );
}

/// The query staged in the sheet reaches the feed intact once Apply commits.
Future<void> _applyAndExpectNarrowedFeed(
  WidgetTester tester,
  Finder editableText,
) async {
  final editable = editableText.evaluate().single.widget as EditableText;
  expect(editable.controller.text, _searchQuery);

  await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_apply'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('jeeber-feed-card-$_exactRequestId')), findsOne);
  expect(
    find.byKey(const Key('jeeber-feed-card-$_droppedRequestId')),
    findsNothing,
  );
  expect(
    find.bySemanticsIdentifier('jeeber_feed_filter_pill_query'),
    findsOneWidget,
  );
}

Future<void> _typeThroughIme(WidgetTester tester, Finder editableText) async {
  const keys = [
    LogicalKeyboardKey.keyL,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyN,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.minus,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit3,
  ];
  final initialEditable = editableText.evaluate().single.widget as EditableText;
  final initialController = initialEditable.controller;
  final initialFocusNode = initialEditable.focusNode;
  await tester.showKeyboard(editableText);
  for (var index = 0; index < keys.length; index += 1) {
    await tester.sendKeyEvent(keys[index]);
    final value = _searchQuery.substring(0, index + 1);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ),
    );
    await tester.pump();
    final rebuiltEditable =
        editableText.evaluate().single.widget as EditableText;
    expect(rebuiltEditable.controller, same(initialController));
    expect(rebuiltEditable.focusNode, same(initialFocusNode));
  }
}

void main() {
  group('Jeeber feed search facet', () {
    testWidgets('enterText preserves the first character through staging', (
      tester,
    ) async {
      final editableText = await _pumpFeedAndOpenSheet(tester);

      await tester.enterText(editableText, _searchQuery);
      await tester.pump();

      // Staged only: nothing reaches the feed before Apply.
      expect(
        find.byKey(
          const Key('jeeber-feed-card-$_droppedRequestId'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await _applyAndExpectNarrowedFeed(tester, editableText);
    });

    testWidgets('IME key sequence preserves the first character on rebuild', (
      tester,
    ) async {
      final editableText = await _pumpFeedAndOpenSheet(tester);

      await _typeThroughIme(tester, editableText);

      await _applyAndExpectNarrowedFeed(tester, editableText);
    });

    testWidgets('the query pill ✕ restores the unfiltered feed', (
      tester,
    ) async {
      final editableText = await _pumpFeedAndOpenSheet(tester);

      await tester.enterText(editableText, _searchQuery);
      await tester.pump();
      await _applyAndExpectNarrowedFeed(tester, editableText);

      await tester.tap(
        find.bySemanticsIdentifier('jeeber_feed_filter_pill_query_clear'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_filter_pill_query'),
        findsNothing,
      );
      expect(
        find.byKey(const Key('jeeber-feed-card-$_droppedRequestId')),
        findsOneWidget,
      );
    });
  });
}
