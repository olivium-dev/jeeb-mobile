# l10n queue — M3-01 `delivery_detail_screen.dart` (`/orders/:id`)

Owner lane: M3-01. The l10n lane owns `lib/l10n/*.arb`; this file is the request.

## New keys

### 1. `deliveryDetailEtaMinutes`

The R21 in-motion band draws `In transit · ETA 20 min`. The screen currently borrows
`chatOfferEtaMinutes` (identical EN/AR text, wrong domain — it is the offer-card key) with a
`TODO(midnight): l10n-queued` at the call site.

| locale | value |
|---|---|
| en | `ETA {minutes} min` |
| ar | `الوصول خلال {minutes} دقيقة` |

```json
"deliveryDetailEtaMinutes": "ETA {minutes} min",
"@deliveryDetailEtaMinutes": {
  "description": "Locked ETA on the client order-detail in-motion status band (/orders/:id). Same wording as chatOfferEtaMinutes, which this replaces at that call site.",
  "placeholders": { "minutes": { "type": "int" } }
}
```

Call site: `lib/features/deep_link_targets/delivery_detail_screen.dart`, `_ActiveStatusBand.build`
(`l10n.chatOfferEtaMinutes(eta)` → `l10n.deliveryDetailEtaMinutes(eta)`).

## Deliberately NOT queued

- **No `deliveryDetailActiveBanner` key.** The active band's headline reuses the canonical
  `deliveryStage*` vocabulary (`deliveryStageMatched` / `deliveryStagePickedUp` /
  `deliveryStageInTransit`), which is the same vocabulary the tracking and pinned-summary
  surfaces already speak. A second spelling of "In transit" would be a divergence, not a key.
- **No loading-state headline key.** The cold-read skeleton reuses `deliveryDetailsTitle`, the
  screen's own title — the same shape R3's loading body uses (`trackingTitle`).
- **No header-subtitle key.** The header's second line is the request `displayId` verbatim
  (`OrderChatSummary.orderRef`); it is a value, not a phrase.
