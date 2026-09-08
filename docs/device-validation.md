# Device validation: record creations, verify cleanup, restore the phone

Every device run uses one private evidence directory and a shared `CREATED.jsonl` ledger. Record each newly created request, offer and session at creation time. Finish with an authorized ledger-bound sweep, an audit of **every account used**, and a **Residual state** section in the run's `REPORT.md`. Missing evidence, failed checks or an offline dry-run are not cleanup acceptance.

This tooling implements P04 **Part B only** on #335 under OD-0 widen and OD-6. It neither performs the historical Part A cleanup nor assumes its old IDs/status/deadline are current. See [the historical problem and cancellation-route evidence](ux-failure-states/plans/PLAN-P04-stray-test-request.md) and [current execution decisions](ux-failure-states/plans/EXECUTION-PLAN-2026-09-06.md).

## Record non-secret provenance

Set `JEEB_DEVICE_EVIDENCE_DIR` to an existing absolute private directory outside the repository. `JEEB_GATEWAY` defaults to `https://msi.olivium.space/gateway`; the only other permitted value is `https://192.168.2.39/gateway`, using normal TLS verification. Plain HTTP, alternate ports, redirects, production, foreign hosts and arbitrary `--allow-host` overrides are refused. If the LAN server cannot meet this envelope, use approved MSI HTTPS; do not disable certificate verification.

Replace the labels below with the **actual newly created UUIDs** observed through the approved workflow. These commands append local provenance, not gateway mutations:

```sh
bash tool/device_validation_cleanup.sh record request REQUEST_UUID CLIENT_UUID "created-for-this-run"
bash tool/device_validation_cleanup.sh record offer OFFER_UUID DRIVER_UUID "created-for-this-run" --request REQUEST_UUID
bash tool/device_validation_cleanup.sh record session USER_UUID USER_UUID "approved-ui-session"
bash tool/device_validation_cleanup.sh record note MESSAGE_UUID AUTHOR_UUID "immutable-chat-message"
```

Do not put access/refresh tokens, JWTs, secrets or raw response bodies in IDs, notes, environment variables, terminal commands or reports. Session rows contain **user IDs only**, not credential or backend session identifiers. `record` adds a timestamp and exact gateway; writes are locked, appended and flushed durably with mode 0600. UUIDs and ownership bindings are validated. A duplicate entity with conflicting owner/request provenance blocks execution.

Existing hand-written historical ledgers without gateway provenance are intentionally refused. The operator must independently verify their creation evidence and ownership, then explicitly record confirmed entries through the tool in a new run directory. Never turn an unrecorded pre-existing production/business entity into a cleanup target merely to make an audit pass.

## Default mode is offline only

```sh
bash tool/device_validation_cleanup.sh sweep
bash tool/device_validation_cleanup.sh audit CLIENT_UUID DRIVER_UUID
```

Without `--execute`, these validate the local ledger and print **DRY RUN ONLY**. They send no HTTP, mint no sessions and change no gateway state. They do **not** establish that any entity is clean or that an audit passed. This is the safe default for review and handoff.

## Authorized execution window

Only run the following during the approved serial validation/cleanup workflow with creation provenance and explicit actor authorization. Stop concurrent test activity on these entities first. `--execute` authorizes the operation's session issuance as well as its reads/deletes; even `audit --execute` issues sessions before performing read-only entity checks.

```sh
bash tool/device_validation_cleanup.sh sweep --execute --actor CLIENT_UUID --actor DRIVER_UUID
bash tool/device_validation_cleanup.sh audit CLIENT_UUID DRIVER_UUID --execute
```

The tool mints each actor's session with the role set that actor's ledger purpose needs: `["customer"]` for a request owner and `["customer","driver"]` for an actor that owns a recorded offer, because offer withdrawal is jeeber-only on the gateway. It never requests admin or operator roles, and it writes the requested set into the session ledger note. A mint that carries no roles is answered 404 whenever the gateway holds no in-process profile for the account, so omitting the role set would strand the run instead of authorizing it. It records each issuance **attempt before sending it**, because a transport failure may leave the outcome unknown. Returned access tokens stay in process memory, are cached once per actor per invocation, and are never printed or written; refresh tokens are not stored or used. `/v1/users/me` must confirm the exact actor before entity operations. A 401/403 from issuance or a later authorization failure exits 2 with an owner handoff, never an auth bypass.

