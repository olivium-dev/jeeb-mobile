# Staging TestFlight and Play Internal audit — 2026-08-24

> Snapshot: 2026-08-24 18:37 UTC
>
> Current verdict: **MOBILE EXACT-HEAD CI PASS; REVIEW, FRESH ARTIFACT BUILDS, UPLOAD, LIVE, AND STORES NO-GO**

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
| Android release | Historical forced-clean signed AAB, API 36, SHA-256 `4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b`; 77,670,304 bytes; predates reconstructed head |
| Android certificates | Upload signer `7A:E6:A6:20:BA:89:E8:43:85:13:E4:2C:F5:9E:69:E3:CF:0F:CD:CE:8C:87:D7:71:3B:07:8C:80:3D:A2:E3:BA`; Play app signer `42:76:6A:BB:4B:EA:1F:A4:88:00:96:6F:78:A1:E5:4F:A0:EA:12:B8:A1:6A:58:AF:07:5A:02:01:0B:B5:58:E9` |
| iOS release | Historical forced-clean signed IPA, 44,386,543 bytes, SHA-256 `eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94`; Super Login/Dev Tool absent, branded launch screen enforced, and predates reconstructed head |
| iOS signer/profile | Apple Distribution team `K5RDQ8J7AN`; profile UUID `78f0591f-fd55-467f-8acc-8c9b14821277`, expires 2027-03-25 |
| iOS validation | `xcrun altool --validate-app` exits 0, no errors, warning 90068 only; validation only, not upload |
| Exact mobile source suite | Source-bearing `e07d4542`: 7,882 passed, 66 intentionally skipped, 0 failed in approximately 329 seconds; compose-only empty/`new` IDs make no realtime request; committed passcode fallback removed; courier tracking requires WSS outside dev; PR #276 validation head `c2b907485` passes all eight reported remote checks |
| Exact mobile local gates | Flutter analyze and fatal-info clean after generated SourcePackages removal; Firebase doctor, 13 protected-config tests, actionlint, ShellCheck, Gitleaks, and diff pass |
| Current Android policy scan | Protected Firebase/Maps inputs and staging origin present; cleartext, forbidden/LAN endpoints, wildcard token mint, old package, Super Login endpoint/type/demo/seam, Dev Tool graph, and UPG route absent |
| Current iOS policy scan | Strict signature, protected Firebase/Maps, staging origin, production APNs, universal-link entitlement, branded launch scales, and dependency ownership pass; forbidden/LAN/wildcard-token/Super Login/Dev Tool surfaces are absent |

Full paths, sizes, profile name, entitlements, and Apple validation evidence are
recorded in [REPORT.md](REPORT.md). Both binaries pass historical artifact
inspection but remain upload-held pending independent review of the exact
reconstructed head and then clean rebuilds from that head.

The source-lineage audit historically found 60 staged and 92 unstaged tracked
paths with 19 collisions (133 unique changed tracked paths), plus 245 untracked
paths, at `a8810345`. Its sanitized 188-file selection was reconstructed as
`e208a4c8906330c8df126f2391ae149a8291e6f6`. `origin/main`
`0c26c159c9714b812bd2a0f6ec3cc9488c7d39c8` was merged into the feature branch.
Source-bearing commit `e07d4542` adds the credential/WSS closures and has a
194-file diff with 12,392 insertions and 4,510 deletions. Reproducible release
contract corrections are included in pushed PR #276 validation head
`c2b90748518d2a01823e670b1ee4492f7db2f9c9`. The PR remains open and has not
been merged to main.

The initial 7,206 analyzer diagnostics came only from generated third-party
`build/ios/SourcePackages` and were a tool-scope error, not source findings.
After that generated tree was removed, Flutter analyze and fatal-info were
clean. PR #276 was CLEAN and mergeable at `c2b907485`; CI, Flutter CI, Mobile
CI, and the fail-closed policy are terminal green across all eight reported
checks. Independent review and fresh signed artifact builds remain open.

