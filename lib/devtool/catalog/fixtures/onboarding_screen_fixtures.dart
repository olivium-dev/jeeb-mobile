// Shared dev-only fixtures for `OnboardingScreen` — the three-slide
// first-launch walkthrough (JM-010 / FR-P1-1 / FR-P1-2).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_08_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/onboarding/presentation/onboarding_screen.dart`.
//
// The screen has no repository, no cubit constructor seam and nothing async of
// its own. It needs exactly two ambient cubits, for two different reasons:
//
//   * [LocaleCubit] is read on EVERY build (`_LanguageToggle` calls
//     `context.watch<LocaleCubit>()`), so a bare `OnboardingScreen` throws.
//     Which locale it resolved to is the only thing that varies between the
//     designed states.
//   * [OnboardingCubit] is read only from a GESTURE (`_completeAndNavigate`),
//     so it is not needed to render — but Skip and Get Started are live in
//     both dev surfaces and both call `complete()`, which WRITES.
//
// Three deliberate changes came with the extraction from the catalog entry.
//
//  * **The prefs are in-memory.** The entry built both cubits over the real
//    `SharedPreferences.getInstance()` — the device's actual prefs, on the
//    device the catalog is running on. Two consequences, both fixed here:
//
//      1. Browsing the catalog MUTATED the app. `OnboardingCubit.complete()`
//         persists `app.onboarding.completed = true`, so tapping Skip once
//         inside the catalog permanently suppressed the real walkthrough; and
//         `LocaleCubit.setLocale` persists `app.locale.languageCode`, so
//         tapping the العربية chip changed the whole app's language on the next
//         cold start. Both writes now land in a map that dies with the card.
//      2. It was not deterministic. `LocaleCubit._resolveInitial` reads the
//         persisted key BEFORE it consults `deviceLocaleProvider`, so on a
//         device where the tester had ever picked a language, the entry's
//         `locale:` argument was ignored and both states rendered the same
//         chip. Nothing here reads the device's prefs, so the fixture decides.
//
//  * **Construction is synchronous.** `SharedPreferences.getInstance()` is a
//    `Future`, which forced the entry into an async seam that rendered
//    `SizedBox.shrink()` for a frame. A preview cannot have that seam at all —
//    a preview is a synchronous `Widget Function()` — so the in-memory
//    stand-in is what makes this screen previewable, and it removes the blank
//    first frame from the catalog as a side effect.
//
//  * **The host owns the cubits' lifetime.** The entry closed them from
//    `dispose`; [OnboardingScreenPreviewHost] does the same, and additionally
//    rebuilds them when the ambient locale changes so a card re-rendered in the
//    other locale is not left seated on the first one's cubit.
//
// Nothing here can reach the network or the DI graph: a [LocaleCubit] with no
// `LanguagePreferenceRepository` never makes a call, [OnboardingCubit] only
// ever touches prefs, and the prefs are a map. `CatalogNetworkGuard` is the net
// under both surfaces, not the plan.
//
// NOT deterministic even here, and not fixable from a fixture:
// `_resolveInitial` consults `DevSeam.current.forcedLocale` first in DEBUG
// builds, so a `--dart-define=JEEB_FORCE_LOCALE=ar` collapses every state below
// onto that one locale in both dev surfaces. `flutter test` sets neither, so
// the render tests are unaffected.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';

import 'language_settings_screen_fixtures.dart';

/// The key [LocaleCubit] persists the user's choice under.
///
/// Private to the cubit, so it is repeated here rather than imported — the same
/// literal `test/onboarding_screen_test.dart` asserts against.
const String _kOnboardingScreenLocalePrefKey = 'app.locale.languageCode';

/// An in-memory stand-in for [SharedPreferences].
///
/// Deliberately an alias rather than a fourth hand-written copy of the same
/// eighty-line map wrapper (`biometric_lock`, `language_settings` and
/// `settings` each declare one). Same contract: construction is synchronous, so
/// a `Widget Function()` preview can have it, and every write is a map write
/// that dies with the card.
typedef OnboardingScreenInMemoryPrefs = LanguageSettingsScreenInMemoryPrefs;

