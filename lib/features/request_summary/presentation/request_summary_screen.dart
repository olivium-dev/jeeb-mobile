import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../application/request_summary_cubit.dart';

class RequestSummaryScreen extends StatelessWidget {
  const RequestSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // orders-compose-request-in-chat (P1, SC-030/SC-031, D83): on a successful
    // submit the created request now opens the ORDER-CHAT COMPOSE surface
    // (`/chat/<requestId>`, the `chat-detail` route) instead of dead-ending
    // back at the Requests tab (`/`). This is the missing compose-the-request-
    // in-chat ENTRY: `ChatDetailScreen` resolves the not-yet-matched request
    // into its compose state, where the FIRST message the customer sends fires
    // the broadcast hook (`POST /v1/matching/find-jeebers` + `/v1/matching/
    // broadcast`, via the live gateway → :10090) and routes to
    // `waiting-no-coverage` (JM-026). `goNamed` (not push) so the create-flow
    // stack — request-type → request-summary — is cleared behind the chat.
    //
    // The submit cubit only flips isSubmitted once, so listenWhen fires exactly
    // on the false → true edge. A failed submit surfaces an OMDS error snackbar
    // on the null → non-null `error` edge and leaves the screen in place so the
    // user can retry.
    return MultiBlocListener(
      listeners: [
        BlocListener<RequestSummaryCubit, RequestSummaryState>(
          listenWhen: (p, c) => !p.isSubmitted && c.isSubmitted,
          listener: (context, state) {
            final requestId = state.requestId;
            if (requestId != null && requestId.isNotEmpty) {
              context.goNamed(
                'chat-detail',
                pathParameters: {'id': requestId},
              );
            } else {
              // Defensive: a created request with no id can't open a compose
              // chat, so fall back to the Requests tab rather than `/chat/`.
              context.go('/');
            }
          },
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
          return Scaffold(
            appBar: const OMDSAppBar(title: 'Review Request'),
            body: _RequestSummaryBody(state: state),
          );
        },
      ),
    );
  }
}

class _RequestSummaryBody extends StatelessWidget {
  const _RequestSummaryBody({required this.state});

  final RequestSummaryState state;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft!;
    return ListView(
      padding: const EdgeInsets.all(Spacing.medium),
      children: [
        _SectionCard(title: 'Description', child: Text(draft.description)),
        if (draft.transcription != null)
          _SectionCard(
            title: 'Transcription',
            child: Text(draft.transcription!),
          ),
        if (draft.photoUrls.isNotEmpty)
          _SectionCard(
            title: 'Photos',
            child: Text('${draft.photoUrls.length} photo(s) attached'),
          ),
        if (draft.tierName != null)
          _SectionCard(title: 'Delivery Tier', child: Text(draft.tierName!)),
        if (draft.pickupAddress != null)
          _SectionCard(title: 'Pickup', child: Text(draft.pickupAddress!)),
        if (draft.dropoffAddress != null)
          _SectionCard(
            title: 'Drop-off',
            child: Text(draft.dropoffAddress!),
          ),
        const SizedBox(height: Spacing.xLarge),
        _SubmitButton(isSubmitting: state.isSubmitting),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isSubmitting});

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_summary_submit',
      button: true,
      child: OmdsLoadingButton(
        key: const Key('request_summary.submit'),
        text: 'Submit Request',
        isLoading: isSubmitting,
        onTap: () => context.read<RequestSummaryCubit>().submit(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: _SectionCardContent(title: title, child: child),
        ),
      ),
    );
  }
}

class _SectionCardContent extends StatelessWidget {
  const _SectionCardContent({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.xSmall),
        child,
      ],
    );
  }
}
