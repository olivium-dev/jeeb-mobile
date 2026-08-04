import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// The sheet's gutter — the 24 band, with the 8 lead the drag-handle-less
/// sheets use.
const EdgeInsetsGeometry _kNoShowBand = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.small,
  Spacing.xLarge,
  Spacing.xLarge,
);

/// MIDNIGHT: this sheet never had a pass — it was still a bare Material sheet
/// over the theme's `titleLarge`/`bodyMedium` ramp and three `OmdsPrimaryButton`
/// pills. It now mounts the `sheet` field and the kit CTA ladder; the three
/// frozen semantics ids and every string are unchanged.
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
      // Shape/background/scrim come from `bottomSheetTheme`; the old local
      // `Spacing.large` (24) override was off the radii ladder entirely.
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantics = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Semantics(
      identifier: 'tracking_noshow_sheet',
      container: true,
      explicitChildNodes: true,
      child: JeebMidnightField(
        variant: JeebFieldVariant.sheet,
        animateDecor: false,
        child: SafeArea(
          child: Padding(
            padding: _kNoShowBand,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.trackingNoShowTitle,
                  style: context.jeebText.h2
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: Spacing.small),
                Text(
                  l10n.trackingNoShowBody,
                  style: context.jeebText.body
                      .copyWith(color: semantics.mutedText),
                ),
                const SizedBox(height: Spacing.large),
                // Descending emphasis, unchanged in order and copy — only the
                // ladder is now the kit's, so no orange is spent on a recovery.
                Semantics(
                  identifier: 'tracking_noshow_reassign_cta',
                  button: true,
                  child: JeebCtaButton.primary(
                    label: l10n.trackingNoShowReassignCta,
                    onTap: onReassign,
                    expand: true,
                  ),
                ),
                const SizedBox(height: Spacing.small),
                Semantics(
                  identifier: 'tracking_noshow_rebroadcast_cta',
                  button: true,
                  child: JeebCtaButton.outline(
                    label: l10n.trackingNoShowRebroadcastCta,
                    onTap: onRebroadcast,
                    expand: true,
                  ),
                ),
                const SizedBox(height: Spacing.small),
                Semantics(
                  identifier: 'tracking_noshow_keep_cta',
                  button: true,
                  child: JeebCtaButton.text(
                    label: l10n.trackingNoShowKeepCta,
                    onTap: onKeepWaiting,
                    expand: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

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
/// Written as a widget rather than an inline [MediaQuery] so `MediaQuery.of`
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
/// The local [Navigator] is what makes this self-contained: `show()` needs a
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    // Both callbacks are no-ops: in production they navigate to
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
/// Deliberately text-free, so every string a preview test pins can only have
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
                    // The courier disc really is accent on the live map.
                    color: context.jeebRoles.accent,
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
/// Three stacked full-bleed CTAs in descending emphasis — filled, outlined,
@JeebPreview(group: 'live_tracking', name: 'Bare sheet · 390 pt', size: _trackingNoShowSheetBox)
Widget trackingNoShowSheetDefault() => _trackingNoShowSheetHosted();

/// 320 pt — where the CTA labels stop fitting on one line.
/// The pill is a fixed 48 pt at every text scale and the label sits in a
@JeebPreview(group: 'live_tracking', name: 'Narrow phone · 320 pt', size: _trackingNoShowSheetNarrowBox)
Widget trackingNoShowSheetNarrowPhone() => _trackingNoShowSheetHosted(width: _trackingNoShowSheetSmallPhoneSize.width);

/// The sheet with a gesture-navigation home indicator under it.
/// [TrackingNoShowSheet] wraps its column in a [SafeArea], and this is the only
@JeebPreview(group: 'live_tracking', name: 'Gesture-bar inset', size: _trackingNoShowSheetBox)
Widget trackingNoShowSheetGestureBar() => const _TrackingNoShowSheetSimulatedSystemInset(
      bottomDp: _trackingNoShowSheetHomeIndicatorDp,
      child: _TrackingNoShowSheetBareSheet(),
    );

/// The sheet as the customer actually meets it: pushed by
/// [TrackingNoShowSheet.show] over the dimmed tracking map.
@JeebPreview(group: 'live_tracking', name: 'Modal presentation', size: _trackingNoShowSheetPhoneBox)
Widget trackingNoShowSheetInModalRoute() => const _TrackingNoShowSheetModalPresentation();

/// The same modal route inside the smallest phone the app supports, 320 × 568.
/// The height ceiling, made visible. At 100% the sheet takes 424 of the 568 pt
@JeebPreview(group: 'live_tracking', name: 'Small phone · modal', size: Size(360, 620))
Widget trackingNoShowSheetSmallPhone() => Center(
      child: SizedBox(
        width: _trackingNoShowSheetSmallPhoneSize.width,
        height: _trackingNoShowSheetSmallPhoneSize.height,
        child: const _TrackingNoShowSheetModalPresentation(),
      ),
    );
