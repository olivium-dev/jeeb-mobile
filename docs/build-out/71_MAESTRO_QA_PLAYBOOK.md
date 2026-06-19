# 71 — Maestro QA Playbook: run scenarios without hanging (DO / DON'T)

> For QA agents running Maestro against the Jeeb Flutter app on the Android emulator + mock.
> Every rule below was learned the hard way during the W0–W4 build-out (it cost real hours).
> Read this before authoring or running flows. Companion: `41_GUARDRAILS_TESTING.md` (full recipe),
> `62_SEAM_HARNESS.md` (seam contract), `00_CTO_BRIEF.md §5` (env).

---

## 0. The run recipe (copy-paste)
```bash
export JAVA_HOME="$(/usr/libexec/java_home)"          # shell default JAVA_HOME is BROKEN
cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile
# fresh build + CLEAN install (see DON'T #1):
rm -f build/app/outputs/flutter-apk/app-dev-debug.apk
/Users/oudaykhaled/flutter/bin/flutter build apk --debug --flavor dev \
  --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010
ls -l build/app/outputs/flutter-apk/app-dev-debug.apk   # CONFIRM timestamp == now
adb uninstall app.jeeb.mobile.dev ; adb install -r build/app/outputs/flutter-apk/app-dev-debug.apk
# run ONE flow, with a hard timeout, explicit device:
timeout 180 ~/.maestro/bin/maestro --device emulator-5554 test \
  -e APP_ID=app.jeeb.mobile.dev --format JUNIT .maestro/flows/<flow>.yaml
```

---

## ✅ DO

- **DO `export JAVA_HOME="$(/usr/libexec/java_home)"`** before any maestro command — the shell default points at an invalid dir and maestro silently no-ops.
- **DO pass `--device emulator-5554` explicitly.** An iPhone simulator is often also attached; without `--device`, `maestro` (esp. `hierarchy`) hangs forever on an interactive device picker.
- **DO clean-install a freshly-built APK** (`rm` the apk → build → `ls -l` to confirm a *now* timestamp → `adb uninstall` → `adb install`). Confirm the timestamp.
- **DO wrap every run in `timeout 180`** so a hung flow is killed and the suite continues, instead of blocking the whole pass.
- **DO run-once-and-report.** Run each flow exactly once; record PASS/FAIL + the failing step + a category (APP_DEFECT / PRECONDITION / MOCK_GAP / FLOW_BUG).
- **DO append each flow's result to the results doc IMMEDIATELY** (one row as it finishes). A stall or API crash then still leaves a complete partial artifact.
- **DO seed start-state via dev-seam intent-extras** (`jeeb.seam.session`, `jeeb.seam.journey`, `jeeb.seam.kyc_status`, `jeeb.seam.wallet_state`) so a flow starts mid-journey instead of driving the whole funnel each time. Contract: `62_SEAM_HARNESS.md`.
- **DO assert by `Semantics(identifier:)` only**, via `extendedWaitUntil: visible: id: <id>` with a generous cold-start timeout (**25–30 s**, up to **45 s** for the Nth consecutive cold `clearState` launch).
- **DO cold-boot the emulator before a long suite**, and **split big suites** (≤~10 flows per fresh boot). The single AVD degrades after ~15 back-to-back flows.
- **DO reset the mock host-side BEFORE the run** (`curl -X POST http://localhost:4010/__mock/reset`), not from inside the flow.
- **DO kill stale daemons if cold boot balloons >90 s**: `pkill -f GradleDaemon; pkill -f KotlinCompileDaemon; pkill -f frontend_server` — accumulated build daemons starve host RAM (boot drops back to ~31 s).
- **DO type multi-cell OTP per cell** (`verify_code_input_0` … `_5`, one digit each), not a single `inputText` on the container.

## ❌ DON'T

- **DON'T trust an incremental build or a pre-existing APK.** A **STALE APK** produced *entire false-fail runs* (0/18, 0/20) more than once — the source was already fixed but the installed binary was old. Always rebuild + confirm timestamp + uninstall/install.
- **DON'T assume a ~40 s first frame is a flake.** `Firebase.initializeApp()` hangs ~40 s with no `google-services.json` (every dev/QA build). It's wrapped in a 5 s timeout in `lib/app/bootstrap.dart` — if you reintroduce a blocking call on the boot path, every flow times out.
- **DON'T block boot on network.** Dev-seam mock-seed POSTs must be fire-and-forget (`awaitMockSeed:false`); awaiting them past the assertion window strands the splash.
- **DON'T inline "fix-and-re-run" during a QA pass.** It makes the agent thrash, never finish the suite, and never write results. Run-and-report; hand fixes to an engineer (Opus), then re-run as a separate pass.
- **DON'T assert on visible text.** The app is bilingual EN/AR (RTL) — text assertions break. IDs only.
- **DON'T assert a cross-wave / not-yet-built target screen.** Use **AP-9**: assert the CTA tap is accepted + the current screen root survives, until that wave ships.
- **DON'T rely on in-flow `evalScript` HTTP to the mock** (`http.post('http://10.0.2.2:4010/__mock/reset')`). Host `evalScript` can't reach the emulator-host alias on this runner — it silently fails. Reset host-side before the run.
- **DON'T depend on fixed mock fixture IDs with hard-coded past timestamps** — offer/accept windows expire and disable CTAs. Seed timestamps relative to *now*.
- **DON'T route-pin a deep authed screen across a logged-out redirect** (`jeeb.route=/sign-up` after a logged-out state). The pin won't survive the first-run/session redirect — drive from the real entry (login → signup link) or use a session seam.
- **DON'T run the whole 57-flow suite in one agent/session.** One emulator = serial; a single agent over ~2 h saturates context and the AVD. Split across sequential batches of ~10, each writing incrementally.
- **DON'T re-key a stateful input on every change.** A multi-cell OTP keyed on `code.isEmpty` wiped all cells on the first digit → submit never enabled → flow "hangs" at the assertion. Use a stable key (e.g. a resend generation counter).

---

## Quick failure-triage map
| Symptom | Most likely cause | Fix |
|---|---|---|
| All flows fail at first assertion | stale APK **or** broken seam landing | rebuild+clean-install; check seam bootstrap lands on target screen |
| First frame ~38 s, then timeout | Firebase boot hang | confirm the 5 s timeout in `bootstrap.dart` is intact |
| `maestro hierarchy` returns empty / hangs | missing `--device`, or semantics not exported | add `--device emulator-5554`; confirm `SemanticsBinding.ensureSemantics()` in `main.dart` |
| Flow can't reach a logged-in screen | seam value not seeded / not landing | use `jeeb.seam.session=...`; verify against `seam_landing_test.dart` |
| Accept/offer CTA disabled | expired window from stale fixture timestamp | seed offer `submittedAt` relative to now |
| Tail of a long suite flakes | single-AVD memory pressure | cold-boot + split the suite; bump cold-start timeouts to 45 s |
