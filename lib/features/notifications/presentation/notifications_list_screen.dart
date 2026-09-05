import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/notifications/domain/notification_deep_link.dart';
import '../../../core/notifications/domain/notification_message.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/notifications_list_cubit.dart';
import '../application/notifications_list_state.dart';
import '../data/empty_notifications_repository.dart';
import '../data/unavailable_notifications_repository.dart';
import '../domain/notifications_repository.dart';
import 'notifications_l10n.dart';
import 'widgets/notification_row.dart';

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
///                                no `ref` → cannot-open snack, stay put)
///   offer_accepted             → order-chat when addressed, else cannot-open
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
/// MIDNIGHT (M3-08): a re-skin, not a rewrite — same route, same 4-state
/// machine, same D84 dispatch, every frozen identifier unmoved. The board never
/// drew this screen, so everything visual is DERIVED from R21 (order history),
/// its neighbour in the shell and the nearest drawn list surface: an in-body
/// [JeebTopBar] that renders in EVERY state, R21's 24px band gutter, rest-glass
/// rows 12px apart, and the E4 `parcel` illustration for empty / loading /
/// error — R21's own empty family.
///
/// Semantics identifiers exposed (EXACT — 30_BACKLOG JM-057, 41_GUARDRAILS_TESTING):
///   `notifications_root`             — screen host container (bell nav target)
///   `notifications_back`             — the top bar's leading circle
///   `notif_row_<id>`                 — per-notification row (dynamic), tap → D84
///   `notif_row_<id>_timestamp`       — per-row relative timestamp
///   `notif_row_<id>_unread_badge`    — per-row unread dot (accessibility)
/// Added by M3-08 (not frozen, mirrors R21's own state-block naming):
///   `notifications_loading` · `notifications_empty` · `notifications_error` ·
///   `notifications_retry_cta`
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
    // A DI miss must not fabricate an empty inbox in release (GEN-01).
    return kDebugMode
        ? const EmptyNotificationsRepository()
        : const UnavailableNotificationsRepository();
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
        // R21 declares ONE radial: PERIWINKLE at 12% -6%, zero orange. There
        // is no zero-glow lever on `content`, so the orange layer is nulled.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowColor: Colors.transparent,
          washPlacement: JeebFieldWashPlacement.topStart,
          animateDecor: false,
          // An in-body row, not a Material app bar: it renders in EVERY state
          // and carries R21's 24px gutter instead of a centred M3 title.
          child: SafeArea(
            child: Column(
              children: [
                JeebTopBar(
                  identifier: 'notifications_back',
                  title: copy.title,
                  leadingTooltip: MaterialLocalizations.of(
                    context,
                  ).backButtonTooltip,
                  // The bell arrives via stack-REPLACING `goNamed`, so pop only
                  // when we can — popping the last page leaves a black surface.
                  onLeadingPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                ),
                Expanded(
                  child:
                      BlocConsumer<
                        NotificationsListCubit,
                        NotificationsListState
                      >(
                        listenWhen: (p, n) =>
                            p.markReadFailure != n.markReadFailure &&
                            n.markReadFailure != null,
                        listener: (context, state) {
                          showJeebErrorSnack(
                            context,
                            identifier: 'notifications_markread_error',
                            message: AppLocalizations.of(
                              context,
                            ).notificationsMarkReadFailed,
                          );
                          context
                              .read<NotificationsListCubit>()
                              .acknowledgeMarkReadFailure();
                        },
                        builder: (context, state) {
                          switch (state.status) {
                            case NotificationsListStatus.initial:
                            case NotificationsListStatus.loading:
                              return _StateBlock(
                                status: JeebEmptyStateStatus.loading,
                                headline: copy.loadingHeadline,
                                identifier: 'notifications_loading',
                              );
                            case NotificationsListStatus.failed:
                              return _ErrorBody(state: state);
                            case NotificationsListStatus.loaded:
                              final cubit = context
                                  .read<NotificationsListCubit>();
                              return JeebPullToRefresh(
                                onRefresh: cubit.refresh,
                                child: Column(
                                  children: [
                                    if (state.refreshError != null)
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.fromSTEB(
                                              Spacing.xLarge,
                                              Spacing.small,
                                              Spacing.xLarge,
                                              0,
                                            ),
                                        child: JeebRefreshFailedNote(
                                          failure: state.refreshError!,
                                          identifier:
                                              'notifications_refresh_error',
                                          onDismiss:
                                              cubit.acknowledgeRefreshError,
                                          onRetry: cubit.refresh,
                                        ),
                                      ),
                                    if (state.degraded)
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.fromSTEB(
                                              Spacing.xLarge,
                                              Spacing.small,
                                              Spacing.xLarge,
                                              0,
                                            ),
                                        child: JeebInfoNote.muted(
                                          identifier:
                                              'notifications_cached_note',
                                          icon: Icons.cloud_off,
                                          text: AppLocalizations.of(
                                            context,
                                          ).notificationsShowingCached,
                                        ),
                                      ),
                                    Expanded(
                                      child: !state.hasItems
                                          ? _EmptyBody(copy: copy)
                                          : _LoadedList(
                                              items: state.items,
                                              copy: copy,
                                            ),
                                    ),
                                  ],
                                ),
                              );
                          }
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty = `loaded` + an empty list (NOT a fifth status, §3), in a scrollable
/// so the pull-to-refresh still works on an empty inbox.
///
/// E4 (`parcel`) is R21's own empty tile and the nearest subject: a list of
/// things that happened, empty. Not E2's `radar` (which implies an outstanding
/// broadcast this surface never has) and not E1 (a compose prompt). No CTA —
/// nothing routes to "make a notification happen", and the E2 ruling is that an
/// unmounted CTA beats a destination-less one.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.copy});

  /// R21/E4: the illustration sits high, not centred in the residual band.
  static const double topGap = Sizes.threeXLarge;

  final NotificationsL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(
        top: topGap,
        bottom: Sizes.sixXLarge,
      ),
      children: [
        JeebEmptyState(
          identifier: 'notifications_empty',
          reason: JeebEmptyStateReason.nothingYet,
          variant: JeebEmptyStateVariant.parcel,
          headline: copy.emptyTitle,
          body: copy.emptyBody,
        ),
      ],
    );
  }
}

/// The loading and error twins of [_EmptyBody] — same illustration, kit
/// skeleton / danger tint, centred in the residual band (R21's `_StateBlock`).
class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.status,
    required this.headline,
    required this.identifier,
  });

  final JeebEmptyStateStatus status;
  final String headline;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    return JeebStateHost(
      child: JeebEmptyState(
        status: status,
        variant: JeebEmptyStateVariant.parcel,
        headline: headline,
        identifier: identifier,
      ),
    );
  }
}