Sweep safety and order:

1. Every mutable ledger owner must be explicitly listed via `--actor`. Every recorded offer must point to a request with creation provenance in the same ledger. The tool verifies request ID/client ownership, offer ID/parent/jeeber ownership, and complete list responses before the first entity mutation.
2. Any unledgered pending offer, foreign owner, assigned request, accepted offer, unexpected state, missing projection, incomplete paginated list or malformed response stops the run. The gateway renders one offer in two vocabularies — `GET /v1/requests/{id}/offers` keeps the upstream words (`submitted`, `edited`) while `GET /v1/jeebers/me/offers` normalizes them to `pending` and folds `rejected`/`expired` to `superseded` — so the projections are compared by live-versus-terminal class, never by string equality. A class disagreement (for example parent `withdrawn` with own `pending`, or parent `submitted` with own `superseded`) and a live offer absent from either projection both stop the run before any mutation. It does not auto-withdraw another tester's newly discovered offer.
3. Requests are processed newest first. Live **recorded** offers (`pending`, `submitted`, `edited` — the jeeber's own list shows all three as `pending`) are withdrawn before their request is cancelled; `withdrawn`, `expired`, `rejected` and `superseded` are the terminal offer states and are left untouched. Both parent and own-offer projections are re-read. Immediately before cancelling, the request is re-read and must still be pending/scheduled/matched with no assigned jeeber; pending offers must be gone.
4. A 200/204 or 409 alone is never proof. Post-action reads must show a terminal request and no pending recorded offer. Every recorded own offer is checked before and after cancellation, including offers already terminal in the parent list, and a final pass verifies all ledger-bound projections. Already terminal requests are not cancelled again. A 409 followed by pending state fails. A 404 is not silently counted as cleanup success because its ownership/state cannot be verified. These are point-in-time reads, not a transaction against concurrent external writers; the required serial workflow remains mandatory.
5. Existing gateway APIs do not provide an atomic compare-and-cancel guard against another actor accepting between the final read and DELETE. Repeated prechecks narrow that race but cannot eliminate it. **Do not run automated sweep during concurrent acceptance activity**; use an owner-controlled quiet window or obtain a gateway conditional-state contract first. This limitation is not solved by this local script.

Audit prints nonterminal requests or pending offers absent from the ledger; it never mutates those rows. It rejects foreign rows and incomplete lists rather than claiming a clean audit. Audit checks **unrecorded active state**, not whether recorded entries are terminal; therefore a passing audit must accompany a successful sweep, not replace it. An account lacking permission to read one surface yields a handoff instead of silently skipping that surface.

Exit 0 means the requested operation completed (or was explicitly labeled dry-run); exit 1 means refused/failed/unverified state; exit 2 means owner intervention is needed. A partially completed sweep can have already withdrawn earlier recorded offers: retain all output, inspect current state and retry only within renewed authorization. No bulk entity deletion, admin routes, user seeding, arbitrary host override or automated session revocation exists.

## Restore the phone and report residue

Record starting app URL, locale, radio state, session and jeeber availability. Restore those exact values afterward through the real UI; approved Super Login Plus UI re-entry may restore the session. Use `adb install -r` for authorized updates only; never uninstall or clear app data. Prefer already approved test accounts; creating Scenario Users or test entities retains the workflow's separate approval and provenance requirements.

The report's **Residual state** section must include actual sweep/audit results, target head/build, every account used, entity terminal states, restored URL/session/locale/radios/availability, and immutable residue such as inbox rows, conversations and chat messages. List session issuance attempts, their known/unknown outcomes and owner follow-up without credentials. The tool does not revoke sessions or erase immutable residue. A missing or failed restoration/cleanup step makes the run incomplete.

Why order matters: the reviewed gateway cancellation path does not close pending offers, while automatic expiry depends on upstream delivery projection. Never rely on historical expiry timestamps or a successful cancel response to prove the offer was removed.

For local fault scenarios, use [the P08 loopback proxy and scoped device runbook](../tool/fault_proxy/README.md). CI runs `bash tool/test_device_validation_cleanup.sh`: all operations there use an in-memory stub/mocked HTTP transport, no real account, token, gateway or phone. These tests prove tooling behavior, not live cleanup acceptance.
