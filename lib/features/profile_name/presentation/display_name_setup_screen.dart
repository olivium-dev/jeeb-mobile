import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../application/display_name_cubit.dart';
import '../data/dio_display_name_repository.dart';
import '../domain/display_name_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/display_name_setup_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

/// Post-OTP display-name onboarding: optional-but-encouraged, skip always available.
class DisplayNameSetupScreen extends StatefulWidget {
  const DisplayNameSetupScreen({
    super.key,
    required this.onDone,
    this.repository,
    this.refreshSignals,
    this.cubit,
  });

  /// Called exactly once when step resolves (save or skip).
  final VoidCallback onDone;

  /// Test seam: scripted repository; null uses DI or fixture mode.
  final DisplayNameRepository? repository;

  /// Test seam: profile-changed broadcast; production uses DI singleton.
  final ProfileRefreshSignals? refreshSignals;

  /// Catalog/test seam: pre-constructed cubit; null builds one from seams.
  final DisplayNameCubit? cubit;

  @override
  State<DisplayNameSetupScreen> createState() => _DisplayNameSetupScreenState();
}

class _DisplayNameSetupScreenState extends State<DisplayNameSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  DisplayNameRepository? _resolveRepository() {
    if (widget.repository != null) return widget.repository;
    if (sl.isRegistered<Dio>()) return DioDisplayNameRepository(sl<Dio>());
    return null;
  }

  ProfileRefreshSignals? _resolveSignals() {
    if (widget.refreshSignals != null) return widget.refreshSignals;
    if (sl.isRegistered<ProfileRefreshSignals>()) {
      return sl<ProfileRefreshSignals>();
    }
    return null;
  }

  /// Resolves exactly once to prevent double-tap or race conditions.
  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _onStateChange(BuildContext context, DisplayNameState state) {
    switch (state.status) {
      case DisplayNameStatus.saved:
        _finish();
      case DisplayNameStatus.failure:
        _showSaveError(context);
      case DisplayNameStatus.idle:
      case DisplayNameStatus.saving:
        break;
    }
  }

  void _showSaveError(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profileNameStepError)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = BlocConsumer<DisplayNameCubit, DisplayNameState>(
      listener: _onStateChange,
      builder: (context, state) => _buildScaffold(context, state),
    );
    final injected = widget.cubit;
    if (injected != null) {
      return BlocProvider<DisplayNameCubit>.value(value: injected, child: child);
    }
    return BlocProvider<DisplayNameCubit>(
      create: (_) => DisplayNameCubit(
        repository: _resolveRepository(),
        refreshSignals: _resolveSignals(),
      ),
      child: child,
    );
  }

  Widget _buildScaffold(BuildContext context, DisplayNameState state) {
    return Semantics(
      identifier: 'profile_name_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(Spacing.medium),
            child: _NameStepBody(
              controller: _nameController,
              state: state,
              onSkip: _finish,
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading + subtitle + name field + buttons, start-aligned for RTL.
class _NameStepBody extends StatelessWidget {
  const _NameStepBody({
    required this.controller,
    required this.state,
    required this.onSkip,
  });

  final TextEditingController controller;
  final DisplayNameState state;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.xLarge),
        Text(
          l10n.profileNameStepTitle,
          key: const Key('profile-name.title'),
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.profileNameStepSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Spacing.xLarge),
        _NameField(controller: controller, enabled: !state.isSaving),
        const SizedBox(height: Spacing.xLarge),
        _SubmitButton(controller: controller, state: state),
        const SizedBox(height: Spacing.small),
        _SkipButton(enabled: !state.isSaving, onSkip: onSkip),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'profile_name_input',
      container: true,
      child: OmdsTextField(
        key: const Key('profile-name.field'),
        controller: controller,
        enabled: enabled,
        labelText: l10n.profileNameLabel,
        hintText: l10n.profileNameHint,
        textCapitalization: TextCapitalization.words,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.controller, required this.state});

  final TextEditingController controller;
  final DisplayNameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Rebuild enablement as user types; controller is source of truth.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return Semantics(
          identifier: 'profile_name_submit_cta',
          button: true,
          container: true,
          child: OmdsLoadingButton(
            key: const Key('profile-name.submit'),
            text: l10n.profileNameStepCta,
            isLoading: state.isSaving,
            isEnabled: hasText && !state.isSaving,
            onTap: () =>
                context.read<DisplayNameCubit>().submit(controller.text),
          ),
        );
      },
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.enabled, required this.onSkip});

  final bool enabled;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'profile_name_skip_cta',
      button: true,
      container: true,
      child: OmdsPrimaryButton(
        key: const Key('profile-name.skip'),
        text: l10n.profileNameStepSkip,
        variant: OmdsButtonVariant.text,
        isEnabled: enabled,
        onTap: onSkip,
      ),
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
// Render tests: test/previews/profile_name/display_name_setup_screen_preview_test.dart
// ===========================================================================
//
// [DisplayNameSetupScreen] is the post-OTP "what should we call you?" step.
// Its whole data axis is one enum — [DisplayNameStatus] — so every card below
// is one status, reached the way the Screen Catalog reaches it.
//
// The repositories and the driven cubits are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/display_name_setup_screen_fixtures.dart`,
// shared with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_09_entries.dart`), so the designer's browser
// and this canvas cannot drift into showing two different "Saving". Nothing
// there can reach the network or the DI graph: every repository is a local
// `implements DisplayNameRepository` with no transport, and a cubit passed
// through the `cubit:` seam short-circuits `_resolveRepository()` before it
// ever asks `sl` for a [Dio]. The guard in [jeebPreviewHost] is the net here,
// not the plan.
//
// Four things about this harness before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + SafeArea + SingleChildScrollView` paints inside
//    it. Same nesting the Screen Catalog produces, and it is harmless here —
//    the render test pins two [Scaffold]s and exactly ONE error snackbar, so
//    the failure card is an honest rendering rather than a doubled one.
//  * **The device frame is pinned in the TREE, not just in `size:`.** `size:`
//    boxes the canvas only; calling a preview function from a render test gets
//    the tester's 800x600 desktop surface, and this screen's copy reflows at
//    every width.
//  * **The `saving` card mutes its ticker.** `OmdsLoadingButton` swaps in an
//    `OmdsButtonLoading` → [CircularProgressIndicator], which never stops
//    scheduling frames, and the render tests' `pumpAndSettle` would hang on it.
//    [TickerMode] still paints the arc — it just stops it spinning, which is
//    what a static canvas wanted anyway.
//  * **Each card carries a caption** ([DisplayNameSetupScreenCaptions]). Three
//    of the five states below put the SAME six strings on screen — the title,
//    the subtitle, the field label and hint, "Continue" and "Skip for now" —
//    and differ only in which widgets are enabled and in how the cubit got
//    where it is. Without a caption a render test cannot tell them apart, and
//    neither can a reviewer. Dev chrome, never shipped copy, so it is
//    deliberately un-localized, LTR and unscaled.
//
// What these previews surfaced in the screen — none of it changed here:
//
//  * **There is no seam for the NAME, so the enabled-CTA state cannot be
//    rendered by any dev surface.** `_DisplayNameSetupScreenState` owns its
//    [TextEditingController] privately and constructs it empty; the widget
//    takes `repository`, `refreshSignals` and `cubit` and nothing else. Since
//    `_SubmitButton` gates on `controller.text` rather than on cubit state, the
//    "valid name typed, Continue live" reading — the one frame every user
//    passes through — is reachable only from a widget test that types into the
//    field. Both the catalog and this canvas show a permanently disabled CTA.
//    An `initialName` seam (or moving the draft into [DisplayNameCubit]) is
//    what would close it; adding one is a production edit and is deliberately
//    not done here.
//  * **`saved` has no rendering at all.** [DisplayNameStatus.saved] leaves
//    `isSaving` false, so the screen paints the idle form again and the only
//    feedback is the host navigating away. See
//    [displayNameSetupScreenSavedWithoutRepository] — that card is
//    pixel-identical to the idle card and the step is already resolved in it.
//  * **A missing repository reports success without sending anything.**
//    `_resolveRepository()` returns null when the `repository:` seam is null
//    and `Dio` is not registered, and [DisplayNameCubit.submit] then emits
//    `saved` with no transport. On any build where the DI graph has not
//    registered [Dio] by the time this step mounts, a user types their name,
//    sees the step resolve, and the name is silently dropped. The doc on the
//    `repository` field calls this "fixture mode"; nothing on screen does.
//  * **Failure is a transient snackbar and nothing else.**
//    [DisplayNameStatus.failure] changes no pixel of the form — no inline
//    error, no field highlight — and `_showSaveError` fires from
//    `BlocConsumer.listener`, which does not run for the state present at first
//    build. So the error copy is tied to a state TRANSITION: a `failure` that
//    is already current at mount renders a clean, untouched form. That is why
//    the failure card has to be driven by
//    [DisplayNameSetupScreenPreviewDriver] instead of seeded.
//  * **A hung PUT is a dead end.** While `isSaving` the field, the CTA and the
//    SKIP button are all disabled, and `DioDisplayNameRepository` sets no
//    timeout — so the "optional, never blocks registration" step becomes an
//    unexitable screen for exactly as long as the request hangs.
//    [displayNameSetupScreenSaving] is that screen; there is no cancel on it.

