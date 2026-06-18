import 'package:equatable/equatable.dart';

/// Field type in the form-builder schema rendered by the gateway.
enum KycFieldType { string, enumField, date, file, unknown }

/// One field descriptor from the form-builder schema.
///
/// Mirrors the `schema.fields[]` shape from `GET /v1/kyc/jeeb/form-schema`.
class KycFormField extends Equatable {
  const KycFormField({
    required this.key,
    required this.type,
    required this.i18nLabelKey,
    this.options = const [],
    this.validationRegex,
  });

  factory KycFormField.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? '';
    return KycFormField(
      key: json['key'] as String? ?? '',
      type: _parseType(rawType),
      i18nLabelKey: json['i18n_label_key'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)?.cast<String>() ?? [],
      validationRegex:
          (json['validation'] as Map<String, dynamic>?)?['regex'] as String?,
    );
  }

  final String key;
  final KycFieldType type;

  /// Backend i18n label key — displayed as-is since mobile resolves labels
  /// from its own ARB catalogue via [KycFormSchema.resolveLabel].
  final String i18nLabelKey;

  /// Non-empty for [KycFieldType.enumField] fields.
  final List<String> options;

  /// Optional regex validation for string fields.
  final String? validationRegex;

  static KycFieldType _parseType(String raw) {
    switch (raw) {
      case 'string':
        return KycFieldType.string;
      case 'enum':
        return KycFieldType.enumField;
      case 'date':
        return KycFieldType.date;
      case 'file':
        return KycFieldType.file;
      default:
        return KycFieldType.unknown;
    }
  }

  @override
  List<Object?> get props => [
    key,
    type,
    i18nLabelKey,
    options,
    validationRegex,
  ];
}

/// Schema envelope returned by `GET /v1/kyc/jeeb/form-schema`.
class KycFormSchema extends Equatable {
  const KycFormSchema({
    required this.templateVersion,
    required this.templateName,
    required this.variant,
    required this.fields,
  });

  factory KycFormSchema.fromJson(Map<String, dynamic> json) {
    final rawSchema = json['schema'] as Map<String, dynamic>? ?? {};
    final rawFields = rawSchema['fields'] as List<dynamic>? ?? [];
    return KycFormSchema(
      templateVersion: json['template_version'] as String? ?? '',
      templateName: json['template_name'] as String? ?? '',
      variant: json['variant'] as String? ?? 'national_id',
      fields: rawFields
          .cast<Map<String, dynamic>>()
          .map(KycFormField.fromJson)
          .toList(),
    );
  }

  final String templateVersion;
  final String templateName;
  final String variant;
  final List<KycFormField> fields;

  @override
  List<Object?> get props => [templateVersion, templateName, variant, fields];
}
