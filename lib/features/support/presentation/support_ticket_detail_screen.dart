import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:omds/omds.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../case_evidence/domain/case_evidence.dart';
import '../../photo_attachment/data/image_picker_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/support_detail_cubit.dart';
import '../application/support_detail_state.dart';
import '../data/stub_support_repository.dart';
import '../domain/support_repository.dart';

const EdgeInsetsGeometry _detailPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.large,
);

class SupportTicketDetailScreen extends StatelessWidget {
  const SupportTicketDetailScreen({
    super.key,
    required this.ticketId,
    this.repository,
    this.photoPicker,
    this.cubitFactory,
  });

  final String ticketId;
  final SupportRepository? repository;
  final PhotoPickerService? photoPicker;

  /// Optional construction seam; the provider owns and closes this cubit.
  final SupportDetailCubit Function()? cubitFactory;

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;
    final resolved =
        repository ??
        (getIt.isRegistered<SupportRepository>()
            ? getIt<SupportRepository>()
            : const StubSupportRepository());
    final SupportThreadRepository threadRepository;
    if (resolved is SupportThreadRepository) {
      threadRepository = resolved as SupportThreadRepository;
    } else {
      threadRepository = const EmptySupportThreadRepository();
    }
    return BlocProvider<SupportDetailCubit>(
      create: (_) => cubitFactory != null
          ? cubitFactory!()
          : (SupportDetailCubit(
              repository: threadRepository,
              ticketId: ticketId,
            )..load()),
      child: _SupportTicketDetailView(photoPicker: photoPicker),
    );
  }
}

class _SupportTicketDetailView extends StatelessWidget {
  const _SupportTicketDetailView({required this.photoPicker});

