import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../application/masked_call_cubit.dart';

class MaskedCallButton extends StatelessWidget {

  const MaskedCallButton({super.key, required this.orderId, this.cubit});
  final String orderId;

  /// Optional cubit override. Defaults to `null`, which preserves the exact
  /// original behaviour: a fresh [MaskedCallCubit] is created locally via
  /// `BlocProvider(create: ...)`. Passing an explicit [cubit] instead wraps
  /// the view in a `BlocProvider.value`, letting a host with no ambient DI
  /// (e.g. the devtool catalog) preview a pre-seeded call state for NO
  /// NETWORK. Additive-only: production call sites that never pass [cubit]
  /// are completely unaffected.
  final MaskedCallCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<MaskedCallCubit>.value(
        value: provided,
        child: _MaskedCallButtonView(orderId: orderId),
      );
    }
    return BlocProvider(
      create: (_) => MaskedCallCubit(),
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
        text: 'Call',
        isLoading: state.isLoading,
        onTap: () => context.read<MaskedCallCubit>().initiateCall(orderId),
      ),
    );
  }

  void _onState(BuildContext context, MaskedCallState state) {
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!)),
      );
    }
  }
}
