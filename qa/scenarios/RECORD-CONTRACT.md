# Scenario record contract

The pack uses normalized scenario-family files instead of 94 near-duplicate
standalone files. Every exact JMS ID is still a complete record. Read its
record by combining the following fields:

1. The suite header supplies result, owner, last verified date, authoritative
   source/AC set, default environment, privacy rule, and common cleanup.
2. The exact ID row supplies priority/gate, persona and mutation class,
   precondition, action, expected observable outcome, existing automation,
   required variants, and scenario-specific evidence.
3. [TRACEABILITY.md](TRACEABILITY.md) supplies routed production screens.
4. [PER-SCENARIO.md](checklists/PER-SCENARIO.md) supplies the exact execution
   record, device/network/locale parameters, step result, and classification.
5. [EVIDENCE.md](checklists/EVIDENCE.md) and the suite cleanup rule supply
   proof, privacy review, state read-back, and cleanup.

This normalized structure is deliberate: a shared field is inherited by every
row in its suite, while scenario-specific behavior remains in one place.

## Mandatory suite header

Every suite declares:

- Result: NOT RUN until exact evidence exists.
- Owner: accountable QA role.
- Last verified: Never until an exact dated run is recorded.
- Source / AC: current product code and any existing JM acceptance flow.
- Default preconditions: pre-run checklist plus the row’s Given clause.
- Default execution: one row at a time using the per-scenario checklist.
- Default cleanup: authoritative read-back followed by isolated fixture reset.
- Default evidence: evidence checklist plus the row’s required proof.

## Mandatory exact-ID row

Every row contains:

- Stable JMS ID.
- Priority and release gate.
- Persona and mutation class where applicable.
- Given / When / Then or equivalent fault/action/outcome.
- Source or automation mapping.
- Required variants and evidence.

If a row says Documented instead of naming current automation, the behavior is
still sourced from the suite’s current code/contract links. It is an automation
gap, not permission to invent a result. If the current product contract cannot
be confirmed, mark the run BLOCKED or INVALID before execution.

## Result records

Do not overwrite expected behavior with observed behavior. A run creates a
separate copied checklist/evidence record that names the exact JMS ID, build,
device, date, result, defect/blocker, cleanup, and evidence location.
