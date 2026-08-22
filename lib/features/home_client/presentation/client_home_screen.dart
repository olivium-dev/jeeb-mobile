import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/layout/bottom_inset.dart';
import '../../../core/lifecycle/route_visibility.dart';
import '../../../core/motion/jeeb_motion.dart';
import '../../../core/accessibility/accessibility.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_filter_button.dart';
import '../../../core/widgets/jeeb/jeeb_filter_pills.dart';
import '../../../core/widgets/jeeb/jeeb_mic_hero.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../request_summary/application/compose_request_controller.dart';
import '../../shell/tab_visibility.dart';
import '../../tier_selection/application/default_tier.dart';
import '../../tier_selection/domain/tier.dart';
import '../../voice_request/cubit/voice_recording_cubit.dart';
import '../../voice_request/cubit/voice_recording_state.dart';
import '../../voice_request/data/voice_recording_repository.dart';
import '../../voice_request/presentation/voice_recording_error_policy.dart';
import '../application/client_home_cubit.dart';
import '../application/client_home_state.dart';
import '../application/home_voice_cubit_factory.dart';
import '../domain/client_home_request.dart';
import 'tabs/in_progress_tab.dart';
import 'tabs/offer_status_requests_tab.dart';
import 'tabs/pending_requests_tab.dart';
import 'tabs/replies_tab.dart';
import 'widgets/client_home_empty_view.dart';
import 'widgets/client_home_greeting.dart';
import 'widgets/client_home_request_hero.dart';
import 'widgets/client_home_voice_dock.dart';
import 'widgets/client_request_filter.dart';
import 'widgets/offer_status_info_sheet.dart';

