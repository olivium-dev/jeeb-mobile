import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../transcription/domain/transcript_audio_player.dart';
import '../application/request_summary_cubit.dart';
import 'widgets/broadcast_footer.dart';
import 'widgets/request_ticket.dart';

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
    // false → true edge. A failed submit surfaces an OMDS error snackbar on
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
              showOmdsErrorSnackbar(context, message: state.error!),
        ),
      ],
      child: BlocBuilder<RequestSummaryCubit, RequestSummaryState>(
        builder: (context, state) {
          final draft = state.draft;
          if (draft == null) return const OmdsLoadingState();
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: SafeArea(
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
                    // Expanded + scroll view (never a bare Spacer) reproduces
                    // the board's flex-1 gap AND survives 200% text scale.
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          Spacing.xLarge,
                          Spacing.large,
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
