import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../earnings/application/earnings_cubit.dart';
import '../../earnings/domain/earnings_repository.dart';
import '../../earnings/presentation/earnings_dashboard_screen.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../core/previews/jeeb_preview.dart';
import '../../earnings/domain/earnings_summary.dart';

class EarningsTab extends StatelessWidget {
  const EarningsTab({super.key, this.sessionUserId});

  /// Catalog / preview seam for the session read. `null` (every production call
  /// site) resolves the real [AuthTokenStore]; a pending future pins the gate.
  final Future<String?>? sessionUserId;

  /// `find.bySemanticsIdentifier` handle on the session-read state.
  static const String loadingIdentifier = 'earnings_tab_session_loading';

  /// …and on the S0-OAD-03 fail-closed state.
  static const String unavailableIdentifier = 'earnings_tab_unavailable';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: sessionUserId ?? _sessionUserId(),
      builder: (context, snapshot) {
        final userId = snapshot.data;
        if (userId != null && userId.isNotEmpty) {
          return BlocProvider<EarningsCubit>(
            create: (_) => EarningsCubit(
              repository: sl<EarningsRepository>(),
              jeeberId: userId,
            ),
            child: const EarningsDashboardScreen(),
          );
        }
        final l10n = AppLocalizations.of(context);
        if (snapshot.connectionState != ConnectionState.done) {
          return _EarningsGate(
            child: JeebEmptyState(
              variant: JeebEmptyStateVariant.radar,
              status: JeebEmptyStateStatus.loading,
              medallions: const <JeebEmptyMedallion>[],
              identifier: loadingIdentifier,
              headline: l10n.earningsLoadingHeadline,
            ),
          );
        }
        return _EarningsGate(
          child: JeebEmptyState(
            variant: JeebEmptyStateVariant.radar,
            status: JeebEmptyStateStatus.error,
            medallions: const <JeebEmptyMedallion>[],
            identifier: unavailableIdentifier,
            headline: l10n.earningsAccountUnavailable,
          ),
        );
      },
    );
  }

  Future<String?> _sessionUserId() async {
    if (sl.isRegistered<AuthTokenStore>()) {
      final id = await sl<AuthTokenStore>().userId;
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }
}

