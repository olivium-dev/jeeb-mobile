# Jeeb Mobile — Build-Out Orchestration Brief (CTO)

> Author: CTO/orchestrator. Date: 2026-06-18. This is the **shared context doc** every
> agent on this engagement reads first. It defines the mission, the ground truth, the
> non-negotiables, the team protocol, and the environment. Do not re-discover what is
> already written here.

---

## 1. Mission

Bring the **Flutter app (`jeeb-mobile`)** to **parity with the 62-screen design blueprint**,
running on an **Android emulator** (iOS sim acceptable fallback) against the **mock backend
only**, with every screen+navigation change **tested via Maestro** and **signed off** against
explicit acceptance criteria.

We are NOT designing the product (that's done — see §2). We are **implementing** the already-
decided design into Flutter, wiring navigation, and updating the mock where contracts are missing.

## 2. The four repos (what each is)

| Repo | Role | Authority |
|------|------|-----------|
| `jeeb-mind-map/` | **Design source of truth.** 62-screen clickable prototype + product spec + decisions D1–D93. **100% complete.** | `web/blueprint.json` = canonical screen graph (62 screens, 188 edges). `docs/07_DECISIONS_LOG.md` + `flow-review/99_LEAD_SYNTHESIS.md §5` = authoritative decisions. |
| `jeeb-mobile/` | **The thing we are building.** Flutter app. 50 features, 61 screen files, ~30 routes. NOT at blueprint parity. | `lib/core/router/app_router.dart` = current nav. `docs/build-out/` = THIS engagement's artifacts. |
| `omds-flutter/` | **Design system.** OMDS tokens/components (`../omds-flutter/omds_library`, local path dep). | Use OMDS components/tokens only. See `jeeb-mobile/docs/omds-component-mapping.md`. |
| `jeeb-mock-backend/` | **Mock backend.** Express, 23 services, serves `:4010`, service-prefixed routes. | Backenders may change this to satisfy app contracts. `npm run dev`. |

## 3. Product model (one paragraph)

"Order anything" marketplace that feels like WhatsApp. Customer's **first chat message is the
request**; broadcast to nearby **Jeebers** (delivery people); each Jeeber replies with **one
private offer**; customer sees all offers, **accepts one**, thread becomes 1:1 chat; Jeeber
fulfils, **paid cash on delivery**. Platform earns **exactly 10%** of the accepted offer,
reserved from the Jeeber's **prepaid, fee-only wallet**. **No in-app payment** — Jeebers charge
their wallet at a physical store (D92/D93). Two roles, role-switched from Profile tab:
**client** tabs = Requests / Delivery / Profile; **jeeber** tabs = Dashboard / Earnings / Profile.

## 4. Ground truth (verified 2026-06-18 — do not re-verify)

- **Blueprint:** 62 screens (customer 15, auth 8, jeeber 22, shared 17), 188 edges. IDs + roles
  enumerated in `docs/build-out/10_BLUEPRINT_INVENTORY.md` (Phase 1 produces this).
- **Flutter app:** branch `integration/first-run-rc5-mac-book`. 50 features, 61 `*_screen/_page.dart`.
  Router defines: shell `/`, `/onboarding`, `/register`, `/lock`, order/chat/profile/location/
  settings/voice/request flows, offer-submission, tracking, OTP, rating, escalate, settlement,
  active-delivery. **Known stubs:** `/wallet` = "coming soon"; auth is a single `/register` screen
  (no distinct login/sign-up/verify/recover/set-password/social/biometric-unlock screens);
  notifications-list absent; dispute-status/account-status/reviews-list/jeeber-pending-offers/
  cancel-request-confirm not distinct routes.
- **Mock backend:** UP on `:4010`. 23 services mounted at service prefixes
  (`/auth-service`, `/wallet-service`, `/chat-service`, `/delivery-service`, `/offer-service`,
  `/feedback-service`, `/notification-service`, `/matching`, `/geolocation-service`,
  `/voice-transcription-service`, `/kyc-admin-service`, `/user-management`, …).
- **Mock wiring:** `lib/core/network/mock_gateway_client.dart` — set `useMockPrefixes = true` to
  target `:4010`. KNOWN GAP: auth paths send `/v1/auth/...` but the rewrite map keys on `/auth/...`
  (no `/v1`) → auth won't reach `:4010` until the map gains `/v1/auth/...` entries. **Backenders/
  foundation must fix this.** Non-auth surface rewrites fine.

## 5. Environment (verified working — do not re-discover)

- **Flutter** 3.44.2 / Dart 3.12.2 at `/Users/oudaykhaled/flutter/bin/flutter`.
- **Android:** `ANDROID_HOME=~/Library/Android/sdk`; system-images 29/31/34/35 present;
  **AVD `jeeb_test`** (android-34 google_apis arm64-v8a) already created. Boot with
  `emulator -avd jeeb_test`. Android **dev flavor** → appId `app.jeeb.mobile.dev`.
- **iOS:** iPhone 15 sim booted; plain `flutter run` (no iOS flavor schemes); appId `app.jeeb.mobile`.
- **Maestro** 1.40.3 at `~/.maestro/bin/maestro`. **REQUIRES** `export JAVA_HOME="$(/usr/libexec/java_home)"`
  (the shell default JAVA_HOME is broken). Run: `JAVA_HOME=$(/usr/libexec/java_home) maestro test -e APP_ID=app.jeeb.mobile.dev <flow>`.
- **🚨 MAESTRO BLOCKER (must fix in Phase 2 foundation):** the Flutter app does **not export its
  semantics tree** — `maestro hierarchy` returns empty nodes, so Maestro cannot see text/IDs.
  FIX: (a) force the semantics tree on at boot (`SemanticsBinding.instance.ensureSemantics()` in
  `main.dart`), and (b) every interactive/asserted widget carries a stable
  `Semantics(identifier: '<screen>_<element>')`. This is a **standing guardrail** for all screen work.
- **Android gradle dup:** `flutter create` dropped `*.gradle.kts` files that duplicate the
  committed Groovy `*.gradle` and break the Android build. Remove the untracked `.kts` ones
  (`android/build.gradle.kts`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`)
  before Android builds.

## 6. NON-NEGOTIABLE contracts (read before any code)

1. **Blueprint is the spec.** Every screen + edge we build must match `web/blueprint.json` and the
   per-screen contract in `web/src/screens/_data/<id>.json` (+ `web/SCREEN_CONTRACT.md`).
2. **Decisions are law.** `docs/07_DECISIONS_LOG.md` D1–D93 + `flow-review/99_LEAD_SYNTHESIS.md §5`.
   Cite by id. Never re-litigate. If a screen needs an undecided detail, raise it — don't invent.
3. **OMDS only.** Use `omds_library` components/tokens. No ad-hoc styling. See `omds-component-mapping.md`.
4. **Clean Architecture** per feature: `data/ domain/ presentation/`. State = flutter_bloc. Nav =
   GoRouter. DI = GetIt. Net = Dio. Match the existing patterns in `lib/features/*`.
5. **Mock only.** All data flows through the mock at `:4010`. No real backends. No secrets.
6. **Maestro-testable.** Every new/changed screen ships `Semantics(identifier:)` on its key
   widgets AND a Maestro flow under `.maestro/flows/` keyed by **identifier**, not visible text
   (i18n-safe). A change is not "done" until its Maestro flow passes on the emulator against mock.
7. **Navigation honesty.** A `goNamed/push` target must be a real registered route. Add the route
   centrally in `app_router.dart` first, then wire the call site.
8. **Don't break green.** `flutter analyze` clean + `flutter test` green before any handoff.

## 7. Team protocol (the data-mediated pipeline — proven on this project)

The lead plans + writes a work order; **sub-agents make every change**; a reviewer + QA verify;
a PO signs off. Agents communicate **through artifact files in `docs/build-out/`**, never by
guessing. Per work item, the loop is:

```
PO defines acceptance criteria  ─►  QA writes Maestro scenario (FIRST, red)
        │                                   │
        ▼                                   ▼
Designer supplies OMDS/Figma spec ─► Engineer implements (screen + nav + mock)
                                            │
                                            ▼
                              Reviewer reviews diff ─► QA runs Maestro on emulator (mock)
                                            │
                                            ▼
                                   PO signs off (criteria met) ─► DONE
```

**Isolation rule:** parallel engineers each own **one screen/feature**; only ONE agent edits a
shared file (`app_router.dart`, `injection_container.dart`, l10n, the mock server mount) per wave —
shared-file edits are batched centrally first, exactly like the prototype's `blueprint.json` pattern.

## 8. Model & cost policy

- **QA test authoring/execution: Sonnet** (per owner). **Everything else: Opus.**
- Maximize parallelism where it adds value (per-screen build, per-dimension review). Avoid
  redundant agents on the same small input.

## 9. Phase map (CTO-owned; tasks tracked in the task list)

- **Phase 1 — Gap analysis & backlog** → `10_BLUEPRINT_INVENTORY.md`, `11_FLUTTER_INVENTORY.md`,
  `12_MOCK_INVENTORY.md`, `20_GAP_MAP.md`, `21_NAV_PLAN.md`, `30_BACKLOG.md`.
- **Phase 2 — Guardrails + execution plan + test foundation** → `40_GUARDRAILS.md`,
  semantics+gradle+AVD+maestro harness green, `50_EXECUTION_PLAN.md` (waves).
- **Phase 3 — Parallel execution waves** → per-item branches/commits, Maestro flows, signoffs in
  `signoffs/<item>.md`.

## 10. Definition of Done (per work item)

Screen matches blueprint + decisions · OMDS components · nav wired both directions · wired to mock
(`:4010`) · `Semantics(identifier:)` present · Maestro flow passes on emulator · `flutter analyze`
clean · reviewer approved · PO signed off (criteria in `30_BACKLOG.md`).
