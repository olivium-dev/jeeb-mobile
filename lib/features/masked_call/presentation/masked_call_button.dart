import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../application/masked_call_cubit.dart';

class MaskedCallButton extends StatelessWidget {
  const MaskedCallButton({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          MaskedCallCubit(dio: sl.isRegistered<Dio>() ? sl<Dio>() : null),
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
      showOmdsErrorSnackbar(context, message: state.error!);
      return;
    }
    final proxyNumber = state.proxyNumber;
    if (proxyNumber != null) {
      unawaited(_launchMaskedCall(context, proxyNumber));
    } else if (state.sessionId != null && !state.isLoading) {
      showOmdsSnackbar(context, message: 'Call session ready');
    }
  }

  Future<void> _launchMaskedCall(BuildContext context, String number) async {
    final launched = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!launched && context.mounted) {
      showOmdsErrorSnackbar(
        context,
        message: 'Could not open the phone dialer.',
      );
    }
  }
}