/// The frame both gate arms share — the same field [EarningsDashboardScreen]
/// paints, so resolving the session flashes no new background.
class _EarningsGate extends StatelessWidget {
  const _EarningsGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `Center` is what fills the tab: without it the field's Stack shrink-wraps
    // a short state and leaves the rest of the page unpainted.
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      animateDecor: false,
      child: SafeArea(
        child: Center(child: SingleChildScrollView(child: child)),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A full tab body: phone width, and tall enough for the headline cards, the
/// stats row and the first breakdown rows without the `ListView` hiding what
const Size _earningsTabBox = Size(390, 760);

/// The empty state is pills + one centred `OmdsEmptyState` block.
const Size _earningsTabEmptyBox = Size(390, 560);

/// The error state is a centred icon + message + retry button.
const Size _earningsTabErrorBox = Size(390, 420);

/// The tab's OWN two branches render a single centred line (or spinner), so a
/// tall box would review nothing but whitespace.
const Size _earningsTabGateBox = Size(390, 260);

/// The session id the canvas pretends to be signed in as. Deliberately shaped
/// like a real gateway id and NOT reused as a fixture key anywhere — the tab's
const String _earningsTabJeeberId = 'user-jeeber-002';

// ─────────────────────────────────────────────────────────────────────────────

/// Answers with a canned summary on the next microtask, like a fast real load.
class _EarningsTabSeededRepository implements EarningsRepository {
  const _EarningsTabSeededRepository(this._summary);

  final EarningsSummary _summary;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      _summary;

  /// Exporting is a WRITE the canvas must never perform: the real
  /// implementation downloads a PDF and `EarningsDashboardScreen` then hands
  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw const EarningsRepositoryException(EarningsErrorKind.network);
}

/// Fails every read the way a dropped connection does.
class _EarningsTabFailingRepository implements EarningsRepository {
  const _EarningsTabFailingRepository();

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw const EarningsRepositoryException(EarningsErrorKind.network);

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw const EarningsRepositoryException(EarningsErrorKind.network);
}

/// Stands in for the keychain-backed [AuthTokenStore].
/// Subclassing rather than reimplementing is deliberate: the real class is
/// concrete, so this cannot drift out of shape, and the three read getters are
class _EarningsTabSeededAuthTokenStore extends AuthTokenStore {
  _EarningsTabSeededAuthTokenStore(this._userId);

  final Future<String?> _userId;

  @override
  Future<String?> get userId => _userId;

  @override
  Future<String?> get accessToken async => 'preview-access-token';

  @override
  Future<String?> get refreshToken async => 'preview-refresh-token';

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async =>
      throw UnsupportedError('previews never write to the keychain');

  @override
  Future<void> clear() async =>
      throw UnsupportedError('previews never write to the keychain');
}

// ─────────────────────────────────────────────────────────────────────────────

/// Rebuilds the two DI entries [EarningsTab] resolves, then returns the tab.
/// Both entries are unregistered first so a preview's state is fully described
Widget _earningsTabHosted({
  EarningsRepository? repository,
  Future<String?>? sessionUserId,
}) {
  if (sl.isRegistered<EarningsRepository>()) {
    sl.unregister<EarningsRepository>();
  }
  if (repository != null) {
    sl.registerSingleton<EarningsRepository>(repository);
  }
  if (sl.isRegistered<AuthTokenStore>()) {
    sl.unregister<AuthTokenStore>();
  }
  if (sessionUserId != null) {
    sl.registerSingleton<AuthTokenStore>(
      _EarningsTabSeededAuthTokenStore(sessionUserId),
    );
  }
  return const EarningsTab();
}

/// A signed-in session over a repository that answers with [summary].
Widget _earningsTabSignedIn(EarningsSummary summary) => _earningsTabHosted(
      repository: _EarningsTabSeededRepository(summary),
      sessionUserId: Future<String?>.value(_earningsTabJeeberId),
    );

// ─────────────────────────────────────────────────────────────────────────────

/// The happy path: a week with cash collected, fees captured, a join date and a
/// delivery breakdown.
@JeebPreview(
  group: 'shell',
  name: 'Ready · cash, fees and breakdown',
  size: _earningsTabBox,
)
Widget earningsTabReady() => _earningsTabSignedIn(
      const EarningsSummary(
        totalCashEarned: 245,
        feesPaid: 24.5,
        currency: 'USD',
        deliveryCount: 7,
        memberSince: '2025-11-03T00:00:00Z',
        deliveries: <EarningsDeliveryItem>[
          EarningsDeliveryItem(
            deliveryId: 'ORD-4821',
            date: '2026-07-04T18:20:00Z',
            cashCollected: 35,
            feePaid: 3.5,
            currency: 'USD',
          ),
          EarningsDeliveryItem(
            deliveryId: 'ORD-4790',
            date: '2026-07-02T12:05:00Z',
            cashCollected: 50,
            feePaid: 5,
            currency: 'USD',
          ),
        ],
      ),
    );

/// T11 / SW-01 regression guard, made visible.
/// A period with nothing recorded must render the honest "nothing yet" block —
@JeebPreview(
  group: 'shell',
  name: 'Empty period · honest zero',
  size: _earningsTabEmptyBox,
)
Widget earningsTabEmptyPeriod() => _earningsTabSignedIn(
      const EarningsSummary(
        totalCashEarned: 0,
        feesPaid: 0,
        currency: 'USD',
        deliveryCount: 0,
      ),
    );

/// The read failed: the dashboard swaps to a retry state.
/// Worth reviewing in the canvas because the cubit and the screen disagree
@JeebPreview(
  group: 'shell',
  name: 'Load failed · retry',
  size: _earningsTabErrorBox,
)
Widget earningsTabLoadFailed() => _earningsTabHosted(
      repository: const _EarningsTabFailingRepository(),
      sessionUserId: Future<String?>.value(_earningsTabJeeberId),
    );

/// S0-OAD-03, the reason this tab exists at all.
/// With no session id the tab must NOT fall back to a fixture jeeber and must
@JeebPreview(
  group: 'shell',
  name: 'No session · fail closed',
  size: _earningsTabGateBox,
)
Widget earningsTabNoSession() => _earningsTabHosted();

/// The session read has not resolved yet — the first frame after opening the
/// tab, before the keychain answers.
@JeebPreview(
  group: 'shell',
  name: 'Session resolving',
  size: _earningsTabGateBox,
)
Widget earningsTabSessionResolving() => _earningsTabHosted(
      repository: const _EarningsTabSeededRepository(
        EarningsSummary(
          totalCashEarned: 245,
          feesPaid: 24.5,
          currency: 'USD',
          deliveryCount: 7,
        ),
      ),
      sessionUserId: Completer<String?>().future,
    );

/// Layout ceiling: a busy month in Lebanese pounds.
/// `MoneyFormat` renders non-USD as `LBP 18,750,000.00` — three times the width
@JeebPreview(
  group: 'shell',
  name: 'Long content · LBP millions',
  size: _earningsTabBox,
)
Widget earningsTabLongContent() => _earningsTabSignedIn(
      const EarningsSummary(
        totalCashEarned: 18750000,
        feesPaid: 1875000,
        currency: 'LBP',
        deliveryCount: 128,
        memberSince: '2024-02-29T00:00:00Z',
        deliveries: <EarningsDeliveryItem>[
          EarningsDeliveryItem(
            deliveryId: 'ORD-4821-REDELIVERY-ATTEMPT-3',
            date: '2026-07-04T18:20:00Z',
            cashCollected: 1450000,
            feePaid: 145000,
            currency: 'LBP',
          ),
          EarningsDeliveryItem(
            deliveryId: 'ORD-4790-EXPRESS-PHARMACY-RUN',
            date: '2026-07-02T12:05:00Z',
            cashCollected: 2300000,
            feePaid: 230000,
            currency: 'LBP',
          ),
        ],
      ),
    );
