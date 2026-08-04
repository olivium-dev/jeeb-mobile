# Dev Tool + test accounts — 2026-08-04

## Why the Dev Tool "wasn't working"

It was **compiled out**, not broken. Two independent gates must both be on:

1. `kDevToolEnabled` — `bool.fromEnvironment('JEEB_DEVTOOL_ENABLED', defaultValue: false)`
   (`lib/core/dev_flags.dart:4`). **Defaults to FALSE.**
2. The `DevToolLauncher` activity-alias (`AndroidManifest.xml:205`), gated by
   `@bool/jeeb_devtool_enabled` — true on dev/staging, false on production.

The APK from the earlier smoke test was built **without the dart-define**, so gate 1 was off
and `main.dart` fell through to `JeebBootstrap` regardless of which icon you tapped.
`flutter analyze` on `lib/devtool` is clean (0 errors) — nothing was wrong with the code.

## The build command that works

```
flutter build apk --debug --flavor dev --dart-define=JEEB_DEVTOOL_ENABLED=true
```

`--flavor dev` is **required**: a flavourless `flutter build apk` assembles all three flavours and
`staging` has no matching client in `android/app/google-services.json`, so the build fails (Q-048).

Installed and verified on both attached devices; the Dev Tool opens from its **own second launcher
icon** ("Jeeber Dev Tool"), same process/DI/session as the app.

| device | model | launch | screenshot |
|---|---|---|---|
| RFCX306JSRT | SM-S921B (Galaxy S24) | ok, 1507 ms | `devtool/devtool-SM-S921B.png` |
| RZCT505K7WF | SM-A336B (Galaxy A33) | ok, 4422 ms | `devtool/devtool-SM-A336B.png` |

Seven tools render: Gesture Logging · Super Login · Screen Catalog · Actions · Server URL ·
Clear Local Data · Scenario Users.

## Accounts (gateway 192.168.2.39:10090, `/health/ready` 200)

**Use Super Login** — it mints a token from `userId` via `/auth/tokens`. No OTP, no phone.
**Neither user endpoint exposes phone numbers**, so real-OTP login cannot be driven from this data.

### Jeebers — 50 accounts have `driver` in `roles[]`
**Every one is dual-role (customer+driver); there is no driver-only account.**
Note `role` (flat) reports 46 and is unreliable — several `*Jeeber*` accounts show `role=customer`.
**Trust `roles[]`, not `role`.**

| name | userId |
|---|---|
| Karim Driver | `d1000000-0000-4000-8000-000000000002` |
| TestJeeber | `c312aff9-a8da-4ede-9543-f35fbbbf6939` |
| Jeeber171 | `a84dcf05-8d17-4182-b5cb-9cab49269a9f` |
| SprintJeeber | `959b0dc3-fcd5-407c-a43f-741a99e2a11b` |
| RamiJeeber | `cd856247-a67c-4429-b827-3e9bd4188794` |
| E2ERerunJeeber | `561b3046-a7f9-4e25-bf4b-f11c215449c2` |
| Rev2Jeeber004 / 006 | `c582420b-…` / `1a02ae1d-…` |

### Customers
| name | userId |
|---|---|
| Nour Demo | `d1000000-0000-4000-8000-000000000001` |
| NourCustomer | `29ba753c-9e23-4e92-a079-bcf6bc729207` |
| TestCustomer | `d240a153-65ed-40cd-a4db-5a3953883d12` |
| SprintCustomer | `e2a73626-2276-437c-8de4-d8705ee898a1` |
| Sara | `0071bbfc-4f0e-4bdc-8ef2-a6f7b177bc15` |

### For a real-OTP run
The only known phone-login pair is the recorded jeeber **+9613000077 / OTP 1234**.

## Honest limits
- **"Latest" could not be established for the NAMED accounts.** `/dev/data/users` (the only
  endpoint carrying `createdAt`) returns **50 of 339** and none of the named ones are in it. The
  newest rows by `createdAt` are all synthetic `jeeb-*` handles from 2026-06-23.
- 339 in the super-login roster vs 50 in the dev-data list — the two endpoints disagree on
  population; the roster is the fuller one.
