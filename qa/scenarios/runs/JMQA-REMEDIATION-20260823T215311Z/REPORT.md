# Jeeb staging-store remediation report

> Run: `JMQA-REMEDIATION-20260823T215311Z`
>
> Snapshot: 2026-08-24 18:37 UTC
>
> Verdict: **NO-GO — the reconstructed mobile validation head passes local and remote CI; review, fresh artifact builds, live staging, store delivery, and physical scenarios remain open**

## Executive result

Jeeb has a historical inspected Android AAB for the permanent native identity
`com.olivium.jeeb`, Firebase project `jeeb-5a293`, and staging REST origin
`https://app.jeeb.fds-1.com`. It was rebuilt from a clean Android/Flutter cache
after the Play-signer Firebase refresh and after removing Super Login and the
Dev Tool from the product entry graph. A clean historical iOS rebuild from that
same corrected product entry is signed, inspected, hashed, and accepted by
Apple's validation-only transport. The transparent Flutter launch placeholder
was also replaced with the existing Jeeb wordmark and guarded against
regression. Both artifacts predate the current hardened source and are not
upload eligible.

The exact source-bearing mobile commit `e07d4542` is closed after a
deterministic CI-equivalent regression pass: 7,882 tests pass, 66 are
intentionally skipped, and none fail (approximately 329 seconds). PR #276
validation head `c2b90748518d2a01823e670b1ee4492f7db2f9c9` is pushed, CLEAN,
and terminal green on all eight reported checks.
Compose-only empty or `new` chat IDs are now rejected before any realtime
resolver or socket request. This strengthens the source gate; it does not
substitute for public WSS or paired store-device evidence.

The same commit removes the committed development Super Admin passcode
fallback and makes that value debug-define-only. Courier live tracking now
requires `wss://` outside the explicit development flavor, matching chat's
transport policy. The two added regression checks and their 22-test focused
suite pass; no credential value is retained in this report.

The earlier source-current binaries were produced after forced cleans from the
passing working-tree state. They remain upload-held because they predate the
immutable reconstructed head. Artifact inspection proves their contents; it
does not make them products of the reviewed source. Independent approval and a
rebuild from that exact approved revision remain mandatory before upload.

The historical source-lineage audit at `a8810345` found 60 staged and 92
unstaged tracked paths, 19 paths in both sets (133 unique changed tracked
paths), and 245 untracked paths. That mixed index was not committed. Its
sanitized 188-file selection was reconstructed as
`e208a4c8906330c8df126f2391ae149a8291e6f6`; `origin/main`
`0c26c159c9714b812bd2a0f6ec3cc9488c7d39c8` was then merged into the feature
branch. Source-bearing commit `e07d4542` has a 194-file diff from `origin/main`,
with 12,392 insertions and 4,510 deletions. The reproducible release-contract
corrections are included in pushed PR #276 validation head `c2b907485`. This is
a feature-branch reconciliation, not a merge to main.

Flutter analysis and fatal-info analysis are clean after generated
`build/ios/SourcePackages` was removed. The initial 7,206 diagnostics were a
third-party generated-cache tool-scope error, not findings in product source.
Firebase doctor, 13 protected-config focused tests, actionlint, ShellCheck,
Gitleaks, and the diff check pass. At `c2b907485`, CI Analyze/Test/Build APK,
Android release contracts, iOS release contracts, Flutter CI, Mobile L10n, and
the fail-closed policy are all remote-green. Independent review plus exact-head
artifact rebuilds remain open.

That does not prove the application works. The staging remediation is not live:
readiness returns 200, while normal OTP returns 503, anonymous Super Login/demo
returns 200, voice still uses fake transcription, WSS reaches the gateway at
401 rather than Phoenix 101, and both link-association files return 401. Plain
HTTP returns 401 without redirect; TLS 1.0, TLS 1.1, and TLS 1.2 all negotiate. Neither
candidate has been delivered by Play Internal Testing or TestFlight, and no
exact JMS scenario has run on either candidate. The release remains NO-GO;
workarounds and mocks are not accepted.

## Status by evidence layer

