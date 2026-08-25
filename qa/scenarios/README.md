# Jeeb Mobile test scenarios

This folder is the master, executable documentation pack for Jeeb Mobile. It
starts with short happy paths and expands into full two-persona, failure,
privacy, lifecycle, concurrency, localization, and security journeys.

All scenarios default to **NOT RUN**. Creating this pack does not authorize a
device run, environment change, store upload, request, KYC submission, message,
account deletion, or Microsoft Clarity setting change.

## Start here

1. [Master scenario index](INDEX.md)
2. [Traceability and screen coverage](TRACEABILITY.md)
3. [Scenario record contract](RECORD-CONTRACT.md)
4. [Smoke, regression, and release gates](GATE-MATRIX.md)
5. [Pre-run checklist](checklists/PRE-RUN.md)
6. [Scenario template](_templates/SCENARIO.md)
7. [Execution history](runs/INDEX.md)

## Non-negotiable product and safety rules

- Jeeb is cash-on-delivery only. No electronic payment, card capture, gateway
  settlement, or money-moving refund scenario belongs in this pack.
- Cash is handed directly from the customer to the Jeeber. Tests validate UI,
  status, receipt, and audit behavior; they never move real money.
- Use synthetic, owner-controlled adult test accounts and non-sensitive test
  content only.
- Never use real faces, identity documents, addresses, locations, messages,
  phone numbers, tokens, OTP values, or account identifiers in evidence.
- Run only in an explicitly authorized Jeeb test environment. Never contact
  the forbidden host named in the workspace AGENTS.md policy.
- Release-candidate evidence must come from the exact Play Internal Testing or
  TestFlight delivery when the scenario crosses an OS/store boundary. Sideloads
  and debug builds are diagnostic evidence only.
- Normal phone/OTP is mandatory for auth-dependent release evidence. Super
  Login Plus, demo users, mocks, fake providers, and crafted local state cannot
  satisfy a scenario.
- A drafted scenario is not evidence. PASS requires the exact path, observable
  result, cleanup, and reviewed evidence specified by that scenario.

## Source hierarchy

When documents disagree, use this order:

1. Workspace AGENTS.md locked policies.
2. Current production route and feature code.
3. This scenario pack.
4. Existing qa/test-plan-*.md and historical build-out documents.

Some older QA plans describe retired authentication, vehicle-KYC, electronic
payment, settlement, or refund behavior. Those passages are historical and are
not requirements for Jeeb.
