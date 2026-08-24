# Jeeb staging-store remediation report

> Run: `JMQA-REMEDIATION-20260823T215311Z`
>
> Snapshot: 2026-08-24 15:23 UTC
>
> Verdict: **NO-GO — both source-current artifacts pass inspection; source review, live staging, store delivery, and physical scenarios remain open**

## Executive result

Jeeb now has a final inspected Android AAB for the permanent native identity
`com.olivium.jeeb`, Firebase project `jeeb-5a293`, and staging REST origin
`https://app.jeeb.fds-1.com`. It was rebuilt from a clean Android/Flutter cache
after the Play-signer Firebase refresh and after removing Super Login and the
Dev Tool from the product entry graph. A clean iOS rebuild from that same
corrected product entry is signed, inspected, hashed, and accepted by Apple's
validation-only transport. The transparent Flutter launch placeholder was also
replaced with the existing Jeeb wordmark and guarded against regression.

The exact current mobile source suite is also closed after a deterministic
regression pass: 7,868 tests pass, 66 are intentionally skipped, and none fail.
Compose-only empty or `new` chat IDs are now rejected before any realtime
resolver or socket request. This strengthens the source gate; it does not
substitute for public WSS or paired store-device evidence.

Both binaries were produced after a forced clean from that passing working-tree
state. They remain upload-held because the large mobile change set has not yet
been frozen into an immutable revision and independently reviewed. Artifact
inspection proves the binaries' contents; it does not create source-review
lineage. The approved revision must be cryptographically bound to these exact
binaries or used for another forced-clean rebuild before upload.

The source-lineage audit found the feature worktree still at `origin/main`
`a8810345`, with 60 staged and 92 unstaged tracked paths, 19 paths present in
both sets (133 unique changed tracked paths), and 245 untracked paths. The
staged index is not build-coherent: staged release tests depend on unstaged
implementations. Raw `.codex-proof` device evidence, binaries, and signer
material must remain outside version control. The dirty tree is preserved; it
must be reconstructed as coherent scoped changes in clean worktrees rather
than committed as-is.

That does not prove the application works. The staging remediation is not live:
normal OTP still returns 503, Super Login Plus/demo endpoints remain open, voice
still uses fake transcription, public WSS is unavailable, and the AASA and
`assetlinks.json` files are not served. Neither candidate has been delivered by
Play Internal Testing or TestFlight, and no exact JMS scenario has run on either
candidate. The release remains NO-GO; workarounds and mocks are not accepted.

## Status by evidence layer

| Layer | Status | What the status means |
|---|---|---|
| Mobile source and focused contracts | PASS | Exact non-capture suite: 7,868 passed, 66 skipped, 0 failed; identity/configuration and release contracts are green. |
| Android signed AAB | PASS / CURRENT ARTIFACT / UPLOAD HELD | Clean rebuilt artifact is signed, structurally valid, API 36, inspected, hashed, and contains no Super Login or Dev Tool release surface; immutable source-review lineage remains open. |
| iOS signed IPA | PASS / CURRENT ARTIFACT / UPLOAD HELD | Clean rebuilt artifact is Apple Distribution signed, inspected, hashed, and Apple-validation green; it contains no Super Login or Dev Tool release surface; immutable source-review lineage remains open. |
| Canonical Firebase registration | PASS | Android and iOS `com.olivium.jeeb` registrations exist in `jeeb-5a293`; protected configs were injected outside version control. |
| Staging source remediation | UNDER REVIEW / NOT LIVE | Infra #26, gateway #523 exact head `63b19dba2b1b2aa94c107d719173a2ebfc4bde33`, and OTP #27 exact head `29ff7af77e22d48f1ba63ff03df988c2b5e8b104` are independently approved with green CI. Realtime #14 is correcting three P1 and one P2 findings; voice #27 is correcting one newly proven full-Spec rollback P1. No merge or deployment is claimed. |
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

This was validation only, and the artifact remains held pending source review.
It is not an App Store upload, TestFlight delivery,
review, or functional PASS. This is the current artifact-layer IPA; the prior
SHA-256 `3592fb673e1e7e669903b98fc1bbaadb54603b275234d151796c4186ab1bda9f`
predates the chat boundary fix and must not be uploaded. Its validation
operation `7830413C0` remains historical provenance only.

