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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/cancel_request/cancel_request_sheet_preview_test.dart
// ===========================================================================
//
// Widget previews for [CancelRequestSheet] — run with
// `flutter widget-preview start`.
//
// JM-030 `cancel-request-confirm` is a four-line sheet, and every line of it is
// a promise: cancelling now is FREE (D69), and the thing that just failed
// either can be retried or cannot. The sprint-009 cycle-4 fix was precisely
// about *which sentence* the user is shown — the mock-era sheet swallowed every
// failure and reported success while the gateway still had the request live, so
// the surface said "cancelled" and the request stayed pending. What replaced it
// is three different error strings behind one `CancelRequestFailure` enum, and
// the only way to check that they read correctly, wrap correctly and mirror
// correctly is to look at them.
//
// **Network-free by construction.** Two seams are used and neither can reach a
// gateway:
//
// * `initialState:` presets the [CancelRequestCubit]'s state — the DT-04 seam
//   the widget already documents — so `inFlight` and each `failed` variant is
//   reached without driving `confirmCancel()` at all.
// * `repository:` takes [_CancelRequestSheetCannedRepository], a local fake
//   with no transport of any kind. Passing it explicitly closes the resolution
//   chain in `_resolveRepository()`: left null the sheet reaches for
//   `sl<CancelRequestRepository>()`, and in production that is
//   `DioCancelRequestRepository`, i.e. a live `DELETE /v1/requests/{id}`. A
//   preview must never depend on whether the canvas happened to build the DI
//   graph.
//
// `requestId` is the `req-client-001-pending` fixture
// `test/features/cancel_request/cancel_request_sheet_test.dart` uses, so the
// previews and the widget tests stay directly comparable.
//
// **What the canvas shows that the widget test does not.** That file asserts
// the four semantics ids, the two callbacks and the 409 copy; it never looks at
// the sheet. Measured heights of the sheet content at 390 pt wide, EN / AR:
//
// | state            | 100%      | 200%      |
// |------------------|-----------|-----------|
// | idle             | 400 / 380 | 672 / 592 |
// | failed · 409     | 448 / 428 | 784 / 704 |
// | failed · generic | 448 / 428 | 848 / 736 |
// | failed · network | 464 / 428 | **848** / 736 |
//
// The 200% column is the finding. The body is a [Column] with
// `mainAxisSize.min` and no scroll fallback, and `showModalBottomSheet(
// isScrollControlled: true)` grants height — it does not add scrolling. On a
// 390×844 phone the network-failure state at 200% is `A RenderFlex overflowed
// by 4.0 pixels on the bottom`; on a 320×568 phone the *idle* sheet already
// overflows by 184 px and the network failure by 424 px, and what is below the
// fold is the bottom of the stack — `cancel_request_confirm_cta` and
// `cancel_request_keep_cta` both. A user at the accessibility ceiling is shown
// a failed cancel with neither button. See
// [cancelRequestSheetNarrowPhone].
//
// The second thing to look at is the Keep pill. `OmdsPrimaryButton` is a FIXED
// 48 pt (`Sizes.fourXLarge`) at every text scale and its label is a bare [Text]
// in a `Center` with no `maxLines` and no ellipsis, so a label that grows is
// clamped and painted over the pill edge rather than growing it. At 200% "Keep
// delivery" measures 307 × 45 inside the 342 × 48 pill at 390 pt, and 237 × 45
// inside a 272 × 48 pill at 320 pt: two lines, three logical pixels of
// horizontal slack, three of vertical. AR ("إبقاء التوصيلة") lands in the same
// place. One more word in either language clips the label off its own button.
//
// Measurements come from `flutter test`, whose substituted font is wider and
// taller than the production Inter face, so read them as the pessimistic
// bound — except the 320 pt overflow, which is far past any font-metric slack.
//
// **Tapping in the canvas.** Confirm runs the real `confirmCancel()` against
// the canned repository, so the idle preview walks idle → inFlight → succeeded
// and then calls a no-op `onCancelled` (production pops the sheet and
// `go('/')`s to customer-orders-home; neither belongs in a canvas). The failed
// previews keep failing. Hot-restart to reset.

/// Phone width with room for the idle stack (handle → 64 pt icon → title →
/// two-line D69 note → 48 pt confirm → 48 pt keep), measured at 400 pt EN /
/// 380 pt AR.
const Size _cancelRequestSheetIdleBox = Size(390, 420);

/// The same stack plus the inline error line — 448 pt EN for the one-line
/// 409 / generic copy.
const Size _cancelRequestSheetErrorBox = Size(390, 470);

