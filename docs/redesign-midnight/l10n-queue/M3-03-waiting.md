# M3-03 — `no_offer_timeout` (waiting / no-coverage) · l10n queue

One new key. Everything else on this screen re-points to keys that already ship
(including E2's own `offersWaitingTitle` / `offersWaitingTitleCount`, which this
screen is the first to WIRE — the offer-review lane had to leave the counted
form unwired because no reach count reaches it; `notifiedCount` does reach here).

## New

| Key | EN | AR |
|---|---|---|
| `waitingErrorTitle` | `Couldn't load your request` | `تعذّر تحميل طلبك` |

`@waitingErrorTitle`: *"JM-026 waiting-screen load-failure headline. The mapped
`waitingErrorBody` / `waitingErrorContractBody` sentence becomes the body under
it, the same headline+body split R10 uses (`offersLoadErrorTitle`)."*

**Placeholder in the meantime:** `requestFeedErrorTitle` ("Couldn't load
requests") — nearest shipped headline of the same shape and noun — marked at the
call site with `TODO(midnight): l10n-queued`. Swap to `waitingErrorTitle` and
drop the TODO when this lands.

## Keys this screen stopped calling (NOT deletions — the l10n lane decides)

`requestSummaryFindingTitle`, `waitingReachingOutLabel`,
`requestSummaryFindingNotifiedCount`. The last one is still exercised directly by
`test/l10n/plural_forms_test.dart`, so it must not be dropped on this screen's
account alone.
