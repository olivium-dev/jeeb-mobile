import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../../delivery_status/domain/jeeber_summary.dart';
import '../../delivery_status/presentation/widgets/delivery_jeeber_card.dart';
import '../application/live_tracking_cubit.dart';
import '../application/live_tracking_state.dart';
import '../domain/delivery_tracking_info.dart';
import 'live_tracking_l10n.dart';
import 'widgets/delivery_tracking_panel.dart';
import 'widgets/order_summary_pinned_header.dart';
import 'widgets/order_tracking_stepper.dart';
import 'widgets/tracking_map_surface.dart';
import 'widgets/tracking_noshow_sheet.dart';
import 'widgets/otp_at_door_card.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/live_tracking_screen_fixtures.dart';
import '../domain/live_tracking_repository.dart';

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({
    super.key,
    required this.deliveryId,
    this.useLiveMap = true,
  });

  final String deliveryId;

  final bool useLiveMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.trackingTitle,
          showBackButton: true,
          centerTitle: true,
        ),
        body: _ResumeRefresh(
          child: BlocConsumer<LiveTrackingCubit, LiveTrackingState>(
            listenWhen: _hasNewEvent,
            listener: _onEvent,
            builder: (context, state) => _TrackingStateView(
              state: state,
              deliveryId: deliveryId,
              useLiveMap: useLiveMap,
            ),
          ),
        ),
      ),
    );
  }

  bool _hasNewEvent(LiveTrackingState prev, LiveTrackingState next) =>
      next.pendingEvent != LiveTrackingEvent.none;

  void _onEvent(BuildContext context, LiveTrackingState state) {
    final l10n = AppLocalizations.of(context);
    switch (state.pendingEvent) {
      case LiveTrackingEvent.jeeberOnTheWay:
        showOmdsSnackbar(context, message: l10n.trackingJeeberOnTheWay);
        break;
      case LiveTrackingEvent.deliveredAutoAdvance:
        context.goNamed(
          'delivered-receipt',
          pathParameters: {'id': deliveryId},
        );
        break;
      case LiveTrackingEvent.none:
      case LiveTrackingEvent.jeeberAtDoor:
        break;
    }
  }
}

class _TrackingStateView extends StatelessWidget {
  const _TrackingStateView({
    required this.state,
    required this.deliveryId,
    required this.useLiveMap,
  });

  final LiveTrackingState state;
  final String deliveryId;
  final bool useLiveMap;

  @override
  Widget build(BuildContext context) {
    switch (state.mode) {
      case LiveTrackingViewMode.loading:
        return const Center(child: OmdsLoadingState());
      case LiveTrackingViewMode.error:
        return _TrackingErrorBody(
          message: state.errorMessage,
          title: state.errorTitle,
          onRetry: () => context.read<LiveTrackingCubit>().retry(),
        );
      case LiveTrackingViewMode.ready:
        final info = state.trackingInfo!;
        if (info.isCancelled) return const _TrackingCancelledBody();
        if (info.isExpired) return const _TrackingExpiredBody();
        if (info.isUnderReview) return const _TrackingUnderReviewBody();
        return _TrackingBody(
          info: info,
          isAtDoor: state.isAtDoor,
          deliveryId: deliveryId,
          useLiveMap: useLiveMap,
          handoverCode: state.handoverCode,
        );
    }
  }
}

class _TrackingCancelledBody extends StatelessWidget {
  const _TrackingCancelledBody();

