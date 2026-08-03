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

Future<Finder> _pumpFeed(WidgetTester tester) async {
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

  // C8 (redesign-2026-08): the search field is collapsed behind the magnifier
  // at rest. Reveal it before the input contract is exercised — the field, its
  // key and its `jeeber_feed_search_field` identifier are unchanged.
  await tester.tap(find.bySemanticsIdentifier('jeeber_feed_search_toggle'));
  await tester.pumpAndSettle();

  return find.descendant(
    of: find.byKey(JeeberFeedTabView.searchBarKey),
    matching: find.byType(EditableText),
  );
}

void _expectFullQueryReachedHandler(Finder editableText) {
  final editable = editableText.evaluate().single.widget as EditableText;
  expect(editable.controller.text, _searchQuery);
  expect(find.byKey(const Key('jeeber-feed-card-$_exactRequestId')), findsOne);
  expect(
    find.byKey(const Key('jeeber-feed-card-$_droppedRequestId')),
    findsNothing,
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
  group('Jeeber feed search input', () {
    testWidgets('enterText preserves the first character through filtering', (
      tester,
    ) async {
      final editableText = await _pumpFeed(tester);

      await tester.enterText(editableText, _searchQuery);
      await tester.pump();

      _expectFullQueryReachedHandler(editableText);
    });

    testWidgets('IME key sequence preserves the first character on rebuild', (
      tester,
    ) async {
      final editableText = await _pumpFeed(tester);

      await _typeThroughIme(tester, editableText);

      _expectFullQueryReachedHandler(editableText);
    });
  });
}