  final PhotoPickerService? photoPicker;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'support_thread_root',
      container: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          animateDecor: false,
          child: SafeArea(
            child: Column(
              children: [
                JeebTopBar.back(
                  identifier: 'support_thread_back',
                  title: AppLocalizations.of(context).supportThreadTitle,
                ),
                Expanded(
                  child: BlocBuilder<SupportDetailCubit, SupportDetailState>(
                    builder: (context, state) {
                      if (state.phase == SupportDetailPhase.initial ||
                          state.phase == SupportDetailPhase.loading) {
                        return const _LoadingState();
                      }
                      if (state.phase == SupportDetailPhase.failed &&
                          state.ticket == null) {
                        return _FailureState(state: state);
                      }
                      return _ThreadBody(
                        state: state,
                        photoPicker: photoPicker,
                      );
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return JeebStateHost(
      child: JeebEmptyState(
        identifier: 'support_thread_loading',
        status: JeebEmptyStateStatus.loading,
        variant: JeebEmptyStateVariant.radar,
        medallions: const <JeebEmptyMedallion>[],
        headline: AppLocalizations.of(context).supportThreadLoadingHeadline,
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.state});

  final SupportDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final AppFailure failure = state.appFailure ?? const UnknownFailure();
    // Only a real transport gap claims "offline" (R6).
    final offline = failure is NetworkFailure && failure.offline;
    final notFound = state.failure == SupportFailure.notFound;
    return JeebStateHost(
      child: JeebFailureBlock(
        failure: failure,
        identifier: offline ? 'support_thread_offline' : 'support_thread_error',
        variant: JeebEmptyStateVariant.radar,
        headlineOverride: notFound ? l10n.supportThreadNotFoundBody : null,
        onRetry: !notFound && failure.isRetryable
            ? () => context.read<SupportDetailCubit>().load()
            : null,
        onExit: () => Navigator.of(context).maybePop(),
        exitLabel: l10n.actionBack,
        exitIdentifier: 'support_thread_exit_cta',
        retryIdentifier: 'support_thread_retry_cta',
      ),
    );
  }
}

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({required this.state, required this.photoPicker});

  final SupportDetailState state;
  final PhotoPickerService? photoPicker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SupportDetailCubit>();
    final ticket = state.ticket!;
    final closed = ticket.canonicalStatus == SupportTicketStatus.closed;
    final AppFailure? refreshError = state.refreshError;
    return Column(
      children: [
        Expanded(
          child: JeebPullToRefresh(
            onRefresh: cubit.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: _detailPadding,
              children: [
                _StatusNote(ticket: ticket),
                if (ticket.isPartial) ...[
                  const SizedBox(height: Spacing.small),
                  JeebInfoNote.warning(
                    identifier: 'support_thread_partial_evidence',
                    icon: Icons.sync_problem,
                    text: l10n.supportThreadAttachmentsDegraded,
                  ),
                ],
                if (refreshError != null) ...[
                  const SizedBox(height: Spacing.small),
                  JeebRefreshFailedNote(
                    failure: refreshError,
                    identifier: 'support_thread_refresh_error',
                    messageOverride: l10n.supportThreadRefreshFailed,
                    onDismiss: cubit.acknowledgeRefreshError,
                    onRetry: cubit.refresh,
                  ),
                ],
                if (state.phase == SupportDetailPhase.conflict) ...[
                  const SizedBox(height: Spacing.small),
                  Semantics(
                    liveRegion: true,
                    child: JeebInfoNote.warning(
                      identifier: 'support_thread_conflict',
                      icon: Icons.sync,
                      text: l10n.supportThreadStaleConflict,
                    ),
                  ),
                ] else if (state.failure != null) ...[
                  const SizedBox(height: Spacing.small),
                  Semantics(
                    liveRegion: true,
                    child: JeebInfoNote.error(
                      identifier: 'support_thread_send_error',
                      icon: Icons.cloud_off,
                      text: l10n.supportThreadReplyNotSent,
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.large),
                _OriginalRequest(ticket: ticket),
                const SizedBox(height: Spacing.large),
                JeebSectionLabel(l10n.supportThreadConversationLabel),
                const SizedBox(height: Spacing.small),
                if (state.paginationFailure != null) ...[
                  Semantics(
                    identifier: 'support_thread_pagination_error',
                    liveRegion: true,
                    container: true,
                    child: JeebInfoNote.error(
                      icon: Icons.cloud_off,
                      text: failureCopy(
                        l10n,
                        state.paginationAppFailure ?? const UnknownFailure(),
                      ).body,
                    ),
                  ),
                  const SizedBox(height: Spacing.xSmall),
                  JeebCtaButton.text(
                    label: l10n.actionRetry,
                    expand: false,
                    identifier: 'support_thread_pagination_retry',
                    onTap: cubit.loadMore,
                  ),
                  const SizedBox(height: Spacing.small),
                ],
                if (state.paginationFailure == null &&
                    (state.nextCursor != null || state.loadingMore)) ...[
                  Semantics(
                    identifier: 'support_thread_load_more',
                    button: true,
                    child: JeebCtaButton.outline(
                      label: state.loadingMore
                          ? l10n.supportThreadLoadingMessages
                          : l10n.supportThreadLoadEarlierCta,
                      leadingIcon: Icons.history,
                      isEnabled: state.canLoadMore,
                      onTap: () =>
                          context.read<SupportDetailCubit>().loadMore(),
                    ),
                  ),
                  const SizedBox(height: Spacing.small),
                ],
                if (ticket.replies.isEmpty)
                  JeebEmptyState.compact(
                    identifier: 'support_thread_empty',
                    reason: JeebEmptyStateReason.nothingYet,
                    variant: JeebEmptyStateVariant.radar,
                    medallions: const <JeebEmptyMedallion>[],
                    headline: l10n.supportThreadEmptyTitle,
                    body: l10n.supportThreadEmptyBody,
                  )
                else
                  for (final reply in ticket.replies) ...[
                    _ReplyCard(reply: reply),
                    const SizedBox(height: Spacing.small),
                  ],
              ],
            ),
          ),
        ),
        if (closed)
          JeebCtaFooter.single(
            child: JeebInfoNote.muted(
              identifier: 'support_thread_closed',
              icon: Icons.lock_outline,
              text: l10n.supportThreadClosedNote,
            ),
          )
        else
          _ReplyComposer(state: state, photoPicker: photoPicker),
      ],
    );
  }
}

class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (ticket.canonicalStatus) {
      SupportTicketStatus.pending => l10n.supportThreadStatusPending,
      SupportTicketStatus.fixed => l10n.supportThreadStatusFixed,
      SupportTicketStatus.closed => l10n.supportThreadStatusClosed,
      SupportTicketStatus.unknown => l10n.supportThreadStatusUnknown,
    };
    return Semantics(
      identifier: 'support_thread_status',
      child: switch (ticket.canonicalStatus) {
        SupportTicketStatus.pending => JeebInfoNote.warning(
          icon: Icons.schedule,
          text: label,
        ),
        SupportTicketStatus.fixed => JeebInfoNote.success(
          icon: Icons.check_circle_outline,
          text: label,
        ),
        _ => JeebInfoNote.muted(icon: Icons.lock_outline, text: label),
      },
    );
  }
}

class _OriginalRequest extends StatelessWidget {
  const _OriginalRequest({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_thread_request',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JeebSectionLabel(
            ticket.ticketNumber ?? l10n.supportThreadRequestLabel,
            hint: ticket.createdAt,
          ),
          const SizedBox(height: Spacing.small),
          JeebOutlinedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ticket.body ?? l10n.supportThreadNoDescription,
                  style: context.jeebText.body,
                ),
                if (ticket.attachments.isNotEmpty) ...[
                  const SizedBox(height: Spacing.small),
                  _AttachmentChips(attachments: ticket.attachments),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});

  final SupportReply reply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_reply_${reply.id}',
      container: true,
      child: JeebOutlinedCard(
        state: reply.isMine
            ? JeebCardState.normal
            : JeebCardState.accentSelected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reply.isMine
                        ? l10n.supportThreadAuthorYou
                        : l10n.supportThreadAuthorSupport,
                    style: context.jeebText.cardTitle,
                  ),
                ),
                Text(reply.createdAt, style: context.jeebText.label),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(reply.body, style: context.jeebText.body),
            if (reply.attachments.isNotEmpty) ...[
              const SizedBox(height: Spacing.small),
              _AttachmentChips(attachments: reply.attachments),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachmentChips extends StatelessWidget {
  const _AttachmentChips({required this.attachments});

  final List<SupportAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: Spacing.xSmall,
      runSpacing: Spacing.xSmall,
      children: attachments
          .map((attachment) {
            return JeebSelectChip(
              role: JeebChipRole.inlineAction,
              label: attachment.failed
                  ? l10n.supportThreadAttachmentUnavailable
                  : attachment.fileName ?? l10n.supportThreadAttachmentLabel,
              selected: !attachment.failed,
              leading: Icon(
                attachment.failed ? Icons.error_outline : Icons.attach_file,
                size: 14,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ReplyComposer extends StatefulWidget {
  const _ReplyComposer({required this.state, required this.photoPicker});

  final SupportDetailState state;
  final PhotoPickerService? photoPicker;

  @override
  State<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<_ReplyComposer> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state.replyBody,
  );

  @override
  void didUpdateWidget(covariant _ReplyComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final restored = widget.state.replyBody;
    if (_controller.text == restored) return;
    _controller.value = TextEditingValue(
      text: restored,
      selection: TextSelection.collapsed(offset: restored.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final sending = state.phase == SupportDetailPhase.sending;
    return JeebCtaFooter.single(
      child: Semantics(
        identifier: 'support_reply_composer',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmdsTextField(
              controller: _controller,
              labelText: l10n.supportThreadReplyLabel,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              onChanged: context.read<SupportDetailCubit>().setReplyBody,
            ),
            if (state.attachmentPaths.isNotEmpty) ...[
              const SizedBox(height: Spacing.xSmall),
              Wrap(
                spacing: Spacing.xSmall,
                children: state.attachmentPaths.indexed
                    .map((entry) {
                      final progress = state.uploads[entry.$2];
                      return JeebSelectChip(
                        role: JeebChipRole.inlineAction,
                        label:
                            progress?.state == CaseAttachmentUploadState.failed
                            ? l10n.supportThreadUploadFailed
                            : l10n.supportThreadAttachmentIndexLabel(
                                entry.$1 + 1,
                              ),
                        selected:
                            progress?.state != CaseAttachmentUploadState.failed,
                        onTap: sending
                            ? null
                            : () => context
                                  .read<SupportDetailCubit>()
                                  .removeAttachment(entry.$2),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            if (sending && state.uploads.isNotEmpty) ...[
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'support_reply_upload_progress',
                liveRegion: true,
                label: l10n.supportThreadUploadingAttachments,
                value:
                    '${((_combinedProgress(state.uploads) ?? 0) * 100).round()}%',
                child: LinearProgressIndicator(
                  value: _combinedProgress(state.uploads),
                ),
              ),
            ],
            const SizedBox(height: Spacing.small),
            Row(
              children: [
                Semantics(
                  identifier: 'support_reply_attach',
                  button: true,
                  child: IconButton(
                    tooltip: l10n.supportThreadAttachPhoto,
                    onPressed: state.canAttach && !sending
                        ? () => _pick(context)
                        : null,
                    icon: const Icon(Icons.attach_file),
                  ),
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Semantics(
                    identifier: 'support_reply_send',
                    button: true,
                    child: JeebCtaButton(
                      label: sending
                          ? l10n.supportThreadSending
                          : state.phase == SupportDetailPhase.conflict
                          ? l10n.supportThreadRetryReply
                          : l10n.supportThreadSendReply,
                      leadingIcon: Icons.send,
                      isEnabled: state.canReply,
                      onTap: () =>
                          context.read<SupportDetailCubit>().sendReply(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<SupportDetailCubit>();
    final picker = widget.photoPicker ?? ImagePickerPhotoPickerService();
    try {
      final photo = await picker.pickFromGallery();
      if (!context.mounted || cubit.isClosed) return;
      final id = 'support_reply_${DateTime.now().microsecondsSinceEpoch}.jpg';
      cubit.addAttachment(id, bytes: photo.bytes);
    } on PhotoPickException catch (error) {
      if (!context.mounted || error.failure == PhotoPickFailure.cancelled) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      showJeebErrorSnack(
        context,
        identifier: 'support_reply_attach_error',
        message: error.failure == PhotoPickFailure.permissionDenied
            ? l10n.supportPhotoPermissionDenied
            : l10n.supportAttachmentFailed,
      );
    }
  }

  double? _combinedProgress(Map<String, CaseAttachmentProgress> uploads) {
    if (uploads.isEmpty) return null;
    return uploads.values.map((item) => item.fraction).reduce((a, b) => a + b) /
        uploads.length;
  }
}
