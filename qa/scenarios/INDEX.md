# Jeeb Mobile scenario index

> Pack status: ACTIVE; scenario results remain NOT RUN until exact evidence exists
> Last updated: 2026-08-24
> Scenario namespace: JMS
> Default environment: explicitly authorized non-production lane with synthetic data; current store-candidate lane is staging

Each exact ID is a normalized record as defined by the
[scenario record contract](RECORD-CONTRACT.md). Every row inherits its suite
header and the linked execution/evidence/cleanup checklists.

The pack currently defines **95 exact JMS IDs**. The current remediation run
has 0 PASS, 0 FAIL, 0 BLOCKED, and 95 NOT RUN; its environment gates are
blocked before scenario execution.

## How the pack is organized

| Level | Purpose | Folder |
|---|---|---|
| 1 | Fast, understandable happy paths | [journeys](journeys/INDEX.md) |
| 2 | Feature regression and state coverage | [features](features/INDEX.md) |
| 3 | Cross-feature, adversarial, and recovery paths | [cross-cutting](cross-cutting/INDEX.md) |
| Run control | Repeatable execution, evidence, and release decisions | [checklists](checklists/INDEX.md) |

## Execution history

- [Test-run index](runs/INDEX.md)
- [Prior Android diagnostic run](runs/JMQA-20260823T183728Z/REPORT.md)
- [Current staging/store remediation run](runs/JMQA-REMEDIATION-20260823T215311Z/INDEX.md)

## Happy-path journeys

| ID | Journey | Personas | Risk | Gate | Status |
|---|---|---|---|---|---|
| JMS-JHP-001 | [Customer creates a request](journeys/JMS-JHP-001-CUSTOMER-REQUEST.md) | Customer | P0 | Smoke | NOT RUN |
| JMS-JHP-002 | [Jeeber activation, KYC, and offer](journeys/JMS-JHP-002-JEEBER-KYC-OFFER.md) | Customer becoming Jeeber | P0 | Regression | NOT RUN |
| JMS-JHP-003 | [Two-persona COD delivery loop](journeys/JMS-JHP-003-TWO-PERSONA-COD.md) | Customer + Jeeber | P0 | RC | NOT RUN |

## Feature suites

| Range | Domain | File | Status |
|---|---|---|---|
| JMS-AUTH-001–008 | Authentication, session, biometric, account state | [AUTH-SESSION.md](features/AUTH-SESSION.md) | NOT RUN |
| JMS-KYC-001–009 | Jeeber activation, KYC, capability synchronization | [KYC-ROLE.md](features/KYC-ROLE.md) | NOT RUN |
| JMS-REQ-001–008 | Request composition, location, waiting, offers | [REQUEST-OFFER.md](features/REQUEST-OFFER.md) | NOT RUN |
| JMS-DEL-001–012 | Delivery, chat, tracking, OTP, COD, rating | [DELIVERY-CHAT-COD.md](features/DELIVERY-CHAT-COD.md) | NOT RUN |
| JMS-OPS-001–010 | Notifications, settings, support, disputes, profiles | [SETTINGS-NOTIFICATIONS-SUPPORT.md](features/SETTINGS-NOTIFICATIONS-SUPPORT.md) | NOT RUN |
| JMS-CLR-001–012 | Clarity consent, masking, capture, session boundaries | [CLARITY-PRIVACY.md](features/CLARITY-PRIVACY.md) | NOT RUN |

## Complex and adversarial suites

| Range | Domain | File | Status |
|---|---|---|---|
| JMS-RES-001–010 | Offline, timeout, retry, idempotency, concurrency | [RESILIENCE-CONCURRENCY.md](cross-cutting/RESILIENCE-CONCURRENCY.md) | NOT RUN |
| JMS-PUSH-001–010 | Push, deep links, lifecycle, process death | [PUSH-DEEP-LINK-LIFECYCLE.md](cross-cutting/PUSH-DEEP-LINK-LIFECYCLE.md) | NOT RUN |
| JMS-LINK-001 | OS-verified App Link and Universal Link on store-delivered builds | [JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md](cross-cutting/JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md) | NOT RUN |
| JMS-XFN-001–012 | RTL, accessibility, privacy, security, performance | [LOCALE-ACCESSIBILITY-SECURITY.md](cross-cutting/LOCALE-ACCESSIBILITY-SECURITY.md) | NOT RUN |

## Result vocabulary

| Result | Meaning |
|---|---|
| NOT RUN | Drafted but no execution evidence exists |
| PASS | Exact scenario and all evidence requirements passed |
| FAIL | Product or contract outcome differs from expected |
| BLOCKED | A required product capability, environment, authorization, fixture, or device is unavailable |
| INVALID | The scenario no longer matches the current product contract and must be revised |

Mocks, sender-only logs, an HTTP success code, or navigation to a substitute
screen cannot by themselves produce PASS.

Store-gated scenarios also reject sideloads. For `JMS-LINK-001`, only the exact
Play Internal Testing and TestFlight deliveries count as executable evidence.

## Existing automation

The semantic-ID Maestro flows under ../../.maestro/flows are reusable evidence
sources when their current prerequisites and assertions match a JMS scenario.
The older ../../.maestro/jeeb customer suite targets a live gateway, uses
coordinate navigation, and can create live requests; it is opt-in diagnostic
material, not the default runner for this pack.

## Current supporting sources

- [Production router](../../lib/core/router/app_router.dart)
- [Clarity canonical screen allowlist](../../lib/core/analytics/clarity/presentation/clarity_navigator_observer.dart)
- [Semantic-ID testing guardrail](../../docs/build-out/41_GUARDRAILS_TESTING.md)
- [Maestro execution playbook](../../docs/build-out/71_MAESTRO_QA_PLAYBOOK.md)
- [Current UI findings triage](../../docs/previews/FINDINGS_TRIAGE.md)
- [Request-lifecycle race matrix](../../docs/sprints/sprint-009/scenario-matrix.md)

The older qa/test-plan files are supporting history only when they agree with
workspace policy and current code.
