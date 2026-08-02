import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../live_tracking_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// JM-032 AC4 (D88): the no-show action sheet — shown when the customer reports
/// the Jeeber never arrived. Offers two recovery paths:
///   * `tracking_noshow_reassign_cta`    → offer-review-list (pick another offer)
///   * `tracking_noshow_rebroadcast_cta` → waiting-no-coverage (send out again)
///
/// EXEMPT: OmdsBottomSheet lacks a `show` static factory with a scroll-safe body
/// (mirrors `cancellation_success_sheet.dart`); uses Flutter's
/// `showModalBottomSheet` with an OMDS-token-only child. The sheet pops itself
/// before invoking the navigation callback so the chosen route replaces it.
class TrackingNoShowSheet extends StatelessWidget {
  const TrackingNoShowSheet({
    super.key,
    required this.onReassign,
    required this.onRebroadcast,
    required this.onKeepWaiting,
  });

  final VoidCallback onReassign;
  final VoidCallback onRebroadcast;
  final VoidCallback onKeepWaiting;

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onReassign,
    required VoidCallback onRebroadcast,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.large),
        ),
      ),
      builder: (sheetContext) => TrackingNoShowSheet(
        onReassign: () {
          Navigator.of(sheetContext).pop();
          onReassign();
        },
        onRebroadcast: () {
          Navigator.of(sheetContext).pop();
          onRebroadcast();
        },
        onKeepWaiting: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'tracking_noshow_sheet',
      container: true,
      explicitChildNodes: true,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.noShowTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.small),
              Text(
                l10n.noShowBody,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'tracking_noshow_reassign_cta',
                button: true,
                child: OmdsPrimaryButton(
                  text: l10n.noShowReassignCta,
                  onTap: onReassign,
                ),
              ),
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'tracking_noshow_rebroadcast_cta',
                button: true,
                child: OmdsPrimaryButton(
                  text: l10n.noShowRebroadcastCta,
                  variant: OmdsButtonVariant.outlined,
                  onTap: onRebroadcast,
                ),
              ),
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'tracking_noshow_keep_cta',
                button: true,
                child: OmdsPrimaryButton(
                  text: l10n.noShowKeepCta,
                  variant: OmdsButtonVariant.text,
                  onTap: onKeepWaiting,
                ),
              ),
            ],
          ),
        ),
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
// Render tests: test/previews/live_tracking/tracking_no_show_sheet_preview_test.dart
// ===========================================================================
// Widget previews for [TrackingNoShowSheet] — run with
// `flutter widget-preview start`.
//
// The sheet carries no data: three [VoidCallback]s in, five strings of
// localized copy out (resolved by `LiveTrackingL10n`, which still serves the
// no-show strings from a feature-local EN/AR map because the integrator has not
// landed the ARB keys yet). There is no cubit, no repository and no image to
// fake, so these previews are network-free because the widget has nothing to
// fetch — not merely because [jeebPreviewHost] guards it.
//
// Nothing about the *content* varies, so what the states below vary is the
// three things that actually decide whether this sheet works:
//
// * **Width.** Every CTA is a full-bleed [OmdsPrimaryButton] whose pill is a
//   FIXED 48 pt (`Sizes.fourXLarge`) at every text scale, so a label that wraps
//   does not grow the button — it is clamped by the `Center` inside it and
//   painted over the pill edge. 320 pt is where that starts.
// * **Height.** The body is a plain [Column] with `mainAxisSize.min` and no
//   scroll fallback — the widget's own doc comment calls this out ("EXEMPT:
//   OmdsBottomSheet lacks a `show` static factory with a scroll-safe body").
//   `showModalBottomSheet(isScrollControlled: true)` will hand it the whole
//   screen and no more, so past that the Column overflows rather than scrolls.
// * **Framing.** Production never shows this widget the way the bare previews
//   do. It arrives through [TrackingNoShowSheet.show] — bottom-anchored, top
//   corners rounded by `Spacing.large`, over a scrim, popping ITSELF before it
//   invokes the navigation callback so the chosen route replaces it rather than
//   stacking under it. `Modal presentation` renders that real path; the bare
//   states keep the content stack easy to inspect.
//
// **Measurements.** All taken under `flutter test`, whose monospaced substitute
// font runs materially wider than the production Inter face — so treat every
// number here as the pessimistic end, and the wrap points as earlier than a
// device will show:
//
// | width | 100% | 200% |
// |-------|------|------|
// | 390pt | 376  | 824  |
// | 320pt | 424  | 904  |
//
// The 200% column is the finding. 824 pt does not fit any phone the app
// supports, and 904 pt is more than 1.5x the 568 pt height of the smallest —
// which is what `Small phone · modal` frames at 100% so the remaining headroom
// is visible before the accessibility ceiling eats it.
//
// Every preview pins its own width via [_trackingNoShowSheetHosted]. The render tests pump an
// 800 px viewport and ignore [JeebPreview.size], so without the pin CI would be
// reviewing a bottom sheet at a width no phone has.

