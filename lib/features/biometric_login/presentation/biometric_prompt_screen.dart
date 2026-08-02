import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';
import '../application/biometric_cubit.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/biometric_prompt_screen_fixtures.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): superseded by biometric_auth/biometric_lock_cubit — see docs/project-understanding/reconciliation/orphans.md
class BiometricPromptScreen extends StatelessWidget {
  const BiometricPromptScreen({super.key, this.cubit});

  /// Catalog/test seam: inject a pre-built cubit (e.g. seeded into a specific
  /// state) instead of the self-constructed one. Defaults to null — production
  /// behavior (construct + `checkAvailability()`) is unchanged.
  final BiometricCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<BiometricCubit>.value(
        value: provided,
        child: const _BiometricPromptScaffold(),
      );
    }
    return BlocProvider(
      create: (_) => BiometricCubit()..checkAvailability(),
      child: const _BiometricPromptScaffold(),
    );
  }
}

class _BiometricPromptScaffold extends StatelessWidget {
  const _BiometricPromptScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BiometricCubit, BiometricState>(
      builder: (context, state) {
        return Semantics(
          identifier: 'biometric_prompt_root',
          container: true,
          child: Scaffold(
          body: SafeArea(
            child: Center(
              child: _PromptColumn(state: state),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _PromptColumn extends StatelessWidget {
  const _PromptColumn({required this.state});
  final BiometricState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _PromptHeader(),
        const SizedBox(height: Spacing.fourXLarge),
        _PromptAction(state: state),
      ],
    );
  }
}

class _PromptHeader extends StatelessWidget {
  const _PromptHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.fingerprint,
          size: Sizes.eightXLarge,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Spacing.xLarge),
        Text(
          AppLocalizations.of(context).useBiometrics,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: Spacing.small),
        Text(
          'Sign in quickly with your fingerprint or face',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PromptAction extends StatelessWidget {
  const _PromptAction({required this.state});
  final BiometricState state;

  @override
  Widget build(BuildContext context) {
    if (state == BiometricState.available) {
      return Semantics(
        identifier: 'biometric_prompt_authenticate_cta',
        button: true,
        container: true,
        child: OmdsPrimaryButton(
        text: 'Authenticate',
        icon: const Icon(Icons.fingerprint),
        onTap: () => context.read<BiometricCubit>().authenticate(),
      ),
      );
    }
    if (state == BiometricState.checking) {
      return const OmdsLoadingState();
    }
    if (state == BiometricState.unavailable) {
      return Text(AppLocalizations.of(context).biometricNotAvailable);
    }
    return const SizedBox.shrink();
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/biometric_login/biometric_prompt_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so two things differ from a widget preview.
//
// 1. It owns its own `Scaffold` and [jeebPreviewHost] wraps every child in one
//    as well, so the canvas shows two nested Scaffolds. The inner one is the
//    real surface; the outer contributes only a background. The canvas box is
//    therefore a real device ([_biometricPromptScreenPhoneBox], 390x844)
//    rather than the harness's default 390x200 — an 80 pt icon over a
//    vertically centred column cannot be judged in a 200 pt strip.
//
// 2. Every state is pinned by a CAPTION ([BiometricPromptScreenCaptions], the
//    same device as `OtpVerificationScreenCaptions`) rather than by screen
//    copy, because for HALF the states there is no copy to pin. `_PromptAction`
//    branches on three of `BiometricState`'s six values and returns
//    `SizedBox.shrink()` for the other three, so `initial`, `failed` and
//    `authenticated` are pixel-identical: the same fingerprint, the same
//    heading, the same subtitle, and nothing underneath. The render test
//    asserts the real state behind each caption — which branch built, whether
//    the CTA is mounted, whether a spinner is up — so the caption can never be
//    the whole proof.
//
// State is driven through the screen's existing `cubit:` seam, with the seeded
// cubits shared verbatim with the Screen Catalog entry
// (`lib/devtool/catalog/fixtures/biometric_prompt_screen_fixtures.dart`).
// `BiometricCubit` takes no repository and resolves nothing out of GetIt, so
// these previews are network-free by construction rather than by the guard in
// [jeebPreviewHost].
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * HALF the screen is hardcoded English. `_PromptHeader`'s subtitle
//    ('Sign in quickly with your fingerprint or face') and `_PromptAction`'s
//    CTA label ('Authenticate') are string literals, while the heading above
//    them is `l10n.useBiometrics`. The AR card therefore renders an Arabic
//    heading over an English sentence over an English button. There is no ARB
//    key for either string in `app_en.arb` or `app_ar.arb`.
//  * `BiometricState.failed` renders NOTHING. A user whose fingerprint was
//    rejected gets the same invitation to authenticate they started from, with
//    the button removed and no error, no retry and no password fallback — a
//    dead end reachable by one wrong finger.
//  * `BiometricState.authenticated` renders nothing either, and the screen has
//    no `BlocListener` and no `onAuthenticated` callback, so a SUCCESSFUL
//    sign-in also leaves the user on a static prompt. Both terminal states of
//    `authenticate()` are invisible.
//  * the `Checking` state is unreachable in production. `checkAvailability()`
//    is `emit(checking); emit(available);` with nothing awaited between them,
//    so no frame is ever built on the spinner. It is previewed anyway because
//    it IS what the screen would show if the stub were replaced by a real
//    `local_auth` round-trip, which is what the file's own comments promise.
//  * the column does not scroll, and at the accessibility ceiling it does not
//    fit. `_PromptColumn` is a bare centred `Column` inside `Center` inside
//    `SafeArea` with no scroll view above it, so at 200% text on a 320 x 568
//    display the composition overflows by 260 px and the
//    `biometricNotAvailable` sentence is clipped off the bottom of the device
//    — see `Unavailable · compact at 200% text`, which asserts it.
//
// Note the ORPHAN marker above the class: JEBV4-227 records this screen as
// superseded by `biometric_auth/BiometricLockScreen`. The previews are here
// because the Screen Catalog still ships it and the coverage ratchet counts it;
// they are not an argument for keeping it.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _biometricPromptScreenPhoneBox = Size(390, 844);

/// The smallest display the app still has to look right on (iPhone SE 1st gen
/// class), used for the accessibility-ceiling card.
const Size _biometricPromptScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see note 2 in the section prose. Dev chrome, never shipped copy, so
/// they are deliberately un-localized and rendered LTR at a fixed text scale.
final class BiometricPromptScreenCaptions {
  BiometricPromptScreenCaptions._();

  /// Mounted, probe not yet run.
  static const String initial = 'preview · initial · probe has not run';

  /// The availability probe is in flight.
  static const String checking = 'preview · checking · probe in flight';

  /// Hardware present and enrolled.
  static const String available = 'preview · available · the only state with '
      'a button';

  /// No hardware, or nothing enrolled.
  static const String unavailable = 'preview · unavailable · nothing enrolled';

  /// The OS prompt rejected the user.
  static const String failed = 'preview · failed · no error, no retry';

  /// The OS prompt accepted the user.
  static const String authenticated = 'preview · authenticated · nothing '
      'happens';

  /// The accessibility ceiling on the smallest supported display.
  static const String compactLargeText = 'preview · unavailable · 320x568 · '
      '200% text';
}

/// Hosts [BiometricPromptScreen] on one seeded cubit, under a caption.
///
/// Stateful so the cubit is built ONCE per mount. The screen mounts what it is
/// given with `BlocProvider<BiometricCubit>.value`, which does not close it, so
/// ownership stays here: build in [initState], close in [dispose]. A cubit
/// built inline in `build` would be replaced on every rebuild of the canvas.
///
/// Pass [window] to pin a simulated display. It is pinned by the FIXTURE rather
/// than left to the canvas `size:` because the render tests pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test, and the one card that exists to show
/// clipping would silently stop clipping.
class _BiometricPromptScreenHost extends StatefulWidget {
  const _BiometricPromptScreenHost({
    required this.createCubit,
    required this.caption,
    super.key,
    this.window,
    this.textScale,
  });

  final BiometricCubit Function() createCubit;

  /// The line painted above the screen — see note 2 in the prose.
  final String caption;

  /// Logical size of the simulated display, or `null` to use the real one.
  final Size? window;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing: `JeebPreview(matrix: true)` renders a card at
  /// `textScaleFactor: 2.0`, and a host that pinned 1.0 would silently
  /// overwrite it and show a 100% rendering under a "200% text" label.
  final double? textScale;

  @override
  State<_BiometricPromptScreenHost> createState() =>
      _BiometricPromptScreenHostState();
}

class _BiometricPromptScreenHostState
    extends State<_BiometricPromptScreenHost> {
  late final BiometricCubit _cubit = widget.createCubit();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Widget _caption(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.small,
          vertical: Spacing.xSmall,
        ),
        child: Text(
          widget.caption,
          // Dev chrome: LTR and unscaled, so the AR card still reads it as one
          // latin line and the 200% card does not spend a third of the device
          // on a label.
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget screen = BiometricPromptScreen(cubit: _cubit);
    final Size? window = widget.window;

    if (window == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _caption(theme),
          Expanded(child: screen),
        ],
      );
    }

    // Unbound on both axes. The render tests pump onto 800 x 600; an `Align` +
    // `SizedBox` would pass the host's constraints down and the frame would be
    // silently clamped, which is exactly the measurement the clipping
    // assertions depend on not being faked.
    return Material(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _caption(theme),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: window,
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                    // Null leaves the ambient scaler alone — see the field doc.
                    textScaler: widget.textScale == null
                        ? null
                        : TextScaler.linear(widget.textScale!),
                  ),
                  child: SizedBox.fromSize(size: window, child: screen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _biometricPromptScreenHosted(
  BiometricCubit Function() createCubit,
  String caption, {
  Size? window,
  double? textScale,
}) =>
    _BiometricPromptScreenHost(
      // Keyed by caption so two previews pumped back to back in the same test
      // cannot reuse each other's element — and therefore each other's seeded
      // cubit, which is built once per mount.
      key: ValueKey<String>(caption),
      createCubit: createCubit,
      caption: caption,
      window: window,
      textScale: textScale,
    );

/// Cold start: the widget is mounted and `checkAvailability()` has not run.
///
/// This is the screen's EMPTY state and the first of three that render the
/// header and nothing else — `_PromptAction` has no `initial` branch, so it
/// falls through to `SizedBox.shrink()`. On a real device it lasts one frame;
/// it is worth a card because it is also what the screen shows FOREVER if the
/// probe is never started (anyone constructing `BiometricPromptScreen(cubit:)`
/// without seeding it, which is the seam the catalog and these previews use).
@JeebPreview(
  group: 'biometric_login',
  name: 'Initial · before the probe',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenInitial() => _biometricPromptScreenHosted(
      biometricPromptScreenInitialCubit,
      BiometricPromptScreenCaptions.initial,
    );

/// The LOADING state: an indeterminate `OmdsLoadingState` where the CTA goes.
///
/// Unreachable in production today. `checkAvailability()` emits `checking` and
/// `available` back to back with no `await` between them, so the framework
/// never builds a frame on this state — it exists for the `local_auth` call the
/// stub's own comment promises. Note that nothing labels the spinner: there is
/// no "Checking your device…" copy, localized or otherwise.
@JeebPreview(
  group: 'biometric_login',
  name: 'Checking · probe in flight',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenChecking() => _biometricPromptScreenHosted(
      biometricPromptScreenCheckingCubit,
      BiometricPromptScreenCaptions.checking,
    );

/// The happy path, and the ONLY state in which this screen has an affordance.
///
/// Matrixed because this card is where the localization gap is visible in one
/// glance: the AR RTL rendering puts `l10n.useBiometrics` ("استخدام القياسات
/// الحيوية") directly above the hardcoded English 'Sign in quickly with your
/// fingerprint or face' and a button labelled 'Authenticate'. The EN 200% card
/// is the other half — the 80 pt fingerprint does NOT scale with text while
/// everything under it does, so the composition's proportions invert.
@JeebPreview(
  group: 'biometric_login',
  name: 'Available · authenticate CTA',
  size: _biometricPromptScreenPhoneBox,
  matrix: true,
)
Widget biometricPromptScreenAvailable() => _biometricPromptScreenHosted(
      biometricPromptScreenAvailableCubit,
      BiometricPromptScreenCaptions.available,
    );

/// The ERROR state: no biometric hardware, or nothing enrolled.
///
/// The only state that swaps in copy of its own, and the only one that is fully
/// localized (`l10n.biometricNotAvailable`). It is a bare `Text` — no icon, no
/// error styling, and no route onward — so the screen still invites the user to
/// "sign in quickly with your fingerprint" immediately above the sentence
/// saying they cannot.
@JeebPreview(
  group: 'biometric_login',
  name: 'Unavailable · nothing enrolled',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenUnavailable() => _biometricPromptScreenHosted(
      biometricPromptScreenUnavailableCubit,
      BiometricPromptScreenCaptions.unavailable,
    );

/// Rejected by the OS prompt — and the screen says nothing at all.
///
/// `_PromptAction` has no `failed` branch, so the CTA is simply gone and
/// nothing replaces it: no error copy, no "Try again", no password fallback.
/// Read this card next to `Available · authenticate CTA` and
/// `Authenticated · success is invisible`: one wrong finger removes the only
/// control on the screen, permanently, because nothing can emit `available`
/// again.
@JeebPreview(
  group: 'biometric_login',
  name: 'Failed · no error, no retry',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenFailed() => _biometricPromptScreenHosted(
      biometricPromptScreenFailedCubit,
      BiometricPromptScreenCaptions.failed,
    );

/// The user authenticated successfully — and the screen is indistinguishable
/// from the failure above.
///
/// `authenticate()` ends here, and the screen has no `BlocListener`, no
/// `onAuthenticated` callback and no navigation, so both outcomes of tapping
/// the CTA produce the same picture: header, no button, no feedback. This card
/// exists to make that equivalence impossible to miss.
@JeebPreview(
  group: 'biometric_login',
  name: 'Authenticated · success is invisible',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenAuthenticated() => _biometricPromptScreenHosted(
      biometricPromptScreenAuthenticatedCubit,
      BiometricPromptScreenCaptions.authenticated,
    );

/// The longest content this screen can hold, in the smallest window it
/// supports: the unavailable sentence at 200% text on a 320 x 568 display.
///
/// **This card overflows, and that is the finding.** `_PromptColumn` is a
/// centred `Column` with no scroll view anywhere above it, so at the
/// accessibility ceiling on the smallest supported display it is clipped —
/// `A RenderFlex overflowed by 260 pixels on the bottom`, i.e. the
/// `biometricNotAvailable` sentence is painted off the device with no way to
/// reach it. `RenderFlex` clamps its leading space at zero, so the fingerprint
/// stays where it is and the message is what falls off.
///
/// The window is pinned by the fixture rather than by the canvas `size:` so the
/// render test measures the same box the canvas draws — see
/// [_BiometricPromptScreenHost]. The overflow is asserted in
/// `test/previews/biometric_login/biometric_prompt_screen_preview_test.dart`,
/// which means this stays a KNOWN state rather than a surprise: if the column
/// is ever given a scroll view, that test fails and this card is retired.
@JeebPreview(
  group: 'biometric_login',
  name: 'Unavailable · compact at 200% text',
  size: _biometricPromptScreenCompactBox,
)
Widget biometricPromptScreenCompactLargeText() => _biometricPromptScreenHosted(
      biometricPromptScreenUnavailableCubit,
      BiometricPromptScreenCaptions.compactLargeText,
      window: _biometricPromptScreenCompactBox,
      textScale: 2,
    );
