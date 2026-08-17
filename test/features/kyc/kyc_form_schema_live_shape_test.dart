import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_form_schema.dart';

/// The gateway's `GET /v1/kyc/jeeb/form-schema` projects the form-builder
/// render schema for `jeeb_jeeber_v1`. It lists fields under
/// `schema.components` with `schema.required_fields` naming componentIDs —
/// but [KycFormSchema.fromJson] read `schema.fields`, a key the service does
/// not emit. Every real response therefore parsed to ZERO fields, silently.
///
/// The payload below is the live 200 body, captured verbatim from MSI
/// (192.168.2.39) on 2026-08-17 and trimmed to three components.
void main() {
  const liveBody = {
    'template_version': 'v1',
    'template_name': 'jeeb_jeeber_v1',
    'variant': 'national_id',
    'schema': {
      'template_name': 'jeeb_jeeber_v1',
      'components': [
        {
          'name': 'id_document_front_url',
          'type': 'string',
          'required': true,
          'componentID': 'kyc-id-front-photo',
        },
        {
          'name': 'id_number',
          'type': 'string',
          'required': true,
          'componentID': 'kyc-id-number',
        },
        {
          'name': 'vehicle_plate_number',
          'type': 'string',
          'required': true,
          'componentID': 'kyc-vehicle-plate-number',
        },
      ],
      'required_fields': [
        'kyc-id-front-photo',
        'kyc-id-number',
        'kyc-vehicle-plate-number',
      ],
    },
  };

  group('KycFormSchema — live wire shape', () {
    test('parses the components the live service actually emits', () {
      final schema = KycFormSchema.fromJson(liveBody);

      expect(schema.templateName, 'jeeb_jeeber_v1');
      expect(schema.templateVersion, 'v1');
      expect(schema.variant, 'national_id');
      expect(
        schema.fields,
        hasLength(3),
        reason: 'reading schema.fields instead of schema.components parsed 0',
      );
      expect(
        schema.fields.map((f) => f.key),
        containsAll(<String>['id_document_front_url', 'id_number']),
      );
      expect(schema.fields.first.componentId, 'kyc-id-front-photo');
      expect(schema.fields.first.required, isTrue);
      expect(schema.requiredFields, hasLength(3));
    });

    test(
        'NEGATIVE CONTROL: a body with no components still parses to zero, so '
        'the assertion above can fail', () {
      final schema = KycFormSchema.fromJson(const {
        'template_version': 'v1',
        'template_name': 'jeeb_jeeber_v1',
        'variant': 'national_id',
        'schema': {'template_name': 'jeeb_jeeber_v1'},
      });

      expect(schema.fields, isEmpty);
      expect(schema.requiredFields, isEmpty);
    });

    test('the legacy `fields` shape still parses (fixtures depend on it)', () {
      final schema = KycFormSchema.fromJson(const {
        'template_version': 'v1',
        'template_name': 'jeeb_jeeber_v1',
        'variant': 'passport',
        'schema': {
          'fields': [
            {
              'key': 'id_number',
              'type': 'string',
              'i18n_label_key': 'kyc.idNumber',
              'validation': {'regex': r'^[A-Z0-9]{6,9}$'},
            },
          ],
        },
      });

      expect(schema.fields, hasLength(1));
      expect(schema.fields.single.key, 'id_number');
      expect(schema.fields.single.validationRegex, r'^[A-Z0-9]{6,9}$');
    });

    test(
        'required_fields is reported but names components the wizard does not '
        'collect — so it must never be used as a submit gate', () {
      final schema = KycFormSchema.fromJson(liveBody);

      // The live template still demands vehicle capture that JM-040/D20
      // deliberately removed, and that no backend enforces (a submission
      // carrying only the collected set returned 201 on live 2026-08-17).
      expect(schema.requiredFields, contains('kyc-vehicle-plate-number'));
      expect(
        schema.fields.map((f) => f.key),
        isNot(contains('driver_license_number')),
      );
    });
  });
}