/// The pair of cubits `OnboardingScreen` is seated on.
///
/// They share ONE prefs instance, the way the app does — `OnboardingCubit` and
/// `LocaleCubit` write different keys into the same store.
class OnboardingScreenCubits {
  OnboardingScreenCubits({required this.onboarding, required this.locale});

  final OnboardingCubit onboarding;
  final LocaleCubit locale;

  /// Closes both. Called from [OnboardingScreenPreviewHost.dispose]; whoever
  /// builds a pair outside that host owns this.
  Future<void> close() async {
    await onboarding.close();
    await locale.close();
  }
}

/// Builds the cubits one designed state is seated on.
///
/// Takes the AMBIENT locale — the one the surrounding `MaterialApp` is already
/// rendering in — so a fixture can either follow it (the coherent reading, and
/// the only one the shipped app can produce) or deliberately ignore it.
typedef OnboardingScreenCubitFactory = OnboardingScreenCubits Function(
  Locale ambient,
);

/// The designed states both dev surfaces render, as cubit factories.
///
/// Every one of these is a static tear-off rather than a closure factory, on
/// purpose: [OnboardingScreenPreviewHost] keys its cubits on the factory's
/// identity, and a `pinned(const Locale('ar'))`-style closure would be a new
/// object on every build.
abstract final class OnboardingScreenPreviewFixtures {
  /// Nothing persisted, and the device reports the locale the card is already
  /// rendering in — the coherent reading, and the one the shipped app produces
  /// (`app.dart` binds `MaterialApp.locale` to this same cubit, so the selected
  /// chip and the slide copy can never disagree there).
  static OnboardingScreenCubits followsAmbient(Locale ambient) =>
      _cubits(device: ambient);

  /// The Screen Catalog's "Slides — EN": the cubit is pinned to English
  /// whatever the surrounding app is rendering in.
  static OnboardingScreenCubits english(Locale _) =>
      _cubits(device: const Locale('en'));

  /// The Screen Catalog's "Slides — AR": the cubit is pinned to Arabic.
  ///
  /// Reached two ways in the wild and identical either way — a first launch on
  /// an Arabic phone (device locale) or a returning user who tapped العربية
  /// (persisted key). Seeded through the PERSISTED key here, because that is
  /// the arm `_resolveInitial` reads first and therefore the one that cannot be
  /// perturbed by the device the catalog is running on.
  static OnboardingScreenCubits arabic(Locale _) =>
      _cubits(saved: 'ar', device: const Locale('ar'));

  static OnboardingScreenCubits _cubits({
    required Locale device,
    String? saved,
    bool completed = false,
  }) {
    final SharedPreferences prefs =
        OnboardingScreenInMemoryPrefs(<String, Object>{
      _kOnboardingScreenLocalePrefKey: ?saved,
      if (completed) OnboardingCubit.completedKey: true,
    });
    return OnboardingScreenCubits(
      onboarding: OnboardingCubit(prefs: prefs),
      locale: LocaleCubit(prefs: prefs, deviceLocaleProvider: () => device),
    );
  }
}

/// Seats a previewed [child] the way the app seats it, minus the app.
///
/// Supplies the two ambient cubits, optionally pins a device frame, and
/// optionally parks the carousel on a later slide.
///
/// [child] is taken rather than built here so the CALLER constructs the screen:
/// `tool/preview_coverage.dart` counts a screen as covered only when its own
/// preview section literally constructs it.
class OnboardingScreenPreviewHost extends StatefulWidget {
  const OnboardingScreenPreviewHost({
    super.key,
    required this.create,
    required this.child,
    this.box,
    this.slide = 0,
  });

  /// Builds the cubits under review, given the ambient locale.
  final OnboardingScreenCubitFactory create;

  /// The surface under the cubits — `OnboardingScreen(onComplete: …)` at both
  /// call sites.
  final Widget child;

  /// Device frame to pin, or `null` to take whatever the host offers (the
  /// Screen Catalog runs full-bleed inside the device it is already on).
  final Size? box;

