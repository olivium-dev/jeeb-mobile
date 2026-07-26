# FM-1 mobile fixture provenance

`captured-notification-service-offer-page.json` is the literal JSON response
captured read-only on 2026-07-26 through `docs/agents/scripts/msi.sh` from
receiver `FM1-PROBE-b02-20260726`.

Files prefixed `constructed-projected-` are honestly labelled gateway response
fixtures. FM-1 cannot deploy its 21-commits-behind gateway branch, so no live
FM-1 gateway projection can be captured. Each file is committed literally and
decoded without runtime field insertion/removal; none is presented as a
captured gateway response.