/// Client home screen — MIDNIGHT R1 (`01-r1-client-home.png`) and its E1 empty
/// (`27-e1-empty-no-requests.png`), on the hero `JeebMidnightField`.
///
/// R1 top-to-bottom: profile header · white prompt + orange Arabic tagline ·
/// Pending/Replies segmented toggle · glass cards. The create capsule is no
/// longer one of them: it is PINNED into the mic's band beside the disc, so
/// both doors into a request sit under the thumb and neither scrolls away. E1
/// swaps the cards for the composed empty illustration and nothing else moves.
///
/// The field's decor is drawn but NOT animated (`03-MOTION-NOTES` §R1: zero
/// animated elements, including the broadcast dot and the orbit rings).
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    super.key,
    this.onOpenRequest,
    this.onCreateRequest,
    this.onTrack,
    this.initialTab = ClientHomeTab.all,
    this.voiceCubit,
  });

  /// Legacy "open the conversation for a request" hook. Retained for API
  /// compatibility with the shell host (`shell/tabs/home_tab.dart`) and the
  /// widget tests that still pass it. As of JM-027/JM-023 it no longer drives
  /// the Pending and Replies sub-tabs: Pending rows route to
  /// `waiting-no-coverage` (JM-026) and Replies CTAs route to `offer-review`
  /// (JM-028) / `offer-accept-confirm` (JM-029) from inside their own tabs, so
  /// `my-orders` no longer opens `/chat/:id` (the divergence 20_GAP_MAP flagged).
  final void Function(ClientHomeRequest request)? onOpenRequest;

  /// Opens the TYPED create door. The screen hands over the tier it already
  /// warmed, so the host never re-fetches the catalog on the tap.
  final void Function(Tier? seedTier)? onCreateRequest;

  /// Opens the live-tracking screen (`/orders/:id/tracking`) for an in-progress
  /// delivery's "Track my order" CTA. Distinct from [onOpenRequest]. When null
  /// the [InProgressTab] falls back to GoRouter navigation directly.
  final void Function(ClientHomeRequest request)? onTrack;

  /// Which bucket the list opens on; [ClientHomeTab.all] is the merged default.
  /// Anything else is a pinned FILTER and renders its applied pill.
  final ClientHomeTab initialTab;

  /// Test seam, mirroring `VoiceRecordingScreen.cubit`. An injected cubit is
  /// never closed by this screen.
  final VoiceRecordingCubit? voiceCubit;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with WidgetsBindingObserver {
  late ClientRequestFilter _filter = ClientRequestFilter(
    bucket: widget.initialTab,
  );

  /// Whether the app is in the foreground. The 10s home poll must NOT keep
  /// firing while the app is backgrounded (F3 — offers polling storm): a hidden
  /// app hammering `/requests` + `/deliveries` + `/v1/offers` is pure waste and
  /// a fast path to a 429. Starts true (a freshly-built screen is foreground).
  bool _appResumed = true;

  /// Last-observed shell-tab visibility, used to detect the off-screen →
  /// on-screen transition. `null` until the first [didChangeDependencies] so we
  /// never auto-refresh on the very first frame ([initState] owns that load).
  bool? _wasVisible;

  /// Captured in [didChangeDependencies] so the resume refetch can reach the
  /// cubit without an unsafe `context.read` from a lifecycle callback.
  ClientHomeCubit? _homeCubit;

  /// Built on first use, never in [dispose]: the production recorder/player
  /// touch platform channels in their constructors.
  VoiceRecordingCubit? _voiceCubit;
  VoiceRecordingCubit get _voice =>
      _voiceCubit ??= widget.voiceCubit ?? buildHomeVoiceCubit();

  /// True between touch-down and release on the mic. Closes the cubit's own
  /// race: `startRecording` emits `idle` before awaiting the platform recorder.
  bool _pressDown = false;

  /// A recording running with NO finger on the glass — the tap route in. A
  /// notifier: the next activation stops it, and the dock has to say so.
  final ValueNotifier<bool> _handsFree = ValueNotifier<bool>(false);
  bool get _tapLatched => _handsFree.value;
  set _tapLatched(bool value) => _handsFree.value = value;

  /// True once the user asked THIS recording to end. Auto-send is gated on it,
  /// so a latch nobody is watching cannot upload itself at the 60s cap.
  bool _stopRequested = false;

  /// True when the last press ended in a `PointerCancel`. The disc joins no
  /// gesture arena, so only the platform steals its touch.
  bool _pressStolen = false;

  /// 0..1 slide-to-cancel travel, written by the mic and read by the disc's
  /// transform and the dock's hint — a notifier so a pointer move rebuilds none.
  final ValueNotifier<double> _slideProgress = ValueNotifier<double>(0);

  /// True when the recording now ending is being THROWN AWAY. Cancel cuts the
  /// scrim; a send hands it off. Read on the exit edge, never listened to.
  final ValueNotifier<bool> _cancelExit = ValueNotifier<bool>(false);

  Tier? _tier;
  Future<void>? _tierWarm;
  bool _tierBlocked = false;
  bool _tierRetrying = false;
  TranscriptionResult? _pendingHandOff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_warmTiers());
      final cubit = context.read<ClientHomeCubit>();
      if (cubit.state.status == ClientHomeStatus.initial) {
        cubit.load();
      }
    });
  }

  /// N3's RESUME one-shot — the backstop that makes a DROPPED push cost
  /// freshness until the user next looks, instead of a permanently wrong
  /// screen. One silent [ClientHomeCubit.refresh] when the app comes back to
  /// the foreground, iff this tab is on screen.
  ///
  /// b02 P0 — deliberately NOT moved to [AppResumeSignals], unlike the other
  /// seven resume-refetch surfaces, and the reason SURVIVES the poll deletion:
  /// the `if (resumed == _appResumed) return;` line below makes this an EDGE
  /// trigger, and that is why this screen contributed ZERO reads to the
  /// measured 60-read storm while the three level-triggered observers
  /// contributed twenty each. It is also the control that proves the platform
  /// re-delivered `resumed` with no intervening background state — had there
  /// been one, this guard would have re-armed and `/requests` + `/deliveries`
  /// would appear in the capture. They do not. Swapping a working edge trigger
  /// for the shared bus would buy nothing and retire that control.
  ///
  /// (The second reason recorded here — "`_appResumed` gates the 10 s poll,
  /// which must stop on the RAW `paused` notification" — is now moot: there is
  /// no poll to gate.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    if (!resumed) {
      // A backgrounded app may never deliver the pointer-up; a stuck
      // `_pressDown` would disable auto-send for the rest of the session.
      _pressDown = false;
      _tapLatched = false;
      _stopRequested = false;
      _cancelExit.value = true;
      unawaited(_voice.cancelRecording());
      _clearBlockingVoiceError();
      return;
    }
    // Back-to-foreground: one immediate refresh iff this tab is on-screen.
    final cubit = _homeCubit;
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    if (cubit == null || !isVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cubit.refresh();
    });
  }

  /// S13 auto-refresh: the Requests tab is an [IndexedStack] child, so
  /// re-entering it from the bottom nav (or returning from a create/accept
  /// flow that left the shell mounted) does NOT re-run [initState]. Watch the
  /// shell-provided [TabVisibility] and, whenever this tab goes off-screen →
  /// on-screen, silently re-pull so a freshly created/accepted order surfaces
  /// without a manual pull-to-refresh. [ClientHomeCubit.refresh] keeps the
  /// current data painted (no loading flash) and drops re-entrant calls.
  /// Outside the shell (bare tests / deep links) [TabVisibility.maybeOf] is
  /// null → treated as always-visible → this affordance is inert.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _homeCubit = context.read<ClientHomeCubit>();
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    final becameVisible = _wasVisible == false && isVisible;
    // Nothing else stops the recorder on a bottom-nav switch: this tab is an
    // [IndexedStack] child, so it is never disposed.
    if (_wasVisible == true && !isVisible) {
      _pressDown = false;
      _tapLatched = false;
      _stopRequested = false;
      _cancelExit.value = true;
      unawaited(_voice.cancelRecording());
      _clearBlockingVoiceError();
    }
    _wasVisible = isVisible;
    final onTop = RouteVisibilityScope.isOnTop(context);
    if (_pendingHandOff != null && isVisible && onTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = _pendingHandOff;
        if (mounted && pending != null) _handOff(pending);
      });
    }
    if (!becameVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClientHomeCubit>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final owned = widget.voiceCubit == null ? _voiceCubit : null;
    if (owned != null) _closeVoice(owned);
    _slideProgress.dispose();
    _cancelExit.dispose();
    _handsFree.dispose();
    super.dispose();
  }

  /// Closing mid-upload throws twice out of [VoiceRecordingCubit.send]'s own
  /// catch, so the close waits for the POST to land — but never forever.
  void _closeVoice(VoiceRecordingCubit voice) {
    if (!voice.state.isSending) {
      unawaited(voice.close());
      return;
    }
    StreamSubscription<VoiceRecordingState>? sub;
    Timer? bail;
    var done = false;
    void finish() {
      if (done) return;
      done = true;
      bail?.cancel();
      unawaited(sub?.cancel());
      unawaited(voice.close());
    }

    sub = voice.stream.listen((s) {
      if (!s.isSending) finish();
    });
    bail = Timer(_kUploadCloseGrace, finish);
  }

  Future<void> _onPressStart() async {
    if (_voice.state.isSending) return;
    _pressDown = true;
    _pressStolen = false;
    _stopRequested = false;
    _cancelExit.value = false;
    _pendingHandOff = null;
    unawaited(_warmTiers());
    // A press always means "record again": startRecording is a no-op from
    // `recorded`, which would strand a failed clip behind a dead mic.
    if (_voice.state.hasClip) await _voice.discardClip();
    if (!mounted) return;
    if (!_pressDown) {
      // Released while the old clip was being dropped — a tap, so honour it.
      if (_pressStolen) {
        _showHoldHint();
        return;
      }
      await _startFromActivation();
      return;
    }
    if (_tierBlocked) setState(() => _tierBlocked = false);
    await _voice.startRecording();
    if (!mounted || _pressDown) return;
    if (_pressStolen) {
      // The first-run permission dialog took the pointer, not the user. Drop
      // the orphan recording and say why nothing was captured.
      if (_voice.state.isRecording) {
        await _voice.cancelRecording();
        _showHoldHint();
      }
      return;
    }
    // The release beat the platform recorder: keep what it finally opened and
    // let the next activation close it.
    if (_voice.state.isRecording) _tapLatched = true;
  }

  /// Recording from an activation rather than a hold — the screen-reader tap
  /// and the sighted quick tap land here, and neither has a release edge.
  Future<void> _startFromActivation() async {
    if (_voice.state.isSending) return;
    _pressDown = false;
    _pressStolen = false;
    _stopRequested = false;
    _cancelExit.value = false;
    _pendingHandOff = null;
    unawaited(_warmTiers());
    if (_voice.state.hasClip) await _voice.discardClip();
    if (!mounted) return;
    if (_tierBlocked) setState(() => _tierBlocked = false);
    await _voice.startRecording();
    if (!mounted) return;
    // A pointer stolen while the recorder came up must not leave a latch.
    if (_voice.state.isRecording && !_pressStolen) _tapLatched = true;
  }

  /// The screen-reader route into recording: press-and-hold carries no
  /// semantics action, so activation has to be a start/stop toggle.
  Future<void> _onMicSemanticTap() async {
    if (_voice.state.isSending) return;
    if (_voice.state.isRecording) {
      _tapLatched = false;
      _stopRequested = true;
      await _voice.stopRecording();
      return;
    }
    await _startFromActivation();
  }

  void _showHoldHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).homeVoiceHoldToRecord),
        ),
      );
  }

  /// Re-checks the mic pre-conditions without leaving a runaway recording: a
  /// tap has no release edge to stop one.
  Future<void> _retryBlocked() async {
    await _voice.startRecording();
    if (_voice.state.isRecording) await _voice.cancelRecording();
  }

  void _clearBlockingVoiceError() {
    final error = _voiceCubit?.state.error;
    if (error != null && isBlockingVoiceError(error)) {
      _voice.acknowledgeError();
    }
  }

  /// The dock's blocking and tier surfaces are persistent by design, so both
  /// need an exit that is not "succeed at the thing that just failed".
  void _dismissBlocked() => _clearBlockingVoiceError();

  void _dismissTier() {
    _pendingHandOff = null;
    unawaited(_voice.reset());
    setState(() {
      _tierBlocked = false;
      _tierRetrying = false;
    });
  }

  /// The typed door. Hands the host the tier this screen already warmed, so the
  /// tap never blocks on `GET /tiers` and never stacks two pushes.
  void _openTyped() {
    if (_voice.state.isRecording) {
      // Leaving home with a live recorder would strand it: nothing else on this
      // route stops it, and the pinned capsule is reachable to a screen reader.
      _tapLatched = false;
      _stopRequested = false;
      _cancelExit.value = true;
      unawaited(_voice.cancelRecording());
    }
    widget.onCreateRequest?.call(_tier);
  }

  void _typeInstead() {
    _clearBlockingVoiceError();
    if (_tierBlocked || _pendingHandOff != null) _dismissTier();
    _openTyped();
  }

  void _onPressEnd() {
    _pressDown = false;
    final VoiceRecordingState s = _voice.state;
    if (_tapLatched) {
      // The latch is consumed FIRST, so a second tap can always stop.
      _tapLatched = false;
    } else if (!_pressStolen &&
        s.isRecording &&
        s.elapsed < VoiceRecordingState.minSendableDuration) {
      // Too brief to be a hold: this was a tap, so keep listening.
      _tapLatched = true;
      return;
    }
    _stopRequested = true;
    if (s.phase == VoiceRecordingPhase.recorded) {
      _maybeAutoSend();
      return;
    }
    unawaited(_voice.stopRecording());
  }

  /// Only the platform reaches here, so it is the exact discriminator between
  /// a quick tap and the first-run permission dialog stealing the touch.
  void _onPressCancel() {
    _pressStolen = true;
    _tapLatched = false;
    _onPressEnd();
  }

  void _onSlideCancel() {
    _pressDown = false;
    _tapLatched = false;
    _stopRequested = false;
    _cancelExit.value = true;
    unawaited(_voice.cancelRecording());
  }

  void _onVoiceState(BuildContext context, VoiceRecordingState state) {
    // Live state, not the delivered event: a late `idle` from the start of a
    // tap must not clear the latch the same start just armed.
    if (!_voice.state.isRecording) _tapLatched = false;
    final l10n = AppLocalizations.of(context);
    final error = state.error;
    if (error != null && isTransientVoiceError(error)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      showOmdsErrorSnackbar(context, message: voiceErrorCopy(l10n, error));
      _voice.acknowledgeError();
    }
    _announceVoice(context, l10n, state);
    _maybeAutoSend();
    final result = state.result;
    if (state.phase == VoiceRecordingPhase.sent && result != null) {
      _handOff(result);
    }
  }

  /// Every dock transition is silent to a screen reader otherwise: the dock is
  /// an unfocused container and the mic's label change is not announced.
  void _announceVoice(
    BuildContext context,
    AppLocalizations l10n,
    VoiceRecordingState state,
  ) {
    final error = state.error;
    final String? message;
    if (error != null && isBlockingVoiceError(error)) {
      message = voiceErrorCopy(l10n, error);
    } else if (state.isRecording) {
      // Never "release to stop": the assistive route in is a tap, so there is
      // no finger down to release.
      message = l10n.homeMicLabelRecording;
    } else if (state.isSending) {
      message = l10n.voiceRecordingSending;
    } else {
      message = null;
    }
    if (message == null) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  void _maybeAutoSend() {
    final s = _voice.state;
    if (_pressDown) return;
    if (s.hasUploadFailure) return;
    if (s.phase != VoiceRecordingPhase.recorded) return;
    if (!_stopRequested) {
      // The cap ended a latch nobody asked to end: uploading it would navigate
      // the customer off home on a pocket brush, and keeping it strands a clip.
      unawaited(_voice.discardClip());
      return;
    }
    if (!s.canSend) return;
    unawaited(_voice.send());
  }

  void _handOff(TranscriptionResult result) {
    if (!sl.isRegistered<ComposeRequestController>()) {
      _pendingHandOff = null;
      unawaited(_voice.reset());
      return;
    }
    // `isOnTop` is the SHELL route, shared by every bottom-nav tab, so it alone
    // would let an upload that lands after a tab switch push over Wallet.
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    if (!isVisible || !RouteVisibilityScope.isOnTop(context)) {
      _pendingHandOff = result;
      return;
    }
    final tier = _tier;
    if (tier == null) {
      _pendingHandOff = result;
      if (!_tierBlocked) setState(() => _tierBlocked = true);
      return;
    }

    final transcript = result.transcript?.trim();
    sl<ComposeRequestController>().beginVoiceSession(
      tier: tier,
      description: transcript,
      transcription: transcript,
      audioUrl: result.id,
    );
    _pendingHandOff = null;
    if (_tierBlocked || _tierRetrying) {
      setState(() {
        _tierBlocked = false;
        _tierRetrying = false;
      });
    }
    // The voice door lands on the SAME tier screen as every other door;
    // `resume=1` makes its Continue re-price instead of blanking the clip.
    GoRouter.maybeOf(context)?.pushNamed(
      'request-type',
      queryParameters: const {'resume': '1'},
    );
    if (transcript == null || transcript.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).homeVoiceTranscriptEmpty,
            ),
          ),
        );
    }
    unawaited(_voice.reset());
  }

  /// A default tier can never be a hardcoded string — `Tier.wireId` is the
  /// live catalog's `serverId`, and a null one makes the create POST 400.
  Future<void> _warmTiers() {
    if (_tier != null) return Future<void>.value();
    // `whenComplete` always defers, so a body that returns synchronously (no
    // TierRepository registered) cannot clear the latch before `??=` stores it.
    return _tierWarm ??= _fetchTier().whenComplete(() {
      _tierWarm = null;
      _afterTierWarm();
    });
  }

  Future<void> _fetchTier() async {
    final tier = await resolveDefaultTier();
    // The dock's tier surface is the recovery; _tier simply stays null.
    if (mounted) _tier = tier;
  }

  /// Runs on EVERY warm, success or failure — the resume must not be gated on
  /// `_tierBlocked`, which the retry has to clear before it can show progress.
  void _afterTierWarm() {
    if (!mounted) return;
    final pending = _pendingHandOff;
    if (_tier == null) {
      setState(() {
        _tierRetrying = false;
        _tierBlocked = pending != null;
      });
      return;
    }
    setState(() {
      _tierRetrying = false;
      _tierBlocked = false;
    });
    if (pending != null) _handOff(pending);
  }

  void _retryTier() {
    if (_tier != null) {
      _afterTierWarm();
      return;
    }
    setState(() => _tierRetrying = true);
    unawaited(_warmTiers());
  }

  /// How many rows the staged [filter] would put on screen — the live count the
  /// sheet's apply CTA carries.
  int _countFor(ClientHomeState state, ClientRequestFilter filter) {
    final ClientOfferStatus? status = filter.offerStatus;
    if (status != null) {
      return state.offerStatusRequests
          .where((request) => request.offerStatuses.contains(status))
          .length;
    }
    return state.listFor(filter.bucket).length;
  }

  Future<void> _openFilterSheet() async {
    // Read through the cubit, never a snapshot: the 10s home poll can land
    // while the sheet is open and the apply CTA counts must not go stale.
    final ClientHomeCubit cubit = context.read<ClientHomeCubit>();
    final ClientRequestFilter? applied = await OfferStatusInfoSheet.show(
      context,
      filter: _filter,
      countFor: (draft) => _countFor(cubit.state, draft),
    );
    if (applied == null || !mounted) return;
    setState(() => _filter = applied);
  }

  @override
  Widget build(BuildContext context) {
    // Mounted above the status BlocBuilder and never conditionally: anything
    // added or removed over the mic disposes the state holding the live press.
    return BlocProvider<VoiceRecordingCubit>.value(
      value: _voice,
      child: BlocListener<VoiceRecordingCubit, VoiceRecordingState>(
        listenWhen: (prev, curr) =>
            prev.phase != curr.phase || prev.error != curr.error,
        listener: _onVoiceState,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      builder: (context, state) {
        // E1's composition: a create-first screen with nothing to list. The
        // ONLY state that re-homes the empty CTA id and the empty avatar id.
        final bool firstRequest =
            state.status == ClientHomeStatus.ready &&
            _filter.offerStatus == null &&
            _filter.bucket != ClientHomeTab.inProgress &&
            state.pending.isEmpty &&
            state.replies.isEmpty;
        return Semantics(
          identifier: 'client_home_root',
          container: true,
          explicitChildNodes: true,
          // The shell keeps every tab mounted in an IndexedStack, so an
          // ungated loop here would schedule frames from Wallet and Chat too.
          child: TickerMode(
            enabled: TabVisibility.maybeOf(context)?.isVisible ?? true,
            child: JeebMidnightField(
              variant: JeebFieldVariant.hero,
              // R1 declares .32; the ratified single .24 is the app default.
              glowColor: context.jeebRoles.accent.withValues(alpha: 0.32),
              animateDecor: false,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OmdsPullToRefresh(
                    onRefresh: () => context.read<ClientHomeCubit>().refresh(),
                    child: _ClientHomeBody(
                      state: state,
                      filter: _filter,
                      firstRequest: firstRequest,
                      onFilterChanged: (filter) =>
                          setState(() => _filter = filter),
                      onOpenFilterSheet: () => unawaited(_openFilterSheet()),
                      onTrack: widget.onTrack,
                    ),
                  ),
                  // Before the scrim, so recording dims the typed door too.
                  _PinnedCreateCta(
                    onCreateRequest: widget.onCreateRequest == null
                        ? null
                        : _openTyped,
                    firstRequest: firstRequest,
                  ),
                  // Under the dock and the disc, over everything else: the
                  // focus wash is what raises their contrast while recording.
                  _RecordingScrim(cancelExit: _cancelExit),
                  ClientHomeVoiceDock(
                    bottom:
                        context.scrollBodyBottomInset + _kFloatingMicReserve,
                    slideProgress: _slideProgress,
                    handsFree: _handsFree,
                    tierBlocked: _tierBlocked,
                    tierRetrying: _tierRetrying,
                    onRetryUpload: () => unawaited(_voice.send()),
                    onDiscard: () => unawaited(_voice.discardClip()),
                    onRetryBlocked: () => unawaited(_retryBlocked()),
                    onDismissBlocked: _dismissBlocked,
                    onTypeInstead: widget.onCreateRequest == null
                        ? null
                        : _typeInstead,
                    onRetryTier: _retryTier,
                    onDismissTier: _dismissTier,
                  ),
                  // Last, so the disc keeps hit priority over the dock.
                  _FloatingVoiceMic(
                    onPressStart: () => unawaited(_onPressStart()),
                    onPressEnd: _onPressEnd,
                    onPressCancel: _onPressCancel,
                    onSlideCancel: _onSlideCancel,
                    onSemanticTap: () => unawaited(_onMicSemanticTap()),
                    onSemanticCancel: _onSlideCancel,
                    slideProgress: _slideProgress,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClientHomeBody extends StatelessWidget {
  const _ClientHomeBody({
    required this.state,
    required this.filter,
    required this.firstRequest,
    required this.onFilterChanged,
    required this.onOpenFilterSheet,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientRequestFilter filter;
  final bool firstRequest;
  final ValueChanged<ClientRequestFilter> onFilterChanged;
  final VoidCallback onOpenFilterSheet;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ClientHomeStatus.initial:
      case ClientHomeStatus.loading:
        return _LoadingLayout(name: state.greetingName);
      case ClientHomeStatus.failed:
        return _FailedLayout(name: state.greetingName);
      case ClientHomeStatus.ready:
        return _ReadyLayout(
          state: state,
          filter: filter,
          firstRequest: firstRequest,
          onFilterChanged: onFilterChanged,
          onOpenFilterSheet: onOpenFilterSheet,
          onTrack: onTrack,
        );
    }
  }
}

/// Screen gutter (token sheet §5) for every block this screen stacks.
const EdgeInsetsGeometry _kGutter = EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.xLarge,
);

/// Air over the shell's pill nav — wide enough that the disc's drop glow and
/// its 48dp slop do not reach the nav slots underneath it.
const double _kFloatingMicGap = Spacing.xLarge;

/// The tail every list reserves so its last row clears the floating mic.
const double _kFloatingMicReserve =
    JeebMicHero.sizeCompact + _kFloatingMicGap + Spacing.medium;

/// Tail the lists reserve so the last card clears BOTH pinned surfaces — the
/// mic's halo box and the create capsule — by a Spacing.medium breather.
final double _kScrollTailReserve =
    math.max(
      _kFloatingMicGap +
          JeebMicHero.sizeCompact +
          (_kMicExtent - JeebMicHero.sizeCompact) / 2,
      _kCreateCtaBottom + kMinInteractiveDimension + 2,
    ) +
    Spacing.medium;

/// How long a dispose waits on an in-flight upload before closing anyway, so a
/// hung POST cannot leak the cubit and its platform recorder forever.
const Duration _kUploadCloseGrace = Duration(seconds: 30);

/// End inset that clears the disc's whole reserved box, leaving `Spacing.small`
/// of air between the capsule's end edge and the Ø56 disc.
final double _kCreateCtaEnd = Spacing.medium + _kMicExtent;

/// Bottom offset that lands the 48dp capsule's centre exactly on the disc's.
const double _kCreateCtaBottom =
    _kFloatingMicGap + (JeebMicHero.sizeCompact - kMinInteractiveDimension) / 2;

/// The typed door, pinned beside the mic instead of scrolling with the list:
/// both ways into a request now live in the same thumb band.
class _PinnedCreateCta extends StatelessWidget {
  const _PinnedCreateCta({
    required this.onCreateRequest,
    required this.firstRequest,
  });

  final VoidCallback? onCreateRequest;
  final bool firstRequest;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: Spacing.xLarge,
      end: _kCreateCtaEnd,
      bottom: context.scrollBodyBottomInset + _kCreateCtaBottom,
      child: SafeArea(
        top: false,
        bottom: false,
        // Effective only because the capsule carries no `BackdropFilter`: a
        // filter re-samples the scrolling backdrop whatever boundary wraps it.
        child: RepaintBoundary(
          child: ClientHomeRequestHero(
            onCreateRequest: onCreateRequest,
            showPrompt: false,
            firstRequest: firstRequest,
          ),
        ),
      ),
    );
  }
}

/// Zero ships a flat wash — a full-screen blur cannot be opacity-faded and is
/// over the §4 budget. Non-zero swaps in a real one with no other change.
const double _kScrimBlurSigma = 0;

/// Wash strength over the navy field. `surface`, never black — black grays it.
const double _kScrimAlpha = 0.72;

/// In slightly slower than the halo pop, so the mic reads first.
const Duration _kScrimIn = Duration(milliseconds: 220);

/// Out on the send path — a baton pass. Tracks `isRecording` ONLY: holding it
/// through `isSending` would scrim a frozen screen for the whole upload grace.
const Duration _kScrimOutSend = Duration(milliseconds: 240);

/// Out on the cancel path — a cut, not a fade.
const Duration _kScrimOutCancel = Duration(milliseconds: 150);

/// Darkens everything the route owns while recording. Absorbing but INERT: it
/// only ever sees a second finger, which must neither scroll nor cancel.
class _RecordingScrim extends StatefulWidget {
  const _RecordingScrim({required this.cancelExit});

  final ValueListenable<bool> cancelExit;

  @override
  State<_RecordingScrim> createState() => _RecordingScrimState();
}

class _RecordingScrimState extends State<_RecordingScrim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this);
  bool _absorbing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(context.read<VoiceRecordingCubit>().state.isRecording, rebuild: false);
    // A muted ticker never advances the fade, so a tab switch mid-recording
    // would otherwise replay a full-screen wash on the way back.
    // Flutter 3.38 CI does not expose TickerMode.valuesOf yet.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) _settle();
  }

  void _settle() => _fade
    ..stop()
    ..value = _absorbing ? 1 : 0;

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _sync(bool recording, {bool rebuild = true}) {
    if (recording == _absorbing) return;
    _absorbing = recording;
    if (rebuild) setState(() {});
    // Flutter 3.38 CI does not expose TickerMode.valuesOf yet.
    // ignore: deprecated_member_use
    final bool ticking = TickerMode.of(context);
    if (!ticking || MediaQuery.disableAnimationsOf(context)) {
      _settle();
      return;
    }
    if (recording) {
      _fade.animateTo(1, duration: _kScrimIn, curve: Curves.easeOutCubic);
      return;
    }
    final bool cancelled = widget.cancelExit.value;
    _fade.animateBack(
      0,
      duration: cancelled ? _kScrimOutCancel : _kScrimOutSend,
      curve: cancelled ? Curves.easeIn : Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color wash = Theme.of(
      context,
    ).colorScheme.surface.withValues(alpha: _kScrimAlpha);
    return BlocListener<VoiceRecordingCubit, VoiceRecordingState>(
      listenWhen: (prev, curr) => prev.isRecording != curr.isRecording,
      listener: (_, state) => _sync(state.isRecording),
      child: Positioned.fill(
        child: RepaintBoundary(
          child: IgnorePointer(
            ignoring: !_absorbing,
            child: Listener(
              key: const Key('client-home-recording-scrim'),
              behavior: HitTestBehavior.opaque,
              child: ExcludeSemantics(
                child: FadeTransition(opacity: _fade, child: _wash(wash)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _wash(Color color) => _kScrimBlurSigma <= 0
      ? ColoredBox(color: color)
      : BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _kScrimBlurSigma,
            sigmaY: _kScrimBlurSigma,
          ),
          child: ColoredBox(color: color),
        );
}

/// The extent the disc claims once the halo and arc turn on, reserved always so
/// the disc does not jump the instant a press starts recording.
final double _kMicExtent = JeebMicHero.extentFor(
  size: JeebMicHero.sizeCompact,
  halo: true,
  arc: true,
);

/// The idle hold ring — Ø68 in the annulus the reserved extent leaves around the
/// Ø56 disc, outside the recording arc's Ø67 outer edge.
const double _kMicIdleRing = JeebMicHero.sizeCompact + Spacing.small;
const double _kMicIdleRingStroke = 1.5;

/// How deep the idle pantomime presses the disc.
const double _kMicPressScale = 0.94;

/// The idle "hold me" pantomime — the visible carrier of the gesture now that
/// the caption is gone: rest, press IN, **dwell**, release. A dwell is what
/// separates a hold from a tap; a drift or a breath encodes neither.
///
/// Phase 0 is the unpressed rest keyframe, so the reduce-motion still is the
/// disc at full size inside its full-width ring.
final Animatable<double> _kMicPress =
    TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: ConstantTween<double>(0), weight: 26),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: JeebMotion.floatCurve)),
        weight: 16,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(1), weight: 34),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: JeebMotion.floatCurve)),
        weight: 24,
      ),
    ]);

