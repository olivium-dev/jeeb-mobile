import 'package:flutter/widgets.dart';

import '../../../features/account_status/data/stub_account_status_repository.dart';
import '../../../features/account_status/domain/account_status.dart';
import '../../../features/account_status/domain/account_status_repository.dart';
import '../../../features/account_status/presentation/account_status_screen.dart';
import '../../../features/client_unreachable/presentation/client_unreachable_screen.dart';
import '../../../features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import '../catalog_models.dart';

/// Batch 00 — worked example / template for the parallel catalog authoring.
///
/// Pattern for every entry: pass an explicit LOCAL fake/stub repository per
/// state so the real screen renders its DESIGNED state with NO network (a bare
/// constructor would hit the live gateway and show a spinner/error instead).
/// Reuse a shipped Stub/Fake when present; otherwise define a private inline
/// fake like [_FakeAccountStatusRepository] below.
List<CatalogEntry> get batch00Entries => <CatalogEntry>[
      const CatalogEntry(
        feature: 'account_status',
        screen: 'AccountStatusScreen',
        states: [
          CatalogState('Suspended', _accountStatusSuspended),
          CatalogState('Locked (with reason)', _accountStatusLocked),
        ],
      ),
      CatalogEntry(
        feature: 'client_unreachable',
        screen: 'ClientUnreachableScreen',
        states: [
          CatalogState(
            'Unreachable',
            (_) =>
                const ClientUnreachableScreen(deliveryId: 'demo-delivery-001'),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'kyc_rejected',
        screen: 'KycRejectedScreen',
        states: [
          CatalogState('Rejected', (_) => const KycRejectedScreen()),
        ],
      ),
    ];

class _FakeAccountStatusRepository implements AccountStatusRepository {
  const _FakeAccountStatusRepository(this._info);
  final AccountStatusInfo _info;
  @override
  Future<AccountStatusInfo> fetchStatus() async => _info;
}

Widget _accountStatusSuspended(BuildContext _) =>
    const AccountStatusScreen(repository: StubAccountStatusRepository());

Widget _accountStatusLocked(BuildContext _) => const AccountStatusScreen(
      repository: _FakeAccountStatusRepository(
        AccountStatusInfo(
          value: AccountStatusValue.locked,
          reason: 'Multiple chargeback disputes',
        ),
      ),
    );
