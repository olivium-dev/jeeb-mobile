# Staging TestFlight and Play Internal audit — 2026-08-24

> Current verdict: **ANDROID/IOS ARTIFACTS PASS; UPLOAD/LIVE/STORES NO-GO**

This is the superseding 2026-08-24 snapshot. Earlier observations remain in the
append-only [test log](TEST-LOG.md) and [structured data](DATA.json). No store
upload, tester invitation, production promotion, or physical scenario is
claimed here.

## Frozen release target

```text
Native Android/iOS identity: com.olivium.jeeb
Firebase project: jeeb-5a293
APP_FLAVOR: staging
REST origin: https://app.jeeb.fds-1.com
App/Universal Link host: app.jeeb.fds-1.com
Build name/code: 1.0.0 / 26082401
```

The user confirmed `com.olivium.jeeb` as the permanent identity. Staging is a
runtime configuration, not a `.staging` package suffix. The existing Firebase
project was extended with the matching registrations; no new project was
created.

## Proven identity and artifact facts

| Surface | Result |
|---|---|
| App Store Connect | App `6804058185`, bundle `com.olivium.jeeb` |
| Google Play | App `4975946044353879549`, package `com.olivium.jeeb`; Play App Signing active |
| Apple App ID/team | `com.olivium.jeeb` / `K5RDQ8J7AN`; Associated Domains, Push Notifications, Sign In with Apple, and In-App Purchase enabled |
| Firebase Android | `1:1051234312170:android:85bc801430c9006623dc93` in `jeeb-5a293` |
| Firebase iOS | `1:1051234312170:ios:1036d2eaaf63036a23dc93` in `jeeb-5a293` |
| Android release | Forced-clean source-current signed AAB, API 36, SHA-256 `4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b`; 77,670,304 bytes |
| Android certificates | Upload signer `7A:E6:A6:20:BA:89:E8:43:85:13:E4:2C:F5:9E:69:E3:CF:0F:CD:CE:8C:87:D7:71:3B:07:8C:80:3D:A2:E3:BA`; Play app signer `42:76:6A:BB:4B:EA:1F:A4:88:00:96:6F:78:A1:E5:4F:A0:EA:12:B8:A1:6A:58:AF:07:5A:02:01:0B:B5:58:E9` |
| iOS release | Forced-clean source-current signed IPA, 44,386,543 bytes, SHA-256 `eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94`; Super Login/Dev Tool absent and branded launch screen enforced |
| iOS signer/profile | Apple Distribution team `K5RDQ8J7AN`; profile UUID `78f0591f-fd55-467f-8acc-8c9b14821277`, expires 2027-03-25 |
| iOS validation | `xcrun altool --validate-app` exits 0, no errors, warning 90068 only; validation only, not upload |
| Exact mobile source suite | 7,868 passed, 66 intentionally skipped, 0 failed; compose-only empty/`new` chat IDs make no realtime request |
| Current Android policy scan | Protected Firebase/Maps inputs and staging origin present; cleartext, forbidden/LAN endpoints, wildcard token mint, old package, Super Login endpoint/type/demo/seam, Dev Tool graph, and UPG route absent |
| Current iOS policy scan | Strict signature, protected Firebase/Maps, staging origin, production APNs, universal-link entitlement, branded launch scales, and dependency ownership pass; forbidden/LAN/wildcard-token/Super Login/Dev Tool surfaces are absent |

Full paths, sizes, profile name, entitlements, and Apple validation evidence are
recorded in [REPORT.md](REPORT.md). Both binaries pass artifact inspection but
remain upload-held: the shared mobile source tree must first be frozen into an
immutable revision, independently reviewed, and then cryptographically bound
to these binaries or rebuilt from that approved revision.

The source-lineage audit found 60 staged and 92 unstaged tracked paths with 19
collisions (133 unique changed tracked paths), plus 245 untracked paths, at
`origin/main`/`a8810345`. The staged index is not build-coherent and must not be
committed. Raw `.codex-proof` evidence, binaries, and signer material remain
outside Git; coherent release changes must be reconstructed in clean worktrees.

