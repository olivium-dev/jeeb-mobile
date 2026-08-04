import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_midnight_field.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../devtool/catalog/fixtures/saved_addresses_screen_fixtures.dart';

/// M4 §2.7 `empty` on the balcony tile — the one tile that draws a home. Copy
/// stays "coming soon": this screen is UNBUILT, not built-and-empty (Q7).
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  /// `find.bySemanticsIdentifier` handle on the placeholder block.
  static const String placeholderIdentifier = 'saved_addresses_placeholder';

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  static const _featureId = 'saved-addresses';

  // TODO(midnight): l10n-queued — `savedAddressesComingSoonTitle` /
  // `savedAddressesComingSoonBody`. Copy kept verbatim so it stays reviewable.
  static const _title = 'Saved Addresses coming soon';
  static const _subtitle = 'This screen is not yet available.';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        animateDecor: false,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: JeebEmptyState(
                variant: JeebEmptyStateVariant.balcony,
                headline: _title,
                body: _subtitle,
                medallions: <JeebEmptyMedallion>[],
                identifier: SavedAddressesScreen.placeholderIdentifier,
                semanticLabel: '$_title. $_subtitle',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The single designed state, hosted for the canvas.
/// `const SavedAddressesScreen()` is written out here rather than delegating to
Widget _savedAddressesScreenHosted() => const SavedAddressesScreen();

/// The reference rendering: a 390x844 phone.
/// `matrix: true` because the AR card is the whole point. The screen renders
@JeebPreview(
  group: 'settings',
  name: 'Placeholder · phone',
  size: SavedAddressesScreenFixtures.phoneBox,
  matrix: true,
)
Widget savedAddressesScreenPlaceholder() => _savedAddressesScreenHosted();

/// The narrowest viewport the app supports (320x568).
/// 272pt of usable width after the 24pt padding, which is where the headline
@JeebPreview(
  group: 'settings',
  name: 'Compact device',
  size: SavedAddressesScreenFixtures.compactBox,
)
Widget savedAddressesScreenCompact() => _savedAddressesScreenHosted();

/// Landscape / split-screen (844x390) — the height ceiling.
/// The icon alone is 100pt and the gaps around it another 48pt before a word
@JeebPreview(
  group: 'settings',
  name: 'Landscape · short viewport',
  size: SavedAddressesScreenFixtures.landscapeBox,
  matrix: true,
)
Widget savedAddressesScreenLandscape() => _savedAddressesScreenHosted();
