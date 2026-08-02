import 'package:flutter/foundation.dart';

class ChatHeaderExpansionStore {
  ChatHeaderExpansionStore._();

  static final ChatHeaderExpansionStore instance = ChatHeaderExpansionStore._();

  final Map<String, bool> _expandedByKey = <String, bool>{};

  bool isExpanded(String key) => _expandedByKey[key] ?? false;

  void setExpanded(String key, {required bool expanded}) {
    _expandedByKey[key] = expanded;
  }

  @visibleForTesting
  void reset() => _expandedByKey.clear();
}
