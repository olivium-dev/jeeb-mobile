import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';

class DevClientHomeFixtures {
  const DevClientHomeFixtures._();

  static const String _itemsSummary =
      '1 kilo potato, water gallon, coffee blend';

  static ClientHomeSnapshot snapshot() => const ClientHomeSnapshot(
        inProgress: _inProgress,
        pending: _pending,
        replies: _replies,
      );

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
