/// Widget previews for [OfferAcceptSheet] — run with
/// `flutter widget-preview start`.
///
/// JM-029 `offer-accept-confirm` is the D11/D71 comprehension gate: the one
/// surface between "I like this bid" and an irreversible accept that captures
/// the fee and closes every losing offer. Almost everything that has gone wrong
/// with it went wrong in **copy and state**, not in the accept call — a
/// past-tense title (SW-14), a raw `jeeb-<hash>` where a name belongs (W6/SW-08),
/// and a failed accept that silently stopped the spinner and said nothing
/// (sprint-009 scenario #7). Those are exactly the things you only catch by
/// looking, which is what these previews are for.
///
/// **Network-free by construction.** Two seams are used and neither can reach a
/// gateway:
///
/// * `initialState:` presets the [OfferAcceptCubit]'s state, so the submitting
///   and failed states are reached without driving `confirm()` at all.
/// * `repository:` takes [_CannedOffersRepository], a local fake with no
///   transport of any kind, so the Confirm button in the canvas resolves against
///   canned data instead of falling through to DI / [FakeOffersRepository].
///
/// Fixture data is lifted from `test/features/client_offers/offer_accept_sheet_test.dart`
/// and `..._tense_test.dart` — the Kamal Hajj / `offer-001` / $6.00 offer and the
/// `jeeb-e1a35ea8a520` synthetic handle — so the preview and the widget tests
/// stay directly comparable.
///
/// **What the matrix shows that a widget test does not.**
///
/// * *EN 200% text* — **this is the one that finds something.** The sheet's
///   [Column] has no scroll fallback (same shape as
///   `ConfirmDeliveryActionSheet`), and `showModalBottomSheet(isScrollControlled:
///   true)` grants height, it does not add scrolling. Measured heights of the
///   sheet at 390 pt wide: idle **328 → 564** pt from 1.0 to 2.0 text; with the
///   BR-10 capacity banner **468 → 924** pt, i.e. a hard
///   `RenderFlex overflowed by 160 pixels` against an 844 pt phone, and by
///   **516 pt** on a 320×568 one. What overflows is the bottom of the stack: the
///   Confirm and Cancel CTAs. See the note on
///   [offerAcceptSheetFailedAtCapacity].
/// * *AR RTL dark* — the fee is the one string that must NOT mirror. It is
///   wrapped in a U+2066/U+2069 LTR isolate by `MoneyFormat`, so `$6.00` has to
///   stay `$6.00` and never render as `6.00$`. The rest of the sheet mirrors on
///   its own (`EdgeInsetsDirectional` padding; the banner's [Row] takes its
///   direction from the ambient [Directionality]), and the dark palette is
///   comfortable throughout — the two roles worth a number are the fee/handle
///   `primary` on `surface` at **10.85:1** and the banner's `onErrorContainer`
///   on `errorContainer` at **7.24:1**.
///
/// Measurements above come from `flutter test`, whose substituted test font is
/// wider and taller than the production Inter face, so treat them as an upper
/// bound on the real device — except the 320 pt overflow, which is far past any
/// font-metric slack.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/client_offers/application/offer_accept_state.dart';
import '../../features/client_offers/domain/jeeber_vehicle.dart';
import '../../features/client_offers/domain/offer.dart';
import '../../features/client_offers/domain/offers_repository.dart';
import '../../features/client_offers/presentation/widgets/offer_accept_sheet.dart';

/// Phone width, with room for the idle stack (drag handle → title → fee → D71
/// note → two 48 pt CTAs), measured at 328 pt.
///
/// Deliberately NOT sized to fit the matrix's 200%-text rendering, unlike
/// `ConfirmDeliveryActionSheet`'s box: that rendering is 564 pt and there is no
/// phone-shaped box that would contain it *and* the error states. The stripes it
/// paints in the canvas are the widget's problem, not the canvas's.
const Size _sheetBox = Size(390, 400);

/// The same stack plus the inline error banner — 408 pt for the one-line
/// request-closed copy, 468 pt for the three-line BR-10 capacity copy.
const Size _sheetWithErrorBox = Size(390, 500);