/// The phone this step is designed against.
const Size _displayNameSetupScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports (iPhone SE 1st gen and the small
/// Android estate) — and roughly what an Android multi-window split leaves a
/// foreground app.
const Size _displayNameSetupScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist: three of these five states put NO distinguishing production copy on
/// screen. Dev chrome, never shipped copy.
final class DisplayNameSetupScreenCaptions {
  DisplayNameSetupScreenCaptions._();

  /// The step as every user first meets it.
  static const String idle = 'preview · idle · nothing typed';

  /// `PUT /api/User/profile` in flight and never landing.
  static const String saving = 'preview · saving · PUT in flight, no exit';

  /// The PUT rejected; the step stays put.
  static const String failure = 'preview · failure · PUT rejected (fail-soft)';

  /// `saved` reached with no repository — the silent-drop branch.
  static const String savedWithoutRepository =
      'preview · saved · with NO repository (nothing was sent)';

  /// The layout ceiling: 320x568.
  static const String compactCeiling = 'preview · 320 x 568 ceiling';
}

/// Puts a dev caption above the device frame, so a card that is pixel-identical
/// to its neighbour still says which state it is.
class _DisplayNameSetupScreenCaptioned extends StatelessWidget {
  const _DisplayNameSetupScreenCaptioned({
    required this.caption,
    required this.child,
  });

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            caption,
            // Dev chrome: LTR and unscaled, so the AR card still reads it as
            // one latin line and the 200% card does not spend a third of the
            // device on a label.
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(child: child),
      ],
    );
  }
}

