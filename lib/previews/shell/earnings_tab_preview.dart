/// Widget previews for [EarningsTab] — run with
/// `flutter widget-preview start`.
///
/// [EarningsTab] paints almost nothing itself. It is a two-stage gate:
///
///  1. a `FutureBuilder` over the REAL session id (`sl<AuthTokenStore>().userId`,
///     S0-OAD-03) which either waits, fails closed on "no session", or
///  2. builds an [EarningsCubit] over `sl<EarningsRepository>()` and hands the
///     screen body to [EarningsDashboardScreen].
///
/// So every state below is seeded through the only seam the tab has: the two
/// GetIt registrations it resolves. Each preview REBUILDS both entries (see
/// [_hosted]) rather than assuming what a previously-rendered preview left
/// behind — the canvas keeps one isolate alive across every card, and a tab
/// whose DI state depended on scroll order would be a preview that lies.
///
/// **Network-free by construction.** Both fixtures below are local classes with
/// canned data — never `DioEarningsRepository`, never the real
/// [AuthTokenStore] (whose getters read the platform keychain). The store fake
/// answers the three read getters and throws on both writers, so no preview can
/// persist a token; [jeebPreviewHost]'s guard is the net, not the plan.
///
/// This is why the Screen Catalog only ever showed one state for this tab
/// (`batch_11_entries.dart`: "Unavailable — no active session"): it shares the
/// production GetIt graph and registers nothing, so the fail-closed branch was
/// the only reachable one. Re-registering per preview is what opens the other
/// four.
///
/// Fixture values are lifted from the fixtures this repo already uses for
/// earnings — `lib/devtool/catalog/entries/batch_03_entries.dart`
/// (245.00 cash / 24.50 fees / 7 deliveries / ORD-4821 + ORD-4790, member since
/// 2025-11-03) and `test/features/earnings/earnings_dashboard_data_truth_test.dart`
/// (the all-zero summary that must NOT render as confident zeros) — so the
/// canvas and the tests describe the same screen.
///
/// Three things these previews surfaced, all in the dashboard body rather than
/// in the previews themselves; each is pinned as a number in
/// `test/previews/shell/earnings_tab_preview_test.dart`:
///
///  * the period-pill `Row` is unwrapped and unscrollable, so at 200% text it
///    clips by ~330 dp against 358 dp of content width — in EVERY state,
///    including the empty one, where the pills are the only control there is;
///  * `_FeesPaidCard`'s amount is the only unflexible child of its `Row`, so a
///    long money token (`LBP 1,875,000.00`) starves the `Expanded` label column
///    to 3 dp: the labels become a one-glyph-per-line ribbon and the card grows
///    from 172 dp to ~1028 dp tall. Nothing throws — this one is silent;
///  * `member since` is formatted with a bare `DateFormat.yMMM()`, which
///    resolves to `en_US` no matter the app locale — the AR RTL rendering shows
///    a Latin-script month inside Arabic copy.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/injection_container.dart';
import '../../core/network/auth_token_store.dart';
import '../../features/earnings/domain/earnings_repository.dart';
import '../../features/earnings/domain/earnings_summary.dart';
import '../../features/shell/tabs/earnings_tab.dart';
import '../harness/jeeb_preview.dart';

/// A full tab body: phone width, and tall enough for the headline cards, the
/// stats row and the first breakdown rows without the `ListView` hiding what
/// the preview is about.
const Size earningsTabBox = Size(390, 760);

/// The empty state is pills + one centred `OmdsEmptyState` block.
const Size earningsTabEmptyBox = Size(390, 560);

/// The error state is a centred icon + message + retry button.
const Size earningsTabErrorBox = Size(390, 420);

/// The tab's OWN two branches render a single centred line (or spinner), so a
/// tall box would review nothing but whitespace.
const Size earningsTabGateBox = Size(390, 260);

/// The session id the canvas pretends to be signed in as. Deliberately shaped
/// like a real gateway id and NOT reused as a fixture key anywhere — the tab's
/// contract is that it passes whatever the store holds straight through.
const String _previewJeeberId = 'user-jeeber-002';

// ─────────────────────────────────────────────────────────────────────────────
// Fixtures. Local, canned, and unable to reach the network.
// ─────────────────────────────────────────────────────────────────────────────

/// Answers with a canned summary on the next microtask, like a fast real load.
class _SeededEarningsRepository implements EarningsRepository {
  const _SeededEarningsRepository(this._summary);

  final EarningsSummary _summary;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      _summary;

  /// Exporting is a WRITE the canvas must never perform: the real
  /// implementation downloads a PDF and `EarningsDashboardScreen` then hands
  /// the path to `OpenFile.open`. Failing with the repository's own exception
  /// type (rather than throwing something the cubit does not catch) keeps a
  /// stray tap on the "Export PDF" button inside the designed error path.
  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw const EarningsRepositoryException(EarningsErrorKind.network);
}

