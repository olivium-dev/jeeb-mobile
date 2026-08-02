import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/notifications/domain/notification_deep_link.dart';
import '../../../core/notifications/domain/notification_message.dart';
import '../../../core/role/role_cubit.dart';
import '../application/notifications_list_cubit.dart';
import '../application/notifications_list_state.dart';
import '../data/empty_notifications_repository.dart';
import '../domain/notifications_repository.dart';
import 'notifications_l10n.dart';
import 'widgets/notification_row.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/notifications_list_screen_fixtures.dart';

/// notifications-list (JM-057). The shared inbox reached from the header bell
/// (`orders_home_bell` / `delivery_tab_bell` / `customer_profile_bell`, wired by
/// the integrator to `goNamed('notifications')`).
///
/// Renders the 4-state machine (40_GUARDRAILS_ARCH §3): loading / failed /
/// loaded(+empty). Each typed `notif_row_<id>` shows the category, payload
/// title/body and a relative timestamp; tapping a row (a) marks it read
/// optimistically and (b) dispatches the D84 deep-link for its kind.
///
/// D84 per-row dispatch (30_BACKLOG JM-057 AC; 21_NAV_PLAN §C):
///   offer (P2)                 → offer-review list  (`/requests/:id/offers`,
///                                via the SAME resolver the push tap uses;
///                                no `ref` → `shell`)
///   offer_accepted             → order-chat when addressed, else `shell`
///   status                     → order-chat         (`chat-detail`, ref=conv/req)
///   low_balance / fee_won /
///     refund_penalty / topup   → wallet-hub         (`wallet`)
///   kyc_approved               → jeeber-requests-home (Dashboard tab → `shell`)
///   kyc_rejected               → kyc-rejected
///   request_expired            → waiting-no-coverage (`/requests/:id/waiting`)
///   confirm_receipt            → delivered-receipt   (`/orders/:id/receipt`)
///   marketing                  → customer-orders-home (Requests tab → `shell`)
///   new_request (G3)           → the request screen, via the SAME resolver
///                                the push tap uses (`deepLinkForMessage` →
///                                `/jeeber/requests/:id`) so a dismissed push
///                                keeps a persistent, tappable inbox trail
///   unknown / other missing-ref → no nav (mark-read only; AP-9 honesty — never
///                                 fabricate a target the row can't address)
///
/// Tabs are NOT routes (21_NAV_PLAN §A): the tab-landing kinds route to `shell`
/// and rely on the shell's role/sub-tab default. Reads the LIVE
/// notification-service via `sl<NotificationsRepository>()` (DioNotificationsRepository;
/// list+read mock-ready on :4010 — 42_GUARDRAILS_MOCK §4). [repository] is a
/// constructor test seam (§5.4) — production leaves it null.
///
/// Semantics identifiers exposed (EXACT — 30_BACKLOG JM-057, 41_GUARDRAILS_TESTING):
///   `notifications_root`             — screen host container (bell nav target)
///   `notif_row_<id>`                 — per-notification row (dynamic), tap → D84
///   `notif_row_<id>_timestamp`       — per-row relative timestamp
///   `notif_row_<id>_unread_badge`    — per-row unread dot (accessibility)
class NotificationsListScreen extends StatelessWidget {
  const NotificationsListScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final NotificationsRepository? repository;

  /// Resolves the repo: an explicit override (tests) → the registered LIVE
  /// `DioNotificationsRepository` → an empty fallback when GetIt is not
  /// configured (router-resolution widget tests). Mirrors
  /// `ClientOffersScreen._resolveRepository()`.
  NotificationsRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<NotificationsRepository>()) {
      return sl<NotificationsRepository>();
    }
    return const EmptyNotificationsRepository();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsListCubit>(
      create: (_) =>
          NotificationsListCubit(repository: _resolveRepository())..load(),
      child: const _NotificationsListView(),
    );
  }
}

class _NotificationsListView extends StatelessWidget {
  const _NotificationsListView();

