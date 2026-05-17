import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../application/request_summary_cubit.dart';

class RequestSummaryScreen extends StatelessWidget {
  const RequestSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestSummaryCubit, RequestSummaryState>(
      builder: (context, state) {
        final draft = state.draft;
        if (draft == null) return const Center(child: CircularProgressIndicator());

        return Scaffold(
          appBar: AppBar(title: const Text('Review Request')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(title: 'Description', child: Text(draft.description)),
              if (draft.transcription != null)
                _SectionCard(title: 'Transcription', child: Text(draft.transcription!)),
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
                _SectionCard(title: 'Drop-off', child: Text(draft.dropoffAddress!)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.isSubmitting ? null : () => context.read<RequestSummaryCubit>().submit(),
                child: state.isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Request'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
