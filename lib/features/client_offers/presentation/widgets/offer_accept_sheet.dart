import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/formatting/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/offer_accept_cubit.dart';
import '../../application/offer_accept_state.dart';
import '../../data/fake_offers_repository.dart';
import '../../domain/offer.dart';
import '../../domain/offers_repository.dart';

/// `offer-accept-confirm` (JM-029, D11/D71/D69) — the accept-offer confirmation
/// sheet.
///
/// The D11/D71 comprehension gate: accepting an offer is consequential — it
/// captures the fee and closes every losing offer — so it is fronted by this
/// explicit confirm step instead of firing inline from the offer card
/// (`offer-review-list`, JM-028). The sheet shows the chosen Jeeber's name, the
/// "Pay $N cash on delivery" amount (D11), and the "other offers will close"
/// note (D71), then:
///   - [offer_accept_confirm_cta] → `POST /v1/offers/:offerId/accept` (fee
///     captured + losers superseded server-side), then navigates to
///     `order-chat` (`/chat/<conversationId>`) so the pinned summary renders.
///   - [offer_accept_cancel_cta]  → dismisses, returning to `offer-review-list`.
///
/// It is a **sheet, not a route** (40_GUARDRAILS_ARCH §5 — sheets are
/// `showModalBottomSheet`, not `GoRoute`s; mirrors `SocialCollisionSheet`).
/// It owns its own async surface via [OfferAcceptCubit].
///
/// Semantics identifiers exposed (EXACT, 63_W1_TEST_PLAN §2.9):
///   - `offer_accept_sheet`              — bottom-sheet root
///   - `offer_accept_jeeber_name`        — "Accept X's offer?" / Jeeber name
///   - `offer_accept_price_label`        — "Pay $N cash on delivery" (D11)
///   - `offer_accept_other_offers_note`  — "Other offers will close" (D71)
///   - `offer_accept_confirm_cta`        — Confirm → capture fee → order-chat
///   - `offer_accept_cancel_cta`         — Cancel → back to offer-review-list
class OfferAcceptSheet extends StatelessWidget {
  const OfferAcceptSheet({
    super.key,
    required this.offer,
    required this.requestId,
    this.repository,
    this.onConfirmed,
    this.onCancelled,
  });

  /// The offer being confirmed. Supplies the Jeeber name + fee + currency the
  /// sheet renders; [Offer.id] is the offer accepted server-side.
  final Offer offer;

  /// The parent request id — paired with [Offer.id] for the accept call.
  final String requestId;

  /// Optional repository override. Production builds leave this null and
  /// resolve [OffersRepository] from DI (DioOffersRepository). Widget tests
  /// inject a scripted instance.
  final OffersRepository? repository;

  /// Fired once the accept call succeeds, with the full [OfferAcceptResult] —
  /// the server `conversationId` (order-chat target) AND the `deliveryId` of the
  /// active delivery the accept just created (used to make live tracking
  /// reachable). Either may be null when the gateway surfaces none. [show] wires
  /// the default `order-chat` navigation; an explicit callback is for tests.
  final void Function(OfferAcceptResult result)? onConfirmed;

  /// Fired when the user cancels (or the accept fails and they back out). [show]
  /// wires the default dismiss; an explicit callback is for tests.
  final VoidCallback? onCancelled;

  OffersRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<OffersRepository>()) return sl<OffersRepository>();
    return FakeOffersRepository();
  }

  /// Opens the accept-confirm sheet over the current route with a dimmed scrim
  /// and the standard OMDS top-rounded sheet shape (matches
  /// `SocialCollisionSheet`). Confirm captures the fee then navigates to
  /// `order-chat`; cancel dismisses back to `offer-review-list`. Both pop the
  /// sheet FIRST so the destination's signature id (`order_chat_pinned_summary`
  /// / `offer_review_list_root`) is the only thing the Maestro flow sees.
  ///
  /// EDGE (21_NAV_PLAN §C, JM-029, D11/D71): the confirm path resolves to
  /// `chat-detail` (`/chat/:id`) — the `order-chat` blueprint surface — keyed on
  /// the [requestId], NEVER on `result.conversationId`. CHAT-CONTRACT
  /// (sprint-8f, T-APP-1): the accept response's conversationId can be a PHANTOM
  /// (`conv-for-<requestId>`) the gateway mints before the real conversation
  /// exists; routing on it lands the client in a thread the winning jeeber never
  /// joins. So we route by request id and let `ChatDetailScreen` resolve-or-
  /// create the REAL conversation by request id (the one shared by BOTH the
  /// customer and the winning jeeber). The accept response also carries the
  /// server-created `deliveryId` (the accepted offer is a real active delivery);
  /// we forward it as the `deliveryId` query param so the order-chat's "Track
  /// order" CTA (G5, `OfferAcceptedBanner`) is reachable for an offer accepted
  /// straight from the review list — the conversation phase is `accepted` on
  /// load but the chat would otherwise have no delivery id to track.
  static Future<void> show(
    BuildContext context, {
    required Offer offer,
    required String requestId,
    OffersRepository? repository,
  }) {
    final rootContext = context;
    final scrim = Theme.of(context).colorScheme.onSecondaryContainer.withValues(
      alpha: UIConstants.opacityHigh,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => OfferAcceptSheet(
        offer: offer,
        requestId: requestId,
        repository: repository,
        onConfirmed: (result) {
          Navigator.of(sheetContext).pop();
          // CHAT-CONTRACT (sprint-8f, T-APP-1): open the order-chat by the
          // REQUEST id, NEVER by `result.conversationId`. The accept response's
          // conversationId may be a PHANTOM (`conv-for-<requestId>`) the gateway
          // synthesises before the real conversation exists; trusting it routes
          // the client into a chat that is not the one the winning jeeber joins,
          // so the two participants never share a thread. `ChatDetailScreen`
          // treats the route param as the conversation's CORRELATION KEY and
          // resolve-or-creates the REAL server conversation by request id (the
          // single conversation BOTH the customer and the winning jeeber are
          // participants of, regardless of when the jeeber offered). So we hand
          // it the request id and discard the (possibly phantom) conversationId.
          final deliveryId = result.deliveryId;
          rootContext.goNamed(
            'chat-detail',
            pathParameters: {'id': requestId},
            queryParameters: {
              if (deliveryId != null && deliveryId.isNotEmpty)
                'deliveryId': deliveryId,
            },
          );
        },
        onCancelled: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<OfferAcceptCubit>(
      create: (_) => OfferAcceptCubit(
        repository: repo,
        requestId: requestId,
        offerId: offer.id,
      ),
      child: _OfferAcceptView(
        offer: offer,
        onConfirmed: onConfirmed,
        onCancelled: onCancelled,
      ),
    );
  }
}

class _OfferAcceptView extends StatelessWidget {
  const _OfferAcceptView({
    required this.offer,
    this.onConfirmed,
    this.onCancelled,
  });

  final Offer offer;
  final void Function(OfferAcceptResult result)? onConfirmed;
  final VoidCallback? onCancelled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Lane item 3 (currency unification): single MoneyFormat across surfaces.
    final feeFormatted = MoneyFormat.format(
      offer.fee,
      currency: offer.currency,
    );
    // W6/SW-08: the confirm title headlines the Jeeber's name — suppress a
    // synthetic handle / UUID the same way the offer card does, so the
    // accept-ONE moment never reads "9acb579d-…'s offer was accepted".
    final jeeberDisplayName =
        displayNameOrNull(offer.jeeberName) ?? l10n.offersCardJeeberFallback;
    return BlocConsumer<OfferAcceptCubit, OfferAcceptState>(
      listenWhen: (prev, next) =>
          prev.status != next.status &&
          next.status == OfferAcceptStatus.succeeded,
      listener: (context, state) {
        // Side effect only in the listener (never the builder) per
        // 40_GUARDRAILS_ARCH §3. Forward the full result so the navigation can
        // route to order-chat (conversationId) AND surface the tracking entry
        // (deliveryId).
        onConfirmed?.call(state.result ?? OfferAcceptResult.empty);
      },
      builder: (context, state) {
        return PopScope(
          // B-01: the accept POST is the accept-exactly-ONE moment. While it is
          // in flight the sheet must be NON-DISMISSIBLE — canPop:false blocks
          // the Android system-back gesture, the scrim tap, and the swipe-down
          // (all route pops go through the navigator's pop disposition). Without
          // this the user could dismiss mid-POST, get no success/failure signal,
          // and return to the list to fire a SECOND accept (double-accept). The
          // Confirm/Cancel CTAs are already inert while submitting; this closes
          // the remaining scrim/drag/back dismissal vectors.
          canPop: !state.isSubmitting,
          child: Semantics(
            identifier: 'offer_accept_sheet',
            // explicitChildNodes keeps each line + CTA as an independent,
            // id-addressable semantics node (matches SocialCollisionSheet) so
            // Maestro can assert/tap each one.
            explicitChildNodes: true,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.xLarge,
                  Spacing.small,
                  Spacing.xLarge,
                  Spacing.xLarge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetDragHandle(),
                    const SizedBox(height: Spacing.large),
                    // "Accept X's offer?" — the Jeeber name is the load-bearing
                    // data; framing reuses chatSystemOfferAcceptedNamed (a
                    // dedicated `offerAcceptTitle` is filed in 50_ROUTE_REQUESTS).
                    Semantics(
                      identifier: 'offer_accept_jeeber_name',
                      child: Text(
                        l10n.chatSystemOfferAcceptedNamed(jeeberDisplayName),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    // "Pay $N cash on delivery" (D11). Reuses offersCardFee
                    // ("{amount} {currency}") for the amount; a dedicated
                    // `offerAcceptPayCashOnDelivery` is filed in 50_ROUTE_REQUESTS.
                    Semantics(
                      identifier: 'offer_accept_price_label',
                      child: Text(
                        l10n.offersCardFee(feeFormatted, offer.currency),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    // "Other offers will close" (D71). Reuses chatOfferAcceptOnlyOne
                    // ("Accept only one offer"); a dedicated
                    // `offerAcceptOtherOffersClose` is filed in 50_ROUTE_REQUESTS.
                    Semantics(
                      identifier: 'offer_accept_other_offers_note',
                      child: Text(
                        l10n.chatOfferAcceptOnlyOne,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // Inline failure copy (sprint-009 scenario matrix #7). A
                    // failed accept — e.g. the 409 race where another accept
                    // closed the auction first — MUST tell the user why; the
                    // pre-fix sheet only listened for success and a failure
                    // silently stopped the spinner. Typed [OffersFailure] →
                    // l10n copy ("This request is no longer open." for the
                    // request-level closure). Confirm stays retryable; cancel
                    // returns to the review list, which re-loads and shows the
                    // closed banner.
                    if (state.status == OfferAcceptStatus.failed &&
                        state.error != null) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'offer_accept_error',
                        liveRegion: true,
                        child: Container(
                          key: const Key('offer-accept-error'),
                          padding: const EdgeInsets.all(Spacing.small),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: OmdsBorderRadius.small,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: Spacing.small),
                              Expanded(
                                child: Text(
                                  _failureCopy(l10n, state.error!),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.twoXLarge),
                    // CONFIRM → capture fee → order-chat. Disabled-while-submitting
                    // + spinner via the loading button; success fires the listener.
                    Semantics(
                      identifier: 'offer_accept_confirm_cta',
                      container: true,
                      button: true,
                      label: l10n.chatOfferAccept,
                      onTap: state.isSubmitting
                          ? null
                          : () => context.read<OfferAcceptCubit>().confirm(),
                      child: ExcludeSemantics(
                        child: OmdsLoadingButton(
                          key: const Key('offer-accept-confirm-cta'),
                          text: state.isSubmitting
                              ? l10n.chatOfferAccepting
                              : l10n.chatOfferAccept,
                          isLoading: state.isSubmitting,
                          onTap: () =>
                              context.read<OfferAcceptCubit>().confirm(),
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          borderRadius: OmdsBorderRadius.uiSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    // CANCEL → back to offer-review-list. Inert while submitting
                    // so a confirmed accept can't be torn down mid-flight.
                    Semantics(
                      identifier: 'offer_accept_cancel_cta',
                      container: true,
                      button: true,
                      label: l10n.actionCancel,
                      onTap: state.isSubmitting ? null : onCancelled,
                      child: ExcludeSemantics(
                        child: OMDSOutlinedButton(
                          key: const Key('offer-accept-cancel-cta'),
                          text: l10n.actionCancel,
                          enabled: !state.isSubmitting,
                          onTap: () => onCancelled?.call(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Typed accept failure → user copy. Mirrors the review-list mapping
  /// (`ClientOffersScreen._errorCopy`) so both surfaces speak identically.
  static String _failureCopy(AppLocalizations l10n, OffersFailure failure) {
    switch (failure) {
      case OffersFailure.network:
        return l10n.offersErrorNetwork;
      case OffersFailure.requestNotOpen:
        return l10n.offersErrorRequestNotOpen;
      case OffersFailure.offerNotPending:
        return l10n.offersErrorOfferNotPending;
      case OffersFailure.unknown:
        return l10n.offersErrorGeneric;
    }
  }
}

/// Centered M3 drag handle (32×4 pill) tinted with the brand primary — matches
/// the shared sheet handle styling used across the app's bottom sheets.
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}
