// The copy family is the whole reason `AppFailure` exists: classify once,
// speak once. These lock the two rules review cannot see — only a transport
// failure blames the connection, and no branch leaks internal vocabulary.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/app_failure_copy.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Every kind, with the two flags that change the branch inside a kind.
const List<AppFailure> _kAllFailures = <AppFailure>[
  NetworkFailure(offline: true),
  NetworkFailure(),
  TimeoutFailure(phase: DioExceptionType.connectionTimeout),
  TimeoutFailure(phase: DioExceptionType.sendTimeout),
  TimeoutFailure(phase: DioExceptionType.receiveTimeout),
  ServerFailure(status: 500),
  ServerFailure(status: 502),
  ServerFailure(status: 503),
  ServerFailure(status: 504),
  UnauthorizedFailure(),
  UnauthorizedFailure(recovering: true),
  UnauthorizedFailure(storeUnavailable: true),
  ForbiddenFailure(),
  NotFoundFailure(),
  ConflictFailure(),
  GoneFailure(),
  ValidationFailure(),
  RateLimitedFailure(),
  RateLimitedFailure(retryAfter: Duration(seconds: 30)),
  RateLimitedFailure(localSuppression: true),
  UnknownFailure(),
  UnknownFailure(parse: true),
];

/// The two kinds whose copy is allowed to talk about the user's connection.
bool _blamesConnectivity(AppFailure f) =>
    f is NetworkFailure || f is TimeoutFailure;

/// Words that name our own plumbing. A user has no server and no gateway.
const List<String> _kBannedEn = <String>[
  'server',
  'gateway',
  'format',
  'json',
  'parse',
  'null',
  'exception',
  'http',
  '500',
  '503',
];

/// The Arabic equivalents of the same leak.
const List<String> _kBannedAr = <String>[
  'الخادم',
  'البوابة',
  'صيغة',
  'استثناء',
];

/// Connectivity vocabulary, per locale.
const List<String> _kConnectivityEn = <String>[
  'connection',
  'connect',
  'offline',
  'network',
];
const List<String> _kConnectivityAr = <String>['اتصال', 'الشبكة', 'متصل'];

AppLocalizations _load(String tag) => debugLoadAppLocalizationsSync(
  Locale(tag),
  File('lib/l10n/app_$tag.arb').readAsStringSync(),
);

