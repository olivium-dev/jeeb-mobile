import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/prohibited_acknowledgment_repository.dart';
import '../domain/prohibited_item.dart';
import 'cubit/prohibited_acknowledgment_cubit.dart';
import 'cubit/prohibited_acknowledgment_state.dart';

/// [matches] are the keywords a 409 `prohibited-item-requires-ack` flagged, so
/// the user sees what tripped the policy before acknowledging it.
Future<bool?> showProhibitedAcknowledgmentDialog(
  BuildContext context, {
  required ProhibitedAcknowledgmentRepository repository,
  List<String> matches = const <String>[],
  // The provider owns disposal; an injected factory owns its initial reads.
  ProhibitedAcknowledgmentCubit Function()? cubitFactory,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => BlocProvider(
      create: (_) =>
          cubitFactory?.call() ??
          (ProhibitedAcknowledgmentCubit(
            repository: repository,
            matches: matches,
          )..load()),
      child: const _ProhibitedAcknowledgmentDialog(),
    ),
  );
}

class _ProhibitedAcknowledgmentDialog extends StatelessWidget {
  const _ProhibitedAcknowledgmentDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<
      ProhibitedAcknowledgmentCubit,
      ProhibitedAcknowledgmentState
    >(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: _handleStateChange,
      builder: (context, state) => _buildDialog(context, l10n, state),
    );
  }

  void _handleStateChange(
    BuildContext context,
    ProhibitedAcknowledgmentState state,
  ) {
    if (state.status == ProhibitedAckStatus.acknowledged) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildDialog(
    BuildContext context,
    AppLocalizations l10n,
    ProhibitedAcknowledgmentState state,
  ) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: OmdsBorderRadius.large),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, l10n),
            const SizedBox(height: Spacing.small),
            _buildBody(context, l10n, state),
            const SizedBox(height: Spacing.large),
            _buildCta(context, l10n, state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.block_rounded,
          color: theme.colorScheme.error,
          size: Sizes.xLarge,
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            l10n.prohibitedItemsDialogTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ProhibitedAcknowledgmentState state,
  ) {
    switch (state.status) {
      case ProhibitedAckStatus.initial:
      case ProhibitedAckStatus.loading:
        return JeebEmptyState.compact(
          status: JeebEmptyStateStatus.loading,
          headline: l10n.loadingGenericHeadline,
          identifier: 'prohibited_acknowledgment_loading',
        );
      case ProhibitedAckStatus.error:
        return JeebFailureBlock.compact(
          failure: state.failure ?? const UnknownFailure(),
          identifier: 'prohibited_acknowledgment_error',
        );
      case ProhibitedAckStatus.loaded:
      case ProhibitedAckStatus.acknowledging:
      case ProhibitedAckStatus.acknowledged:
      case ProhibitedAckStatus.acknowledgeFailed:
        return _LoadedBody(l10n: l10n, state: state);
    }
  }

  Widget _buildCta(
    BuildContext context,
    AppLocalizations l10n,
    ProhibitedAcknowledgmentState state,
  ) {
    if (state.status == ProhibitedAckStatus.error) {
      return _retryCta(context, l10n);
    }
    if (state.status == ProhibitedAckStatus.acknowledgeFailed) {
      return _acknowledgeFailedCta(context, l10n);
    }
    if (state.status == ProhibitedAckStatus.acknowledging) {
      return _acknowledgingCta(l10n);
    }
    return _acknowledgeCta(context, l10n, state);
  }

  /// The dialog does NOT pop: nothing was recorded, so the ask must stand.
  Widget _acknowledgeFailedCta(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        JeebInfoNote.error(
          text: l10n.prohibitedAckFailedBody,
          identifier: 'prohibited_acknowledgment_ack_failed_note',
        ),
        const SizedBox(height: Spacing.small),
        JeebCtaButton.primary(
          label: l10n.requestSubmitAcknowledgeCta,
          identifier: 'prohibited_acknowledgment_ack_retry_cta',
          onTap: () =>
              context.read<ProhibitedAcknowledgmentCubit>().acknowledge(),
        ),
      ],
    );
  }

  Widget _retryCta(BuildContext context, AppLocalizations l10n) {
    return Semantics(
      identifier: 'prohibited_acknowledgment_sheet_retry_cta',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.prohibitedItemsDialogRetry,
        onTap: () => context.read<ProhibitedAcknowledgmentCubit>().load(),
      ),
    );
  }

  Widget _acknowledgingCta(AppLocalizations l10n) {
    return Semantics(
      identifier: 'prohibited_acknowledgment_sheet_acknowledge_cta',
      container: true,
      button: true,
      child: OmdsLoadingButton(
        text: l10n.prohibitedItemsDialogAcknowledge,
        isLoading: true,
        onTap: () {},
      ),
    );
  }

  Widget _acknowledgeCta(
    BuildContext context,
    AppLocalizations l10n,
    ProhibitedAcknowledgmentState state,
  ) {
    return Semantics(
      identifier: 'prohibited_acknowledgment_sheet_acknowledge_cta',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.prohibitedItemsDialogAcknowledge,
        isEnabled: state.status == ProhibitedAckStatus.loaded,
        onTap: () =>
            context.read<ProhibitedAcknowledgmentCubit>().acknowledge(),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.l10n, required this.state});

  final AppLocalizations l10n;
  final ProhibitedAcknowledgmentState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.matches.isNotEmpty) ...[
          Semantics(
            identifier: 'prohibited_acknowledgment_matches',
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.prohibitedAckMatchedItemsTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: Spacing.xSmall),
                Text(
                  state.matches.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.medium),
        ],
        Text(l10n.prohibitedItemsDialogBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.medium),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: _ItemList(items: state.items, l10n: l10n),
          ),
        ),
      ],
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.l10n});

  final List<ProhibitedItem> items;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) =>
                _buildItemRow(item, colorScheme, context.jeebRoles, textTheme),
          )
          .toList(growable: false),
    );
  }

  Widget _buildItemRow(
    ProhibitedItem item,
    ColorScheme colorScheme,
    JeebRoles roles,
    TextTheme textTheme,
  ) {
    final isBlock = item.severity == ProhibitedItemSeverity.block;
    return Semantics(
      label: l10n.prohibitedItemsSemanticItem(item.name),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isBlock ? Icons.cancel_rounded : Icons.warning_amber_rounded,
              size: Sizes.medium,
              color: isBlock ? colorScheme.error : roles.warning,
            ),
            const SizedBox(width: Spacing.xSmall),
            Expanded(child: Text(item.name, style: textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