| Layer | Status | What the status means |
|---|---|---|
| Mobile source and focused contracts | LOCAL + REMOTE CI PASS / REVIEW PENDING | Source-bearing commit `e07d4542` passes 7,882 tests with 66 intentional skips and 0 failures plus the focused credential/WSS and prior local gates. PR #276 validation head `c2b907485` passes all eight reported remote checks. |
| Android signed AAB | PASS / HISTORICAL ARTIFACT / UPLOAD HELD | The inspected artifact is signed, structurally valid, API 36, and contains no Super Login or Dev Tool release surface; it predates validation head `c2b907485` and must be rebuilt from the approved exact head after review. |
| iOS signed IPA | PASS / HISTORICAL ARTIFACT / UPLOAD HELD | The inspected artifact is Apple Distribution signed and Apple-validation green; it predates validation head `c2b907485` and must be rebuilt from the approved exact head after review. |
| Canonical Firebase registration | PASS | Android and iOS `com.olivium.jeeb` registrations exist in `jeeb-5a293`; protected configs were injected outside version control. |
| Staging source remediation | UNDER REVIEW / NOT LIVE | Infra #26 remains reviewed/green. Gateway bootstrap is an unpushed isolated change from `63b19dba`. Realtime #14 `4959d9e` is remote-green but REQUEST_CHANGES on two P1s. OTP `29ff7af` and voice `6509c840` remain test-green, but their earlier rollout approvals are superseded by the same non-atomic rollback race. No deployment is claimed. |
| Live staging providers and WSS | BLOCKED | OTP, Super Login/demo closure, real voice, WSS, AASA, and asset links fail the live preflight. |
| Play Internal delivery | NOT RUN | No AAB upload or store-installed build is evidence in this run. |
| TestFlight delivery | NOT RUN | Apple validation passed, but no upload or TestFlight installation is evidence in this run. |
| Physical release scenarios | NOT RUN | No candidate install, login, tap, mutation, or JMS run occurred. |

Current-run exact scenario accounting is **0 PASS, 0 FAIL, 0 BLOCKED, 95 NOT
RUN**. Environment prerequisites are BLOCKED; scenarios are not relabelled
BLOCKED until an exact scenario execution record is opened.

## Canonical identity and service configuration

| Surface | Current value | Evidence status |
|---|---|---|
| Android package / iOS bundle | `com.olivium.jeeb` | Frozen and embedded in signed artifacts |
| Firebase project | `jeeb-5a293` | Existing canonical project; no replacement project created |
| Firebase Android app | `1:1051234312170:android:85bc801430c9006623dc93` | Registered for `com.olivium.jeeb` |
| Firebase iOS app | `1:1051234312170:ios:1036d2eaaf63036a23dc93` | Registered for `com.olivium.jeeb` and App Store app `6804058185` |
| Apple team | `K5RDQ8J7AN` | Signed profile and App ID agree |
| Staging REST | `https://app.jeeb.fds-1.com` | Embedded; public REST health is green |
| Associated/App Link host | `app.jeeb.fds-1.com` | Embedded, but well-known files are not live |

Protected Firebase, signing, and Maps inputs remain outside the scenario folder
and version control. This report contains identifiers and certificate hashes,
not private keys, API secrets, OTPs, tokens, or user data.

The canonical historical `jeeb-5a293` configuration for
`app.jeeb.mobile.dev` was validated without output. Four previously absent
repository Actions secrets are now installed by name:
`DEV_GOOGLE_SERVICES_JSON_B64`, `DEV_FIREBASE_EXPECTED_PROJECT_NUMBER`,
`DEV_FIREBASE_EXPECTED_PROJECT_ID`, and `DEV_FIREBASE_EXPECTED_APP_ID`.
Read-back was limited to names and timestamps. No provider resource was changed
and no value was exposed. Real native config files remain absent from source,
and `tool/run_with_dev_firebase_config.sh` removes its injected config after
both command success and command failure.

The historically tracked Android Firebase client key is now restricted at the
provider to four exact package/signer pairs: canonical upload and Play delivery,
plus the preserved legacy production/development compatibility pairs. The
existing Firebase API allowlist was unchanged. The key value is not copied into
this evidence pack. The already tracked value did appear in
transient authenticated diagnostic output while the provider resource was
matched. Official Firebase guidance classifies Firebase-only client keys as
public identifiers rather than authorization secrets; because this key remains
Firebase-API-only and is now app-restricted, security disposition is no rotation
or history rewrite. The reconstructed source must still delete the two real
old-identity config files.

## Current Android candidate