/// The two-line network error, the tallest the sheet gets at 100% — 464 pt EN.
///
/// Deliberately NOT sized for the matrix's 200% rendering (848 pt): no
/// phone-shaped box contains that, and the stripes it paints in the canvas
/// belong to the widget, not to the canvas.
const Size _cancelRequestSheetNetworkErrorBox = Size(390, 490);

/// The narrowest phone the app supports, and the taller box its extra wrapping
/// needs — the network failure reaches 480 pt at 100% here.
const Size _cancelRequestSheetNarrowBox = Size(320, 500);

/// Width of the smallest supported phone (iPhone SE 1st-gen class).
const double _cancelRequestSheetSmallPhoneWidth = 320;

/// A repository with no transport at all.
///
/// [FakeCancelRequestRepository] would also be inert, but it is a mutable
/// recorder built for assertions; this one is `const`, records nothing, and
/// makes the canned outcome explicit at each call site. With [failure] set,
/// tapping Confirm in the canvas reaches the matching error copy for real
/// rather than falling back to whatever the preset [initialState] said.
class _CancelRequestSheetCannedRepository implements CancelRequestRepository {
  const _CancelRequestSheetCannedRepository({this.failure});

  /// When set, `cancelRequest` throws this instead of succeeding.
  final CancelRequestFailure? failure;

  @override
  Future<void> cancelRequest({required String requestId}) async {
    final CancelRequestFailure? f = failure;
    if (f != null) throw CancelRequestException(f);
  }
}

/// Mounts the sheet the way `showModalBottomSheet` presents it — bottom-anchored
/// content on the surface colour — without needing a [Navigator] to push onto.
///
/// The width pin is load-bearing: the render tests pump an 800 px viewport and
/// ignore [JeebPreview.size], so without it CI would be reviewing a bottom
/// sheet at a width no phone has. Bottom anchoring reproduces the real
/// geometry: the sheet grows upward from the bottom edge and, past the box,
/// overflows at the bottom of its own [Column] exactly as it does on a phone.
Widget _cancelRequestSheetHosted({
  CancelRequestFailure? failure,
  CancelRequestStatus status = CancelRequestStatus.idle,
  double width = 390,
}) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(
      width: width,
      child: CancelRequestSheet(
        // The fixture id used throughout
        // test/features/cancel_request/cancel_request_sheet_test.dart.
        requestId: 'req-client-001-pending',
        repository: _CancelRequestSheetCannedRepository(failure: failure),
        initialState: CancelRequestState(status: status, error: failure),
        // No-ops on purpose. Production pops the sheet and routes to
        // customer-orders-home; `go` without a GoRouter ancestor would throw.
        onCancelled: () {},
        onKept: () {},
      ),
    ),
  );
}

/// The default reading, and the one line this sheet exists to say: cancelling
/// before an offer is accepted is **free** (D69).
///
/// Two mismatches are visible here and both are deliberate-for-now, filed in
/// 50_ROUTE_REQUESTS: the heading borrows `cancellationTitle` — "Cancel
/// Delivery" — and the dismiss CTA borrows `deliveryCancelDialogDismiss` —
/// "Keep delivery". There is no delivery yet. That is the whole premise of the
/// sheet, and it is stated in the sentence directly between them. If
/// `cancelRequestTitle` / `cancelRequestKeepCta` ever land, this preview is
/// where the copy is checked.
///
/// The matrix is on because the free note is the load-bearing string and it is
/// the one that moves: 2 lines EN, 1 line AR, and at 200% it is what pushes the
/// CTAs toward the fold.
@JeebPreview(
  group: 'cancel_request',
  name: 'Idle · free before accept',
  size: _cancelRequestSheetIdleBox,
  matrix: true,
)
Widget cancelRequestSheetIdle() => _cancelRequestSheetHosted();

/// The cancel is in flight — the re-entrancy guard, made visible.
///
/// `confirmCancel()` returns early while `isInFlight`, and the sheet backs that
/// up in the UI: both CTAs report `enabled: false` with a null `onTap`, so the
/// sheet cannot be double-fired or torn down mid-call.
///
/// **What this rendering shows: there is no word on screen for what is
/// happening.** `OmdsLoadingButton` swaps `text` for `OmdsButtonLoading`
/// whenever `isLoading`, so the confirm label is gone and a 20 pt spinner
/// stands in its place; the surrounding `Semantics` keeps `label:
/// l10n.actionCancel` unconditionally and the child is `ExcludeSemantics`, so a
/// screen reader announces a disabled "Cancel" button and nothing else. The
/// only other movement is the Keep pill going outlined-disabled — a 45%-alpha
/// border and a 90%-alpha label, which is the pair worth judging in the AR dark
/// rendering.
@JeebPreview(
  group: 'cancel_request',
  name: 'Confirming · in flight',
  size: _cancelRequestSheetIdleBox,
)
Widget cancelRequestSheetConfirming() =>
    _cancelRequestSheetHosted(status: CancelRequestStatus.inFlight);

