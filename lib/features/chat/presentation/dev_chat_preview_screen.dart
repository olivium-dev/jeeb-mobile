import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/dev_chat_fixture_gateway.dart';
import '../domain/delivery_chat_message.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import 'chat_screen.dart';
import 'widgets/chat_fee_banner.dart';
import 'widgets/confirm_delivery_action_sheet.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/dev_chat_preview_screen_fixtures.dart';

/// Debug-only full-screen host that renders [ChatScreen] for one of the
/// designed chat states, backed by [DevChatFixtureGateway].
///
/// Reached only via the router's `JEEB_DEV_CHAT` seam (see `AppRouter`), which
/// extends the established `JEEB_DEV_*` dart-define pattern (pilot learning
/// #1) so the Figma chat frames can be captured deterministically on the
/// emulator. Never reachable in release.
///
/// Selectors:
///   `sending`               → client's just-sent initial request, pre-offers
///                             (Figma 56535:6469) — single outgoing bubble, no
///                             offer cards, composer present
///   `broadcasting`          → client offers feed (Figma 56535:6659)
///   `accepted` / *          → client accepted thread (Figma 56546:2382)
///   `dm`                    → delivery-man chat (Figma 56539:906)
///   `dm-order-picked`       → delivery-man chat, "Order picked" banner
///                             (Figma 56560:1605)
///   `dm-confirm-picking`    → delivery-man chat + confirm-picking sheet
///                             (Figma 56618:2751)
///   `dm-confirm-heading-off`→ delivery-man chat + heading-off sheet
///                             (Figma 56618:2852)
class DevChatPreviewScreen extends StatelessWidget {
  const DevChatPreviewScreen({super.key, required this.selector});

  final String selector;

  bool get _isDeliveryMan => selector.startsWith('dm');

  ChatFeeBannerTrailing get _bannerTrailing {
    if (selector == 'dm-order-picked') return ChatFeeBannerTrailing.orderPicked;
    if (selector == 'dm') return ChatFeeBannerTrailing.none;
    return ChatFeeBannerTrailing.dismiss;
  }

  DeliveryConfirmKind? get _autoSheet => switch (selector) {
        'dm-confirm-picking' => DeliveryConfirmKind.picking,
        'dm-confirm-heading-off' => DeliveryConfirmKind.headingOff,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    if (_isDeliveryMan) return _DeliveryManPreview(host: this);
    return _clientPreview();
  }

  Widget _clientPreview() {
    final sending = selector == 'sending';
    final broadcasting = selector == 'broadcasting';
    // `sending` and `broadcasting` share the request-feed header (centered
    // order id, no counterpart avatar) and the broadcasting phase semantics
    // (composer visible, no counterpart header). `sending` differs only in the
    // seeded thread: a single outgoing request with no offer cards yet.
    final requestFeed = sending || broadcasting;
    final phase = requestFeed
        ? ConversationPhase.broadcasting
        : ConversationPhase.accepted;
    // No bundled avatar bitmap (dev-only assets must not ship): the accepted
    // header falls back to the OMDS initials avatar, captured deterministically
    // and offline.
    return ChatScreen(
      deliveryId: 'dev-chat',
      counterpartName: requestFeed ? 'ORD-23748' : 'Kamal Hajj',
      gateway: DevChatFixtureGateway(phase: phase, sending: sending),
      pickerService: StubPhotoPickerService(),
    );
  }
}

/// Delivery-man chat preview: fee banner + price/time composer hint, with an
/// optional confirmation sheet auto-opened for the picking / heading-off
/// states so they can be captured without a tap.
class _DeliveryManPreview extends StatefulWidget {
  const _DeliveryManPreview({required this.host});

  final DevChatPreviewScreen host;

  @override
  State<_DeliveryManPreview> createState() => _DeliveryManPreviewState();
}

class _DeliveryManPreviewState extends State<_DeliveryManPreview> {
  static const String _feeAmount = r'$0.5';

  /// Backing delivery for this Jeeber-variant thread. Reused both as the chat
  /// channel id and as the path id for the active-delivery entry point so the
  /// "Start delivery" CTA opens the matching delivery.
  static const String _deliveryId = 'dev-chat-dm';

