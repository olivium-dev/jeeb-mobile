import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';

import '../support/sync_app_localizations.dart';

// Diagnostic contract: attribute real app consumers, not a proxy expectation
// adjustment. Every request is terminated locally; no live account is used.
class _AttributionDio extends DioForNative {
  _AttributionDio() : super(BaseOptions(baseUrl: 'https://attribution.test')) {
    httpClientAdapter = _FailureAdapter();
  }

  final List<String> profileCallers = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    if (path == '/v1/users/me') {
      profileCallers.add(StackTrace.current.toString());
    }
    return super.get<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

class _FailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{}',
    options.path == '/v1/users/me' ? 409 : 503,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    await sl.reset();
    await NetworkReachabilitySignals.debugReset();
    SharedPreferences.setMockInitialValues({'app.onboarding.completed': true});
  });

  tearDown(() async {
    await sl.reset();
    await NetworkReachabilitySignals.debugReset();
  });

  testWidgets(
    'profile reads belong to two startup consumers then the visible tab',
    (tester) async {
      final dio = _AttributionDio();
      sl.registerSingleton<Dio>(
        dio,
        dispose: (value) => value.close(force: true),
      );
      await tester.pumpWidget(
        JeebApp(
          preferences: await SharedPreferences.getInstance(),
          localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
          sessionGate: const AlwaysAuthenticatedSessionGate(),
        ),
      );
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(ShellScreen), findsOneWidget);
      expect(dio.profileCallers, hasLength(2));
      for (final consumer in const [
        'RoleSync.sync',
        'GreetingProfileCubit.load',
      ]) {
        expect(
          dio.profileCallers.where((stack) => stack.contains(consumer)),
          hasLength(1),
          reason: '$consumer must account for exactly one startup read',
        );
      }
      expect(
        dio.profileCallers.where(
          (stack) => stack.contains('CustomerProfileCubit.load'),
        ),
        isEmpty,
        reason: 'The hidden Profile tab must not read eagerly',
      );
      await tester.pump(const Duration(seconds: 6));
      expect(
        dio.profileCallers,
        hasLength(2),
        reason: 'No hidden profile polling',
      );

      await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(dio.profileCallers, hasLength(3));
      expect(dio.profileCallers.last, contains('CustomerProfileCubit.load'));
      for (final consumer in const [
        'RoleSync.sync',
        'GreetingProfileCubit.load',
        'CustomerProfileCubit.load',
      ]) {
        expect(
          dio.profileCallers.where((stack) => stack.contains(consumer)),
          hasLength(1),
          reason: '$consumer must account for exactly one read',
        );
      }
      await tester.pump(const Duration(seconds: 6));
      expect(
        dio.profileCallers,
        hasLength(3),
        reason: 'No extra consumer profile read',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
}
