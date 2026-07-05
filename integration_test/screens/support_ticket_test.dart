// Isolated native UI test — SupportTicketScreen (routed support-ticket).
// The screen reads GoRouterState.of(context).extra at build, so it is pumped
// inside a minimal GoRouter (via pumpRouterAndShoot). No DI needed: with GetIt
// unregistered the screen falls back to StubSupportRepository.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_screen.dart';

import '../support/screen_harness.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/support',
      routes: [
        GoRoute(
          path: '/support',
          builder: (_, _) => const SupportTicketScreen(),
        ),
      ],
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('support-ticket: form (en)', (tester) async {
    await pumpRouterAndShoot(tester, binding, _router(), 'support-ticket__en');
  });

  testWidgets('support-ticket: form (ar)', (tester) async {
    await pumpRouterAndShoot(tester, binding, _router(), 'support-ticket__ar',
        locale: const Locale('ar'));
  });
}
