# Staging-store remediation and physical rerun checklist

Checked boxes represent observed evidence at this run's 2026-08-24 15:23 UTC
snapshot. They do not inherit into a later build or deployment.

## A. Frozen identity and artifact gates

- [x] Native Android/iOS identity is `com.olivium.jeeb`.
- [x] Canonical Firebase project is the existing `jeeb-5a293` project.
- [x] Firebase Android registration is
      `1:1051234312170:android:85bc801430c9006623dc93`.
- [x] Firebase iOS registration is
      `1:1051234312170:ios:1036d2eaaf63036a23dc93`.
- [x] Current Android AAB `1.0.0` / `26082401` is signed and Bundletool 1.18.3 validates it.
- [x] Current Android AAB SHA-256 is
      `4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b`.
- [x] Android target API is 36 and cleartext traffic is disabled.
- [x] Android upload certificate SHA-256 and Play app-signing SHA-256 are
      recorded separately in [REPORT.md](REPORT.md).
- [x] Current iOS IPA `1.0.0` / `26082401` is signed by team `K5RDQ8J7AN` with the
      `com.olivium.jeeb` App Store profile.
- [x] iOS IPA SHA-256 is
      `eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94`.
- [x] iOS signed entitlements contain production APNs and
      `applinks:app.jeeb.fds-1.com`.
- [x] Apple upload validation exits 0 with no errors; warning 90068 is recorded
      as future minimum-OS work, not hidden.
- [x] Protected Firebase/Maps/signing inputs were injected outside version
      control and artifact scans reject forbidden/LAN/wildcard-token values.
- [x] The historical Android Firebase client key has four exact Android
      package/signer restrictions; its existing Firebase API allowlist is
      preserved and no key value is retained in this evidence pack.
- [x] Exact current mobile suite passes 7,868 tests with 66 intentional skips
      and zero failures; compose-only empty/`new` chat IDs make no realtime call.
- [x] Reject the stale incremental Android output and rebuild both store
      artifacts after purging build caches; the current hashes differ from the
      pre-chat-fix binaries.

- [x] Refresh the protected Android `google-services.json` after registering
      Play signing fingerprints; read-back shows three OAuth clients and the
      canonical project/app/package.
- [x] Rebuild the Android AAB after that refresh, repeat all signing/manifest/
      policy/Bundletool inspections, and record a new final SHA-256.
- [x] Prove the Android release binary contains no Super Login endpoints,
      services, demo roster, device seam, or Dev Tool graph.
- [x] Rebuild and re-sign the iOS IPA after the product-entry correction, prove
      the same forbidden-surface absence, and repeat Apple validation.
- [x] Replace Flutter's transparent launch placeholder with existing Jeeb
      branding and enforce the 1x/2x/3x scales in release inspection.

Artifact gate result: **Android PASS; iOS PASS**. Neither result authorizes a
scenario PASS.

- [ ] Freeze every intended mobile change into an immutable revision without
      dropping unrelated/user work, obtain independent release review, and
      cryptographically bind these artifacts to that revision or force-clean
      rebuild them from it.
- [ ] Reconstruct the 133 unique changed tracked paths as coherent scoped
      changes in clean worktrees; do not commit the current mixed index or the
      245 untracked paths, and keep `.codex-proof`/signer material outside Git.
- [ ] Keep both real old-identity Android Firebase config files deleted from the
      reconstructed head; use only templates and protected config injection.

Upload eligibility result: **BLOCKED on immutable source-review lineage**.

## B. Live staging barrier — must pass before upload

- [x] Public REST health is green at `https://app.jeeb.fds-1.com`.
- [ ] Normal OTP request succeeds on reserved synthetic numbers; current live
      result is 503/unavailable.
- [ ] Normal OTP receiver receipt, verify, wrong/expired, resend, lockout, and
      rate-limit checks pass.
- [ ] Super Login Plus rejects anonymous and authenticated use; current live
      surface remains open.
- [ ] Demo-user endpoints are disabled; current live surface remains open.
- [ ] Real OpenAI transcription succeeds through the public gateway using the
      committed synthetic Arabic fixture; current live voice mode is fake.
- [ ] Public WSS returns an authenticated 101 upgrade and rejects invalid or
      over-broad membership; current public WSS is unavailable.
- [ ] Paired-device chat send, receive, order, read state, reconnect, and
      duplicate-frame handling pass.
- [ ] Firebase auth/installations and receiver-side FCM delivery pass with the
      canonical app registrations.
- [ ] AASA is served without redirect and names
      `K5RDQ8J7AN.com.olivium.jeeb`.
- [ ] `assetlinks.json` is served without redirect and names
      `com.olivium.jeeb` plus the Play app-signing SHA-256.
- [ ] Plain HTTP redirects to HTTPS; the current edge returns HTTP 200 without
      a redirect.
