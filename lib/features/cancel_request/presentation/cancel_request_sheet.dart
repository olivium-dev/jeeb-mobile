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
                  Icon(
                    Icons.help_outline,
                    size: Sizes.sixXLarge,
                    color: theme.colorScheme.primary,
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
