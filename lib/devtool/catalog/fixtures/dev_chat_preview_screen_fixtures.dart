// The designed states of `DevChatPreviewScreen` — ONE source of truth, two
// consumers.
//
//   lib/devtool/catalog/fixtures/chat_screen_fixtures.dart
//       …which the on-device Screen Catalog entry
//       (`devtool/catalog/entries/batch_02_entries.dart`) and the JEEB PREVIEWS
//       section of `features/chat/presentation/chat_screen.dart` both call.
//   lib/features/chat/presentation/dev_chat_preview_screen.dart
//       the JEEB PREVIEWS section at its bottom.
//
// **Why this file is a list of strings and not a list of fakes.**
// `DevChatPreviewScreen`'s entire input surface is one `String selector`.
// Everything a state needs — the counterpart name, the conversation phase, the
// fee banner and its trailing slot, the price/time composer hint, which confirm
// sheet auto-opens — is DERIVED from that string inside the screen, and the
// message rows come from `DevChatFixtureGateway`. There is nothing else to
// inject. So the fixture set for this screen is its selector vocabulary, and
// the vocabulary is named here once instead of being retyped as a literal at
// each call site.
//
// That is not bookkeeping. Both branches of the screen's dispatch END IN A
// SILENT FALLBACK — `selector.startsWith('dm')` picks the leg and the client
// leg's `_ =>` arm lands on `accepted` — so a mistyped literal does not fail,
// it renders a DIFFERENT designed state under the label of the one you asked
// for. On a tool whose whole job is capturing frames for design review, that is
// the worst failure mode available. See [unrecognised], which previews the
// fallback deliberately so it stays visible.
//
// NOTHING here touches the network: these are strings, and the gateway every
// selector reaches (`DevChatFixtureGateway`) answers from a const list. The
// `CatalogNetworkGuard` both hosts install is a net, not the plan.

/// Selector strings [DevChatPreviewScreen] recognises, one per designed state.
///
/// The seven named Figma frames plus the unrecognised-input case. Kept as
/// `String` constants rather than widget builders so the CATALOG can keep its
/// `const DevChatPreviewScreen(...)` construction and the PREVIEW section can
/// build the same widget itself — which is what `tool/preview_inventory.dart`
/// requires of a preview section (it must construct the widget it is named
/// after, not delegate the construction to a helper library).
class DevChatPreviewScreenPreviewFixtures {
  const DevChatPreviewScreenPreviewFixtures._();

  /// Client's just-sent initial request, before any offer lands
  /// (Figma 56535:6469) — one outgoing bubble, no offer cards.
  static const String clientSending = 'sending';

  /// Client's offers feed (Figma 56535:6659) — the same request plus the
  /// stacked offer cards that have started arriving.
  static const String clientBroadcasting = 'broadcasting';

  /// Client's accepted 1:1 thread (Figma 56546:2382).
  static const String clientAccepted = 'accepted';

  /// Jeeber's accepted thread (Figma 56539:906) — fee banner with NO trailing
  /// affordance, price/time composer hint, Start-delivery CTA.
  static const String jeeberAccepted = 'dm';

  /// Jeeber's thread with the "Order picked" pill in the fee banner's trailing
  /// slot (Figma 56560:1605).
  static const String jeeberOrderPicked = 'dm-order-picked';

  /// Jeeber's thread with the confirm-picking sheet auto-opened
  /// (Figma 56618:2751).
  static const String jeeberConfirmPicking = 'dm-confirm-picking';

  /// Jeeber's thread with the heading-off sheet auto-opened
  /// (Figma 56618:2852).
  static const String jeeberConfirmHeadingOff = 'dm-confirm-heading-off';

  /// A selector the screen does NOT know — here a plausible typo of
  /// [clientAccepted], which is how it would actually arrive (the value comes
  /// from the `jeeb.state` dev-seam knob, typed by hand).
  ///
  /// Documented behaviour: `accepted` / `*` both mean "client accepted thread",
  /// so this renders a perfectly valid-looking frame for a state nobody asked
  /// for. Deliberately NOT a `dm`-prefixed typo: those take the other branch
  /// and are the more dangerous half of the same hole (see the preview section
  /// in `dev_chat_preview_screen.dart`).
  static const String unrecognised = 'accepted-thread';
}
