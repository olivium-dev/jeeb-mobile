// Shared dev-only fixtures for `DisplayNameSetupScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_09_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/profile_name/presentation/display_name_setup_screen.dart`.
//
// The screen's whole data axis is one enum — [DisplayNameStatus] — so a
// "fixture" here is either the repository the screen builds its own cubit over
// (`idle`, the only status reachable that way) or a [DisplayNameCubit] already
// driven onto the status under review. The screen's `cubit:` seam exists for
// exactly this: `build()` otherwise constructs its own cubit from
// `repository`/`refreshSignals`, and `saving`/`failure`/`saved` have no other
// entry point from outside.
//
// Nothing here can reach the network or the DI graph. Every repository below is
// a local `implements DisplayNameRepository` with no transport, and none of the
// cubits is given a [ProfileRefreshSignals], so nothing is broadcast either.
// The `CatalogNetworkGuard` both surfaces install is the net, not the plan.
//
// Two things about the driven cubits, both deliberate:
//
//  * **`saving` and `saved` are seeded EAGERLY.** `submit` emits `saving`
//    synchronously (before its first `await`), so calling it un-awaited in the
//    factory leaves the cubit on the status the fixture is named for by the
//    time either surface builds the screen. Both are read by the screen's
//    `builder`, which runs on the first frame, so a still state is enough.
//  * **`failure` CANNOT be seeded, and is driven one frame after mount
//    instead** — see [DisplayNameSetupScreenPreviewDriver]. The screen surfaces
//    failure through `BlocConsumer.listener`, which does not fire for the state
//    present at first build, so a cubit already on `failure` when the screen
//    mounts renders an ordinary, error-free form: no snackbar, nothing. An
//    eager `submit()` in the factory is a RACE between the rejected future's
//    microtask and the mount — it happens to land after the mount in a
//    synchronous `build()` (the Screen Catalog, the preview canvas) and BEFORE
//    it under `WidgetTester.pumpWidget`, where the error then never appears.
//    The driver removes the race from both surfaces. This is a property of the
//    screen, not of the fixture; the preview section says so at length.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:jeeb_mobile/features/profile_name/application/display_name_cubit.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';

/// A PUT that always succeeds, immediately.
///
/// Used for the idle state, where nothing is submitted at all unless a reviewer
/// types a name and taps Continue in the canvas — at which point this is what
/// keeps that tap local.
class _AcceptingDisplayNameRepository implements DisplayNameRepository {
  const _AcceptingDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) async {}
}

/// A PUT that never resolves, pinning the cubit on `saving` for a stable frame.
///
/// Also the honest shape of the real thing: `DioDisplayNameRepository` issues a
/// `GET /v1/users/me` followed by a `PUT /api/User/profile` and sets no timeout
/// of its own, so "in flight forever" is a state the shipped screen can reach.
class _PendingDisplayNameRepository implements DisplayNameRepository {
  const _PendingDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) => Completer<void>().future;
}

/// A PUT that rejects the way the transport rejects: the same typed
/// [DisplayNameRepositoryException] `DioDisplayNameRepository` maps a
/// connection error onto.
class _FailingDisplayNameRepository implements DisplayNameRepository {
  const _FailingDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) async {
    throw const DisplayNameRepositoryException(DisplayNameFailure.network);
  }
}

/// The designed states both dev surfaces render.
abstract final class DisplayNameSetupScreenPreviewFixtures {
  /// The name the driven fixtures submit.
  ///
  /// It never reaches the text field — the screen owns its
  /// `TextEditingController` privately and has no seam to seed it — so this is
  /// only ever the argument `submit` was called with. Pinned as a constant so a
  /// test can say which name is in flight without repeating the literal.
  static const String submittedName = 'Ahmad Khaled';

  /// The repository behind the idle state: a local no-op, never DI's.
  static const DisplayNameRepository accepting =
      _AcceptingDisplayNameRepository();

  /// A PUT that never resolves.
  static const DisplayNameRepository pending = _PendingDisplayNameRepository();

  /// A PUT that rejects with a network failure.
  static const DisplayNameRepository failing = _FailingDisplayNameRepository();

  /// The cubit the screen would build for itself in the idle state.
  ///
  /// The catalog's idle state passes [accepting] through the `repository:` seam
  /// instead and lets the screen build this exact cubit; the preview uses the
  /// same seam. Kept here so a surface that needs the cubit directly does not
  /// re-derive it.
  static DisplayNameCubit idle() => DisplayNameCubit(repository: accepting);

  /// Pinned on `saving`: the PUT is in flight and will never land.
  static DisplayNameCubit saving() {
    final DisplayNameCubit cubit = DisplayNameCubit(repository: pending);
    unawaited(cubit.submit(submittedName));
    return cubit;
  }

  /// `idle` over a PUT that will reject.
  ///
  /// Deliberately NOT submitted here: seat it under a
  /// [DisplayNameSetupScreenPreviewDriver], which fires the submit one frame
  /// after the screen has mounted so the `saving → failure` transition happens
  /// with the screen's `BlocConsumer.listener` already subscribed. See the file
  /// header for why an eager submit is a race.
  static DisplayNameCubit rejecting() => DisplayNameCubit(repository: failing);

  /// `saved` — reached with **no repository at all**.
  ///
  /// This is not a contrivance for the dev surfaces: it is the branch
  /// `DisplayNameSetupScreen._resolveRepository()` falls through to when the
  /// `repository:` seam is null and `Dio` is not registered in the DI graph.
  /// `DisplayNameCubit.submit` then emits `saved` without a transport, so the
  /// step reports success for a name that was never sent anywhere.
  ///
  /// Emitted synchronously, so a surface built over this cubit mounts with
  /// `saved` already current — which is also why `onDone` is never called from
  /// it (the listener does not fire for the state present at first build).
  static DisplayNameCubit savedWithoutRepository() {
    final DisplayNameCubit cubit = DisplayNameCubit();
    unawaited(cubit.submit(submittedName));
    return cubit;
  }
}

/// Fires `cubit.submit` one frame AFTER [child] has mounted.
///
/// The only way either dev surface can render the screen's failure state. The
/// error copy is raised from `BlocConsumer.listener`, and a listener does not
/// run for the state present at first build — so `failure` has to ARRIVE while
/// the screen is watching. Doing that from a post-frame callback makes it
/// deterministic; doing it from the fixture factory makes it a race with the
/// mount that the widget-test binding loses.
///
/// [child] is taken rather than built here so the CALLER constructs the screen:
/// `tool/preview_coverage.dart` counts a screen as covered only when its own
/// preview section literally constructs it.
class DisplayNameSetupScreenPreviewDriver extends StatefulWidget {
  const DisplayNameSetupScreenPreviewDriver({
    super.key,
    required this.cubit,
    required this.child,
  });

  /// The cubit [child] was built over — the same instance, or the submit lands
  /// somewhere nothing is watching.
  final DisplayNameCubit cubit;

  /// The surface under the cubit — a `DisplayNameSetupScreen` at every call
  /// site.
  final Widget child;

  @override
  State<DisplayNameSetupScreenPreviewDriver> createState() =>
      _DisplayNameSetupScreenPreviewDriverState();
}

class _DisplayNameSetupScreenPreviewDriverState
    extends State<DisplayNameSetupScreenPreviewDriver> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        widget.cubit.submit(
          DisplayNameSetupScreenPreviewFixtures.submittedName,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
