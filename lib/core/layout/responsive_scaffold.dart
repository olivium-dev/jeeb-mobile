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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/core/responsive_body_preview_test.dart
// ===========================================================================
//
// Widget previews for [ResponsiveBody] — run with
// `flutter widget-preview start`.
//
// [ResponsiveBody] has no state, no dependencies, no strings and nothing to
// paint. Its entire behaviour is a function of ONE input — the width its
// parent offers it — so "empty / loading / error" do not exist here. The
// states that can break are the widths on either side of each breakpoint, and
// the two shapes of child (fills the width vs. sizes to its content) that the
// widget treats differently without saying so.
//
// Because the widget is invisible, every preview below wraps it in two
// fixtures that are NOT part of production: a `_Viewport` that pins the
// offered width, and a `_ContentBlock` that paints the column
// [ResponsiveBody] handed it and prints the width it was given. The tinted
// margin around the block is exactly the space the widget took away.
//
// The width has to be pinned inside the preview rather than left to the
// canvas [Size]. The canvas honours `size`, but the render tests in
// `test/previews/` pump onto a fixed 800 × 600 surface — so a preview that
// merely asked for a 1280 pt canvas would render the *medium* branch under
// test, and all three wide states would silently become the same widget. That
// is the "every preview shows the same thing" failure the README warns about.
// `_Viewport` scrolls horizontally so a width wider than the host is honoured
// instead of being clamped down to it (an `Align` + `SizedBox`, the idiom the
// chat previews use, cannot do this — `Align` passes the host's max width
// down and a wider `SizedBox` is silently clamped).
//
// Three things these previews surfaced, all in the widget rather than in the
// previews — see the notes on the individual states:
//
//  * the content column is WIDER just below the wide breakpoint (799 pt at
//    839 pt) than it is above it (600 pt at 840 pt), so growing the window by
//    one pixel shrinks the text column by a third;
//  * `Center` centres vertically as well as horizontally, so the same body
//    that starts at y = 0 on a phone floats in the vertical middle of the
//    window on a tablet;
//  * the child is given TIGHT width constraints on phones and LOOSE ones on
//    wide screens, so a child that does not ask for `double.infinity`
//    shrink-wraps on tablets only.

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
/// rather than anything about [ResponsiveBody].
const double _responsiveBodyBoxHeight = 300;

/// Marks the content column so the render test can measure where
/// [ResponsiveBody] actually put it. Widths and gutters are the whole contract
/// of this widget; asserting them is the only way a test can tell the
/// breakpoints apart.
const Key responsiveBodyPreviewContentKey = Key('responsive-body-preview-content');

/// Simulates a viewport of exactly [width] pt around [ResponsiveBody].
///
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
///
/// [fillWidth] is the difference between the two kinds of real child. `true`
/// asks for `double.infinity` the way a `Column` with stretched children or a
/// full-bleed `ListView` does; `false` sizes to its content the way a `Card` or
/// a `Column` of `Text` does. [ResponsiveBody] treats them differently and the
/// dartdoc does not mention it.
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
/// untouched.
///
/// Worth looking at precisely because nothing happens: the content is flush to
/// x = 0 with NO gutter, so on the path ~every user is on, every caller has to
/// pad its own child or its text sits against the display edge. The widget
/// removes no `MediaQuery` padding either — a `SafeArea` has to come from the
/// caller. Measured at 390 pt: content 390 pt wide at left = 0.
@JeebPreview(group: 'core', name: 'Phone 390 · untouched', size: Size(_responsiveBodyPhoneWidth, _responsiveBodyBoxHeight))
Widget responsiveBodyPhone() => _responsiveBodyHosted(
      width: _responsiveBodyPhoneWidth,
      label: 'Phone · 390 pt viewport',
    );

