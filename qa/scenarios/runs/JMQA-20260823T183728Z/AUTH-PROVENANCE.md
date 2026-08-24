# Authentication provenance correction

> Run: JMQA-20260823T183728Z
>
> Classification: **SUPER LOGIN PLUS–SEEDED / NOT VALID FOR AUTH, ROLE, OR KYC SIGN-OFF**

## What happened

Before the corrective visible wave, the isolated Clarity QA package was prepared
through its debug-only Dev Tool and Super Login Plus. A release-flavor APK with
the same package identity and signer was then installed in place. That update
removed the debug launcher from the installed binary but preserved the package's
authenticated session data.

The visible 19:03–19:10 UTC wave did not reopen the Dev Tool or Super Login Plus,
but it relied on the session they had created. Describing the wave only as an
“existing authenticated test persona” omitted material provenance.

## Why it was used

The normal OTP customer/Jeeber fixture pair and cleanup ownership were not ready.
Super Login Plus provided a fast real-MSI synthetic session without entering an
OTP or a legacy administrator passcode, allowing read-only access to protected
screens.

That convenience was the wrong trade-off for the requested end-to-end physical
test. It bypassed the real authentication entry, and the selected account's role
and KYC state could not be treated as independently proven fixtures.

## Evidence

- The package manager reports a first install followed by a later in-place
  update for `app.jeeb.mobile.clarityqa`.
- Android recent-task state retains a launch rooted at the Clarity QA
  `DevToolLauncher` before the currently installed release-flavor activity.
- The installed APK is the non-debuggable release-flavor artifact, whose Dev
  Tool launcher is absent; therefore the authenticated state survived from the
  earlier debug package rather than being created through a release login in the
  visible wave.

Device identifiers, account values, session tokens, and roster contents are not
recorded here.

## Evidence impact

| Claim | Disposition |
|---|---|
| Physical screen navigation occurred | Retained |
| Delivery/chat/KYC screens were physically reached | Retained as reach evidence |
| Crash/ANR/log-window observations | Retained |
| Stable semantic-ID failure | Retained; independent of account entry method |
| Normal OTP/login happy path | INVALID / NOT RUN |
| Stored-session authentication correctness | INVALID for sign-off |
| Selected persona and role correctness | UNPROVEN |
| KYC transition and server-authoritative role synchronization | UNPROVEN / BLOCKED |
| Full customer↔Jeeber end-to-end happy path | NOT RUN |

The visible UI defects remain legitimate findings, but delivery, role, and KYC
findings must be reproduced after a clean normal login before release closure.
No current JMS PASS was claimed, so final PASS accounting remains zero.

## Required clean rerun

1. Remove the isolated Clarity QA package data only after explicit approval.
2. Install the exact test/release candidate cleanly, with no debug-to-release
   session carry-over.
3. Authenticate through the normal phone/OTP path using reserved synthetic
   customer and Jeeber accounts.
4. Read back the selected account, available roles, and KYC state from the
   authoritative test environment before navigation.
5. Authorize and use the second physical device for paired delivery/chat proof.
6. Keep Super Login Plus completely outside the evidence chain.
