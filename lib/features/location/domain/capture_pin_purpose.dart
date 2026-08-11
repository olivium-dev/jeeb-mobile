import '../../../l10n/app_localizations.dart';

/// What the capture-location pin is choosing. The screen is shared by the
/// create-flow PICKUP leg, the saved-address/service-area pick and the
/// drop-off leg; it used to claim "Drop-off here" on all three.
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
