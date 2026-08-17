import 'package:equatable/equatable.dart';

enum KycFieldType { string, enumField, date, file, unknown }

class KycFormField extends Equatable {
  const KycFormField({
    required this.key,
    required this.type,
    required this.i18nLabelKey,
    this.componentId = '',
    this.required = false,
    this.options = const [],
    this.validationRegex,
  });

  factory KycFormField.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? '';
    return KycFormField(
      // The live projection names the wire field `name`; the legacy shape this
      // parser was written against called it `key`. Accept either.
      key: (json['name'] ?? json['key']) as String? ?? '',
      componentId: json['componentID'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      type: _parseType(rawType),
      i18nLabelKey: json['i18n_label_key'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)?.cast<String>() ?? [],
      validationRegex:
          (json['validation'] as Map<String, dynamic>?)?['regex'] as String?,
    );
  }

  /// Wire field name, e.g. `id_document_front_url` — the key used in the
  /// submit body.
  final String key;

  /// Form-builder component id, e.g. `kyc-id-front-photo`. This — not [key] —
  /// is what `required_fields` lists.
  final String componentId;

  final bool required;

  final KycFieldType type;

  final String i18nLabelKey;

  final List<String> options;

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
  List<Object?> get props =>
      [key, componentId, required, type, i18nLabelKey, options, validationRegex];
}

class KycFormSchema extends Equatable {
  const KycFormSchema({
    required this.templateVersion,
    required this.templateName,
    required this.variant,
    required this.fields,
    this.requiredFields = const [],
  });

  /// The live gateway projection nests the form-builder render schema and lists
  /// its fields under `components`, with `required_fields` naming componentIDs.
  /// This parser previously read only `schema.fields`, a key the service does
  /// not emit — so [fields] silently parsed as EMPTY on every real response and
  /// the schema round-trip proved nothing. `fields` is still accepted so the
  /// legacy fixtures keep working.
  factory KycFormSchema.fromJson(Map<String, dynamic> json) {
    final rawSchema = json['schema'] as Map<String, dynamic>? ?? {};
    final rawFields =
        (rawSchema['components'] ?? rawSchema['fields']) as List<dynamic>? ??
            const [];
    return KycFormSchema(
      templateVersion: json['template_version'] as String? ?? '',
      templateName: json['template_name'] as String? ?? '',
      variant: json['variant'] as String? ?? 'national_id',
      fields: rawFields
          .cast<Map<String, dynamic>>()
          .map(KycFormField.fromJson)
          .toList(),
      requiredFields:
          (rawSchema['required_fields'] as List<dynamic>?)?.cast<String>() ??
              const [],
    );
  }

  final String templateVersion;
  final String templateName;
  final String variant;
  final List<KycFormField> fields;

  /// ComponentIDs the template declares mandatory. Reported, NOT enforced: the
  /// live `jeeb_jeeber_v1` still lists driver-licence and vehicle components
  /// that the ratified wizard deliberately stopped collecting (JM-040/D20
  /// dropped vehicle capture) and that no backend enforces — a submission
  /// carrying only the collected set is accepted (verified live 2026-08-17).
  /// Gating on this list here would block onboarding outright.
  final List<String> requiredFields;

  @override
  List<Object?> get props =>
      [templateVersion, templateName, variant, fields, requiredFields];
}
