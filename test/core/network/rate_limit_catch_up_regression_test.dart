import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/rate_limit_interceptor.dart';

class _ErrorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException err) {}
}

class _RequestHandler extends RequestInterceptorHandler {
  @override
  void next(RequestOptions options) {}

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {}
}

class _ResponseHandler extends ResponseInterceptorHandler {
  @override
  void next(Response<dynamic> response) {}
}

void main() {
  final start = DateTime.utc(2026, 9, 6);

  RateLimitInterceptor build(
    FakeAsync async, {
    required void Function() onCatchUp,
    Duration maxJitter = Duration.zero,
  }) => RateLimitInterceptor(
    clock: () => start.add(async.elapsed),
    maxJitter: maxJitter,
    random: math.Random(7),
    onBackoffWindowClosed: onCatchUp,
  );

  void receive429(
    RateLimitInterceptor limiter,
    String path,
    int seconds, {
    String method = 'GET',
  }) {
    final request = RequestOptions(path: path, method: method);
    limiter.onRequest(request, _RequestHandler());
    limiter.onError(
      DioException(
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['$seconds'],
          }),
        ),
      ),
      _ErrorHandler(),
    );
  }

  void receiveResponse(RateLimitInterceptor limiter, String path, int status) {
    limiter.onResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
      ),
      _ResponseHandler(),
    );
  }

  for (final recovery in <String?>[null, '/v1/users/me', '/v1/offers/o-1']) {
    test('catch-up budget resets only on own scope recovery: $recovery', () {
      fakeAsync((async) {
        var caughtUp = 0;
        var reissue = true;
        late RateLimitInterceptor limiter;
        limiter = build(
          async,
          onCatchUp: () {
            caughtUp++;
            if (reissue) receive429(limiter, '/v1/offers', 5);
          },
        );
        receive429(limiter, '/v1/offers', 5);
        async.elapse(const Duration(seconds: 30));
        expect(caughtUp, 3);
        reissue = false;
        async.elapse(const Duration(minutes: 10));
        if (recovery != null) receiveResponse(limiter, recovery, 200);
        receive429(limiter, '/v1/offers', 5);
        async.elapse(const Duration(seconds: 60));
        expect(caughtUp, recovery == '/v1/offers/o-1' ? 4 : 3);
        limiter.dispose();
      });
    });
  }

  test('independent deadlines both wake up', () {
    fakeAsync((async) {
      var caughtUp = 0;
      final limiter = build(async, onCatchUp: () => caughtUp++);
      receive429(limiter, '/v1/offers', 30);
      receive429(limiter, '/v1/users', 5);
      async.elapse(const Duration(seconds: 6));
      expect(caughtUp, 1);
      expect(limiter.isPathSuppressed('/v1/offers'), isTrue);
      async.elapse(const Duration(seconds: 25));
      expect(caughtUp, 2);
      expect(limiter.isPathSuppressed('/v1/offers'), isFalse);
      limiter.dispose();
    });
  });

  test(
    'unrelated successes during every catch-up cannot reopen the budget',
    () {
      fakeAsync((async) {
        var caughtUp = 0;
        late RateLimitInterceptor limiter;
        limiter = build(
          async,
          onCatchUp: () {
            caughtUp++;
            receiveResponse(limiter, '/v1/users/me', 200);
            receive429(limiter, '/v1/offers', 5);
          },
        );
        receive429(limiter, '/v1/offers', 5);
        async.elapse(const Duration(seconds: 60));
        expect(caughtUp, 3);
        limiter.dispose();
      });
    },
  );

  test('an exhausted scope does not starve a fresh scope', () {
    fakeAsync((async) {
      var caughtUp = 0;
      var reissue = true;
      late RateLimitInterceptor limiter;
      limiter = build(
        async,
        onCatchUp: () {
          caughtUp++;
          if (reissue) receive429(limiter, '/v1/offers', 5);
        },
      );
      receive429(limiter, '/v1/offers', 5);
      async.elapse(const Duration(seconds: 30));
      reissue = false;
      receiveResponse(limiter, '/v1/offers', 304);
      receive429(limiter, '/v1/offers', 5);
      receive429(limiter, '/v1/users', 10);
      async.elapse(const Duration(seconds: 6));
      expect(caughtUp, 3);
      async.elapse(const Duration(seconds: 5));
      expect(caughtUp, 4);
      limiter.dispose();
    });
  });

  test('a jittered burst coalesces into one global refresh', () {
    fakeAsync((async) {
      var caughtUp = 0;
      final limiter = build(
        async,
        maxJitter: const Duration(seconds: 1),
        onCatchUp: () => caughtUp++,
      );
      for (final path in ['/v1/offers', '/v1/users', '/v1/deliveries']) {
        receive429(limiter, path, 60);
      }
      async.elapse(const Duration(seconds: 59));
      expect(caughtUp, 0);
      async.elapse(const Duration(seconds: 4));
      expect(caughtUp, 1);
      expect(limiter.isSuppressed, isFalse);
      limiter.dispose();
    });
  });

  test('another 429 moves a pending scope deadline without duplicating it', () {
    fakeAsync((async) {
      var caughtUp = 0;
      final limiter = build(async, onCatchUp: () => caughtUp++);
      receive429(limiter, '/v1/offers', 5);
      async.elapse(const Duration(seconds: 1));
      receive429(limiter, '/v1/offers/accept', 5, method: 'POST');
      async.elapse(const Duration(milliseconds: 4500));
      expect(caughtUp, 0);
      async.elapse(const Duration(seconds: 2));
      expect(caughtUp, 1);
      limiter.dispose();
    });
  });

  test('dispose cancels all pending scopes', () {
    fakeAsync((async) {
      var caughtUp = 0;
      final limiter = build(async, onCatchUp: () => caughtUp++);
      receive429(limiter, '/v1/offers', 30);
      receive429(limiter, '/v1/users', 5);
      limiter.dispose();
      async.elapse(const Duration(minutes: 1));
      expect(caughtUp, 0);
    });
  });
}
