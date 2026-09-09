import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/session/reviews_refresh_signals.dart';
import 'package:jeeb_mobile/features/rating/data/dio_rating_repository.dart';

class _ActorStore extends AuthTokenStore {
  String? actor = 'actor-a';
  @override
  Future<String?> get userId async => actor;
}

void main() {
  for (final state in [
    'revealed',
    'pending_counter',
    'pending_self',
    'locked_no_rating',
    'auto_revealed',
  ]) {
    test(
      'submit $state only invalidates when owner confirms mutual visibility',
      () async {
        final signals = ReviewsRefreshSignals();
        final events = <ReviewsRefreshEvent>[];
        final subscription = signals.stream.listen(events.add);
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'deliveryId': 'delivery-a',
                    'state': state,
                    'ratedCount': 2,
                  },
                ),
              );
            },
          ),
        );
        final repo = DioRatingRepository(
          dio,
          tokenStore: _ActorStore(),
          reviewsRefreshSignals: signals,
        );
        await repo.submitRating(
          deliveryId: 'delivery-a',
          stars: 5,
          isClient: true,
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          events.map((e) => e.rateeId),
          state == 'revealed' ? ['actor-a'] : isEmpty,
        );
        await subscription.cancel();
        await signals.dispose();
        dio.close();
      },
    );
  }

  for (final fault in [
    'wrong-delivery',
    'changed-session',
    'signed-out',
    'missing-response',
    'failed',
  ]) {
    test(
      '$fault cannot invalidate a different actor or infer visibility',
      () async {
        final signals = ReviewsRefreshSignals();
        final events = <ReviewsRefreshEvent>[];
        final subscription = signals.stream.listen(events.add);
        final store = _ActorStore();
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (fault == 'changed-session') store.actor = 'actor-b';
              if (fault == 'signed-out') store.actor = null;
              if (fault == 'failed') {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.connectionError,
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: request,
                  statusCode: 200,
                  data: fault == 'missing-response'
                      ? null
                      : {
                          'deliveryId': fault == 'wrong-delivery'
                              ? 'other'
                              : 'delivery-a',
                          'state': 'revealed',
                        },
                ),
              );
            },
          ),
        );
        final repo = DioRatingRepository(
          dio,
          tokenStore: store,
          reviewsRefreshSignals: signals,
        );
        final submit = repo.submitRating(
          deliveryId: 'delivery-a',
          stars: 5,
          isClient: true,
        );
        if (fault == 'failed') {
          await expectLater(submit, throwsException);
        } else {
          await submit;
        }
        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty);
        await subscription.cancel();
        await signals.dispose();
        dio.close();
      },
    );
  }
}
