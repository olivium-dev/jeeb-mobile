import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The widest phone the app targets — comfortably inside the compact branch.
const double _responsiveBodyPhoneWidth = 390;

/// A tablet in portrait / a half-screen split view: the medium branch.
const double _responsiveBodyTabletWidth = 700;

/// One pixel below [ResponsiveBody.breakpointWide]: still the medium branch,
/// and the widest the content column ever gets.
const double _responsiveBodyJustUnderWide = ResponsiveBody.breakpointWide - 1;

/// Exactly [ResponsiveBody.breakpointWide]: the first width that is centred.
const double _responsiveBodyAtWide = ResponsiveBody.breakpointWide;

/// A desktop / landscape tablet window, well past the wide breakpoint.
const double _responsiveBodyDesktopWidth = 1280;

/// Canvas height. Generous on purpose: the 200% rendering doubles every line in
/// the content block, and a box that clipped it would report a fixture overflow
const double _responsiveBodyBoxHeight = 300;

/// Marks the content column so the render test can measure where
/// [ResponsiveBody] actually put it. Widths and gutters are the whole contract
const Key responsiveBodyPreviewContentKey = Key('responsive-body-preview-content');

/// Simulates a viewport of exactly [width] pt around [ResponsiveBody].
/// The [ColoredBox] tints the full simulated viewport, so whatever is NOT the
/// content block is the space the widget removed.
class _ResponsiveBodyViewport extends StatelessWidget {
  const _ResponsiveBodyViewport({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ResponsiveBody(child: child),
        ),
      ),
    );
  }
}

/// A stand-in for a screen body: paints the column it was given and reports the
/// width [ResponsiveBody] offered it.
/// [fillWidth] is the difference between the two kinds of real child. `true`
class _ResponsiveBodyContentBlock extends StatelessWidget {
  const _ResponsiveBodyContentBlock({required this.label, this.fillWidth = true});

  final String label;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          key: responsiveBodyPreviewContentKey,
          width: fillWidth ? double.infinity : null,
          color: theme.colorScheme.primaryContainer,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'offered ${constraints.maxWidth.toStringAsFixed(0)} pt',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _responsiveBodyHosted({
  required double width,
  required String label,
  bool fillWidth = true,
}) =>
    _ResponsiveBodyViewport(
      width: width,
      child: _ResponsiveBodyContentBlock(label: label, fillWidth: fillWidth),
    );

/// The state ~every real user is in: a phone, below
/// [ResponsiveBody.breakpointMedium], where the widget returns its child
@JeebPreview(group: 'core', name: 'Phone 390 · untouched', size: Size(_responsiveBodyPhoneWidth, _responsiveBodyBoxHeight))
Widget responsiveBodyPhone() => _responsiveBodyHosted(
      width: _responsiveBodyPhoneWidth,
      label: 'Phone · 390 pt viewport',
    );

/// The medium branch: a tablet in portrait, or an iPad split view.
/// 20 pt of `Spacing.large` on each side, from an `EdgeInsets.symmetric`, which
@JeebPreview(group: 'core', 
  name: 'Tablet 700 · padded',
  size: Size(_responsiveBodyTabletWidth, _responsiveBodyBoxHeight),
)
Widget responsiveBodyTabletPortrait() => _responsiveBodyHosted(
      width: _responsiveBodyTabletWidth,
      label: 'Tablet portrait · 700 pt viewport',
    );

/// The state that breaks, half one: one pixel BELOW the wide breakpoint.
/// Still the medium branch, so the content column is `839 - 40 = 799` pt wide —
@JeebPreview(group: 'core', 
  name: '839 · widest line the app renders',
  size: Size(_responsiveBodyJustUnderWide, _responsiveBodyBoxHeight),
)
Widget responsiveBodyJustUnderWide() => _responsiveBodyHosted(
      width: _responsiveBodyJustUnderWide,
      label: '839 pt · one pixel below the wide breakpoint',
    );

/// The state that breaks, half two: exactly at the wide breakpoint.
/// One pixel wider than the preview above, and the content column SHRINKS from
@JeebPreview(group: 'core', 
  name: '840 · snaps back to 600',
  size: Size(_responsiveBodyAtWide, _responsiveBodyBoxHeight),
)
Widget responsiveBodyAtWideBreakpoint() => _responsiveBodyHosted(
      width: _responsiveBodyAtWide,
      label: '840 pt · exactly at the wide breakpoint',
    );

/// The expanded branch at a real desktop width.
/// 600 pt of content centred in 1280 pt, i.e. 340 pt of dead space per side —
@JeebPreview(group: 'core', 
  name: 'Desktop 1280 · centred at 600',
  size: Size(_responsiveBodyDesktopWidth, _responsiveBodyBoxHeight),
)
Widget responsiveBodyDesktop() => _responsiveBodyHosted(
      width: _responsiveBodyDesktopWidth,
      label: 'Desktop · 1280 pt viewport',
    );

/// The trap: the same child, minus `width: double.infinity`.
/// On a phone [ResponsiveBody] forwards its parent's TIGHT constraints, so any
@JeebPreview(group: 'core', 
  name: 'Intrinsic child · shrink-wraps on wide',
  size: Size(_responsiveBodyDesktopWidth, _responsiveBodyBoxHeight),
)
Widget responsiveBodyIntrinsicChild() => _responsiveBodyHosted(
      width: _responsiveBodyDesktopWidth,
      label: 'Intrinsic child · 1280 pt',
      fillWidth: false,
    );
