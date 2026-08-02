/// Widget previews for [RecentDeliveryCard] — run with
/// `flutter widget-preview start`.
///
/// [RecentDeliveryCard] is a pure view over one [RecentDeliverySummary]: no
/// cubit, no repository, no image. Every fixture below is a plain value object
/// and `onReorder` is a no-op, so these previews are network-free by
/// construction, not merely by the guard in [jeebPreviewHost].
///
/// The happy-path fixture reuses `test/client_home_cubit_test.dart` (`_recent`:
/// "Mini-market run" / "Hamra, Beirut"), and the degraded fixture reuses what
/// `DioClientHomeRepository._parseRecentDelivery` actually emits for a row with
/// no `title` and no `dropoff.address` — a `Delivery #XXXXXX` reference title
/// and an **empty** destination string.
///
/// ## Read this canvas for one thing: the text column is tiny, and localized
///
/// The row is `icon(24) + 12 + Expanded(text) + 12 + button`, inside 16 pt card
/// padding. The button is NOT flexible — `OmdsPrimaryButton` has a null `width`,
/// so in a [Row] it lays out at its intrinsic label width first and `Expanded`
/// divides what is left. The label is localized, so the *text column width
/// depends on the locale*. Measured at real device widths, not guessed:
///
/// | width           | button (EN / AR) | text column EN | text column AR |
/// |-----------------|-----------------:|---------------:|---------------:|
/// | 390 pt (iPhone) |   144.8 / 186.0  |     165.2 pt   |   **124.0 pt** |
/// | 360 pt (S22)    |   144.8 / 186.0  |     135.2 pt   |    **94.0 pt** |
/// | 320 pt (SE)     |   144.8 / 186.0  |      95.2 pt   |    **54.0 pt** |
///
/// Against that: "Mini-market run" wants **211.5 pt** and "Hamra, Beirut" wants
/// **161.2 pt**. So the *shortest realistic fixture in the repo already
/// ellipsizes on every phone*, and in Arabic — where "إعادة الطلب" is 41 pt
/// wider than "Re-order" — both lines are clipped on every phone, down to about
/// three characters on a 320 pt device.
///
/// At 200% text the button grows but the column does not: EN leaves 53.2 pt,
/// and **AR leaves 0.0 pt and still overflows the card by 30 px** — the title
/// and destination disappear entirely and the canvas shows the stripe. That
/// rendering is in the matrix for every preview below; it is the same card in
/// each, so read it once on `Typical` and then look at content.
///
/// None of this is visible under `test/`: widget tests pump into an 800×600
/// viewport where the text column is 575 pt and everything fits. That gap is the
/// whole reason these `size:` boxes are real phone widths. The preview render
/// tests inherit the same 800 pt viewport and stay green; the clipping is a
/// canvas finding, not a test failure.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/home_client/domain/recent_delivery_summary.dart';
import '../../features/home_client/presentation/widgets/recent_delivery_card.dart';

/// A phone-width box. The card lays out at **80 pt** tall at 390 pt (108 pt at
/// 200% text), so 120 frames all three renderings of the matrix.
const Size _cardBox = Size(390, 120);

/// The same card on a 320 pt phone — the small-device end of the range.
const Size _smallPhoneBox = Size(320, 120);

/// `completedAt` is fixed so nothing here depends on the clock.
///
/// It is also never rendered: the card shows title + destination only, so this
/// value cannot be seen in any preview below.
final DateTime _completedAt = DateTime.utc(2026, 5, 16, 10, 30);

Widget _hosted({
  required String id,
  required String title,
  required String destinationLabel,
}) =>
    RecentDeliveryCard(
      summary: RecentDeliverySummary(
        id: id,
        title: title,
        destinationLabel: destinationLabel,
        completedAt: _completedAt,
      ),
      onReorder: () {},
    );