## Live staging preflight

| Gate | Live observation | Local remediation | Required fresh closure |
|---|---|---|---|
| REST health | Green | N/A | Keep green through deployment and rollback probes |
| Normal phone OTP | 503 / disabled | Restricted `JEEB_*` Twilio secrets installed; PR #27 exact head `29ff7af` is local/remote green and independently approved after all six provider corrections plus full-Spec same-digest rollback proof; owner-confirmed canary recipient remains | Confirm protected physical recipient, merge with compatible revisions, deploy, and prove send, receipt, verify, expiry, retry, lockout, and rate limit |
| Super Login Plus / demo | Open | Gateway defaults and guards close both | Deploy; prove both public surfaces reject access |
| Voice transcription | Fake provider live | Voice PR #27 exact head `e5b3142` is remote-green and independently proves all five prior fixes with 173/173 tests, but a same-digest secret/config failure can still leave the candidate Spec active; one isolated writer is adding full-Spec transactional recovery | Complete the full-Spec fix and exact-head approval, deploy, then prove genuine uncached synthetic Arabic audio through the public gateway |
| Chat/realtime | No public WSS 101 | Gateway descriptor is approved; realtime #14 head `ac05b64` is 634/634 locally and remote-green, but exact-head review found three P1 and one P2 rollout/probe-policy defects; one isolated writer is correcting them | Prove full-Spec rollback, keep runtime verification and authenticated exact-topic/cross-topic/forged-ticket WSS probes inside the armed transaction, close the checkout bypass, obtain approval, and deploy compatible revisions |
| Firebase gateway secrets | Not yet proven through candidate | Canonical file selection and shared Guardian/ticket secrets installed | Deploy; prove auth, installations, push registration, and receiver delivery |
| AASA / asset links | Not live | Candidate identities and entitlements are aligned | Serve both well-known files without redirect and run JMS-LINK-001 |
| Edge transport | Plain HTTP returns 200 without redirect; TLS 1.1 is accepted | Worker redirect work is under review; zone minimum-TLS control remains external | Enforce HTTP→HTTPS and minimum TLS 1.2, then prove HTTP redirect, TLS 1.0/1.1 rejection, and TLS 1.2+ success |
| Gateway release | Old live behavior | PR #523 exact head `63b19dba` is remote-CI green and independently approved after 12/12 baseline and three adversarial mutation checks | Complete required QA/Product/Tech Lead/CODEOWNER gates, merge with cross-repo readiness, deploy immutable image, and retain readiness/rollback evidence |

Local tests and installed secrets are implementation evidence only. They cannot
supersede a failing public probe. Cloudflare investigation is conclusive: the
authenticated identity lacks target-account Worker/token authority, so a target
account admin must grant that authority or install the exact least-privilege
staging token. The target-zone owner must also set the public minimum TLS to
1.2 or newer. No broader credential or deployment workaround is accepted.

## Physical device state

| Lane | Current state | Permitted conclusion |
|---|---|---|
| Samsung A33 | ADB authorized | Device is available; no candidate was installed or driven |
| Samsung S24 | Connected but ADB unauthorized | BLOCKED until the phone accepts USB debugging |
| Physical iPhone | Offline | BLOCKED until online and available for TestFlight installation |

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

1. **SOURCE-LINEAGE:** freeze and independently review the exact intended mobile
   change set; bind the approved revision to both artifacts or force-clean
   rebuild them from that revision. Follow the
   [clean reconstruction runbook](MOBILE-SOURCE-RECONSTRUCTION.md); never commit
   the current mixed index.
2. **STG-LIVE:** deploy the approved immutable staging revisions; fresh public
   probes must close OTP, bypass/demo, voice, WSS, Firebase, and link-host gates.
3. **STORE-DELIVERY:** after staging closure, upload the current recorded AAB
   and IPA, wait for processing,
   and install from Play Internal Testing and TestFlight. Re-hash installed
   Android splits and record iOS store build provenance.
4. **DEVICE-READY:** A33 and S24 are authorized; the iPhone is online; device
   keeper/automation side effects are paused; permissions and clean app data are
   recorded.
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