/// The medium branch: a tablet in portrait, or an iPad split view.
///
/// 20 pt of `Spacing.large` on each side, from an `EdgeInsets.symmetric`, which
/// is why this branch mirrors correctly in Arabic — the AR RTL rendering is the
/// check that it stays symmetric if anyone ever tunes one side.
@JeebPreview(group: 'core', 
  name: 'Tablet 700 · padded',
  size: Size(_responsiveBodyTabletWidth, _responsiveBodyBoxHeight),
)
Widget responsiveBodyTabletPortrait() => _responsiveBodyHosted(
      width: _responsiveBodyTabletWidth,
      label: 'Tablet portrait · 700 pt viewport',
    );

/// The state that breaks, half one: one pixel BELOW the wide breakpoint.
///
/// Still the medium branch, so the content column is `839 - 40 = 799` pt wide —
/// a third wider than [ResponsiveBody.maxContentWidth], the value the class
/// dartdoc calls a "hard ceiling on the content column width for readability".
/// The ceiling only applies above 840 pt, so the widest line length the app
/// ever renders is produced by the branch that was supposed to prevent it.
/// Read this preview next to the one below.
@JeebPreview(group: 'core', 
  name: '839 · widest line the app renders',
  size: Size(_responsiveBodyJustUnderWide, _responsiveBodyBoxHeight),
)
Widget responsiveBodyJustUnderWide() => _responsiveBodyHosted(
      width: _responsiveBodyJustUnderWide,
      label: '839 pt · one pixel below the wide breakpoint',
    );

/// The state that breaks, half two: exactly at the wide breakpoint.
///
/// One pixel wider than the preview above, and the content column SHRINKS from
/// 799 pt to 600 pt while 120 pt of empty gutter appears on each side. Dragging
/// a window across 840 pt reflows every line of body text on the screen.
@JeebPreview(group: 'core', 
  name: '840 · snaps back to 600',
  size: Size(_responsiveBodyAtWide, _responsiveBodyBoxHeight),
)
Widget responsiveBodyAtWideBreakpoint() => _responsiveBodyHosted(
      width: _responsiveBodyAtWide,
      label: '840 pt · exactly at the wide breakpoint',
    );

/// The expanded branch at a real desktop width.
///
/// 600 pt of content centred in 1280 pt, i.e. 340 pt of dead space per side —
/// the intended behaviour, and the one state where the AR RTL rendering is
/// genuinely uninteresting, because `Center` has no handedness.
///
/// What IS worth checking here: `Center` has no width or height factor, so it
/// takes all the height on offer and centres the child on BOTH axes — the only
/// branch that moves content vertically. Measured under the render test, the
/// block sits at (340, 258) with 258 pt of dead space above it, where the
/// identical block in the phone preview sits at (0, 0). A screen body that
/// starts under the app bar on a phone floats in the middle of the window on a
/// tablet.
@JeebPreview(group: 'core', 
  name: 'Desktop 1280 · centred at 600',
  size: Size(_responsiveBodyDesktopWidth, _responsiveBodyBoxHeight),
)
Widget responsiveBodyDesktop() => _responsiveBodyHosted(
      width: _responsiveBodyDesktopWidth,
      label: 'Desktop · 1280 pt viewport',
    );

/// The trap: the same child, minus `width: double.infinity`.
///
/// On a phone [ResponsiveBody] forwards its parent's TIGHT constraints, so any
/// child is stretched to the full width whether it asked to be or not. On a
/// wide screen `Center` hands the child LOOSE constraints, so a child that
/// sizes to its content — a `Card`, a `Column` of `Text` — suddenly
/// shrink-wraps to its longest line instead of filling the 600 pt column.
///
/// The block still reports "offered 600 pt", because that is what it was
/// offered; it just did not take it. Measured under the render test: 435.8 pt
/// wide against 600 pt for the identical child one preview up. Nothing warns
/// about it — the widget silently changes the contract it offers its child
/// halfway up the breakpoint scale.
@JeebPreview(group: 'core', 
  name: 'Intrinsic child · shrink-wraps on wide',
  size: Size(_responsiveBodyDesktopWidth, _responsiveBodyBoxHeight),
)
Widget responsiveBodyIntrinsicChild() => _responsiveBodyHosted(
      width: _responsiveBodyDesktopWidth,
      label: 'Intrinsic child · 1280 pt',
      fillWidth: false,
    );
