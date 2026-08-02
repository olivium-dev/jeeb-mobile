import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/request_summary_cubit.dart';

class RequestSummaryScreen extends StatelessWidget {
  const RequestSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          return Scaffold(
            appBar: OMDSAppBar(title: AppLocalizations.of(context).requestSummaryTitle),
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
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(Spacing.medium),
      children: [
        _SectionCard(
          title: l10n.requestSummarySectionDescription,
          child: Text(draft.description),
        ),
        if (draft.transcription != null)
          _SectionCard(
            title: l10n.requestSummarySectionTranscription,
            child: Text(draft.transcription!),
          ),
        if (draft.photoUrls.isNotEmpty)
          _SectionCard(
            title: l10n.requestSummarySectionPhotos,
            child: Text(l10n.requestSummaryPhotosAttached(draft.photoUrls.length)),
          ),
        if (draft.tierName != null)
          _SectionCard(
            title: l10n.requestSummarySectionTier,
            child: Text(draft.tierName!),
          ),
        if (draft.pickupAddress != null)
          _SectionCard(
            title: l10n.requestSummarySectionPickup,
            child: Text(draft.pickupAddress!),
          ),
        if (draft.dropoffAddress != null)
          _SectionCard(
            title: l10n.requestSummarySectionDropoff,
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
        text: AppLocalizations.of(context).requestSummarySubmit,
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
