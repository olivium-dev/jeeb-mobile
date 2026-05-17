import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../application/masked_call_cubit.dart';

class MaskedCallButton extends StatelessWidget {
  final String orderId;

  const MaskedCallButton({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MaskedCallCubit(),
      child: BlocConsumer<MaskedCallCubit, MaskedCallState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        },
        builder: (context, state) {
          return FilledButton.icon(
            onPressed: state.isLoading
                ? null
                : () => context.read<MaskedCallCubit>().initiateCall(orderId),
            icon: state.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.phone),
            label: const Text('Call'),
          );
        },
      ),
    );
  }
}