| Property | Value / result |
|---|---|
| Artifact | `build/app/outputs/bundle/productionRelease/app-production-release.aab` |
| Size | 77,670,304 bytes |
| SHA-256 | `4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b` |
| Version | `1.0.0` (`26082401`) |
| SDK | minimum 24; target 36 |
| Upload signer SHA-256 | `7A:E6:A6:20:BA:89:E8:43:85:13:E4:2C:F5:9E:69:E3:CF:0F:CD:CE:8C:87:D7:71:3B:07:8C:80:3D:A2:E3:BA` |
| Play app-signing SHA-256 | `42:76:6A:BB:4B:EA:1F:A4:88:00:96:6F:78:A1:E5:4F:A0:EA:12:B8:A1:6A:58:AF:07:5A:02:01:0B:B5:58:E9` |
| Inspection | `jarsigner` verification and Bundletool 1.18.3 validation pass; cleartext is disabled |
| Firebase/Maps | Canonical app/project resources match the refreshed protected config; upload and Play OAuth signers validate; the dedicated Maps key matches its protected value and exact package/two-signer/two-API restrictions |
| Embedded-policy scan | Canonical staging value present; forbidden host, LAN/emulator/loopback origin, wildcard chat token route, old package, Super Login endpoints/types/seams, demo roster, and Dev Tool graph are absent. One `http://localhost` literal is proven to be Google Firebase Auth internal bytecode. |

This is the current artifact-layer candidate and is held from upload. It is not a Play
upload, store-delivered build, or functional PASS. The prior clean hash
`163972d5604c2facd0374a9489f5dd4ba2a05b0274779dc9818b0a220f82153c`
predates the chat boundary fix and is historical evidence only. An incremental
attempt reproduced that stale hash and was rejected; the current hash exists
only after purging build output and rebuilding from the green source state.

The local certificate is the upload signer. Play's app-signing certificate is
recorded separately because Play re-signs delivered APKs. Play upload-key
acceptance and the hash of the store-delivered split APK remain NOT RUN. The
Play app-signing SHA-1 `2E:CF:AF:7F:13:AB:9E:B5:34:E4:04:AD:3B:A9:F6:B2:A1:EA:77:12`
and recorded SHA-256 were added idempotently to the existing Firebase Android
app. Read-back shows two SHA-1 and two SHA-256 entries: Play plus upload. This
closes certificate registration, not store-delivered functional behavior.

## Current iOS candidate

| Property | Value / result |
|---|---|
| IPA | `build/ios/internal-26082401/jeeb_mobile.ipa` |
| Archive | `build/ios/archive/Jeeb-26082401.xcarchive` |
| Size | 44,386,543 bytes |
| SHA-256 | `eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94` |
| Version | `1.0.0` (`26082401`) |
| Signer | `Apple Distribution: Ouday Khaled (K5RDQ8J7AN)` |
| Profile | `iOS Team Store Provisioning Profile: com.olivium.jeeb` |
| Profile UUID / expiry | `78f0591f-fd55-467f-8acc-8c9b14821277` / 2027-03-25 |
| Entitlements | Production APNs and `applinks:app.jeeb.fds-1.com` |
| Inspection | Strict signature, protected Firebase/Maps, staging-origin, forbidden-host/LAN/wildcard-token, Super Login, Dev Tool, and dependency-ownership checks pass |
| Launch screen | Existing Jeeb wordmark at 1x/2x/3x replaces Flutter's transparent placeholder; release inspection enforces exact scales |

`xcrun altool --validate-app` exited 0 with `VERIFY SUCCEEDED`: no errors and
one non-blocking warning (90068, the announced future iOS 15 minimum in spring
2027).

This was validation only, and the artifact remains held pending exact-head CI,
independent source review, and a fresh rebuild from that source.
It is not an App Store upload, TestFlight delivery,
review, or functional PASS. This is the current artifact-layer IPA; the prior
SHA-256 `3592fb673e1e7e669903b98fc1bbaadb54603b275234d151796c4186ab1bda9f`
predates the chat boundary fix and must not be uploaded. Its validation
operation `7830413C0` remains historical provenance only.

## Live staging preflight

