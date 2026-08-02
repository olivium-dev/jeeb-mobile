/// Widget previews for [GpsPermissionBanner] — run with
/// `flutter widget-preview start`.
///
/// The banner carries exactly ONE piece of data — the boolean
/// [GpsPermissionBanner.needsSystemSettings] — plus two callbacks. That boolean
/// swaps BOTH the body copy and the CTA (re-run the in-app prompt vs. open the
/// OS settings page), and picking the wrong one re-creates the defect the
/// banner exists to end: on Android 11+ a "Try again" fires a request the
/// platform silently drops, so the jeeber taps a button that cannot work while
/// the customer's tracking map stays empty. Every preview below varies that
/// boolean, the WIDTH the band is handed, and the chrome it is stacked in —
/// there is nothing else in this widget that can break.
///
/// Network-free by construction: no cubit, no repository, no gateway. The
/// widget takes plain values and the two callbacks are no-ops here. The
/// fixtures are the two states §4 of
/// `test/features/background_gps/background_location_permission_test.dart`
/// already asserts — a parked uploader with `gpsNeedsSystemSettings: true`
/// ("Open settings") and a recoverable denial without it ("Allow location").
///
/// Production placement is `active_delivery_jeeber_screen.dart`
/// (`_ReadyContent`): the FIRST child of the delivery `ListView`, inside
/// `EdgeInsets.all(Spacing.medium)`, gated on `state.isGpsBlocked`, and
/// deliberately not dismissible. Each preview pins an explicit device width,
/// because [jeebPreviewHost] stretches its child to the host and the heights
/// quoted below are only reproducible at a known width.
///
/// WHAT THE MATRIX EXPOSES (measured in the render test, not guessed):
///
/// * **The CTA overflows at 200% text.** `OMDSOutlinedButton` lays its label
///   out as the lone non-flex child of a `Row`, which hands it an UNBOUNDED
///   width, so the label never wraps and the button reports *"A RenderFlex
///   overflowed by N pixels on the right"*: 75 px for "Allow location" and
///   47 px for "Open settings" at 390 dp, 117 px at 320 dp, 74/46 px for the
///   Arabic labels. The clipped element is the banner's ONLY recovery
///   affordance.
/// * **The icon does not scale.** `Icons.location_off_outlined` is pinned at
///   `Sizes.large` (20 dp) and stays 20 dp while the title beside it doubles,
///   so the one glyph that says "location is off" shrinks to a footnote
///   exactly for the users who asked for larger text.
/// * **RTL mirrors correctly.** `EdgeInsetsDirectional` and the
///   `AlignmentDirectional` CTA hold: in Arabic the icon takes the right-hand
///   (leading) edge and the copy flows away from it, with no hardcoded
///   left/right anywhere.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../features/active_delivery_jeeber/presentation/widgets/delivery_status_stepper.dart';
import '../../features/active_delivery_jeeber/presentation/widgets/gps_permission_banner.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// The widest phone the app targets, and the width every quoted height below
/// was measured at.
const double _phoneWidth = 390;

/// The narrowest width the app ships to.
const double _smallPhoneWidth = 320;

/// The banner at a pinned device width, laid out from the leading edge.
///
/// [width] is pinned rather than inherited because the preview host stretches
/// its child: without it the band would be as wide as the canvas, the body
/// would never wrap, and the widths at which this layout actually gets tight
/// would never be reached.
///
/// The scroll view is not decoration either. The band's inner `Column` is
/// `mainAxisSize.max`, so handed a BOUNDED height it stretches to fill it — in
/// a 600 dp canvas box a 216 dp band renders 600 dp tall with the CTA stranded
/// at the bottom, which is a preview artefact, not a real state. Production
/// hands it the unbounded height of a `ListView` child; this reproduces that,
/// and lets the 200% rendering scroll instead of reporting a bottom overflow
/// the real screen never has.
Widget _hosted({required bool needsSystemSettings, double width = _phoneWidth}) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: width,
      child: SingleChildScrollView(
        child: GpsPermissionBanner(
          needsSystemSettings: needsSystemSettings,
          onOpenSettings: () {},
          onRetry: () {},
        ),
      ),
    ),
  );
}