/// Phone width, tall enough that the EN 200%-text rendering still has room.
const Size _trackingNoShowSheetBox = Size(390, 600);

/// The narrowest phone the app supports, and the taller box its extra wrapping
/// needs.
const Size _trackingNoShowSheetNarrowBox = Size(320, 660);

/// A whole phone, so the modal previews have a backdrop and a scrim to judge.
const Size _trackingNoShowSheetPhoneBox = Size(390, 720);

/// Logical size of the smallest supported phone (iPhone SE 1st gen class).
const Size _trackingNoShowSheetSmallPhoneSize = Size(320, 568);

/// The bottom inset of a gesture-navigation home indicator, in logical pixels.
const double _trackingNoShowSheetHomeIndicatorDp = 34;

/// The bare sheet, driven exactly as `live_tracking_screen` drives it, pinned to
/// a real phone width.
///
/// The callbacks are no-ops: in production two of them push a route and the
/// third pops, and a preview has no business navigating.
Widget _trackingNoShowSheetHosted({double width = 390}) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: TrackingNoShowSheet(
          onReassign: () {},
          onRebroadcast: () {},
          onKeepWaiting: () {},
        ),
      ),
    );

/// [_trackingNoShowSheetHosted] as a const-constructible widget, so the states that wrap it can be
/// `const`.
class _TrackingNoShowSheetBareSheet extends StatelessWidget {
  const _TrackingNoShowSheetBareSheet();

  @override
  Widget build(BuildContext context) => _trackingNoShowSheetHosted();
}

/// Seeds the bottom system inset that [jeebPreviewHost]'s own [SafeArea] has
/// already consumed.
///
/// Written as a widget rather than an inline [MediaQuery] so `MediaQuery.of`
/// resolves against the ambient data and this overrides two fields of it instead
/// of replacing the whole thing (which would silently drop the matrix's text
/// scaler).
class _TrackingNoShowSheetSimulatedSystemInset extends StatelessWidget {
  const _TrackingNoShowSheetSimulatedSystemInset({required this.bottomDp, required this.child});

  final double bottomDp;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets inset = EdgeInsets.only(bottom: bottomDp);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: inset,
        viewPadding: inset,
      ),
      child: child,
    );
  }
}

/// Hosts the sheet in a real modal route, pushed through the production
/// [TrackingNoShowSheet.show].
///
/// The local [Navigator] is what makes this self-contained: `show()` needs a
/// navigator to push onto, and a preview must not assume the canvas (or a test
/// harness) supplies one it can safely mutate.
class _TrackingNoShowSheetModalPresentation extends StatelessWidget {
  const _TrackingNoShowSheetModalPresentation();

  @override
  Widget build(BuildContext context) => Navigator(
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const _TrackingNoShowSheetOverMap(),
        ),
      );
}

/// Opens the sheet over [_TrackingNoShowSheetMapBackdrop] on the first frame.
class _TrackingNoShowSheetOverMap extends StatefulWidget {
  const _TrackingNoShowSheetOverMap();

  @override
  State<_TrackingNoShowSheetOverMap> createState() => _TrackingNoShowSheetOverMapState();
}

class _TrackingNoShowSheetOverMapState extends State<_TrackingNoShowSheetOverMap> {
  @override
  void initState() {
    super.initState();
    // Post-frame, because `show()` needs a mounted route to push onto — the
    // same sequencing the other modal previews in this folder use.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    // Both callbacks are no-ops: in production they navigate to
    // offer-review-list / waiting-no-coverage, and the sheet has already popped
    // itself by the time either runs.
    await TrackingNoShowSheet.show(
      context: context,
      onReassign: () {},
      onRebroadcast: () {},
    );
  }

  @override
  Widget build(BuildContext context) => const _TrackingNoShowSheetMapBackdrop();
}

