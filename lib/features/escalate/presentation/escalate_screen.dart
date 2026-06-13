import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/escalate_cubit.dart';
import '../application/escalate_state.dart';
import '../domain/escalate_repository.dart';

/// Escalate/dispute screen accessible from delivery detail (T-MOB-022).
///
/// Reason picker → optional photos (≤5) → optional comment → submit.
/// On success, transitions to confirmation with case number and 24h SLA.
class EscalateScreen extends StatelessWidget {
  const EscalateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.escalateTitle),
      body: BlocBuilder<EscalateCubit, EscalateState>(
        builder: _buildBody,
      ),
    );
  }

  Widget _buildBody(BuildContext context, EscalateState state) {
    switch (state.phase) {
      case EscalatePhase.inputting:
        return _InputForm(state: state);
      case EscalatePhase.submitting:
        return const _SubmittingView();
      case EscalatePhase.success:
        return _ConfirmationView(caseId: state.caseId ?? '');
      case EscalatePhase.error:
        return _ErrorView(errorKind: state.errorKind);
    }
  }
}

class _InputForm extends StatelessWidget {
  const _InputForm({required this.state});
  final EscalateState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.escalateSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.large),
                  _ReasonPicker(selectedReason: state.reason),
                  const SizedBox(height: Spacing.large),
                  _PhotoSection(photos: state.photoPaths),
                  const SizedBox(height: Spacing.large),
                  _CommentField(),
                ],
              ),
            ),
          ),
          _SubmitButton(canSubmit: state.canSubmit),
        ],
      ),
    );
  }
}

class _ReasonPicker extends StatelessWidget {
  const _ReasonPicker({required this.selectedReason});
  final EscalateReason? selectedReason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.escalateReasonLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Spacing.small),
        ...EscalateReason.values.map(
          (r) => _ReasonTile(reason: r, selected: r == selectedReason),
        ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.reason, required this.selected});
  final EscalateReason reason;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      title: Text(_reasonLabel(l10n, reason)),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
      ),
      onTap: () => context.read<EscalateCubit>().setReason(reason),
    );
  }

  String _reasonLabel(AppLocalizations l10n, EscalateReason r) {
    switch (r) {
      case EscalateReason.damaged:
        return l10n.escalateReasonDamaged;
      case EscalateReason.wrongItem:
        return l10n.escalateReasonWrongItem;
      case EscalateReason.noShow:
        return l10n.escalateReasonNoShow;
      case EscalateReason.fraud:
        return l10n.escalateReasonFraud;
      case EscalateReason.abuse:
        return l10n.escalateReasonAbuse;
      case EscalateReason.other:
        return l10n.escalateReasonOther;
    }
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.photos});
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final remaining = 5 - photos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: l10n.escalatePhotoCountRemaining(remaining),
          child: Text(
            l10n.escalatePhotoLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: Spacing.small),
        if (photos.isNotEmpty) _PhotoThumbnails(photos: photos),
        const SizedBox(height: Spacing.small),
        if (photos.length < 5)
          OmdsPrimaryButton(
            text: l10n.escalatePhotoAttached(photos.length),
            onTap: () => _fakePickPhoto(context),
            variant: OmdsButtonVariant.outlined,
          ),
      ],
    );
  }

  /// EXEMPT: Image picker is device-native. In release, wire to
  /// image_picker package. Stubbed here for testability.
  void _fakePickPhoto(BuildContext context) {
    context.read<EscalateCubit>().addPhoto('photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
  }
}

class _PhotoThumbnails extends StatelessWidget {
  const _PhotoThumbnails({required this.photos});
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.xSmall,
      children: photos.indexed.map((e) {
        final (i, path) = e;
        return _PhotoChip(path: path, index: i);
      }).toList(),
    );
  }
}

class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.path, required this.index});
  final String path;
  final int index;

  @override
  Widget build(BuildContext context) {
    return OmdsChip(
      label: 'Photo ${index + 1}',
      isSelected: true,
      onTap: () => context.read<EscalateCubit>().removePhoto(path),
    );
  }
}

class _CommentField extends StatelessWidget {
  const _CommentField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsTextField(
      labelText: l10n.escalateCommentLabel,
      maxLines: 4,
      maxLength: 1000,
      onChanged: (v) => context.read<EscalateCubit>().setComment(v),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.canSubmit});
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: OmdsPrimaryButton(
        text: l10n.escalateSubmitButton,
        isEnabled: canSubmit,
        onTap: () => context.read<EscalateCubit>().submit(),
      ),
    );
  }
}

class _SubmittingView extends StatelessWidget {
  const _SubmittingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OmdsLoadingState(),
          const SizedBox(height: Spacing.medium),
          Text(l10n.escalateSubmitting),
        ],
      ),
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64),
          const SizedBox(height: Spacing.large),
          Text(
            l10n.escalateConfirmationTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.medium),
          if (caseId.isNotEmpty)
            Text(
              l10n.escalateConfirmationCaseNumber(caseId),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.escalateConfirmationBody,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xLarge),
          OmdsPrimaryButton(
            text: l10n.escalateConfirmationDone,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.errorKind});
  final EscalateErrorKind? errorKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = _errorMessage(l10n, errorKind);
    return OmdsErrorState(
      message: message,
      onRetry: errorKind == EscalateErrorKind.alreadyOpen
          ? null
          : () => context.read<EscalateCubit>().retryFromError(),
    );
  }

  String _errorMessage(AppLocalizations l10n, EscalateErrorKind? kind) {
    switch (kind) {
      case EscalateErrorKind.network:
        return l10n.escalateErrorNetwork;
      case EscalateErrorKind.alreadyOpen:
        return l10n.escalateErrorAlreadyOpen;
      default:
        return l10n.escalateErrorServer;
    }
  }
}