/// A repository with no transport at all.
///
/// The sheet resolves its repository as "the explicit one, else the
/// DI-registered `OffersRepository`, else a `FakeOffersRepository`". Passing
/// this explicitly closes that chain: a preview must never depend on whether
/// the canvas happened to build the DI graph, and `FakeOffersRepository` —
/// while itself in-memory — is production code with a randomised seed and a
/// wall-clock drip feed, which is not what a preview fixture should be.
///
/// `fetchOffers` is never called by this sheet (the review list owns the read);
/// it is implemented only to satisfy the interface.
class _CannedOffersRepository implements OffersRepository {
  const _CannedOffersRepository({this.failure});

  /// When set, `acceptOffer` throws this instead of succeeding — so tapping
  /// Confirm in the canvas reaches the inline error banner for real.
  final OffersFailure? failure;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async =>
      const OffersSnapshot(
        offers: <Offer>[],
        windowExpiresAt: null,
        requestIsOpen: true,
      );

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    final OffersFailure? f = failure;
    if (f != null) throw OffersRepositoryException(f);
    return const OfferAcceptResult(
      conversationId: 'conv-preview-accepted',
      deliveryId: 'dlv-preview-001',
    );
  }
}

/// The offer under confirmation. Defaults reproduce the fixture the JM-029
/// widget tests use.
Offer _offer({
  String jeeberName = 'Kamal Hajj',
  double fee = 6.0,
  String currency = 'USD',
}) =>
    Offer(
      id: 'offer-001',
      jeeberId: 'user-jeeber-002',
      jeeberName: jeeberName,
      fee: fee,
      currency: currency,
      etaMinutes: 20,
      vehicle: JeeberVehicle.scooter,
      rating: 4.8,
      ratingCount: 42,
      // Fixed, never `DateTime.now()`: a preview that changes between two
      // renders is a preview you cannot diff.
      submittedAt: DateTime(2026, 6, 18, 9, 12),
    );

/// Mounts the sheet the way `showModalBottomSheet` presents it — bottom-anchored
/// content on the surface colour — without needing a [Navigator] to push onto.
///
/// Mirrors `_sheetHost` in `lib/devtool/catalog/entries/batch_02_entries.dart`
/// so the catalog and the canvas frame the same widget the same way. The sheet
/// is *content*, not a route: it renders a bare [Column] and relies on its host
/// for the scrim and the rounded top corners.
Widget _hosted(
  Offer offer, {
  OfferAcceptState? initialState,
  OffersFailure? failure,
}) =>
    Align(
      alignment: Alignment.bottomCenter,
      child: OfferAcceptSheet(
        offer: offer,
        requestId: 'req-client-001-offers',
        repository: _CannedOffersRepository(failure: failure),
        initialState: initialState,
        // No-ops on purpose. Production pops the sheet and navigates to
        // order-chat; neither belongs in a canvas.
        onConfirmed: (OfferAcceptResult _) {},
        onCancelled: () {},
      ),
    );

/// The default reading: a real Jeeber name, a small USD fee, nothing in flight.
///
/// The title must be a **question** — "Accept Kamal Hajj's offer?" — and it is
/// the SW-14 regression that makes this worth looking at rather than assuming.
/// The slot used to borrow `chatSystemOfferAcceptedNamed` ("{name}'s offer was
/// accepted"), a chat system message written to narrate an accept that had
/// already happened, so the sheet reported a decision the customer had not made
/// yet while the button below it was still asking them to make it. If this ever
/// renders past tense again, the copy has regressed.
@JeebPreview(name: 'Idle · named Jeeber', size: _sheetBox)
Widget offerAcceptSheetIdle() => _hosted(_offer());

/// The accept POST is in flight — the B-01 accept-exactly-ONE lock, made
/// visible.
///
/// While `isSubmitting` the sheet is deliberately non-dismissible
/// (`PopScope(canPop: false)` plus `enableDrag: false` on the route) and both
/// CTAs go inert, because the hole this closed was a user bailing mid-POST and
/// going back to accept a SECOND offer.
///
/// Two things this rendering shows that no assertion in the test file does.
///
/// **The spinner is the ONLY in-flight signal, and it is silent.** `text:` is
/// set to `chatOfferAccepting` ("Accepting…" / "جاري القبول…") while submitting,
/// but `OmdsLoadingButton` renders `OmdsButtonLoading` *instead of* `text`
/// whenever `isLoading` — so that string is translated in both ARBs and never
/// appears on screen. The surrounding `Semantics` keeps `label:
/// l10n.chatOfferAccept` unconditionally and the child is `ExcludeSemantics`, so
/// a screen reader announces a plain "Accept Offer" button that does nothing:
/// the B-01 lock is visible but not audible.
///
/// **The swap must not resize the button.** It is animated, so a height change
/// across label→spinner reads as a jump. The indicator itself is `onPrimary`
/// over `primary` dimmed to 60% — 3.26:1 dark / 4.70:1 light, i.e. it clears
/// WCAG 1.4.11's 3:1 non-text floor but not by much in dark.
@JeebPreview(name: 'Submitting · B-01 lock', size: _sheetBox)
Widget offerAcceptSheetSubmitting() => _hosted(
      _offer(),
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.submitting,
      ),
    );

