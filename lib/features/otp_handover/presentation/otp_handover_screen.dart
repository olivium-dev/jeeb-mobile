import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../application/otp_handover_cubit.dart';
import '../application/otp_handover_state.dart';

class OtpHandoverScreen extends StatelessWidget {
  final String deliveryId;
  final bool isClient;
  const OtpHandoverScreen({
    super.key,
    required this.deliveryId,
    required this.isClient,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OMDSAppBar(title: isClient ? 'Your OTP' : 'Enter OTP'),
      body: BlocConsumer<OtpHandoverCubit, OtpHandoverState>(
        listener: _onState,
        builder: (context, state) => _OtpBody(state: state, isClient: isClient),
      ),
    );
  }

  void _onState(BuildContext context, OtpHandoverState state) {
    if (state.mode == OtpHandoverViewMode.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery confirmed!')),
      );
      Navigator.of(context).pop(true);
    }
    if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage!)),
      );
    }
  }
}

class _OtpBody extends StatelessWidget {
  const _OtpBody({required this.state, required this.isClient});
  final OtpHandoverState state;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    switch (state.mode) {
      case OtpHandoverViewMode.loading:
        return const Center(child: OmdsLoadingState());
      case OtpHandoverViewMode.error:
        return OmdsErrorState(
          message: state.errorMessage ?? 'Something went wrong',
          onRetry: () => context.read<OtpHandoverCubit>().retry(),
        );
      case OtpHandoverViewMode.ready:
      case OtpHandoverViewMode.submitting:
      case OtpHandoverViewMode.success:
        return Padding(
          padding: const EdgeInsets.all(Spacing.xLarge),
          child: isClient
              ? _ClientOtpDisplay(code: state.handoverCode ?? '----')
              : _JeeberOtpEntry(
                  isSubmitting: state.mode == OtpHandoverViewMode.submitting,
                ),
        );
    }
  }
}

class _ClientOtpDisplay extends StatelessWidget {
  final String code;
  const _ClientOtpDisplay({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Share this code with your Jeeber',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xLarge),
          _OtpCodeChip(code: code),
          const SizedBox(height: Spacing.medium),
          Text(
            'Do not share until you receive your items',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OtpCodeChip extends StatelessWidget {
  const _OtpCodeChip({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.twoXLarge,
        vertical: Spacing.medium,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: Text(
        code,
        style: theme.textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: Spacing.small,
        ),
      ),
    );
  }
}

class _JeeberOtpEntry extends StatefulWidget {
  final bool isSubmitting;
  const _JeeberOtpEntry({required this.isSubmitting});

  @override
  State<_JeeberOtpEntry> createState() => _JeeberOtpEntryState();
}

class _JeeberOtpEntryState extends State<_JeeberOtpEntry> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Enter the OTP from the Client',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xLarge),
          OmdsOtpInput(
            length: 4,
            onChanged: (value) => setState(() => _code = value),
            onCompleted: (value) {
              if (!widget.isSubmitting) {
                context.read<OtpHandoverCubit>().submitOtp(value);
              }
            },
          ),
          const SizedBox(height: Spacing.xLarge),
          OmdsLoadingButton(
            text: 'Verify OTP',
            isLoading: widget.isSubmitting,
            isEnabled: _code.length == 4,
            onTap: () => context.read<OtpHandoverCubit>().submitOtp(_code),
          ),
        ],
      ),
    );
  }
}
