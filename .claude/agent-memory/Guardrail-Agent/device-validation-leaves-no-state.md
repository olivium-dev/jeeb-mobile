---
name: device-validation-leaves-no-state
description: Every device run records created ids to CREATED.jsonl and ends with tool/device_validation_cleanup.sh sweep && audit; a REPORT without a Residual-state section is rejected
metadata:
  type: project
---

Cancel does not close pending offers on the gateway: withdraw the offer first, then cancel the request, then re-read both projections. `sweep`/`audit` need `--execute` plus explicit `--actor` ids inside an authorized quiet window; a dry run proves nothing.

TRAP: the same offer has two vocabularies. `GET /v1/requests/{id}/offers` is verbatim upstream (`submitted`/`edited`); `GET /v1/jeebers/me/offers` normalizes to `pending` and folds `rejected`/`expired` to `superseded` (`UpstreamPendingOffersStore.MapStatus` vs `MapOwnStatus`). Compare the two projections by live-versus-terminal class, never by string equality.
