import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../../voice_request/domain/voice_clip.dart';
import '../../voice_request/domain/voice_recorder.dart';
import '../application/escalate_cubit.dart';
import '../application/escalate_state.dart';
import '../domain/escalate_repository.dart';

class EscalateScreen extends StatefulWidget {
  const EscalateScreen({
    super.key,
    this.photoPicker,
    this.voiceRecorder,
  });

  final PhotoPickerService? photoPicker;

  final VoiceRecorder? voiceRecorder;

  @override
  State<EscalateScreen> createState() => _EscalateScreenState();
}

class _EscalateScreenState extends State<EscalateScreen> {
  late final PhotoPickerService _photoPicker =
      widget.photoPicker ?? StubPhotoPickerService();
  late final VoiceRecorder _voiceRecorder =
      widget.voiceRecorder ?? FakeVoiceRecorder();

  bool _recording = false;
  int _photoSeq = 0;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EscalateCubit>().loadEvidence();
    });
  }

  Future<void> _pickPhoto() async {
    final cubit = context.read<EscalateCubit>();
    if (!cubit.state.canAddPhoto) return;
    final permissionCopy =
        AppLocalizations.of(context).voiceRecordingErrorPermission;
    try {
      await _photoPicker.pickFromGallery();
      _photoSeq += 1;
      cubit.addPhoto('dispute_photo_$_photoSeq.jpg');
      if (mounted) setState(() => _photoError = null);
    } on PhotoPickException catch (e) {
      if (!mounted) return;
      setState(() {
        _photoError = e.failure == PhotoPickFailure.permissionDenied
            ? permissionCopy
            : null;
      });
    }
  }

  Future<void> _toggleVoice() async {
    final cubit = context.read<EscalateCubit>();
    if (cubit.state.hasVoice) {
      cubit.clearVoice();
      return;
    }
    final permissionCopy =
        AppLocalizations.of(context).voiceRecordingErrorPermission;
    if (_recording) {
      try {
        final VoiceClip clip =
            await _voiceRecorder.stop(recordedDuration: Duration.zero);
        cubit.setVoice(clip.sourcePath ?? 'dispute_voice.m4a');
      } on VoiceRecorderException {
        await _voiceRecorder.cancel();
      } finally {
        if (mounted) setState(() => _recording = false);
      }
      return;
    }
    try {
      await _voiceRecorder.start();
      if (mounted) setState(() => _recording = true);
    } on VoiceRecorderException catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _photoError = e.failure == VoiceRecorderFailure.permissionDenied
            ? permissionCopy
            : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dispute_root',
      container: true,
      child: Scaffold(
      appBar: OMDSAppBar(title: l10n.escalateTitle, showBackButton: true),
      body: BlocConsumer<EscalateCubit, EscalateState>(
        listenWhen: (p, n) =>
            p.phase != n.phase && n.phase == EscalatePhase.success,
        listener: (context, state) {
          final id = state.caseId ?? '';
          if (id.isEmpty) return;
          context.goNamed(
            'dispute-status',
            pathParameters: <String, String>{'id': id},
          );
        },
        builder: (context, state) {
          switch (state.phase) {
            case EscalatePhase.inputting:
            case EscalatePhase.success:
              return _InputForm(
                state: state,
                recording: _recording,
                photoError: _photoError,
                onPickPhoto: _pickPhoto,
                onToggleVoice: _toggleVoice,
              );
            case EscalatePhase.submitting:
              return const _SubmittingView();
            case EscalatePhase.error:
              return _ErrorView(errorKind: state.errorKind);
          }
        },
      ),
    ),
    );
  }
}

class _InputForm extends StatelessWidget {
  const _InputForm({
    required this.state,
    required this.recording,
    required this.photoError,
    required this.onPickPhoto,
    required this.onToggleVoice,
  });