/// How far the held disc shrinks as the slide reaches the cancel wall.
const double _kMicSlideShrink = 0.10;

/// Rubber band: 1:1 to the knee, then [_kMicBandRate] — a finger arming at 64
/// leaves the disc at 56dp, and the last 8dp are the dock's to close.
const double _kMicBandKnee = 32;
const double _kMicBandRate = 0.75;

/// The magnetic snap onto the chip, and how long it takes. Also the tempo of
/// the mic → delete glyph crossfade.
const double _kMicDockPull = 8;
const Duration _kMicDockDuration = Duration(milliseconds: 90);

/// The send release: the disc GLIDES home instead of teleporting.
const Duration _kMicGlideDuration = Duration(milliseconds: 120);

/// The cancel commit: shrink into the chip (150), a beat (50), then the disc
/// springs back at rest (180).
const Duration _kMicCommitDuration = Duration(milliseconds: 380);

/// Where in [_kMicCommitDuration] the slide sink is released back to 0 — the
/// disc is already at scale 0 by then, so the trip home is invisible.
const double _kMicCommitHold = 200 / 380;

/// The cancel destination: a Ø32 chip [_kChipOffset] dp toward the START edge
/// of the disc's rest centre, revealed across this slice of finger travel.
const double _kChipDiameter = 32;
const double _kChipOffset = 64;
const double _kChipRevealStart = 0.25;
const double _kChipRevealEnd = 0.70;
const Duration _kChipPulseDuration = Duration(milliseconds: 450);

