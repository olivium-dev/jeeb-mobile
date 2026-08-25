// Role-aware entry-point guard for ChatDetailScreen (jeeber active-delivery

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/chat/data/dev_chat_fixture_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

const _ctaKey = Key('chat-start-active-delivery-cta');

Widget _host(
  RoleCubit role,
  DevChatFixtureGateway gateway, {
  String? statusId = 'Ordered',
}) => MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<RoleCubit>.value(
    // ChatDetailScreen reads RoleCubit via context.read; provide a real one
    value: role,
    child: ChatDetailScreen(
      chatId: 'pen-1',
      debugGateway: gateway,
      debugPhase: ConversationPhase.accepted,
      debugHasWinner: true,
      debugSummary: statusId == null
          ? null
          : OrderChatSummary(
              deliveryId: 'delivery-1',
              requestId: 'request-1',
              statusId: statusId,
            ),
    ),
  ),
);

Future<RoleCubit> _roleCubit(UserRole role) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: role);
}

void main() {
  // b02: the pinned header's expand choice is SESSION state and widget
  setUp(ChatHeaderExpansionStore.instance.reset);
  assert(kDebugMode, 'dev-seam role-aware tests must run in debug');

  setUp(() {
    // Drive the seam exactly as the Maestro flow / fixture test does so
    DevSeam.debugOverride(const DevSeamConfig(route: '/', homeTab: 'pending'));
  });

  tearDown(DevSeam.debugReset);

  group('ChatDetailScreen — role-aware Start delivery wiring', () {
    testWidgets(
      'jeeber role: ChatScreen.onStartActiveDelivery is wired and CTA renders',
      (tester) async {
        final role = await _roleCubit(UserRole.jeeber);
        addTearDown(role.close);
        final gateway = DevChatFixtureGateway(
          phase: ConversationPhase.accepted,
          deliveryMan: true,
        );
        addTearDown(gateway.dispose);

        await tester.pumpWidget(_host(role, gateway));
        await tester.pumpAndSettle();

        // The constructed ChatScreen carries the non-null callback (the wiring
        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        expect(
          chatScreen.onStartActiveDelivery,
          isNotNull,
          reason: 'jeeber must receive the active-delivery entry point',
        );

        // And the accepted-phase banner actually surfaces the CTA to the user.
        expect(find.byKey(_ctaKey), findsOneWidget);
        final semantics = tester.getSemantics(find.byKey(_ctaKey));
        expect(semantics.identifier, 'chat_start_active_delivery_cta');
        expect(find.bySemanticsIdentifier('chat_detail_root'), findsOneWidget);
      },
    );

    testWidgets(
      'client role: onStartActiveDelivery is null and the CTA is absent',
      (tester) async {
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);
        final gateway = DevChatFixtureGateway(
          phase: ConversationPhase.accepted,
        );
        addTearDown(gateway.dispose);

        await tester.pumpWidget(_host(role, gateway));
        await tester.pumpAndSettle();

        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        expect(
          chatScreen.onStartActiveDelivery,
          isNull,
          reason: 'client never starts a delivery — CTA must be hidden',
        );
        expect(find.byKey(_ctaKey), findsNothing);
        expect(find.bySemanticsIdentifier('order_chat_root'), findsOneWidget);
      },
    );

    for (final status in <String?>['AtDoor', 'Done', 'Cancelled', null]) {
      testWidgets(
        'jeeber status $status fails closed and hides Start delivery',
        (tester) async {
          final role = await _roleCubit(UserRole.jeeber);
          addTearDown(role.close);
          final gateway = DevChatFixtureGateway(
            phase: ConversationPhase.accepted,
            deliveryMan: true,
          );
          addTearDown(gateway.dispose);

          await tester.pumpWidget(_host(role, gateway, statusId: status));
          await tester.pumpAndSettle();

          final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
          expect(chatScreen.onStartActiveDelivery, isNull);
          expect(find.byKey(_ctaKey), findsNothing);
        },
      );
    }
  });
}
