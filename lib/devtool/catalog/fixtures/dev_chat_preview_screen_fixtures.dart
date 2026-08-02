/// Selector strings for DevChatPreviewScreen states.
/// Silent fallback on unrecognised input; see [unrecognised].
class DevChatPreviewScreenPreviewFixtures {
  const DevChatPreviewScreenPreviewFixtures._();

  /// Initial request, no offers.
  static const String clientSending = 'sending';

  /// Offers feed.
  static const String clientBroadcasting = 'broadcasting';

  /// Accepted 1:1 thread.
  static const String clientAccepted = 'accepted';

  /// Jeeber accepted; fee banner, composer hint.
  static const String jeeberAccepted = 'dm';

  /// Order picked pill in fee banner.
  static const String jeeberOrderPicked = 'dm-order-picked';

  /// Confirm-picking sheet open.
  static const String jeeberConfirmPicking = 'dm-confirm-picking';

  /// Heading-off sheet open.
  static const String jeeberConfirmHeadingOff = 'dm-confirm-heading-off';

  /// Unrecognised selector; triggers fallback to 'accepted'.
  static const String unrecognised = 'accepted-thread';
}
