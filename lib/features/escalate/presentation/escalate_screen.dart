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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/escalate_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/escalate/escalate_screen_preview_test.dart
// ===========================================================================
//
// [EscalateScreen] is the dispute-open form (JM-060): reason, photos (≤5),
// voice, comment, the read-only D53 auto-attach panel, and a two-button bottom
// bar. It reads its [EscalateCubit] from the ROUTE, so every preview below
// mounts its own [BlocProvider] the way `/orders/:id/escalate` does — there is
// no widget-level seam and none was added for previewing.
//
// The scripted repository, the evidence snapshots and the cubit pre-drive are
// NOT declared here. They live in
// `lib/devtool/catalog/fixtures/escalate_screen_fixtures.dart`, shared with the
// on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_04_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". Nothing there can reach the network: every answer is a const value,
// an error, or a `Completer` that is never completed.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's `Scaffold + OMDSAppBar` paints inside it. Same nesting the Screen
//    Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.**
//    [_escalateScreenFramed] pins the same box the annotation asks for, so a
//    render test measures a phone rather than the 800x600 test surface. The
//    body scrolls, so only the WIDTH is load-bearing.
//  * **Tapping is not previewing.** Submit, Back and "Contact support" all
//    route through a [GoRouter] that does not exist above a preview card, and
//    the photo/voice CTAs reach the screen's default stub capture seams. Every
//    state below is reached by pre-driving the cubit instead.
//
// The states are the four the Screen Catalog names plus four it does not, and
// the extra four are where this screen is worth looking at:
//
//   * **Evidence still in flight** — the first frames of every cold entry, and
//     the one state the catalog's enum-of-behaviours could not express.
//   * **Evidence complete** — the ≤5 photo cap REACHED, which silently removes
//     the only add-photo control on the screen.
//   * **`alreadyOpen`** — the one error the screen renders with NO retry, so it
//     is the only dead end in the flow.
//   * **The compact 320 ceiling** — six reason rows, a four-row timeline and a
//     two-button bottom bar on the narrowest phone the app supports.

/// The phone this screen is designed against.
const Size _escalateScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _escalateScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _escalateScreenFramed(Widget screen, Size box) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: box.width, height: box.height, child: screen),
    );

/// Mounts the screen under the [EscalateCubit] its route provides, pre-driven
/// into one designed state.
Widget _escalateScreenHosted(
  EscalateRepository repository, {
  EscalateReason? reason,
  List<String> photoPaths = const <String>[],
  String? voicePath,
  bool submit = false,
  Size box = _escalateScreenPhoneBox,
}) {
  return _escalateScreenFramed(
    BlocProvider<EscalateCubit>(
      create: (_) => EscalateScreenPreviewFixtures.cubit(
        repository,
        reason: reason,
        photoPaths: photoPaths,
        voicePath: voicePath,
        submit: submit,
      ),
      child: const EscalateScreen(),
    ),
    box,
  );
}

/// The reference reading: the auto-attach resolved, nothing chosen yet.
///
/// This is the form a customer actually lands on — six radio rows, an empty
/// photo strip, a mic CTA, a 1000-character comment field, the read-only
/// evidence panel and a disabled Submit (`canSubmit` is `reason != null`).
///
/// It is one of the two the matrix is for, and the reason is the copy: the
/// SAME string (`escalateSubtitle`) is rendered three times on this screen —
/// as the subtitle, as the `dispute_auto_attach_note` beside a paperclip, and
/// as the evidence panel's own header. At 200% text those three paragraphs are
/// most of the first viewport, and in AR the whole stack mirrors while the
/// `ListTile` radio rows keep their own leading/trailing convention.
@JeebPreview(
  group: 'escalate',
  name: 'Reason picker · evidence loaded',
  size: _escalateScreenPhoneBox,
  matrix: true,
)
Widget escalateScreenReasonPicker() =>
    _escalateScreenHosted(EscalateScreenPreviewFixtures.evidenceLoaded());

/// The auto-attach still in flight — `evidenceLoaded` has not flipped.
///
/// Every cold entry passes through this: `initState` posts `loadEvidence()` on
/// the first frame and the panel renders its not-loaded branch until the read
/// returns. What that branch renders is `escalateSubmitting` — **"Submitting…"**
/// — over a form the customer has not filled in, let alone submitted. Nothing
/// is being submitted here; the screen is reading a chat snapshot.
///
/// Kept as a preview because it is invisible in practice (a fast read resolves
/// before anyone looks) and permanent on a slow one — and because the copy is
/// the kind of defect that only shows up when the state is held still.
@JeebPreview(
  group: 'escalate',
  name: 'Evidence pending · auto-attach in flight',
  size: _escalateScreenPhoneBox,
)
Widget escalateScreenEvidencePending() =>
    _escalateScreenHosted(EscalateScreenPreviewFixtures.evidenceStalled());

/// The auto-attach FAILED, and the screen says so by saying nothing.
///
/// `EscalateCubit.loadEvidence` swallows every failure and degrades to
/// [EscalateEvidence.empty] — deliberately, so a missing snapshot never blocks
/// opening a dispute. This is therefore also the EMPTY reading of the panel,
/// and it is indistinguishable from a delivery that genuinely has no chat and
/// no GPS history: the chat row drops its `(n)` count and the timeline
/// collapses to a single generic "Live tracking" line under a pin icon.
///
/// The customer is told the evidence is auto-attached (the note at the top says
/// so) and is shown a panel that attaches nothing. Compare with
/// [escalateScreenReasonPicker], whose panel carries the same header.
@JeebPreview(
  group: 'escalate',
  name: 'Evidence degraded · empty panel',
  size: _escalateScreenPhoneBox,
)
Widget escalateScreenEvidenceDegraded() =>
    _escalateScreenHosted(EscalateScreenPreviewFixtures.evidenceDegraded());

