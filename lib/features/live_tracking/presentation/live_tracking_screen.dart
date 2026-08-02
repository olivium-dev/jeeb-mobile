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

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _liveTrackingScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _liveTrackingScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
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
/// Every entry to this screen opens here. The body is a bare centred spinner —
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
/// `hasSummary` is false (no price, no jeeber name) so the pinned header is not
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
/// At the door the layout swaps: the quiet `_HandoverCodeRow` and the status
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
/// No stepper, no map, no retry — there is nothing to retry, the row is dead —
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
/// Structurally the twin of the card above and deliberately not merged with it:
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
/// The pre-fix symptom was the ordinary active layout with the stepper rewound to
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
/// The one error kind with its own heading and a neutral inbox icon rather than
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
