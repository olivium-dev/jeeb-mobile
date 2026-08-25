# Sanitized physical-run log summary

> Run: JMQA-20260823T183728Z
>
> Lane: physical A33
>
> Window: corrective visible wave, 2026-08-23 19:03:48–19:10:57 UTC
>
> Raw classification: PRIVATE-ONLY

## Retained raw artifacts

| Artifact | Size/count | SHA-256 | Share status |
|---|---:|---|---|
| Visible-wave runtime log | 162 lines | `9b75afa408f266489b24aeab3624811385f810bbd1bd4b4170c5495661380a7a` | Private; aggregate counts only |
| Package exit history | 20 lines | `9fed892a6b11b70413d77bee74e0d10dd7ad81c4931d2324aba7ae7ecb5cfe1e` | Private; aggregate counts only |
| Final memory snapshot | 77 lines | `b96094784ae8cb179a56806945a87ed2c30c57c187b8f42917864c830edc32e9` | Private; aggregate values only |
| Screenshot checksum manifest | 21 entries | Per-file values retained in private manifest | Hash list safe after path review |

Raw files live under the workspace's private temporary QA directory and are due
for deletion on 2026-08-30 after review. They are intentionally not copied into
this versioned scenario pack.

## Bounded error and exit counts

| Signal | Count |
|---|---:|
| Fatal exception | 0 |
| ANR in bounded log | 0 |
| FlutterError | 0 |
| Unhandled Exception | 0 |
| Crash exit record | 0 |
| ANR exit record | 0 |

These are windowed observations, not a soak-test or full-session stability
claim. The app process remained PID `5444` during the visible wave.

## Final memory observation

| Metric | Value |
|---|---:|
| Total PSS | 239,283 KB |
| Total RSS | 286,251 KB |
| Total Swap PSS | 36,295 KB |

This is one final sample. It cannot establish a leak, regression, or budget
PASS/FAIL.

## Text privacy and policy scan

The retained runtime log and exit history produced the following exact match
counts:

| Pattern class | Count |
|---|---:|
| JWT-like token | 0 |
| Authorization header | 0 |
| Email-like value | 0 |
| Forbidden-host marker | 0 |
| Electronic-payment-gateway marker | 0 |

Binary screenshots were not treated as sanitized by this text scan. Direct
visual review classified all screenshots PRIVATE-ONLY because at least part of
the set contains synthetic identity, precise location, entity IDs, or chat
content.
