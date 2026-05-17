/// The vehicle a Jeeber proposes to use for a delivery. Display only on the
/// client offer card — the gateway is the source of truth for the actual tier
/// constraint matching.
enum JeeberVehicle {
  car,
  motorcycle,
  bicycle,
  scooter,
  walker,
  van,
}
