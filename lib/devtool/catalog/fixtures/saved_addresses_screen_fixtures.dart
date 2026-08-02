// Designed-state fixtures for `SavedAddressesScreen` — the "Saved Addresses"

import 'package:flutter/widgets.dart';

import '../../../features/settings/presentation/screens/saved_addresses_screen.dart';

/// The one designed state of `SavedAddressesScreen`, plus the boxes it is
/// reviewed in.
class SavedAddressesScreenFixtures {
  const SavedAddressesScreenFixtures._();

  /// Label for the single catalog state / preview. Shared so the designer's
  /// on-device state and the engineer's canvas card cannot end up named
  static const String placeholderLabel = 'Placeholder';

  /// The headline the placeholder renders.
  /// HARDCODED ENGLISH in the screen — `l10n.savedAddressesTitle` and
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
  /// `OmdsEmptyState` centres a NON-scrolling `Column` (a 100pt icon, a
  static const Size landscapeBox = Size(844, 390);

  /// The single state, built the same way for both hosts.
  /// The preview section deliberately writes `const SavedAddressesScreen()` out
  static Widget placeholder() => const SavedAddressesScreen();
}