  /// Zero-based slide to park the carousel on after the first frame.
  ///
  /// See [_OnboardingScreenSlideDriver] for why this is a post-frame jump and
  /// not a constructor argument.
  final int slide;

  @override
  State<OnboardingScreenPreviewHost> createState() =>
      _OnboardingScreenPreviewHostState();
}

class _OnboardingScreenPreviewHostState
    extends State<OnboardingScreenPreviewHost> {
  OnboardingScreenCubits? _cubits;
  Locale? _seededFrom;
  OnboardingScreenCubitFactory? _seededBy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read the ambient locale HERE, in the element's own dependency phase: a
    // `Localizations.maybeLocaleOf` inside a `BlocProvider.create` callback
    // would register an inherited dependency in a callback that never runs
    // again, which `provider` rejects outright.
    final Locale ambient =
        Localizations.maybeLocaleOf(context) ?? const Locale('en');
    if (_cubits != null &&
        _seededFrom == ambient &&
        _seededBy == widget.create) {
      return;
    }
    // Rebuilt rather than reused: a card re-rendered in the other locale must
    // not keep the cubit seeded from the first one, or a render test pumping
    // two fixtures into the same tree position would go on showing the first
    // one's state under the second one's name.
    _closeCubits();
    _seededFrom = ambient;
    _seededBy = widget.create;
    _cubits = widget.create(ambient);
  }

  @override
  void dispose() {
    _closeCubits();
    super.dispose();
  }

  /// Closes the seated pair, if any, without blocking the lifecycle callback
  /// that asked for it.
  void _closeCubits() {
    final OnboardingScreenCubits? seated = _cubits;
    _cubits = null;
    if (seated != null) unawaited(seated.close());
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingScreenCubits cubits = _cubits!;
    final Widget seated = MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<OnboardingCubit>.value(value: cubits.onboarding),
        BlocProvider<LocaleCubit>.value(value: cubits.locale),
      ],
      child: _OnboardingScreenSlideDriver(
        slide: widget.slide,
        child: widget.child,
      ),
    );
    final Size? frame = widget.box;
    if (frame == null) return seated;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: frame.width, height: frame.height, child: seated),
    );
  }
}

/// Parks the walkthrough carousel on a later slide, after the first frame.
///
/// `OnboardingScreen` builds its own `PageController` in a field
/// (`final _pageController = PageController()`) and exposes no `initialPage`
/// seam, so "show me slide 3" is not expressible as a constructor argument and
/// adding one would be a production edit made for a dev surface. What IS
/// reachable without touching the screen: the `PageView` it builds is a
/// descendant of this widget, `PageView.controller` is public, and a
/// `jumpToPage` drives the same `onPageChanged` a swipe does — so the slide the
/// screen renders is reached through the screen's own state machine rather than
/// faked around it.
///
/// Deliberately guarded and silent: with no clients (nothing laid out yet) it
/// leaves the carousel on slide 1 rather than throwing, because a preview that
/// crashes the canvas is worse than one that shows the wrong slide — and the
/// render tests assert the slide, so a jump that stops working fails there.
class _OnboardingScreenSlideDriver extends StatefulWidget {
  const _OnboardingScreenSlideDriver({
    required this.slide,
    required this.child,
  });

  final int slide;
  final Widget child;

  @override
  State<_OnboardingScreenSlideDriver> createState() =>
      _OnboardingScreenSlideDriverState();
}

class _OnboardingScreenSlideDriverState
    extends State<_OnboardingScreenSlideDriver> {
  @override
  void initState() {
    super.initState();
    if (widget.slide == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jump());
  }

  void _jump() {
    if (!mounted) return;
    final PageController? pager = _pagerBelow(context);
    if (pager == null || !pager.hasClients) return;
    pager.jumpToPage(widget.slide);
  }

  /// First [PageView] in this widget's subtree, or null.
  static PageController? _pagerBelow(BuildContext context) {
    PageController? found;
    void visit(Element element) {
      if (found != null) return;
      final Widget candidate = element.widget;
      if (candidate is PageView) {
        found = candidate.controller;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