/// Seats [DisplayNameSetupScreen] on one fixture at a pinned device box.
///
/// Exactly one of [repository] / [cubit] is ever passed: `repository` is the
/// seam the screen builds its OWN cubit over (the only way to reach `idle`),
/// `cubit` is the seam that pre-drives a status the screen cannot otherwise be
/// put into from outside.
///
/// [submitAfterMount] wraps the screen in [DisplayNameSetupScreenPreviewDriver],
/// which fires `cubit.submit` one frame after mount. Only the failure card uses
/// it, and it has to: see that preview's doc.
///
/// `onDone` is a no-op. The step's two exits both call it — Skip immediately,
/// a successful save through the listener — and in a preview there is no host
/// to resolve to, so pressing Skip in the canvas leaves the card exactly where
/// it is. That is the honest rendering: the screen itself has no "done" state.
Widget _displayNameSetupScreenHosted({
  required String caption,
  DisplayNameRepository? repository,
  DisplayNameCubit? cubit,
  bool submitAfterMount = false,
  Size box = _displayNameSetupScreenPhoneBox,
  bool muteTicker = false,
}) {
  Widget screen = DisplayNameSetupScreen(
    onDone: () {},
    repository: repository,
    cubit: cubit,
  );
  if (submitAfterMount && cubit != null) {
    screen = DisplayNameSetupScreenPreviewDriver(cubit: cubit, child: screen);
  }
  return _DisplayNameSetupScreenCaptioned(
    caption: caption,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: box.width,
        height: box.height,
        child: muteTicker ? TickerMode(enabled: false, child: screen) : screen,
      ),
    ),
  );
}

/// The reference reading: the step as it is mounted after OTP, with an empty
/// field and nothing in flight.
///
/// Continue is rendered and DEAD — `_SubmitButton` gates on
/// `controller.text.trim().isNotEmpty`, so at 0.6 alpha it sits above a live
/// "Skip for now" that is the only button on the screen that does anything.
/// Read the AR card for the mirroring: every inset on the path is
/// [EdgeInsetsDirectional] and the heading, subtitle and field label all
/// start-align, so the whole column flips cleanly. The 200% card is where the
/// two-sentence subtitle stops being cheap — it is the longest string this
/// screen can paint, and the AR translation is longer still.
@JeebPreview(
  group: 'profile_name',
  name: 'Idle · nothing typed',
  size: _displayNameSetupScreenPhoneBox,
  matrix: true,
)
Widget displayNameSetupScreenIdle() => _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.idle,
      repository: DisplayNameSetupScreenPreviewFixtures.accepting,
    );

