// Designed-state fixtures for `SavedAddressesScreen` — the "Saved Addresses"
// row on the settings tab, restored as a placeholder under T-MOB-FIX-001.
//
// ONE source of truth, TWO consumers:
//
//   * `lib/devtool/catalog/entries/batch_10_entries.dart` — the on-device
//     Screen Catalog entry designers browse, and
//   * the `JEEB PREVIEWS` section at the bottom of
//     `lib/features/settings/presentation/screens/saved_addresses_screen.dart`
//     — the engineer's `flutter widget-preview start` loop.
//
// This is the degenerate case of that rule, and saying so is the point rather
// than an apology for a thin file. `SavedAddressesScreen` takes no parameters,
// owns no cubit and reads no repository: `build` returns a `const
// OmdsEmptyStatePage` with two literal English strings. There is no fake
// repository to extract and no seeded cubit, because there is nothing to seed
// — the screen has exactly ONE state, which is why the catalog entry has
// exactly one, `Placeholder`.
//
// What IS worth single-sourcing is the part both surfaces and the render test
// would otherwise re-type from the screen body: the copy, and the canvas boxes
// the placeholder is judged in. The copy literals below are a DELIBERATE
// duplicate of the screen's, not a shared constant the screen reads — the
// screen is shipping code that may not import `lib/devtool/`, and pinning its
// strings from outside is exactly what makes the render test able to notice
// when they change.
//
// Everything here is inert by construction: no Dio, no GetIt, no platform
// channel. The `CatalogNetworkGuard` both hosts install has nothing to catch.

import 'package:flutter/widgets.dart';

import '../../../features/settings/presentation/screens/saved_addresses_screen.dart';

/// The one designed state of `SavedAddressesScreen`, plus the boxes it is
/// reviewed in.
class SavedAddressesScreenFixtures {
  const SavedAddressesScreenFixtures._();

  /// Label for the single catalog state / preview. Shared so the designer's
  /// on-device state and the engineer's canvas card cannot end up named
  /// different things for the same screen.
  static const String placeholderLabel = 'Placeholder';

  /// The headline the placeholder renders.
  ///
  /// HARDCODED ENGLISH in the screen — `l10n.savedAddressesTitle` and
  /// `l10n.savedAddressesEmptyTitle` both exist in `app_en.arb` / `app_ar.arb`
  /// and `settings_screen.dart` already uses the first of them, but this screen
  /// does not. Pinned here so the AR preview / AR render test can assert that
  /// an Arabic build still shows this English string, rather than quietly
  /// looking like it passed.
  static const String title = 'Saved Addresses coming soon';

  /// The body copy under [title]. Also hardcoded English.
  static const String subtitle = 'This screen is not yet available.';

  /// The screen's `Semantics.label`, which concatenates [title] and [subtitle]
  /// into one announcement for a screen reader.
  static const String semanticsLabel =
      'Saved Addresses coming soon. This screen is not yet available.';

  /// A 390x844 phone — the reference device the rest of this app's previews are
  /// sized for.
  static const Size phoneBox = Size(390, 844);

  /// The 320x568 compact phone — the narrowest viewport the app supports, and
  /// the one that decides whether [title] fits on a line.
  static const Size compactBox = Size(320, 568);

  /// A 844x390 landscape / split-screen viewport.
  ///
  /// `OmdsEmptyState` centres a NON-scrolling `Column` (a 100pt icon, a
  /// headline, a body, inside `EdgeInsets.all(24)`), so its content has a hard
  /// height floor that grows with the text scale. Height, not width, is what
  /// this screen runs out of, and this is the box where that becomes visible.
  static const Size landscapeBox = Size(844, 390);

  /// The single state, built the same way for both hosts.
  ///
  /// The preview section deliberately writes `const SavedAddressesScreen()` out
  /// again instead of calling this — see the comment there; the coverage
  /// detector requires the literal constructor call inside the section.
  static Widget placeholder() => const SavedAddressesScreen();
}