| Gate | Live observation | Local remediation | Required fresh closure |
|---|---|---|---|
| REST health | `/health/ready` returns 200 | N/A | Keep green through deployment and recovery probes |
| Normal phone OTP | 503 / disabled | Restricted `JEEB_*` Twilio secrets and one owner-controlled canary recipient are installed; PR #27 `29ff7af` is test-green, but its prior approval is superseded because plain CLI rollback is not atomic against a concurrent third Spec; no SMS sent | Add Engine API version-CAS rollback plus race mutation proof and re-review; then deploy and prove send, receipt, verify, expiry, retry, lockout, and rate limit |
| Super Login Plus / demo | Anonymous probe returns 200 | Gateway defaults and guards close both | Deploy; prove both public surfaces reject access |
| Voice transcription | Fake provider live | Voice PR #27 `6509c840` is test-green, but its prior approval is superseded by the same plain-CLI rollback race | Add Engine API version-CAS rollback and adversarial race proof, re-review, then deploy and prove genuine uncached synthetic Arabic audio through the public gateway |
| Chat/realtime | WSS reaches the gateway at 401, not Phoenix 101 | Realtime PR #14 `4959d9e` is remote-green (634 ExUnit, 48 policy/rollout, 15 WSS), but exact-head review found two P1s: plain CLI recovery can race a third Spec, and the runbook still documents the unsafe old deployment order | Use exact Service ID and candidate Version with Engine API recovery CAS, add the race harness, update the runbook/PR sequence, re-review, then follow the binding two-phase rollout |
| Firebase gateway secrets | Not yet proven through candidate | Canonical file selection and shared Guardian/ticket secrets installed | Deploy; prove auth, installations, push registration, and receiver delivery |
| AASA / asset links | Both well-known endpoints return 401 | Candidate identities and entitlements are aligned | Serve both well-known files without redirect and run JMS-LINK-001 |
| Edge transport | Plain HTTP returns 401 without redirect; TLS 1.0, TLS 1.1, and TLS 1.2 all negotiate | Worker redirect and target-zone minimum TLS configuration are not deployed | Enforce HTTP→HTTPS and minimum TLS 1.2, then prove HTTP redirect, TLS 1.0/1.1 rejection, and TLS 1.2+ success |
| Gateway release | Old live behavior | Base PR #523 `63b19dba` is green, but safe rollout requires a separate bootstrap head with chat/realtime forced OFF, descriptor proofs armed, Engine API CAS recovery, and the generic staging-target activation bypass blocked; implementation is local/unpushed | Finish adversarial executable gates and independent review, then deploy only as phase A1 |

Local tests and installed secrets are implementation evidence only. They cannot
supersede a failing public probe. The least-privilege
`CLOUDFLARE_API_TOKEN` secret is present in `jeeb-infrastructure/staging` with
Account → Workers Scripts → Edit metadata; the value was not read or exposed.
REM-BLK-115 is therefore closed at the access layer. The Worker/route changes
are not deployed, and the target-zone owner must still set the public minimum
TLS to 1.2 or newer. No broader credential or deployment workaround is
accepted.

The OTP protected-input prerequisite is also closed: Twilio exposes exactly one
Verified Caller ID, normalized and validated in memory as E.164 and distinct
from the sender ending `97`; it was installed by stdin as the sole
`one-time-password/staging` `JEEB_STAGING_SMS_CANARY_TO` secret. Metadata count
is one. The value appeared once in protected local browser-DOM diagnostic
output but is not retained in Git, a file, chat, or CLI history. No SMS was
sent, so live OTP remains blocked.

### Binding gateway/realtime/edge rollout

There is no safe one-step deployment order. The required two-phase sequence is:

| Step | Required change and gate |
|---|---|
| A1 — gateway bootstrap | Deploy gateway with chat OFF and descriptor contract ON. |
| A2 — realtime compatibility | Deploy realtime with the real descriptor and pass the direct-host Phoenix gate while rollback remains armed. |
| A3 — public edge | Enable edge/public WSS and pass the public realtime gate. |
| B — activation | Activate a small gateway slice, pass real chat/user/mobile canaries, then and only then turn chat ON. |

All five GitHub `staging` environments currently enforce custom branch policies
with exactly their default branch (`main`, except OTP `master`). Cloudflare
access and the protected SMS canary input are present, while unapplied
edge/zone configuration, service approval/deployment, and a real no-workaround
canary execution remain blockers to live closure.

## Physical device state

| Lane | Current state | Permitted conclusion |
|---|---|---|
| Samsung A33 | ADB authorized | Device is available; no candidate was installed or driven |
| Samsung S24 | Connected but ADB unauthorized | BLOCKED until the phone accepts USB debugging |
| Physical iPhone | Reachable; no phone number read/exposed | WAITING for a TestFlight candidate; no install or scenario action occurred |

The earlier A33 build and screen observations used a persisted Super Login Plus
session and are historical diagnostics only. They do not prove current auth,
role, KYC, chat, delivery, or release behavior.

