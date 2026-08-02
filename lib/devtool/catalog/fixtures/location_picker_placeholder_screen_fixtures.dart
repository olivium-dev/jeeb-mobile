// Designed-state fixtures for the `LocationPickerScreen` PLACEHOLDER — the

import 'package:flutter/widgets.dart';

import '../../../features/location/presentation/screens/location_picker_screen.dart';

/// The one designed state of the `/location` placeholder, the boxes it is
/// reviewed in, and the captions that label those boxes.
class LocationPickerPlaceholderScreenFixtures {
  const LocationPickerPlaceholderScreenFixtures._();

  // ── Copy ────────────────────────────────────────────────────────────────

  /// The headline the placeholder renders.
  static const String title = 'Location Picker coming soon';

  /// The body copy under [title].
  static const String subtitle = 'This screen is not yet available.';

  /// The `Semantics.label` the screen wraps itself in.
  /// NOT what a screen reader announces. `container: true` over a subtree that
  static const String semanticsLabel =
      'Location Picker coming soon. This screen is not yet available.';

  // ── Boxes ───────────────────────────────────────────────────────────────

  /// The reference device: a 390x844 phone.
  /// 342 pt of usable width, so [title] stays on ONE line — the only box where
  static const Size phoneBox = Size(390, 844);

  /// The narrowest viewport the app supports (320x568), and the tight one.
  /// 272 pt of usable width once `OmdsEmptyState`'s `EdgeInsets.all(24)` is off
  static const Size compactBox = Size(320, 568);

  /// A 844x390 landscape / split-screen viewport — the SHORTEST one, and not
  /// the one that breaks.
  static const Size landscapeBox = Size(844, 390);

  // ── Captions ────────────────────────────────────────────────────────────

  /// The reference reading at [phoneBox].
  static const String captionPhone =
      'preview · what /location actually serves · 390x844';

  /// [compactBox] — the width floor.
  static const String captionCompact =
      'preview · narrowest supported device · 320x568';

  /// [landscapeBox] — the height ceiling.
  static const String captionLandscape =
      'preview · short viewport, nothing scrolls · 844x390';

  /// The placeholder pushed onto a route the user can pop back out of.
  static const String captionDeadEnd =
      'preview · pushed route · no back affordance is drawn';

  /// Stands in for the screen the user tapped through from, one route below the
  /// placeholder. Never asserted; it exists so the pushed card has something to
  static const String originRouteLabel =
      'preview · the screen the user came from';

  // ── The single designed state ───────────────────────────────────────────

  /// The one state, built the same way for every consumer.
  /// The preview section deliberately writes `const LocationPickerScreen()` out
  static Widget placeholder() => const LocationPickerScreen();
}