/// 409 — the request advanced past the cancellable window while the sheet was
/// open, so it can no longer be cancelled.
///
/// This is the race the customer actually loses: a Jeeber accepted between the
/// tap that opened the sheet and the tap that confirmed it. The copy is the one
/// dedicated string in the set — "This request can no longer be cancelled." —
/// and it is a *terminal* statement sitting directly above a Confirm button
/// that is still live and still says "Cancel". Retrying it can only produce the
/// same 409. The state to judge is whether the sentence is emphatic enough to
/// stop someone from tapping the red button again.
@JeebPreview(
  group: 'cancel_request',
  name: 'Failed · no longer cancellable (409)',
  size: _cancelRequestSheetErrorBox,
)
Widget cancelRequestSheetFailedConflict() => _cancelRequestSheetHosted(
      status: CancelRequestStatus.failed,
      failure: CancelRequestFailure.conflict,
    );

/// The retryable failure, and the longest copy this sheet can lay out.
///
/// A connection timeout is the one case where the app genuinely does not know
/// whether the request was released, so the sheet stays open with the shared
/// `loginNetworkError` string and the Confirm CTA doubles as Retry — without
/// ever saying so, because its label is still `actionCancel`.
///
/// The matrix is on because this is the state that breaks. 464 pt at 100%, 848
/// at 200% against an 844 pt phone: `A RenderFlex overflowed by 4.0 pixels on
/// the bottom`, and the pixels lost are the bottom of the Keep pill. AR is
/// shorter (428 / 736) and clears it — so the EN 200% card is the only one of
/// the three that shows the defect, which is exactly why they are worth seeing
/// side by side.
@JeebPreview(
  group: 'cancel_request',
  name: 'Failed · network (retryable)',
  size: _cancelRequestSheetNetworkErrorBox,
  matrix: true,
)
Widget cancelRequestSheetFailedNetwork() => _cancelRequestSheetHosted(
      status: CancelRequestStatus.failed,
      failure: CancelRequestFailure.network,
    );

/// Everything else — 5xx, a malformed body, a 404 the caller cannot explain,
/// a 403 they must not be told about — collapsed onto one generic sentence.
///
/// This is the cycle-4 no-swallow guarantee at its least specific, and the
/// state that most needs looking at: `_errorCopyFor` routes only `conflict` and
/// `network` to dedicated strings, so `notFound`, `forbidden` and `unknown` all
/// land here. If this preview ever renders blank, a failure has stopped
/// surfacing and the P0 "cancellations never reach the server" bug is back.
@JeebPreview(
  group: 'cancel_request',
  name: 'Failed · generic (5xx)',
  size: _cancelRequestSheetErrorBox,
)
Widget cancelRequestSheetFailedGeneric() => _cancelRequestSheetHosted(
      status: CancelRequestStatus.failed,
      failure: CancelRequestFailure.unknown,
    );

/// The network failure at 320 pt — the narrowest phone, and where the sheet
/// stops fitting at all.
///
/// 480 pt of content at 100% against a 568 pt screen leaves 88 pt of scrim, so
/// it is fine as drawn. At 200% it is 992 pt EN / 840 pt AR, i.e. `A RenderFlex
/// overflowed by 424 pixels on the bottom` — and the *idle* sheet overflows by
/// 184 px at this width before any error is shown at all. There is no
/// `SingleChildScrollView` under the [Column] and `showModalBottomSheet` does
/// not add one, so both CTAs are simply not on screen.
///
/// The Keep pill is the other reason for this width: at 200% its label wraps to
/// 237 × 45 inside a 272 × 48 fixed-height pill, which is three logical pixels
/// of slack in each direction before "Keep delivery" is painted over its own
/// border.
@JeebPreview(
  group: 'cancel_request',
  name: 'Narrow phone · 320 pt',
  size: _cancelRequestSheetNarrowBox,
)
Widget cancelRequestSheetNarrowPhone() => _cancelRequestSheetHosted(
      status: CancelRequestStatus.failed,
      failure: CancelRequestFailure.network,
      width: _cancelRequestSheetSmallPhoneWidth,
    );