  final EscalateState state;
  final bool recording;
  final String? photoError;
  final VoidCallback onPickPhoto;
  final VoidCallback onToggleVoice;

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
                  const SizedBox(height: Spacing.medium),
                  Semantics(
                    identifier: 'dispute_auto_attach_note',
                    container: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.attachment_outlined,
                          size: Sizes.medium,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Spacing.small),
                        Expanded(
                          child: Text(
                            l10n.escalateSubtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.large),
                  _ReasonPicker(selectedReason: state.reason),
                  const SizedBox(height: Spacing.large),
                  _PhotoSection(
                    photos: state.photoPaths,
                    error: photoError,
                    onPick: onPickPhoto,
                  ),
                  const SizedBox(height: Spacing.large),
                  _VoiceSection(
                    hasVoice: state.hasVoice,
                    recording: recording,
                    onToggle: onToggleVoice,
                  ),
                  const SizedBox(height: Spacing.large),
                  const _CommentField(),
                  const SizedBox(height: Spacing.large),
                  _EvidenceSection(
                    evidence: state.evidence,
                    loaded: state.evidenceLoaded,
                  ),
                  const SizedBox(height: Spacing.large),
                  const _SupportLink(),
                ],
              ),
            ),
          ),
          _BottomBar(canSubmit: state.canSubmit),
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
    return Semantics(
      identifier: 'dispute_reason',
      child: Column(
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
      ),
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
    return Semantics(
      identifier: 'dispute_reason_${reason.name}',
      button: true,
      selected: selected,
      child: ListTile(
        title: Text(_reasonLabel(l10n, reason)),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color:
              selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        ),
        onTap: () => context.read<EscalateCubit>().setReason(reason),
      ),
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
  const _PhotoSection({
    required this.photos,
    required this.error,
    required this.onPick,
  });
  final List<String> photos;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final remaining = 5 - photos.length;
    return Semantics(
      identifier: 'dispute_photos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: l10n.escalatePhotoCountRemaining(remaining),
            child: Text(
              l10n.escalatePhotoLabel,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: Spacing.small),
          if (photos.isNotEmpty) _PhotoThumbnails(photos: photos),
          const SizedBox(height: Spacing.small),
          if (photos.length < 5)
            Semantics(
              identifier: 'dispute_photos_add_cta',
              button: true,
              child: OMDSOutlinedButton(
                text: l10n.escalatePhotoAttached(photos.length),
                icon: const Icon(Icons.add_a_photo_outlined),
                onTap: onPick,
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: Spacing.xSmall),
            Text(
              error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
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
    return Semantics(
      identifier: 'dispute_photos_chip_$index',
      button: true,
      child: OmdsChip(
        label: 'Photo ${index + 1}',
        isSelected: true,
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => context.read<EscalateCubit>().removePhoto(path),
        onTap: () => context.read<EscalateCubit>().removePhoto(path),
      ),
    );
  }
}

class _VoiceSection extends StatelessWidget {
  const _VoiceSection({
    required this.hasVoice,
    required this.recording,
    required this.onToggle,
  });
  final bool hasVoice;
  final bool recording;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final String label;
    final IconData icon;
    if (hasVoice) {
      label = l10n.voiceRecordingDiscard;
      icon = Icons.delete_outline;
    } else if (recording) {
      label = l10n.voiceRecordingReleaseToStop;
      icon = Icons.stop_circle_outlined;
    } else {
      label = l10n.voiceRecordingHoldToRecord;
      icon = Icons.mic_none_outlined;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.voiceRecordingTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'dispute_voice',
          button: true,
          label: label,
          child: OMDSOutlinedButton(
            text: hasVoice ? l10n.voiceRequestRecorded : label,
            icon: Icon(icon),
            onTap: onToggle,
          ),
        ),
      ],
    );
  }
}

class _CommentField extends StatelessWidget {
  const _CommentField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dispute_comment_field',
      child: OmdsTextField(
        labelText: l10n.escalateCommentLabel,
        maxLines: 4,
        maxLength: 1000,
        onChanged: (v) => context.read<EscalateCubit>().setComment(v),
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.evidence, required this.loaded});
  final EscalateEvidence evidence;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'dispute_evidence_timeline',
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: Spacing.xSmall),
                Expanded(
                  child: Text(
                    l10n.escalateSubtitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.small),
            if (!loaded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.small),
                child: Text(
                  l10n.escalateSubmitting,
                  style: theme.textTheme.bodySmall,
                ),
              )
            else ...[
              Semantics(
                identifier: 'dispute_evidence_chat',
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 16),
                    const SizedBox(width: Spacing.xSmall),
                    Expanded(
                      child: Text(
                        evidence.hasChatSnapshot
                            ? '${l10n.chatTitle} (${evidence.chatMessageCount ?? 0})'
                            : l10n.chatTitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xSmall),
              if (evidence.hasTimeline)
                ...evidence.timeline.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16),
                        const SizedBox(width: Spacing.xSmall),
                        Expanded(
                          child: Text(
                            _stepLabel(l10n, e.status),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16),
                    const SizedBox(width: Spacing.xSmall),
                    Expanded(
                      child: Text(
                        l10n.trackingTitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _stepLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'Ordered':
        return l10n.trackingStepOrdered;
      case 'Picked':
        return l10n.trackingStepPicked;
      case 'InTransit':
        return l10n.trackingStepInTransit;
      case 'AtDoor':
      case 'Done':
        return l10n.trackingStepCompleted;
      default:
        return status;
    }
  }
}

class _SupportLink extends StatelessWidget {
  const _SupportLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dispute_support_link',
      button: true,
      link: true,
      container: true,
      onTap: () => context.goNamed('support-ticket'),
      child: ExcludeSemantics(
        child: TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(Sizes.fiveXLarge),
            alignment: AlignmentDirectional.centerStart,
          ),
          icon: const Icon(Icons.support_agent_outlined, size: 18),
          label: Text(l10n.disputeStatusSupportCta),
          onPressed: () => context.goNamed('support-ticket'),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.canSubmit});
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: Row(
        children: [
          Semantics(
            identifier: 'dispute_back',
            button: true,
            child: OMDSOutlinedButton(
              text: l10n.disputeStatusBackCta,
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.goNamed('shell'),
            ),
          ),
          const SizedBox(width: Spacing.medium),
          Expanded(
            child: Semantics(
              identifier: 'dispute_submit_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.escalateSubmitButton,
                isEnabled: canSubmit,
                onTap: () => context.read<EscalateCubit>().submit(),
              ),
            ),
          ),
        ],
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.errorKind});
  final EscalateErrorKind? errorKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = _errorMessage(l10n, errorKind);
    return Semantics(
      identifier: 'dispute_error',
      child: OmdsErrorState(
        message: message,
        onRetry: errorKind == EscalateErrorKind.alreadyOpen
            ? null
            : () => context.read<EscalateCubit>().retryFromError(),
      ),
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