/// sprint-009 scenario #7: the accept race the customer actually loses.
///
/// Another accept closed the auction first, so the gateway answers 409
/// `request_not_open`. The pre-fix sheet only listened for success — the spinner
/// simply stopped and nothing was said — which is the single worst outcome on a
/// surface whose whole job is comprehension. The inline banner is the fix, and
/// the CTAs stay live underneath it: Confirm is retryable, Cancel returns to the
/// review list, which reloads and shows the closed banner.
@JeebPreview(name: 'Failed · request closed (409)', size: _sheetWithErrorBox)
Widget offerAcceptSheetFailedRequestClosed() => _hosted(
      _offer(),
      failure: OffersFailure.requestNotOpen,
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.failed,
        error: OffersFailure.requestNotOpen,
      ),
    );

/// BR-10 `too-many-active-deliveries`, and the longest error copy the sheet can
/// show.
///
/// This is the distinct-copy half of fix/offer-accept-409-mislabel: the winning
/// Jeeber is already at their concurrent-delivery cap, so the OFFER is still
/// pending upstream and the sheet must NOT say "this offer is no longer
/// available". It says "…Choose another offer." instead — 75 characters set next
/// to a fixed-size [Icon] in a plain [Row], and the longest string this widget
/// can be asked to lay out.
///
/// **This state is where the 200%-text rendering breaks, and the break is real.**
/// The sheet measures 468 pt at 1.0 and 924 pt at 2.0; on an 844 pt phone that
/// is `A RenderFlex overflowed by 160 pixels on the bottom` (80 in AR, whose
/// copy is shorter), and on a 320×568 phone it is 516 pixels. The [Column] has
/// no scroll fallback and `showModalBottomSheet` does not add one, so what is
/// clipped is the bottom of the stack — **both CTAs**. A customer at large text
/// who loses the accept race is shown an error they can neither retry nor
/// dismiss.
@JeebPreview(name: 'Failed · Jeeber at capacity', size: _sheetWithErrorBox)
Widget offerAcceptSheetFailedAtCapacity() => _hosted(
      _offer(),
      failure: OffersFailure.jeeberAtCapacity,
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.failed,
        error: OffersFailure.jeeberAtCapacity,
      ),
    );

/// W6/SW-08 regression guard: a phone-only Jeeber has no real name, only a
/// synthetic handle (`jeeb-<hash>`).
///
/// The title runs it through `displayNameOrNull` and falls back to
/// `offersCardJeeberFallback` — "New Jeeber" / "جِيبر جديد". If this preview ever
/// renders "Accept jeeb-e1a35ea8a520's offer?", the suppression has broken on
/// the one screen where the customer is being asked to trust a stranger with
/// their money.
@JeebPreview(name: 'Synthetic handle suppressed', size: _sheetBox)
Widget offerAcceptSheetSyntheticHandle() =>
    _hosted(_offer(jeeberName: 'jeeb-e1a35ea8a520'));

/// The content ceiling: the longest plausible name against the longest plausible
/// fee.
///
/// A six-figure LBP quote is not hypothetical — LBP is a live currency here and
/// `MoneyFormat` groups it as `LBP 4,500,000.00`, which is 17 characters set in
/// `headlineSmall` and bold. Paired with a name that wraps the title, this is
/// where the sheet is widest and tallest at once: 384 pt at 1.0 text, and
/// **836 pt at 200%** — eight pixels short of an 844 pt phone, with no error
/// banner shown. That is the margin the state above spends.
///
/// The AR RTL rendering is the load-bearing one: the fee carries a U+2066 LTR
/// isolate precisely so the amount does not reorder under RTL, and a long Latin
/// name inside an Arabic question sentence is the classic bidi-reorder case.
@JeebPreview(name: 'Long name · LBP fee', size: _sheetWithErrorBox)
Widget offerAcceptSheetLongContent() => _hosted(
      _offer(
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        fee: 4500000,
        currency: 'LBP',
      ),
    );
