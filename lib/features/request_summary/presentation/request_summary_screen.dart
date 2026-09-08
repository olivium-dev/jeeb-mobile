import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import '../../prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart';
import '../../transcription/domain/transcript_audio_player.dart';
import '../application/request_summary_cubit.dart';
import 'widgets/broadcast_footer.dart';
import 'widgets/request_ticket.dart';

/// Board `margin:22px` above the ticket, less the top bar's 4dp tap overhang.
const double _kTicketTopGap = 18;

class RequestSummaryScreen extends StatelessWidget {
  const RequestSummaryScreen({super.key, this.audioPlayer});

  /// Test override for the voice replay band. Production leaves it null and the
  /// band constructs the `audioplayers` adapter itself, so playback needs no
  /// DI registration and no router change.
  final TranscriptAudioPlayer? audioPlayer;

  @override
  Widget build(BuildContext context) {
    // On a successful submit, return to the Requests tab (`/`). The submit
    // cubit only flips isSubmitted once, so listenWhen fires exactly on the
    // false → true edge. A failed submit surfaces a Midnight danger snackbar on
    // the null → non-null `error` edge and leaves the screen in place so the
    // user can retry.
    return MultiBlocListener(
      listeners: [
        BlocListener<RequestSummaryCubit, RequestSummaryState>(
          listenWhen: (p, c) => !p.isSubmitted && c.isSubmitted,
          listener: (context, state) => context.go('/'),
        ),
        BlocListener<RequestSummaryCubit, RequestSummaryState>(
          // A moderation 409 owns its own surface (blocked note / ack sheet),
          // so it must never also raise an error snack with a Retry.
          listenWhen: (p, c) =>
              p.error == null &&
              c.error != null &&
              !c.moderationBlocked &&
              c.moderationMatches.isEmpty,
          listener: _onSubmitFailure,
        ),
        BlocListener<RequestSummaryCubit, RequestSummaryState>(
          listenWhen: (p, c) =>
              p.moderationMatches.isEmpty &&
              c.moderationMatches.isNotEmpty &&
              !c.moderationBlocked,
          listener: _onModerationAckRequired,
        ),
      ],
      child: BlocBuilder<RequestSummaryCubit, RequestSummaryState>(
        builder: (context, state) {
          final l10n = AppLocalizations.of(context);
          final draft = state.draft;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: JeebMidnightField(
              variant: JeebFieldVariant.content,
              child: SafeArea(
                child: Semantics(
                  identifier: 'request_summary_root',
                  // Both flags or this node swallows every nested identifier.
                  container: true,
                  explicitChildNodes: true,
                  child: Column(
                    children: [
                      JeebTopBar.back(
                        title: l10n.requestSummaryTitle,
                        identifier: 'request_summary_back',
                        // Mirrors `backFallbacks['request-summary'] = '/'`; the
                        // route is already wrapped, so no RootAwareBackScope.
                        onLeadingPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                      ),
                      if (draft == null)
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: JeebEmptyState(
                                status: JeebEmptyStateStatus.loading,
                                headline: l10n.requestSummaryLoadingHeadline,
                                identifier: 'request_summary_loading',
                              ),
                            ),
                          ),
                        )
                      else ...[
                        // Expanded + scroll view (never a bare Spacer)
                        // reproduces the board's flex-1 gap AND survives 200%
                        // text scale.
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              Spacing.xLarge,
                              _kTicketTopGap,
                              Spacing.xLarge,
                              0,
                            ),
                            child: RequestTicket(
                              draft: draft,
                              audioPlayer: audioPlayer,
                            ),
                          ),
                        ),
                        if (state.moderationBlocked)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              Spacing.xLarge,
                              0,
                              Spacing.xLarge,
                              Spacing.medium,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                JeebInfoNote.error(
                                  text: l10n
                                      .requestSubmitErrorProhibitedBlocked,
                                  identifier:
                                      'request_summary_moderation_blocked',
                                ),
                                const SizedBox(height: Spacing.small),
                                JeebCtaButton.primary(
                                  label: l10n.actionBack,
                                  identifier:
                                      'request_summary_moderation_exit_cta',
                                  onTap: () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/');
                                    }
                                  },
                                ),
                              ],
                            ),
                          )
                        else
                          BroadcastFooter(isSubmitting: state.isSubmitting),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onSubmitFailure(BuildContext context, RequestSummaryState state) {
    final cubit = context.read<RequestSummaryCubit>();
    final l10n = AppLocalizations.of(context);
    // No Retry on a terminal kind (401/403/404): an inert button is worse
    // than none.
    final bool retryable = failureCopy(l10n, state.error!).retryable;
    showJeebErrorSnack(
      context,
      failure: state.error!,
      identifier: 'request_summary_submit_error',
      retryLabel: l10n.actionRetry,
      onRetry: retryable ? cubit.submit : null,
    );
    cubit.acknowledgeError();
  }

  /// The 409 needs-ack round trip: acknowledge, then resubmit under the SAME
  /// Idempotency-Key, so no acknowledgement can create a second request.
  Future<void> _onModerationAckRequired(
    BuildContext context,
    RequestSummaryState state,
  ) async {
    final cubit = context.read<RequestSummaryCubit>();
    final matches = state.moderationMatches;
    cubit.acknowledgeModeration();
    if (!sl.isRegistered<ProhibitedAcknowledgmentRepository>()) {
      // Without the sheet the 409 would vanish silently; say what happened.
      showJeebErrorSnack(
        context,
        message:
            AppLocalizations.of(context).requestSubmitErrorProhibitedNeedsAck,
        identifier: 'request_summary_moderation_needs_ack',
      );
      return;
    }
    final bool? acknowledged = await showProhibitedAcknowledgmentDialog(
      context,
      repository: sl<ProhibitedAcknowledgmentRepository>(),
      matches: matches,
    );
    if (acknowledged == true && context.mounted) {
      await cubit.submit();
    }
  }
}
