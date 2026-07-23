import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/notifications/application/push_refresh_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../application/cancel_request_cubit.dart';
import '../application/cancel_request_state.dart';
import '../data/fake_cancel_request_repository.dart';
import '../domain/cancel_request_repository.dart';

/// `cancel-request-confirm` (JM-030, D69) — the PRE-ACCEPT cancel sheet.
///
/// Before an offer is accepted there is no Jeeber and no locked price, so
/// cancelling a still-pending request is **free** — nothing is charged (D69).
/// The sheet states that explicitly, confirms → `customer-orders-home`
/// (`context.go('/')`, the role-aware shell Requests tab), and dismisses on keep.
///
/// It is a **sheet, not a route** (40_GUARDRAILS_ARCH §5 — sheets are
/// `showModalBottomSheet`, not `GoRoute`s; mirrors `OfferAcceptSheet` /
/// `SocialCollisionSheet`). It owns its async surface via [CancelRequestCubit].
/// It is explicitly NOT a reuse of `cancellation_screen.dart` (the post-accept
/// reason picker that may charge a fee — 20_GAP_MAP reconciliation note 7).
///
/// Invoked by the JM-026 waiting screen (`waiting_cancel_cta`) and the JM-028
/// offer-review screen (`offer_review_cancel_cta`) via [show].
///
/// Semantics identifiers exposed (EXACT, 63_W1_TEST_PLAN §2.10):
///   - `cancel_request_sheet`       — bottom-sheet root (signature id)
///   - `cancel_request_free_note`   — "free before accept, nothing charged" (D69)
///   - `cancel_request_confirm_cta` — Confirm → customer-orders-home
///   - `cancel_request_keep_cta`    — Keep / dismiss
class CancelRequestSheet extends StatelessWidget {
  const CancelRequestSheet({
    super.key,
    required this.requestId,
    this.repository,
    this.onCancelled,
    this.onKept,
    this.initialState,
  });

  /// The pre-accept request being cancelled.
  final String requestId;

  /// DT-04 screen-catalog / test seam: preset the cubit's initial state (e.g.
  /// `inFlight` / `failed`) so the sheet can be previewed already mid-flow.
  /// Null (default, production) starts idle exactly as before.
  final CancelRequestState? initialState;

  /// Optional repository override. Production builds leave this null and resolve
  /// [CancelRequestRepository] from DI (DioCancelRequestRepository). Widget
  /// tests inject a [FakeCancelRequestRepository] via this parameter.
  final CancelRequestRepository? repository;

  /// Fired once the cancel succeeds. [show] wires the default
  /// `pop(true)` + `context.go('/')` (customer-orders-home); an explicit
  /// callback is for tests.
  final VoidCallback? onCancelled;

  /// Fired when the user keeps the request (dismiss). [show] wires the default
  /// `pop(false)`; an explicit callback is for tests.
  final VoidCallback? onKept;

  CancelRequestRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<CancelRequestRepository>()) {
      // Production path: DioCancelRequestRepository over the gateway's
      // request-keyed DELETE /v1/requests/{id} (registered in
      // injection_container.dart — cycle-4; it was previously UNREGISTERED,
      // which silently routed every real cancel into the in-memory fake).
      return sl<CancelRequestRepository>();
    }
    // Defensive fallback so the sheet never crashes if DI is absent entirely
    // (router-less widget harnesses / dev-seam entries without the DI batch).
    return FakeCancelRequestRepository();
  }

  /// Opens the cancel-confirm sheet over the current route with a dimmed scrim
  /// and the standard OMDS top-rounded sheet shape (matches [OfferAcceptSheet]).
  /// Confirm releases the request then routes to `customer-orders-home`; keep
  /// dismisses back to the caller (waiting / offer-review). Both pop the sheet
  /// FIRST so the destination's signature id is the only thing Maestro sees.
  ///
  /// Returns `true` when the request was cancelled, `false`/`null` when kept.
  static Future<bool?> show(
    BuildContext context, {
    required String requestId,
    CancelRequestRepository? repository,
  }) {
    final rootContext = context;
    final scrim = Theme.of(context).colorScheme.onSecondaryContainer.withValues(
      alpha: UIConstants.opacityHigh,
    );
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => CancelRequestSheet(
        requestId: requestId,
        repository: repository,
        // EDGE (63_W1_TEST_PLAN §3 jm-030, JM-023): confirm → customer-orders-home.
        // `context.go('/')` resolves the role-aware shell Requests tab (same
        // entry registration/OTP screens use); pop the sheet first.
        onCancelled: () {
          Navigator.of(sheetContext).pop(true);
          rootContext.go('/');
        },
        onKept: () => Navigator.of(sheetContext).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CancelRequestCubit>(
      create: (_) => CancelRequestCubit(
        repository: _resolveRepository(),
        requestId: requestId,
        initialState: initialState,
      ),
      child: _CancelRequestView(onCancelled: onCancelled, onKept: onKept),
    );
  }
}

class _CancelRequestView extends StatelessWidget {
  const _CancelRequestView({this.onCancelled, this.onKept});

  final VoidCallback? onCancelled;
  final VoidCallback? onKept;