/// Fails every read the way a dropped connection does.
class _FailingEarningsRepository implements EarningsRepository {
  const _FailingEarningsRepository();

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
///
/// Subclassing rather than reimplementing is deliberate: the real class is
/// concrete, so this cannot drift out of shape, and the three read getters are
/// all overridden — nothing here can reach `FlutterSecureStorage`. Both writers
/// throw, because a preview that persisted a token would leak canvas state into
/// a real signed-in session on the same device.
class _SeededAuthTokenStore extends AuthTokenStore {
  _SeededAuthTokenStore(this._userId);

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
// Host.
// ─────────────────────────────────────────────────────────────────────────────

/// Rebuilds the two DI entries [EarningsTab] resolves, then returns the tab.
///
/// Both entries are unregistered first so a preview's state is fully described
/// by its own arguments. Passing `sessionUserId: null` leaves NO
/// [AuthTokenStore] registered at all, which is the production shape of "signed
/// out" (`sl.isRegistered` is the tab's own first check); passing
/// `repository: null` leaves no [EarningsRepository], which is what makes the
/// fail-closed preview prove something — the tab cannot have bound an earnings
/// account, because there was none to bind.
Widget _hosted({
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
    sl.registerSingleton<AuthTokenStore>(_SeededAuthTokenStore(sessionUserId));
  }
  return const EarningsTab();
}

/// A signed-in session over a repository that answers with [summary].
Widget _signedIn(EarningsSummary summary) => _hosted(
      repository: _SeededEarningsRepository(summary),
      sessionUserId: Future<String?>.value(_previewJeeberId),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Previews.
// ─────────────────────────────────────────────────────────────────────────────

/// The happy path: a week with cash collected, fees captured, a join date and a
/// delivery breakdown.
///
/// Both money framings are on screen at once (D41/D44) — cash the jeeber keeps
/// off-wallet, and the platform fee paid from the wallet — which is the whole
/// reason this screen was reframed. The AR RTL rendering is where the
/// `member since` row gives itself away: the label translates, the month does
/// not.
@JeebPreview(group: 'shell', name: 'Ready · cash, fees and breakdown', size: earningsTabBox)
Widget earningsTabReady() => _signedIn(
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
///
/// A period with nothing recorded must render the honest "nothing yet" block —
/// never "0.00 USD earned · 0 Deliveries · 0.00 fees", which reads as a
/// betrayal ten minutes after a completed cash delivery. If this preview ever
/// shows a headline card, `EarningsSummary.isEmpty` has broken.
@JeebPreview(group: 'shell', name: 'Empty period · honest zero', size: earningsTabEmptyBox)
Widget earningsTabEmptyPeriod() => _signedIn(
      const EarningsSummary(
        totalCashEarned: 0,
        feesPaid: 0,
        currency: 'USD',
        deliveryCount: 0,
      ),
    );

/// The read failed: the dashboard swaps to a retry state.
///
/// Worth reviewing in the canvas because the cubit and the screen disagree
/// about who owns the wording — `EarningsCubit._mapError` builds a hardcoded
/// ENGLISH `errorMessage` ("Unable to connect. Check your internet."), and the
/// body then ignores it and renders the localized `earningsLoadFailed`. The
/// English string in state is dead copy; the AR rendering here is the one that
/// is actually shown.
@JeebPreview(group: 'shell', name: 'Load failed · retry', size: earningsTabErrorBox)
Widget earningsTabLoadFailed() => _hosted(
      repository: const _FailingEarningsRepository(),
      sessionUserId: Future<String?>.value(_previewJeeberId),
    );

/// S0-OAD-03, the reason this tab exists at all.
///
/// With no session id the tab must NOT fall back to a fixture jeeber and must
/// NOT bind another user's earnings — it renders one explicit line and builds
/// no cubit. Nothing is registered under [EarningsRepository] for this preview,
/// so "no earnings account was bound" is structurally true here, not just
/// visually plausible.
@JeebPreview(group: 'shell', name: 'No session · fail closed', size: earningsTabGateBox)
Widget earningsTabNoSession() => _hosted();

/// The session read has not resolved yet — the first frame after opening the
/// tab, before the keychain answers.
///
/// Two branches of this widget render the SAME centred `OmdsLoadingState`: this
/// one, and the dashboard's own in-flight read. Neither carries a message, so a
/// screen reader is told nothing at all while the tab decides whether the user
/// even has an earnings account.
@JeebPreview(group: 'shell', name: 'Session resolving', size: earningsTabGateBox)
Widget earningsTabSessionResolving() => _hosted(
      repository: const _SeededEarningsRepository(
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
///
/// `MoneyFormat` renders non-USD as `LBP 18,750,000.00` — three times the width
/// of `$245.00`, with a three-digit delivery count beside it and long
/// gateway-shaped delivery ids in the breakdown. Lebanon is the launch market,
/// so this is not a stress fixture: it is what a normal week looks like in the
/// local currency.
///
/// This is the state where `_FeesPaidCard` gives itself away. Its amount is the
/// only child of the `Row` with no flex, so it is measured unbounded and the
/// `Expanded` label column divides the remainder — which here is 3 dp. Compare
/// this card side by side with the one in `Ready`: same widget, six times the
/// height, labels reduced to a vertical thread of single glyphs. No exception
/// is thrown, so only looking at it (or the geometry assertions in the render
/// test) catches it.
@JeebPreview(group: 'shell', name: 'Long content · LBP millions', size: earningsTabBox)
Widget earningsTabLongContent() => _signedIn(
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
