# WP-9 — AR register backlog (system/failure copy → Levantine)

OD-7 chose Levantine for system copy. Per `plans/EXECUTION-PLAN-2026-09-06.md:231-238`, P07 F4 is dropped and a WP-9 ticket converts the MSA side instead: the two Levantine headlines (`orderHistoryLoadingHeadline`, `jeeberTabsLoadingHeadline`) stay, and the ~505-key AR failure family plus the 34 MSA `*LoadingHeadline` keys are rewritten in register in one pass, so the app never ships a mix (`plans/PLAN-P07-arabic-failure-states.md:70`).

AR keys added by this wave are authored MSA like their siblings and are listed here.

## P03 — create-request validation (`lib/l10n/app_ar.arb:510-512`)

| Key | Current AR (MSA) |
|---|---|
| `composeDescriptionTooShort` | أضف بضع كلمات أخرى ليعرف الجيبرز ما الذي يجب إحضاره. |
| `composeDescriptionTooLong` | اختصر طلبك قليلًا. |
| `composeDescriptionProhibited` | لا يمكن توصيل هذا: {items}. أزله للمتابعة. |

## P05, P13, P02 — filled by the l10n integration lane

The same treatment for the AR keys those lanes added (P05 ×3, P13 ×2, P02 ×2 per `EXECUTION-PLAN:238`). Note for the ticket's sizing: `git diff origin/main -- lib/l10n/app_ar.arb | grep -c '^+  "'` = 457 added or changed AR value lines on this branch, i.e. the register sweep is larger than the 10 keys §3 enumerates.
