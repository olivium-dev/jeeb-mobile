# JMS-{DOMAIN}-{NNN} — Scenario title

Use this standalone template for a scenario that needs its own file. Scenario
families may instead use a normalized suite row, provided they follow the
[scenario record contract](../RECORD-CONTRACT.md) and inherit every mandatory
field from the suite header and shared checklists.

> Result: **NOT RUN**
> Owner: Mobile QA
> Last verified: Never

## Contract

| Field | Value |
|---|---|
| Source / acceptance criterion | Link or current-code reference |
| Persona | Customer / Jeeber / both / administrator |
| Priority | P0 / P1 / P2 / P3 |
| Gate | Smoke / Regression / RC / Exploratory |
| Mutation class | R0 read-only / R1 local / R2 isolated write / R3 sensitive lifecycle write |
| Privacy class | Public synthetic / masked synthetic / prohibited real data |
| Automation | Existing path, candidate, or manual only |
| Clarity screen names | Canonical names only; never parameters or user text |

## Preconditions

- [ ] Exact build SHA and artifact hash are recorded.
- [ ] Authorized environment, synthetic account aliases, fixture aliases, device,
      OS, locale, time zone, permissions, and network profile are recorded.
- [ ] Required receiver/device is online when the outcome depends on delivery.
- [ ] Destructive or state-mutating action is explicitly authorized and resettable.

## Acceptance scenario

```gherkin
Given one exact observable precondition
When one user-visible action or journey is completed
Then one primary observable outcome occurs
And the system has no unintended side effect
```

## Execution steps

| # | Action | Expected result | Evidence |
|---:|---|---|---|
| 1 | | | |
| 2 | | | |

## Variants

- Happy:
- Validation/negative:
- Boundary/illegal state:
- Timeout/offline/retry/idempotency:
- Permission denied:
- Lifecycle/process death:
- Concurrency/multi-device:
- English and Arabic RTL:
- Accessibility and large text:
- Supported/minimum OS:
- Privacy/security:
- Performance/resource:

## Cleanup and read-back

- [ ] The receiving surface proves the write with a unique nonce where relevant.
- [ ] The final server/product state is read back.
- [ ] Synthetic state is reset without touching shared or real data.

## Evidence and result

- [ ] Precondition evidence
- [ ] Result evidence
- [ ] Receiver-side evidence where required
- [ ] Timestamp, device/OS, build SHA, nonce, and artifact provenance
- [ ] Manual privacy/redaction review
- [ ] Secret scan

Final result: NOT RUN / PASS / FAIL / BLOCKED / INVALID
Failure category: APP_DEFECT / CONTRACT / ENVIRONMENT / FIXTURE / FLOW / PRIVACY