/// The happy path, straight from `test/client_home_cubit_test.dart`.
///
/// This is the reference rendering the others are read against — and the first
/// surprise: a 15-character title on the widest supported phone is *already*
/// truncated. "Mini-market run" wants 211.5 pt and gets 165.2 pt in English,
/// 124.0 pt in Arabic. Nothing about this fixture is long; the column is short.
@JeebPreview(name: 'Typical', size: _cardBox)
Widget recentDeliveryCardTypical() => _hosted(
      id: 'rd-2f1c',
      title: 'Mini-market run',
      destinationLabel: 'Hamra, Beirut',
    );

/// Real Beirut content: an Arabic title and an Arabic destination.
///
/// The AR RTL rendering of every other preview mirrors the *chrome* while
/// showing English content, which is not what a Lebanese client sees — titles
/// and addresses come back from the gateway in whatever the client typed. This
/// is the state where the mirrored layout and the mirrored content are read
/// together, and where the ellipsis has to land on the **left**.
///
/// It is also the tightest realistic pairing: the Arabic CTA leaves 124.0 pt,
/// and "طلبية سوبرماركت" wants 210.0 pt.
@JeebPreview(name: 'Arabic content', size: _cardBox)
Widget recentDeliveryCardArabicContent() => _hosted(
      id: 'rd-9b30',
      title: 'طلبية سوبرماركت',
      destinationLabel: 'الحمرا، بيروت',
    );

/// Degraded payload: exactly what the Dio parser produces for a completed row
/// that carries neither a `title`/`description` nor a `dropoff.address`.
///
/// Two fallbacks fire at once, and only one of them is real. The title degrades
/// to a friendly reference (`Delivery #CC42E6`) — deliberate, and the reason
/// `friendlyReference` exists. The destination degrades to `''`, which
/// [RecentDeliveryCard] renders as a `Text('')`: a **0 × 16 pt blank line**
/// under the title, plus its 4 pt gap, still occupying the same space a real
/// address would. The card does not shrink and does not say "destination
/// unknown" — it just shows a gap. Put this next to `Typical` in the canvas:
/// same height, one line of information missing with nothing marking it.
@JeebPreview(name: 'Degraded payload', size: _cardBox)
Widget recentDeliveryCardDegradedPayload() => _hosted(
      id: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
      title: 'Delivery #CC42E6',
      destinationLabel: '',
    );

/// Content ceiling: the longest plausible title next to the longest plausible
/// address.
///
/// Both lines are `maxLines: 1` + ellipsis, so the card can only clip — it
/// never wraps and never grows. In 165.2 pt of English column that is
/// "Pharmacy pickup for…"; in 124.0 pt of Arabic column it is roughly the first
/// two words. Because the card is the *"order again"* affordance, a client
/// re-ordering from a truncated title is tapping a button whose subject they
/// cannot fully read.
@JeebPreview(name: 'Long title + long destination', size: _cardBox)
Widget recentDeliveryCardLongContent() => _hosted(
      id: 'rd-7d41',
      title: 'Pharmacy pickup for Mrs. Haddad on Rue Sursock and the bakery '
          'next door',
      destinationLabel:
          'Rue Sursock, near the Sursock Museum, Ashrafieh, Beirut',
    );

/// The same card on a 320 pt phone — a small Android or an SE-class device.
///
/// The fixed-width CTA does not shrink with the viewport, so every pixel lost
/// comes out of the text: 95.2 pt of column in English, **54.0 pt in Arabic**.
/// At that width the Arabic rendering of a normal title shows about three
/// characters before the ellipsis, which is the state to weigh when deciding
/// whether this row should become two lines (text above, CTA below) rather than
/// one.
@JeebPreview(name: 'Small phone (320 pt)', size: _smallPhoneBox)
Widget recentDeliveryCardSmallPhone() => _hosted(
      id: 'rd-4e88',
      title: 'Bakery order',
      destinationLabel: 'Mar Mikhael, Beirut',
    );