The upload and Play app-signing certificates are intentionally distinct. Play
SHA-1 `2E:CF:AF:7F:13:AB:9E:B5:34:E4:04:AD:3B:A9:F6:B2:A1:EA:77:12` and the
recorded Play SHA-256 were added idempotently to the existing Firebase Android
app. Read-back shows two SHA-1 and two SHA-256 entries, covering Play and upload
signers. Store-delivered Google/Firebase behavior remains NOT RUN.

In-App Purchase was already enabled on the Apple App ID. It does not authorize
electronic payment in Jeeb, and the mobile tree contains no StoreKit or
`in_app_purchase` implementation. Jeeb remains cash-on-delivery only.

## Live staging truth

| Gate | Current public state | Isolated remediation state | Verdict |
|---|---|---|---|
| REST health | Green over Cloudflare HTTPS | N/A | PASS, re-probe after deploy |
| Phone OTP | 503 / upstream disabled | Restricted Jeeb-scoped Twilio secret files installed; PR #27 head `29ff7af` is remote-green and independently approved with full-Spec rollback; protected physical canary recipient still absent | BLOCKED |
| Super Login Plus/demo | Open | Closed defaults and policy guards implemented | BLOCKED |
| Voice | Fake transcription enabled | Head `e5b3142` is remote-green and closes the five prior findings with 173/173 tests; exact review proved one remaining same-digest full-Spec rollback defect and an isolated writer is correcting it | BLOCKED |
| WSS/chat | No public authenticated 101 upgrade | Gateway descriptor is approved; realtime #14 head `ac05b64` is 634/634 local and remote-green, but review found three P1 and one P2 covering full-Spec rollback, verifier ordering, missing authenticated WSS probes, and checkout authority; an isolated writer is correcting them | BLOCKED |
| Gateway | Old live behavior | PR #523 exact head `63b19dba` is remote-green and independently approved; protocol/cross-repo/live gates remain | BLOCKED |
| Firebase/push | Not proven on store candidates | Canonical selection plus Guardian/ticket secrets installed | BLOCKED |
| AASA/asset links | Not live | Artifact identity/entitlements aligned | BLOCKED |
| Edge transport | HTTP is served without redirect; TLS 1.1 succeeds | Worker redirect is under review; minimum-TLS zone control is not authorized | BLOCKED |
| Cloudflare edge control | Target tunnel is readable, but no Worker-authorized token is installed | Required routes and exact-version recovery contract are under review | BLOCKED |

Implemented-but-not-live work is not a pass. Each row requires a fresh public
probe after an approved immutable deployment, including readiness and rollback
evidence.

## Store and physical state

| Target | State | Required next evidence |
|---|---|---|
| Play Internal Testing | No release uploaded or delivered | After source-lineage review and live staging closure, upload only AAB SHA-256 `4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b` if it is bound to the approved source; prove Play acceptance and store-installed signing/hash |
| TestFlight | Current IPA is signed and Apple-validation green; no upload/delivery | After source-lineage review and live staging closure, upload only SHA-256 `eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94` if it is bound to the approved source; record processing/store provenance |
| Samsung A33 | ADB authorized | Clean Play install, normal OTP, exact scenario record |
| Samsung S24 | ADB unauthorized | Accept USB prompt, then clean Play install and receiver-side run |
| Physical iPhone | Offline | Bring online, install from TestFlight, execute iOS/push/link matrix |

## Upload and acceptance boundary

Apple validation, a signed bundle, source tests, or a healthy REST endpoint are
not functional PASS results. Before the candidates can satisfy release gates:

1. the exact mobile source must be frozen, independently reviewed, and bound to
   the upload artifacts;
2. live OTP, bypass/demo closure, real voice, WSS, Firebase/push, AASA, and
   asset links must pass fresh public probes;
3. the exact hashes must be delivered by Play Internal Testing and TestFlight;
4. both personas must authenticate through normal OTP;
5. KYC, request, delivery, receiver-side chat/push, COD/OTP/receipt/rating,
   recovery, and [JMS-LINK-001](../../cross-cutting/JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md)
   must run on physical devices with server read-back and cleanup.

Super Login Plus, demo users, mocks/fakes, crafted state, direct LAN/service
access, custom-scheme/direct-intent substitutes, sideloads, and sender-only
evidence cannot close these gates.
