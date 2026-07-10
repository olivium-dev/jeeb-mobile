import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioClientHomeRepository repository;

  setUp(() {
    dio = _MockDio();
    repository = DioClientHomeRepository(dio);
  });

  test('maps mock aliases into the client home snapshot', () async {
    _stubGatewaySnapshot(dio);

    final snapshot = await repository.loadSnapshot();

    expect(snapshot.inProgress.single.id, 'dlv-golden-001');
    expect(snapshot.inProgress.single.status, ClientRequestStatus.enRoute);
    expect(snapshot.pending.single.id, 'req-pending-001');
    expect(snapshot.replies.single.id, 'req-replies-001');
    expect(snapshot.replies.single.offerCount, 2);
    expect(snapshot.replies.single.conversationId, 'conv-replies-001');
    expect(snapshot.replies.single.offerAvatarUrls, [
      'https://cdn.jeeb.app/avatars/kamal.jpg',
      'https://cdn.jeeb.app/avatars/rana.jpg',
    ]);
  });
}

void _stubGatewaySnapshot(_MockDio dio) {
  when(
    () => dio.get<Map<String, dynamic>>(
      any(),
      queryParameters: any(named: 'queryParameters'),
    ),
  ).thenAnswer((invocation) async {
    final path = invocation.positionalArguments.first as String;
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      data: path == '/deliveries' ? _activeDeliveries() : _clientRequests(),
      statusCode: 200,
    );
  });
}

Map<String, dynamic> _activeDeliveries() {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'deliveryId': 'dlv-golden-001',
        'displayId': 'ORD-9001',
        'description': 'Coffee beans',
        'dropoffAddress': 'Gemmayze, Beirut',
        'currentStage': 'InTransit',
        'eta_minutes': 12,
        'tierId': 'express',
        'conversation_id': 'conv-active-001',
      },
    ],
  };
}

Map<String, dynamic> _clientRequests() {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[_pendingRequest(), _repliesRequest()],
  };
}

Map<String, dynamic> _pendingRequest() {
  return <String, dynamic>{
    'requestId': 'req-pending-001',
    'orderNumber': 'ORD-1001',
    'description': 'One grocery bag',
    'dropoff': <String, dynamic>{'label': 'Hamra, Beirut'},
    'offers_count': 0,
    'tierId': 'standard',
  };
}

Map<String, dynamic> _repliesRequest() {
  return <String, dynamic>{
    'requestId': 'req-replies-001',
    'orderNumber': 'ORD-1002',
    'description': 'Pharmacy pickup',
    'destinationLabel': 'Achrafieh, Beirut',
    'conversation_id': 'conv-replies-001',
    'offers': <Map<String, dynamic>>[_kamalOffer(), _ranaOffer()],
    'tier': 'express',
  };
}

Map<String, dynamic> _kamalOffer() {
  return <String, dynamic>{
    'avatarUrl': 'https://cdn.jeeb.app/avatars/kamal.jpg',
  };
}

Map<String, dynamic> _ranaOffer() {
  return <String, dynamic>{
    'jeeberAvatarUrl': 'https://cdn.jeeb.app/avatars/rana.jpg',
  };
}
