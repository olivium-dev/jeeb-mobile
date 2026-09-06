import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/app_failure.dart';
import '../domain/prohibited_acknowledgment_repository.dart';
import '../domain/prohibited_item.dart';

/// Legacy device-global latch, retained only for removal after server ack.
const _kAckKey = 'app.acknowledged_prohibited';

/// Dio-backed implementation.
/// Endpoint contract verified against Mockoon :3055 (s05-order-prohibited-items):
///   GET  /prohibited-items → { items: [...], version, acknowledged }
class DioProhibitedAcknowledgmentRepository
    implements ProhibitedAcknowledgmentRepository {
  DioProhibitedAcknowledgmentRepository({
    required Dio dio,
    required SharedPreferences prefs,
  }) : _dio = dio,
       _prefs = prefs;

  static const _itemsPath = '/prohibited-items';
  static const _ackPath = '/prohibited-items/acknowledge';

  final Dio _dio;
  final SharedPreferences _prefs;
  String? _lastVersion;
  bool _serverAcknowledged = false;

  @override
  Future<List<ProhibitedItem>> fetchItems() async {
    _lastVersion = null;
    _serverAcknowledged = false;
    try {
      final response = await _dio.get<dynamic>(_itemsPath);
      final items = _parseItems(response.data);
      final version = _parseVersion(response.data);
      final acknowledged =
          (response.data as Map<String, dynamic>)['acknowledged'];
      if (acknowledged is! bool) throw const UnknownFailure(parse: true);
      _lastVersion = version;
      _serverAcknowledged = acknowledged;
      return items;
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }

  @override
  Future<void> acknowledge() async {
    try {
      if (_lastVersion == null) await fetchItems();
      final version = _lastVersion!;
      final response = await _dio.post<dynamic>(
        _ackPath,
        data: {'version': version},
      );
      final body = response.data;
      if (body is! Map<String, dynamic> ||
          body['version'] != version ||
          body['userId'] is! String ||
          (body['userId'] as String).trim().isEmpty ||
          body['acknowledgedAt'] is! String ||
          DateTime.tryParse(body['acknowledgedAt'] as String) == null) {
        throw const UnknownFailure(parse: true);
      }
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }

  @override
  Future<bool> hasAcknowledged() async {
    return _lastVersion != null && _serverAcknowledged;
  }

  @override
  Future<void> saveLocalAcknowledgment() async {
    // The authenticated catalog, not a device-global preference, authorizes
    // skipping the dialog. Remove the legacy latch when completing an ack.
    await _prefs.remove(_kAckKey);
  }

  String _parseVersion(dynamic data) {
    final version = data is Map<String, dynamic> ? data['version'] : null;
    if (version is! String || version.trim().isEmpty) {
      throw const UnknownFailure(parse: true);
    }
    return version;
  }

  List<ProhibitedItem> _parseItems(dynamic data) {
    final List<dynamic> raw;
    if (data is Map<String, dynamic> && data['items'] is List) {
      raw = data['items'] as List<dynamic>;
    } else {
      // A catalogue we cannot read is not an empty catalogue: acknowledging a
      // blank policy is worse than failing.
      throw const UnknownFailure(parse: true);
    }
    return raw
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const UnknownFailure(parse: true);
          }
          return _parseItem(item);
        })
        .toList(growable: false);
  }

  ProhibitedItem _parseItem(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final category = json['category'];
    final severityValue = json['severity'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        (category != null && category is! String) ||
        (severityValue != null &&
            severityValue != 'warn' &&
            severityValue != 'block')) {
      throw const UnknownFailure(parse: true);
    }
    final severity = (json['severity'] as String?) == 'warn'
        ? ProhibitedItemSeverity.warn
        : ProhibitedItemSeverity.block;
    return ProhibitedItem(
      id: id,
      name: name,
      category: category as String?,
      severity: severity,
    );
  }
}
