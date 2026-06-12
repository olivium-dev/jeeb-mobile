import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../application/request_summary_cubit.dart';

class RequestSummaryScreen extends StatelessWidget {
  const RequestSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestSummaryCubit, RequestSummaryState>(
      builder: (context, state) {
        final draft = state.draft;
        if (draft == null) return const OmdsLoadingState();
        return Scaffold(
          appBar: const OMDSAppBar(title: 'Review Request'),
          body: _RequestSummaryBody(state: state),
        );
      },
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
    return OmdsLoadingButton(
      text: 'Submit Request',
      isLoading: isSubmitting,
      onTap: () => context.read<RequestSummaryCubit>().submit(),
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
