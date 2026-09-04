# Firebase & push invariants

Contract, not prose. If you are about to touch anything Firebase/FCM/push in
this repo, read this first. Every rule below exists because breaking it once
already caused a real incident — see the SHA cited per rule.

## 1. The one true project

- Project: **`jeeb-5a293`**, project_number **`1051234312170`**. This is the
  only Firebase project this app ever talks to — production, staging, and
  dev flavor all resolve to the same project and Firestore database
  **`(default)`**. The machine-readable source of truth is
  `contracts/jeeb-firebase-v1.json`; native app registrations are pinned in
  `contracts/jeeb-mobile-firebase-apps-v1.json`.
- **`alrahmah-d7a33` is FORBIDDEN.** Never point any Firebase config,
  `google-services.json`, plist, or Firestore rule at it. No commit in this
  repo's history has ever done so, but the risk is live enough that
  `pubspec.yaml:176-179` carries a standing comment: chat history written to
  that project once caused a **live outage**. Treat any PR that introduces
  the string `alrahmah` anywhere near Firebase config as an instant reject.
- **`.firebaserc` (repo root) pins the CLI default project to `jeeb-5a293`.**
  The logged-in Firebase CLI account on this Mac can also see forbidden
  projects, and `flutterfire configure` rewrites every config wholesale — the
  pin plus the doctor/integrity-test checks make any such rewrite loud.

## 2. File policy — what's committed, what isn't, and why

| File | Tracked? | Why |
|---|---|---|
| `android/app/google-services.json` (production/staging) | **NO — protected injection** | The release wrapper validates project, canonical package `com.olivium.jeeb`, app ID, signer-bound OAuth client, file mode, and cleanup before building. |
| `android/app/src/dev/google-services.json` | **NO — protected injection** | The dev wrapper validates the existing `app.jeeb.mobile.dev` registration and removes the mode-0600 file on success or failure. |
| `*.template` files (both flavors) | YES | Reference/onboarding copies with `TODO_*` sentinels. |
| `pubspec.lock` | **YES** | Pins the resolved Firebase package graph (firebase_core/auth/messaging/cloud_firestore/crashlytics + all `*_platform_interface`/`*_web` transitives) so a fresh `pub get` can't silently re-roll into the pigeon-poison range (§3). Mirrors `ios/Podfile.lock`, which has always been tracked. |
| `ios/Runner/GoogleService-Info.plist` | **NO — protected injection** | The iOS wrappers validate the store or dev app registration against the same canonical project, then remove the file after compile/archive, including failure paths. |
| `lib/core/firebase/firebase_options.dart` | **DELETED** | Dead placeholder (`DefaultFirebaseOptions.currentPlatform` always threw). Zero references repo-wide; native config drives initialization (see §5). |

**All four real native configs must be gitignored, untracked, and absent when
their wrapper is not active. `pubspec.lock` must remain tracked and unignored.**
Templates document shape only; they are not accepted as build inputs.

**Root cause M1 — gitignored-but-required config, 7 confirmed incidents**
(`68600da8`+`95b1736d` 06-22 same-day contradiction, `ed1f00c4` 06-30 force-track,
`6243f72c` 07-12 official resolve, `d0046320` 07-18 branch reverts the regime and
sits unmerged for 4 weeks, `7184c551`/`7c4c139c`/`23cb37b8` 07-21 identical fix
landed independently 3× by parallel lanes, `963cdae6` 08-05, `b22aff78` 08-15
reinstates the dead 4-week-stale regime wholesale on merge). The mechanism is
always involved an implicit local file with no supported reconstruction path.
The current policy closes that mechanism: builds fail closed without protected
input, wrappers validate before use, cleanup is trapped, and source tests prove
the real files remain absent/untracked/ignored. Never restore a skip-worktree
overlay or direct shell redirection as a substitute for the wrappers.

## 3. Dependency envelope

```
firebase_core        >=3.13.1 <3.15.0   (resolved 3.14.0)
firebase_auth        5.6.0 EXACT        (resolved 5.6.0)
firebase_messaging    ^15.1.3           (resolved 15.2.7)
cloud_firestore       ^5.6.5            (resolved 5.6.9)
firebase_crashlytics  ^4.1.3            (resolved 4.3.7)
```

