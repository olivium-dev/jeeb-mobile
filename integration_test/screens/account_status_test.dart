// Isolated native UI test — AccountStatusScreen (account-status, JM-066, D5). The
// screen owns its own BlocProvider and cold-loads via an injected repository; we
// feed a static in-memory repo so the blocked body (status banner + reason + the
// support / sign-out exit CTAs) renders deterministically. CTA navigation only
// fires on tap, so no router is needed. Covers suspended, locked, and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';

import '../support/screen_harness.dart';

/// Serves one fixed blocked-status snapshot (mirrors the widget test's scripted
/// repo) so the cubit's cold load settles into the loaded body.
class _StaticAccountStatusRepository implements AccountStatusRepository {
  const _StaticAccountStatusRepository(this._info);
  final AccountStatusInfo _info;

  @override
  Future<AccountStatusInfo> fetchStatus() async => _info;
}

AccountStatusScreen _status(AccountStatusInfo info) =>
    AccountStatusScreen(repository: _StaticAccountStatusRepository(info));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('account-status: suspended blocked body (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _status(const AccountStatusInfo(value: AccountStatusValue.suspended)),
      'account-status__suspended',
    );
  });

  testWidgets('account-status: locked blocked body (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _status(const AccountStatusInfo(value: AccountStatusValue.locked)),
      'account-status__locked',
    );
  });

  testWidgets('account-status: suspended blocked body (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _status(const AccountStatusInfo(value: AccountStatusValue.suspended)),
      'account-status__ar',
      locale: const Locale('ar'),
    );
  });
}
