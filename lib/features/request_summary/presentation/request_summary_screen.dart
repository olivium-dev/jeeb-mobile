import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
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
          listenWhen: (p, c) => p.error == null && c.error != null,
          listener: (context, state) =>
              _showSubmitError(context, state.error!),
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
                                headline: l10n.requestSummaryTitle,
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

  /// The OMDS error snackbar paints white ink on `colorScheme.error` (#FF5252),
  /// which fails AA on navy; §9's ratified danger pair is the container quartet.
  static void _showSubmitError(BuildContext context, String message) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        backgroundColor: scheme.errorContainer,
      ),
    );
  }
}