/// A neutral stand-in for the live-tracking map behind the sheet — enough shape
/// to judge the scrim against.
///
/// Deliberately text-free, so every string a preview test pins can only have
/// come from the sheet itself.
class _TrackingNoShowSheetMapBackdrop extends StatelessWidget {
  const _TrackingNoShowSheetMapBackdrop();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceContainerHighest),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The route line and the courier pin, as plain shapes.
            Expanded(
              child: Center(
                child: Container(
                  width: Spacing.xLarge,
                  height: Spacing.xLarge,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Container(
              height: Spacing.fourXLarge,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(Spacing.small),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The default reading: JM-032 AC4 (D88) at 390 pt.
///
/// Three stacked full-bleed CTAs in descending emphasis — filled, outlined,
/// text. The thing to check is that the descent still reads as a hierarchy in
/// the **AR RTL dark** rendering, where the outlined variant's 1.5 pt
/// `colorScheme.primary` border is the only thing separating "Send request
/// again" from the text-only "Keep waiting" below it.
@JeebPreview(group: 'live_tracking', name: 'Bare sheet · 390 pt', size: _trackingNoShowSheetBox)
Widget trackingNoShowSheetDefault() => _trackingNoShowSheetHosted();

/// 320 pt — where the CTA labels stop fitting on one line.
///
/// The pill is a fixed 48 pt at every text scale and the label sits in a
/// `Center` inside it, so wrapping does not grow the button: at 200% text this
/// width gives the label 248 pt to work with, "Send request again" needs two
/// lines (80 pt) and gets clamped to 48. Nothing in [OmdsPrimaryButton] ellipsizes
/// or shrinks it, so what the reviewer sees is a clipped label — this is the
/// state to look at in the **EN 200% text** rendering.
///
/// The body copy is the other casualty: one 84-character sentence, five lines
/// here at 200%, and the only reason the sheet still fits its box at 100%.
@JeebPreview(group: 'live_tracking', name: 'Narrow phone · 320 pt', size: _trackingNoShowSheetNarrowBox)
Widget trackingNoShowSheetNarrowPhone() => _trackingNoShowSheetHosted(width: _trackingNoShowSheetSmallPhoneSize.width);

/// The sheet with a gesture-navigation home indicator under it.
///
/// [TrackingNoShowSheet] wraps its column in a [SafeArea], and this is the only
/// state where that [SafeArea] does anything: [jeebPreviewHost] wraps every
/// preview in its own, which zeroes the ambient padding, so without seeding it
/// back the matrix would review a sheet whose bottom inset is permanently 0.
///
/// It matters for the tertiary CTA specifically. "Keep waiting" is the one users
/// reach for when they decide the Jeeber is merely late, it is the bottom-most
/// 48 pt row, and with no [SafeArea] it would sit directly under the home
/// indicator — the one place a tap is swallowed by the system. Measured: 20 pt
/// of padding below the pill without the inset, 54 pt with it.
@JeebPreview(group: 'live_tracking', name: 'Gesture-bar inset', size: _trackingNoShowSheetBox)
Widget trackingNoShowSheetGestureBar() => const _TrackingNoShowSheetSimulatedSystemInset(
      bottomDp: _trackingNoShowSheetHomeIndicatorDp,
      child: _TrackingNoShowSheetBareSheet(),
    );

/// The sheet as the customer actually meets it: pushed by
/// [TrackingNoShowSheet.show] over the dimmed tracking map.
///
/// This is the only preview that exercises the production entry point — the
/// scrim, the `Spacing.large` top corners, the bottom anchoring, and the
/// pop-before-callback wiring. Everything above renders a shape production never
/// ships: the bare sheet top-aligned on an opaque surface.
///
/// Tapping any of the three CTAs dismisses the sheet, because `show()` pops
/// before it calls back — hot-restart the preview to bring it back.
@JeebPreview(group: 'live_tracking', name: 'Modal presentation', size: _trackingNoShowSheetPhoneBox)
Widget trackingNoShowSheetInModalRoute() => const _TrackingNoShowSheetModalPresentation();

/// The same modal route inside the smallest phone the app supports, 320 × 568.
///
/// The height ceiling, made visible. At 100% the sheet takes 424 of the 568 pt
/// (measured; less with the production face) and what is left of the map above
/// it is all the context the customer keeps while deciding. At 200% the same
/// content wants 904 pt — the sheet is already pinned to the top of the phone
/// by then, and the [Column] has no scroll fallback, so the **EN 200% text**
/// rendering of this state overflows INSIDE the simulated phone. That overflow
/// belongs to the widget, not to the canvas box: `isScrollControlled: true`
/// caps the sheet at the screen height and there is nothing below it to give.
@JeebPreview(group: 'live_tracking', name: 'Small phone · modal', size: Size(360, 620))
Widget trackingNoShowSheetSmallPhone() => Center(
      child: SizedBox(
        width: _trackingNoShowSheetSmallPhoneSize.width,
        height: _trackingNoShowSheetSmallPhoneSize.height,
        child: const _TrackingNoShowSheetModalPresentation(),
      ),
    );
