import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/delivery_status_cubit.dart';
import '../application/delivery_status_state.dart';
import '../domain/delivery_snapshot.dart';
import '../domain/delivery_status_gateway.dart';
import 'widgets/delivery_details_card.dart';
import 'widgets/delivery_eta_badge.dart';
import 'widgets/delivery_jeeber_card.dart';
import 'widgets/delivery_lifecycle_banner.dart';
import 'widgets/delivery_stage_indicator.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/delivery_status_screen_fixtures.dart';

typedef ContactJeeberHandler = void Function(String phoneE164);

class DeliveryStatusScreen extends StatelessWidget {
  const DeliveryStatusScreen({
    super.key,
    required this.deliveryId,
    this.cubit,
    this.gateway,
    this.onContactJeeber,
  }) : assert(
          cubit == null || gateway == null,
          'Provide either a cubit or a gateway, not both.',
        );

  final String deliveryId;

  final DeliveryStatusCubit? cubit;

  final DeliveryStatusGateway? gateway;

  final ContactJeeberHandler? onContactJeeber;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<DeliveryStatusCubit>.value(
        value: provided,
        child: _Scaffold(
          deliveryId: deliveryId,
          onContactJeeber: onContactJeeber,
        ),
      );
    }
    return BlocProvider<DeliveryStatusCubit>(
      create: (_) => DeliveryStatusCubit(
        deliveryId: deliveryId,
        gateway: gateway ??
            InMemoryDeliveryStatusGateway(
              seed: demoDeliverySnapshot(id: deliveryId),
            ),
      ),
      child: _Scaffold(
        deliveryId: deliveryId,
        onContactJeeber: onContactJeeber,
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.deliveryId, this.onContactJeeber});

  final String deliveryId;
  final ContactJeeberHandler? onContactJeeber;

  static const Key rootKey = Key('delivery-status-screen');
  static const Key bodyScrollKey = Key('delivery-status-scroll');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'delivery_status_root',
      container: true,
      child: Scaffold(
        key: rootKey,
        appBar: OMDSAppBar(
          title: l10n.deliveryStatusTitle,
          showBackButton: true,
          centerTitle: false,
        ),
        body: SafeArea(
          child: BlocConsumer<DeliveryStatusCubit, DeliveryStatusState>(
            listenWhen: (prev, curr) =>
                prev.error != curr.error && curr.error != null,
            listener: _surfaceError,
            builder: (context, state) {
              switch (state.mode) {
                case DeliveryStatusViewMode.loading:
                  return _LoadingView(l10n: l10n);
                case DeliveryStatusViewMode.error:
                  return _ErrorView(
                    l10n: l10n,
                    onRetry: () =>
                        context.read<DeliveryStatusCubit>().retry(),
                  );
                case DeliveryStatusViewMode.ready:
                  final snapshot = state.snapshot;
                  if (snapshot == null) {
                    return _LoadingView(l10n: l10n);
                  }
                  return _ReadyView(
                    snapshot: snapshot,
                    isCancelling: state.isCancelling,
                    deliveryId: deliveryId,
                    onContactJeeber: onContactJeeber,
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  void _surfaceError(BuildContext context, DeliveryStatusState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeliveryStatusCubit>();
    final message = _messageFor(l10n, state.error!);
    if (message != null) {
      showOmdsSnackbar(context, message: message);
    }
    cubit.acknowledgeError();
  }

  String? _messageFor(AppLocalizations l10n, DeliveryStatusError error) {
    switch (error) {
      case DeliveryStatusError.cancelTooLate:
        return l10n.deliveryErrorCancelTooLate;
      case DeliveryStatusError.cancelNetwork:
        return l10n.deliveryErrorCancelNetwork;
      case DeliveryStatusError.contactUnavailable:
        return l10n.deliveryErrorContactUnavailable;
      case DeliveryStatusError.streamLost:
        return l10n.deliveryErrorStreamLost;
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.l10n});

  final AppLocalizations l10n;

  static const Key rootKey = Key('delivery-status-loading');

  @override
  Widget build(BuildContext context) {
    return Center(
      key: rootKey,
      child: OmdsLoadingState(message: l10n.deliveryStatusLoading),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.l10n, required this.onRetry});

  final AppLocalizations l10n;
  final VoidCallback onRetry;

  static const Key rootKey = Key('delivery-status-error');

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rootKey,
      padding: const EdgeInsets.all(Spacing.large),
      child: Center(
        child: OmdsErrorState(
          title: l10n.deliveryStatusErrorTitle,
          message: l10n.deliveryStatusErrorBody,
          icon: Icons.cloud_off_outlined,
          retryLabel: l10n.deliveryStatusRetry,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.snapshot,
    required this.isCancelling,
    required this.deliveryId,
    this.onContactJeeber,
  });

  final DeliverySnapshot snapshot;
  final bool isCancelling;
  final String deliveryId;
  final ContactJeeberHandler? onContactJeeber;

  static const Key contactButtonKey = Key('delivery-status-contact-cta');
  static const Key cancelButtonKey = Key('delivery-status-cancel-cta');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: _Scaffold.bodyScrollKey,
      padding: const EdgeInsets.fromLTRB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeliveryLifecycleBanner(lifecycle: snapshot.lifecycle),
          if (snapshot.lifecycle != DeliveryLifecycle.active)
            const SizedBox(height: Spacing.medium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.deliveryStatusIdSubtitle(deliveryId),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (snapshot.isEtaVisible)
                DeliveryEtaBadge(minutes: snapshot.etaMinutes!),
            ],
          ),
          const SizedBox(height: Spacing.medium),
          DeliveryStageIndicator(snapshot: snapshot),
          const SizedBox(height: Spacing.large),
          DeliveryDetailsCard(snapshot: snapshot),
          const SizedBox(height: Spacing.medium),
          DeliveryJeeberCard(jeeber: snapshot.jeeber),
          const SizedBox(height: Spacing.large),
          _ActionBar(
            snapshot: snapshot,
            isCancelling: isCancelling,
            onContactJeeber: onContactJeeber,
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.snapshot,
    required this.isCancelling,
    this.onContactJeeber,
  });

  final DeliverySnapshot snapshot;
  final bool isCancelling;
  final ContactJeeberHandler? onContactJeeber;

  Future<void> _onCancelPressed(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeliveryStatusCubit>();
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: l10n.deliveryCancelDialogTitle,
      content: l10n.deliveryCancelDialogBody,
      confirmText: l10n.deliveryCancelDialogConfirm,
      cancelText: l10n.deliveryCancelDialogDismiss,
      isDestructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!confirmed) return;
    await cubit.cancel();
  }

  void _onContactPressed(BuildContext context) {
    final cubit = context.read<DeliveryStatusCubit>();
    final number = cubit.requestContactNumber();
    if (number == null) return;
    HapticFeedback.selectionClick();
    onContactJeeber?.call(number);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!snapshot.isInFlight) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.canContactJeeber)
          Semantics(
            identifier: 'delivery_status_contact_cta',
            container: true,
            button: true,
            child: OmdsPrimaryButton(
              key: _ReadyView.contactButtonKey,
              text: l10n.deliveryActionContact,
              icon: const Icon(Icons.phone, size: 18),
              onTap: () => _onContactPressed(context),
            ),
          ),
        if (snapshot.canContactJeeber && snapshot.canCancel)
          const SizedBox(height: Spacing.small),
        if (snapshot.canCancel)
          Semantics(
            identifier: 'delivery_status_cancel_cta',
            container: true,
            button: true,
            child: OmdsPrimaryButton(
              key: _ReadyView.cancelButtonKey,
              text: isCancelling
                  ? l10n.deliveryActionCancellingLabel
                  : l10n.deliveryActionCancel,
              variant: OmdsButtonVariant.outlined,
              isEnabled: !isCancelling,
              onTap: () => _onCancelPressed(context),
            ),
          ),
      ],
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/delivery_status/delivery_status_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so four things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so each card shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes a background and the
//    `SafeArea`. The canvas box is therefore a real device
//    ([_deliveryStatusScreenPhoneBox], 390x844, plus the 320x568
//    [_deliveryStatusScreenCompactBox] for the narrowest viewport the app
//    supports) rather than the harness default 390x200 — a scrolling column of
//    a stepper, two cards and two CTAs cannot be judged in a 200 pt strip.
//
// 2. Every card is frozen with `TickerMode(enabled: false)`. Two of this
//    screen's states animate forever: the active milestone's pulsing dot
//    (`AnimationController.repeat(reverse: true)`) and the indeterminate
//    `CircularProgressIndicator` inside `OmdsLoadingState`, which the cold-load
//    view and the no-courier-yet Jeeber card both render. `pumpAndSettle` waits
//    for frames to STOP being scheduled, so either one makes the render tests
//    spin to their fake-time budget and throw (measured). Muting is what
//    `delivery_stage_indicator.dart` already does for the same reason: the
//    controllers still start and still report `isAnimating`, they just never
//    advance, so the canvas paints a deterministic `t = 0` frame — the pulse at
//    its most visible — and the suite settles.
//
// 3. Every state is pinned by a CAPTION rather than by screen copy — see
//    [DeliveryStatusScreenCaptions]. Three pairs of previews are otherwise
//    indistinguishable to `find.text`: the two stream failures render the
//    identical error page (which is the point of having both), and cancel-in-
//    flight opens as an ordinary pre-pickup delivery. The render test asserts
//    the real state behind each caption — which CTAs exist, which banner, what
//    the ETA says — so the caption is never the whole proof.
//
// 4. The states come from
//    `lib/devtool/catalog/fixtures/delivery_status_screen_fixtures.dart`,
//    shared with the Screen Catalog entry
//    (`devtool/catalog/entries/batch_03_entries.dart`), which used to own a
//    private copy of the same snapshot builder and error gateway. Nothing here
//    resolves DI and no preview passes a real repository — every one drives the
//    shipped `gateway:` seam with a local fake — so these are network-free by
//    construction rather than by the guard in [jeebPreviewHost].
//
// The one thing NOT reproduced is a router. This screen never navigates
// (no `context.pop`, no `GoRouter`), so its only route-aware control is the
// OMDSAppBar back arrow, which pops the preview's own `MaterialApp` route.
// `onContactJeeber` is likewise left null, exactly as the catalog leaves it:
// production wires a `tel:` launcher, and a dev surface must not dial anyone.
//
// ## What these previews exposed in the screen
//
//  * **A dropped stream throws away a perfectly good delivery.** `_Scaffold`
//    switches on `state.mode` alone and the `error` branch never looks at
//    `state.snapshot` — which the cubit still holds, fully populated.
//    `Stream dropped mid-delivery` seeds exactly that (one good in-transit
//    snapshot, then a transport failure) and the entire delivery — stepper,
//    addresses, courier, ETA, both CTAs — is replaced by a full-page
//    "Connection lost". Read it beside `Stream lost on open`: they are the same
//    picture, although in one case the app knows where the parcel is and in the
//    other it never did. A tunnel is enough to produce it.
//  * **And the two halves of that page contradict each other.** The body says
//    "We can't reach the status service right now. Tap retry to reconnect"
//    while a snackbar over it says "Live status reconnecting…". Nothing is
//    reconnecting: `DeliveryStatusCubit` re-subscribes only from `retry()`,
//    which only the button calls. One of the two sentences has to go.
//    (A dropped stream reaches the cubit twice — `onError`, then `onDone`
//    seeing `snapshot.isInFlight` — but the second emit is identical to the
//    first and `DeliveryStatusState` is `Equatable`, so `Cubit` drops it and
//    only one toast is raised. That is worth knowing before anyone "fixes" the
//    double path: it is already harmless, and the render test pins it.)
//  * **A completed delivery says it is still looking for a courier.**
//    `_ReadyView` hands `snapshot.jeeber` to `DeliveryJeeberCard` with no
//    regard for lifecycle, and the card renders its `jeeber == null` branch —
//    a spinner and "Looking for a Jeeber…" — under a green "Delivered
//    successfully" banner. That is the `Delivered` card the Screen Catalog has
//    shipped since DT-04, because the gateway fixture drops the courier on
//    terminal snapshots; any real gateway that does the same gets the same
//    screen, and the spinner never resolves.
//  * **A cancelled delivery is contradicted by its own stepper.** The banner
//    says "Delivery cancelled" while `DeliveryStageIndicator` zeroes
//    `completedSteps` and keeps every milestone timestamp, so the same card
//    reads "this never started" and "matched at 10:00" at once. The ARB has a
//    `deliveryStageCancelled` string; nothing on this screen reads it.
//  * **"Cancelling…" has no seam and almost no treatment.**
//    `DeliveryStatusCubit` takes a gateway and nothing else — no
//    `initialState:`, no seed — so `isCancelling` cannot be preset by the
//    catalog, by a preview, or by a test; `Cancel in flight` reaches it the way
//    a user does, by tapping, and holds it there with a gateway whose `cancel`
//    future never completes. What you get for a write that is in the air is one
//    button label changing to "Cancelling…" and greying out. No overlay, no
//    progress, and Contact Jeeber beside it stays live.
//  * **A four-hour ETA reads "240 min".** `deliveryEtaMinutes` is the only
//    plural form in the ARB, so `Longest content` renders the badge as
//    "ETA 240 min" rather than "4 h". The screen clamps nothing on the way in:
//    `isEtaVisible` only asks for a non-null value in the in-transit stage.
//  * **Nothing on the screen is clamped.** `Longest content` puts a UUID-shaped
//    reference in the subtitle, a 56-character address with a two-line
//    landmark, and a full display name in the courier card; every one of them
//    wraps and the column simply grows. That is the right failure mode for a
//    scroll view, and it is why the AR and 200% renderings of that card are the
//    ones worth reading — the EN-light card looks fine long after the other two
//    have stopped fitting.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _deliveryStatusScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _deliveryStatusScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see note 3 in the section prose. Dev chrome, never shipped copy, so
/// they are deliberately un-localized and rendered LTR at a fixed text scale.
final class DeliveryStatusScreenCaptions {
  DeliveryStatusScreenCaptions._();

  /// No snapshot has landed yet — the first frame of every delivery.
  static const String connecting = 'preview · cold start · no snapshot yet';

  /// Pre-pickup: the only state with both CTAs.
  static const String matched = 'preview · matched · cancel + contact';

  /// Matched, but the snapshot carries no courier.
  static const String awaitingJeeber = 'preview · matched · no courier yet';

  /// In transit: ETA appears, cancel is withdrawn.
  static const String inTransit = 'preview · in transit · ETA, no cancel';

  /// Delivered — and still looking for a Jeeber.
  static const String delivered = 'preview · delivered · terminal';

  /// Cancelled — banner against a zeroed stepper.
  static const String cancelled = 'preview · cancelled · terminal';

  /// The service was already down when the screen opened.
  static const String streamLostOnOpen = 'preview · stream lost on open';

  /// A live delivery, then a transport failure.
  static const String streamDropped = 'preview · stream dropped mid-delivery';

  /// Cancel tapped, the write still in the air.
  static const String cancelInFlight = 'preview · cancel in flight · tap Cancel';

  /// Every string at its longest plausible length.
  static const String longestContent = 'preview · longest content';

  /// The in-transit reading on the narrowest supported device.
  static const String compact = 'preview · in transit · 320x568 viewport';
}

/// Mounts the real screen on one shared designed state, captioned and frozen.
///
/// `TickerMode(enabled: false)` mutes the pulsing milestone dot and the
/// indeterminate spinner — see note 2 in the section prose. The screen keeps
/// its own `Scaffold`; nothing here substitutes for it.
Widget _deliveryStatusScreenHosted(
  DeliveryStatusScreenDesignedState state,
  String caption,
) {
  return TickerMode(
    enabled: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeliveryStatusScreenCaption(caption: caption),
        Expanded(
          child: DeliveryStatusScreen(
            deliveryId: state.deliveryId,
            gateway: state.gateway,
          ),
        ),
      ],
    ),
  );
}

