import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Responsive layout wrapper; constrains content to [maxContentWidth] on wide screens.
/// Wraps body content (not a Scaffold replacement).
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child});

  final Widget child;

  static const double breakpointMedium = 600;

  static const double breakpointWide = 840;

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

enum DeviceFormFactor { compact, medium, expanded }

DeviceFormFactor deviceFormFactor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < ResponsiveBody.breakpointMedium) return DeviceFormFactor.compact;
  if (width < ResponsiveBody.breakpointWide) return DeviceFormFactor.medium;
  return DeviceFormFactor.expanded;
}
