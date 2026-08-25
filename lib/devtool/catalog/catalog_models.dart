import 'package:flutter/widgets.dart';

enum CatalogCapturePolicy { visual, navigationOnly }

class CatalogState {
  const CatalogState(
    this.label,
    this.builder, {
    this.capturePolicy = CatalogCapturePolicy.visual,
  });
  final String label;
  final WidgetBuilder builder;
  final CatalogCapturePolicy capturePolicy;
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
