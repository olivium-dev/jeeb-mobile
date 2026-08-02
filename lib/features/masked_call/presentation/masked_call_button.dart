import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';
import '../application/masked_call_cubit.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; gateway carries an equally-uncalled twin endpoint — see docs/project-understanding/reconciliation/orphans.md
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
      showOmdsErrorSnackbar(
        context,
        message: AppLocalizations.of(context).callInitiateFailed,
      );
    }
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/masked_call/masked_call_button_preview_test.dart
// ===========================================================================
//
// [MaskedCallButton] is a `BlocConsumer<MaskedCallCubit, MaskedCallState>`, so
// every state below is driven the way a host screen drives it — through the
// `cubit:` seam the widget already exposes. Nothing here builds a repository:
// [MaskedCallCubit] has no collaborators at all (its `initiateCall` is a bare
// `Future.delayed`), so these previews are network-free by construction, not
// just by the guard in [jeebPreviewHost].
//
// Two shapes of preview live here, because this widget has two halves:
//
// * **Seeded** (`_maskedCallButtonSeeded`) — the `builder` half. A private
//   subclass emits the designed state from its constructor, i.e. BEFORE the
//   `BlocConsumer` subscribes, so the `listener` deliberately does NOT fire.
// * **On mount** (`_MaskedCallButtonFailOnMount`) — the `listener` half. The
//   same state is emitted one post-frame after the host has mounted, so the
//   consumer is subscribed and the error snackbar is presented through the
//   production code path rather than hand-placed. That is the only way to see
//   it: a seeded `failed` state renders IDENTICALLY to idle, because this
//   widget has no inline error affordance of its own.
//
// What the canvas shows, all of it pinned in the render test:
//
// * **Three of the five previews below draw the SAME pill.** Idle, "the call is
//   placed" (`sessionId` set) and "the call failed" all render one full-bleed
//   `Call` button. The widget has no inline affordance for success or for
//   failure — the only signal either ever gets is a 4-second snackbar, and a
//   failure that lands before the consumer subscribes gets nothing at all.
// * **The in-flight pill has no accessible name.** `OmdsLoadingButton` swaps
//   its `Text` for a spinner while loading, and the `Semantics` wrapper above
//   it is `container: true` with no `label` of its own, so the merged node
//   loses its only source of text: the CTA reads as an unlabelled, still-
//   enabled button for as long as the call is being placed.
// * **`failed` is unreachable from the real cubit.** `initiateCall` wraps a
//   `Future.delayed` in a `try/catch` that nothing can throw from, so the
//   snackbar preview below is the only way that branch is ever exercised.
//
// The spinner is frozen with `TickerMode(enabled: false)`: an indeterminate
// `CircularProgressIndicator` never stops scheduling frames, so the render
// tests' `pumpAndSettle` would hang on it.

/// The canvas box for a full-bleed CTA: phone width, one 48 dp pill, and enough
/// slack that the 200% rendering is not cropped by the box itself.
const Size _maskedCallButtonCtaBox = Size(390, 120);

/// Taller box for the state that ends in a floating snackbar, which is laid out
/// against the bottom of the host.
const Size _maskedCallButtonSnackbarBox = Size(390, 260);

/// The same order id the Screen Catalog uses for this widget
/// (`lib/devtool/catalog/entries/batch_06_entries.dart`), so the two browsers
/// show the same delivery.
const String _maskedCallButtonOrderId = 'DLV-9001';

/// A [MaskedCallCubit] parked on [seed] from its constructor.
///
/// [MaskedCallCubit] exposes no seed seam, and `isLoading` is otherwise
/// reachable only for the one second `initiateCall` sleeps, so emitting once
/// from the constructor is the whole implementation. Nothing is overridden:
/// tapping the button in the canvas still runs the production `initiateCall`.
///
/// The emit lands BEFORE `BlocConsumer` subscribes, so as far as the listener
/// is concerned the seeded state is the *initial* state and no snackbar fires —
/// see [_MaskedCallButtonFailOnMount] for that.
class _MaskedCallButtonSeededCubit extends MaskedCallCubit {
  _MaskedCallButtonSeededCubit([MaskedCallState? seed]) {
    if (seed != null) emit(seed);
  }

  /// Emits [state] later, once a caller decides the consumer is listening.
  /// `emit` is `@protected`, so a host that wants to drive this cubit after
  /// construction has to go through a member like this one.
  void seedLater(MaskedCallState state) {
    if (!isClosed) emit(state);
  }
}

