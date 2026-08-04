import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../../voice_request/domain/voice_clip.dart';
import '../../voice_request/domain/voice_recorder.dart';
import '../application/escalate_cubit.dart';
import '../application/escalate_state.dart';
import '../domain/escalate_repository.dart';

/// Dispute open + evidence (JM-060, blueprint `dispute-open-evidence`).
///
/// Extends the original T-MOB-022 escalate surface into the blueprint dispute
/// flow (20_GAP_MAP reconciliation note 8 — the dead `dispute_screen.dart` is
/// retired). Exposes the blueprint identifiers: `dispute_reason`,
/// `dispute_photos` (real picker, ≤5), `dispute_voice` (D53), the auto-attached
/// chat + GPS/status timeline (D53), `dispute_submit_cta` (→ `dispute-status`,
/// JM-065), `dispute_support_link` (→ `support-ticket`, D76), `dispute_back`
/// (→ `order-chat`). POSTs `POST /v1/disputes` (D19/D2/D53/D54/D76).
///
/// The cubit is provided by the route (`/orders/:id/escalate`); the platform
/// photo/voice collaborators are owned by THIS (presentation) layer and
/// injectable for tests — they default to the codebase's stub/fake seams
/// (image_picker real binding is the cross-codebase D1m/T-mobile-040 follow-up).
///
/// MIDNIGHT M3-02 — **the board never drew this screen.** Its language is
/// derived from **R13 OTP handover**, the tile that draws the door into it
/// ("Problem? Open a dispute"): the `content` field with one quiet glow, glass
/// rows down the page, real emptiness, then ONE docked footer. The reason rows
/// take R9's ratified lit-selection idiom (the board's only drawn exclusive
/// choice); the destructive affordance takes R22's danger-SOFT
/// `onErrorContainer`, never full-strength `error`. Same phases, same block
/// order, same edges, all 11 identifiers unmoved.
class EscalateScreen extends StatefulWidget {
  const EscalateScreen({
    super.key,
    this.photoPicker,
    this.voiceRecorder,
  });

  /// Photo capture seam (defaults to [StubPhotoPickerService]). The real
  /// `image_picker` binding lands with the camera-plugin task (not yet a
  /// pubspec dependency — see 50_ROUTE_REQUESTS GAP).
  final PhotoPickerService? photoPicker;