/// The arm ring's paint box. `jHalo` starts at .75 of the box radius, so this
/// has to clear the docked Ø56·0.9 disc that lands on the chip, or it is unseen.
const double _kChipPulseExtent = 80;

/// Where the disc's accent starts turning toward `error`.
const double _kMicTintStart = 0.5;

/// WCAG relative contrast between two OPAQUE colours.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The glyph ink for a disc that lerps accent → `error`: white loses AA long
/// before the fill arrives, and `onError` is page navy, so the pair swaps.
Color _discInk(Color disc, Color onAccent, Color onError) =>
    _contrast(disc, onAccent) >= _contrast(disc, onError) ? onAccent : onError;

/// Commit choreography for the disc: 1 → 0 into the chip, hold, then 0.8 → 1
/// back at rest. Both ends are 1, so a resting controller is a no-op.
final Animatable<double> _kMicCommitScale =
    TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 150,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(0), weight: 50),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.8,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 180,
      ),
    ]);

/// The chip's answering pop as the disc lands in it.
final Animatable<double> _kChipCommitScale =
    TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 1.15),
        weight: 90,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.15, end: 0),
        weight: 90,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(0), weight: 200),
    ]);

final Animatable<double> _kChipCommitOpacity =
    TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: ConstantTween<double>(1), weight: 90),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0),
        weight: 90,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(0), weight: 200),
    ]);