  /// Maps the typed repository failure onto user copy. Network keeps the
  /// shared retryable connection string (the Confirm CTA doubles as retry);
  /// a 409 gets the dedicated "no longer cancellable" copy; everything else
  /// (404/403/5xx) uses the generic cancel error.
  static String _errorCopyFor(
    AppLocalizations l10n,
    CancelRequestFailure? failure,
  ) {
    return switch (failure) {
      CancelRequestFailure.conflict => l10n.cancelRequestErrorConflict,
      CancelRequestFailure.network => l10n.loginNetworkError,
      _ => l10n.cancelRequestErrorGeneric,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return BlocConsumer<CancelRequestCubit, CancelRequestState>(
      listenWhen: (prev, next) =>
          prev.status != next.status &&
          next.status == CancelRequestStatus.succeeded,
      listener: (context, state) {
        // Side effect only in the listener (never the builder) per
        // 40_GUARDRAILS_ARCH §3.
        //
        // The server confirmed the cancel — nudge every surface that renders
        // this request to re-pull so the cancelled row disappears from the
        // pending list immediately. Reuses the app-wide status-change bus
        // the customer home / tracking cubits already subscribe to.
        if (sl.isRegistered<PushRefreshSignals>()) {
          sl<PushRefreshSignals>().signalStatusChange();
        }
        onCancelled?.call();
      },
      builder: (context, state) {
        final inFlight = state.isInFlight;
        // cancel_request_sheet — signature root. explicitChildNodes keeps each
        // line + CTA an independent, id-addressable node (matches
        // OfferAcceptSheet) so Maestro can assert/tap each one.
        return Semantics(
          identifier: 'cancel_request_sheet',
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
                  Icon(
                    Icons.help_outline,
                    size: Sizes.sixXLarge,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: Spacing.medium),
                  // Heading. Reuses cancellationTitle ("Cancel Delivery"); a
                  // dedicated `cancelRequestTitle` ("Cancel this request?") is
                  // filed in 50_ROUTE_REQUESTS. Maestro keys on the root id, not
                  // text, so this is copy-polish.
                  Text(
                    l10n.cancellationTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.medium),
                  // cancel_request_free_note — the load-bearing D69 copy:
                  // "free before accept, nothing charged". No existing ARB key
                  // carries this (deliveryCancelDialogBody says the OPPOSITE),
                  // so this references the intended getter `cancelRequestFreeNote`
                  // (filed REQUIRED in 50_ROUTE_REQUESTS).
                  Semantics(
                    identifier: 'cancel_request_free_note',
                    child: Text(
                      l10n.cancelRequestFreeNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (state.status == CancelRequestStatus.failed) ...[
                    const SizedBox(height: Spacing.medium),
                    // Typed failure copy (cycle-4, no-swallow): 409 → "can no
                    // longer be cancelled"; network → retryable connection
                    // copy (confirm retries); 404/403/5xx → generic cancel
                    // error. The sheet stays open in every case so the user
                    // can retry or keep the request.
                    Semantics(
                      identifier: 'cancel_request_error',
                      child: Text(
                        _errorCopyFor(l10n, state.error),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Spacing.twoXLarge),
                  // cancel_request_confirm_cta — Confirm → customer-orders-home.
                  // Disabled-while-submitting + spinner via the loading button;
                  // success fires the listener. Reuses actionCancel ("Cancel");
                  // dedicated `cancelRequestConfirmCta` filed in 50_ROUTE_REQUESTS.
                  Semantics(
                    identifier: 'cancel_request_confirm_cta',
                    container: true,
                    button: true,
                    enabled: !inFlight,
                    label: l10n.actionCancel,
                    onTap: inFlight
                        ? null
                        : () => context
                              .read<CancelRequestCubit>()
                              .confirmCancel(),
                    child: ExcludeSemantics(
                      child: OmdsLoadingButton(
                        key: const Key('cancel-request-confirm-cta'),
                        text: l10n.actionCancel,
                        isLoading: inFlight,
                        isEnabled: !inFlight,
                        onTap: () =>
                            context.read<CancelRequestCubit>().confirmCancel(),
                        backgroundColor: theme.colorScheme.error,
                        textColor: theme.colorScheme.onError,
                        borderRadius: OmdsBorderRadius.uiSmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.small),
                  // cancel_request_keep_cta — Keep / dismiss. Inert while a
                  // confirm is in flight so it can't tear down mid-call. Reuses
                  // deliveryCancelDialogDismiss ("Keep delivery"); dedicated
                  // `cancelRequestKeepCta` ("Keep my request") filed in
                  // 50_ROUTE_REQUESTS.
                  Semantics(
                    identifier: 'cancel_request_keep_cta',
                    container: true,
                    button: true,
                    enabled: !inFlight,
                    label: l10n.deliveryCancelDialogDismiss,
                    onTap: inFlight ? null : onKept,
                    child: ExcludeSemantics(
                      child: OmdsPrimaryButton(
                        key: const Key('cancel-request-keep-cta'),
                        text: l10n.deliveryCancelDialogDismiss,
                        variant: OmdsButtonVariant.outlined,
                        isEnabled: !inFlight,
                        onTap: () => onKept?.call(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
