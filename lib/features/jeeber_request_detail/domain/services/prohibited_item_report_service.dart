/// Prohibited-item flagging RPC (orders-prohibited-item-report /
/// disputes-prohibited-item-report).
///
/// A Jeeber (or client) reports that a delivery request involves a prohibited
/// item. The report is submitted to the gateway, which routes it to the
/// delivery / moderation pipeline.
///
/// **Gateway contract (backend built in parallel — jeeb-backend-feature-services).**
/// The mobile client speaks the expected gateway `/v1` shape; `MockGatewayClient`
/// rewrites the prefix to the owning service. Until the backend route shape is
/// finalised this is the documented contract the client is built against:
///
///   POST /v1/deliveries/{requestId}/prohibited-report
///     body: { reason: String, photoUrl?: String }
///     → 201 { id, requestId, status }   (best-effort; 4xx/5xx surface as failure)
///
/// See `DioProhibitedItemReportService` for the live impl and
/// `lib/core/network/mock_gateway_client.dart` for the prefix rewrite.
library;

/// Typed failure surfaced to the UI (the screen never sees a `DioException`).
enum ProhibitedReportFailure {
  /// Connection / timeout — the report did not reach the server.
  network,

  /// Any server reject (4xx/5xx) or unexpected error.
  unknown,
}

/// Thrown by the data layer; the screen maps [failure] to localized copy.
class ProhibitedReportException implements Exception {
  const ProhibitedReportException(this.failure, [this.message]);

  final ProhibitedReportFailure failure;
  final String? message;

  @override
  String toString() => 'ProhibitedReportException($failure, $message)';
}

/// Domain port for submitting a prohibited-item report. The screen + tests
/// depend on this abstraction; DI binds `DioProhibitedItemReportService` in
/// production and tests inject a recording double.
abstract class ProhibitedItemReportService {
  const ProhibitedItemReportService();

  /// Submits a prohibited-item [reason] (and optional [photoUrl]) for the
  /// delivery [requestId].
  ///
  /// Throws [ProhibitedReportException] on failure.
  Future<void> report({
    required String requestId,
    required String reason,
    String? photoUrl,
  });
}
