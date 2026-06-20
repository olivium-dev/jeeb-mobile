import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../application/masked_call_cubit.dart';
import '../data/url_launcher_phone_dialer.dart';
import '../domain/masked_call_repository.dart';
import '../domain/phone_dialer.dart';

/// Masked / anonymised call CTA (orders-masked-call).
///
/// Tapping it brokers a masked-call session over the gateway then opens the
/// native dialer pre-filled with the returned proxy number. Surfaced in the
/// order-chat / delivery-order-chat / order-tracking surfaces for COD
/// coordination. Neither party sees the other's real number.
class MaskedCallButton extends StatelessWidget {
  const MaskedCallButton({
    super.key,
    required this.orderId,
    this.repository,
    this.dialer,
  });

  final String orderId;

  /// Injectable seams — production resolves from DI; tests inject doubles.
  final MaskedCallRepository? repository;
  final PhoneDialer? dialer;

  @override
  Widget build(BuildContext context) {
    final repo = repository ??
        (sl.isRegistered<MaskedCallRepository>()
            ? sl<MaskedCallRepository>()
            : null);
    if (repo == null) {
      // Repository not registered (bare GetIt harness) — hide the affordance
      // rather than red-screening.
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (_) => MaskedCallCubit(
        repository: repo,
        dialer: dialer ?? const UrlLauncherPhoneDialer(),
      ),
      child: _MaskedCallButtonView(orderId: orderId),
    );
  }
}

class _MaskedCallButtonView extends StatelessWidget {
  const _MaskedCallButtonView({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<MaskedCallCubit, MaskedCallState>(
      listenWhen: (p, n) => p.error != n.error && n.error != null,
      listener: (context, state) => _onError(context, l10n, state),
      builder: (context, state) => Semantics(
        identifier: 'masked-call-button',
        button: true,
        child: OmdsLoadingButton(
          text: l10n.maskedCallButton,
          isLoading: state.isLoading,
          onTap: () => context.read<MaskedCallCubit>().initiateCall(orderId),
        ),
      ),
    );
  }

  void _onError(
    BuildContext context,
    AppLocalizations l10n,
    MaskedCallState state,
  ) {
    final key = state.error;
    if (key == null) return;
    final String message;
    switch (key) {
      case 'maskedCallErrorNetwork':
        message = l10n.maskedCallErrorNetwork;
      case 'maskedCallErrorDialer':
        message = l10n.maskedCallErrorDialer;
      default:
        message = l10n.maskedCallErrorUnavailable;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
