/// Widget previews for [OfferAcceptedBanner] — run with
/// `flutter widget-preview start`.
///
/// The banner is a pure-props widget: three nullable callbacks and a name. It
/// holds no state, reads no cubit and touches no repository, so these previews
/// are network-free by construction rather than by the guard in
/// [jeebPreviewHost].
///
/// It paints NO data of its own — every string it shows comes from the ARB
/// ("Offer accepted!", the supporting sentence, and the two CTA labels), and
/// `jeeberName` is never rendered. So the axes that can actually break it are
/// the CALLBACK COMBINATION it is handed (which decides whether the supporting
/// sentence has room to be painted, and how many 48 dp CTAs share the row), the
/// WIDTH it is given, and the text scale — the last of which every
/// [JeebPreview] renders for free.
///
/// Production placement is `chat_screen.dart` (`_ChatBody.header`), gated on
/// `phase == accepted && !dismissed && winnerName != null`, where the winner
/// name is read back off the last `offerAccepted` system notice in the thread
/// (`ChatScreen._extractWinnerName`). Every preview therefore carries that
/// notice under the banner: it is the message that gates the banner, it is
/// where `jeeberName` comes from, and it is the only place the Jeeber's name
/// actually reaches the screen.
///
/// The two CTAs are role-scoped and mutually exclusive in the two hosts that
/// exist today (`chat_detail_screen.dart:1732-1740` picks one on `isJeeber`):
///
///   * `onStartActiveDelivery` — Jeeber only, pushes the active-delivery route.
///   * `onTrackOrder` — client only, and null until the accept response has
///     surfaced a delivery id, so the CTA is never a dead end (the G5 fix
///     asserted in `test/features/chat/offer_accept_track_test.dart`).
///
/// Fixture names ('Kamal Hajj', 'Rana', 'Nour', 'Ziad', 'Layla') are the ones
/// the existing chat widget tests already use; each state gets its own so a
/// preview cannot silently render a neighbour's fixture.
library;

import 'package:flutter/material.dart';

import '../../features/chat/domain/delivery_chat_message.dart';
import '../../features/chat/presentation/widgets/chat_fee_banner.dart';
import '../../features/chat/presentation/widgets/chat_message_bubble.dart';
import '../../features/chat/presentation/widgets/offer_accepted_banner.dart';
import '../harness/jeeb_preview.dart';

/// Frozen instant for every fixture, so the system notice's clock never drifts
/// between runs of the canvas.
final DateTime _frozenAt = DateTime(2026, 6, 15, 9, 41);

/// The system notice that GATES the banner in production and supplies its
/// `jeeberName`. Without an `offerAccepted` message in the thread,
/// `_extractWinnerName` returns the counterpart name (or null) and
/// `showAcceptedBanner` is false — so no preview omits it.
DeliveryChatMessage _acceptedNotice(String jeeberName) =>
    DeliveryChatMessage.offerAccepted(
      id: 'sys-accepted-$jeeberName',
      sentAt: _frozenAt,
      payload: SystemOfferPayload(
        offerId: 'offer-$jeeberName',
        jeeberId: 'j-$jeeberName',
        jeeberName: jeeberName,
      ),
    );

/// Builds the banner in its production stacking order: chrome above, the
/// gating system notice below.
///
/// [width] constrains the whole stack to a device width. The canvas box alone
/// cannot do that and neither can the render tests — `pumpPreview` uses the
/// default 800x600 viewport and ignores `JeebPreview.size` — so a preview that
/// wants to prove anything about phone-width layout has to clamp itself.
Widget _hosted({
  required String jeeberName,
  bool dismissable = true,
  bool startDelivery = false,
  bool trackOrder = false,
  List<Widget> chrome = const <Widget>[],
  double? width,
}) {
  final Widget body = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      ...chrome,
      OfferAcceptedBanner(
        jeeberName: jeeberName,
        onDismiss: dismissable ? () {} : null,
        onStartActiveDelivery: startDelivery ? () {} : null,
        onTrackOrder: trackOrder ? () {} : null,
      ),
      ChatMessageBubble(message: _acceptedNotice(jeeberName)),
    ],
  );
  if (width == null) return body;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, child: body),
  );
}

