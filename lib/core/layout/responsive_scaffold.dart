import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Responsive layout wrapper that constrains body content to a maximum width
/// on large screens (tablets, desktop) while filling the available width on
/// phones.
///
/// On narrow viewports (< [breakpointMedium]) the child fills edge to edge.
/// On medium viewports the child is padded horizontally. On wide viewports
/// (≥ [breakpointWide]) the child is centred at [maxContentWidth].
///
/// This widget lives *inside* the Scaffold body — it is not a Scaffold
/// replacement. Wrap it around any screen body that should respect responsive
/// constraints:
///
/// ```dart
/// Scaffold(
///   appBar: const OMDSAppBar(title: 'Home'),
///   body: ResponsiveBody(child: MyContent()),
/// )
/// ```
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child});

  final Widget child;

  /// Below this width content fills edge-to-edge (phones).
  static const double breakpointMedium = 600;

  /// At or above this width content is centred at [maxContentWidth].
  static const double breakpointWide = 840;

  /// Hard ceiling on the content column width for readability on large screens.
  static const double maxContentWidth = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < breakpointMedium) {
          return child;
        }
        if (width < breakpointWide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
            child: child,
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// Convenience type that describes the current device form factor based on
/// viewport width. Use in tests or in layout decisions that need an enum
/// rather than raw pixel checks.
enum DeviceFormFactor { compact, medium, expanded }

/// Returns the [DeviceFormFactor] for the current viewport.
DeviceFormFactor deviceFormFactor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < ResponsiveBody.breakpointMedium) return DeviceFormFactor.compact;
  if (width < ResponsiveBody.breakpointWide) return DeviceFormFactor.medium;
  return DeviceFormFactor.expanded;
}