/// The button over a cubit already parked on [seed].
///
/// [TickerMode] is disabled because the loading branch paints an indeterminate
/// `CircularProgressIndicator`, which never stops scheduling frames. It is
/// inert for every other state.
Widget _maskedCallButtonSeeded(MaskedCallState seed) => TickerMode(
      enabled: false,
      child: MaskedCallButton(
        orderId: _maskedCallButtonOrderId,
        cubit: _MaskedCallButtonSeededCubit(seed),
      ),
    );

/// Drives the button to [outcome] one post-frame after mount, so the
/// `BlocConsumer` is already subscribed and its `listener` half runs.
///
/// A [StatefulWidget] rather than a bare fixture function for two reasons. The
/// cubit has to be created while the host is being built — a cubit constructed
/// before `pumpWidget`/the canvas' first frame emits into a consumer that has
/// not subscribed yet, and the snackbar never appears. And the emit has to be
/// post-frame, because the listener pushes onto a [ScaffoldMessenger] that must
/// already be mounted. Same shape as `_SocialSignInSectionSignInOnMount`.
///
/// The cubit is deliberately NOT closed here: [MaskedCallButton] hands it to a
/// `BlocProvider(create: …)`, which owns and closes it.
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
  /// preview must not assume the canvas supplies one it may safely push onto.
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

/// Cold entry, wired exactly as production wires it: no injected cubit, so the
/// widget builds its own [MaskedCallCubit] and the pill is live.
///
/// The baseline every other state is read against, and the one the matrix is
/// really for. The label is a single centred word inside a full-bleed pill, so
/// AR RTL is where a stray `EdgeInsets.only` would show, and the pill's height
/// is a hard `Sizes.fourXLarge` (48 dp) that does NOT scale with text: at the
/// 200% rendering the label already occupies 40 of those 48 dp in EN and in AR,
/// leaving 4 dp of clearance top and bottom. It fits today with nothing to
/// spare — measured and pinned in the render test.
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

/// The call is being placed: `POST /calls` is in flight.
///
/// The whole label is replaced by a 20 dp spinner — the pill keeps its box and
/// loses every readable word, and the surface drops to 60% alpha. This is the
/// state to read with a screen reader in mind: with the `Text` gone there is
/// nothing left for the `container: true` semantics node to merge, so the CTA
/// announces as a button with no name (pinned in the render test).
@JeebPreview(
  group: 'masked_call',
  name: 'Placing the call',
  size: _maskedCallButtonCtaBox,
)
Widget maskedCallButtonPlacing() =>
    _maskedCallButtonSeeded(const MaskedCallState(isLoading: true));

/// The call succeeded — `sessionId` is set and the masked leg is live.
///
/// Open this beside `Idle · ready to call` in the canvas and look for the
/// difference: there is none. The widget never reads `sessionId`, so a placed
/// call and a call that was never started are the same frame, and the pill
/// invites the user to place a second one.
@JeebPreview(
  group: 'masked_call',
  name: 'Session live · nothing changed',
  size: _maskedCallButtonCtaBox,
)
Widget maskedCallButtonSessionLive() => _maskedCallButtonSeeded(
      const MaskedCallState(sessionId: 'session-$_maskedCallButtonOrderId'),
    );

/// A failure that arrives before the consumer subscribes — a rebuild, a
/// re-mount, or a host that seeds the cubit the way these previews do.
///
/// `BlocConsumer` runs its `listener` on state *changes* only, so a `failed`
/// initial state is swallowed whole: no snackbar, no inline error, no retry
/// hint. The frame is byte-identical to idle. That silence is the finding, and
/// it is why the failure below needs a whole separate preview to be visible at
/// all.
@JeebPreview(
  group: 'masked_call',
  name: 'Failure before subscribe · no trace',
  size: _maskedCallButtonCtaBox,
)
Widget maskedCallButtonFailedSilently() =>
    _maskedCallButtonSeeded(const MaskedCallState(failed: true));

/// The only visual a failure ever gets: a transient floating snackbar.
///
/// Pushed through the widget's own `listener`, not hand-placed.
/// `callInitiateFailed` is the only full sentence this widget ever shows, in a
/// single unbounded `Text`, and its length and script both swing by locale —
/// which is what the matrix is here to show. The snackbar, not the button, is
/// the piece that clips first at 200%.
///
/// Note what is left behind once it times out: the pill underneath is back to
/// plain `Call`, with nothing recording that the last attempt failed.
@JeebPreview(
  group: 'masked_call',
  name: 'Failed · error snackbar',
  size: _maskedCallButtonSnackbarBox,
  matrix: true,
)
Widget maskedCallButtonFailedSnackbar() => const _MaskedCallButtonFailOnMount(
      outcome: MaskedCallState(failed: true),
    );
