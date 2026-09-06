# Owner decisions — recorded 2026-09-06 (from the decision-record artifact db, collection `decisions`)

> Historical 06:54–07:05 UTC decision snapshot. Later owner clarifications are recorded in [P01 v3](plans/PLAN-P01-dm-onboarding-route.v3.md) (form builder defines the form; gateway stores answers in preferences) and [P15](plans/PLAN-P15-wallet-independence.md) (wallet independence without breaking sibling products). Their corrected plans supersede the pending OD-1/OD-15 wording below; this table is not a claim that those questions remain unanswered.

| OD | Decision | Matches CTO recommendation |
|---|---|---|
| OD-0 | Let follow-ups ride #335 (`widen`) | No — recommended freeze |
| OD-1 | Other: "Keep using the formbuilder, store the data in the user preferences (through gateway)" | Re-plan required |
| OD-2 | Mechanism only, no Production bbox (`nobbox`) | No — recommended fail-open bbox |
| OD-3 | One MSI deploy, one staging dispatch (`combined`) | Yes |
| OD-4 | Keep chat-detail /chat/{ref} (`chat`) | Yes |
| OD-5 | Min length 5, code-only expansion (`five`) | Yes |
| OD-6 | Approve the minted-token sweep (`api`) | Yes |
| OD-7 | Levantine for system copy (`lev`) | No — recommended MSA |
| OD-8 | Proxy-only via adb reverse (`proxy`) | Yes |
| OD-9 | Delete ChatTab and its stack (`delete`) | Yes |
| OD-10 | Real UI only, never curl (`uionly`) | No — recommended UI first, curl if blocked |
| OD-11 | Leave and document the ids (`leave`) | Yes |
| OD-12 | Raise timeout to 35 minutes (`raise35`) | Yes |
| OD-13 | Squash and keep the branch (`squash`) | Yes |
| OD-14 | Both stores, first day after merge (`nextday`) | Yes |
| OD-15 | Other: "No decision yet, you have to explain to me if there is a breaking change or not and which one is being used now." | Explanation owed |
| OD-16 | Approve the dev-gated define (`define`) | Yes |
| OD-17 | Wi-Fi hint wording (`wifi`) | Yes |

Decided between 2026-09-06 06:54 and 07:05 UTC. Source of truth: artifact db `decisions/<OD>`.

## OD-7 implementation disposition — this wave's new AR keys (recorded 2026-09-07)

OD-7 chose Levantine for system copy. `plans/EXECUTION-PLAN-2026-09-06.md:231-238` implements that choice as "P07 F4 dropped + a WP-9 ticket converts the ~505-key MSA failure family", with this wave's new AR keys (P05 ×3, P13 ×2, P02 ×2, P03 ×3) authored MSA like their siblings and appended to the WP-9 list. The owner-ask at `:267` item 5 (one Levantine reference sentence) is still open, and authoring only the new keys in register would ship the mix `plans/PLAN-P07-arabic-failure-states.md:70` forbids. The P03 triple `composeDescriptionTooShort` / `composeDescriptionTooLong` / `composeDescriptionProhibited` (`lib/l10n/app_ar.arb:510-512`) therefore stays MSA and is tracked in `WP-9-AR-REGISTER-BACKLOG.md`.
