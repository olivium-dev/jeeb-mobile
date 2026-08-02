// Shared dev-only fixtures for `OnboardingScreen` — the three-slide

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';

import 'language_settings_screen_fixtures.dart';

/// The key [LocaleCubit] persists the user's choice under.
/// Private to the cubit, so it is repeated here rather than imported — the same
const String _kOnboardingScreenLocalePrefKey = 'app.locale.languageCode';

/// An in-memory stand-in for [SharedPreferences].
/// Deliberately an alias rather than a fourth hand-written copy of the same
/// eighty-line map wrapper (`biometric_lock`, `language_settings` and
typedef OnboardingScreenInMemoryPrefs = LanguageSettingsScreenInMemoryPrefs;

/// The pair of cubits `OnboardingScreen` is seated on.
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
/// Takes the AMBIENT locale — the one the surrounding `MaterialApp` is already
/// rendering in — so a fixture can either follow it (the coherent reading, and
typedef OnboardingScreenCubitFactory = OnboardingScreenCubits Function(
  Locale ambient,
);

/// The designed states both dev surfaces render, as cubit factories.
/// Every one of these is a static tear-off rather than a closure factory, on
abstract final class OnboardingScreenPreviewFixtures {
  /// Nothing persisted, and the device reports the locale the card is already
  /// rendering in — the coherent reading, and the one the shipped app produces
  static OnboardingScreenCubits followsAmbient(Locale ambient) =>
      _cubits(device: ambient);

  /// The Screen Catalog's "Slides — EN": the cubit is pinned to English
  /// whatever the surrounding app is rendering in.
  static OnboardingScreenCubits english(Locale _) =>
      _cubits(device: const Locale('en'));

  /// The Screen Catalog's "Slides — AR": the cubit is pinned to Arabic.
  /// Reached two ways in the wild and identical either way — a first launch on
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
/// Supplies the two ambient cubits, optionally pins a device frame, and
/// optionally parks the carousel on a later slide.
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
  /// See [_OnboardingScreenSlideDriver] for why this is a post-frame jump and
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
    final Locale ambient =
        Localizations.maybeLocaleOf(context) ?? const Locale('en');
    if (_cubits != null &&
        _seededFrom == ambient &&
        _seededBy == widget.create) {
      return;
    }
    // Rebuilt rather than reused: a card re-rendered in the other locale must
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
/// `OnboardingScreen` builds its own `PageController` in a field
/// (`final _pageController = PageController()`) and exposes no `initialPage`
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