  @override
  Widget build(BuildContext context) {
    final copy = NotificationsL10n.of(context);
    return Semantics(
      identifier: 'notifications_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.title,
          showBackButton: true,
          // The bell reaches this screen via stack-REPLACING `goNamed(
          // 'notifications')`, so there is usually nothing to pop. Pop when we
          // can (pushed entry), else return to the shell — never pop the last
          // page (which would leave an empty Navigator → black surface).
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: BlocBuilder<NotificationsListCubit, NotificationsListState>(
          builder: (context, state) {
            switch (state.status) {
              case NotificationsListStatus.initial:
              case NotificationsListStatus.loading:
                return const OmdsLoadingState();
              case NotificationsListStatus.failed:
                return OmdsErrorState(
                  message: _errorCopy(copy, state.error),
                  retryLabel: copy.retry,
                  onRetry: () =>
                      context.read<NotificationsListCubit>().refresh(),
                );
              case NotificationsListStatus.loaded:
                return OmdsPullToRefresh(
                  onRefresh: () =>
                      context.read<NotificationsListCubit>().refresh(),
                  child: !state.hasItems
                      ? _EmptyBody(copy: copy)
                      : _LoadedList(items: state.items, copy: copy),
                );
            }
          },
        ),
      ),
    );
  }

  static String _errorCopy(NotificationsL10n copy, NotificationsFailure? f) {
    switch (f) {
      case NotificationsFailure.network:
        return copy.networkError;
      case NotificationsFailure.unauthorized:
      case NotificationsFailure.unknown:
      case null:
        return copy.loadError;
    }
  }
}

/// Empty = `loaded` + an empty list (NOT a fifth status, §3). Wrapped in a
/// scrollable so the pull-to-refresh still works on an empty inbox.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.copy});

  final NotificationsL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        OmdsEmptyState(
          icon: Icons.notifications_none_outlined,
          title: copy.emptyTitle,
          subtitle: copy.emptyBody,
        ),
      ],
    );
  }
}

class _LoadedList extends StatelessWidget {
  const _LoadedList({required this.items, required this.copy});

