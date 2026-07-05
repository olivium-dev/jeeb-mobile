// Isolated native UI test — ClientHomeScreen (Requests tab / shell home body).
// Pumps the screen directly over an InMemoryClientHomeRepository + ClientHomeCubit
// and screenshots the populated / empty variants in en + ar.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';

import '../support/screen_harness.dart';

/// Populated snapshot mirroring the widget test's Figma mock data (screens
/// 13/14/15): one in-progress, one pending, and one replies request.
ClientHomeRepository _populatedRepo() {
  return InMemoryClientHomeRepository.fromSnapshot(
    const ClientHomeSnapshot(
      inProgress: [
        ClientHomeRequest(
          id: 'ip-1',
          title: 'Kamal Hajj',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.enRoute,
          tier: ClientRequestTier.flash,
          progressStep: 3,
        ),
      ],
      pending: [
        ClientHomeRequest(
          id: 'pen-1',
          title: 'ORD-23470',
          displayId: 'ORD-23470',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.searching,
          tier: ClientRequestTier.express,
        ),
      ],
      replies: [
        ClientHomeRequest(
          id: 'rep-1',
          title: 'ORD-23470',
          displayId: 'ORD-23470',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.offersReceived,
          tier: ClientRequestTier.express,
          offerCount: 9,
          offerAvatarUrls: ['', '', ''],
          conversationId: 'conv-rep-1',
        ),
      ],
    ),
    latency: Duration.zero,
  );
}

/// Wrap the screen in a Scaffold (its root is a Stack, not a Scaffold) and a
/// BlocProvider carrying the cubit. Callbacks are no-ops so the New Order FAB /
/// Track CTAs render.
Widget _clientHome({required ClientHomeRepository repo, String? name}) {
  return Scaffold(
    body: BlocProvider(
      create: (_) => ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => name,
      ),
      child: ClientHomeScreen(
        onCreateRequest: () {},
        onTrack: (_) {},
      ),
    ),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client-home: populated in-progress requests (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _clientHome(repo: _populatedRepo(), name: 'Layla'),
      'client-home__populated',
    );
  });

  testWidgets('client-home: empty state (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _clientHome(
        repo: InMemoryClientHomeRepository(latency: Duration.zero),
        name: 'Layla',
      ),
      'client-home__empty',
    );
  });

  testWidgets('client-home: populated requests (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _clientHome(repo: _populatedRepo(), name: 'ليلى'),
      'client-home__ar',
      locale: const Locale('ar'),
    );
  });
}
