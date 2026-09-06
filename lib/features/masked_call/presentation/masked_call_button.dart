import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../application/masked_call_cubit.dart';
import '../domain/masked_call_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; gateway carries an equally-uncalled twin endpoint — see docs/project-understanding/reconciliation/orphans.md
class MaskedCallButton extends StatelessWidget {

  const MaskedCallButton({super.key, required this.orderId, this.cubit});
  final String orderId;

  /// Optional cubit override. Defaults to null (unchanged production
  /// behavior: a fresh [MaskedCallCubit] is created). Lets the Dev Tool
  final MaskedCallCubit? cubit;

  /// Null when DI carries none: the cubit then reports an honest failure
  /// instead of fabricating a session id for a call nobody placed.
  static MaskedCallRepository? _resolveRepository() =>
      sl.isRegistered<MaskedCallRepository>()
          ? sl<MaskedCallRepository>()
          : null;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => cubit ?? MaskedCallCubit(repository: _resolveRepository()),
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
      builder: (context, state) => Semantics(
        identifier: 'masked_call_cta',
        button: true,
        container: true,
        child: OmdsLoadingButton(
          text: AppLocalizations.of(context).callButtonLabel,
          isLoading: state.isLoading,
          onTap: () => context.read<MaskedCallCubit>().initiateCall(orderId),
        ),
      ),
    );
  }

  void _onState(BuildContext context, MaskedCallState state) {
    if (state.failed) {
      showJeebErrorSnack(
        context,
        message: AppLocalizations.of(context).callInitiateFailed,
        identifier: 'masked_call_error',
      );
      // Without this the flag survives every rebuild and re-fires the snack.
      context.read<MaskedCallCubit>().acknowledgeFailure();
    }
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

/// The canvas box for a full-bleed CTA: phone width, one 48 dp pill, and enough
const Size _maskedCallButtonCtaBox = Size(390, 120);

/// Taller box for the state that ends in a floating snackbar, which is laid out
const Size _maskedCallButtonSnackbarBox = Size(390, 260);

/// The same order id the Screen Catalog uses for this widget
const String _maskedCallButtonOrderId = 'DLV-9001';

class _MaskedCallButtonSeededCubit extends MaskedCallCubit {
  _MaskedCallButtonSeededCubit([MaskedCallState? seed]) {
    if (seed != null) emit(seed);
  }

  /// Emits [state] later, once a caller decides the consumer is listening.
  /// `emit` is `@protected`, so a host that wants to drive this cubit after
  void seedLater(MaskedCallState state) {
    if (!isClosed) emit(state);
  }
}

Widget _maskedCallButtonSeeded(MaskedCallState seed) => TickerMode(
      enabled: false,
      child: MaskedCallButton(
        orderId: _maskedCallButtonOrderId,
        cubit: _MaskedCallButtonSeededCubit(seed),
      ),
    );

class _MaskedCallButtonFailOnMount extends StatefulWidget {
  const _MaskedCallButtonFailOnMount({required this.outcome});

  final MaskedCallState outcome;

  @override
  State<_MaskedCallButtonFailOnMount> createState() =>
      _MaskedCallButtonFailOnMountState();
}

class _MaskedCallButtonFailOnMountState
    extends State<_MaskedCallButtonFailOnMount> {
  final _MaskedCallButtonSeededCubit _cubit = _MaskedCallButtonSeededCubit();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cubit.seedLater(widget.outcome);
    });
  }

  /// The local [ScaffoldMessenger] is what makes this self-contained: the
  /// widget presents its error through `ScaffoldMessenger.of(context)`, and a
  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.large),
                child: MaskedCallButton(
                  orderId: _maskedCallButtonOrderId,
                  cubit: _cubit,
                ),
              ),
            ),
          ),
        ),
      );
}

@JeebPreview(
  group: 'masked_call',
  name: 'Idle · ready to call',
  size: _maskedCallButtonCtaBox,
  matrix: true,
)
Widget maskedCallButtonIdle() => const TickerMode(
      enabled: false,
      child: MaskedCallButton(orderId: _maskedCallButtonOrderId),
    );

@JeebPreview(
  group: 'masked_call',
  name: 'Placing the call',
  size: _maskedCallButtonCtaBox,
)
Widget maskedCallButtonPlacing() =>
    _maskedCallButtonSeeded(const MaskedCallState(isLoading: true));

@JeebPreview(
  group: 'masked_call',
  name: 'Session live · nothing changed',
  size: _maskedCallButtonCtaBox,
)
Widget maskedCallButtonSessionLive() => _maskedCallButtonSeeded(
      const MaskedCallState(sessionId: 'session-$_maskedCallButtonOrderId'),
    );

@JeebPreview(
  group: 'masked_call',
  name: 'Failure before subscribe · no trace',
  size: _maskedCallButtonCtaBox,
)
Widget maskedCallButtonFailedSilently() =>
    _maskedCallButtonSeeded(const MaskedCallState(failed: true));

@JeebPreview(
  group: 'masked_call',
  name: 'Failed · error snackbar',
  size: _maskedCallButtonSnackbarBox,
  matrix: true,
)
Widget maskedCallButtonFailedSnackbar() => const _MaskedCallButtonFailOnMount(
      outcome: MaskedCallState(failed: true),
    );
