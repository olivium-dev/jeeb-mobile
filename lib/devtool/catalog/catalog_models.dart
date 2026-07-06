import 'package:flutter/widgets.dart';

/// One mocked UI state of a screen for the designer catalog (DT-04 / F2). The
/// [builder] returns the real screen widget, seeded (locally, no network) into
/// this state.
class CatalogState {
  const CatalogState(this.label, this.builder);
  final String label;
  final WidgetBuilder builder;
}

/// One cataloged screen and its list of mocked states.
class CatalogEntry {
  const CatalogEntry({
    required this.feature,
    required this.screen,
    required this.states,
  });

  final String feature;
  final String screen;
  final List<CatalogState> states;
}

/// Total feature modules under `lib/features` — the denominator for the honest
/// coverage readout on the catalog menu.
const int kTotalFeatureCount = 66;
