import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/prohibited_acknowledgment_repository.dart';
import '../domain/prohibited_item.dart';

/// Preference key used to persist the local acknowledgment state (T-MOB-021).
const _kAckKey = 'app.acknowledged_prohibited';

/// Dio-backed implementation.
/// Endpoint contract verified against Mockoon :3055 (s05-order-prohibited-items):
///   GET  /prohibited-items → { items: [...], version, acknowledged }
class DioProhibitedAcknowledgmentRepository
    implements ProhibitedAcknowledgmentRepository {
  DioProhibitedAcknowledgmentRepository({
    required Dio dio,
    required SharedPreferences prefs,
  })  : _dio = dio,
        _prefs = prefs;

  static const _itemsPath = '/prohibited-items';
  static const _ackPath = '/prohibited-items/acknowledge';

  final Dio _dio;
  final SharedPreferences _prefs;

  @override
  Future<List<ProhibitedItem>> fetchItems() async {
    final response = await _dio.get<dynamic>(_itemsPath);
    return _parseItems(response.data);
  }

  @override
  Future<void> acknowledge() async {
    await _dio.post<dynamic>(_ackPath);
  }

  @override
  Future<bool> hasAcknowledged() async {
    return _prefs.getBool(_kAckKey) ?? false;
  }

  @override
  Future<void> saveLocalAcknowledgment() async {
    await _prefs.setBool(_kAckKey, true);
  }

  List<ProhibitedItem> _parseItems(dynamic data) {
    final List<dynamic> raw;
    if (data is Map<String, dynamic> && data['items'] is List) {
      raw = data['items'] as List<dynamic>;
    } else if (data is List) {
      raw = data;
    } else {
      return const [];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_parseItem)
        .whereType<ProhibitedItem>()
        .toList(growable: false);
  }

  ProhibitedItem? _parseItem(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    if (id == null || name == null) return null;
    final severity = (json['severity'] as String?) == 'warn'
        ? ProhibitedItemSeverity.warn
        : ProhibitedItemSeverity.block;
    return ProhibitedItem(
      id: id,
      name: name,
      category: json['category'] as String?,
      severity: severity,
    );
  }
}
