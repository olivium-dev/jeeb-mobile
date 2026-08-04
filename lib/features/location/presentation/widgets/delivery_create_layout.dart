import 'package:flutter/widgets.dart';
import 'package:omds/omds.dart';

/// Shared layout constants for the delivery-create screens (Request type,
/// Client Location). Keeps the page gutter rhythm identical across the flow
/// without repeating the literal `EdgeInsetsDirectional` in each screen.
class DeliveryCreateLayout {
  const DeliveryCreateLayout._();

  /// Scrollable page padding: the board-wide 24px start/end gutter
  /// (`Spacing.xLarge`, wiring request 09 — was `Spacing.large`/20), a medium
  /// top inset under the navbar, and a generous bottom inset so the last row
  /// clears the nav bar. Screens 07/08/09 all render against 24.
  static const EdgeInsetsDirectional pagePadding =
      EdgeInsetsDirectional.fromSTEB(
    Spacing.xLarge,
    Spacing.medium,
    Spacing.xLarge,
    Spacing.twoXLarge,
  );
}
