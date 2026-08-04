import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/notifications/domain/notification_deep_link.dart';
import '../../../core/notifications/domain/notification_message.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../application/notifications_list_cubit.dart';
import '../application/notifications_list_state.dart';
import '../data/empty_notifications_repository.dart';
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
                      BlocBuilder<
                        NotificationsListCubit,
                        NotificationsListState
                      >(
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
                              return _StateBlock(
                                status: JeebEmptyStateStatus.error,
                                headline: copy.errorTitle,
                                body:
                                    state.error == NotificationsFailure.network
                                    ? copy.networkError
                                    : null,
                                identifier: 'notifications_error',
                                action: JeebCtaButton.primary(
                                  label: copy.retry,
                                  identifier: 'notifications_retry_cta',
                                  onTap: () => context
                                      .read<NotificationsListCubit>()
                                      .refresh(),
                                ),
                              );
                            case NotificationsListStatus.loaded:
                              return OmdsPullToRefresh(
                                onRefresh: () => context
                                    .read<NotificationsListCubit>()
                                    .refresh(),
                                child: !state.hasItems
                                    ? _EmptyBody(copy: copy)
                                    : _LoadedList(
                                        items: state.items,
                                        copy: copy,
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
    this.body,
    this.action,
  });

  final JeebEmptyStateStatus status;
  final String headline;
  final String identifier;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState(
          status: status,
          variant: JeebEmptyStateVariant.parcel,
          headline: headline,
          body: body,
          identifier: identifier,
          action: action,
        ),
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
