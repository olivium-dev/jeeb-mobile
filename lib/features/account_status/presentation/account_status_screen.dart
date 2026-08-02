import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../application/account_status_cubit.dart';
import '../application/account_status_state.dart';
import '../data/dio_account_status_repository.dart';
import '../data/stub_account_status_repository.dart';
import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';
import 'account_status_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/account_status_screen_fixtures.dart';

/// `account-status` (JM-066, D5). Terminal screen shown when
/// `getMe.status ∈ {suspended, locked}`. The router's [AccountStatusGate]
/// forces this route and blocks ALL tab access while the account is not active;
/// the only exits are contact-support and sign-out.
///
/// W4 body (JM-066): the redirect-gate PREDICATE landed in W0 (router +
/// [AccountStatusGate]); this is the data-bound body fill. It reads the blocked
/// status from `GET /users/me` (U1 — 42_GUARDRAILS_MOCK W-1 FLOOR) so the
/// banner + reason copy reflect WHICH blocked state the account is in
/// (suspended vs locked, D5). It renders the D30 four-state machine
/// (40_GUARDRAILS_ARCH §3): loading → loaded (banner + reason + CTAs) | failed
/// (retry). The screen NEVER polices its own reachability (40_GUARDRAILS_ARCH
/// §12) — the gate owns that.
///
/// CTAs (both target REGISTERED routes — navigation honesty, CTO brief §6.7):
///   * `account_status_support_cta` → `support-ticket` (JM-063, `/support`, D76).
///   * `account_status_signout_cta` → the logout/delete confirm host
///     `settings` (JM-062); the confirm clears the session and the router gate
///     then routes to splash (`/` → first-run, D5).
///
/// Semantics identifiers exposed (EXACT — 30_BACKLOG JM-066):
///   `account_status_root`         — screen host container (gate target)
///   `account_status_support_cta`  — Contact support → support-ticket
///   `account_status_signout_cta`  — Sign out → logout-delete host
class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final AccountStatusRepository? repository;

  /// Resolves the repo: an explicit override (tests) → the registered
  /// `AccountStatusRepository` (when the integrator DI batch lands it) → a LIVE
  /// `DioAccountStatusRepository` over `sl<Dio>()` when GetIt is configured →
  /// the inert `StubAccountStatusRepository` for bare router-resolution widget
  /// tests. Mirrors `NotificationsListScreen._resolveRepository()`.
  AccountStatusRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<AccountStatusRepository>()) {
      return sl<AccountStatusRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioAccountStatusRepository(sl<Dio>());
    }
    return const StubAccountStatusRepository();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountStatusCubit>(
      create: (_) =>
          AccountStatusCubit(repository: _resolveRepository())..load(),
      child: const _AccountStatusView(),
    );
  }
}

class _AccountStatusView extends StatelessWidget {
  const _AccountStatusView();

  @override
  Widget build(BuildContext context) {
    final copy = AccountStatusL10n.of(context);
    return Semantics(
      identifier: 'account_status_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: copy.title),
        body: BlocBuilder<AccountStatusCubit, AccountStatusState>(
          builder: (context, state) {
            switch (state.status) {
              case AccountStatusScreenStatus.initial:
              case AccountStatusScreenStatus.loading:
                return const OmdsLoadingState();
              case AccountStatusScreenStatus.failed:
                return OmdsErrorState(
                  message: copy.loadError,
                  retryLabel: copy.retry,
                  onRetry: () =>
                      context.read<AccountStatusCubit>().refresh(),
                );
              case AccountStatusScreenStatus.loaded:
                return _BlockedBody(
                  value: state.value,
                  serverReason: state.reason,
                  copy: copy,
                );
            }
          },
        ),
      ),
    );
  }
}

/// The blocked-account body: status banner + reason + the two exit CTAs.
class _BlockedBody extends StatelessWidget {
  const _BlockedBody({
    required this.value,
    required this.serverReason,
    required this.copy,
  });