/// The cold-read failure. `failureCopy` supplies both lines, and a 401 gets
/// the sign-in exit rather than a Retry that cannot win.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.state});

  final NotificationsListState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final AppFailure failure = state.appFailure ?? const UnknownFailure();
    final unauthorized = state.error == NotificationsFailure.unauthorized;
    return JeebStateHost(
      child: JeebFailureBlock(
        failure: failure,
        identifier: 'notifications_error',
        variant: JeebEmptyStateVariant.parcel,
        retryIdentifier: 'notifications_retry_cta',
        onRetry: failure.isRetryable
            ? () => context.read<NotificationsListCubit>().retry()
            : null,
        onExit: () => unauthorized
            ? context.goNamed('login')
            : (context.canPop() ? context.pop() : context.go('/')),
        exitLabel: unauthorized ? l10n.actionSignIn : l10n.actionBack,
        exitIdentifier: unauthorized ? 'notifications_error_signin_cta' : null,
      ),
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
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        Spacing.xLarge,
      ),
      itemCount: items.length,
      // R21 `gap:11px` on the 4px scale; the outlines ARE the separation — a
      // divider between two outlined cards draws a third line nobody asked for.
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
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

  /// NOTIF-04: a row that cannot address a destination says so instead of
  /// swallowing the tap.
  void _cannotOpen(BuildContext context) => showJeebSnack(
    context,
    identifier: 'notifications_cannot_open',
    message: AppLocalizations.of(context).notificationsCannotOpen,
  );

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
        // F8: `offer_accepted` addresses a jeeber surface; a client holding one
        // (leaked/stale row) has no destination for it.
        if (deepLinkRefusedForRole(
          NotificationMessage(
            id: item.id,
            category: NotificationCategory.offerAccepted,
            title: item.title,
            body: item.body,
            receivedAt: DateTime.now(),
            data: <String, String>{'requestId': ?ref},
          ),
          role: context.read<RoleCubit>().state,
        )) {
          _cannotOpen(context);
          break;
        }
        // F8 (device run 2): an `offer_accepted` row names ONE conversation.
        // With no ref there is no destination — home is a different screen.
        if (ref == null) {
          _cannotOpen(context);
          break;
        }
        context.goNamed('chat-detail', pathParameters: {'id': ref});
        break;

      // Order status → the addressed conversation thread.
      case NotificationKind.status:
        if (ref != null) {
          context.goNamed('chat-detail', pathParameters: {'id': ref});
        } else {
          _cannotOpen(context);
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
      // F8 (device run 2): no `ref` → no offer list to open, so say so rather
      // than dropping the tap on home (the resolver's id-less `'/'` sentinel).
      case NotificationKind.offer:
        if (ref == null) {
          _cannotOpen(context);
          break;
        }
        final offerTarget = deepLinkForMessage(
          NotificationMessage(
            id: item.id,
            category: NotificationCategory.newOffer,
            title: item.title,
            body: item.body,
            receivedAt: DateTime.now(),
            data: {'requestId': ref},
          ),
        );
        if (offerTarget != null) {
          context.push(offerTarget);
        } else {
          _cannotOpen(context);
        }
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
        } else {
          _cannotOpen(context);
        }
        break;

      // Confirm-receipt → the delivered-receipt prompt (`/orders/:id/receipt`);
      // `ref` is the deliveryId.
      case NotificationKind.confirmReceipt:
        if (ref != null) {
          context.goNamed('delivered-receipt', pathParameters: {'id': ref});
        } else {
          _cannotOpen(context);
        }
        break;

      // Marketing → customer-orders-home (Requests tab) — a shell tab.
      case NotificationKind.marketing:
        context.goNamed('shell');
        break;

      case NotificationKind.dispute:
        if (ref != null) {
          context.pushNamed(
            'dispute-status',
            pathParameters: <String, String>{'id': ref},
          );
        } else {
          _cannotOpen(context);
        }
        break;

      case NotificationKind.support:
        if (ref == null) {
          context.pushNamed('support-ticket');
        } else {
          context.pushNamed(
            'support-ticket-detail',
            pathParameters: <String, String>{'id': ref},
          );
        }
        break;

      // G3: new_request → the request screen. CONSUME the push-tap resolver
      // (deepLinkForMessage, fix/push-tap-routing) rather than re-mapping the
      // route here, so the inbox row and the push tap can never diverge —
      // `/jeeber/requests/:id` already handles cache recovery + graceful
      // fallback for taken/expired requests. Pushed (not go) so back returns
      // to the inbox.
      case NotificationKind.newRequest:
        if (ref == null) {
          _cannotOpen(context);
          break;
        }
        final newRequestMessage = NotificationMessage(
          id: item.id,
          category: NotificationCategory.newRequest,
          title: item.title,
          body: item.body,
          receivedAt: DateTime.now(),
          data: {'requestId': ref},
        );
        // F8: the resolver answers `/` for a client here — home is not this
        // row's destination, so say the row can't be opened and stay put.
        if (deepLinkRefusedForRole(
          newRequestMessage,
          role: context.read<RoleCubit>().state,
        )) {
          _cannotOpen(context);
          break;
        }
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
        if (target != null) {
          context.push(target);
        } else {
          _cannotOpen(context);
        }
        break;

      // Unknown / unmapped — mark-read only, stay on the inbox (AP-9: never
      // fabricate a destination the row can't address).
      case NotificationKind.unknown:
        _cannotOpen(context);
        break;
    }
  }
}