  static const Key cancelledStateKey = Key('live-tracking-cancelled-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_cancelled_state',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmdsEmptyState(
                key: cancelledStateKey,
                icon: Icons.cancel_outlined,
                title: l10n.deliveryCancelledBanner,
                subtitle: l10n.trackingCancelledBody,
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'tracking_cancelled_home_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  key: const Key('tracking-cancelled-home-cta'),
                  text: l10n.trackingCancelledHomeCta,
                  onTap: () => context.go('/'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingExpiredBody extends StatelessWidget {
  const _TrackingExpiredBody();

  static const Key expiredStateKey = Key('live-tracking-expired-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_expired_state',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmdsEmptyState(
                key: expiredStateKey,
                icon: Icons.timer_off_outlined,
                title: l10n.trackingExpiredTitle,
                subtitle: l10n.trackingExpiredBody,
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'tracking_expired_home_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  key: const Key('tracking-expired-home-cta'),
                  text: l10n.trackingCancelledHomeCta,
                  onTap: () => context.go('/'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingUnderReviewBody extends StatelessWidget {
  const _TrackingUnderReviewBody();

  static const Key underReviewStateKey =
      Key('live-tracking-under-review-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_under_review_state',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmdsEmptyState(
                key: underReviewStateKey,
                icon: Icons.report_problem_outlined,
                title: l10n.trackingUnderReviewTitle,
                subtitle: l10n.trackingUnderReviewBody,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({
    required this.info,
    required this.isAtDoor,
    required this.deliveryId,
    required this.useLiveMap,
    this.handoverCode,
  });

  final DeliveryTrackingInfo info;
  final bool isAtDoor;
  final String deliveryId;
  final bool useLiveMap;

  final String? handoverCode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          if (info.hasSummary)
            OrderSummaryPinnedHeader(
              info: info,
              onOpenChat: () => context.goNamed(
                'chat-detail',
                pathParameters: {
                  'id': (info.requestId?.isNotEmpty ?? false)
                      ? info.requestId!
                      : deliveryId,
                },
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.medium,
              Spacing.medium,
              Spacing.medium,
              Spacing.xSmall,
            ),
            child: OrderTrackingStepper(
              currentStep: info.trackingStepIndex4,
              atDoor: info.currentStage == TrackingStage.atDoor,
            ),
          ),
          Expanded(
            flex: isAtDoor ? 1 : 2,
            child: TrackingMapSurface(info: info, useLiveMap: useLiveMap),
          ),
          if (info.jeeber != null) _TrackingJeeberSection(jeeber: info.jeeber!),
          if (isAtDoor)
            OtpAtDoorCard(deliveryId: deliveryId, handoverCode: handoverCode)
          else ...[
            // a best-effort local cache must not, between them, be able to
            _HandoverCodeRow(code: handoverCode, deliveryId: deliveryId),
            _TrackingPanelSection(info: info),
          ],
          _TrackingActionBar(info: info, deliveryId: deliveryId),
        ],
      ),
    );
  }
}

class _TrackingActionBar extends StatelessWidget {
  const _TrackingActionBar({required this.info, required this.deliveryId});

  final DeliveryTrackingInfo info;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final requestId = (info.requestId?.isNotEmpty ?? false)
        ? info.requestId!
        : deliveryId;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        0,
        Spacing.medium,
        Spacing.medium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              identifier: 'tracking_noshow_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.noShowCta,
                variant: OmdsButtonVariant.text,
                onTap: () => TrackingNoShowSheet.show(
                  context: context,
                  onReassign: () => context.goNamed(
                    'offer-review',
                    pathParameters: {'id': requestId},
                  ),
                  onRebroadcast: () => context.goNamed(
                    'waiting-no-coverage',
                    pathParameters: {'id': requestId},
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Semantics(
              identifier: 'tracking_dispute_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.disputeCta,
                variant: OmdsButtonVariant.outlined,
                onTap: () => context.goNamed(
                  'escalate',
                  pathParameters: {'id': deliveryId},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// hand-over cannot happen without it, so it must not be hidden by a cache
class _HandoverCodeRow extends StatelessWidget {
  const _HandoverCodeRow({required this.code, required this.deliveryId});

  final String? code;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final knownCode = code;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.small,
        Spacing.medium,
        0,
      ),
      child: Semantics(
        identifier: 'tracking_handover_code_row',
        button: true,
        label: l10n.trackingCodeChipLabel,
        value: knownCode == null
            ? l10n.trackingAtDoorCta
            : knownCode.split('').join(' '),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.medium,
          child: InkWell(
            borderRadius: OmdsBorderRadius.medium,
            onTap: () => context.push('/orders/$deliveryId/otp'),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Spacing.medium,
                vertical: Spacing.small,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.key_outlined,
                    size: Sizes.medium,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trackingCodeChipLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          l10n.trackingCodeChipHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.small),
                  Text(
                    knownCode ?? l10n.trackingAtDoorCta,
                    key: const Key('tracking.codeRowValue'),
                    style: (knownCode == null
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: knownCode == null ? null : Spacing.xSmall,
                      color: knownCode == null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingJeeberSection extends StatelessWidget {
  const _TrackingJeeberSection({required this.jeeber});

  final JeeberSummary jeeber;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.medium,
        Spacing.medium,
        Spacing.medium,
        0,
      ),
      child: DeliveryJeeberCard(jeeber: jeeber),
    );
  }
}

class _TrackingPanelSection extends StatelessWidget {
  const _TrackingPanelSection({required this.info});

  final DeliveryTrackingInfo info;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      child: DeliveryTrackingPanel(info: info),
    );
  }
}

class _TrackingErrorBody extends StatelessWidget {
  const _TrackingErrorBody({
    required this.message,
    required this.onRetry,
    this.title,
  });

  final String? message;

  final String? title;
  final VoidCallback onRetry;

  static const Key errorStateKey = Key('live-tracking-error-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNotFound = title != null;
    return Center(
      child: OmdsErrorState(
        key: errorStateKey,
        title: title,
        message: message ?? l10n.trackingGpsLostBody,
        icon: isNotFound ? Icons.inbox_outlined : Icons.location_off_outlined,
        onRetry: onRetry,
        retryLabel: l10n.trackingGpsLostRetry,
      ),
    );
  }
}

class _ResumeRefresh extends StatefulWidget {
  const _ResumeRefresh({required this.child});

  final Widget child;

  @override
  State<_ResumeRefresh> createState() => _ResumeRefreshState();
}

class _ResumeRefreshState extends State<_ResumeRefresh>
    with ResumeRefetchMixin {
  @override
  void onAppResumed() => context.read<LiveTrackingCubit>().refreshNow();

  @override
  Widget build(BuildContext context) => widget.child;
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/live_tracking/live_tracking_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so five things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so each card shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes a background and the
//    `SafeArea`. That is the same nesting the Screen Catalog produces. The box
//    is therefore a real device ([_liveTrackingScreenPhoneBox], 390x844, plus
//    the 320x568 [_liveTrackingScreenCompactBox]) rather than the harness
//    default 390x200 — `_TrackingBody` is a `Column` whose map is the only
//    `Expanded`, so on a short canvas the map collapses first and every other
//    section is judged against a height it never has on a phone. The width is
//    pinned in the TREE as well as in `size:`, so the render tests measure the
//    same phone instead of the 800 pt test surface.
//
// 2. `useLiveMap: false` on every card. The shipping default is TRUE, and it is
//    right: `AndroidManifest.xml` now wires `com.google.android.geo.API_KEY` and
//    the customer gets a live courier map. But a `GoogleMap` is a platform view
//    — there is none on the desktop canvas and none under `flutter test` — and
//    mounting one keyless is a native FATAL no Dart try/catch can contain
//    (sprint-009 P0). So these cards review the deterministic placeholder, which
//    is the same seam `tracking_map_surface.dart`'s own previews use; the
//    courier-freshness ladder is reviewed there, on the widget that owns it.
//
// 3. Every card is frozen with `TickerMode(enabled: false)`. The cold-read state
//    is an `OmdsLoadingState`, i.e. an indeterminate `CircularProgressIndicator`
//    that schedules frames forever, and `pumpAndSettle` waits for frames to STOP
//    being scheduled. Muting the tickers paints a deterministic `t = 0` frame and
//    lets the suite settle.
//
// 4. Every state is pinned by a CAPTION rather than by screen copy — see
//    [LiveTrackingScreenCaptions]. Several of these previews have nothing of
//    their own to pin: the cold read paints no text at all below the app bar, the
//    two at-door cards differ only in whether four digits are present, and the
//    compact card is the longest-content card at a different width. The render
//    test's `preview specifics` group then asserts the real state behind every
//    caption, so the caption is never the whole proof.
//
// 5. The states come from
//    `lib/devtool/catalog/fixtures/live_tracking_screen_fixtures.dart`, shared
//    with the Screen Catalog entry (`devtool/catalog/entries/batch_06_entries.dart`),
//    which used to own a private copy of the same two fake repositories and two
//    inline `DeliveryTrackingInfo` literals. Nothing here resolves DI and no
//    preview passes a real repository — every one drives `LiveTrackingCubit`'s
//    own `repository:` seam with a local fake, with `refreshSignals` empty and no
//    position channel — so these are network-free by construction rather than by
//    the guard in [jeebPreviewHost].
//
// ## Two things a preview card cannot reproduce
//
// **There is no router.** `context.goNamed` / `context.go` back the dispute CTA,
// the no-show sheet's two recovery routes, the pinned header's chat CTA and both
// terminal "Back to Home" buttons. All of them are inert here. They are still
// rendered, because WHICH exits a state offers is most of what these cards are
// for.
//
// **There is no DELIVERED card, and that is a finding rather than an omission.**
// See below.
//
// ## What these previews exposed in the screen
//
//  * **The delivered state is unreachable on this screen — by design, and
//    nothing says so.** `_onEvent` answers `LiveTrackingEvent.deliveredAutoAdvance`
//    with `context.goNamed('delivered-receipt')`, so the moment the row reads
//    `Done` the screen replaces itself. The 4-step stepper this screen advertises
//    (`OrderTrackingStepper`, D70) therefore has a fourth step no customer ever
//    sees lit on this surface, and a preview of that state cannot be written at
//    all: with no [GoRouter] above the card the listener throws instead of
//    rendering. Every card below stops at step 3.
//  * **"Jeeber is on the way!" fires on every OPEN, not on the transition.**
//    `LiveTrackingCubit._detectEvent` reads `prev = state.trackingInfo?.currentStage`,
//    which is `null` on the first read of a screen entry, so `prev != next` holds
//    and an `inTransit` row returns `jeeberOnTheWay` — a snackbar — every single
//    time the customer opens tracking on a delivery that is already under way.
//    The `delivered` arm one line above is explicitly guarded against exactly
//    this (`prev != TrackingStage.delivered`); the in-transit arm is not.
//    `In transit · greets on every open` is that state, and the render test pins
//    the snackbar.
//  * **The error body is hard-coded ENGLISH.** `_mapError` and `_mapErrorTitle`
//    return string literals from the cubit — "Delivery not found", "Unable to
//    connect. Check your internet." — which `_TrackingErrorBody` renders verbatim.
//    Everything AROUND them is localized (`trackingGpsLostRetry`, the app-bar
//    title, the icon choice), so the Arabic rendering of both error cards is an
//    RTL page with an English sentence in the middle of it. The render test
//    asserts it in `ar`, where it is unmistakable.
//  * **A terminal delivery loses every trace of WHICH delivery it was.**
//    `_TrackingCancelledBody`, `_TrackingExpiredBody` and `_TrackingUnderReviewBody`
//    take no arguments: they drop `info` on the floor, so the pinned summary, the
//    item line, the price and the courier all vanish the instant the row goes
//    terminal. The customer is told "this delivery was cancelled" with nothing on
//    screen naming the order, the amount or the Jeeber — and the row carrying all
//    of it is sitting in `state.trackingInfo` two frames up.
//  * **The ordinary active layout does not fit the narrowest supported
//    viewport.** `_TrackingBody` is a `Column` with exactly one `Expanded` (the
//    map) and there is no scroll view anywhere on this screen, so once the six
//    fixed blocks around the map exceed the height the app bar leaves them, the
//    frame overflows rather than scrolls. Measured on `Compact 320x568` with the
//    EVERYDAY row (not a longest-content one) and through the real font faces:
//    **152 pt in English, 145 pt in Arabic**. The same fixture at 390x844 is
//    clean, so this is a viewport ceiling, not an unshippable fixture.
//  * **The 200% text rendering of the matrix overflows too, on a full phone.**
//    Same cause, one axis up: at `TextScaler.linear(2)` the pinned header, the
//    hand-over row and the status panel all grow, the map is the only slack, and
//    390x844 reports **262 pt** of vertical overflow plus a 1 pt horizontal one.
//    `Picked up · full active layout` is matrixed so that rendering is one glance
//    away; the render test measures it rather than leaving it to the eye.
//  * **`hasSummary` and `info.jeeber` are independent, and the shipped in-transit
//    row proves they diverge.** `In transit` carries `jeeberName: 'Kamal Hajj'`
//    (so the pinned header names a courier) and `jeeber: null` (so
//    `_TrackingJeeberSection` is not mounted). The customer sees a name in the
//    header and no courier card under the map, on the same frame.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _liveTrackingScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _liveTrackingScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see note 4 in the section prose. Dev chrome, never shipped copy, so
/// they are deliberately un-localized and rendered LTR at a fixed text scale.
final class LiveTrackingScreenCaptions {
  LiveTrackingScreenCaptions._();

  /// The read is on the wire and nothing has come back.
  static const String coldRead = 'preview · cold read · fetch in flight';

  /// Matched, but no courier and no summary yet.
  static const String ordered = 'preview · ordered · no jeeber, no summary';

  /// The reference reading: every optional section mounted at once.
  static const String pickedUp = 'preview · picked up · full active layout';

  /// The state that greets the customer on every open.
  static const String inTransit = 'preview · in transit · greets on every open';

  /// At the door with the accept-time code cached.
  static const String atDoor = 'preview · at door · code known, inline';

  /// At the door on a device that never received the code.
  static const String atDoorNoCode = 'preview · at door · code NOT cached';

  /// Terminal: cancelled.
  static const String cancelled = 'preview · cancelled · terminal';

  /// Terminal: expired (distinct fee/strike semantics from cancelled).
  static const String expired = 'preview · expired · terminal';

  /// Parked with admin, still live.
  static const String underReview = 'preview · under review · still live';

  /// The 404 that gets its own heading.
  static const String notFound = 'preview · error · delivery not found';

  /// The generic transport failure.
  static const String networkError = 'preview · error · network';

  /// Every string at its longest plausible length.
  static const String longestContent = 'preview · longest content';

  /// The ordinary active layout on the narrowest supported device, where it
  /// does not fit.
  static const String compact = 'preview · active layout · 320x568 OVERFLOWS';
}

/// Mounts the real screen on one shared designed state, framed, captioned and
/// frozen.
///
/// `TickerMode(enabled: false)` mutes the indeterminate spinner — see note 3 in
/// the section prose. The cubit is built by `BlocProvider`'s `create:` (not
/// `.value`) so the provider owns it and closes it when the card is torn down.
///
/// ## Why the frame is a `FittedBox` and not an `Align`
///
/// The sibling screen previews put the device `SizedBox` under an `Align`, which
/// lets a surface SHORTER than [box] clamp the height — harmless for a screen
/// whose body is a `ListView`, because the content just scrolls further. This
/// screen has no scroll view anywhere: `_TrackingBody` is a `Column` whose only
/// `Expanded` is the map, so a clamped height does not shorten the card, it
/// OVERFLOWS it. Measured: at the 800x600 surface `flutter test` renders,
/// `Picked up` overflows by 36 pt and the AR `In transit` by 20 — neither of
/// which exists on the 390x844 device the card claims to be.
///
/// Scaling instead of clamping makes the layout device-true everywhere: the
/// child is laid out at exactly [box] on the canvas AND under `flutter test`,
/// and only the on-screen scale varies. `BoxFit.scaleDown` never magnifies, so
/// on the canvas — where the card really is [box] tall — this is a no-op. An
/// overflow seen on one of these cards is therefore an overflow a phone has.
Widget _liveTrackingScreenHosted(
  LiveTrackingCubit Function() build,
  String caption, {
  Size box = _liveTrackingScreenPhoneBox,
}) {
  return TickerMode(
    enabled: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LiveTrackingScreenCaption(caption: caption),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: BlocProvider<LiveTrackingCubit>(
                create: (_) => build(),
                child: const LiveTrackingScreen(
                  deliveryId: LiveTrackingScreenFixtures.deliveryId,
                  // See note 2: no platform view on the canvas or in tests.
                  useLiveMap: false,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The dev-chrome line painted above each device frame.
class _LiveTrackingScreenCaption extends StatelessWidget {
  const _LiveTrackingScreenCaption({required this.caption});

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
        // latin line and the 200% card does not spend a third of the device on
        // a label.
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Cold start: `GET /v1/deliveries/{id}` is in flight and nothing has come back.
///
/// Every entry to this screen opens here. The body is a bare centred spinner —
/// no message, no skeleton, no timeout, and none of the CTAs (dispute, no-show,
/// hand-over code) exist yet, because they all live inside `_TrackingBody`. The
/// app-bar title is the only text on the card.
@JeebPreview(
  group: 'live_tracking',
  name: 'Loading · cold read',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenColdRead() => _liveTrackingScreenHosted(
      LiveTrackingScreenFixtures.loading,
      LiveTrackingScreenCaptions.coldRead,
    );

/// The genuinely EMPTY reading of the active layout: matched, nothing moved.
///
/// `hasSummary` is false (no price, no jeeber name) so the pinned header is not
/// mounted; `info.jeeber` is null so the courier card is not mounted; the panel
/// has neither a distance nor an ETA, so both lines render their "…updating"
/// placeholders. What is left — stepper, map placeholder, hand-over row, panel,
/// two CTAs — is the floor this screen degrades to, and it is worth looking at:
/// it is what a customer sees for the whole window between accept and pickup.
@JeebPreview(
  group: 'live_tracking',
  name: 'Ordered · no jeeber yet',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenOrdered() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.orderedInfo,
      ),
      LiveTrackingScreenCaptions.ordered,
    );

/// The reference reading: every optional section of `_TrackingBody` mounted at
/// once.
///
/// Pinned summary header, the 4-step stepper at step 2, the map surface, the
/// matched-courier card, the hand-over code row, the status panel and the action
/// bar — seven blocks in one non-scrolling `Column` whose only `Expanded` is the
/// map.
///
/// Matrixed, and this is the state the matrix is really for: AR has to mirror
/// the header's name/price row, the code row's label/code row and the two-CTA
/// action bar together, and 200% is where the code row's `Expanded` label wraps
/// to three lines beside a `titleLarge` code that does not shrink — every point
/// it takes comes out of the map.
@JeebPreview(
  group: 'live_tracking',
  name: 'Picked up · full active layout',
  size: _liveTrackingScreenPhoneBox,
  matrix: true,
)
Widget liveTrackingScreenPickedUp() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.pickedUpInfo,
      ),
      LiveTrackingScreenCaptions.pickedUp,
    );

/// The Screen Catalog's `In transit` state — and the greeting defect, made
/// visible.
///
/// `_detectEvent` compares the incoming stage against `state.trackingInfo?.currentStage`,
/// which is null on the first read of every screen entry. An already-moving
/// delivery therefore satisfies `prev != next` and returns
/// [LiveTrackingEvent.jeeberOnTheWay], so `_onEvent` shows the
/// "Jeeber is on the way!" snackbar EVERY time the customer opens tracking —
/// not on the transition it was written for. The `delivered` arm directly above
/// it carries the guard this arm is missing.
///
/// Also the card where the header/courier-card split shows: `jeeberName` is set
/// (the header names Kamal Hajj) while `jeeber` is null (no courier card).
@JeebPreview(
  group: 'live_tracking',
  name: 'In transit · greets on every open',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenInTransit() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.inTransitInfo,
      ),
      LiveTrackingScreenCaptions.inTransit,
    );

/// The hand-over moment, on a device that has the accept-time code.
///
/// At the door the layout swaps: the quiet `_HandoverCodeRow` and the status
/// panel are replaced by [OtpAtDoorCard], which renders the four digits inline
/// and large, and the map's `Expanded` flex drops from 2 to 1 to make room. The
/// third stepper step relabels to "At Door" while keeping its
/// `tracking_step_in_transit` identifier (P6/A5).
@JeebPreview(
  group: 'live_tracking',
  name: 'At the door · code inline',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenAtDoor() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.atDoorInfo,
      ),
      LiveTrackingScreenCaptions.atDoor,
    );

/// The same moment on a device that never received the code — a reinstall, or an
/// accept parsed before the `handoverCode` fix.
///
/// The card degrades to the pre-G4 copy and the "Show OTP" CTA, which routes to
/// the OTP screen's SMS fallback. Reviewing it beside the card above is the
/// point: this is the state the customer hits at the door with nothing to read
/// out, and the difference between the two is four digits.
@JeebPreview(
  group: 'live_tracking',
  name: 'At the door · code NOT cached',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenAtDoorNoCode() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.atDoorInfo,
        code: null,
      ),
      LiveTrackingScreenCaptions.atDoorNoCode,
    );

/// Terminal: the delivery was cancelled (sprint-009 scenario matrix #9).
///
/// No stepper, no map, no retry — there is nothing to retry, the row is dead —
/// and one "Back to Home" exit. Note what is NOT here: `_TrackingCancelledBody`
/// takes no arguments, so the order, its price, its item line and the courier all
/// disappear with the stepper. The customer is told a delivery was cancelled
/// without being told which one.
@JeebPreview(
  group: 'live_tracking',
  name: 'Cancelled · terminal',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenCancelled() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.cancelledInfo,
      ),
      LiveTrackingScreenCaptions.cancelled,
    );

/// Terminal: the request EXPIRED before it could complete (P6/A3).
///
/// Structurally the twin of the card above and deliberately not merged with it:
/// cancel and expire carry different fee/strike semantics, so the copy and the
/// ids are separate. The pre-fix bug was that `expired` reused the cancelled
/// body verbatim; reading these two side by side is how that stays fixed.
@JeebPreview(
  group: 'live_tracking',
  name: 'Expired · terminal',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenExpired() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.expiredInfo,
      ),
      LiveTrackingScreenCaptions.expired,
    );

/// `FailedNeedsEscalation` — parked with admin, and NOT terminal (P6/A1).
///
/// The pre-fix symptom was the ordinary active layout with the stepper rewound to
/// step 1, watching a row only an admin could move. The body is now explicit, and
/// deliberately carries NO home CTA: the delivery is still live, so this is not an
/// exit. That leaves the app-bar back arrow as the only way off the screen, which
/// is worth seeing rather than reading.
@JeebPreview(
  group: 'live_tracking',
  name: 'Under review · still live',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenUnderReview() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.underReviewInfo,
      ),
      LiveTrackingScreenCaptions.underReview,
    );

/// The 404: the delivery row does not exist yet.
///
/// The one error kind with its own heading and a neutral inbox icon rather than
/// the GPS-lost crosshair — an accept-minted delivery that has not propagated is
/// not a fault. Both strings come from `LiveTrackingCubit._mapError` /
/// `_mapErrorTitle` as ENGLISH LITERALS, so this card is identical in Arabic
/// except for the retry label around it.
@JeebPreview(
  group: 'live_tracking',
  name: 'Error · delivery not found',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenNotFound() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.failing(LiveTrackingErrorKind.notFound),
      LiveTrackingScreenCaptions.notFound,
    );

/// The generic transport failure: the GPS-lost crosshair, no heading, and a
/// retry that can actually succeed.
@JeebPreview(
  group: 'live_tracking',
  name: 'Error · network',
  size: _liveTrackingScreenPhoneBox,
)
Widget liveTrackingScreenNetworkError() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.failing(LiveTrackingErrorKind.network),
      LiveTrackingScreenCaptions.networkError,
    );

/// The layout ceiling: every string at its longest plausible length, at the
/// stage that mounts the most sections.
///
/// A three-line item summary the customer typed themselves (`itemSummary` is the
/// G1 `description` fallback and has no client-side cap), a full transliterated
/// courier name in both the header and the card, a 145-minute ETA and a
/// four-figure price. Nothing on this screen scrolls, so this is where the
/// `Column` runs out of slack and the map — the only `Expanded` — pays for all of
/// it.
///
/// Matrixed because the EN-light reading stays plausible long after AR and 200%
/// have run out of room.
@JeebPreview(
  group: 'live_tracking',
  name: 'Longest content',
  size: _liveTrackingScreenPhoneBox,
  matrix: true,
)
Widget liveTrackingScreenLongestContent() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.longestInfo,
      ),
      LiveTrackingScreenCaptions.longestContent,
    );

/// The narrowest viewport the app supports — where the ORDINARY active layout
/// does not fit.
///
/// This card carries [LiveTrackingScreenFixtures.pickedUpInfo], the same
/// everyday row as `Picked up · full active layout`, not the longest-content
/// one. That is the point: 320x568 leaves the body 512 pt under the app bar, the
/// seven blocks of `_TrackingBody` need more than that even with the map
/// squeezed to nothing, and nothing on this screen scrolls — so the frame paints
/// the overflow stripe on an ordinary delivery. Measured through the real font
/// faces: 152 pt in English, 145 pt in Arabic.
///
/// It is therefore the ONE state kept out of the shared `testPreviewsRender`
/// suite, which asserts that every preview builds without an exception; its own
/// cases assert the overflow instead, one per locale (a `RenderFlex` reports its
/// overflow once per RenderObject, so two locales in one case would give a false
/// clean on the second).
@JeebPreview(
  group: 'live_tracking',
  name: 'Compact 320x568 · does not fit',
  size: _liveTrackingScreenCompactBox,
)
Widget liveTrackingScreenCompact() => _liveTrackingScreenHosted(
      () => LiveTrackingScreenFixtures.ready(
        LiveTrackingScreenFixtures.pickedUpInfo,
      ),
      LiveTrackingScreenCaptions.compact,
      box: _liveTrackingScreenCompactBox,
    );
