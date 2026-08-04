// MIDNIGHT · M3-44 — the row's finding, pinned: `DevChatPreviewScreen` is a
// debug-only fixture HOST for M2-16's `ChatScreen`, so this row ships no diff.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/dev_chat_preview_screen_fixtures.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/dev_chat_preview_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Chrome the host must never grow: every pixel is the delegate's to own.
const List<Type> _forbiddenBetween = <Type>[
  JeebMidnightField,
  ChatAppBar,
  Scaffold,
  AppBar,
  DecoratedBox,
  ColoredBox,
  Padding,
  SafeArea,
];

Widget _harness(String selector) {
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
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: DevChatPreviewScreen(selector: selector),
  );
}

/// The widget types mounted strictly between the host and its delegate.
List<Type> _chainBetween(WidgetTester tester) {
  final chain = <Type>[];
  var reachedHost = false;
  tester.element(find.byType(ChatScreen)).visitAncestorElements((element) {
    if (element.widget is DevChatPreviewScreen) {
      reachedHost = true;
      return false;
    }
    chain.add(element.widget.runtimeType);
    return true;
  });
  expect(
    reachedHost,
    isTrue,
    reason: 'the delegate must be mounted BY the host, not beside it',
  );
  return chain;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  const List<String> clientSelectors = <String>[
    DevChatPreviewScreenPreviewFixtures.clientSending,
    DevChatPreviewScreenPreviewFixtures.clientBroadcasting,
    DevChatPreviewScreenPreviewFixtures.clientAccepted,
    DevChatPreviewScreenPreviewFixtures.unrecognised,
  ];
  const List<String> jeeberSelectors = <String>[
    DevChatPreviewScreenPreviewFixtures.jeeberAccepted,
    DevChatPreviewScreenPreviewFixtures.jeeberOrderPicked,
  ];

  for (final String selector in <String>[...clientSelectors, ...jeeberSelectors]) {
    testWidgets('"$selector" renders the real chat surface', (tester) async {
      await tester.pumpWidget(_harness(selector));
      await _settle(tester);

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(
        find.byType(JeebMidnightField),
        findsOneWidget,
        reason: 'the delegate owns the one Midnight field; a second one means '
            'the dev host started painting',
      );
      expect(find.byType(ChatAppBar), findsOneWidget);
    });
  }

  for (final String selector in clientSelectors) {
    testWidgets('"$selector" adds no chrome between host and delegate', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(selector));
      await _settle(tester);

      expect(
        _chainBetween(tester),
        isEmpty,
        reason: 'the client leg is a direct build; anything between it and '
            "ChatScreen is chrome M2-16 already owns",
      );
    });
  }

  for (final String selector in jeeberSelectors) {
    testWidgets('"$selector" adds no chrome between host and delegate', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(selector));
      await _settle(tester);

      final chain = _chainBetween(tester);
      for (final Type forbidden in _forbiddenBetween) {
        expect(
          chain,
          isNot(contains(forbidden)),
          reason: '$forbidden between the host and the delegate would double '
              "M2-16's chrome",
        );
      }
      expect(
        chain,
        hasLength(1),
        reason: 'the jeeber leg carries exactly ONE stateful host (it schedules '
            'the confirm sheet); a second layer is a surface of its own',
      );
    });
  }

  testWidgets('the host spends none of the orange budget itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(DevChatPreviewScreenPreviewFixtures.clientAccepted),
    );
    await _settle(tester);

    final Element host = tester.element(find.byType(DevChatPreviewScreen));
    final List<Widget> owned = <Widget>[];
    void collect(Element element) {
      if (element.widget is ChatScreen) return;
      owned.add(element.widget);
      element.visitChildren(collect);
    }

    host.visitChildren(collect);
    expect(
      owned,
      isEmpty,
      reason: 'a debug host that draws its own ink can leak orange into a '
          'surface whose budget M2-16 already balanced',
    );
  });
}
