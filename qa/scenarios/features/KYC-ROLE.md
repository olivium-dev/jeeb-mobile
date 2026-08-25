# Jeeber activation and KYC scenarios

> Suite result: **NOT RUN**
> Current model: Jeeber is an additive account capability. Five shell tabs stay
> mounted; there is no client/Jeeber mode-toggle happy path.

> Owner: Mobile QA + KYC test-state owner
> Last verified: Never
> Source / AC: [current router](../../../lib/core/router/app_router.dart), current
> KYC/Jeeber capability code, and the JM flows named per row

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the Given clause. Execute the
row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); read back
KYC/capability/offer state, reset isolated fixtures, and apply the
[evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Persona / mutation | Given / When / Then | Source / automation | Required variants and evidence |
|---|---|---|---|---|---|
| JMS-KYC-001 | P0 / Smoke | Customer without capability / R0 | Given no Jeeber approval, when Dashboard/Delivery entry is opened, then registration prompt appears and live offer actions remain unavailable. | jm-036 | none/pending/rejected; deep link; stale local role; no feed data leakage |
| JMS-KYC-002 | P0 / Regression | Customer becoming Jeeber / R2 | Given the registration prompt, when personal/photo, address, and service-area steps complete, then KYC begins without a vehicle-registration step. | jm-037–040 partial | Back navigation; permission denial; location failure; process death; no mode toggle |
| JMS-KYC-003 | P1 / Regression | KYC submitter / R3 | Given complete synthetic KYC fields, when submit is tapped once, then one pending submission and funding/information handoff appear without electronic payment. | jm-040, jm-041 | Double tap; upload timeout; partial upload; background; no raw media retained |
| JMS-KYC-004 | P0 / Regression | Pending/approved user / R0–R2 | Given server KYC state changes, when the app foregrounds or cold-starts, then status and available_roles refresh from server and approved feed access appears once. | jm-042 | none/pending/approved; stale prefs; polling expiry; offline transition; read-back |
| JMS-KYC-005 | P0 / Regression | Finally rejected user / R2 | Given final KYC rejection, when details/appeal is opened, then reason is safe, no general resubmit appears, and support appeal is reachable. | jm-043, jm-063 | Missing reason; deep link; EN/AR; support failure; no sensitive document echo |
| JMS-KYC-006 | P1 / RC | User directed to correct fields / R3 | Given backend explicitly requests field resubmission, when only named synthetic fields are replaced, then unchanged fields remain and one new review starts. | Documented | Each field subset; invalid image; interrupted upload; old decision cannot overwrite new review |
| JMS-KYC-007 | P0 / Regression | Unapproved offerer / R0 | Given non-approved KYC, when an offer entry point is opened directly or from feed, then offer-kyc-gate blocks the composer. | jm-044, jm-048 | none/pending/rejected; crafted deep link; back behavior; no request detail leakage |
| JMS-KYC-008 | P0 / Regression | Approved Jeeber / R2 | Given approval and an open request, when one valid offer is submitted, then it appears once in Pending Offers and the customer can observe it. | jm-045, jm-048 | Insufficient internal balance display; expired request; 409; timeout; unique nonce read-back |
| JMS-KYC-009 | P1 / Regression | Approved Jeeber / R2 | Given one pending offer, when it is reviewed or withdrawn, then final state is server-authoritative and additive customer access remains intact. | jm-047 | Withdraw twice; accepted elsewhere; capability revoked; negative assertion for absent role toggle |

## KYC media checklist

- [ ] Synthetic adult identity imagery only; no real face or government document.
- [ ] Raw uploads remain ephemeral and outside version control.
- [ ] Screenshots show masked placeholders, never readable identity fields.
- [ ] No vendor is contacted unless a separately authorized sandbox/test-mode run exists.
- [ ] Cleanup verifies submission, media, role capability, and offer fixtures are reset.
