import 'package:flutter/widgets.dart';

/// Feature-local EN/AR copy for the JM-050 address-detail-form field labels that
/// have **no existing ARB key** (Building / Floor-apt / Delivery-notes / COD
/// phone / the edit-pin CTA / the "use a saved pin" hint).
///
/// Mirrors the JM-031 `order_summary_l10n.dart` precedent: the ARB is
/// integrator-owned and per-screen engineers must not edit it (40_GUARDRAILS
/// §9), so the missing strings live here, locale-resolved off the active
/// `Directionality`/`Locale`, until the integrator batches the dedicated
/// `addressForm*` keys (requested in 50_ROUTE_REQUESTS). Maestro keys on the
/// `Semantics(identifier:)`, never the text, so this is cosmetic copy only — the
/// labels are NOT load-bearing for the flow.
class AddressFormL10n {
  const AddressFormL10n._(this._ar);

  factory AddressFormL10n.of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return AddressFormL10n._(code == 'ar');
  }

  final bool _ar;

  String get buildingLabel => _ar ? 'المبنى' : 'Building';
  String get buildingHint => _ar ? 'اسم أو رقم المبنى' : 'Building name or no.';

  String get floorAptLabel => _ar ? 'الطابق / الشقة' : 'Floor / apartment';
  String get floorAptHint => _ar ? 'الطابق 4، شقة 12' : '4th floor, Apt 12';

  String get deliveryNotesLabel =>
      _ar ? 'ملاحظات التسليم' : 'Delivery notes';
  String get deliveryNotesHint =>
      _ar ? 'اقرع الجرس مرتين؛ الباب الأزرق.' : 'Ring twice; blue door.';

  String get codPhoneLabel =>
      _ar ? 'هاتف الدفع عند الاستلام' : 'Cash-on-delivery phone';
  String get codPhoneHint =>
      _ar ? 'رقم يتصل به الجيبر عند التسليم' : 'Number the Jeeber calls on delivery';

  String get pinSectionTitle =>
      _ar ? 'الموقع على الخريطة' : 'Location on the map';
  String get editPinCta => _ar ? 'تعديل الدبوس' : 'Edit pin';
  String get pinPlaceholder =>
      _ar ? 'تم اختيار الموقع' : 'Location selected';
  String get pinMissing =>
      _ar ? 'اختر موقعًا على الخريطة' : 'Pick a location on the map';
}
