import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';
import '../application/masked_call_cubit.dart';

class MaskedCallButton extends StatelessWidget {

  const MaskedCallButton({super.key, required this.orderId, this.cubit});
  final String orderId;

  /// Optional cubit override. Defaults to null (unchanged production
  /// behavior: a fresh [MaskedCallCubit] is created). Lets the Dev Tool
  /// screen catalog (DT-04) seed a specific designed state (e.g. mid-call)
  /// without a network dependency — no existing call site passes this.
  final MaskedCallCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => cubit ?? MaskedCallCubit(),
      child: _MaskedCallButtonView(orderId: orderId),
    );
  }
}

class _MaskedCallButtonView extends StatelessWidget {
  const _MaskedCallButtonView({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MaskedCallCubit, MaskedCallState>(
      listener: _onState,
      builder: (context, state) => OmdsLoadingButton(
        text: AppLocalizations.of(context).callButtonLabel,
        isLoading: state.isLoading,
        onTap: () => context.read<MaskedCallCubit>().initiateCall(orderId),
      ),
    );
  }

  void _onState(BuildContext context, MaskedCallState state) {
    if (state.failed) {
      showOmdsErrorSnackbar(
        context,
        message: AppLocalizations.of(context).callInitiateFailed,
      );
    }
  }
}