/// Everything optional is filled in, and the photo cap is REACHED.
///
/// Five chips, a captured clip, a reason chosen, Submit finally enabled. The
/// state worth looking at is the photo strip: `_PhotoSection` renders the
/// add-photo CTA under `if (photos.length < 5)`, so at the cap the only control
/// for adding photos is simply GONE — no disabled button, no "5 of 5" line, no
/// explanation. The remaining count exists but only as a `Semantics` label, so
/// it reaches a screen reader and nothing else.
///
/// The voice row is worth a second look too: with a clip captured the button
/// reads `voiceRequestRecorded` ("Recording ready") while its semantics label
/// says `voiceRecordingDiscard` ("Re-record"), which is what tapping it does.
@JeebPreview(
  group: 'escalate',
  name: 'Evidence complete · photo cap reached',
  size: _escalateScreenPhoneBox,
)
Widget escalateScreenEvidenceComplete() => _escalateScreenHosted(
      EscalateScreenPreviewFixtures.evidenceLoaded(),
      reason: EscalateReason.wrongItem,
      photoPaths: EscalateScreenPreviewFixtures.cappedPhotos,
      voicePath: EscalateScreenPreviewFixtures.voicePath,
    );

/// The POST in flight: a centred [OmdsLoadingState] and "Submitting…".
///
/// The whole form is replaced for the duration — the evidence the customer
/// assembled, the reason they picked and the back button are all gone, and
/// there is no way to cancel. `EscalateCubit.submit` has no timeout, so a
/// request that never answers leaves the screen here indefinitely; that is
/// exactly what this fixture holds still.
///
/// It is also the one state whose render test cannot use `pumpAndSettle`: a
/// `CircularProgressIndicator` is an indefinite animation, so the harness's
/// settle would time out. See the dedicated pump-once group in
/// `test/previews/escalate/escalate_screen_preview_test.dart`.
@JeebPreview(
  group: 'escalate',
  name: 'Submitting',
  size: _escalateScreenPhoneBox,
)
Widget escalateScreenSubmitting() => _escalateScreenHosted(
      EscalateScreenPreviewFixtures.stalledSubmit(),
      reason: EscalateReason.damaged,
      submit: true,
    );

/// The POST failed on the transport: the classified network copy with a Retry.
///
/// `retryFromError` returns the cubit to `inputting` with the reason, photos,
/// voice and comment intact, so the retry is genuinely cheap. What the copy
/// promises is not: "Your report will be retried automatically" — nothing in
/// this feature retries anything automatically. `submit()` emits the error and
/// stops; the only retry is the button under the sentence.
@JeebPreview(
  group: 'escalate',
  name: 'Error · network',
  size: _escalateScreenPhoneBox,
)
Widget escalateScreenErrorNetwork() => _escalateScreenHosted(
      EscalateScreenPreviewFixtures.failingSubmit(),
      reason: EscalateReason.noShow,
      submit: true,
    );

/// The 409 reading: a dispute for this delivery already exists.
///
/// The ONLY error kind the screen renders with `onRetry: null`, because
/// retrying would fail the same way — which leaves a full-screen error with
/// nothing on it to tap at all. There is no route back to the form (the app bar
/// back arrow leaves the flow entirely) and no link to the dispute that already
/// exists, even though the customer's next move is obviously to open it.
///
/// Previewed beside [escalateScreenErrorNetwork] because the two are one enum
/// value apart and only one of them is a dead end.
@JeebPreview(
  group: 'escalate',
  name: 'Error · already open (no retry)',
  size: _escalateScreenPhoneBox,
)
Widget escalateScreenErrorAlreadyOpen() => _escalateScreenHosted(
      EscalateScreenPreviewFixtures.failingSubmit(
        EscalateErrorKind.alreadyOpen,
      ),
      reason: EscalateReason.fraud,
      submit: true,
    );

/// The layout ceiling, on the narrowest phone the app supports.
///
/// Everything that can be long is long at once: all six reason rows, the photo
/// strip at its cap, a captured clip, and a completed delivery's auto-attach —
/// a 248-message snapshot over a four-row timeline. The bottom bar is the part
/// to watch: it is a `Row` of a full-width-content "Back to chat" outlined
/// button beside an `Expanded` Submit, inside `Spacing.large` padding, and the
/// AR copy for both is longer than the EN.
///
/// Read the AR RTL and 200% renderings rather than the English one — the
/// English stays plausible long after the other two have stopped fitting.
@JeebPreview(
  group: 'escalate',
  name: 'Longest content · compact 320',
  size: _escalateScreenCompactBox,
  matrix: true,
)
Widget escalateScreenCompactCeiling() => _escalateScreenHosted(
      EscalateScreenPreviewFixtures.completedEvidenceLoaded(),
      reason: EscalateReason.abuse,
      photoPaths: EscalateScreenPreviewFixtures.cappedPhotos,
      voicePath: EscalateScreenPreviewFixtures.voicePath,
      box: _escalateScreenCompactBox,
    );