void main() {
  final AppLocalizations en = _load('en');
  final AppLocalizations ar = _load('ar');

  group('failureCopy · every kind resolves', () {
    for (final AppLocalizations l10n in <AppLocalizations>[en, ar]) {
      final String tag = l10n.locale.languageCode;
      for (final AppFailure failure in _kAllFailures) {
        test('${failure.kind.name} · $tag', () {
          final FailureCopy copy = failureCopy(l10n, failure);
          expect(copy.title, isNotEmpty);
          expect(copy.body, isNotEmpty);
          expect(copy.action, isNotEmpty);
          // A key that fell through `_get` renders as its own name.
          expect(copy.title, isNot(startsWith('error')));
          expect(copy.body, isNot(startsWith('error')));
        });
      }
    }
  });

  group('failureCopy · only transport failures blame the connection', () {
    for (final AppFailure failure in _kAllFailures) {
      test('${failure.runtimeType} · en', () {
        final String body = failureCopy(en, failure).body.toLowerCase();
        final bool mentions = _kConnectivityEn.any(body.contains);
        expect(
          mentions,
          _blamesConnectivity(failure) ? isTrue : isFalse,
          reason: 'A ${failure.runtimeType} that tells the user to check '
              'their connection sends them to fix something that is not '
              'broken (the client_location honesty rule): "$body"',
        );
      });

      test('${failure.runtimeType} · ar', () {
        final String body = failureCopy(ar, failure).body;
        final bool mentions = _kConnectivityAr.any(body.contains);
        expect(mentions, _blamesConnectivity(failure) ? isTrue : isFalse,
            reason: 'AR body: "$body"');
      });
    }
  });

  group('failureCopy · no internal vocabulary reaches the user', () {
    for (final AppFailure failure in _kAllFailures) {
      test('${failure.runtimeType} · en', () {
        final FailureCopy copy = failureCopy(en, failure);
        for (final String word in _kBannedEn) {
          expect(
            '${copy.title} ${copy.body} ${copy.action}'.toLowerCase(),
            isNot(contains(word)),
            reason: '"$word" is plumbing vocabulary, not copy',
          );
        }
      });

      test('${failure.runtimeType} · ar', () {
        final FailureCopy copy = failureCopy(ar, failure);
        for (final String word in _kBannedAr) {
          expect(
            '${copy.title} ${copy.body} ${copy.action}',
            isNot(contains(word)),
            reason: '"$word" is plumbing vocabulary, not copy',
          );
        }
      });
    }
  });

  group('failureCopy · retryable matches what the CTA can achieve', () {
    test('auth retry policy and copy agree for every flag combination EN/AR', () {
      for (final l10n in [en, ar]) {
        for (final recovering in [false, true]) {
          for (final storeUnavailable in [false, true]) {
            final failure = UnauthorizedFailure(
              recovering: recovering,
              storeUnavailable: storeUnavailable,
            );
            final copy = failureCopy(l10n, failure);
            expect(failure.isRetryable, copy.retryable);
            expect(copy.action,
                recovering ? l10n.actionRetry : l10n.actionSignIn);
          }
        }
      }
    });

    test('unrecoverable kinds are never marked retryable', () {
      for (final AppFailure failure in <AppFailure>[
        const UnauthorizedFailure(),
        const ForbiddenFailure(),
        const NotFoundFailure(),
        const GoneFailure(),
      ]) {
        expect(
          failureCopy(en, failure).retryable,
          isFalse,
          reason: '${failure.runtimeType} would render a Retry the user '
              'can never win',
        );
      }
    });

    test('a 401 raised inside the refresh cooldown IS retryable', () {
      expect(failureCopy(en, const UnauthorizedFailure()).retryable, isFalse);
      expect(
        failureCopy(en, const UnauthorizedFailure(recovering: true)).retryable,
        isTrue,
        reason: 'the session is being renewed, so retrying is exactly right',
      );
    });

    test('transport, server, conflict, validation and unknown are retryable', () {
      for (final AppFailure failure in <AppFailure>[
        const NetworkFailure(),
        const TimeoutFailure(phase: DioExceptionType.receiveTimeout),
        const ServerFailure(status: 500),
        const ConflictFailure(),
        const ValidationFailure(),
        const RateLimitedFailure(),
        const UnknownFailure(),
      ]) {
        expect(failureCopy(en, failure).retryable, isTrue);
      }
    });
  });

  group('failureCopy · the branches that must differ', () {
    test('502/503/504 say something other than a plain 500', () {
      expect(
        failureCopy(en, const ServerFailure(status: 503)).body,
        isNot(failureCopy(en, const ServerFailure(status: 500)).body),
      );
      expect(
        failureCopy(en, const ServerFailure(status: 503)).body,
        en.errorServiceUnavailableBody,
      );
    });

    test('Retry-After renders the countdown, not the generic line', () {
      final String withAfter = failureCopy(
        en,
        const RateLimitedFailure(retryAfter: Duration(seconds: 30)),
      ).body;
      expect(withAfter, contains('30'));
      expect(withAfter, isNot(en.errorRateLimitedBody));
      expect(
        failureCopy(en, const RateLimitedFailure()).body,
        en.errorRateLimitedBody,
      );
    });

    test('the AR countdown uses the CLDR branch, not the English one', () {
      expect(
        failureCopy(
          ar,
          const RateLimitedFailure(retryAfter: Duration(seconds: 2)),
        ).body,
        ar.byKey('errorRateLimitedRetryInTwo'),
      );
      expect(
        failureCopy(
          ar,
          const RateLimitedFailure(retryAfter: Duration(seconds: 5)),
        ).body,
        contains('5'),
      );
    });

    test('Retry is one label, in both locales', () {
      expect(failureCopy(en, const NetworkFailure()).action, en.actionRetry);
      expect(failureCopy(ar, const NetworkFailure()).action, ar.actionRetry);
      expect(en.actionRetry, isNot(ar.actionRetry));
    });

    test('an expired session offers sign-in, a 403 offers a way back', () {
      expect(failureCopy(en, const UnauthorizedFailure()).action, en.actionSignIn);
      expect(failureCopy(en, const ForbiddenFailure()).action, en.actionBack);
      expect(failureCopy(en, const GoneFailure()).action, en.actionBack);
    });
  });

  group('failureCopy · the failure itself is never rendered', () {
    test('a cause carrying a stack trace does not reach the copy', () {
      final AppFailure failure = UnknownFailure(
        cause: StateError('DioException [bad response]: 500 at /v1/wallet'),
      );
      final FailureCopy copy = failureCopy(en, failure);
      expect(copy.body, isNot(contains('Dio')));
      expect(copy.body, isNot(contains('wallet')));
      expect(copy.body, en.errorGenericBody);
    });
  });
}
