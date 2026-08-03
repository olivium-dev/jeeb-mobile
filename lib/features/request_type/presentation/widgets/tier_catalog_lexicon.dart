import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../tier_selection/domain/tier.dart';

/// The per-tier display marks the catalog rows need: the DS emoji and the
/// relative price level (how many of the four meter dots are filled).
@immutable
class TierCatalogMark {
  const TierCatalogMark({required this.emoji, required this.priceLevel});

  /// The DS tier emoji (`⚡ 🚀 🟦 🤝 🌿`).
  final String emoji;

  /// Filled dots out of four — flash 4 … eco 1 (08 `tpl 426-429`).
  final int priceLevel;
}

/// Client-side display lexicon for the tier catalog (redesign-2026-08 · 08).
///
/// Neither the price level nor the vehicle/meta line is a gateway field: the
/// board deliberately replaced the indicative dollar range with a *relative*
/// signal, and `Tier` carries no such column. Because the catalog is a closed
/// five-value product vocabulary (never data-driven growth), a const table is
/// the honest answer rather than an invented backend contract (plan §7.6).
///
/// Standard and On-the-Way are both 2/4 exactly as drawn (`tpl 458-461` /
/// `tpl 476-479`) — the board makes them equal, and this table does not
/// "correct" it.
TierCatalogMark tierCatalogMarkOf(TierId id) => switch (id) {
  TierId.flash => const TierCatalogMark(emoji: '⚡', priceLevel: 4),
  TierId.express => const TierCatalogMark(emoji: '🚀', priceLevel: 3),
  TierId.standard => const TierCatalogMark(emoji: '🟦', priceLevel: 2),
  TierId.onTheWay => const TierCatalogMark(emoji: '🤝', priceLevel: 2),
  TierId.eco => const TierCatalogMark(emoji: '🌿', priceLevel: 1),
};

/// The localized tier name (`Flash`, `Express`, …).
String tierCatalogName(AppLocalizations l10n, TierId id) => switch (id) {
  TierId.flash => l10n.tierFlashTitle,
  TierId.express => l10n.tierExpressTitle,
  TierId.standard => l10n.tierStandardTitle,
  TierId.onTheWay => l10n.tierOnTheWayTitle,
  TierId.eco => l10n.tierEcoTitle,
};

/// The relative-price caption under the meter (`Highest price` … `Lowest
/// price`). Ordered by [TierCatalogMark.priceLevel]; Standard and On-the-Way
/// share a level but not a wording, so this stays its own switch.
String tierCatalogPriceCaption(AppLocalizations l10n, TierId id) =>
    switch (id) {
      TierId.flash => l10n.tierCatalogPriceHighest,
      TierId.express => l10n.tierCatalogPriceHigher,
      TierId.standard => l10n.tierCatalogPriceBalanced,
      TierId.onTheWay => l10n.tierCatalogPriceLower,
      TierId.eco => l10n.tierCatalogPriceLowest,
    };

/// The second-row meta line (`Bike / scooter`, `Any vehicle`, …).
///
/// C7: this is tier metadata — "what kind of Jeeber picks this up" — not a
/// vehicle contract, so it ships as its own key family and never reuses the
/// D20-banned vehicle strings.
String tierCatalogMetaLabel(AppLocalizations l10n, TierId id) => switch (id) {
  TierId.flash => l10n.tierCatalogMetaFlash,
  TierId.express => l10n.tierCatalogMetaExpress,
  TierId.standard => l10n.tierCatalogMetaStandard,
  TierId.onTheWay => l10n.tierCatalogMetaOnTheWay,
  TierId.eco => l10n.tierCatalogMetaEco,
};

/// The glyph beside the meta line. The board draws it on Flash alone; C7 calls
/// that a design slip and mandates all five.
IconData tierCatalogVehicleIcon(TierVehicleClass vehicleClass) =>
    switch (vehicleClass) {
      TierVehicleClass.bikeOrScooter => Icons.two_wheeler_rounded,
      TierVehicleClass.scooterOrCar => Icons.directions_car_rounded,
      TierVehicleClass.carOrVan => Icons.local_shipping_rounded,
      TierVehicleClass.any => Icons.commute_rounded,
    };

/// The SLA chip copy, rendered from live [Tier.slaMinutes] — never from the
/// board's literals, which disagree with the catalog the gateway serves.
///
/// A null SLA is the opportunistic tier (On-the-Way): it reads `Flexible`, the
/// customer-facing wording, not the engineer-facing "No SLA".
String tierCatalogSlaLabel(AppLocalizations l10n, int? slaMinutes) {
  if (slaMinutes == null) return l10n.tierCatalogSlaFlexible;
  // Whole-hour SLAs read "≤ N hr"; anything finer falls back to minutes.
  if (slaMinutes >= 60 && slaMinutes % 60 == 0) {
    return l10n.tierSelectionSlaHours(slaMinutes ~/ 60);
  }
  return l10n.tierSelectionSlaMinutes(slaMinutes);
}