The canonical historical `jeeb-5a293` / `app.jeeb.mobile.dev` configuration was
validated without output. Four named dev repository Actions secrets are
installed, with names/timestamps only read back. Real native configs remain
absent, and the dev wrapper removes injected configuration after both success
and failure. No provider resource was changed and no secret value was exposed.

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
| REST health | `/health/ready` returns 200 over Cloudflare HTTPS | N/A | PASS, re-probe after deploy |
| Phone OTP | 503 / upstream disabled | Restricted Twilio files and one protected owner-controlled canary recipient are installed; PR #27 `29ff7af` is test-green, but prior approval is superseded by the cross-service plain-CLI rollback race; no SMS sent | BLOCKED |
| Super Login Plus/demo | Anonymous public probe returns 200 | Closed defaults and policy guards implemented | BLOCKED |
| Voice | Fake transcription enabled | Voice #27 `6509c840` is test-green, but prior approval is superseded by the same rollback race; not deployed | BLOCKED |
| WSS/chat | Upgrade reaches the gateway at 401, not the Phoenix 101 path | Realtime #14 `4959d9e` is remote 4/4 green with 634 ExUnit, 48 policy/rollout, and 15 WSS locally; exact review found two P1s: recovery CAS race and stale runbook order | BLOCKED |
| Gateway | Old live behavior | Base #523 `63b19dba` is green; safe bootstrap with features OFF, descriptor proof, Engine API CAS, and generic staging-bypass block is local/unpushed | BLOCKED |
| Firebase/push | Not proven on store candidates | Canonical selection plus Guardian/ticket secrets installed | BLOCKED |
| AASA/asset links | Both well-known endpoints return 401 | Artifact identity/entitlements aligned | BLOCKED |
| Edge transport | HTTP returns 401 without redirect; TLS 1.0, TLS 1.1, and TLS 1.2 all negotiate | Worker redirect and target-zone minimum TLS configuration are not deployed | BLOCKED |
| Cloudflare edge control | `CLOUDFLARE_API_TOKEN` exists in `jeeb-infrastructure/staging` with least-privilege Workers Scripts metadata; no value was read | Access blocker cleared; required routes/configuration and exact-version recovery contract remain pending | BLOCKED ON CONFIGURATION/DEPLOYMENT |

Implemented-but-not-live work is not a pass. Each row requires a fresh public
probe after an approved immutable deployment, including readiness and rollback
evidence.

### Binding two-phase gateway/realtime/edge plan

There is no safe one-step order:

1. Deploy gateway bootstrap with chat OFF and the descriptor contract ON.
2. Deploy realtime compatibility with the real descriptor and pass the
   direct-host Phoenix gate while rollback remains armed.
3. Enable edge/public WSS and pass the public realtime gate.
4. Activate a small gateway slice, pass real chat/user/mobile canaries, and
   only then turn chat ON.

Execution remains blocked by Engine API version-CAS remediation/re-review in
gateway, realtime, OTP, and voice and by unapplied edge/zone configuration.
Cloudflare access and the protected SMS canary input are present, but no
deployment or SMS canary has run. The recipient value is not retained here.
All five GitHub staging environments do enforce only their exact default
branch.

## Store and physical state

| Target | State | Required next evidence |
|---|---|---|
| Play Internal Testing | No release uploaded or delivered | After source-lineage review and live staging closure, force-clean rebuild and reinspect the AAB from the exact approved head; upload only that newly recorded hash, then prove Play acceptance and store-installed signing/hash |
| TestFlight | Historical IPA is signed and Apple-validation green; no upload/delivery | After source-lineage review and live staging closure, force-clean rebuild, sign, inspect, and validate the IPA from the exact approved head; upload only that newly recorded hash and retain processing/store provenance |
| Samsung A33 | ADB authorized | Clean Play install, normal OTP, exact scenario record |
| Samsung S24 | ADB unauthorized | Accept USB prompt, then clean Play install and receiver-side run |
| Physical iPhone | Reachable; no phone number read/exposed; no candidate installed | After store delivery, install from TestFlight and execute the iOS/push/link matrix |

## Upload and acceptance boundary

Apple validation, a signed bundle, source tests, or a healthy REST endpoint are
not functional PASS results. Before the candidates can satisfy release gates:

1. the remote mobile workflows are green at validation head `c2b907485`;
   independent review must pass, after which both upload artifacts must be
   force-clean rebuilt and reinspected from the approved revision;
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