/// `PUT /api/User/profile` is in flight: the CTA swaps its label for a spinner
/// and the field, the CTA and Skip are all disabled.
///
/// The card to look at for the dead end. `DisplayNameStatus.saving` disables
/// the ONLY exit this "optional, never blocks registration" step has, and
/// `DioDisplayNameRepository` sets no send/receive timeout of its own — so a
/// request that hangs leaves the user on this frame with no cancel, no back and
/// no skip. The fixture's repository never resolves, which is the same frame,
/// held.
///
/// The ticker is muted so a static canvas (and `pumpAndSettle`) has something
/// to settle on; see the section prose.
@JeebPreview(
  group: 'profile_name',
  name: 'Saving · PUT in flight',
  size: _displayNameSetupScreenPhoneBox,
)
Widget displayNameSetupScreenSaving() => _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.saving,
      cubit: DisplayNameSetupScreenPreviewFixtures.saving(),
      muteTicker: true,
    );

/// The PUT was rejected: `profileNameStepError` in a snackbar, and the form
/// comes straight back — fail-soft, the step is never a hard block.
///
/// Everything except the snackbar is identical to the idle card, which is the
/// finding: `DisplayNameStatus.failure` has no persistent rendering. Nothing
/// marks the field, nothing marks the CTA, and once the snackbar's four seconds
/// are up the screen cannot tell a user who has never submitted from one whose
/// name has just been lost.
///
/// This card cannot be built by seeding a cubit. `_showSaveError` is raised
/// from `BlocConsumer.listener`, and a listener does not run for the state
/// present at first build — so a cubit already on `failure` when the screen
/// mounts renders a clean form and no snackbar at all. The PUT has to be fired
/// while the screen is already watching, which is what
/// [DisplayNameSetupScreenPreviewDriver] does from a post-frame callback. The
/// Screen Catalog used to fire it in the state builder and rely on the
/// rejection landing after the mount; that holds inside a synchronous `build()`
/// and loses the race under `WidgetTester.pumpWidget`.
@JeebPreview(
  group: 'profile_name',
  name: 'Error · PUT rejected',
  size: _displayNameSetupScreenPhoneBox,
)
Widget displayNameSetupScreenSaveFailed() => _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.failure,
      cubit: DisplayNameSetupScreenPreviewFixtures.rejecting(),
      submitAfterMount: true,
    );

/// `DisplayNameStatus.saved` — reached with **no repository at all**.
///
/// Two things at once, and they are the same pixel.
///
/// The status is terminal and the screen renders NOTHING for it: no
/// confirmation, no disabled form, no name echoed back. This card is
/// indistinguishable from [displayNameSetupScreenIdle] and the step is already
/// resolved in it.
///
/// And the way it got there is a live production branch, not a contrivance:
/// `_resolveRepository()` returns null when the `repository:` seam is null and
/// `Dio` is not registered in the DI graph, at which point
/// [DisplayNameCubit.submit] emits `saved` without sending anything. A user on
/// that build types their name, watches the step resolve, and the name is gone.
@JeebPreview(
  group: 'profile_name',
  name: 'Saved · no repository, nothing sent',
  size: _displayNameSetupScreenPhoneBox,
)
Widget displayNameSetupScreenSavedWithoutRepository() =>
    _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.savedWithoutRepository,
      cubit: DisplayNameSetupScreenPreviewFixtures.savedWithoutRepository(),
    );

/// Layout ceiling: the narrowest supported phone, 320x568.
///
/// The user data on this screen is a name that no seam can seed, so the ceiling
/// here is the localized chrome — and the two-sentence `profileNameStepSubtitle`
/// is the longest string the app paints on this step, longer again in Arabic.
/// The body is a [SingleChildScrollView], so growth is absorbed by scrolling
/// rather than overflowing; what the 200% card shows is how far down the fold
/// the two buttons go once the heading and the subtitle have taken their share
/// of 568 pt.
@JeebPreview(
  group: 'profile_name',
  name: 'Compact 320x568 · layout ceiling',
  size: _displayNameSetupScreenCompactBox,
  matrix: true,
)
Widget displayNameSetupScreenCompactCeiling() => _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.compactCeiling,
      repository: DisplayNameSetupScreenPreviewFixtures.accepting,
      box: _displayNameSetupScreenCompactBox,
    );
