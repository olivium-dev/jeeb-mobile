---
name: push-service-has-no-read-api
description: Verified — the MSI push service exposes NO GET for device registrations, so any device-row prune is unsnapshottable and unverifiable by construction. Shapes every JEBV4-324 remedy plan.
metadata:
  type: project
---

**Verified live 2026-07-26** (`GET /openapi.json` on MSI `127.0.0.1:10040`, "Push Notifications API 1.0.0"). The complete surface is:

`PUT /api/v1/register` · `DELETE /api/v1/register/by-device-and-user` · `DELETE /api/v1/register/by-user` · `POST /api/v1/sent-payload/{broadcast,device/{id},topic/{name},user/{id}}` · `GET /health`

**There is no GET on `/register`.** Device rows therefore cannot be enumerated, snapshotted, or verified after deletion — and MSI has no `psql`, and direct access to the `[decommissioned-host]` DB box is banned by standing policy. DB name is `jeeb-push-notifications` (Jeeb-scoped data on the shared `[decommissioned-host]` host), so a delete cannot reach a sibling product — but it can reach any Jeeb user's rows, invisibly.

**Why it matters:** `DELETE /api/v1/register/by-user` is a blind, unbounded, irreversible destructive operation. "Snapshot before you delete" is *impossible* to satisfy here — any plan claiming to snapshot device rows is claiming something the API cannot do.

**How to apply:** for any JEBV4-324-style prune, rule `by-user` out entirely; allow only `by-device-and-user` for a device physically in hand, with a demonstrated `PUT /api/v1/register` restore tuple as the substitute for a snapshot. Note `PUT /api/v1/register` is an **upsert** — minting a fresh token usually replaces the dead row at zero destructive cost, so check whether the prune is needed at all before deleting anything.

Generalized into law as "Runtime Data Deletion Through a Service API — Delete Only What You Can Enumerate or Recreate" in `/Users/oudaykhaled/Desktop/claude-ui/guardrails/07-deploy-and-migration.md`. Related: [[owner-ruling-msi-only]].
