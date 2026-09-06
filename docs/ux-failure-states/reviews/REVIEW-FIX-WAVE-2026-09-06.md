# PR #335 review-fix wave — 2026-09-06

Codex continued the stopped Claude `pr335-review-fix-wave` workflow from `f9eaf63d`, on `ux/api-error-handling-empty-states`. This is a correction wave, not completion of all P01–P15 implementation plans. The historical independent review and final programme report remain snapshots of their original revisions.

## Outcome

Nine mobile regressions were repaired in `db5d2fdc`; OD-12's 35-minute stage-test timeout was applied in `7e3bd624`. The plan corrections and sanitized upstream patch kit are separate commits in this wave. No deploy, upstream filing, release, merge, history rewrite, or security-gate bypass was performed.

| Review finding | Correction | Evidence |
|---|---|---|
| A1: cross-account chat drafts | Account-scoped durable outbox views; safe owned legacy migration; sender/conversation filters; unique IDs; account-keyed provider lifecycle | `chat_recovery_regression_test.dart`; independent collision/migration/write-failure probes |
| A2: deactivated source wallet cannot be restored by ensure | P15 retains drained source wallets; final deactivation requires a separate owner decision | `PLAN-P15-wallet-independence.md` G1/G6 |
| A3: missing staging Partner currency pin | P15 requires all three currency settings and Partner read/predict proof | P15 currency migration gates |
| A4: attachment retry does not upload | Failed photo/voice retries re-upload; uploaded references reused; missing voice input fails closed | Chat regression suite |
| A5: recovered history banner persists | Successful history refresh clears its failure; closed cubits cannot publish late results | Chat regression suite |
| A6: offline state lost to edge throttle/remount | Unthrottled state stream plus seeded subscription; reconnect pulses remain separately bounded | Reachability regressions and offline-mount tests |
| A7: elapsed backoff replenishes retry budget before recovery | Only same-scope successful requests reset that scope's bounded budget | Rate-limit regressions |
| A8: one timer loses independent scope wake-ups | Per-scope suppression/deadlines, coalesced near-identical deadlines, one earliest-deadline queue | Rate-limit regressions |
| A9: recovering auth has no retry | `UnauthorizedFailure(recovering: true)` is retryable; EN/AR profile and notification consumers verified | App-failure/copy/profile/notification tests |
| A10: healthy home rows hidden | Active requests tracked separately from role-only requests; failed sources do not hide healthy rows or turn every empty into an error | Client-home source-health regressions |
| A11: portrait ticket exception leaves busy state | Unexpected ticket errors become safe photo failures and release the busy state without discarding retry identity | Portrait-ticket regressions |
| A12: Windows drive-root extraction rejected | Boundary normalization preserves root separators and sibling traversal protection | Packaged rubyzip patch; simulated Windows and filesystem-root tests |

The known P12-A6 identifier-coverage matcher was also repaired: quoted identifiers are now actually detected, with a matcher unit test and a measured remaining floor of 26. This does not claim P12-A1–A5/A7 or ChatTab removal are complete.

## Gate measured on this wave

| Check | Result |
|---|---|
| `dart analyze --fatal-infos .` | PASS, no issues after final mobile edits |
| `flutter test --no-pub --exclude-tags capture --coverage --reporter expanded` | **10,592 passed, 109 skipped, 2 failed** in 7m39s; not a green full gate |
| LCOV line coverage | **56,872 / 67,163 = 84.68%**; measurement from the run with the two tooling failures |
| Localization parity | PASS; 2,538 keys per locale; 1,132 unused-getter warnings remain |
| Arabic plural audit | PASS; 76 numeric-placeholder warnings remain |
| Diff-scoped design tokens | PASS, 411 changed feature files |
| Forward-only deployment policy | PASS, final rerun across 3,069 tracked UTF-8 files including this report |
| New regression / independent review lanes | PASS; chat storage received an additional adversarial review and hardening |
| Rubyzip final clean patch application | 328 tests / 3,023 assertions / 0 failures on Ruby 3.3; RuboCop clean |
| Fastlane final clean patch application | 8 IPA specs / 0 failures; historical full-suite baseline failures explicitly retained in kit evidence |

### The two Firebase failures are environmental, not silently waived

`firebase_config_integrity_test.dart` assumes the ignored dev Firebase file is absent after the wrapper test, although this checkout already contained one. `firebase_doctor_test.dart` rejects the pre-existing ignored production config because it lacks the canonical `com.olivium.jeeb` client. Both files existed before this continuation. No real config, key, or Firebase source was changed.

An isolated checkout of the exact starting commit `f9eaf63d` passes these two test files **9/9** with no native local configs. Synthetic ignored configs reproducing the same public project/package structure, without copying secrets, produce **7 passes and the identical 2 failures**. Relevant tracked test/script contents are unchanged from the baseline. This supports landing the reviewed code with a documented environment exception; it does not turn the original full-suite result green.

