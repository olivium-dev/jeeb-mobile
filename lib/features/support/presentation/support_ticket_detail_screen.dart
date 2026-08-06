import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:omds/omds.dart';

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
  });

  final String ticketId;
  final SupportRepository? repository;
  final PhotoPickerService? photoPicker;

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
      create: (_) =>
          SupportDetailCubit(repository: threadRepository, ticketId: ticketId)
            ..load(),
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
                  title: _copy(context, 'Support', 'الدعم'),
                ),
                Expanded(
                  child: BlocBuilder<SupportDetailCubit, SupportDetailState>(
                    builder: (context, state) {
                      if (state.phase == SupportDetailPhase.initial ||
                          state.phase == SupportDetailPhase.loading) {
                        return _LoadingState();
                      }
                      if (state.phase == SupportDetailPhase.failed &&
                          state.ticket == null) {
                        return _FailureState(failure: state.failure);
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: JeebEmptyState(
        identifier: 'support_thread_loading',
        status: JeebEmptyStateStatus.loading,
        variant: JeebEmptyStateVariant.radar,
        medallions: const <JeebEmptyMedallion>[],
        headline: _copy(
          context,
          'Loading your support conversation',
          'جارٍ تحميل محادثة الدعم',
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.failure});

  final SupportFailure? failure;

  @override
  Widget build(BuildContext context) {
    final offline = failure == SupportFailure.network;
    return Semantics(
      liveRegion: true,
      child: Center(
        child: JeebEmptyState(
          identifier: offline
              ? 'support_thread_offline'
              : 'support_thread_error',
          status: JeebEmptyStateStatus.error,
          variant: JeebEmptyStateVariant.radar,
          medallions: const <JeebEmptyMedallion>[],
          headline: offline
              ? _copy(context, 'You are offline', 'أنت غير متصل')
              : failure == SupportFailure.notFound
              ? _copy(
                  context,
                  'This support ticket could not be found.',
                  'تعذر العثور على تذكرة الدعم هذه.',
                )
              : _copy(
                  context,
                  'Could not load this support ticket.',
                  'تعذر تحميل تذكرة الدعم هذه.',
                ),
          body: offline
              ? _copy(
                  context,
                  'Reconnect, then try again.',
                  'أعد الاتصال ثم حاول مرة أخرى.',
                )
              : null,
          action: Semantics(
            identifier: 'support_thread_retry_cta',
            button: true,
            child: JeebCtaButton.outline(
              label: _copy(context, 'Retry', 'إعادة المحاولة'),
              leadingIcon: Icons.refresh,
              onTap: () => context.read<SupportDetailCubit>().refresh(),
            ),
          ),
        ),
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
    final ticket = state.ticket!;
    final closed = ticket.canonicalStatus == SupportTicketStatus.closed;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<SupportDetailCubit>().refresh(),
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
                    text: _copy(
                      context,
                      'Some attachments are unavailable. The rest of the conversation is intact.',
                      'بعض المرفقات غير متاحة. بقية المحادثة محفوظة.',
                    ),
                  ),
                ],
                if (state.phase == SupportDetailPhase.conflict) ...[
                  const SizedBox(height: Spacing.small),
                  Semantics(
                    liveRegion: true,
                    child: JeebInfoNote.warning(
                      identifier: 'support_thread_conflict',
                      icon: Icons.sync,
                      text: _copy(
                        context,
                        'This ticket changed while you were replying. Review the latest messages, then retry.',
                        'تم تحديث التذكرة أثناء ردك. راجع أحدث الرسائل ثم أعد المحاولة.',
                      ),
                    ),
                  ),
                ] else if (state.failure != null) ...[
                  const SizedBox(height: Spacing.small),
                  Semantics(
                    liveRegion: true,
                    child: JeebInfoNote.error(
                      identifier: state.phase == SupportDetailPhase.failed
                          ? 'support_thread_refresh_error'
                          : 'support_thread_send_error',
                      icon: Icons.cloud_off,
                      text: state.phase == SupportDetailPhase.failed
                          ? _copy(
                              context,
                              'Could not refresh this conversation.',
                              'تعذر تحديث هذه المحادثة.',
                            )
                          : _copy(
                              context,
                              'Your reply was not sent. Retry will not duplicate it.',
                              'لم يتم إرسال ردك. لن تؤدي إعادة المحاولة إلى تكراره.',
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.large),
                _OriginalRequest(ticket: ticket),
                const SizedBox(height: Spacing.large),
                JeebSectionLabel(_copy(context, 'Conversation', 'المحادثة')),
                const SizedBox(height: Spacing.small),
                if (state.paginationFailure != null) ...[
                  Semantics(
                    identifier: 'support_thread_pagination_error',
                    liveRegion: true,
                    child: JeebInfoNote.error(
                      icon: Icons.cloud_off,
                      text: _copy(
                        context,
                        'Could not load more messages.',
                        'تعذر تحميل المزيد من الرسائل.',
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.small),
                ],
                if (state.nextCursor != null || state.loadingMore) ...[
                  Semantics(
                    identifier: 'support_thread_load_more',
                    button: true,
                    child: JeebCtaButton.outline(
                      label: state.loadingMore
                          ? _copy(context, 'Loading messages', 'جارٍ التحميل')
                          : _copy(
                              context,
                              'Load earlier messages',
                              'تحميل الرسائل السابقة',
                            ),
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
                    variant: JeebEmptyStateVariant.radar,
                    medallions: const <JeebEmptyMedallion>[],
                    headline: _copy(
                      context,
                      'No replies yet',
                      'لا توجد ردود بعد',
                    ),
                    body: _copy(
                      context,
                      'Support will reply here.',
                      'سيرد فريق الدعم هنا.',
                    ),
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
              text: _copy(
                context,
                'This ticket is closed. Only support administrators can close tickets.',
                'هذه التذكرة مغلقة. يمكن لمشرفي الدعم فقط إغلاق التذاكر.',
              ),
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
    final label = switch (ticket.canonicalStatus) {
      SupportTicketStatus.pending => _copy(context, 'Pending', 'قيد المتابعة'),
      SupportTicketStatus.fixed => _copy(context, 'Fixed', 'تم الإصلاح'),
      SupportTicketStatus.closed => _copy(context, 'Closed', 'مغلق'),
      SupportTicketStatus.unknown => _copy(
        context,
        'Status unavailable',
        'الحالة غير متاحة',
      ),
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
    return Semantics(
      identifier: 'support_thread_request',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JeebSectionLabel(
            ticket.ticketNumber ?? _copy(context, 'Your request', 'طلبك'),
            hint: ticket.createdAt,
          ),
          const SizedBox(height: Spacing.small),
          JeebOutlinedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ticket.body ??
                      _copy(context, 'No description', 'لا يوجد وصف'),
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
                        ? _copy(context, 'You', 'أنت')
                        : _copy(context, 'Support', 'الدعم'),
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
    return Wrap(
      spacing: Spacing.xSmall,
      runSpacing: Spacing.xSmall,
      children: attachments
          .map((attachment) {
            return JeebSelectChip(
              role: JeebChipRole.inlineAction,
              label: attachment.failed
                  ? _copy(context, 'Attachment unavailable', 'المرفق غير متاح')
                  : attachment.fileName ?? _copy(context, 'Attachment', 'مرفق'),
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
              labelText: _copy(context, 'Reply', 'رد'),
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
                            ? _copy(context, 'Upload failed', 'فشل الرفع')
                            : '${_copy(context, 'Attachment', 'المرفق')} ${entry.$1 + 1}',
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
                label: _copy(
                  context,
                  'Uploading attachments',
                  'جارٍ رفع المرفقات',
                ),
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
                    tooltip: _copy(context, 'Attach photo', 'إرفاق صورة'),
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
                          ? _copy(context, 'Sending', 'جارٍ الإرسال')
                          : state.phase == SupportDetailPhase.conflict
                          ? _copy(context, 'Retry reply', 'إعادة إرسال الرد')
                          : _copy(context, 'Send reply', 'إرسال الرد'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.failure == PhotoPickFailure.permissionDenied
                ? AppLocalizations.of(context).voiceRecordingErrorPermission
                : _copy(
                    context,
                    'Could not attach this photo.',
                    'تعذر إرفاق هذه الصورة.',
                  ),
          ),
        ),
      );
    }
  }

  double? _combinedProgress(Map<String, CaseAttachmentProgress> uploads) {
    if (uploads.isEmpty) return null;
    return uploads.values.map((item) => item.fraction).reduce((a, b) => a + b) /
        uploads.length;
  }
}

String _copy(BuildContext context, String en, String ar) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
