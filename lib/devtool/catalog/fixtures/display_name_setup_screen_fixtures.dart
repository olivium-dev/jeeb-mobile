// Shared dev-only fixtures for `DisplayNameSetupScreen`.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:jeeb_mobile/features/profile_name/application/display_name_cubit.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';

/// A PUT that always succeeds, immediately.
/// Used for the idle state, where nothing is submitted at all unless a reviewer
/// types a name and taps Continue in the canvas — at which point this is what
class _AcceptingDisplayNameRepository implements DisplayNameRepository {
  const _AcceptingDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) async {}
}

/// A PUT that never resolves, pinning the cubit on `saving` for a stable frame.
/// Also the honest shape of the real thing: `DioDisplayNameRepository` issues a
/// `GET /v1/users/me` followed by a `PUT /api/User/profile` and sets no timeout
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

/// A PUT the gateway refuses: `/v1/users/me` answered without a `userId`, or a
/// 401/403 — the identity change is rejected, not merely delayed.
class _UnauthorizedDisplayNameRepository implements DisplayNameRepository {
  const _UnauthorizedDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) async {
    throw const DisplayNameRepositoryException(
      DisplayNameFailure.unauthorized,
    );
  }
}

/// The designed states both dev surfaces render.
abstract final class DisplayNameSetupScreenPreviewFixtures {
  /// The name the driven fixtures submit.
  /// It never reaches the text field — the screen owns its
  static const String submittedName = 'Ahmad Khaled';

  /// The repository behind the idle state: a local no-op, never DI's.
  static const DisplayNameRepository accepting =
      _AcceptingDisplayNameRepository();

  /// A PUT that never resolves.
  static const DisplayNameRepository pending = _PendingDisplayNameRepository();

  /// A PUT that rejects with a network failure.
  static const DisplayNameRepository failing = _FailingDisplayNameRepository();

  /// A PUT the gateway refuses outright (UX-39 / UX-23).
  static const DisplayNameRepository unauthorized =
      _UnauthorizedDisplayNameRepository();

  /// `idle` over a PUT that will be refused; drive it to see the rejection.
  static DisplayNameCubit unauthorizedRejecting() =>
      DisplayNameCubit(repository: unauthorized);

  /// The cubit the screen would build for itself in the idle state.
  /// The catalog's idle state passes [accepting] through the `repository:` seam
  static DisplayNameCubit idle() => DisplayNameCubit(repository: accepting);

  /// Pinned on `saving`: the PUT is in flight and will never land.
  static DisplayNameCubit saving() {
    final DisplayNameCubit cubit = DisplayNameCubit(repository: pending);
    unawaited(cubit.submit(submittedName));
    return cubit;
  }

  /// `idle` over a PUT that will reject.
  /// Deliberately NOT submitted here: seat it under a
  static DisplayNameCubit rejecting() => DisplayNameCubit(repository: failing);

  /// `unavailable` — reached with **no repository at all**. UX-39: this used to
  /// report `saved`, a fabricated success for a PUT nobody issued.
  /// This is not a contrivance for the dev surfaces: it is the branch
  static DisplayNameCubit savedWithoutRepository() {
    final DisplayNameCubit cubit = DisplayNameCubit();
    unawaited(cubit.submit(submittedName));
    return cubit;
  }
}

/// Fires `cubit.submit` one frame AFTER [child] has mounted.
/// The only way either dev surface can render the screen's failure state. The
/// error copy is raised from `BlocConsumer.listener`, and a listener does not
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
