import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';

/// Deterministic, debug-only fixtures used by the dev seam to render the three
/// client "My Orders" filter variants (screens 13/14/15) without a backend.
///
/// These mirror the Figma mock data verbatim so emulator captures line up with
/// the design frames. They are only ever reached through the `kDebugMode`-gated
/// dev-seam path in [HomeTab]; release builds never construct them.
class DevClientHomeFixtures {
  const DevClientHomeFixtures._();

  static const String _itemsSummary =
      '1 kilo potato, water gallon, coffee blend';

  /// A repository pre-loaded with all three lists so the seam can switch tabs
  /// at runtime against populated data.
  static ClientHomeSnapshot snapshot() => const ClientHomeSnapshot(
        inProgress: _inProgress,
        pending: _pending,
        replies: _replies,
      );

  /// In Progress (screen 15, node 56535:1525): jeeber name + items summary +
  /// tier + progress; the first card is actively trackable.
  static const List<ClientHomeRequest> _inProgress = <ClientHomeRequest>[
    ClientHomeRequest(
      id: 'ip-1',
      title: 'Kamal Hajj',
      status: ClientRequestStatus.enRoute,
      destinationLabel: _itemsSummary,
      itemsSummary: _itemsSummary,
      tier: ClientRequestTier.flash,
      progressStep: 3,
    ),
    ClientHomeRequest(
      id: 'ip-2',
      title: 'Rania Kassem',
      status: ClientRequestStatus.atPickup,
      destinationLabel: _itemsSummary,
      itemsSummary: _itemsSummary,
      tier: ClientRequestTier.express,
      progressStep: 1,
    ),
    ClientHomeRequest(
      id: 'ip-3',
      title: 'Bahaa Saad',
      status: ClientRequestStatus.atPickup,
      destinationLabel: _itemsSummary,
      itemsSummary: _itemsSummary,
      tier: ClientRequestTier.express,
      progressStep: 1,
    ),
  ];

  /// Pending Requests (screen 13, node 56535:1783): order id + items + tier,
  /// no avatar / progress / CTA.
  static const List<ClientHomeRequest> _pending = <ClientHomeRequest>[
    ClientHomeRequest(
      id: 'pen-1',
      title: 'ORD-23470',
      displayId: 'ORD-23470',
      status: ClientRequestStatus.searching,
      destinationLabel: _itemsSummary,
      itemsSummary: _itemsSummary,
      tier: ClientRequestTier.express,
    ),
    ClientHomeRequest(
      id: 'pen-2',
      title: 'ORD-23471',
      displayId: 'ORD-23471',
      status: ClientRequestStatus.searching,
      destinationLabel: _itemsSummary,
      itemsSummary: _itemsSummary,
      tier: ClientRequestTier.flash,
    ),
    ClientHomeRequest(
      id: 'pen-3',
      title: 'ORD-23472',
      displayId: 'ORD-23472',
      status: ClientRequestStatus.searching,
      destinationLabel: _itemsSummary,
      itemsSummary: _itemsSummary,
      tier: ClientRequestTier.standard,
    ),
  ];

  /// Replies (screen 14, node 56535:2251): order id + items + offerer avatar
  /// stack with a "+6" overflow + Check Offers CTA.
  static const List<ClientHomeRequest> _replies = <ClientHomeRequest>[
    ClientHomeRequest(
      id: 'rep-1',
      title: 'ORD-23470',
      displayId: 'ORD-23470',
      status: ClientRequestStatus.offersReceived,
      destinationLabel: _itemsSummary,
      itemsSummary: _itemsSummary,
      tier: ClientRequestTier.express,
      offerCount: 9,
      offerAvatarUrls: <String>['', '', ''],
      conversationId: 'conv-rep-1',
    ),
  ];
}
