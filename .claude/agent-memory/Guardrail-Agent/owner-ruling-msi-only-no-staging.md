---
name: owner-ruling-msi-only-no-staging
description: Historical owner ruling from 2026-07-26, superseded for approved Jeeb staging operations on 2026-08-18
metadata:
  type: project
---

## Status: superseded for approved staging operations

This ruling governed the 2026-07-26 b02 evidence batch. On **2026-08-18**, the owner
reactivated `192.168.2.20` (`olivium-ephemerals`) as the authoritative Jeeb staging
host and approved deployments through the `jeeb-staging-deploy` GitHub Actions
pipelines and Cloudflare SSH tunnel. Do not cite this historical ruling to block
those approved staging operations.

The original ruling required MSI `192.168.2.39` for that evidence batch and prohibited
ad hoc access to staging or production. Direct database access, unreviewed destructive
operations, and credentials copied into mobile tooling remain prohibited; use the
staging pipeline and its health gates.

**Why:** the owner wants exactly one backend surface of record for the b02 "Polling → Push" batch so that acceptance evidence is comparable and no lane can drift onto a different baseline. MSI is dev/staging for Jeeb; a *deploy* there is still an integration-orchestrator action, never a feature lane's.

**How to apply now:** retain MSI-only labels on historical b02 evidence. For current
work, distinguish ordinary feature-lane validation from owner-approved staging
deployments. Only the latter may target `192.168.2.20`, through the staging GitHub
Actions workflow with target-attestation and health gates. See [[guardrails-kb-location]].

**Companion rule — the config file is a trap (verified live, twice).** A committed config is NOT evidence of which backend is live: `jeeb-gateway/appsettings.Production.json` names `PushNotificationServiceApi:BaseUrl = http://192.168.2.50:10040`, which is "No route to host" from MSI (all `.50` ports → `000`); the effective value is `PushNotificationServiceApi__BaseUrl=http://127.0.0.1:10040` from `/home/ec2-user/iter5-native/env/gateway.env`. Always resolve the effective backend from the **running process's environment** — a topology claim derived from a config file alone is inadmissible.

**How an agent proves a probe was MSI-only** for historical or explicitly MSI-scoped
work: preserve the original three-layer evidence rule — use the MSI wrapper or a named
device, record the resolved target, and capture host identity in the same invocation.
For an approved staging deployment, the equivalent attestation is the workflow's exact
`olivium-ephemerals` plus `192.168.2.20` assertion.