/// The recoverable denial: the grant can still be won from inside the app, so
/// the CTA is "Allow location" and tapping it re-runs the escalation.
///
/// This is what a jeeber sees after dismissing the OS prompt once, and it is
/// the only state whose CTA is worth tapping — every other path has to go
/// through the settings app. If this variant ever renders "Open settings", a
/// jeeber who could have been fixed in one tap is sent on a four-screen detour
/// instead.
///
/// Measured at 390 dp: 216 dp tall at 1.0 in both locales, 716 dp (EN) / 596 dp
/// (AR) at the 200% rendering. The band has no fixed height, so the body
/// reflows and pushes it taller rather than clipping — that half degrades
/// correctly. The CTA does not: see the library note.
@JeebPreview(name: 'Recoverable denial', size: Size(_phoneWidth, 240))
Widget gpsPermissionBannerRecoverable() => _hosted(needsSystemSettings: false);

/// The state the whole live-tracking wave was built for: a permanent denial, or
/// the Android 11+ "Allow all the time" upgrade, which the platform will only
/// grant from its own settings page.
///
/// The body gains a sentence ("Open settings and set location access to 'Allow
/// all the time'") and the CTA becomes "Open settings". Offering "Try again"
/// here would fire a request the OS drops on the floor — the silent park this
/// banner exists to end — so the two halves must flip TOGETHER. A rendering
/// with the settings body and the retry CTA, or the reverse, is a defect and
/// not a copy nit; the render test pins both directions.
///
/// Measured at 390 dp: 256 dp (EN) / 236 dp (AR) at 1.0, and 836 dp / 716 dp at
/// the 200% rendering — 40 dp taller than the recoverable state at 1.0, because
/// the longer body wraps two extra lines.
@JeebPreview(name: 'Needs system settings', size: Size(_phoneWidth, 280))
Widget gpsPermissionBannerNeedsSystemSettings() =>
    _hosted(needsSystemSettings: true);

/// Longest plausible content at the narrowest width the app ships to: the
/// settings body on a 320 dp phone.
///
/// This is where the copy wraps hardest — 288 dp of inner width for the longest
/// string the banner can show, measured 316 dp (EN) / 296 dp (AR) tall at 1.0
/// and 956 dp at the 200% rendering, which is more than a small phone's whole
/// viewport for a single band.
///
/// It is also where the CTA breaks worst. The label is laid out unbounded
/// inside `OMDSOutlinedButton`'s `Row`, so it does not wrap: at 200% "Open
/// settings" wants 365 dp against the 248 dp this band can give it and
/// overflows by 117 px. Arabic ("فتح الإعدادات") hits the same wall 1 px
/// earlier. Every other part of the band survives this width; the button is the
/// piece that does not.
@JeebPreview(name: 'Small phone 320dp', size: Size(_smallPhoneWidth, 340))
Widget gpsPermissionBannerSmallPhone() => _hosted(
      needsSystemSettings: true,
      width: _smallPhoneWidth,
    );

/// The production composition: the banner as the FIRST item of the delivery
/// `ListView`, above the progress stepper, at `Spacing.medium` list padding.
///
/// This answers the question the isolated states cannot — does the band read as
/// an alarm on the delivery screen, or as one more card? It is
/// `colorScheme.errorContainer` with an `OmdsBorderRadius.medium` corner
/// directly on the scaffold surface, and the stepper below it is the content it
/// has to out-shout. The stepper is fixed at [JeeberDeliveryStatus.inTransit]
/// because that is when the uploader is supposed to be streaming; the banner is
/// not reachable before an active delivery exists.
///
/// It is also the only preview where the band is NOT full-bleed: the list
/// padding takes 16 dp off each edge, so it is 358 dp of a 390 dp screen —
/// 236 dp tall (EN) / 216 dp (AR) at 1.0, and 756 dp / 596 dp at 200%, at which
/// point the stepper it is warning about has been pushed entirely off-screen.
@JeebPreview(name: 'First item in delivery list', size: Size(_phoneWidth, 560))
Widget gpsPermissionBannerInDeliveryList() => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: _phoneWidth,
        child: Builder(
          builder: (BuildContext context) {
            final AppLocalizations l10n = AppLocalizations.of(context);
            return ListView(
              padding: const EdgeInsets.all(Spacing.medium),
              children: <Widget>[
                GpsPermissionBanner(
                  needsSystemSettings: false,
                  onOpenSettings: () {},
                  onRetry: () {},
                ),
                const SizedBox(height: Spacing.large),
                OMDSSectionCard(
                  title: l10n.activeDeliveryProgressTitle,
                  showDivider: false,
                  content: DeliveryStatusStepper(
                    currentStatus: JeeberDeliveryStatus.inTransit,
                    isTransitioning: false,
                    onAdvance: () {},
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
