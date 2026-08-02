import 'package:flutter/widgets.dart';

class CatalogState {
  const CatalogState(this.label, this.builder);
  final String label;
  final WidgetBuilder builder;
}

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

const int kTotalFeatureCount = 66;