  @override
  void initState() {
    super.initState();
    final kind = widget.host._autoSheet;
    if (kind != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet(kind));
    }
  }

  Future<void> _openSheet(DeliveryConfirmKind kind) async {
    if (!mounted) return;
    await ConfirmDeliveryActionSheet.show(
      context,
      kind: kind,
      onConfirm: () async {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatScreen(
      deliveryId: _deliveryId,
      counterpartName: 'Sami Fawaz',
      composerHint: AppLocalizations.of(context).chatComposerHintPriceTime,
      feeNotice: ChatFeeNotice(
        amount: _feeAmount,
        trailing: widget.host._bannerTrailing,
        onDismiss: () {},
        onOrderPicked: () {},
      ),
      // ENTRY POINT (jeeber active-delivery): the Jeeber-variant chat is the
      // only place a jeeber-role [ChatScreen] is constructed (feeNotice !=
      // null). The production `/chat/:id` route builds the CLIENT variant via
      // ChatDetailScreen (currentUserId hardcoded to a client, feeNotice null,
      // and it resolves a conversation id rather than carrying the jeeber role
      // + delivery id), so it cannot cleanly supply both signals today. We
      // therefore gate the "Start delivery" CTA on the jeeber variant here,
      // where the delivery id is in scope, and push the active-delivery route.
      onStartActiveDelivery: () =>
          context.push('/jeeber/deliveries/$_deliveryId/active'),
      gateway: DevChatFixtureGateway(
        phase: ConversationPhase.accepted,
        deliveryMan: true,
      ),
      pickerService: StubPhotoPickerService(),
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
// Render tests: test/previews/chat/dev_chat_preview_screen_preview_test.dart
// ===========================================================================
//
// [DevChatPreviewScreen] is a DISPATCHER, not a data surface. It takes one
// string and derives everything from it: which leg to build (client vs
// jeeber), the counterpart name, the conversation phase, whether the fee banner
// gets a dismiss ×, an "Order picked" pill or nothing at all, and which confirm
// sheet auto-opens on the first frame. The rows themselves come from
// [DevChatFixtureGateway], a const in-memory list.
//
// So there is no repository to fake and no cubit to seed here — and no empty,
// loading or error state to preview either. Every selector resolves
// immediately, from memory. What CAN break is the dispatch, and that is what
// these previews are pointed at:
//
//  * **Both dispatch arms end in a silent fallback.** `_isDeliveryMan` is
//    `selector.startsWith('dm')` and the client leg's `switch` closes with
//    `_ => accepted`, so NO selector is ever rejected. A typo does not throw
//    and does not render blank — it renders a different, entirely plausible
//    designed state. [devChatPreviewScreenUnrecognisedSelector] is that hole
//    made visible; it must keep showing the client accepted thread, because the
//    day it shows anything else is the day a capture labelled "sending" is
//    holding the wrong frame. The `dm` half of the same hole is worse and has
//    no preview because it cannot have one: `dm-order-picke` renders as plain
//    [devChatPreviewScreenJeeberAccepted], pixel for pixel, minus the pill.
//  * **The two `dm-confirm-*` selectors push a modal route at mount.** That is
//    this screen's only side effect, and the reason
//    [_devChatPreviewScreenSheetHosted] exists: `showModalBottomSheet` targets
//    the NEAREST enclosing [Navigator], which in the preview canvas is the
//    canvas's own and in the Screen Catalog is the catalog's own — so the sheet
//    lands over the whole host instead of over the chat. Wrapping the screen in
//    a local [Navigator] confines it to the card, which is what makes these two
//    states previewable at all. (`chat_screen.dart`'s section skips them for
//    exactly this reason; here they are the screen's own behaviour, so they are
//    hosted rather than skipped.)
//  * **The broadcasting feed overflows at the width the app ships.**
//    [OfferCardBubble] lays Accept + Decline out as a `Row(mainAxisSize: min)`
//    of two intrinsically sized pills with no [Wrap] and no [Flexible], inside
//    a bubble capped at 250 pt: 97 px of stripes per card in EN at 390 pt. It
//    is a pre-existing defect of that widget, measured in its own preview
//    library, and this screen only carries it into view. The render test
//    tolerates that ONE exception narrowly rather than asserting it — a test
//    that pins a bug fails the day someone fixes it — and the frame is NOT
//    widened to make it disappear.
//
// Selector strings are never spelled as literals below. They live in
// [DevChatPreviewScreenPreviewFixtures], shared with the Screen Catalog entry
// for these frames, so the catalog and this canvas cannot drift into showing
// two different "designed states" of the same name.
//
// Nothing here reaches the network: every selector lands on
// [DevChatFixtureGateway] (const list, no polling opt-in) plus a
// [StubPhotoPickerService]. The guard in [jeebPreviewHost] is the net, not the
// plan. One thing IS live — the Jeeber legs' "Start delivery" CTA calls
// `context.push`, and there is no [GoRouter] above a preview card, so that one
// tap throws in the canvas. Everything else is inert by construction.

/// The phone the chat frames are designed against (Figma 56535:6659).
const Size _devChatPreviewScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app. The viewport that produced the
/// measured "BOTTOM OVERFLOWED BY 16 PIXELS" the chat header bound now
/// prevents.
const Size _devChatPreviewScreenCompactBox = Size(320, 568);

/// Pins [child] to a device-sized frame inside whatever box the host gives it.
///
/// The `size:` on [JeebPreview] boxes the CANVAS; this boxes the WIDGET TREE,
/// so the render tests measure the same phone the canvas draws. Without it a
/// preview is 800 pt wide under `flutter test`, where none of the layout under
/// review applies. Note the render surface is 800x600, so a request for 844 pt
/// of height is enforced down to what the host has; the compact box fits.
Widget _devChatPreviewScreenFramed(
  Widget child, {
  Size box = _devChatPreviewScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: child),
  );
}

/// One selector, framed. The ordinary host.
Widget _devChatPreviewScreenHosted(
  String selector, {
  Size box = _devChatPreviewScreenPhoneBox,
}) =>
    _devChatPreviewScreenFramed(
      DevChatPreviewScreen(selector: selector),
      box: box,
    );

/// Host for the two selectors that auto-open a confirm sheet.
///
/// The local [Navigator] is the whole point: [ConfirmDeliveryActionSheet.show]
/// calls `showModalBottomSheet` with the default `useRootNavigator: false`, so
/// it pushes onto the nearest navigator it can find. Under a preview card that
/// is the canvas's own navigator and under the Screen Catalog it is the
/// catalog's, either of which puts the sheet over the entire host rather than
/// over the chat it belongs to. A navigator of its own confines both the sheet
/// and its scrim to this card — and dismissing it leaves the chat behind,
/// where it should be, instead of leaving the tool.
Widget _devChatPreviewScreenSheetHosted(String selector) {
  return _devChatPreviewScreenFramed(
    Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => DevChatPreviewScreen(selector: selector),
      ),
    ),
  );
}

/// Figma 56535:6469 — the request is sent and nothing has answered yet.
///
/// Shares the request-feed header with the broadcasting state (the centred
/// order id `ORD-23748`, no counterpart avatar) and differs only in the seeded
/// thread: ONE outgoing bubble in the read state, no offer cards. The composer
/// stays visible through `broadcasting`, which is the difference between this
/// and a locked auction. Guarded by `test/features/chat/
/// dev_chat_sending_fixture_test.dart`, whose contract this preview shows.
@JeebPreview(
  group: 'chat',
  name: 'Client · sending initial request',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenClientSending() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.clientSending,
    );

/// Figma 56535:6659 — offers are landing, and the most content this screen can
/// produce.
///
/// The same header and the same outgoing bubble as the sending state, plus the
/// stacked offer cards and the "accept only one" footer that closes them. This
/// is the state that overflows: see the note in the library comment above.
/// Widening the frame would only hide it — the app ships 390.
@JeebPreview(
  group: 'chat',
  name: 'Client · broadcasting offers',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenClientBroadcasting() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.clientBroadcasting,
    );

/// Figma 56546:2382 — the accepted 1:1 thread.
///
/// The selector flips the phase to `accepted` and the header name from the
/// order id to `Kamal Hajj`, which is what mounts the counterpart avatar and
/// the "Offer accepted!" banner. No bundled avatar bitmap ships with the dev
/// seam, so the header falls back to the OMDS initials avatar — deliberate, and
/// what makes the capture deterministic offline.
@JeebPreview(
  group: 'chat',
  name: 'Client · accepted thread',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenClientAccepted() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.clientAccepted,
    );

/// The silent fallback, previewed on purpose.
///
/// `accepted-thread` is not a selector this screen knows. It renders anyway —
/// identically to [devChatPreviewScreenClientAccepted] — because the client
/// leg's `switch` closes with `_ => accepted` and nothing above it validates
/// the string. Read the two cards next to each other: they are supposed to look
/// the same, and that IS the finding. A dev seam that answers every input with
/// a plausible frame cannot tell you it was handed the wrong one, which on a
/// capture tool means a screenshot filed under one state can be holding
/// another.
@JeebPreview(
  group: 'chat',
  name: 'Unrecognised selector · silent fallback',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenUnrecognisedSelector() =>
    _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.unrecognised,
    );

/// Figma 56539:906 — the Jeeber's side of the same thread.
///
/// The leg that carries the balance-deduction banner and the price/time
/// composer hint, and whose accepted banner offers "Start delivery" instead of
/// "Track my order". This is also the ONLY state whose fee banner has an empty
/// trailing slot ([ChatFeeBannerTrailing.none]) — every other `dm*` selector
/// gets a dismiss × or the pill, so a banner with no trailing affordance is how
/// you know the dispatch landed here and not on a `dm` typo.
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · accepted thread',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenJeeberAccepted() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberAccepted,
    );

