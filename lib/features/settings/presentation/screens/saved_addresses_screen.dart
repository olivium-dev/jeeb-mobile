import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../devtool/catalog/fixtures/saved_addresses_screen_fixtures.dart';

/// Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5). Real implementation
/// arrives in the per-feature follow-up ticket. Do NOT add behavior here.
// ORPHAN (JEBV4-227, verified 2026-07-12): superseded by SavedLocationsScreen (T-MOB-025) — see docs/project-understanding/reconciliation/orphans.md
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  static const _featureId = 'saved-addresses';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Saved Addresses coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Saved Addresses coming soon',
        subtitle: 'This screen is not yet available.',
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
// Render tests: test/previews/settings/saved_addresses_screen_preview_test.dart
// ===========================================================================
//
// This screen has exactly ONE state, and that is a fact about the screen
// rather than a gap in these previews. It takes no parameters, owns no cubit
// and reads no repository — `build` returns a `const OmdsEmptyStatePage` with
// two literal strings — so there is no empty / loading / error triad to cover
// because there is nothing to load. The Screen Catalog reaches the same
// conclusion in its own vocabulary: `batch_10_entries.dart` lists one state,
// `Placeholder`, and both surfaces now read it from
// [SavedAddressesScreenFixtures].
//
// What DOES vary is the BOX the placeholder is handed, and that is the thing
// that breaks. `OmdsEmptyState` centres a non-scrolling `Column` — a 100pt
// icon, a headline, a body, inside `EdgeInsets.all(24)` — so its content has a
// hard height floor that grows with the text scale and has nowhere to go when
// the viewport is shorter than that floor. The three previews are that box at
// the three shapes the app ships into: the 390pt reference phone, the 320pt
// compact phone, and a landscape / split-screen viewport.
//
// Three things a reviewer should read off these cards rather than take on
// trust, all of them stated and none of them fixed — nothing above the banner
// may change:
//
//   * The copy is HARDCODED ENGLISH. `savedAddressesTitle` and
//     `savedAddressesEmptyTitle` exist in both ARBs and `settings_screen.dart`
//     already uses the first, but this screen ships string literals. The AR
//     card of the phone matrix therefore renders English inside an RTL frame —
//     if it ever renders Arabic, someone localized the screen and these
//     fixtures need updating.
//   * There is NO app bar (`appBar: null`) and so no back affordance on any
//     card. The screen is currently unrouted (JEBV4-227 marks it an orphan
//     superseded by `SavedLocationsScreen`), which is the only reason that is
//     not a trap today.
//   * The landscape card at 200% text is where the `Column` runs out of
//     height. That is what the second matrix is for.
//
// On hosting: the screen returns its own `Scaffold` (via `OmdsEmptyStatePage`)
// and `jeebPreviewHost` wraps every preview in another one, so the canvas draws
// a Scaffold inside a Scaffold. It nests harmlessly here — the inner one has no
// app bar, no FAB and no bottom bar — and the host is left alone deliberately,
// because it is shared by every preview in the tree.

/// The single designed state, hosted for the canvas.
///
/// `const SavedAddressesScreen()` is written out here rather than delegating to
/// [SavedAddressesScreenFixtures.placeholder] because the coverage detector
/// (`tool/preview_inventory.dart` · `SourceFile.constructs`) looks for the
/// literal constructor call inside this section; a section that only calls a
/// factory is reported MALFORMED. The fixtures file still owns everything a
/// reader could get wrong — the copy and the boxes.
Widget _savedAddressesScreenHosted() => const SavedAddressesScreen();

/// The reference rendering: a 390x844 phone.
///
/// `matrix: true` because the AR card is the whole point. The screen renders
/// string literals, so Arabic mirrors the LAYOUT and keeps the ENGLISH words —
/// the one bug a single EN card cannot show you.
@JeebPreview(
  group: 'settings',
  name: 'Placeholder · phone',
  size: SavedAddressesScreenFixtures.phoneBox,
  matrix: true,
)
Widget savedAddressesScreenPlaceholder() => _savedAddressesScreenHosted();

/// The narrowest viewport the app supports (320x568).
///
/// 272pt of usable width after the 24pt padding, which is where the headline
/// stops fitting on one line. `OmdsEmptyState` passes no `maxLines` and no
/// `overflow`, so the title wraps rather than truncating — worth seeing, since
/// the wrap is what pushes the body copy toward the bottom edge.
@JeebPreview(
  group: 'settings',
  name: 'Compact device',
  size: SavedAddressesScreenFixtures.compactBox,
)
Widget savedAddressesScreenCompact() => _savedAddressesScreenHosted();

/// Landscape / split-screen (844x390) — the height ceiling.
///
/// The icon alone is 100pt and the gaps around it another 48pt before a word
/// is drawn, and none of it scrolls. At the app's 200% accessibility ceiling
/// the column wants more height than a 390pt viewport has, and because there is
/// no `SingleChildScrollView` there is no recovery: the content is clipped, not
/// scrolled to. `matrix: true` is here for that third card.
@JeebPreview(
  group: 'settings',
  name: 'Landscape · short viewport',
  size: SavedAddressesScreenFixtures.landscapeBox,
  matrix: true,
)
Widget savedAddressesScreenLandscape() => _savedAddressesScreenHosted();
