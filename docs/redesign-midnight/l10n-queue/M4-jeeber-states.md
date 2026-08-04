# l10n queue — M4 · jeeber-side state surfaces

Lane: `jeeber_home` · `jeeber_request_feed` · `jeeber_request_detail` ·
`jeeber_pending_offers` · `offers` · `jeeber_active_deliveries` ·
`no_offer_timeout`.

`lib/l10n` belongs to the l10n lane — **this row added no keys and edited
neither ARB.** Every state below ships on an existing key with a
`TODO(midnight): l10n-queued` marker in-file.

## Requested keys

| Requested key | Proposed EN | Shipping on today | Where |
|---|---|---|---|
| `jeeberRequestDetailLoadingHeadline` | `Finding this request` | `jeeberRequestDetailTitle` (`Request details`) | `lib/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart` — `JeeberRequestDetailLoadingView` |
| `jeeberRegisterStreetSemantic` | a street-accurate a11y label for the E3 tile | `jeeberRegisterHeroSemantic` (`Delivery scooter bursting out of a phone`) | `lib/features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart` — `_UnregisteredHero` |

### Why each

**`jeeberRequestDetailLoadingHeadline`.** The loader's block headline currently
repeats the top-bar title verbatim, so `Request details` renders twice on one
screen. That is the ratified `jeeber_pending_offers` stand-in pattern (M3-36),
not a new invention, but it reads as duplication here because the bar sits
directly above the block. The `*LoadingHeadline` family already exists
(`orderHistoryLoadingHeadline`, `customerProfileLoadingHeadline`,
`activeDeliveryLoadingHeadline`, …); this is the missing member.

**`jeeberRegisterStreetSemantic`.** The upsell hero's semantic label still
describes the retired glyph (a scooter bursting out of a phone). The block now
draws E3's night street — a parked scooter under a streetlamp — so the label is
approximately, not actually, true. The `semanticLabel` slot is wired and will
pick up the new key with a one-word change.

## Reused, NOT new

These states ship on keys that already existed and already fit — recorded so a
later sweep does not mistake them for debt:

| State | Key(s) |
|---|---|
| request feed · empty | `requestFeedEmptyTitle` + `requestFeedEmptySubtitle` |
| request feed · error | `requestFeedErrorTitle` + `requestFeedErrorLoad` + `requestFeedErrorRetry` |
| request feed · loading | `requestFeedEmptyTitle` — byte-identical to the LIVE twin `jeeber_home_screen::_FeedLoadingView`, deliberately |
| `JeeberFeedEmptyView` · empty | `jeeberFeedEmptyTitle` + `jeeberFeedEmptySubtitle` |
| `JeeberUnregisteredView` · upsell | `jeeberRegisterTitle` + `jeeberRegisterSubtitle` + `jeeberRegisterCta` |

## Zero hard-coded strings

Grepped this lane's seven dirs after the change: no EN literal reaches a state
surface. Both ARBs untouched.
