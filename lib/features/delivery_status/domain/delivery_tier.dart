/// Vehicle-tier the sender picked at request creation. The cubit echoes the
/// gateway's `tier` field verbatim — the screen renders an icon + localized
/// label off it.
///
/// Mirrors the tiers that `src/JeebGateway/Tiers/` owns; we don't infer fees
/// here (those are computed server-side and arrive separately).
enum DeliveryTier {
  bike,
  scooter,
  car,
  pickup,
}