  /// Voice capture seam (defaults to [FakeVoiceRecorder]).
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
    // Auto-attach evidence (D53) on cold entry. Never blocks the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EscalateCubit>().loadEvidence();
    });
  }

  Future<void> _pickPhoto() async {
    final cubit = context.read<EscalateCubit>();
    if (!cubit.state.canAddPhoto) return;
    // Capture locale-derived copy BEFORE the await (no BuildContext across gaps).
    final permissionCopy =
        AppLocalizations.of(context).voiceRecordingErrorPermission;
    try {
      // Real picker contract: a RawPhoto with bytes. We persist a stable
      // per-pick path token the dispute body carries (the real binding writes
      // the captured file; the stub round-trips a synthetic name).
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
      // Tapping a captured clip clears it (re-record).
      cubit.clearVoice();
      return;
    }
    // Capture locale-derived copy BEFORE the await (no BuildContext across gaps).
    final permissionCopy =
        AppLocalizations.of(context).voiceRecordingErrorPermission;
    if (_recording) {
      // Stop and capture.
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
    // Start recording.
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
    // JM-060: the dispute-open-evidence screen root. The flow asserts
    // `dispute_root` after the `/orders/:id/escalate` route lands
    // (67_W34_TEST_PLAN coined id).
    return Semantics(
      identifier: 'dispute_root',
      container: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The header is an in-body row (R13's shape), not a Material app bar,
        // so it renders in EVERY phase — submitting and error included.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.centerUpper,
          animateDecor: false,
          child: SafeArea(
            child: Column(
              children: [
                JeebTopBar(
                  title: l10n.escalateTitle,
                  // No `identifier:` on purpose — `dispute_back` is the FROZEN id
                  // of the footer's "Back to chat" button and must stay unique.
                  leadingTooltip: l10n.disputeStatusBackCta,
                ),
                Expanded(
                  child: BlocConsumer<EscalateCubit, EscalateState>(
                    listenWhen: (p, n) =>
                        p.phase != n.phase && n.phase == EscalatePhase.success,
                    listener: (context, state) {
                      // EDGE (JM-060 AC): on a successful open, route to
                      // dispute-status (JM-065). 21_NAV_PLAN §C. Replace so back
                      // doesn't re-open the form.
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Board `margin:18px` under the header (R13 `tpl 799`), less the bar's own
/// 4dp tap overhang so the first block lands where the tile draws it.
const double _kContentTopGap = 18 - JeebTopBar.tapOverhang;

/// 24px side gutters (token sheet §5 — the default screen gutter).
const EdgeInsetsGeometry _kBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  _kContentTopGap,
  Spacing.xLarge,
  Spacing.xLarge,
);

/// Between two top-level blocks — R13's own stacked-block margin (`tpl 813`).
const double _kBlockGap = 22;

/// The empty-family subject for this screen: the dispute is about the parcel
/// that went wrong, not about composing a new request (E1's mic).
const JeebEmptyStateVariant _kEmptyVariant = JeebEmptyStateVariant.parcel;

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
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: _kBodyPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // JM-060 AC1: auto-attach note (D53) — the chat snapshot +
                // GPS/timeline are attached automatically. Coined id
                // `dispute_auto_attach_note` (67_W34_TEST_PLAN).
                JeebInfoNote.muted(
                  identifier: 'dispute_auto_attach_note',
                  icon: Icons.attachment,
                  // TODO(midnight): l10n-queued `escalateAutoAttachNote` — this
                  // is the screen lede, not the auto-attach sentence the id names.
                  text: l10n.escalateSubtitle,
                  padding: JeebInfoNote.stackedPadding,
                  gap: JeebInfoNote.stackedGap,
                  iconSize: JeebInfoNote.stackedIconSize,
                ),
                const SizedBox(height: _kBlockGap),
                _ReasonPicker(selectedReason: state.reason),
                const SizedBox(height: _kBlockGap),
                _PhotoSection(
                  photos: state.photoPaths,
                  error: photoError,
                  onPick: onPickPhoto,
                ),
                const SizedBox(height: _kBlockGap),
                _VoiceSection(
                  hasVoice: state.hasVoice,
                  recording: recording,
                  onToggle: onToggleVoice,
                ),
                const SizedBox(height: _kBlockGap),
                const _CommentField(),
                const SizedBox(height: _kBlockGap),
                _EvidenceSection(
                  evidence: state.evidence,
                  loaded: state.evidenceLoaded,
                ),
                const SizedBox(height: Spacing.xSmall),
                const _SupportLink(),
              ],
            ),
          ),
        ),
        _BottomBar(canSubmit: state.canSubmit),
      ],
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JeebSectionLabel(l10n.escalateReasonLabel),
          const SizedBox(height: Spacing.small),
          for (final r in EscalateReason.values) ...[
            if (r != EscalateReason.values.first)
              const SizedBox(height: Spacing.xSmall),
            _ReasonTile(reason: r, selected: r == selectedReason),
          ],
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
    final scheme = Theme.of(context).colorScheme;
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Semantics(
      identifier: 'dispute_reason_${reason.name}',
      button: true,
      selected: selected,
      child: JeebOutlinedCard(
        // R9's lit selection is the board's ONE drawn exclusive choice, and at
        // most one of these six rows is ever lit.
        state: selected ? JeebCardState.accentSelected : JeebCardState.normal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: 14,
        ),
        onTap: () => context.read<EscalateCubit>().setReason(reason),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              // Rest ring = the board's radio-ring rung (§3 `glassBorderVivid`).
              color: selected
                  ? context.jeebRoles.accent
                  : semantics.glassBorderVivid,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                _reasonLabel(l10n, reason),
                style: context.jeebText.cardTitle
                    .copyWith(color: scheme.onSurface),
              ),
            ),
          ],
        ),
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
    final remaining = 5 - photos.length;
    return Semantics(
      identifier: 'dispute_photos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The cap was screen-reader-only chrome; the kit's own hint slot puts
          // it on the row where everyone can read it.
          JeebSectionLabel(
            l10n.escalatePhotoLabel,
            hint: l10n.escalatePhotoCountRemaining(remaining),
          ),
          const SizedBox(height: Spacing.small),
          if (photos.isNotEmpty) ...[
            _PhotoThumbnails(photos: photos),
            const SizedBox(height: Spacing.small),
          ],
          if (photos.length < 5)
            Semantics(
              identifier: 'dispute_photos_add_cta',
              button: true,
              child: JeebCtaButton.outline(
                label: l10n.escalatePhotoAttached(photos.length),
                leadingIcon: Icons.add_a_photo,
                onTap: onPick,
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: Spacing.xSmall),
            JeebInfoNote.error(icon: Icons.error, text: error!),
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
    // Scrollable rather than wrapping: five attachment pills stay on one line
    // and the trailing gutter scrolls with the last one (the kit's chip idiom).
    return JeebChipRow.scrollable(
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
      child: JeebSelectChip(
        role: JeebChipRole.inlineAction,
        label: AppLocalizations.of(context).escalatePhotoChipLabel(index + 1),
        // Attached = a settled selection; tapping it removes the attachment,
        // which is what the close glyph announces.
        selected: true,
        leading: Icon(
          Icons.close,
          size: 14,
          // The selected pill is a white slab: its own navy ink, or the glyph
          // is invisible. Danger-soft would fail AA on white.
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
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
    final String label;
    final IconData icon;
    if (hasVoice) {
      label = l10n.voiceRecordingDiscard; // captured → tap to re-record
      icon = Icons.delete_outline;
    } else if (recording) {
      label = l10n.voiceRecordingReleaseToStop;
      icon = Icons.stop_circle;
    } else {
      label = l10n.voiceRecordingHoldToRecord;
      icon = Icons.mic;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TODO(midnight): l10n-queued `escalateVoiceLabel` — this reads
        // "Record your request", which is the create-flow's sentence.
        JeebSectionLabel(l10n.voiceRecordingTitle),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'dispute_voice',
          button: true,
          label: label,
          child: hasVoice
              ? _CapturedVoiceRow(discardLabel: label, onDiscard: onToggle)
              : JeebCtaButton.outline(
                  label: label,
                  leadingIcon: icon,
                  onTap: onToggle,
                ),
        ),
      ],
    );
  }
}

/// The captured clip: a glass row (R13's grammar) whose only action is
/// destructive, so its label carries R22's danger-SOFT `onErrorContainer`.
class _CapturedVoiceRow extends StatelessWidget {
  const _CapturedVoiceRow({required this.discardLabel, required this.onDiscard});
  final String discardLabel;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return JeebOutlinedCard(
      onTap: onDiscard,
      child: Row(
        children: [
          Icon(Icons.graphic_eq, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              l10n.voiceRequestRecorded,
              style:
                  context.jeebText.cardTitle.copyWith(color: scheme.onSurface),
            ),
          ),
          Text(
            discardLabel,
            style: context.jeebText.bodySmall.copyWith(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
      // The kit has no input primitive; OmdsTextField reads the Midnight
      // `inputDecorationTheme` (glass fill, glass border, periwinkle caret).
      child: OmdsTextField(
        labelText: l10n.escalateCommentLabel,
        maxLines: 4,
        maxLength: 1000,
        onChanged: (v) => context.read<EscalateCubit>().setComment(v),
      ),
    );
  }
}

/// Auto-attached evidence (D53): the immutable chat snapshot + the GPS/status
/// timeline. Read-only — the customer cannot edit it; it travels with the
/// dispute so the back office sees the same context.
class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.evidence, required this.loaded});
  final EscalateEvidence evidence;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'dispute_evidence_timeline',
      child: JeebOutlinedCard(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!loaded) {
      return _EvidenceLine(
        icon: Icons.hourglass_top,
        // TODO(midnight): l10n-queued `escalateEvidenceLoading`.
        label: l10n.deliveryStatusLoading,
      );
    }
    if (evidence.isEmpty) {
      // The fetch degraded: nothing was attached, so nothing is listed. The
      // blueprint's chat id stays addressable on a zero-size node.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: 'dispute_evidence_chat',
            child: const SizedBox.shrink(),
          ),
          JeebEmptyState.compact(
            variant: _kEmptyVariant,
            // TODO(midnight): l10n-queued `escalateEvidenceEmpty`.
            headline: l10n.activeDeliveryUnavailable,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          identifier: 'dispute_evidence_chat',
          child: evidence.hasChatSnapshot
              ? _EvidenceLine(
                  icon: Icons.chat_bubble,
                  label: '${l10n.chatTitle} (${evidence.chatMessageCount ?? 0})',
                )
              : const SizedBox.shrink(),
        ),
        for (final e in evidence.timeline)
          _EvidenceLine(icon: Icons.place, label: _stepLabel(l10n, e.status)),
      ],
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

/// One attached-evidence line: glyph + subtitle ink, both periwinkle.
class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              label,
              style: context.jeebText.bodySmall
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportLink extends StatelessWidget {
  const _SupportLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // EDGE: dispute_support_link → support-ticket (D76). 21_NAV_PLAN §C.
    // The tap action lives on the Semantics node itself (with the child's own
    // semantics excluded) so Maestro — which taps the NODE CENTRE — reliably
    // fires it. The prior `Align(centerStart)` left the TextButton on the left
    // half only, so the node-centre tap missed the button and the nav never
    // fired on-device (68_W34 closeout; same class as the W2 RD-3 fix). The
    // kit's `text` variant keeps that full-width target (`expand: true`) and
    // centres the label, so the node centre now sits ON the label.
    return Semantics(
      identifier: 'dispute_support_link',
      button: true,
      link: true,
      container: true,
      onTap: () => context.goNamed('support-ticket'),
      // R23's `How fees work` / R13's `Send by SMS`: the informational escape
      // out of a flow is the board's one sanctioned orange text link (§4.1).
      child: ExcludeSemantics(
        child: JeebCtaButton.accentText(
          label: l10n.disputeStatusSupportCta,
          expand: true,
          onTap: () => context.goNamed('support-ticket'),
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
    return JeebCtaFooter.split(
      leading: Semantics(
        identifier: 'dispute_back',
        button: true,
        child: JeebCtaButton.outline(
          label: l10n.disputeStatusBackCta,
          // Intrinsic width — the submit pill keeps the visual weight.
          expand: false,
          // EDGE: dispute_back → order-chat. Pop when possible (the chat /
          // tracking / receipt is the typical entry); else fall back to the
          // home shell (a cold deep-link has nothing to pop). 21_NAV_PLAN §C.
          onTap: () => _leave(context),
        ),
      ),
      trailing: Semantics(
        identifier: 'dispute_submit_cta',
        button: true,
        child: JeebCtaButton(
          label: l10n.escalateSubmitButton,
          isEnabled: canSubmit,
          onTap: () => context.read<EscalateCubit>().submit(),
        ),
      ),
    );
  }
}

void _leave(BuildContext context) =>
    context.canPop() ? context.pop() : context.goNamed('shell');

class _SubmittingView extends StatelessWidget {
  const _SubmittingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState(
          status: JeebEmptyStateStatus.loading,
          variant: _kEmptyVariant,
          headline: l10n.escalateSubmitting,
          identifier: 'dispute_submitting',
        ),
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
    final alreadyOpen = errorKind == EscalateErrorKind.alreadyOpen;
    return Semantics(
      identifier: 'dispute_error',
      child: Center(
        child: SingleChildScrollView(
          child: JeebEmptyState(
            status: JeebEmptyStateStatus.error,
            variant: _kEmptyVariant,
            headline: _errorMessage(l10n, errorKind),
            // An already-open dispute cannot be retried, and a dead end is
            // worse than the wrong verb: it gets the way out instead.
            action: alreadyOpen
                ? JeebCtaButton.outline(
                    label: l10n.disputeStatusBackCta,
                    onTap: () => _leave(context),
                  )
                : JeebCtaButton.primary(
                    // TODO(midnight): l10n-queued `escalateRetryCta`.
                    label: l10n.otpRetry,
                    onTap: () =>
                        context.read<EscalateCubit>().retryFromError(),
                  ),
          ),
        ),
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
