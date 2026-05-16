/// Vehicle a Jeeber registers for KYC.
///
/// On-foot is included for low-volume opportunistic deliveries. IDs are stable
/// — the localized label is resolved through [VehicleTypeX.localizedLabel].
enum VehicleType { scooter, car, bicycle, onFoot }