/// The dev-chrome line painted above each device frame.
class _DeliveryStatusScreenCaption extends StatelessWidget {
  const _DeliveryStatusScreenCaption({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      child: Text(
        caption,
        // Dev chrome: LTR and unscaled, so the AR card still reads it as one
        // latin line and the 200% card does not spend a third of the device
        // on a label.
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Cold start: `mode` is still `loading`, because the gateway's first snapshot
/// has not landed.
///
/// Every delivery opens here — `DeliveryStatusState` starts in `loading` and
/// only leaves it when a snapshot arrives — and on a slow connection it is the
/// state the user reads for as long as the network takes. There is no app-bar
/// subtitle yet, no skeleton and no timeout: a gateway that never answers
/// leaves this spinner on screen forever.
@JeebPreview(
  group: 'delivery_status',
  name: 'Cold start · no snapshot yet',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenConnecting() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.connecting,
      DeliveryStatusScreenCaptions.connecting,
    );

/// Pre-pickup, courier matched: the only state that renders BOTH CTAs.
///
/// `canCancel` is gated on `stage.isBefore(pickedUp)` (BR-4 in the
/// cancellation matrix) and `canContactJeeber` on the gateway having exposed a
/// number, so this narrow window is the only place the two appear together —
/// and the only place the action bar is two buttons tall.
@JeebPreview(
  group: 'delivery_status',
  name: 'Matched · cancel + contact',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenMatched() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.matched,
      DeliveryStatusScreenCaptions.matched,
    );

/// The empty state: an active delivery whose snapshot has no courier on it.
///
/// The Jeeber card falls back to a spinner and "Looking for a Jeeber…", and the
/// action bar drops to a single button — Cancel survives, Contact does not,
/// because there is no number to dial. This is the correct pairing, and the
/// only card where the two CTAs are visibly decoupled.
@JeebPreview(
  group: 'delivery_status',
  name: 'Matched · no courier yet',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenAwaitingJeeber() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.awaitingJeeber,
      DeliveryStatusScreenCaptions.awaitingJeeber,
    );

/// In transit: the ETA badge appears and Cancel is withdrawn.
///
/// The header is the one row on this screen that has to survive translation —
/// an `Expanded` subtitle beside a non-flexible pill — so it is matrixed. The
/// AR rendering mirrors it (badge leads, subtitle trails) and the 200%
/// rendering is where the pill stops leaving the subtitle room.
@JeebPreview(
  group: 'delivery_status',
  name: 'In transit · ETA, no cancel',
  size: _deliveryStatusScreenPhoneBox,
  matrix: true,
)
Widget deliveryStatusScreenInTransit() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.inTransit,
      DeliveryStatusScreenCaptions.inTransit,
    );

/// Delivered: the terminal state, with both CTAs collapsed to nothing.
///
/// Also the card that shows a completed delivery still hunting for a courier —
/// see the section prose. The banner and the Jeeber card disagree because
/// nothing tells the card which lifecycle it is in.
@JeebPreview(
  group: 'delivery_status',
  name: 'Delivered · terminal',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenDelivered() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.delivered,
      DeliveryStatusScreenCaptions.delivered,
    );

/// Cancelled: the other terminal state, and the one the stepper argues with.
///
/// `DeliveryLifecycle.cancelled` zeroes the stepper while the milestone rows
/// keep their timestamps, so the card claims the delivery both never started
/// and reached "Matched at 10:00". The red banner is the only element that
/// names the state.
@JeebPreview(
  group: 'delivery_status',
  name: 'Cancelled · terminal',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenCancelled() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.cancelled,
      DeliveryStatusScreenCaptions.cancelled,
    );

/// The status service was already down when the screen opened.
///
/// Full-page error plus a Retry that re-subscribes to the same failing stream.
/// Note the snackbar riding over it: "Live status reconnecting…" — a promise
/// the cubit does not keep, since nothing re-subscribes without a tap.
@JeebPreview(
  group: 'delivery_status',
  name: 'Stream lost on open',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenStreamLostOnOpen() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.streamLostOnOpen,
      DeliveryStatusScreenCaptions.streamLostOnOpen,
    );

/// A live delivery, one good snapshot in, and then the transport drops.
///
/// The card to read next to `Stream lost on open`: they are identical, even
/// though the cubit is still holding a complete in-transit snapshot with an
/// ETA, an address pair and a courier. Everything the user was looking at is
/// gone because the view branches on `mode` and never falls back to the data it
/// already has. This is the ordinary failure — a tunnel, a locked phone — not
/// an outage.
@JeebPreview(
  group: 'delivery_status',
  name: 'Stream dropped mid-delivery',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenStreamDropped() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.streamDroppedMidDelivery,
      DeliveryStatusScreenCaptions.streamDropped,
    );

/// Cancel tapped, `cancel()` still in the air — reachable only by tapping.
///
/// The cubit has no seam for `isCancelling`, so this card opens as an ordinary
/// pre-pickup delivery; tap Cancel, confirm the dialog, and the gateway behind
/// it never answers. The whole in-flight treatment is then visible at once: the
/// Cancel button reads "Cancelling…" and greys out, and nothing else on the
/// screen changes — Contact Jeeber stays live, the stepper keeps saying the
/// delivery is on its way.
@JeebPreview(
  group: 'delivery_status',
  name: 'Cancel in flight · tap Cancel',
  size: _deliveryStatusScreenPhoneBox,
)
Widget deliveryStatusScreenCancelInFlight() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.cancelInFlight,
      DeliveryStatusScreenCaptions.cancelInFlight,
    );

/// The longest plausible string on every axis at once.
///
/// A UUID-shaped gateway reference in the subtitle, a 56-character street with
/// a two-line landmark, a full (rather than privacy-trimmed) courier name, the
/// longest tier label, and a 240-minute ETA that the badge renders as
/// "240 min". Nothing clamps: the column grows and the scroll view absorbs it,
/// which is the right failure mode and also the reason this is invisible
/// without a device-sized canvas. Matrixed because the EN-light reading stays
/// plausible long after AR and 200% have run out of room.
@JeebPreview(
  group: 'delivery_status',
  name: 'Longest content',
  size: _deliveryStatusScreenPhoneBox,
  matrix: true,
)
Widget deliveryStatusScreenLongestContent() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.longestContent,
      DeliveryStatusScreenCaptions.longestContent,
    );

/// The in-transit reading on the narrowest viewport the app supports.
///
/// Nothing on this screen is pinned outside the scroll view — the app bar is
/// the only fixed chrome — so a short device costs reach rather than layout:
/// the CTAs move below the fold and there is no scrollbar, fade or shadow to
/// say so.
@JeebPreview(
  group: 'delivery_status',
  name: 'In transit · compact 320x568',
  size: _deliveryStatusScreenCompactBox,
)
Widget deliveryStatusScreenCompact() => _deliveryStatusScreenHosted(
      DeliveryStatusScreenFixtures.compactViewport,
      DeliveryStatusScreenCaptions.compact,
    );
