import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/notifications/application/push_refresh_signals.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_scrim.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../application/cancel_request_cubit.dart';
import '../application/cancel_request_state.dart';
import '../data/fake_cancel_request_repository.dart';
import '../domain/cancel_request_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

class CancelRequestSheet extends StatelessWidget {
  const CancelRequestSheet({
    super.key,
    required this.requestId,
    this.repository,
    this.onCancelled,
    this.onKept,
    this.initialState,
  });

  final String requestId;

  final CancelRequestState? initialState;

  final CancelRequestRepository? repository;

  final VoidCallback? onCancelled;

  final VoidCallback? onKept;

  CancelRequestRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<CancelRequestRepository>()) {
      return sl<CancelRequestRepository>();
    }
    return FakeCancelRequestRepository();
  }

  static Future<bool?> show(
    BuildContext context, {
    required String requestId,
    CancelRequestRepository? repository,
  }) {
    final rootContext = context;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: JeebScrim.barrier(context),
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => CancelRequestSheet(
        requestId: requestId,
        repository: repository,
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
        if (sl.isRegistered<PushRefreshSignals>()) {
          sl<PushRefreshSignals>().signalStatusChange();
        }
        onCancelled?.call();
      },
      builder: (context, state) {
        final inFlight = state.isInFlight;
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
                  // Cancelling before an offer is FREE (D69), so this asks a
                  // question — the info role, never the rationed accent.
                  Icon(
                    Icons.help_outline,
                    size: Sizes.sixXLarge,
                    color: context.jeebRoles.info,
                  ),
                  const SizedBox(height: Spacing.medium),
                  Text(
                    l10n.cancellationTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.medium),
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
                  Semantics(
                    identifier: 'cancel_request_keep_cta',
                    container: true,
                    button: true,
                    enabled: !inFlight,
                    label: l10n.deliveryCancelDialogDismiss,
                    onTap: inFlight ? null : onKept,
                    // `OmdsPrimaryButton.outlined` inks BOTH its 1.5px border
                    // and its label from `colorScheme.primary` — #D73B00 here.
                    child: ExcludeSemantics(
                      child: Theme(
                        data: theme.copyWith(
                          colorScheme: theme.colorScheme.copyWith(
                            primary: theme.colorScheme.secondary,
                          ),
                        ),
                        child: OmdsPrimaryButton(
                          key: const Key('cancel-request-keep-cta'),
                          text: l10n.deliveryCancelDialogDismiss,
                          variant: OmdsButtonVariant.outlined,
                          isEnabled: !inFlight,
                          onTap: () => onKept?.call(),
                        ),
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

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    // Shared drag-handle treatment: inert chrome takes the .22 glass rung.
    // Matches the sign-out grabber and the chat confirm sheet.
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: semantics.glassBorderVivid,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width with room for the idle stack (handle → 64 pt icon → title →
/// two-line D69 note → 48 pt confirm → 48 pt keep), measured at 400 pt EN /
const Size _cancelRequestSheetIdleBox = Size(390, 420);

/// The same stack plus the inline error line — 448 pt EN for the one-line
/// 409 / generic copy.
const Size _cancelRequestSheetErrorBox = Size(390, 470);

/// The two-line network error, the tallest the sheet gets at 100% — 464 pt EN.
/// Deliberately NOT sized for the matrix's 200% rendering (848 pt): no
const Size _cancelRequestSheetNetworkErrorBox = Size(390, 490);

/// The narrowest phone the app supports, and the taller box its extra wrapping
/// needs — the network failure reaches 480 pt at 100% here.
const Size _cancelRequestSheetNarrowBox = Size(320, 500);

/// Width of the smallest supported phone (iPhone SE 1st-gen class).
const double _cancelRequestSheetSmallPhoneWidth = 320;

/// A repository with no transport at all.
/// [FakeCancelRequestRepository] would also be inert, but it is a mutable
/// recorder built for assertions; this one is `const`, records nothing, and
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
        requestId: 'req-client-001-pending',
        repository: _CancelRequestSheetCannedRepository(failure: failure),
        initialState: CancelRequestState(status: status, error: failure),
        // No-ops on purpose. Production pops the sheet and routes to
        onCancelled: () {},
        onKept: () {},
      ),
    ),
  );
}

/// The default reading, and the one line this sheet exists to say: cancelling
/// before an offer is accepted is **free** (D69).
@JeebPreview(
  group: 'cancel_request',
  name: 'Idle · free before accept',
  size: _cancelRequestSheetIdleBox,
  matrix: true,
)
Widget cancelRequestSheetIdle() => _cancelRequestSheetHosted();

/// The cancel is in flight — the re-entrancy guard, made visible.
/// `confirmCancel()` returns early while `isInFlight`, and the sheet backs that
@JeebPreview(
  group: 'cancel_request',
  name: 'Confirming · in flight',
  size: _cancelRequestSheetIdleBox,
)
Widget cancelRequestSheetConfirming() =>
    _cancelRequestSheetHosted(status: CancelRequestStatus.inFlight);

/// 409 — the request advanced past the cancellable window while the sheet was
/// open, so it can no longer be cancelled.
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
/// A connection timeout is the one case where the app genuinely does not know
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