## Exact functional rerun queue

The first store-delivered rerun must execute this minimum set in order. Passing
it does not waive the remaining P0/P1 release matrix in [GATE-MATRIX.md](../../GATE-MATRIX.md).

| Wave | Exact IDs | Purpose |
|---|---|---|
| 1 — identity/auth | JMS-AUTH-001, JMS-AUTH-002, JMS-AUTH-003, JMS-AUTH-008, JMS-LINK-001 | Clean install, normal OTP, session boundaries, and OS-owned HTTPS links |
| 2 — happy paths | JMS-JHP-001, JMS-JHP-002, JMS-JHP-003 | Customer request, real KYC/offer boundary, and full paired COD loop |
| 3 — voice/request | JMS-REQ-001–008 | Typed and real voice request, location, offer, expiry, cancellation, and recovery |
| 4 — KYC | JMS-KYC-001–009 | None, pending, approved, rejected, directed resubmission, role/capability refresh |
| 5 — delivery/chat/COD | JMS-DEL-001–012 | Detail, receiver-side chat, tracking, transitions, OTP, direct cash, receipt, rating, cancellation, escalation, dispute |
| 6 — receiver/lifecycle | JMS-PUSH-001–010 | Push permission, token/account boundaries, foreground/background/terminated delivery, typed routes, duplicate/stale rejection |
| 7 — complex recovery | JMS-RES-001–010 | Offline, timeout, retry, unknown result, idempotency, concurrency, process death |

Every exact scenario retains its own evidence and cleanup checklist. All other
P0/P1 scenarios, Android/iOS locale and accessibility coverage, and the Clarity
privacy suite remain mandatory before release GO.

## Synchronization barriers

1. **SOURCE-LINEAGE:** source-bearing commit `e07d4542` passes the 7,882-test
   CI-equivalent gate, and PR #276 validation head `c2b907485` passes all eight
   reported remote checks. Obtain independent approval, then force-clean
   rebuild both artifacts from the approved revision and repeat every
   inspection.
   Follow the
   [clean reconstruction runbook](MOBILE-SOURCE-RECONSTRUCTION.md). The
   historical mixed index was preserved and was not committed.
2. **STG-LIVE:** deploy the approved immutable staging revisions; fresh public
   probes must close OTP, bypass/demo, voice, WSS, Firebase, and link-host gates.
3. **STORE-DELIVERY:** after staging closure, upload only the newly rebuilt and
   reinspected AAB and IPA, wait for processing,
   and install from Play Internal Testing and TestFlight. Re-hash installed
   Android splits and record iOS store build provenance.
4. **DEVICE-READY:** A33 is authorized, S24 remains unauthorized, and the iPhone
   is reachable. Store candidates, clean app data, permissions, and sanitized
   device baselines remain pending.
5. **PERSONA-READY:** two isolated adult synthetic personas complete normal OTP;
   server role/KYC/readiness and before-state are read back. No agent mutates a
   shared persona before both runners acknowledge this barrier.
6. **PAIRED-ACTION:** customer and Jeeber runners exchange a run nonce and wait
   at each offer/chat/delivery/OTP transition until sender, receiver, and server
   agree. Unknown results reconcile before retry.
7. **CLEANUP-REVIEW:** reset every synthetic graph, verify final state, redact
   evidence, run secret/privacy review, and only then classify exact IDs.

## Evidence and verdict rules

PASS requires the exact store-delivered artifact, normal OTP, real providers,
receiver-side evidence, authoritative server read-back, and verified cleanup.
Artifact compilation, Apple validation, HTTP 200, sender logs, screen reach, or
source tests cannot independently pass a JMS scenario.

- **PASS:** every Given/When/Then assertion, no-side-effect assertion, evidence
  item, and cleanup step passes.
- **FAIL:** the executable product differs from the current contract.
- **BLOCKED:** an opened scenario cannot proceed because a live capability,
  store delivery, device, authorization, persona, or fixture is unavailable.
- **NOT RUN:** no exact execution record was opened.
- **INVALID:** the scenario conflicts with the authoritative product contract.

Any Super Login Plus/demo session, mock or fake provider, crafted state, debug
seam, direct intent, custom-scheme substitute, sideloaded store candidate, or
sender-only proof makes the affected acceptance result ineligible. Jeeb remains
cash-on-delivery only; any electronic payment, settlement, or money-moving
refund path is an automatic NO-GO.
