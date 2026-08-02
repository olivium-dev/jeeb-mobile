/// Widget previews for [DeliveryLifecycleBanner] — run with
/// `flutter widget-preview start`.
///
/// The banner takes exactly one input, [DeliveryLifecycle], and that enum has
/// three values — two of which paint a band and one of which deliberately
/// paints nothing (`SizedBox.shrink`). There is no free text and no data to
/// vary: both sentences come from the ARB (`deliveryCompletedBanner`,
/// `deliveryCancelledBanner`). So the axes that can actually break it are the
/// LIFECYCLE it is handed, the WIDTH it is given, and the text scale — the last
/// of which every [JeebPreview] renders for free.
///
/// Production placement is `delivery_status_screen.dart` (`_ReadyView`): the
/// banner is the FIRST child of a stretched `Column` inside a
/// `SingleChildScrollView` padded `Spacing.large` on both sides, and the screen
/// itself adds the `Spacing.medium` gap under it only when
/// `snapshot.lifecycle != active`. Every preview below reproduces that exact
/// stack — banner, conditional gap, then the `Delivery #<id>` subtitle row —
/// so the canvas shows the width the banner really gets (350 dp on a 390 dp
/// phone, not the full canvas) and so the collapsed state is visibly a
/// no-paint rather than an empty card.
///
/// Network-free by construction: no cubit, no gateway, no repository. The
/// banner reads nothing but its enum and the ambient theme; the delivery ids
/// are inert strings in the `d-…` shape `test/delivery_status_screen_test.dart`
/// already uses, one per preview so a card cannot silently render a
/// neighbour's fixture.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/delivery_status/domain/delivery_snapshot.dart';
import '../../features/delivery_status/presentation/widgets/delivery_lifecycle_banner.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// The subtitle row the screen paints directly under the banner. It is the
/// only content on the status screen that carries a per-delivery string, which
/// is what lets each preview below be pinned to a state only IT can render.
Widget _deliveryIdSubtitle(String deliveryId) => Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Text(
          AppLocalizations.of(context).deliveryStatusIdSubtitle(deliveryId),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );

/// Rebuilds the banner's production stacking order from `_ReadyView`: the
/// banner(s), the gap the screen inserts ONLY for terminal lifecycles, then the
/// delivery-id subtitle.
///
/// [width] clamps the stack to a device width. The canvas box alone cannot do
/// that, and neither can the render tests — `pumpPreview` uses the default
/// 800x600 viewport and ignores `JeebPreview.size` — so a preview that wants to
/// prove anything about phone-width layout has to clamp itself.
Widget _hosted({
  required List<DeliveryLifecycle> lifecycles,
  required String deliveryId,
  double width = 390,
}) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: width,
      child: Padding(
        // `_ReadyView`'s horizontal padding, so the band is 350 dp at 390 dp.
        padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final DeliveryLifecycle lifecycle in lifecycles) ...<Widget>[
              DeliveryLifecycleBanner(lifecycle: lifecycle),
              // The screen gates its own gap on the same condition the banner
              // gates its paint on. Reproduced verbatim: if the two ever
              // disagree, an active delivery grows a 16 dp hole at the top of
              // the screen, and this is where that would show up.
              if (lifecycle != DeliveryLifecycle.active)
                const SizedBox(height: Spacing.medium),
            ],
            _deliveryIdSubtitle(deliveryId),
          ],
        ),
      ),
    ),
  );
}

/// The success terminal: `completed` on a 390 dp phone.
///
/// Worth looking at for the COLOR ROLE, not the layout. The band used to be the
/// brand tertiary orange and now reads `jeebRoles.successContainer` /
/// `onSuccessContainer` (mint on dark green in light, dark green on mint in
/// dark) — the swap the widget's own comment records. If this card ever comes
/// back orange, that swap has been reverted. The dark rendering of the matrix
/// is the one that matters here: `successContainer` inverts between the two
/// themes, so it is the only pairing not covered by reading the light card.
///
/// Measured at 390 dp: the band is 350 x 64 dp on one line, and 350 x 144 dp at
/// the 200% rendering, where the sentence takes three lines. (Every dimension
/// quoted in this file comes from the render test, which runs on the test
/// fallback font — its glyphs are wider than the bundled Inter, so the line
/// counts are an upper bound, not a promise about the shipped font.)
@JeebPreview(group: 'delivery_status', name: 'Completed', size: Size(390, 240))
Widget deliveryLifecycleBannerCompleted() => _hosted(
      lifecycles: const <DeliveryLifecycle>[DeliveryLifecycle.completed],
      deliveryId: 'd-2481',
    );

