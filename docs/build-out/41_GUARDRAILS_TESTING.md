# 41 — Guardrails: Testing & Semantics (the STANDARD for every screen)

> **Phase 2 deliverable — Testing & Semantics guardrail (Senior Principal Engineer).**
> This is the **standing, non-negotiable standard** for how every screen in `jeeb-mobile` is made
> Maestro-testable and how its flow is authored, keyed, and run. It is the operational expansion of
> **CTO brief §6.6** ("Maestro-testable: `Semantics(identifier:)` on key widgets + a flow keyed by
> identifier, not text") and **§10** (Definition of Done), and of **CTO-D rulings R-A/R-B**
> (`01_CTO_DECISIONS.md`). It does NOT re-litigate any product decision — those are fixed in
> `07_DECISIONS_LOG.md` / `99_LEAD_SYNTHESIS.md §5` (cited `D#`) and `01_CTO_DECISIONS.md` (`CTO-D#`).
>
> **Companions:** the **identifier convention** lives in `30_BACKLOG.md §"Identifier convention"`
> (this doc is the authoritative *how*); per-screen ids are listed in each `JM-###` AC. The
> Foundation engineer is concurrently (a) enabling the semantics tree at boot in `lib/main.dart`
> and (b) adding ids to onboarding as the *proof*; **this doc is the standard those — and all 58
> JM items — must follow.**
>
> **Why this matters (the original blocker):** the Flutter app historically did NOT export its
> semantics tree, so `maestro hierarchy` returned ~40 nodes with empty text/resource-id and **no
> id-based assertion was possible** (`.maestro/smoke.yaml`, CTO brief §5 "🚨 MAESTRO BLOCKER"). Two
> things fix it together: **(boot)** force the tree on for the process lifetime, and **(per-widget)**
> attach a stable `Semantics(identifier:)` to every interactive/asserted widget. Boot alone makes the
> tree visible but empty of ids; ids alone never publish. **Both are required.**

---

## 0. TL;DR (the five rules)

1. **Every interactive or asserted widget carries a stable `Semantics(identifier: '<screenId>_<element>')`.** No id → not testable → not Done (CTO brief §10).
2. **Assert on the `id`, never on visible text** (i18n / RTL safe — AP-5, `D` Arabic locale flips at runtime via `language-settings`/JM-059).
3. **Test-first per JM item:** QA writes the red Maestro flow keyed by the AC's ids **before** the engineer implements (CTO brief §7 pipeline). Flow path: `.maestro/flows/jm-NNN-slug.yaml`.
4. **One run recipe, always:** `JAVA_HOME=$(/usr/libexec/java_home)`, AVD `jeeb_test`, dev flavor `app.jeeb.mobile.dev`, mock on host `:4010` via emulator alias `10.0.2.2`, `maestro test -e APP_ID=app.jeeb.mobile.dev <flow>`.
5. **Flows accumulate; never delete a green flow.** Each wave gains a suite that must stay green (regression gate, §6).

---

## 1. The Semantics identifier rule (the contract)

### 1.1 The id grammar (canonical)

Every id is `lower_snake_case`, ASCII, stable across i18n/RTL/redesign, and **screen-scoped** so it
is globally unique. Source of truth for the *shape* is `30_BACKLOG.md §"Identifier convention"`;
this doc fixes the *full grammar*:

| widget kind | id form | example |
|---|---|---|
| **Element on a screen** (field, button, row, card, container) | `<screenId>_<element>` | `login_email_field`, `login_continue_cta`, `offer_composer_send_cta`, `wallet_available_balance` |
| **Shell tab target** (bottom-nav item) | `shell_tab_<id>` | `shell_tab_requests`, `shell_tab_delivery`, `shell_tab_profile`, `shell_tab_dashboard`, `shell_tab_earnings` |
| **Bottom sheet / modal-dialog element** | `<screenId>_sheet_<element>` | `offer_accept_sheet`, `offer_accept_sheet_confirm_cta`, `cancel_request_sheet_keep_cta`, `insufficient_balance_sheet_topup_cta` |
| **Per-item row in a list** (dynamic) | `<screenId>_<element>_<dataId>` | `offer_card_<offerId>`, `notif_row_<notifId>`, `wallet_activity_row_<txnId>`, `pending_offer_<offerId>_withdraw_cta` |
| **Screen root** (the host container, for "did not navigate away" re-asserts) | `<screenId>_root` | `waiting_no_coverage_root`, `wallet_hub_root` |

- **`<screenId>`** = the blueprint screen id, normalized to snake_case (`offer-composer` → `offer_composer`, `wallet-hub` → `wallet_hub`, `delivered-receipt-confirm` → `delivered_receipt`). Use the `name` column of `21_NAV_PLAN.md §A` when the blueprint id and route name differ.
- **`<element>`** = role suffix. Use a small controlled vocabulary so flows are predictable:
  `_field` (text input) · `_cta` / `_button` (primary action) · `_link` (secondary/navigation text) ·
  `_toggle` · `_radio` · `_row` · `_card` · `_chip` · `_badge` · `_sheet` · `_input` (OTP/code) ·
  `_dropdown` · `_bell` (notification entry) · `_avatar` · `_stepper` · `_root`.
- **Dynamic rows** interpolate the backend id, never the index: `offer_card_${offer.id}` (matches `JM-028`), `notif_row_${n.id}` (`JM-057`). QA asserts the seeded fixture id (e.g. `pending_requests_item_pen-1` in flow `13`).
- **Tabs are NOT routes** (CTO brief §4, `21_NAV_PLAN.md §A "Tab disambiguation"`). They are reached by tapping `shell_tab_<id>`, never by a path. The five tab bodies (`customer-orders-home`, `my-orders`, `customer-profile`, `delivery-requests`, `jeeber-requests-home`, `earnings-fees-dashboard`) get their own per-screen ids for their *contents*, but the navigation target is the tab id.

> **LEGACY / deprecated:** some shipped flows use a **leading-underscore** form (`_splash_screen`,
> `_request_empty_state_root`, `_register_hero`). That predates this convention. **Do NOT add new
> leading-underscore ids.** New work uses bare `<screenId>_<element>`. Existing underscore ids are
> grandfathered until their screen is reworked under a JM item, at which point they migrate to the
> canonical form (and the flow updates with them). The backlog ACs already use the canonical form
> (`login_email_field`, `offer_composer_send_cta`, `wallet_hub_topup_cta`, `kyc_gate_start_cta`).

### 1.2 How to add it in Flutter — WITHOUT breaking layout

`Semantics` is a **zero-layout-impact** annotation widget: it wraps a child and writes to the
accessibility tree, it does **not** add padding, constraints, or a render box of its own. Three
rules keep it invisible to layout and visible to Maestro:

**Rule A — wrap, set `identifier:`, and (almost always) `container: true`.** `container: true`
forces this node to be its **own** semantics node so Maestro sees a distinct resource-id, instead
of being merged into a parent/sibling node. This is exactly the bug `30-walkthrough-login-home.yaml`
documents (the walkthrough title+description **merged into one node**, so they had to target the
standalone button). Default to `container: true` on every asserted element.

```dart
// Interactive button (tappable target). The Semantics wraps the gesture widget
// so the tap target and the id are the same node.
Semantics(
  identifier: 'login_continue_cta',
  button: true,
  container: true,
  child: OmdsPrimaryButton(
    onPressed: _onContinue,
    label: l10n.continueLabel,   // visible text stays localized; the ID does not
  ),
)
```

```dart
// Text field. Put the id on the field, not on a Padding/Container around it.
Semantics(
  identifier: 'login_email_field',
  textField: true,
  container: true,
  child: OmdsTextField(controller: _email, hintText: l10n.emailHint),
)
```

```dart
// Screen root container — lets a flow re-assert "still on this screen" (AP-9 honesty).
Semantics(
  identifier: 'wallet_hub_root',
  container: true,
  child: Scaffold(/* … */),
)
```

**Rule B — `excludeSemantics: false` (the default). Never strip child semantics you still need.**
If a parent uses `Semantics(... container: true, child: ...)` to give itself an id, the children
keep their own nodes only if they are *also* containers. For a row that is itself the tap target
(e.g. a profile row), put the id on the row's `InkWell`/`GestureDetector` and use `container: true`;
do not also wrap inner Text in containers unless the flow asserts that Text by id.

**Rule C — prefer the OMDS/widget's built-in `semanticsId`/`identifier` param when it exists.** Some
project widgets already take an id (e.g. `chat_composer_icon_button.dart` takes `semanticsId`, see
`offer_card_bubble.dart` interpolating `chat_detail_accept_${offerId}`). Pass the id through that
param rather than double-wrapping — double-wrapping risks node-merge ambiguity. Where OMDS lacks the
param, wrap with `Semantics` per Rule A (CTO-D R-D: build/extend local widgets, don't block on the DS).

**What NOT to do (layout/■ correctness):**
- ❌ Do **not** wrap with `Container`/`Padding`/`SizedBox` "to attach an id" — that *does* change
  layout. `Semantics` is the only correct wrapper.
- ❌ Do **not** put the id on a parent that has multiple interactive children (the tap will be
  ambiguous and may merge). One id = one logical element.
- ❌ Do **not** use `MergeSemantics` around an element a flow must target individually — it does the
  opposite of `container: true` and is what broke the walkthrough copy in flow `30`.
- ❌ Do **not** set `label:`/`hint:` to a hardcoded English string as a stand-in for the id.
  Labels are localized content; **ids are the stable contract** (AP-5).

### 1.3 The boot half (already landed; do not duplicate)

`lib/main.dart` already holds the handle for the process lifetime:

```dart
SemanticsBinding.instance.ensureSemantics(); // Flutter 3.44.2 — retained, never disposed
```

This is the Foundation engineer's boot fix (CTO brief §5). **Do not add it again** in feature code,
tests, or per-screen `initState`. Per-screen work only ever adds `Semantics(identifier:)` widgets.

### 1.4 Verify the id is exported BEFORE writing the flow (mandatory)

An id that is set in code but merged/hidden in the tree is worse than none — the flow will mystery-fail.
QA confirms every id is a real Android `resource-id` **before** keying a flow on it:

```bash
export JAVA_HOME="$(/usr/libexec/java_home)"          # shell default is broken (CTO brief §5)
# App must be running on jeeb_test (see §3). Then dump the live tree:
~/.maestro/bin/maestro hierarchy | grep -iE 'resource-id|identifier'
```

Every id named in the JM AC must appear. If it does not: it merged (add `container: true`), or it is
off-screen (scroll first), or the widget did not build (wrong state). This is the same evidence step
flows `01`/`08`/`13` cite ("independently confirmed by QA via `maestro hierarchy` … BEFORE this flow
was written — not assumed").

---

## 2. Test-first pipeline (per JM item)

The CTO pipeline (brief §7) puts QA's red flow **before** implementation. Concretely, per `JM-###`:

```
1. PO   : AC is written Given/When/Then in 30_BACKLOG.md, naming every id (e.g. JM-007 names
          login_email_field, login_password_field, login_continue_cta, …).
2. QA   : authors .maestro/flows/jm-NNN-slug.yaml from those ids — RED (screen not built yet,
          or ids not present). The flow IS the executable acceptance criteria. (Model: Sonnet, R-E.)
3. ENG  : implements the screen + nav + mock wiring, adding Semantics(identifier:) per §1 until the
          QA flow's ids all appear in `maestro hierarchy` (§1.4). (Model: Opus, R-E.)
4. QA   : runs the flow on jeeb_test against mock (§3) — must go GREEN. (Sonnet.)
5. REVR : reviews diff (ids present, no text assertions, nav honest per §C of NAV_PLAN). (Opus.)
6. PO   : signs off → signoffs/jm-NNN.md. DONE = CTO brief §10.
```

- **One flow per JM item**, named for the item: `jm-007-login.yaml`, `jm-053-wallet-hub.yaml`,
  `jm-029-offer-accept-confirm.yaml`. `NNN` is the zero-padded JM number; `slug` is the blueprint
  screen id. This makes the flow file greppable from the backlog and vice-versa.
- The flow **may be red against an unwired backend leg** — that is honest (AP-9). Where the dev
  build can't satisfy a downstream nav (e.g. flow `08`'s `onCreateRequest` no-op), assert the tap is
  *accepted and does not crash* and re-assert the screen root, rather than fabricating a destination.
- The flow **keys only on ids from the AC**. If implementation needs an id the AC didn't name, the
  engineer adds it AND QA adds the assertion — but the AC is the source of truth; surprises get
  recorded inline (CTO-D R-F).
- **Naming reconciliation:** the older numbered flows (`01-splash.yaml` … `30-walkthrough-login-home.yaml`)
  are the *pre-build-out* parity suite and keep their names. **All build-out work uses the
  `jm-NNN-slug.yaml` scheme** so a flow maps 1:1 to a backlog item and a wave.

---

## 3. The exact run recipe (copy-pasteable)

> Surface: **Android emulator `jeeb_test`** + **dev flavor `app.jeeb.mobile.dev`** + **mock only**
> (CTO-D R-A). iOS sim is the fallback (CTO brief §5) — same flow files, appId `app.jeeb.mobile`,
> mock at `localhost:4010` (no `10.0.2.2` remap). The recipe below is the Android primary path.

### 3.1 One-time / per-shell environment

```bash
# JAVA_HOME: the shell default is broken; Maestro REQUIRES this (CTO brief §5 / CTO-D R-B).
export JAVA_HOME="$(/usr/libexec/java_home)"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$HOME/.maestro/bin:$PATH"
```

### 3.2 Boot the mock (host) — service-prefixed `:4010`

```bash
# In jeeb-mock-backend/ — serves the 23 services on :4010 (CTO brief §2/§4).
( cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mock-backend && npm run dev ) &
# Sanity: a service-prefixed route answers.
curl -s http://localhost:4010/user-management/users/me >/dev/null && echo "mock :4010 up"
```

### 3.3 Boot the AVD `jeeb_test`

```bash
emulator -avd jeeb_test &                  # android-34 google_apis arm64-v8a (pre-created, §5)
adb wait-for-device
# Block until the framework is fully up (NO foreground `sleep` — poll instead):
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do :; done
adb devices                                # note the emulator-XXXX id (e.g. emulator-5554)
```

### 3.4 Build + install the dev flavor against the mock via the emulator host alias

The emulator reaches a service on the **host machine** through the alias **`10.0.2.2`** (the
emulator's loopback-to-host mapping; `localhost` inside the emulator is the emulator itself). The
dev build reads its base URL from `--dart-define=JEEB_MOCK_BASE_URL` and targets the `:4010`
service-prefixed mock with `useMockPrefixes = true` (`lib/core/network/mock_gateway_client.dart`).

```bash
# Remove the stray Kotlin-DSL gradle files that break the Android build (CTO brief §5).
cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile
rm -f android/build.gradle.kts android/settings.gradle.kts android/app/build.gradle.kts

# Build + install the dev flavor (appId app.jeeb.mobile.dev) pointed at the host mock via 10.0.2.2.
/Users/oudaykhaled/flutter/bin/flutter run \
  --flavor dev \
  --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010 \
  -d emulator-5554
# (or `flutter build apk --flavor dev --dart-define=… && adb install -r build/app/outputs/.../app-dev.apk`)
```

> **Why `10.0.2.2:4010`:** host `:4010` (where `npm run dev` listens) is reachable from inside the
> AVD only as `http://10.0.2.2:4010`. With `useMockPrefixes=true` the client routes to the
> service-prefixed mock; with the default `:3055` it would target the Mockoon gateway shim instead
> (`mock_gateway_client.dart` lines 18–30). For build-out work we target `:4010` (CTO brief §4).
> Dev-seam knobs (`jeeb.route`, `jeeb.home_tab`, `jeeb.hold_splash`, `jeeb.locale`) are passed as
> Android intent extras via `launchApp.arguments` in the flow (see flows `01`/`13`), **not** dart-defines.

### 3.5 Run the flow

```bash
export JAVA_HOME="$(/usr/libexec/java_home)"
maestro --device emulator-5554 test \
  -e APP_ID=app.jeeb.mobile.dev \
  --format JUNIT --output evidence/maestro/jm-007-junit.xml \
  .maestro/flows/jm-007-login.yaml
```

One-liner (the canonical invocation, CTO brief §5 / smoke header):

```bash
JAVA_HOME=$(/usr/libexec/java_home) maestro test -e APP_ID=app.jeeb.mobile.dev .maestro/flows/jm-007-login.yaml
```

### 3.6 Maestro version note (2.x)

The flows run on Maestro 2.x (`~/.maestro/bin/maestro`; smoke header notes 1.40.3, current flows
target **2.0.5** — check `maestro --version`). In 2.x:
- `assertVisible` does **NOT** accept an inline `timeout:` (1.x only). Use `extendedWaitUntil` for any
  timed wait (it waits up to `timeout` **and** asserts). Bare `assertVisible` is only for re-confirming
  an element already proven present.
- Never use a fixed `sleep` for timing (AP-1) — use `extendedWaitUntil` (waits) /
  `waitForAnimationToEnd` (settles before a screenshot, AP-7).
- Never tap by coordinate (AP-1) or by localized label (AP-5) — tap by `id`.

---

## 4. Assert on ids, never on visible text (i18n / RTL)

The app is bilingual; Arabic flips the whole UI to **RTL at runtime** (`language-settings` / JM-059,
locale via `jeeb.locale=ar` intent extra — flow `01` exercises exactly this). Therefore:

- **DO:** `extendedWaitUntil: { visible: { id: "login_continue_cta" }, timeout: 15000 }`
- **DON'T:** `tapOn: "Continue"` / `assertVisible: "متابعة"` — text varies by locale and copy edits.
- **DON'T** assert merged slide copy or any multi-line content node — it merges unpredictably
  (the walkthrough lesson, flow `30`). Target the discrete element by id.
- **Screenshots are evidence, not assertions.** `takeScreenshot` after `waitForAnimationToEnd`
  documents the settled frame; the *pass/fail* always comes from an id assertion.

This is CTO brief §6.6, CTO-D R-B, and AP-5, restated as an inviolable rule: **a flow that
references any visible string for control flow or assertion is rejected in review (§2 step 5).**

---

## 5. Regression: how flows accumulate + per-wave suites

Flows are **append-only**. A passing flow is a permanent regression gate; it is never deleted and is
only edited when its screen is reworked under a new JM item (and then the ids migrate per §1.1).

### 5.1 Per-wave suites (Maestro tags)

Each flow declares its wave (and JM id) via Maestro `tags` in the flow header, so a whole wave runs
as one suite and accumulates as waves land:

```yaml
appId: ${APP_ID}
tags:
  - jm-007
  - w0
  - auth
```

Run a wave's full suite (all flows tagged for that wave) with `--include-tags`:

```bash
export JAVA_HOME="$(/usr/libexec/java_home)"
# All Wave 0 flows, against jeeb_test + mock:
maestro --device emulator-5554 test \
  -e APP_ID=app.jeeb.mobile.dev \
  --include-tags w0 \
  --format JUNIT --output evidence/maestro/w0-junit.xml \
  .maestro/flows/
```

Wave tags mirror `30_BACKLOG.md §"Wave summary"`: `w0` (auth+gates, JM-001..010), `w1` (core
customer, JM-023..035), `w2` (jeeber onboarding/offering, JM-036..048), `w2_5` (wallet hub/charge,
JM-053/054), `w3` (wallet ledger/earnings, JM-051/052/055/056), `w4` (shared, JM-057..068).

### 5.2 The accumulating gates

- **Per item:** `jm-NNN-slug.yaml` green is required for that item's sign-off (§2/CTO brief §10).
- **Per wave (entry gate to the next wave):** the **entire prior-wave suite** (`--include-tags wN`)
  must be green before the next wave's parallel build starts. A new screen that reds an earlier
  wave's flow is a regression — fix before merge, do not retag/skip.
- **Full regression (release gate):** `maestro test .maestro/flows/` (no tag filter) runs every flow.
  The legacy numbered parity flows (`01`..`30`) stay in this set; build-out adds `jm-*` flows over them.
- **CI/local discipline:** suites run on `jeeb_test` against the mock, never a real backend (CTO-D
  R-A / brief §6.5). Evidence (`--format JUNIT --output evidence/maestro/…`) is attached to the
  sign-off, matching what flows `08`/`13`/`01` already emit.

---

## 6. Template flow (copy this for every new JM item)

Copy to `.maestro/flows/jm-NNN-slug.yaml`, replace `NNN`/`slug`/`<screenId>`/element ids with the
ones named in the JM AC, set the `tags`, and delete the guidance comments you don't need. This
template encodes every rule above: id-only assertions (§4), `extendedWaitUntil`/`waitForAnimationToEnd`
not sleeps (§3.6/AP-1/AP-7), root re-assert for nav honesty (AP-9), wave/JM tags (§5).

```yaml
# Jeeb mobile — JM-NNN <Screen Name> (blueprint id: <screen-id>).
#
# WHAT THIS PROVES (acceptance criteria from 30_BACKLOG.md JM-NNN):
#   Given <precondition>, When <action by id>, Then <result by id>.
#   Targeted BY SEMANTIC ID only (never localized text — §4/AP-5; never coordinates — AP-1).
#   IDs (confirmed in `maestro hierarchy` BEFORE writing this flow — §1.4):
#     <screenId>_root          — screen host container (re-assert nav honesty)
#     <screenId>_<element>     — <what it is>
#     ...
#
# BACKEND: mock only on :4010 via emulator alias 10.0.2.2 (§3). No real backend (CTO-D R-A).
#
# RUN (§3.5):
#   JAVA_HOME=$(/usr/libexec/java_home) maestro --device emulator-5554 test \
#     -e APP_ID=app.jeeb.mobile.dev \
#     --format JUNIT --output evidence/maestro/jm-NNN-junit.xml \
#     .maestro/flows/jm-NNN-slug.yaml
appId: ${APP_ID}
tags:
  - jm-NNN          # backlog item
  - wN              # wave (w0/w1/w2/w2_5/w3/w4) — §5.1
  - <area>          # auth | customer | jeeber | wallet | shared
---
# Fresh state so there is no auth/state bleed between runs (AP-4). If the screen
# is reached via a dev-seam route, pass it as an intent extra instead of clearState
# (see flow 13: arguments: { jeeb.route: "/", jeeb.home_tab: "pending" }).
- launchApp:
    clearState: true

# Screen host — waited+asserted by id. extendedWaitUntil (NOT a fixed sleep — AP-1)
# absorbs cold-start + router-redirect variance AND asserts (AP-3 headroom).
- extendedWaitUntil:
    visible:
      id: "<screenId>_root"
    timeout: 25000

# Settle the entrance transition before the evidence frame (AP-7, not a sleep).
- waitForAnimationToEnd:
    timeout: 5000
- takeScreenshot: jm-NNN_<screenId>_rendered

# Assert each key element from the AC, BY ID (i18n-safe — §4).
- extendedWaitUntil:
    visible:
      id: "<screenId>_<element_a>"
    timeout: 10000
- assertVisible:
    id: "<screenId>_<element_b>"

# ── PRIMARY INTERACTION (the screen's main user action, from the AC) ──────────
# Tap by id (NOT coordinate — AP-1; NOT label — AP-5). If the downstream nav leg
# is unwired on the dev build, assert the tap is accepted + the screen survives
# (AP-9: never fabricate a destination the backend can't satisfy).
- tapOn:
    id: "<screenId>_<primary_cta>"
- waitForAnimationToEnd:
    timeout: 5000

# THEN: assert the result. Either the destination screen's root id is visible
# (nav wired)…
- extendedWaitUntil:
    visible:
      id: "<destinationScreenId>_root"
    timeout: 15000
# …OR (if the leg is unwired on dev) re-confirm THIS screen's root still hosts
# (no crash, no silent navigation). Use ONE of these two THEN blocks, not both.
# - assertVisible:
#     id: "<screenId>_root"
```

### 6.1 Worked example — `jm-029-offer-accept-confirm.yaml` (a sheet; JM-029)

Shows the **sheet** id form (`<screenId>_sheet_<element>`) and a real wave/area tagging.

```yaml
# Jeeb mobile — JM-029 Accept Offer Confirmation (blueprint id: offer-accept-confirm; a bottom sheet).
# AC (30_BACKLOG.md JM-029): Given an offer chosen, When the accept sheet shows, Then
#   offer_accept_sheet displays the confirm copy; offer_accept_sheet_confirm_cta captures the fee,
#   closes losers, routes to order-chat; offer_accept_sheet_cancel_cta → back to offer-review-list.
# IDs (confirmed via `maestro hierarchy` before authoring — §1.4):
#   offer_review_root                  — host list the sheet is raised from
#   offer_card_<offerId>_accept_cta    — opens the sheet (dynamic row id — §1.1)
#   offer_accept_sheet                 — the sheet container
#   offer_accept_sheet_confirm_cta     — confirm
#   offer_accept_sheet_cancel_cta      — cancel
#   order_chat_root                    — destination on confirm
appId: ${APP_ID}
tags:
  - jm-029
  - w1
  - customer
---
- launchApp:
    arguments:
      jeeb.route: "/requests/req-1/offers"   # dev-seam deep-link to offer-review-list
- extendedWaitUntil:
    visible:
      id: "offer_review_root"
    timeout: 25000
- waitForAnimationToEnd:
    timeout: 5000

# Open the accept sheet from a seeded offer row (dynamic id — fixture offerId off-1).
- tapOn:
    id: "offer_card_off-1_accept_cta"
- extendedWaitUntil:
    visible:
      id: "offer_accept_sheet"
    timeout: 10000
- waitForAnimationToEnd:
    timeout: 5000
- takeScreenshot: jm-029_offer_accept_sheet

# Cancel path keeps us on the list (assert by id, never the "Cancel" label — §4).
- assertVisible:
    id: "offer_accept_sheet_cancel_cta"
- tapOn:
    id: "offer_accept_sheet_cancel_cta"
- extendedWaitUntil:
    visible:
      id: "offer_review_root"
    timeout: 8000

# Re-open and confirm → captures fee (D11/D71), routes to order-chat (JM-029 AC).
- tapOn:
    id: "offer_card_off-1_accept_cta"
- extendedWaitUntil:
    visible:
      id: "offer_accept_sheet_confirm_cta"
    timeout: 8000
- tapOn:
    id: "offer_accept_sheet_confirm_cta"
- waitForAnimationToEnd:
    timeout: 5000
# Wired leg → destination root. (If accept is unwired on dev, swap for an
# assertVisible on offer_accept_sheet's dismissal + offer_review_root — AP-9.)
- extendedWaitUntil:
    visible:
      id: "order_chat_root"
    timeout: 15000
```

---

## 7. Review checklist (reviewer gate, §2 step 5)

A change is **rejected** if any of the following is true. (Reviewer = Opus, R-E.)

- [ ] An interactive or asserted widget has **no** `Semantics(identifier:)` (CTO brief §10).
- [ ] An id does **not** match the grammar `<screenId>_<element>` / `shell_tab_<id>` / `<screenId>_sheet_<element>` (§1.1), or a **new** id uses the deprecated leading-underscore form.
- [ ] The flow **asserts or controls on visible text / a localized label / a coordinate** (§4, AP-1/AP-5).
- [ ] The flow uses a **fixed `sleep`** for timing instead of `extendedWaitUntil`/`waitForAnimationToEnd` (AP-1/AP-7).
- [ ] An id was set but **never verified in `maestro hierarchy`** (merged/hidden — §1.4).
- [ ] The flow **fabricates a destination** the dev build can't satisfy instead of asserting tap-accepted + root-survives (AP-9).
- [ ] A `goNamed/push` target is **not a registered route** (`21_NAV_PLAN.md §C`; CTO brief §6.7).
- [ ] The flow is **not** named `jm-NNN-slug.yaml` or is **missing** its `jm-NNN`/`wN` tags (§2/§5.1).
- [ ] `Semantics` was attached via a layout widget (`Container`/`Padding`) instead of the `Semantics` annotation, or via `MergeSemantics` around a must-target element (§1.2).
- [ ] `flutter analyze` not clean / `flutter test` not green (CTO brief §8).

---

## 8. Cross-references

- CTO brief §5 (env + the MAESTRO BLOCKER), §6.6 (Maestro-testable), §7 (pipeline), §10 (DoD): `00_CTO_BRIEF.md`.
- CTO-D **R-A** (Android/dev-flavor/mock surface), **R-B** (JAVA_HOME + id-not-text), **R-E** (model policy), **R-F** (no human gate): `01_CTO_DECISIONS.md`.
- Identifier convention (the short form this doc expands): `30_BACKLOG.md §"Identifier convention"`; per-screen ids in each `JM-###` AC.
- Routes/edges/tab-vs-route: `21_NAV_PLAN.md` (§A reconciliation, §C edges, §D shared-file batching).
- Boot fix already in place: `lib/main.dart` (`ensureSemantics()`); proof-of-pattern ids: `lib/app/branded_splash.dart`, onboarding (Foundation engineer, in flight).
- Reference flows for the patterns cited: `.maestro/flows/01-splash.yaml` (id-only, locale=ar, seam), `08-request-empty-state.yaml` (id assertions + no-op CTA honesty), `13-request-pending-requests.yaml` (dev-seam route + dynamic row id), `30-walkthrough-login-home.yaml` (the node-merge lesson → why `container: true`). `.maestro/smoke.yaml` (the original blocker write-up).
