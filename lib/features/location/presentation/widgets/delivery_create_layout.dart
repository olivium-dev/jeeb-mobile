import 'package:flutter/widgets.dart';
import 'package:omds/omds.dart';

/// Shared layout constants for the delivery-create screens (Request type,
/// Client Location). Keeps the page gutter rhythm identical across the flow
/// (Figma `GapPadding-24` → `Spacing.large`) without repeating the literal
/// `EdgeInsetsDirectional` in each screen.
class DeliveryCreateLayout {
  const DeliveryCreateLayout._();

  /// Scrollable page padding: large gutters, a medium top inset under the
  /// navbar, and a generous bottom inset so the last row clears the nav bar.
  static const EdgeInsetsDirectional pagePadding =
      EdgeInsetsDirectional.fromSTEB(
    Spacing.large,
    Spacing.medium,
    Spacing.large,
    Spacing.twoXLarge,
  );
}