  final List<NotificationItem> items;
  final NotificationsL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return NotificationRow(
          item: item,
          copy: copy,
          onTap: () => _onRowTap(context, item),
        );
      },
    );
  }

  /// (a) mark read (optimistic; cubit owns the flag), then (b) dispatch the
  /// D84 deep-link. Side-effect navigation lives here (the InkWell callback),
  /// never in a `builder` (40_GUARDRAILS_ARCH §3 nav-in-listener rule — this is
  /// an explicit user gesture, not a rebuild).
  void _onRowTap(BuildContext context, NotificationItem item) {
    context.read<NotificationsListCubit>().markRead(item.id);
    _dispatch(context, item);
  }

  void _dispatch(BuildContext context, NotificationItem item) {
    final ref = item.ref;
    switch (item.kind) {
      // Wallet money rows → wallet-hub (`wallet`).
      case NotificationKind.lowBalance:
      case NotificationKind.feeWon:
      case NotificationKind.refundPenalty:
      case NotificationKind.topup:
        context.goNamed('wallet');
        break;

      // Offer-accepted → the conversation when addressed, otherwise the shell.
      case NotificationKind.offerAccepted:
        if (ref != null) {
          context.goNamed('chat-detail', pathParameters: {'id': ref});
        } else {
          context.goNamed('shell');
        }
        break;

      // Order status → the addressed conversation thread.
      case NotificationKind.status:
        if (ref != null) {
          context.goNamed('chat-detail', pathParameters: {'id': ref});
        }
        break;

      // A fresh offer → the offer-review list, via the SAME resolver the push
      // tap uses (the file's own rule at the `newRequest` branch below). Before
      // P2 this went to `shell` while the push went to `/orders/:id` — two
      // different wrong answers for one event.
      //
      // Resolver-mediated rather than `goNamed('offer-review')`: both forms
      // land on the IDENTICAL path (`app_router.dart:768`), so this is a
      // mechanism choice, not a destination one. Three reasons for this side:
      //   1. `push` (not `go`) so BACK returns to the inbox. `offer-review` is
      //      in `AppRouter.backFallbacks` → `/`, and that fallback is consumed
      //      only at the true stack root, so a `go` here would send BACK to
      //      Home and lose the inbox.
      //   2. One resolver for inbox-tap and push-tap makes the two
      //      structurally unable to drift apart again — the P2 defect.
      //   3. `NotificationCategory.newOffer` exists in the resolver; routing
      //      around it would leave that branch with no caller from here.
      // No `ref` → the shell, as before (handled before the resolver, so the
      // resolver's own id-less `'/'` return is never reached from this screen).
      case NotificationKind.offer:
        if (ref == null) {
          context.goNamed('shell');
          break;
        }
        final offerTarget = deepLinkForMessage(NotificationMessage(
          id: item.id,
          category: NotificationCategory.newOffer,
          title: item.title,
          body: item.body,
          receivedAt: DateTime.now(),
          data: {'requestId': ref},
        ));
        if (offerTarget != null) context.push(offerTarget);
        break;

      // KYC approved → jeeber-requests-home (Dashboard tab) — a shell tab.
      case NotificationKind.kycApproved:
        context.goNamed('shell');
        break;

      // KYC rejected → the appeal-only rejected screen (D52/D87).
      case NotificationKind.kycRejected:
        context.goNamed('kyc-rejected');
        break;

      // Request expired → waiting / no-coverage (`/requests/:id/waiting`).
      case NotificationKind.requestExpired:
        if (ref != null) {
          context.goNamed('waiting-no-coverage', pathParameters: {'id': ref});
        }
        break;

      // Confirm-receipt → the delivered-receipt prompt (`/orders/:id/receipt`);
      // `ref` is the deliveryId.
      case NotificationKind.confirmReceipt:
        if (ref != null) {
          context.goNamed('delivered-receipt', pathParameters: {'id': ref});
        }
        break;

      // Marketing → customer-orders-home (Requests tab) — a shell tab.
      case NotificationKind.marketing:
        context.goNamed('shell');
        break;

      // G3: new_request → the request screen. CONSUME the push-tap resolver
      // (deepLinkForMessage, fix/push-tap-routing) rather than re-mapping the
      // route here, so the inbox row and the push tap can never diverge —
      // `/jeeber/requests/:id` already handles cache recovery + graceful
      // fallback for taken/expired requests. Pushed (not go) so back returns
      // to the inbox.
      case NotificationKind.newRequest:
        if (ref == null) break;
        final target = deepLinkForMessage(
          NotificationMessage(
            id: item.id,
            category: NotificationCategory.newRequest,
            title: item.title,
            body: item.body,
            receivedAt: DateTime.now(),
            data: {'requestId': ref},
          ),
          // F5: a CLIENT tapping a `new_request` row must not be sent to
          // `/jeeber/requests/:id` — its recovery path calls the jeeber-only
          // `GET /v1/jeebers/me/feed` → 403 (FIX-REQUESTS.md:35). The resolver
          // returns `/` for a client instead. Without this argument `role`
          // defaults to null and the guard compiles but never fires.
          role: context.read<RoleCubit>().state,
        );
        if (target != null) context.push(target);
        break;

      // Unknown / unmapped — mark-read only, stay on the inbox (AP-9: never
      // fabricate a destination the row can't address).
      case NotificationKind.unknown:
        break;
    }
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/notifications/notifications_list_screen_preview_test.dart
// ===========================================================================
//
// [NotificationsListScreen] is the shared inbox behind the header bell. It
// takes a REPOSITORY, not a state — it builds its own [NotificationsListCubit]
// and calls `load()` at mount — so every preview below hands it a local fake
// through the same `repository:` seam the widget tests use, and the real
// cold-load path runs exactly as it does in production.
//
// The fakes and the casts are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/notifications_list_screen_fixtures.dart`,
// shared with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_07_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". None of those repositories can reach the network — they answer from
// a list, throw, or never complete — and the `sl<NotificationsRepository>()`
// branch of `_resolveRepository` is never reached, so these previews are
// network-free by construction rather than by the guard in [jeebPreviewHost].
//
// Three things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and the
//    screen's own `Scaffold + OMDSAppBar` paints inside it. That is the same
//    nesting the Screen Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.** The `size:` on
//    [JeebPreview] boxes the canvas; [_notificationsListScreenFramed] pins the
//    same device in the widget tree — a `MediaQuery` override AND a `SizedBox`
//    — so the render tests measure the same phone instead of the 800x600 test
//    surface. The `MediaQuery` half is load-bearing rather than tidy:
//    `_EmptyBody` spaces its illustration down by `MediaQuery.of(context)
//    .size.height * 0.18`, so without it the empty state on a 320x568 card
//    would be positioned for whatever window the host happens to have.
//  * **Tapping is not previewing.** Every row dispatches through `goNamed` /
//    `push`, and the `new_request` branch additionally reads a [RoleCubit];
//    neither a [GoRouter] nor that cubit exists above a preview card, so a tap
//    throws. Nothing here is a tap target under review — the states are.
//
// ## The states, and what they are chosen for
//
// The four the Screen Catalog names (Loading / Populated / Empty / Load
// Failed) plus two it does not:
//
//   * **Empty vs failed.** Different bodies making different claims: "you're
//     all caught up" is a statement about server DATA that a failed read is no
//     evidence for. They are previewed adjacently so a regression that makes
//     one look like the other is visible here first — and note that
//     `_resolveRepository` falls back to [EmptyNotificationsRepository] when
//     GetIt is unconfigured, so a mis-wired build renders exactly the Empty
//     card below rather than an error.
//   * **The two failures.** `_errorCopy` gives [NotificationsFailure.network]
//     its own copy and collapses `unauthorized` / `unknown` / null into the
//     generic "Could not load notifications.". Both cards are previewed
//     because they are the same pixels for very different situations: on the
//     expired-session one, Retry cannot ever succeed and nothing on the
//     surface says "sign in again".
//   * **Longest content at 320 pt.** The layout ceiling on the narrowest phone
//     the app supports, with the two degenerate payloads under it.
//
// ## What these previews expose in the screen
//
//  * **The list has no clock.** [NotificationRow] takes an injectable `now`
//    for its relative timestamp and `_LoadedList` does not pass one, so every
//    age on this screen is measured against the device wall clock. No mocked
//    surface can freeze it (which is why the fixtures express each row as an
//    OFFSET from the read rather than as an instant), and on a device whose
//    clock is behind the server's every row reads "Just now" — `relativeTime`
//    returns that for any negative difference.
//  * **A failed pull-to-refresh is invisible, and no preview here can show
//    it.** The `BlocBuilder` switches on `state.status` alone; `refresh()`
//    failing emits `copyWith(error: …)` with the status still `loaded`, and
//    `state.error` is read ONLY inside the `failed` branch. So the rows do not
//    change, no banner appears, and `NotificationsListCubit.acknowledgeError`
//    — which exists for exactly this — has no caller in this file. Staging it
//    would need a cubit seam the screen does not have; this note is the
//    preview.

/// The phone this screen is designed against.
const Size _notificationsListScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _notificationsListScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame: the window it thinks it is in
/// (`MediaQuery`) and the box it is laid out in (`SizedBox`).
///
/// Both halves are needed. `_EmptyBody` reads `MediaQuery.size.height`, so the
/// window has to say 844 for the empty illustration to sit where a designer
/// signs it off; and the render tests pump onto a fixed 800x600 surface, so the
/// box has to be enforced or every card would measure 800 x 600.
///
/// The frame is placed inside two unbounded scroll views rather than an
/// `Align`, because an `Align` passes the host's constraints down and an 844 pt
/// phone would be silently clamped to the 600 pt test surface — faking the one
/// measurement these previews depend on. `textScaler` is deliberately NOT
/// overridden: [JeebPreview] renders a 200% card and a frame that pinned 1.0
/// would quietly show a 100% rendering under a "200% text" label.
Widget _notificationsListScreenFramed(
  Widget screen, {
  Size box = _notificationsListScreenPhoneBox,
}) {
  return SingleChildScrollView(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: box,
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: SizedBox.fromSize(size: box, child: screen),
        ),
      ),
    ),
  );
}

