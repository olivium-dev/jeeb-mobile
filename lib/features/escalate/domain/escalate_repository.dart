/// Domain contract for the escalate (dispute) feature (T-MOB-022).
///
/// Endpoint: POST /v1/deliveries/{deliveryId}/escalate
///   body: multipart — reason (String), comment? (String), photos (files)
///   → 201 { caseId, status: "open", sla: "24h" }
///
/// Mock contract verified against Mockoon :3055 (scenario s14-dispute-escalation).
abstract class EscalateRepository {
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths,
  });
}

enum EscalateReason { damaged, wrongItem, noShow, fraud, abuse, other }

class EscalateResult {
  const EscalateResult({required this.caseId, required this.status});

  final String caseId;
  final String status;

  factory EscalateResult.fromJson(Map<String, dynamic> json) {
    return EscalateResult(
      caseId: json['caseId'] as String? ??
          json['id'] as String? ??
          json['case_id'] as String? ??
          '',
      status: json['status'] as String? ?? 'open',
    );
  }
}

class EscalateException implements Exception {
  const EscalateException(this.kind, [this.cause]);

  final EscalateErrorKind kind;
  final Object? cause;

  @override
  String toString() =>
      'EscalateException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum EscalateErrorKind { network, server, alreadyOpen, notFound }
