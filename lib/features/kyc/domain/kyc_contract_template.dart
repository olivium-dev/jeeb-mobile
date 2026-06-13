import 'package:equatable/equatable.dart';

/// Contract template meta returned by `GET /v1/kyc/contract-template?type=tos`.
///
/// Holds the template identifier used when POSTing the sign endpoint.
class KycContractTemplate extends Equatable {
  const KycContractTemplate({
    required this.templateId,
    required this.tosVersion,
    required this.documentUrl,
    required this.locale,
    required this.name,
  });

  final String templateId;
  final String tosVersion;

  /// CDN URL of the ToS markdown document.
  final String documentUrl;

  final String locale;
  final String name;

  factory KycContractTemplate.fromJson(Map<String, dynamic> json) {
    return KycContractTemplate(
      templateId: json['template_id'] as String? ?? '',
      tosVersion: json['tos_version'] as String? ?? '',
      documentUrl: json['document_url'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en',
      name: json['name'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props =>
      [templateId, tosVersion, documentUrl, locale, name];
}

/// Returned by `POST /v1/kyc/contract-template/sign`.
class KycSignStamp extends Equatable {
  const KycSignStamp({
    required this.tosSignedAt,
    required this.tosAcceptedVersion,
  });

  final DateTime tosSignedAt;
  final String tosAcceptedVersion;

  factory KycSignStamp.fromJson(Map<String, dynamic> json) {
    return KycSignStamp(
      tosSignedAt: DateTime.parse(json['tos_signed_at'] as String),
      tosAcceptedVersion: json['tos_accepted_version'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [tosSignedAt, tosAcceptedVersion];
}