/// The failure terminal: `cancelled`, on the M3 `errorContainer` pair.
///
/// This is the state a user lands on after the sender cancels pre-pickup (BR-4)
/// or the gateway cancels for them, so it is read in a moment of friction — the
/// one card where the AR RTL dark rendering's contrast is worth checking
/// deliberately rather than glancing at.
///
/// Its sentence ("Delivery cancelled", 18 chars) is shorter than the completed
/// one, so it is NOT the layout ceiling; the small-phone card below is.
@JeebPreview(group: 'delivery_status', name: 'Cancelled', size: Size(390, 240))
Widget deliveryLifecycleBannerCancelled() => _hosted(
      lifecycles: const <DeliveryLifecycle>[DeliveryLifecycle.cancelled],
      deliveryId: 'd-3067',
    );

/// The state that must render NOTHING: `active`, i.e. every in-flight delivery.
///
/// This is the contract the widget's doc comment states and the one no other
/// test pins — `delivery_status_screen_test.dart` only asserts the banner is
/// PRESENT once the delivery completes. Here the card should show the
/// `Delivery #d-4192` subtitle flush against the top of the box, with no band,
/// no tinted strip and no gap above it. Anything visible in this card is a bug:
/// a terminal banner on a delivery that is still moving would tell the customer
/// their parcel has arrived while the courier is still riding.
///
/// The zero-height collapse also has to survive `CrossAxisAlignment.stretch`,
/// which hands the shrunk box a TIGHT width — a `SizedBox.shrink` under tight
/// width constraints is full-width and 0 dp tall, which is the correct
/// degradation and what this card proves. Measured: 350 x 0 dp.
@JeebPreview(group: 'delivery_status', name: 'Active · collapsed', size: Size(390, 120))
Widget deliveryLifecycleBannerActive() => _hosted(
      lifecycles: const <DeliveryLifecycle>[DeliveryLifecycle.active],
      deliveryId: 'd-4192',
    );

/// Small-phone width (320 dp), the narrowest width the app ships to, carrying
/// the LONGER of the two sentences ("Delivered successfully", 22 chars).
///
/// This is the layout ceiling, and it is the card that contradicts the widget's
/// own description of itself as a "single-line banner". At 320 dp the band is
/// 280 dp wide and the sentence gets 280 − 32 (padding) − 24 (icon) − 12 (gap)
/// = 212 dp. That still fits on one line at 1x (a 64 dp band); at the 200%
/// rendering it wraps and the band grows to 184 dp. The degradation is a WRAP,
/// not a `RenderFlex overflowed` stripe — the `Expanded` around the `Text` and
/// the absence of any height constraint are what buy that.
///
/// Two things to actually look at in the 200% rendering of this card, both
/// pinned by the render test:
///
///   * the check icon does NOT grow with the text. `Icon` takes its default
///     24 dp and the app's theme never sets `IconThemeData.applyTextScaling`,
///     so a 24 dp glyph ends up labelling 28 pt copy.
///   * the `Row` keeps its default `crossAxisAlignment: center`, so once the
///     sentence wraps the icon drifts to the vertical middle of the text block
///     — measured 68 dp below the first line it is supposed to mark. Compare
///     against the 1x card above before deciding that is fine.
@JeebPreview(group: 'delivery_status', name: 'Small phone 320dp', size: Size(320, 260))
Widget deliveryLifecycleBannerSmallPhone() => _hosted(
      lifecycles: const <DeliveryLifecycle>[DeliveryLifecycle.completed],
      deliveryId: 'd-5510',
      width: 320,
    );

/// Both terminal bands in one card, for the only comparison that matters:
/// success container against error container, side by side, in the same theme.
///
/// A single delivery can never be both, so this stack is not reachable through
/// the screen — it is a review card, and it earns its place because the
/// question it answers ("after the role swap, is the success band still
/// obviously not the cancelled band?") cannot be answered by looking at two
/// cards a scroll apart. Both bands are full-bleed, same width, same height,
/// same icon weight; the fill and the ink are the ONLY things carrying the
/// difference between "your parcel arrived" and "your delivery was cancelled",
/// which is exactly the kind of meaning-by-colour-alone that a side-by-side
/// reading catches. The AR RTL DARK rendering is the one to check: dark
/// `successContainer` (#14532D) is the darkest of the four fills.
@JeebPreview(group: 'delivery_status', name: 'Terminal pair · contrast', size: Size(390, 300))
Widget deliveryLifecycleBannerTerminalPair() => _hosted(
      lifecycles: const <DeliveryLifecycle>[
        DeliveryLifecycle.completed,
        DeliveryLifecycle.cancelled,
      ],
      deliveryId: 'd-6733',
    );