/// Builds the screen the way its route builds it — nothing but a repository —
/// inside a device frame.
Widget _notificationsListScreenHosted(
  NotificationsRepository repository, {
  Size box = _notificationsListScreenPhoneBox,
}) {
  return _notificationsListScreenFramed(
    NotificationsListScreen(repository: repository),
    box: box,
  );
}

/// The reference reading: three rows across three D84 dispatch classes, the
/// middle one already read.
///
/// This is the one the matrix is for. Each row is a [Row] of a fixed leading
/// icon, an unclamped text column and a 12 pt unread dot: in AR the whole
/// stack mirrors (the icon to the trailing edge, the dot to the leading one —
/// AC-16 FM1), and at 200% text the eyebrow/title/body/age column is four
/// lines of roughly double height inside the same 390 pt frame, which is where
/// a list of three rows stops being a list you can scan.
///
/// Read the top two lines of each row as a pair while you are here: the
/// eyebrow is the per-KIND category label and the title is the payload
/// headline, and P0-X08 was a fixture that rendered the same string twice.
@JeebPreview(
  group: 'notifications',
  name: 'Populated · mixed inbox',
  size: _notificationsListScreenPhoneBox,
  matrix: true,
)
Widget notificationsListScreenPopulated() => _notificationsListScreenHosted(
      NotificationsListScreenPreviewFixtures.populated(),
    );