**The 3.15.0/3.15.1 pigeon-poison story:** `firebase_core` 3.15.0 and 3.15.1
pull `firebase_core_platform_interface` `^5.4.1` but ship pigeon channels
namespaced for platform_interface 6.0.0 — a channel-name mismatch, not a
version mismatch, so the failure is a runtime `PlatformException(channel-error)`
on `Firebase.initializeApp()`, not a resolve-time conflict. It bit live
hardware once: `4fedf9b0` (2026-08-10), S22, FCM entirely dead. Root enabler
was `pubspec.lock` being gitignored plus an unpinned `^3.6.0` range — "bit one
build machine and not another" per the fix commit. The range `>=3.13.1
<3.15.0` is the fix and is not negotiable; do not widen it to `^3.x` or bump
past 3.15.0 without re-deriving this whole analysis.

**Why 3.15.2+ is also blocked, not just 3.15.0/3.15.1:** the currently tested
FlutterFire bill of materials is the 3.14.0 generation, including exact
`firebase_auth 5.6.0`, and the protected unsigned/signed iOS release gates
resolve it successfully through the tracked SwiftPM/CocoaPods graph. Moving
past this family is a coordinated Dart+native+lockfile change, not a one-line
bump. `firebase_messaging`,
`cloud_firestore`, and `firebase_crashlytics` stay on open caret ranges
deliberately — over-pinning them blocks legitimate patches with no
documented native-floor-per-version map to justify it — but any resolve
above their current point version (15.2.7 / 5.6.9 / 4.3.7 respectively)
needs a manual native-pod compatibility check before merge.

**The lock-floor-vs-CI trap:** `pubspec.lock`'s own `sdks:` block floors at
`dart >=3.12.0 / flutter >=3.44.0` — higher than `pubspec.yaml`'s declared
environment (`dart >=3.10.8`, `flutter >=3.16.0`). CI workflows pin
`FLUTTER_VERSION: '3.44.2'`, which satisfies the lock floor — but if CI's
version is ever dropped back below 3.44.0 while this lock stays committed, a
`pub get --enforce-lockfile` (or equivalent) fails on the **SDK floor alone**,
independent of any package version fight. `tool/firebase_doctor.sh` (§4)
checks this specific trap: lock floor vs. locally-installed Flutter, and vs.
each CI workflow's declared `FLUTTER_VERSION`. If you bump the lock (any
`pub upgrade` that touches a firebase-family package), rerun the doctor
before committing.

## 4. How to check everything in one command

```
bash tool/firebase_doctor.sh
```

Requires `jq` (not preinstalled on macOS — `brew install jq`); without it the
doctor fails fast with one line rather than a wall of empty-value errors.

Run this after any change to `pubspec.yaml`/`pubspec.lock`, any Firebase
config file, or any CI workflow's Flutter version. It is the single source of
truth for "is the Firebase/push envelope currently sound" — it supersedes
manually re-deriving §3's table by hand. **`test/firebase_doctor_test.dart`
shells out to it on every `flutter test` run**, so a normal local test run
already covers this — you only need to run the doctor by hand when iterating
on the envelope itself before committing.

The config-file invariants in §2 are separately asserted by
`test/firebase_config_integrity_test.dart`, and the disabled-workflow gates by
`test/dev_firebase_workflow_contract_test.dart`. (Not to be confused with
`firebase_identity_teardown_test` / `firebase_custom_token_identity_uid_test` /
`gateway_chat_firebase_token_minter_test`, which guard *chat identity* and have
nothing to do with the doctor.)

**Alarm-fatigue guard (root cause M2):** a guard that is permanently red teaches
everyone to ignore it. The protected dev pipeline is now implemented through
`tool/run_with_dev_firebase_config.sh`; CI must call that wrapper and must not
write the payload directly. Every guard in this document is required to be
green against the committed tree.

## 5. Runtime

**Three `Firebase.initializeApp()` call sites, all optionless / native-config
-driven — none passes `DefaultFirebaseOptions` (that class is gone, §2):**
1. `lib/app/bootstrap.dart` — `_defaultCrashReporterFactory()`, 5s timeout,
   falls back to `NoopCrashReporter` on any error/timeout.
2. `lib/app/app.dart` — `_defaultFirebaseInitializer()`, no-op if
   `Firebase.apps` is non-empty, swallows duplicate-app, rethrows others.
3. `lib/features/auth/social/social_auth_service.dart` — Google Sign-In's own
   independent init, guarded the same way.

Initialization is driven entirely by the native `google-services.json` /
`GoogleService-Info.plist` picked up by the Gradle/CocoaPods Firebase
plugins — there is no Dart-side options object in the loop.

**Registration:** `lib/core/notifications/data/device_token_registrar.dart`
— `PUT /api/PushNotification/register`, body `{fcmToken, deviceId}`. Wired
in `_initPushChainAsync()` (`lib/app/app.dart`) **only** when the transport is a real
`FirebaseMessagingTransport` (never for the fake). Polls up to 40×3s for a
resolved user id, then `revalidate()` on app resume (30-min rate-limited).

**The `JEEB-PUSH-DEGRADED` tripwire** — emitted by `_logPushDegraded()` in
`lib/app/app.dart`, at the existing silent-degrade path
(`transport = built ?? FakePushTransport();`). This is **prophylactic
instrumentation, not a repair**: on-hardware evidence (S24 + A336B,
2026-08-23) shows this path has never fired — `FakePushTransport`,
`channel-error`, and `MissingPluginException` are all 0/6 across every logcat
buffer collected. It is keyed on the **cleartext `deviceId`**, never the FCM
token or `Authorization` header — both are redacted in logs by policy, so a
token-keyed tripwire would be unreadable. On-call runbook grep:
```
adb logcat | grep -E 'JEEB-PUSH-DEGRADED|JEEB-PUSH-DROPPED'
```
A hit means a real device fell back to the fake transport (`DEGRADED`) or
suppressed an arriving push on the audience gate (`DROPPED`); today both have
a 0% observed rate, so any hit is worth investigating immediately.

> ⚠️ **LIMITATION — both tripwires are `kDebugMode`-gated, so a RELEASE build
> emits NEITHER.** The grep above only works against a debug/profile build. A
> genuine production outage is therefore still invisible to this tripwire; the
> release-visible signal remains the `Diag` JSON event (`push_suppressed`),
> which honours `--dart-define=JEEB_DIAG=true`. Moving the tripwires onto
> `Diag.enabled` would close this gap with no change to default release
> behaviour, but it puts a `deviceId` into production logs — **owner decision,
> deliberately not taken here.**

## 6. Environment and producer contract

- **Staging and production share the permanent native identity**
  `com.olivium.jeeb`; staging is selected through runtime defines, not a package
  suffix. Protected configuration and source gates are green, while real
  store-installed Firebase/FCM behavior remains an explicit acceptance gate.
- **Dev uses separate native app registrations in the same project.** Android
  uses `app.jeeb.mobile.dev`; iOS uses `app.jeeb.jeebMobile.dev`. Different
  provider files are required because package/bundle identity is part of each
  file, but both files are contract-checked to `jeeb-5a293` / `(default)`.
- **`notification-service` is the sole durable push producer.** The
  push-notification service is the FCM relay; gateway direct delivery remains
  denied except registration/recovery. Treat any second durable sender as a
  contract violation, even if dispatch-ledger deduplication hides duplicates.
- **CI is enabled for pull requests and main.** Source tests and dependency
  guards run without provider files; the secret-dependent dev APK build runs
  only after a main push through the protected wrapper. A green PR remains
  source evidence, not proof of real Firebase delivery on a store build.

## 7. If push is broken, do this in order

1. **Confirm it's actually broken, not perceived.** Check
   `push_notification` (token-on-file) and `push_dispatch` (send outcome) on
   the live DB (`:5442`, `jeeb-push-notifications` database) before touching
   any client code — most historical "push is broken" reports were
   registration-timing bugs (root cause M6, 6 distinct incidents, same
   symptom: device never registers or registers under the wrong identity),
   not send-side failures.
2. **Grep hardware logcat for the tripwire** (§5): `JEEB-PUSH-DEGRADED`. If
   present, the device fell back to `FakePushTransport` — this is a client
   init failure, go to step 3. If absent, the client believes it has a real
   transport; the problem is registration or server-side, go to step 4.
3. **Run the doctor:** `bash tool/firebase_doctor.sh`. This catches the
   dependency-envelope class of failure (§3) — wrong `firebase_core`
   version, lock/CI SDK floor mismatch, native pod drift. If it's red, fix
   what it reports before doing anything else.
4. **Check registration, not send.** Confirm `PUT /api/PushNotification/register`
   actually fired (device logcat) and returned 201, and that the resulting
   row in `push_notification` carries the right `user_id`/`active_role`. The
   registrar only wires up for a real `FirebaseMessagingTransport` — a fake
   transport (step 2) silently means registration never happens at all.
5. **Check audience gating** (root cause M7 — push audience/role-gating
   dead-code & silent-drop, 3 confirmed incidents, most recent `32546906`
   08-16: a role-set synthesized before `getMe()` resolved made the
   fail-open branch unreachable, so a jeeber-audience push arriving early
   was matched against the default `client` role and silently dropped,
   logged as `push_suppressed {"reason":"audience_mismatch"}`). Grep client
   logcat for `push_suppressed` before assuming the server never sent it.
6. **Only then suspect the server.** Check `push_dispatch` for
   `UNREGISTERED`/`NotRegistered`/`InvalidRegistration` — that specific
   signature has not been observed live as of 2026-08-23 (all recent
   failures were 404 "no token on file", a registration problem, not a
   token-rejection problem).
