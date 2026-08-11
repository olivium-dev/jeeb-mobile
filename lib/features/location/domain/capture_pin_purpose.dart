import '../../../l10n/app_localizations.dart';

/// What the shared capture-location screen is picking — it used to claim
/// "Drop-off here" on every leg, pickup included.
enum CapturePinPurpose {
  /// Create-request location leg — the point the jeeber collects from.
  pickup,

  /// The delivery destination.
  dropOff,

  /// A plain point: a saved address, the jeeber home base / service area.
  place;

  static CapturePinPurpose parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pickup':
        return CapturePinPurpose.pickup;
      case 'dropoff':
      case 'drop-off':
      case 'drop_off':
        return CapturePinPurpose.dropOff;
      default:
        return CapturePinPurpose.place;
    }
  }

  String callout(AppLocalizations l10n) => switch (this) {
    CapturePinPurpose.pickup => l10n.captureLocationPickupCallout,
    CapturePinPurpose.dropOff => l10n.captureLocationDropOffCallout,
    CapturePinPurpose.place => l10n.captureLocationPlaceCallout,
  };

  String confirmCta(AppLocalizations l10n) => switch (this) {
    CapturePinPurpose.pickup => l10n.captureLocationConfirmPickupCta,
    CapturePinPurpose.dropOff => l10n.captureLocationConfirmDropOffCta,
    CapturePinPurpose.place => l10n.captureLocationConfirmPlaceCta,
  };
}
