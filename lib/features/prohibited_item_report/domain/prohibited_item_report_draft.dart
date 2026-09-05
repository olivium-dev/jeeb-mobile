import 'dart:typed_data';

/// What the report screen hands back: a DRAFT, never a completed submission —
/// a caller reading `true` would be reading a report never sent (PIR-01).
class ProhibitedItemReportDraft {
  const ProhibitedItemReportDraft({
    required this.requestId,
    required this.description,
    this.photoBytes,
  });

  final String requestId;
  final String description;
  final Uint8List? photoBytes;
}