/// Figma 56560:1605 — the fee banner's trailing slot becomes an "Order picked"
/// pill.
///
/// The pill is a NON-FLEX child beside the notice text, which makes this the
/// fee-banner state that runs out of room first — so it is one of the two
/// matrix cards here. In AR the banner mirrors and the pill moves to the
/// leading edge; at 200% text the notice grows to three lines against a pill
/// that does not shrink. Both are only judgeable side by side.
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · order picked',
  size: _devChatPreviewScreenPhoneBox,
  matrix: true,
)
Widget devChatPreviewScreenJeeberOrderPicked() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberOrderPicked,
    );

/// Figma 56618:2751 — the confirm-picking sheet, auto-opened over the thread.
///
/// The composition only this screen produces, and the second matrix card: the
/// sheet is bottom-anchored over a navy scrim with the chat still visible
/// behind it, so AR has to mirror BOTH layers and 200% text has to fit a
/// three-line title into a sheet that is already 537 pt tall at 1.0. The dark
/// rendering is worth a look for a different reason — the sheet's own title and
/// CTA fall below WCAG AA there (1.98:1 and 1.40:1, measured and documented in
/// `confirm_delivery_action_sheet.dart`), which is a defect of that widget
/// rather than of this host.
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · confirm picking sheet',
  size: _devChatPreviewScreenPhoneBox,
  matrix: true,
)
Widget devChatPreviewScreenJeeberConfirmPicking() =>
    _devChatPreviewScreenSheetHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberConfirmPicking,
    );

