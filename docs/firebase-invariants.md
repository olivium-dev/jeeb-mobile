# Firebase & push invariants

Contract, not prose. If you are about to touch anything Firebase/FCM/push in
this repo, read this first. Every rule below exists because breaking it once
already caused a real incident — see the SHA cited per rule.

## 1. The one true project

- Project: **`jeeb-5a293`**, project_number **`1051234312170`**. This is the
  only Firebase project this app ever talks to — production, staging, and
  dev flavor all resolve to the same project (staging currently has no
  client entry at all; see §6).
- **`alrahmah-d7a33` is FORBIDDEN.** Never point any Firebase config,
  `google-services.json`, plist, or Firestore rule at it. No commit in this
  repo's history has ever done so, but the risk is live enough that
  `pubspec.yaml:176-179` carries a standing comment: chat history written to
  that project once caused a **live outage**. Treat any PR that introduces
  the string `alrahmah` anywhere near Firebase config as an instant reject.

## 2. File policy — what's committed, what isn't, and why

| File | Tracked? | Why |
|---|---|---|
| `android/app/google-services.json` (prod/staging flavor) | **YES** | Firebase *client* config is public by design (it's shipped inside the APK anyway) — there is no secret in it. |
| `android/app/src/dev/google-services.json` | **YES** | Same reasoning; dev flavor ships two clients (`app.jeeb.mobile` + `app.jeeb.mobile.dev`), same project. |
| `*.template` files (both flavors) | YES | Reference/onboarding copies with `TODO_*` sentinels. |
| `pubspec.lock` | **YES** | Pins the resolved Firebase package graph (firebase_core/auth/messaging/cloud_firestore/crashlytics + all `*_platform_interface`/`*_web` transitives) so a fresh `pub get` can't silently re-roll into the pigeon-poison range (§3). Mirrors `ios/Podfile.lock`, which has always been tracked. |
| `ios/Runner/GoogleService-Info.plist` | **NO — stays gitignored** | Not injected by any pipeline today; iOS dev builds exclude it entirely (`EXCLUDED_SOURCE_FILE_NAMES` in the `-dev` Xcode configs) by design. This is the one legitimate untracked Firebase file. |
| `lib/core/firebase/firebase_options.dart` | **DELETED** | Dead placeholder (`DefaultFirebaseOptions.currentPlatform` always threw). Zero references repo-wide — no call site ever used it. All three real `Firebase.initializeApp()` sites are optionless and native-config-driven (see §5). Its `.gitignore` entry for the never-generated `firebase_options.g.dart` is removed too. |

**`.gitignore` must never re-ignore `google-services.json` (either flavor) or
`pubspec.lock`.** If you find either re-added to `.gitignore`, that is a
regression of the historical failure mode below — revert it, don't "fix" the
ignore rule.

**Root cause M1 — gitignored-but-required config, 7 confirmed incidents**
(`68600da8`+`95b1736d` 06-22 same-day contradiction, `ed1f00c4` 06-30 force-track,
`6243f72c` 07-12 official resolve, `d0046320` 07-18 branch reverts the regime and
sits unmerged for 4 weeks, `7184c551`/`7c4c139c`/`23cb37b8` 07-21 identical fix
landed independently 3× by parallel lanes, `963cdae6` 08-05, `b22aff78` 08-15
reinstates the dead 4-week-stale regime wholesale on merge). The mechanism is
always the same: a required file gets gitignored (or a branch that gitignores
it survives long enough to get merged later), then something destructive —
**`git clean -X`/`-x`, an rsync `--exclude`, or template regeneration**
— deletes the "ignored" file that a build actually needs, and the break isn't
caught because nothing enforces "this file must be tracked." `b22aff78` is the
clearest single incident: a merge-all sweep reinstated the gitignored-dev-json
regime *and* landed two permanently-red contract tests in the same commit
(root cause M2, see §4). If you are ever tempted to gitignore a Firebase
config file "to keep it out of git", read the incident list above first.

## 3. Dependency envelope

```
firebase_core        >=3.13.1 <3.15.0   (resolved 3.14.0)
firebase_auth        5.4.2 EXACT        (resolved 5.4.2)
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

**Why 3.15.2+ is also blocked, not just 3.15.0/3.15.1:** 3.15.2+ requires
`platform_interface ^6.0.0` outright, which is incompatible with the
`firebase_auth 5.4.2` **exact** pin — that pin exists because `ios/Podfile`
pins native `FirebaseSDKVersion = '11.4.0'` (plus two forced pod pins,
`FirebaseCoreInternal`/`FirebaseSharedSwift` at 11.4.0, to stop transitive
float to 11.15.0 which needs Xcode 16/Swift 6). Moving `firebase_auth` past
5.4.2 means moving the native floor past 11.4.0, which is a coordinated
Dart+native+Podfile change, not a one-line bump. `firebase_messaging`,
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

**Alarm-fatigue guard (root cause M2):** a guard that is permanently red
teaches everyone to ignore it, and real drift ships unnoticed underneath the
noise — that is exactly how M1 incident #19 (`b22aff78`) landed: two
contract tests asserting a CI secret-injection pipeline
(`DEV_GOOGLE_SERVICES_JSON_B64`) that was never built, both deterministically
red from the moment they were added. Every guard in this doc is required to
be green against the tree as committed. If you add a guard and it can't pass
today, it does not belong in this contract — fix the tree first, or don't
add the guard yet.

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

## 6. Known gaps (gaps, not bugs — do not "fix" these without an owner decision)

- **Staging flavor has no Firebase client entry** in any `google-services.json`
  (`applicationIdSuffix ".staging"`, `android/app/build.gradle:105-107`).
  Latent: no staging build has ever run on hardware, so this has never been
  exercised. If someone builds staging, expect init to fail or mismatch.
- **iOS dev builds ship with no Firebase at all**, by design — the `-dev`
  Xcode configs (`Release-dev`/`Debug-dev`/`Profile-dev`) exclude
  `GoogleService-Info.plist` via `EXCLUDED_SOURCE_FILE_NAMES`. This is
  intentional, not an oversight.
- **`notification-service` (`:10026`) is a second push producer.** It sits
  alongside the push relay (`jeeb-push.service`, `:10040`) and gateway
  proxying. Server-side dispatch-ledger analysis (`push_dispatch`, last 3
  days: 14/14 succeeded, 0 duplicates by `(target_user_id, request_hash)`)
  found no evidence of double-firing — the risk this gap represents is
  **duplicate pushes, not lost pushes**. Don't treat a user report of "I got
  two notifications" as a registration bug; check this producer first.
- **CI is disabled fleet-wide** (`ci.yml`, `flutter-ci.yml`, `mobile-ci.yml`
  all `disabled_manually`; only `fail-closed-deploy-policy.yml` is active,
  and it runs exactly one step, `check_fail_closed_deployment.py` — it does
  **not** run `tool/check_firebase_core_pin.sh` or anything Firebase-related).
  That means **local `flutter test` is the real gate** for everything in
  this document until GitHub Actions is re-enabled (owner-gated, Phase P).
  Don't assume a green PR means these workflows checked anything — they
  didn't run.

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
