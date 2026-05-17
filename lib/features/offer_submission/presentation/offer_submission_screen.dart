import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../application/offer_submission_cubit.dart';

class OfferSubmissionScreen extends StatelessWidget {
  final String requestId;
  const OfferSubmissionScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OfferSubmissionCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Submit Offer')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<OfferSubmissionCubit, OfferSubmissionState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Offer Price (LBP)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    onChanged: (v) {
                      final price = double.tryParse(v);
                      if (price != null) context.read<OfferSubmissionCubit>().setPrice(price);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Time (minutes)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    onChanged: (v) {
                      final mins = int.tryParse(v);
                      if (mins != null) context.read<OfferSubmissionCubit>().setEstimatedMinutes(mins);
                    },
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 8),
                    Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: state.isSubmitting ? null : () => context.read<OfferSubmissionCubit>().submit(requestId),
                    child: state.isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit Offer'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