- [ ] TLS 1.0/1.1 handshakes fail and TLS 1.2+ succeeds; the current edge still
      accepts TLS 1.1.
- [ ] Immutable deployment identity, readiness, rollback, and post-rollback
      verification evidence is retained.
- [ ] Fresh public probes replace every pre-deploy observation in the test log.

Implementation status only: gateway #523 exact head `63b19dba` and OTP #27
exact head `29ff7af` are remote-green and independently approved. OTP has 51
unit, 13 integration, and 32 rollout/policy tests, including executable
same-digest Spec-change rollback and drifted-restoration rejection. Realtime
#14 is correcting three P1 and one P2 findings; voice #27 is correcting one
newly proven full-Spec rollback P1 after all five prior findings and 173/173
tests closed. Protected Firebase/Guardian/ticket and restricted Twilio `JEEB_*`
secrets are installed. None is checked as live until deployment and probes
pass.

Barrier result: **BLOCKED / NO-GO**.

## C. Store delivery barrier

- [ ] Upload only the rebuilt, re-inspected AAB to Play Internal Testing and record the console
      release/build identifier without inviting new testers.
- [ ] Play accepts the upload certificate and processes the release.
- [x] Register and read back Play's app-signing SHA-1/SHA-256 on the existing
      Firebase Android app; it now has Play plus upload SHA-1/SHA-256 entries.
- [ ] Install from Play Internal Testing and record installed split hashes and
      Play app-signing certificate.
- [ ] Upload only the rebuilt and newly validated IPA to App Store Connect and record the build
      identifier without enabling external testing or production release.
- [ ] Wait for processing and install build `26082401` from TestFlight.
- [ ] Confirm installed package/bundle, version, Firebase registration, staging
      origin, APNs/FCM registration, and clean-install state.
- [ ] Reject any sideload, debug build, simulator build, direct intent, custom
      scheme, or developer seam as store/OS acceptance evidence.

Barrier result: **NOT RUN**.

## D. Physical device and persona barrier

- [x] Samsung A33 is ADB-authorized; no current candidate action occurred.
- [ ] Samsung S24 accepts its pending USB-debugging authorization.
- [ ] Physical iPhone is online and available for TestFlight; it is currently offline.
- [ ] Device keeper and unrelated automation are paused before the run.
- [ ] Both Android devices and the iPhone have clean store installs and recorded
      OS, locale, font scale, permissions, network, battery, and storage state.
- [ ] Two isolated adult synthetic customer/Jeeber personas and cleanup owner are assigned.
- [ ] Both personas authenticate using normal phone/OTP.
- [ ] Server-authoritative account, role, KYC, and open-entity before-state is recorded.
- [ ] Super Login Plus, demo users, mocks/fakes, crafted role/KYC state, and
      sender-only evidence are absent.

Barrier result: **BLOCKED / NOT READY**.

## E. Exact store-delivered scenario queue

- [ ] JMS-AUTH-001, JMS-AUTH-002, JMS-AUTH-003, JMS-AUTH-008
- [ ] [JMS-LINK-001](../../cross-cutting/JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md)
- [ ] JMS-JHP-001, JMS-JHP-002, JMS-JHP-003
- [ ] JMS-REQ-001–008
- [ ] JMS-KYC-001–009
- [ ] JMS-DEL-001–012
- [ ] JMS-PUSH-001–010
- [ ] JMS-RES-001–010
- [ ] All remaining P0/P1, required locale/accessibility, and full Clarity
      privacy scenarios in [GATE-MATRIX.md](../../GATE-MATRIX.md)

Execution order and synchronization barriers are defined in
[REPORT.md](REPORT.md). No exact scenario has started in this run.

## F. Evidence, reconciliation, and cleanup

- [ ] Copy and complete the [per-scenario checklist](../../checklists/PER-SCENARIO.md)
      for every exact ID.
- [ ] Capture sender, receiver, and authoritative server read-back with one
      non-sensitive run nonce for all cross-actor writes.
- [ ] Reconcile current server state before any retry after timeout or unknown result.
- [ ] Record well-known file hashes, OS trust state, outside-app tap, target, and
      safe back stack for JMS-LINK-001.
- [ ] Prove KYC media, chat, location, delivery, OTP, push, Clarity, and logs use
      synthetic/redacted content only.
- [ ] Prove direct cash handover without any electronic payment, settlement, or
      money-moving refund call.
- [ ] Reset every synthetic request, offer, chat, delivery, KYC fixture, push
      token, and evidence attachment; read back final state.
- [ ] Complete the [evidence/privacy checklist](../../checklists/EVIDENCE.md)
      and secret scan.
- [ ] Append every fact and correction to [TEST-LOG.md](TEST-LOG.md); never
      overwrite historical observations in [DATA.json](DATA.json).
- [ ] Staff Mobile QA issues an exact-ID accounting and GO/NO-GO decision.

Current release decision: **NO-GO**.
