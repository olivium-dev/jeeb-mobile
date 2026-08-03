/// Vehicle-tier the sender picked at request creation. The cubit echoes the
/// gateway's `tier` field verbatim — the screen renders an icon + localized
/// label off it.
enum DeliveryTier {
  bike,
  scooter,
  car,
  pickup,
}
