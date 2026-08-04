// Regression gate for "Tier field renders empty", seen on real hardware during

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/chat/data/dio_order_chat_summary_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/order_summary/data/dio_order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_summary/presentation/widgets/order_summary_pinned.dart';

const _deliveryId = 'req-uuid-0001';

/// The `DeliveryRequestDto` body as the gateway serializes it. `tierId`, not
/// `tier` — see the provenance note at the top of this file.
Map<String, Object?> _gatewayDeliveryBody({String tierId = 'flash'}) => {
      'id': _deliveryId,
      'clientId': 'client-0001',
      'status': 'Picked',
      'description': '2 kilos apples',
      'photos': <Object?>[],
      'tierId': tierId,
      'jeeberId': 'user-jeeber-002',
      'jeeberName': 'Kamal Hajj',
      'amount': {'value': 6.0, 'currency': 'USD'},
      'requestId': _deliveryId,
      'createdAt': '2026-07-31T19:40:00Z',
    };

/// NEGATIVE CONTROL: the key read every one of these parsers used before the
/// fix. Kept executable so "the old code really did come back empty on this
String oldRead(Map<String, Object?> json) => (json['tier'] as String?) ?? '';

ResponseBody _json(Map<String, Object?> body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  final Map<String, Map<String, Object?>> bodies = <String, Map<String, Object?>>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final override = bodies[options.path];
    if (override != null) return _json(override);
    if (options.path.contains('/offers')) {
      return _json(const {'items': <Object?>[]});
    }
    return _json(const <String, Object?>{});
  }
}

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

OrderSummary _summary({required String tier}) => OrderSummary(
      deliveryId: _deliveryId,
      requestId: _deliveryId,
      conversationId: '',
      price: 6.0,
      currency: 'USD',
      jeeberName: 'Kamal Hajj',
      tier: tier,
      etaMinutes: 20,
    );

Widget _harness(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _syncDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

String _factValue(WidgetTester tester, String identifier) {
  final texts = find.descendant(
    of: find.bySemanticsIdentifier(identifier),
    matching: find.byType(Text),
  );
  return tester
      .widgetList<Text>(texts)
      .map((t) => t.data ?? '')
      .join('|');
}

void main() {
  setUpAll(() {
    _syncDelegate = _SyncDelegate({
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    });
  });

  test('NEGATIVE CONTROL — the pre-fix key read is empty on the gateway body',
      () {
    final body = _gatewayDeliveryBody();
    expect(body.containsKey('tierId'), isTrue);
    expect(
      body.containsKey('tier'),
      isFalse,
      reason: 'DeliveryRequestDto has no `tier` member — only `TierId`',
    );
    expect(
      oldRead(body),
      isEmpty,
      reason: 'this is exactly why the field rendered blank on device',
    );
  });

  group('DeliveryTrackingInfo.fromDeliveryJson (tracking header)', () {
    test('reads tierId', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson(
        _deliveryId,
        _gatewayDeliveryBody(),
      );
      expect(info.tier, 'flash');
    });

    test('still reads the legacy :4010 `tier` alias', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson(
        _deliveryId,
        const {'id': _deliveryId, 'status': 'Ordered', 'tier': 'eco'},
      );
      expect(info.tier, 'eco');
    });

    test('stays null when the row genuinely carries no tier', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson(
        _deliveryId,
        const {'id': _deliveryId, 'status': 'Ordered'},
      );
      expect(info.tier, isNull);
    });
  });

  group('DioOrderSummaryRepository (order-summary screen)', () {
    late _RecordingAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
        ..httpClientAdapter = adapter;
    });

    test('reads tierId off GET /v1/deliveries/{id}', () async {
      adapter.bodies['/v1/deliveries/$_deliveryId'] = _gatewayDeliveryBody();

      final summary = await DioOrderSummaryRepository(dio, originGateway: true)
          .fetchSummary(_deliveryId);

      expect(summary.tier, 'flash');
    });

    test('falls back to the REQUEST row tierId when the delivery omits it',
        () async {
      adapter.bodies['/v1/deliveries/$_deliveryId'] = const {
        'id': _deliveryId,
        'requestId': _deliveryId,
      };
      adapter.bodies['/v1/requests/$_deliveryId'] =
          _gatewayDeliveryBody(tierId: 'express');

      final summary = await DioOrderSummaryRepository(dio, originGateway: true)
          .fetchSummary(_deliveryId);

      expect(summary.tier, 'express');
    });

    test('legacy `tier` alias still parses', () async {
      adapter.bodies['/v1/deliveries/$_deliveryId'] = const {
        'id': _deliveryId,
        'requestId': _deliveryId,
        'tier': 'standard',
      };

      final summary = await DioOrderSummaryRepository(dio, originGateway: true)
          .fetchSummary(_deliveryId);

      expect(summary.tier, 'standard');
    });
  });

  group('DioOrderChatSummaryRepository (chat header chip)', () {
    late _RecordingAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
        ..httpClientAdapter = adapter;
    });

    test('reads tierId, so hasTier is true and the chip leaves "Pending"',
        () async {
      adapter.bodies['/v1/deliveries/$_deliveryId'] = _gatewayDeliveryBody();

      final summary =
          await DioOrderChatSummaryRepository(dio, originGateway: true)
              .fetchSummary(_deliveryId);

      expect(summary.tierId, 'flash');
      expect(summary.hasTier, isTrue);
    });

    test('no tier anywhere still degrades to empty, not a throw', () async {
      adapter.bodies['/v1/deliveries/$_deliveryId'] = const {
        'id': _deliveryId,
        'status': 'Ordered',
      };

      final summary =
          await DioOrderChatSummaryRepository(dio, originGateway: true)
              .fetchSummary(_deliveryId);

      expect(summary.tierId, '');
      expect(summary.hasTier, isFalse);
    });
  });

  group('OrderSummaryPinned tier cell', () {
    testWidgets('renders the localized tier name', (tester) async {
      await tester.pumpWidget(
        _harness(OrderSummaryPinned(summary: _summary(tier: 'flash'))),
      );
      await tester.pump();

      expect(_factValue(tester, 'order_summary_tier'), contains('Flash'));
    });

    testWidgets('an absent tier reads "Pending", never a labelled blank', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(OrderSummaryPinned(summary: _summary(tier: ''))),
      );
      await tester.pump();

      final rendered = _factValue(tester, 'order_summary_tier');
      expect(
        rendered,
        contains('Pending'),
        reason: 'POSITIVE control — the cell states it does not know yet',
      );
      expect(
        rendered,
        isNot('Tier|'),
        reason: 'NEGATIVE control — the pre-fix render was label + nothing',
      );
    });
  });
}