/// Figma 56618:2852 — the heading-off sheet, auto-opened over the thread.
///
/// Worth its own card precisely because it looks almost identical to the
/// picking sheet: the same shell, the same illustration, the same CTA, and only
/// the title and subtitle differ. If this ever renders "Confirm Picking the
/// order", either the `switch` in [ConfirmDeliveryActionSheet] has collapsed or
/// this screen's `_autoSheet` is handing it the wrong [DeliveryConfirmKind] —
/// and the jeeber is being asked to confirm a transition they are not making.
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · confirm heading-off sheet',
  size: _devChatPreviewScreenPhoneBox,
)
Widget devChatPreviewScreenJeeberConfirmHeadingOff() =>
    _devChatPreviewScreenSheetHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberConfirmHeadingOff,
    );

/// The same order-picked state on the 320x568 floor.
///
/// The Jeeber leg stacks the most non-flexible chrome of any state here — fee
/// banner, accepted banner, Start-delivery CTA — above a composer that is also
/// non-flexible. That arithmetic is what [kChatHeaderMaxViewportFraction] and
/// [kChatPinnedCtaReserve] exist for, and it is only observable once the
/// viewport is small enough for the bound to engage. At 390 pt this state has
/// room to spare; here it does not, and the degradation should be a scrollable
/// header slot rather than clipped chrome.
@JeebPreview(
  group: 'chat',
  name: 'Compact 320 pt · jeeber order picked',
  size: _devChatPreviewScreenCompactBox,
)
Widget devChatPreviewScreenCompactJeeber() => _devChatPreviewScreenHosted(
      DevChatPreviewScreenPreviewFixtures.jeeberOrderPicked,
      box: _devChatPreviewScreenCompactBox,
    );