/// A read that SUCCEEDED and came back with zero rows: "You're all caught up".
///
/// Read it next to [notificationsListScreenLoadFailedNetwork] — this is the
/// only one of the two entitled to make a claim about the server's data. It is
/// also what a build with an unconfigured GetIt renders, because
/// `_resolveRepository` falls through to [EmptyNotificationsRepository] rather
/// than failing: the same reassuring page, with nothing behind it.
///
/// The body is a `ListView` on purpose (`AlwaysScrollableScrollPhysics`), so
/// pull-to-refresh still works on an empty inbox — the one affordance this
/// state has.
@JeebPreview(
  group: 'notifications',
  name: 'Empty · nothing yet',
  size: _notificationsListScreenPhoneBox,
)
Widget notificationsListScreenEmpty() => _notificationsListScreenHosted(
      NotificationsListScreenPreviewFixtures.emptyInbox(),
    );

/// The cold read in flight: an [OmdsLoadingState] spinner and nothing else.
///
/// Note what is NOT on screen — no rows, no copy, and nothing to do but leave.
/// `load()` guards re-entry on `status != initial`, so a remount does not
/// refetch; a read that never lands leaves the screen exactly here for as long
/// as the inbox is open, with no timeout and no retry.
@JeebPreview(
  group: 'notifications',
  name: 'Loading · cold read',
  size: _notificationsListScreenPhoneBox,
)
Widget notificationsListScreenLoading() => _notificationsListScreenHosted(
      NotificationsListScreenPreviewFixtures.stalledLoad(),
    );

/// The cold read failed on the transport: the centred [OmdsErrorState] with the
/// one message this screen has that names its own cause, over a Retry that can
/// actually succeed once the connection returns.
@JeebPreview(
  group: 'notifications',
  name: 'Load failed · network',
  size: _notificationsListScreenPhoneBox,
)
Widget notificationsListScreenLoadFailedNetwork() =>
    _notificationsListScreenHosted(
      NotificationsListScreenPreviewFixtures.networkFailure(),
    );

/// The same failed body, reached by a 401.
///
/// `_errorCopy` maps `unauthorized` onto the generic `loadError`, so this card
/// is pixel-identical to [notificationsListScreenLoadFailedNetwork] except for
/// one sentence — and it is the one where the offered action is useless: Retry
/// re-issues the same unauthenticated read and fails the same way until the
/// user signs in again, which nothing on this surface tells them to do. Worth a
/// card of its own precisely because the two are so hard to tell apart.
@JeebPreview(
  group: 'notifications',
  name: 'Load failed · session expired',
  size: _notificationsListScreenPhoneBox,
)
Widget notificationsListScreenSessionExpired() =>
    _notificationsListScreenHosted(
      NotificationsListScreenPreviewFixtures.unauthorizedFailure(),
    );

/// The layout ceiling on the narrowest supported phone, with the two
/// degenerate payloads underneath it.
///
/// Nothing on a row clamps — neither the title nor the body sets `maxLines` —
/// so the first row does not ellipsize, it GROWS, and at 320 pt it is most of
/// the viewport on its own. The `Divider(height: 1)` between rows is then the
/// only thing telling a reader that one notification ended and the next began.
///
/// Under it: a `new_request` from a data-only push (empty title and body,
/// filled in by the localized G3 fallback) and an `unknown` row with an empty
/// title, body AND timestamp, which is what any wire `type` the mobile enum
/// does not know about degrades to — a bare category eyebrow and an unread dot.
/// The cubit sorts the timestamp-less row last, so this is also the ordering
/// contract: a malformed row can never jump to the top.
///
/// This state carries the matrix because 320 pt is where AR and 200% text stop
/// being a formality.
@JeebPreview(
  group: 'notifications',
  name: 'Longest content · compact 320',
  size: _notificationsListScreenCompactBox,
  matrix: true,
)
Widget notificationsListScreenLongestContent() => _notificationsListScreenHosted(
      NotificationsListScreenPreviewFixtures.longestContentInbox(),
      box: _notificationsListScreenCompactBox,
    );
