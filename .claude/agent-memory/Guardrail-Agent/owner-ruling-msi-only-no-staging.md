---
name: owner-ruling-msi-only-no-staging
description: Owner ruling 2026-07-26 — never use the staging/production server; MSI 192.168.2.39 is the only backend any lane may touch
metadata:
  type: project
---

Owner ruling relayed by the Lane Governor on **2026-07-26**: **never use the staging server — MSI `192.168.2.39` only, for now.** No agent may deploy to, read from, point a build at, seed data into, run a test against, or fetch a credential/bearer from a staging or production host. Covers builds/APKs with a non-MSI `GATEWAY_BASE_URL`/`--dart-define`, integration checks, seeded test data, device runs, and credential fetches.

**Why:** the owner wants exactly one backend surface of record for the b02 "Polling → Push" batch so that acceptance evidence is comparable and no lane can drift onto a different baseline. MSI is dev/staging for Jeeb; a *deploy* there is still an integration-orchestrator action, never a feature lane's.

**How to apply:** put it in every guardrail brief as a BLOCKING guardrail with an objectively checkable line ("no non-MSI host in any changed file, dart-define, test config, or command in the execution log"). If a lane claims its work cannot be validated on MSI alone, that is a BLOCKER to escalate upward — never a local decision to reach for staging. Recorded durably in `/Users/oudaykhaled/Desktop/claude-ui/guardrails/15-workspace-rules.md` Rule 7 **and** `07-deploy-and-migration.md` ("MSI Is the ONLY Backend Environment"). See [[guardrails-kb-location]].

**Companion rule — the config file is a trap (verified live, twice).** A committed config is NOT evidence of which backend is live: `jeeb-gateway/appsettings.Production.json` names `PushNotificationServiceApi:BaseUrl = http://192.168.2.50:10040`, which is "No route to host" from MSI (all `.50` ports → `000`); the effective value is `PushNotificationServiceApi__BaseUrl=http://127.0.0.1:10040` from `/home/ec2-user/iter5-native/env/gateway.env`. Always resolve the effective backend from the **running process's environment** — a topology claim derived from a config file alone is inadmissible.

**How an agent PROVES a probe was MSI-only** (the enforcement answer, asked by the Lane Governor 2026-07-26): three layers, all required — (1) single chokepoint: every backend command goes through `docs/agents/scripts/msi.sh` or `adb -s <serial>`, never a bare remote `curl`; (2) target attestation: each evidence file's manifest line records the full command as issued plus a resolved `target=`, and any host token that is not `192.168.2.39` / `127.0.0.1` / a device serial is an audit failure (**including `192.168.2.50` and the `.20` DB box**); (3) self-identifying probes: run `hostname` inside the *same* invocation so the captured output carries the host identity rather than the agent asserting it. Evidence that fails layer 2 is inadmissible regardless of how correct the result looks.