/// Disc travel for a raw finger `t`. The sink stays raw finger travel; the map
/// is the consumer's so the widget's arm verdict can never disagree with it.
double _micBandTravel(double t) {
  final double x = JeebMicHero.slideCancelThreshold * t;
  if (x <= _kMicBandKnee) return x;
  return _kMicBandKnee + (x - _kMicBandKnee) * _kMicBandRate;
}

/// The screen's primary action, floated bottom-end so it sits under the thumb.
/// Press-and-hold records in place; there is no voice route to open.
class _FloatingVoiceMic extends StatefulWidget {
  const _FloatingVoiceMic({
    required this.onPressStart,
    required this.onPressEnd,
    required this.onPressCancel,
    required this.onSlideCancel,
    required this.onSemanticTap,
    required this.onSemanticCancel,
    required this.slideProgress,
  });

  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onPressCancel;
  final VoidCallback onSlideCancel;
  final VoidCallback onSemanticTap;
  final VoidCallback onSemanticCancel;
  final ValueNotifier<double> slideProgress;

  @override
  State<_FloatingVoiceMic> createState() => _FloatingVoiceMicState();
}

/// The only legal home for the exit controllers: below the screen's TickerMode,
/// above the idle one, which is muted for the whole recording and upload.
class _FloatingVoiceMicState extends State<_FloatingVoiceMic>
    with TickerProviderStateMixin {
  late final AnimationController _dock = AnimationController(
    vsync: this,
    duration: _kMicDockDuration,
  );

  /// Only ever painted while it is `forward`: `JHaloPainter` mods the phase, so
  /// EVERY resting value is a lit ring — the paint has to be gated instead.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _kChipPulseDuration,
  );

  late final AnimationController _commit = AnimationController(
    vsync: this,
    duration: _kMicCommitDuration,
  );

  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: _kMicGlideDuration,
  );

  bool _armed = false;
  bool _committing = false;
  bool _gliding = false;
  double _glideFrom = 0;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    widget.slideProgress.addListener(_onSlide);
    _commit
      ..addListener(_driveCommit)
      ..addStatusListener(_onCommitStatus);
    _glide
      ..addListener(_driveGlide)
      ..addStatusListener(_onGlideStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    // A muted ticker freezes an exit curve where it stands; it would otherwise
    // resume whenever the user next returns to this tab.
    // Flutter 3.38 CI does not expose TickerMode.valuesOf yet.
    // ignore: deprecated_member_use
    if (!TickerMode.of(context)) _landExits();
  }

  void _landExits() {
    if (!_gliding && !_committing) return;
    _gliding = false;
    _committing = false;
    _glide.stop();
    _commit
      ..stop()
      ..value = 0;
    _dock.value = 0;
    widget.slideProgress.value = 0;
  }

  @override
  void dispose() {
    widget.slideProgress.removeListener(_onSlide);
    _dock.dispose();
    _pulse.dispose();
    _commit.dispose();
    _glide.dispose();
    super.dispose();
  }

  void _onSlide() {
    final bool armed = widget.slideProgress.value >= 1;
    if (armed == _armed) return;
    _armed = armed;
    if (_reduce) {
      _dock.value = armed ? 1 : 0;
      return;
    }
    if (!armed) {
      _dock.reverse();
      return;
    }
    _dock.forward();
    _pulse.forward(from: 0);
  }

  void _driveCommit() {
    if (!_committing) return;
    if (_commit.value < _kMicCommitHold) {
      widget.slideProgress.value = 1;
      return;
    }
    // The disc is already at scale 0 here, so un-docking it is a state change
    // rather than motion — animating 8dp nobody can see just delays "home".
    _dock.value = 0;
    widget.slideProgress.value = 0;
  }

  void _onCommitStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _committing = false;
    widget.slideProgress.value = 0;
  }

  void _driveGlide() {
    if (!_gliding) return;
    widget.slideProgress.value =
        _glideFrom * (1 - Curves.easeOut.transform(_glide.value));
  }

  void _onGlideStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _gliding = false;
    widget.slideProgress.value = 0;
  }

  /// The mic zeroes the sink at pointer-DOWN and only then calls this, so
  /// stopping the exit curves here can never leave a stale value painted.
  void _handlePressStart() {
    _gliding = false;
    _committing = false;
    _glide.stop();
    _commit
      ..stop()
      ..value = 0;
    _dock.value = 0;
    widget.onPressStart();
  }

  void _handlePressEnd() {
    final double from = widget.slideProgress.value;
    widget.onPressEnd();
    if (_reduce || from <= 0) {
      widget.slideProgress.value = 0;
      return;
    }
    _glideFrom = from;
    _gliding = true;
    _glide.forward(from: 0);
  }

  /// The kit already zeroed the sink, so there is no travel left to glide back.
  void _handlePressCancel() {
    widget.onPressCancel();
    widget.slideProgress.value = 0;
  }

  void _handleSlideCancel() {
    HapticFeedback.lightImpact();
    widget.onSlideCancel();
    if (_reduce) {
      widget.slideProgress.value = 0;
      return;
    }
    _committing = true;
    _commit.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool reduce = _reduce;
    final int sign = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = context.jeebRoles.accent;
    final Color onAccent = context.jeebRoles.onAccent;
    final Color ringColor =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.midnight())
            .orangeSoft;
    return PositionedDirectional(
      bottom:
          context.scrollBodyBottomInset +
          _kFloatingMicGap -
          (_kMicExtent - JeebMicHero.sizeCompact) / 2,
      // 16 matches the pill nav's own side margin; the SafeArea carries the
      // landscape cutout / side nav-bar inset on the horizontal axis only.
      end: Spacing.medium,
      child: SafeArea(
        top: false,
        bottom: false,
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: _kMicExtent,
            child: BlocBuilder<VoiceRecordingCubit, VoiceRecordingState>(
              builder: (context, state) {
                final bool idle = !state.isRecording && !state.isSending;
                // Muted rather than unmounted: removing the loop would
                // re-parent the mic mid-press and kill the live pointer.
                return TickerMode(
                  enabled: idle,
                  child: JMotionLoop(
                    duration: JeebMotion.floatDurationSlow,
                    builder: (context, press, _) => Stack(
                      alignment: Alignment.center,
                      // The chip paints outside the reserved extent; a
                      // positioned child would clip the sliding disc too.
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        // Index 0 always occupied, the disc always LAST:
                        // swapping the mic's index re-parents it mid-press.
                        _MicHoldRing(
                          active: idle,
                          press: press,
                          color: ringColor,
                        ),
                        _MicCancelTarget(
                          slideProgress: widget.slideProgress,
                          commit: _commit,
                          pulse: _pulse,
                          sign: sign,
                          reduce: reduce,
                        ),
                        AnimatedBuilder(
                          animation: Listenable.merge(<Listenable>[
                            press,
                            widget.slideProgress,
                            _dock,
                            _commit,
                          ]),
                          builder: (context, _) {
                            // ONE shape on every frame — a conditional root
                            // type here re-inflates the mic mid-press.
                            final double t = widget.slideProgress.value;
                            final double travel = reduce ? 0 : t;
                            final double dock = reduce
                                ? 0
                                : Curves.easeOut.transform(_dock.value);
                            final double sink = idle
                                ? _kMicPress.evaluate(press)
                                : 0;
                            final double tint = reduce
                                ? (t >= 1 ? 1.0 : 0.0)
                                : ((t - _kMicTintStart) / (1 - _kMicTintStart))
                                      .clamp(0.0, 1.0);
                            final Color disc = Color.lerp(
                              accent,
                              scheme.error,
                              tint,
                            )!;
                            return Transform.translate(
                              offset: Offset(
                                -sign *
                                    (_micBandTravel(travel) +
                                        _kMicDockPull * dock),
                                0,
                              ),
                              child: Transform.scale(
                                scale:
                                    (1 - (1 - _kMicPressScale) * sink) *
                                    (1 - _kMicSlideShrink * travel) *
                                    _kMicCommitScale.evaluate(_commit),
                                // Paint-only: the pantomime must never shrink
                                // the 56dp target under the thumb.
                                transformHitTests: false,
                                child: JeebMicHero(
                                  key: const Key('client-home-floating-mic'),
                                  size: JeebMicHero.sizeCompact,
                                  identifier: 'client_home_mic_cta',
                                  semanticLabel: state.isRecording
                                      ? l10n.homeMicLabelRecording
                                      : (state.isSending
                                            ? l10n.voiceRecordingSending
                                            : l10n.homeMicLabel),
                                  isRecording: state.isRecording,
                                  // The halo means "listening"; an armed disc
                                  // is about to stop.
                                  halo: state.isRecording && t < 1,
                                  discColor: disc,
                                  glyphColor: _discInk(
                                    disc,
                                    onAccent,
                                    scheme.onError,
                                  ),
                                  crossfadeGlyph: Icons.delete_outline,
                                  glyphCrossfade: _dock.value,
                                  progress: state.isRecording
                                      ? (state.elapsed.inMilliseconds /
                                                VoiceRecordingState
                                                    .maxDuration
                                                    .inMilliseconds)
                                            .clamp(0.0, 1.0)
                                      : null,
                                  onPressStart: _handlePressStart,
                                  onPressEnd: _handlePressEnd,
                                  onPressCancel: _handlePressCancel,
                                  onSlideCancel: _handleSlideCancel,
                                  slideProgress: widget.slideProgress,
                                  holdSlideOnRelease: true,
                                  // Hold and slide are raw pointer; without
                                  // this AT cannot record at all.
                                  onSemanticTap: widget.onSemanticTap,
                                  semanticTapHint: state.isRecording
                                      ? l10n.homeMicTapHintStop
                                      : l10n.homeMicTapHintStart,
                                  // …and the slide is the other half of that.
                                  onSemanticCancel: state.isRecording
                                      ? widget.onSemanticCancel
                                      : null,
                                  semanticCancelLabel:
                                      l10n.homeMicCancelRecording,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The destination the slide gains, painted UNDER the disc and never a hit or
/// semantics target. Non-positioned: a positioned one would clip the disc.
class _MicCancelTarget extends StatelessWidget {
  const _MicCancelTarget({
    required this.slideProgress,
    required this.commit,
    required this.pulse,
    required this.sign,
    required this.reduce,
  });

  final ValueListenable<double> slideProgress;
  final Animation<double> commit;
  final Animation<double> pulse;
  final int sign;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final Color error = Theme.of(context).colorScheme.error;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[slideProgress, commit]),
          builder: (context, _) {
            final double t = slideProgress.value;
            final double reveal = reduce
                ? (t >= _kChipRevealStart ? 1.0 : 0.0)
                : Curves.easeOutBack.transform(
                    ((t - _kChipRevealStart) /
                            (_kChipRevealEnd - _kChipRevealStart))
                        .clamp(0.0, 1.0),
                  );
            return Opacity(
              key: const Key('client-home-mic-cancel-chip'),
              opacity:
                  reveal.clamp(0.0, 1.0) * _kChipCommitOpacity.transform(
                    commit.value,
                  ),
              child: Transform.translate(
                offset: Offset(-sign * _kChipOffset, 0),
                child: Transform.scale(
                  scale:
                      (0.6 + 0.4 * reveal) *
                      _kChipCommitScale.transform(commit.value),
                  child: SizedBox.square(
                    dimension: _kChipPulseExtent,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        AnimatedBuilder(
                          animation: pulse,
                          builder: (context, _) => CustomPaint(
                            size: const Size.square(_kChipPulseExtent),
                            painter: pulse.status == AnimationStatus.forward
                                ? JHaloPainter(
                                    progress: pulse,
                                    color: error,
                                    strokeWidth: 1.5,
                                  )
                                : null,
                          ),
                        ),
                        SizedBox.square(
                          dimension: _kChipDiameter,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: error.withValues(alpha: 0.18),
                              border: Border.all(color: error),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The "hold me" cue the deleted caption used to carry: a hairline ring that
/// CONVERGES onto the disc as the pantomime presses it in — inward pressure,
/// the opposite read of the outward halo that means "listening"
/// (`mic_cluster.dart`). Gone the moment capture starts.
class _MicHoldRing extends StatelessWidget {
  const _MicHoldRing({
    required this.active,
    required this.press,
    required this.color,
  });

  final bool active;
  final Animation<double> press;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: CustomPaint(
          key: const Key('client-home-mic-idle-ring'),
          size: const Size.square(_kMicIdleRing),
          painter: _MicHoldRingPainter(press: press, color: color),
        ),
      ),
    );
  }
}

class _MicHoldRingPainter extends CustomPainter {
  _MicHoldRingPainter({required this.press, required this.color})
    : super(repaint: press);

  final Animation<double> press;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = _kMicPress.evaluate(press);
    final double diameter =
        _kMicIdleRing + (JeebMicHero.sizeCompact - _kMicIdleRing) * t;
    canvas.drawCircle(
      size.center(Offset.zero),
      (diameter - _kMicIdleRingStroke) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _kMicIdleRingStroke
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_MicHoldRingPainter oldDelegate) =>
      oldDelegate.press != press || oldDelegate.color != color;
}

class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the nav-bar inset AND both pinned surfaces so the last item
      // clears them in edge-to-edge mode. See [BottomInsetX].
      padding: EdgeInsets.only(
        bottom: context.scrollBodyBottomInset + _kScrollTailReserve,
      ),
      children: [
        ClientHomeGreeting(name: name),
        const SizedBox(height: Spacing.medium),
        JeebEmptyState(
          status: JeebEmptyStateStatus.loading,
          headline: l10n.homeEmptyTitle,
          illustrationSize: ClientHomeEmptyView.illustrationSize,
        ),
      ],
    );
  }
}

class _FailedLayout extends StatelessWidget {
  const _FailedLayout({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the nav-bar inset AND both pinned surfaces so the retry CTA
      // clears them in edge-to-edge mode. See [BottomInsetX].
      padding: EdgeInsets.only(
        bottom: context.scrollBodyBottomInset + _kScrollTailReserve,
      ),
      children: [
        ClientHomeGreeting(name: name),
        const SizedBox(height: Spacing.medium),
        JeebEmptyState(
          status: JeebEmptyStateStatus.error,
          headline: l10n.homeLoadFailedTitle,
          body: l10n.homeLoadFailedBody,
          illustrationSize: ClientHomeEmptyView.illustrationSize,
          action: IntrinsicWidth(
            child: JeebCtaButton.primary(
              label: l10n.homeLoadFailedRetry,
              identifier: 'client_home_retry_cta',
              expand: false,
              onTap: () => context.read<ClientHomeCubit>().load(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadyLayout extends StatelessWidget {
  const _ReadyLayout({
    required this.state,
    required this.filter,
    required this.firstRequest,
    required this.onFilterChanged,
    required this.onOpenFilterSheet,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientRequestFilter filter;
  final bool firstRequest;
  final ValueChanged<ClientRequestFilter> onFilterChanged;
  final VoidCallback onOpenFilterSheet;
  final void Function(ClientHomeRequest)? onTrack;

  /// Progressive disclosure: the chrome exists once there is something to
  /// filter, or a filter is on — so there is always a way back out of one.
  bool get _showFilterChrome {
    if (filter.bucket == ClientHomeTab.inProgress) return false;
    return filter.isActive ||
        state.pending.isNotEmpty ||
        state.replies.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('client-home-ready-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the nav-bar inset AND both pinned surfaces so the last order
      // card clears them. See [BottomInsetX.scrollBodyBottomInset].
      padding: EdgeInsets.only(
        bottom: context.scrollBodyBottomInset + _kScrollTailReserve,
      ),
      children: _scrollChildren(),
    );
  }

  List<Widget> _scrollChildren() {
    return <Widget>[
      ClientHomeGreeting(
        name: state.greetingName,
        avatarSemanticsIdentifier: firstRequest
            ? '_request_empty_state_avatar'
            : null,
      ),
      const SizedBox(height: Spacing.medium),
      // Either the create prompt or the list chrome owns this slot, never both:
      // the 312px prompt above a populated list pushed content a third of the
      // way down the screen and re-said the greeting's own time-of-day line.
      if (_showFilterChrome) ...<Widget>[
        _ClientHomeRequestsHeader(
          state: state,
          filter: filter,
          onFilterChanged: onFilterChanged,
          onOpenFilterSheet: onOpenFilterSheet,
        ),
        _ClientHomeFilterPills(
          filter: filter,
          onFilterChanged: onFilterChanged,
          onOpenFilterSheet: onOpenFilterSheet,
        ),
        const SizedBox(height: Spacing.medium),
      ] else ...<Widget>[
        const Padding(
          padding: _kGutter,
          child: ClientHomeRequestHero(showCapsule: false),
        ),
        const SizedBox(height: Spacing.large),
      ],
      _ReadyContent(state: state, filter: filter, onTrack: onTrack),
    ];
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.state,
    required this.filter,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientRequestFilter filter;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    final offerStatus = filter.offerStatus;
    if (offerStatus != null) {
      return OfferStatusRequestsTab(
        status: offerStatus,
        requests: state.offerStatusRequests,
      );
    }
    switch (filter.bucket) {
      case ClientHomeTab.inProgress:
        return InProgressTab(onTrack: onTrack);
      case ClientHomeTab.pendingRequests:
        // JM-023 AC2: a pending request row routes to `waiting-no-coverage`
        // (the live broadcast/wait state, JM-026) — NOT the chat thread. We
        // pass an explicit waiting handler so the pending tap target diverges
        // from the Replies/In-Progress chat/track callbacks; the rows carry
        // the indexed `orders_home_request_row_<n>` identifier inside the tab.
        return PendingRequestsTab(
          onTap: (request) => _openWaiting(context, request),
        );
      case ClientHomeTab.replies:
        // JM-027: the Replies sub-tab owns its own navigation — Check Offers →
        // offer-review-list (JM-028) and Accept → offer-accept-confirm sheet
        // (JM-029). It MUST NOT reuse `onOpenRequest` (which routes to
        // `/chat/:id`, the divergent edge 20_GAP_MAP flagged for `my-orders`),
        // so no callbacks are injected here — RepliesTab's defaults apply.
        return const RepliesTab();
      case ClientHomeTab.all:
        return _mergedList(context);
    }
  }

  /// Replies over pending, built from the two tabs with their empty states
  /// suppressed — so `orders_home_request_row_<n>` stays pending-scoped.
  Widget _mergedList(BuildContext context) {
    final bool hasReplies = state.replies.isNotEmpty;
    final bool hasPending = state.pending.isNotEmpty;
    if (!hasReplies && !hasPending) {
      return PendingRequestsTab(
        onTap: (request) => _openWaiting(context, request),
      );
    }
    return Column(
      // stretch, never the default centre: centre hands the sections loose
      // width and every card shrink-wraps to its own text.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const RepliesTab(hideWhenEmpty: true),
        if (hasReplies && hasPending) const SizedBox(height: Spacing.small),
        PendingRequestsTab(
          hideWhenEmpty: true,
          onTap: (request) => _openWaiting(context, request),
        ),
      ],
    );
  }

  /// JM-023 AC2: route a pending request row to its waiting / no-coverage
  /// state (`waiting-no-coverage` → `/requests/:id/waiting`, JM-026), keyed by
  /// the request id. Defends an empty id (the route requires the path param).
  void _openWaiting(BuildContext context, ClientHomeRequest request) {
    if (request.id.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('waiting-no-coverage', pathParameters: {'id': request.id});
  }
}


/// The section header: title, neutral total, accent replies badge, filter disc.
/// Mounted only by [_ReadyLayout._showFilterChrome].
class _ClientHomeRequestsHeader extends StatelessWidget {
  const _ClientHomeRequestsHeader({
    required this.state,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenFilterSheet,
  });

  final ClientHomeState state;
  final ClientRequestFilter filter;
  final ValueChanged<ClientRequestFilter> onFilterChanged;
  final VoidCallback onOpenFilterSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int replies = state.replies.length;
    final int total = replies + state.pending.length;
    return Padding(
      padding: _kGutter,
      child: Row(
        key: const Key('client-home-requests-header'),
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    l10n.homeRequestsSectionTitle,
                    style: context.jeebText.cardTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Spacing.xSmall),
                Text(
                  '$total',
                  key: const Key('client-home-requests-count'),
                  style: context.jeebText.cardTitle.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (replies > 0) ...<Widget>[
            _RepliesBadge(
              count: replies,
              onTap: () => onFilterChanged(
                const ClientRequestFilter(bucket: ClientHomeTab.replies),
              ),
            ),
            const SizedBox(width: Spacing.xSmall),
          ],
          JeebFilterButton(
            identifier: 'orders_filter_open',
            active: filter.isActive,
            semanticLabel: filter.isActive
                ? l10n.homeFilterActiveA11yLabel
                : l10n.homeFilterOpenLabel,
            onTap: onOpenFilterSheet,
          ),
        ],
      ),
    );
  }
}

/// Carries JM-023/JM-027's frozen `orders_home_replies_tab`, re-homed off the
/// deleted segment: tapping it applies the has-replies bucket, as it always did.
class _RepliesBadge extends StatelessWidget {
  const _RepliesBadge({required this.count, required this.onTap});

  /// Accent at 45% — a stroke, matching `JeebFilterPill`.
  static const double borderAlpha = 0.45;

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final JeebRoles roles = context.jeebRoles;
    final String label = l10n.homeRequestsRepliesBadge(count);
    return Semantics(
      identifier: 'orders_home_replies_tab',
      label: label,
      button: true,
      container: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: roles.accentContainer,
              borderRadius: OmdsBorderRadius.pill,
              border: Border.all(
                color: roles.accent.withValues(alpha: borderAlpha),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Spacing.small,
                vertical: Spacing.twoXSmall,
              ),
              child: Text(
                label,
                key: const Key('client-home-replies-badge'),
                style: context.jeebText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: roles.onAccentContainer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D7's invariant, re-homed off the deleted clear button: a pill body reopens
/// the sheet, its ✕ drops that one facet, and one is always visible.
class _ClientHomeFilterPills extends StatelessWidget {
  const _ClientHomeFilterPills({
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenFilterSheet,
  });

  final ClientRequestFilter filter;
  final ValueChanged<ClientRequestFilter> onFilterChanged;
  final VoidCallback onOpenFilterSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ClientOfferStatus? status = filter.offerStatus;
    return JeebFilterPillRow(
      key: const Key('client-home-filter-pills'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.small,
        Spacing.xLarge,
        0,
      ),
      pills: <Widget>[
        if (filter.bucket != ClientHomeTab.all)
          _pill(
            l10n,
            label: clientBucketLabel(l10n, filter.bucket),
            identifier: 'orders_filter_pill_bucket',
            onClear: () =>
                onFilterChanged(ClientRequestFilter(offerStatus: status)),
          ),
        if (status != null)
          _pill(
            l10n,
            label: offerStatusTitle(l10n, status),
            identifier: 'orders_filter_pill_status',
            onClear: () =>
                onFilterChanged(ClientRequestFilter(bucket: filter.bucket)),
          ),
      ],
    );
  }

  Widget _pill(
    AppLocalizations l10n, {
    required String label,
    required String identifier,
    required VoidCallback onClear,
  }) {
    return JeebFilterPill(
      label: label,
      identifier: identifier,
      clearIdentifier: '${identifier}_clear',
      clearSemanticLabel: l10n.filterPillClearA11yLabel(label),
      onTap: onOpenFilterSheet,
      onClear: onClear,
    );
  }
}