/// The client's first reading of an accepted offer: no delivery id yet, so no
/// CTA — the state the G5 fix deliberately leaves CTA-less rather than shipping
/// a button that goes nowhere.
///
/// It is also the ONLY state that paints the supporting sentence: `showBody` is
/// `!hasCta`, so with no CTA sharing the line there is room for
/// "You are now chatting with your Jeeber." In every other state below that
/// sentence exists only on the row's accessible name — which is the half of the
/// b02 redesign a screenshot review cannot see and a screen reader can.
///
/// Measured with the real bundled Inter at 390 dp: the band is 64 dp on one
/// line and 120 dp at the 200% rendering, where the sentence takes its full
/// two-line clamp. The box below fits the whole stack (banner + notice) at 2x.
@JeebPreview(group: 'chat', name: 'Client · no CTA yet', size: Size(390, 220))
Widget offerAcceptedBannerClientNoCta() => _hosted(jeeberName: 'Kamal Hajj');

/// The Jeeber leg, in its real chrome: the balance-deduction band sits directly
/// on top of this banner (`_ChatBody.header` emits `feeNotice` first), so two
/// full-bleed bands share an edge.
///
/// This is the pairing the b02 redesign is about. The fee band is still the
/// saturated navy `secondaryContainer`; the banner underneath is now the
/// low-chroma success container, which is what stops the top of the thread
/// reading as one solid slab. If this preview ever shows two saturated bands
/// again, the role swap has been reverted.
///
/// The tallest state of the five: measured 156 dp of chrome at 1x and 316 dp at
/// the 200% rendering, because both bands grow independently.
@JeebPreview(group: 'chat', name: 'Jeeber · start delivery', size: Size(390, 340))
Widget offerAcceptedBannerJeeberStartDelivery() => _hosted(
      jeeberName: 'Rana',
      startDelivery: true,
      chrome: const <Widget>[ChatFeeBanner(amount: r'$0.50')],
    );

/// The client leg once the accept response surfaced a delivery id (G5): the
/// row becomes `icon · title · Track my order · ×`, and the supporting sentence
/// drops out of the paint to make room.
///
/// Worth looking at beside the state above: both are one 48 dp row (a 64 dp
/// band at 390 dp), but this one is the customer's only in-chat route into live
/// tracking, so its label is the one that has to survive the 200% rendering. It
/// is also the longest of the two CTA labels — 262 dp at 200%, against 239 dp
/// for "Start delivery" — which is why the small-phone state below is this CTA
/// and not the Jeeber's.
@JeebPreview(group: 'chat', name: 'Client · track order', size: Size(390, 200))
Widget offerAcceptedBannerClientTrackOrder() =>
    _hosted(jeeberName: 'Nour', trackOrder: true);

/// Small-phone width (320 dp), the narrowest width the app ships to, carrying
/// the longer of the two CTAs.
///
/// This is the width the `Wrap` in the banner exists for. The code comment
/// records the CTA dropping to a second line at text scale 1.3 on a 411 dp
/// phone; at 320 dp it happens at 1.0x already — measured, the band is 88 dp
/// here against 64 dp at 390 dp, i.e. two runs instead of one. The degradation
/// is a WRAP and not a `RenderFlex overflowed` stripe, and because the preview
/// clamps its own width the render test can assert that rather than trusting
/// the canvas.
///
/// It is also where the 200% rendering bites: the padding leaves each Wrap
/// child at most 320 − 16 − 4 − 48 = 252 dp, and this CTA wants 262 dp at 200%,
/// so the label ellipsises. That is the one thing to look at in this card.
@JeebPreview(group: 'chat', name: 'Small phone 320dp', size: Size(320, 220))
Widget offerAcceptedBannerSmallPhone() => _hosted(
      jeeberName: 'Ziad',
      trackOrder: true,
      width: 320,
    );

/// The widest the row can get: icon, title, BOTH CTAs and the dismiss target.
///
/// Today's two hosts pick one CTA on role, so this combination is not reachable
/// through them — but `ChatScreen` forwards both fields to the banner blindly,
/// and the banner's own contract accepts both, so it must degrade rather than
/// overflow. It is also the fastest regression guard for the `IntrinsicWidth`
/// around each CTA: `OmdsPrimaryButton` centres its content and claimed the
/// whole line (measured 343 dp) before that wrapper was added, so if it comes
/// off, this is the state where two full-width buttons collide first.
///
/// Measured at 390 dp: 116 dp at 1x and 160 dp at the 200% rendering — the CTAs
/// take a run of their own and the band roughly doubles, which is the correct
/// degradation, not an overflow.
@JeebPreview(group: 'chat', name: 'Both CTAs', size: Size(390, 240))
Widget offerAcceptedBannerBothCtas() => _hosted(
      jeeberName: 'Layla',
      startDelivery: true,
      trackOrder: true,
    );
