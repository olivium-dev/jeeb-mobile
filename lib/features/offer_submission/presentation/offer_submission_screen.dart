import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../application/offer_submission_cubit.dart';

class OfferSubmissionScreen extends StatelessWidget {
  const OfferSubmissionScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OfferSubmissionCubit(),
      child: Scaffold(
        appBar: const OMDSAppBar(title: 'Submit Offer'),
        body: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: _OfferSubmissionForm(requestId: requestId),
        ),
      ),
    );
  }
}

class _OfferSubmissionForm extends StatelessWidget {
  const _OfferSubmissionForm({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfferSubmissionCubit, OfferSubmissionState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PriceField(),
            const SizedBox(height: Spacing.medium),
            _EtaField(),
            if (state.error != null) ...[
              const SizedBox(height: Spacing.xSmall),
              _ErrorText(message: state.error!),
            ],
            const Spacer(),
            _SubmitButton(requestId: requestId, state: state),
          ],
        );
      },
    );
  }
}

class _PriceField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OmdsTextField(
      labelText: 'Offer Price (USD)',
      keyboardType: TextInputType.number,
      prefixIcon: const Icon(Icons.attach_money),
      onChanged: (v) {
        final price = double.tryParse(v);
        if (price != null) {
          context.read<OfferSubmissionCubit>().setPrice(price);
        }
      },
    );
  }
}

class _EtaField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OmdsTextField(
      labelText: 'Estimated Time (minutes)',
      keyboardType: TextInputType.number,
      prefixIcon: const Icon(Icons.timer),
      onChanged: (v) {
        final mins = int.tryParse(v);
        if (mins != null) {
          context.read<OfferSubmissionCubit>().setEstimatedMinutes(mins);
        }
      },
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.requestId, required this.state});

  final String requestId;
  final OfferSubmissionState state;

  @override
  Widget build(BuildContext context) {
    return OmdsLoadingButton(
      text: 'Submit Offer',
      isLoading: state.isSubmitting,
      onTap: () => context.read<OfferSubmissionCubit>().submit(requestId),
    );
  }
}