  final AccountStatusValue value;
  final String? serverReason;
  final AccountStatusL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Prefer a server-supplied reason; else localized per-state copy.
    final reason = serverReason ?? copy.defaultReason(value);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Spacing.medium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              value == AccountStatusValue.locked
                  ? Icons.lock_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Spacing.large),
            // Status banner — the WHICH-blocked-state headline (D5).
            Semantics(
              identifier: 'account_status_banner',
              container: true,
              child: Text(
                copy.banner(value),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: Spacing.small),
            // Reason — server reason verbatim, else localized per-state copy.
            Semantics(
              identifier: 'account_status_reason',
              // container so the reason owns its own node, mirroring the banner
              // above. Without it the default explicitChildNodes:false annotation
              // merges this identifier up into account_status_root (which already
              // owns that node), folding the reason id away (JM-049 merge class).
              container: true,
              child: Text(
                reason,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: Spacing.large),
            // EDGE → support-ticket (JM-063, D76). `/support` is registered.
            Semantics(
              identifier: 'account_status_support_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: copy.supportCta,
                onTap: () => context.goNamed('support-ticket'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            // EDGE → logout-delete-account (JM-062, JM-066 AC3). Open the
            // confirm sheet (`logout_delete_sheet`) directly; on confirm the
            // session is cleared and the gate routes to splash → /login (D5).
            Semantics(
              identifier: 'account_status_signout_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: copy.signoutCta,
                variant: OmdsButtonVariant.outlined,
                onTap: () => LogoutDeleteConfirmSheet.show(
                  context,
                  mode: LogoutDeleteMode.both,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/account_status/account_status_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so three things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (the OMDS app bar + the blocked body) and
//    [jeebPreviewHost] wraps every child in one as well, so the canvas shows
//    two nested Scaffolds. The inner one is the real surface; the outer
//    contributes only a background. The canvas box is therefore a real device
//    ([_accountStatusScreenPhoneBox], 390x844) rather than the harness's
//    default 390x200 — a centred column under an app bar cannot be judged in a
//    200 pt strip.
//
// 2. Both affordances on it navigate. `account_status_support_cta` calls
//    `context.goNamed('support-ticket')` and `account_status_signout_cta`
//    raises `LogoutDeleteConfirmSheet`, whose `onCompleted` calls
//    `context.go('/')`; the first is a GoRouter extension, so it throws WHEN
//    TAPPED unless a `Router` sits above the screen — which neither the canvas
//    host nor the render harness provides. (The screen paints without one; it
//    is only the taps that die, which is the worst version of this: a canvas
//    that looks fine and is dead to the touch.) [_AccountStatusScreenHost]
//    supplies one over a local [GoRouter] whose stand-in routes catch both
//    destinations, so the canvas is honest to tap in.
//
// 3. State is driven the only way this screen allows: through the
//    `repository:` constructor seam (40_GUARDRAILS_ARCH §5.4), with the fakes
//    shared with the Screen Catalog entry
//    (`lib/devtool/catalog/fixtures/account_status_screen_fixtures.dart`). The
//    screen builds its own [AccountStatusCubit] internally — there is no
//    `cubit:` seam — so a state is reachable here only if some canned read
//    produces it. No preview constructs a `DioAccountStatusRepository` and
//    `_resolveRepository()`'s `sl<>()` branches are never reached, so these are
//    network-free by construction rather than by the guard in
//    [jeebPreviewHost].
//
// One seam the fixtures cannot close, worth knowing before you tap: the
// sign-out CTA calls `LogoutDeleteConfirmSheet.show(context, mode: both)` with
// no terminator argument, and the sheet self-provides a
// `DioAccountSessionTerminator(resolveGatewayDio(), AuthTokenStore())` when DI
// has nothing registered. OPENING the sheet is inert — its `_terminator` is
// `late`, so nothing is built until a confirm CTA fires — but confirming inside
// the canvas is a real logout attempt, and the `CatalogNetworkGuard`'s POST
// rejection is the only thing between it and the gateway.
//
// What these previews surfaced in the screen — the notes on each say more:
//
//  * **the failed branch has no way off the screen.** `AccountStatusGate`
//    forces this route and blocks ALL tab access while the account is blocked,
//    and the only two exits — contact support, sign out — are built inside the
//    `loaded` branch of `_AccountStatusView`. When the status read fails the
//    user gets an icon, one sentence and a Retry. `unauthorized` is the case
//    that bites: a rejected token fails `GET /v1/users/me` the same way every
//    time, so Retry is a button that cannot succeed and there is no sign-out
//    anywhere on the surface to escape with. See
//    [accountStatusScreenLoadFailed];
//  * **one error string covers all three typed failures.**
//    `AccountStatusL10n.loadError` is a single getter, so a dead session and a
//    5xx are both reported as "Check your connection and try again." That is
//    also why there is only ONE error preview here: a second one built with
//    `AccountStatusFailure.unauthorized` would be pixel-identical, which is the
//    finding rather than a gap in coverage;
//  * **the loaded body does not scroll, and it breaks on the app's OWN copy.**
//    `_BlockedBody` is a `SafeArea` → `Padding` →
//    `Column(mainAxisAlignment: center)` with no scroll fallback, so the column
//    grows past the viewport instead of yielding. What goes past the fold is the
//    bottom of the stack: the support CTA and the sign-out CTA — the only two
//    exits from a screen the gate will not let the user leave. Bottom overflow
//    in logical pixels, EN / AR:
//
//    | state                      | 390 · 100% | 390 · 150% | 390 · 200% | 320 · 100% | 320 · 150% | 320 · 200% |
//    |----------------------------|-----------|-----------|-----------|-----------|-----------|-----------|
//    | suspended, localized copy  | – | – | – | – | **62** / – | **344 / 120** |
//    | locked + one-line reason   | – | – | – | – | – | **176 / 80** |
//    | locked + paragraph reason  | – | **320 / 284** | **1052 / 1004** | **212 / 188** | **842 / 770** | **1656 / 1560** |
//    | failed (`OmdsErrorState`)  | – | – | – | – | – | **36** / – |
//
//    The first row is the finding. That state carries NO server text at all —
//    both lines are `AccountStatusL10n`'s own copy — and it is already over the
//    edge of a 320x568 device at 150%. The third row is the ordinary one: a
//    paragraph-length `statusReason`, which is what a human agent types, needs
//    no large text scale to break a compact phone. The last row is not this
//    screen's `Column` but `OmdsErrorState`'s, which has no scroll fallback
//    either. Note the semantics nodes SURVIVE every one of these — both CTA ids
//    still resolve — so nothing but the overflow error reports it.
//
//    All numbers come from `flutter test`, whose substituted font is materially
//    wider and taller than the production Inter face, so read them as the
//    pessimistic bound — except the 320 pt 100% figures, which are far past any
//    font-metric slack. The four bold FIRST breaks — one per row — are each
//    pinned by a KNOWN test, with the neighbouring clean cells as controls.
//    Same shape as the JM-062 sheet's delete overflow;
//  * **the server reason is dropped verbatim into an RTL paragraph.** Nothing
//    wraps it in a `Directionality`, and `statusReason` is not localized, so in
//    an Arabic build a latin sentence is laid out RTL-base and its trailing
//    period is painted at the LEFT end of the last line. Visible in the AR card
//    of [accountStatusScreenLockedServerReason], which is the whole reason that
//    state is matrixed;
//  * **the loading surface says nothing.** `OmdsLoadingState` is built with no
//    `message`, so a cold entry is a bare spinner under a title reading
//    "Account unavailable" — the render test pins that the whole screen holds
//    exactly ONE `Text` in that state. Combined with the cubit's re-entry guard
//    (`load()` returns early unless `status == initial`), a hung read parks a
//    blocked user there with no copy, no retry and no exit. See
//    [accountStatusScreenLoading].

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _accountStatusScreenPhoneBox = Size(390, 844);

/// The one destination the support CTA has, stubbed.
///
/// The real target is `support-ticket` (JM-063, `/support`, D76); here it only
/// has to exist so a tap lands somewhere and shows which route was taken.
class _AccountStatusScreenStandIn extends StatelessWidget {
  const _AccountStatusScreenStandIn(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: diagnostic, not shipped copy, and a latin route name
          // reorders visually inside an RTL paragraph — the same effect this
          // screen's own server-reason line has, and not one worth reproducing
          // in a stand-in.
          label,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [AccountStatusScreen] so its two CTAs work.
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state.
/// `Router.withConfig` is exactly what `MaterialApp.router` does internally, so
/// this adds a Router and nothing else — the ambient theme, locale and text
/// scale still come from the preview host above it.
///
/// `initialLocation` is the blocked-account route itself with nothing beneath
/// it, which is what the gate's redirect produces: there is no back arrow on
/// this screen and nothing to pop to. `/` is present because the confirm sheet's
/// `onCompleted` goes there (splash → `/login`, D5).
class _AccountStatusScreenHost extends StatefulWidget {
  const _AccountStatusScreenHost({required this.repository});

  final AccountStatusRepository repository;

  @override
  State<_AccountStatusScreenHost> createState() =>
      _AccountStatusScreenHostState();
}

class _AccountStatusScreenHostState extends State<_AccountStatusScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/account-status',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const _AccountStatusScreenStandIn('splash (D5)'),
      ),
      GoRoute(
        path: '/account-status',
        builder: (_, _) => AccountStatusScreen(repository: widget.repository),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (_, _) =>
            const _AccountStatusScreenStandIn('support-ticket (JM-063)'),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

Widget _accountStatusScreenHosted(AccountStatusRepository repository) =>
    _AccountStatusScreenHost(repository: repository);

/// A suspended account with NO server-supplied reason — the closest thing this
/// screen has to an empty state.
///
/// There is no fifth `empty` status (a blocked account always resolves to an
/// [AccountStatusInfo]) and `reason` is the only optional field on it, so this
/// is the shape a gateway that blocks an account without writing a note
/// produces. It is also the ONLY loaded rendering whose reason line is
/// localized: `_BlockedBody` prefers the server string and falls back to
/// `AccountStatusL10n.defaultReason` exactly here.
///
/// Read it against [accountStatusScreenLockedServerReason]: the pause glyph
/// rather than the padlock is the only non-textual difference between the two
/// blocked values.
///
/// It is also the state the overflow table above is really about. Nothing here
/// is server-supplied, nothing is long, and the body still runs 62 pt past a
/// 320x568 device at 150% text and 344 pt past it at 200% — taking both exit
/// CTAs with it. The canvas box below is a 390 pt phone, where it is clean at
/// every scale, so this card will not show you that; the render test is what
/// holds it.
@JeebPreview(
  group: 'account_status',
  name: 'Suspended · no server reason',
  size: _accountStatusScreenPhoneBox,
)
Widget accountStatusScreenSuspendedNoReason() => _accountStatusScreenHosted(
      const AccountStatusScreenFakeRepository(accountStatusScreenSuspended),
    );

/// Locked, with a one-sentence server reason — the catalog's signed-off state.
///
/// Matrixed for the **AR** card. `reason` is free server text rendered verbatim
/// into a `Text` with no `Directionality` of its own, and `statusReason` is not
/// localized — so in an Arabic build this English sentence is laid out with an
/// RTL base direction, and the neutral characters at its edges resolve to RTL:
/// the trailing period is painted at the LEFT end of the last line. The banner
/// directly above it IS localized, so the AR card is where a genuinely Arabic
/// headline and a bidi-reordered English body can be read together, which is
/// what a blocked Arabic user actually gets. Nothing in the EN card shows it.
///
/// The 200% card of this state is clean on the 390 pt box — it is the compact
/// device, not the text scale, that breaks a one-line reason (see the table).
@JeebPreview(
  group: 'account_status',
  name: 'Locked · server reason',
  size: _accountStatusScreenPhoneBox,
  matrix: true,
)
Widget accountStatusScreenLockedServerReason() => _accountStatusScreenHosted(
      const AccountStatusScreenFakeRepository(
        accountStatusScreenLockedWithReason,
      ),
    );

/// The layout ceiling: a paragraph-length hold notice in `reason`.
///
/// Nothing pathological — `statusReason` is free text typed by whoever actioned
/// the block, and a short paragraph is what a human agent writes. `_BlockedBody`
/// centres it in a `Column` with no scroll fallback, so the column simply grows.
///
/// Matrixed because the **200%** card is the finding: on the 390x844 box above
/// the stack runs 1052 pt past the bottom of the phone and the two exit CTAs go
/// with it. The EN-light card is clean, which is the trap — this reason breaks
/// the same phone at **150%** (320 pt) and a 320x568 device at **100%**
/// (212 pt), and the default single card shows none of that.
///
/// Pinned by the render test, which measures at the declared box rather than at
/// the tester's default 800x600 surface — where the extra 410 pt of width folds
/// the paragraph into four lines and hides the whole thing.
@JeebPreview(
  group: 'account_status',
  name: 'Locked · long server reason',
  size: _accountStatusScreenPhoneBox,
  matrix: true,
)
Widget accountStatusScreenLongServerReason() => _accountStatusScreenHosted(
      const AccountStatusScreenFakeRepository(
        accountStatusScreenLockedLongReason,
      ),
    );

/// The status read failed — the D30 `failed` branch, and the state to read for
/// what is NOT on it.
///
/// The gate forces this route and blocks every tab while the account is
/// blocked, so the two CTAs in the loaded body are the user's only exits. They
/// are built inside the `loaded` case, so this surface has neither: an
/// `error_outline`, one sentence, and a Retry that calls `refresh()`.
///
/// With [AccountStatusFailure.network] that is recoverable — the connection
/// comes back and Retry works. With `unauthorized` it is not: the token is
/// rejected, every retry fails identically, the copy still says "Check your
/// connection", and there is no sign-out anywhere on screen. Both render this
/// exact card, which is why there is one error preview and not two.
///
/// `OmdsErrorState` centres a `Column(mainAxisSize: min)` of its own with no
/// scroll fallback either, so this branch has the same ceiling as the loaded
/// one — 36 pt of bottom overflow on a 320x568 device at 200% text, where the
/// Retry is the thing that goes past the fold.
@JeebPreview(
  group: 'account_status',
  name: 'Error · status read failed',
  size: _accountStatusScreenPhoneBox,
)
Widget accountStatusScreenLoadFailed() => _accountStatusScreenHosted(
      const AccountStatusScreenFailingRepository(),
    );

/// Cold entry, held open by a read that never lands.
///
/// `AccountStatusCubit.load()` emits `loading` from the screen's `BlocProvider`
/// `create`, and its re-entry guard (`status != initial`) means nothing else
/// will move it — so a hung `GET /v1/users/me` parks the surface here
/// indefinitely.
///
/// What that surface is: a bare 48 pt `CircularProgressIndicator` under the
/// "Account unavailable" app bar, with no copy at all
/// (`OmdsLoadingState.message` is left null). A blocked user opening the app
/// sees a title telling them the account is unavailable and a spinner that
/// never explains why — and, as with the failed branch, no exit.
@JeebPreview(
  group: 'account_status',
  name: 'Loading · cold entry',
  size: _accountStatusScreenPhoneBox,
)
Widget accountStatusScreenLoading() => _accountStatusScreenHosted(
      const AccountStatusScreenPendingRepository(),
    );