## Inventory review corrections

- B1/B3/B4: timeout applied; inventory fixes the gateway/mobile branch mix-up; OD-0 widen supersedes the old scope freeze; current execution notes distinguish this wave from broader unimplemented work.
- B2: release security remains blocked on mobile's existing rubyzip 2.4.1. The kit does not change the installed dependency or clear the advisory gate.
- B5: private assistant/session trailers removed from the upstream patches, original upstream author date restored, evidence made durable, commands/provenance/checklists corrected. Owner must verify author email and decide whether to file. Native Windows/legacy Ruby proof remains upstream work.
- B6/B7: P01 v3 distinguishes Rahma's component-ID renderer from jeeb's selected vocabulary, weighs configurable package reuse, identifies template provenance and actual preference DTO/authorization behavior, and uses the real MSI working directory. Preserve untracked live KYC data. Existing builder policy failures/disabled CI are not attributed to the proposed patch; owner choices remain explicit.
- B8: P15 preserves the real main wallet contract, states validator environments and stack dependencies, and proposes P01-before-P15 ordering for shared files. No source-diff shortcut is treated as independence proof.
- B9: local decision-page v5 corrects P01/OD-1, actual plan filenames and OD-15. Static checks pass; saved choice keys and all executable scripts are unchanged. It is **not published**. Older generators remain historical and must not overwrite it.
- B10: old pushed commit/comment attribution is left intact; changing pushed history remains owner-gated. This continuation is attributed to Codex, not represented as Claude-authored work.
- B11: source/citation and scratch-helper corrections are in the plans and inventory. The existing diff-scoped token policy and historical Firebase regime remain explicitly distinguishable from this wave.

## Pushed-head device and hosted-test follow-up

Hosted Flutter stage Test on `a1978fdb` passed **10,594 tests / 109 skipped / zero failures** at 10:51:29 UTC. Test runtime was 19m46s; the whole job took **20m36s**, validating the approved 35-minute job limit. [Completed job](https://github.com/olivium-dev/jeeb-mobile/actions/runs/34027524435/job/101471317973). The local Firebase exception above remains an honest account of that separate local run.

The debug/dev APK from `a1978fdb` was installed with `-r` on SM-A336B / RZCT505K7WF; local and installed APK SHA-256 matched `41bc48beee2685016fd719363dfce016db014ada619ead94d0f4b321f39275b4`.

- Two rapid radio flaps: no persistent false offline banner after reconnection. Banner appeared offline and remained after cold launch and profile navigation. Eventual home recovery is visible; automatic-versus-manual refresh causality was not isolated.
- Existing client account: notifications rendered three rows and profile rendered the actual seeded identity. Active order history was empty. Its wallet destination is a cash-payment information page, not the Jeeber wallet hub.
- Valid unreachable gateway: home, notifications and profile each eventually rendered timeout error plus retry, without false empty state or raw exceptions. Notifications and profile were still loading at the operator's 40-second checkpoint, then settled at later capture; no fast-failure latency claim.
- Original gateway restored through Dev Tool; home, profile and notifications recovered. Final read-only checks confirmed the original URL, Wi-Fi=1 and mobile_data=1; same account, English and home screen. No new message/request/offer/wallet action, account switch, uninstall or data clear.
- A malformed URL edit during setup exposed a separate **pre-existing Dev Tool validation/startup gap**. Those blank captures are excluded. Only the exact affected URL preference was restored through a narrowly checked stopped-app edit; all other preferences were compared unchanged, then valid UI-driven outage/recovery was completed. No product code was changed for that new diagnostic; it remains a separate follow-up.

Independent reviewers checked XML and selected PNGs. This is bounded evidence, not full device acceptance: chat/attachment/account-switch delivery, Jeeber wallet, Arabic and non-timeout API-body scenarios remain unproved in this continuation.

## Still pending

The stage Test job validated the new 35-minute limit, but remaining hosted coverage/platform results need their own completion. Release security remains red until an approved dependency/advisory resolution; no ignore was added. The bounded device results above do not complete the missing scenarios. P01/P02/P03 gateway and onboarding-route implementations, broader copy/guardrail plans, wallet train, owner deploys and upstream submissions are not completed by these review corrections. PR #335 remains draft.

Local continuation evidence lives under the Claude session scratchpad `fixwave/`: lane `CODEX-STATUS.md` files, `codex-gate/test-full.log`, `codex-gate/FIREBASE-BASELINE-REVIEW.md`, `codex-gate/firebase-baseline-synthetic.log`, and `FINAL-MAP.md`. The sibling `site/REVIEW-FIX-HANDOFF.md` identifies the authoritative unpublished HTML and generator limitations. These local paths are not required for the durable upstream kit: its sanitized evidence is committed under `docs/security/upstream-rubyzip-cve-2026-85396/evidence/`.
