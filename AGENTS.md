# AGENTS.md — jeeb-mobile device testing (read before any device action)

This file is the repo-persistent playbook for the Codex device-testing runtime
(HANDOVER §8 contract). It carries the STABLE facts every run needs; per-run values
(run number, APK sha, evidence dir, deploy gate) arrive in the mission prompt.
Before you start: read `docs/testing/LESSONS.md` (append-only; newest first) —
it overrides your instincts.

## Rig
- CUSTOMER: Samsung S22 Ultra `R5CT71TVVAJ` (wifi `192.168.2.10:5555`).
- JEEBER:   Samsung S24 `RFCX306JSRT` (wifi `192.168.2.137:5555`; sometimes USB-only —
  try the USB serial if the wifi endpoint is absent).
- NO EMULATOR for proof runs. `adb devices` must show BOTH as `device` (and no emulator)
  before anything else.
- App id `app.jeeb.mobile.dev` (dev flavor; staging→`.staging`, prod→`app.jeeb.mobile`).
  APK path pattern: `build/app/outputs/flutter-apk/app-dev-debug.apk` in the build worktree.
  ALWAYS verify the sha256 given in the mission against the on-device `pm path` → `base.apk`.
- Gateway `http://192.168.2.39:10090`. `/health` 200 = process alive, NOT proof that any
  specific deploy leg is live — deploy state is proven only by the mission's behavioral
  discriminator (e.g. create returns 201, accept carries `handoverCode`).

## Tools & gotchas (each of these has burned a run)
- Maestro 2.0.5: the device flag is TOP-LEVEL — `maestro --device <SERIAL> test flow.yaml`.
  `maestro test --device …` errors "Unknown option". `-e APP_ID=…` is also run-time only.
- Wake the screen before any screencap: `adb -s <S> shell input keyevent KEYCODE_WAKEUP`
  (+ `wm dismiss-keyguard`) or you capture the black AOD battery frame.
- Background/cold states: `am kill` — NEVER `force-stop` (force-stop kills the push
  background isolate under test).
- After any network submit, gate on the DESTINATION screen's root semantics id with
  `extendedWaitUntil` timeout 45000. Never fixed sleeps; 25000 is only for warm,
  non-network, same-screen transitions.
- Off-screen targets: `scrollUntilVisible {element:{id:…}, direction: DOWN, timeout:15000}`
  BEFORE tapOn/screenshot — `extendedWaitUntil` does not scroll.
- Target semantics ids, never text (bilingual EN/AR + RTL) and never blind pixel
  coordinates — coordinate-guess loops are the single biggest token/time waste on record
  (run-24: 79 blind taps, 446 retries). If the semantics tree is empty, SAY SO and fall
  back to screenshots + uiautomator dump resource-ids.
- On external volumes ignore macOS `._*` AppleDouble sidecars (~4 KB); size-check the real
  artifact by EXACT name (a real mp4 is > 10 KB, real PNGs ~60–85 KB).
- Maestro sometimes doubles the screenshot extension (`<state>.png.png`); match states by
  name stem + size, don't reject on filename.

## Assertion source: the [jeeb-diag] stream
- `adb -s <S> logcat | grep jeeb-diag` → JSON lines `{"t":"nav"|"api"|"evt",…}`,
  tokens redacted by design.
- API asserts come from diag `api` lines (seq+screen+status); nav asserts from `nav`
  lines with params; chat/evt asserts from `evt` lines.
- On-device JSONL export: the app writes sessions to
  `/data/user/0/app.jeeb.mobile.dev/files/diag/<ISO-ts>-<role>.jsonl`; the diag `session`
  header line and the `exportinfo` evt carry the exact file path. Pull it from BOTH
  devices at run end into `wire/` (worked example: `docs/sprints/sprint-009/proof-run25/wire/`).
  Note: missions have referenced `docs/diagnostics.md` — that file is not in this clone;
  the proof-run25 wire dir is the ground-truth example of the export + assertions.

## Evidence discipline
- ALL evidence under the mission's evidence dir (repo-relative,
  `docs/sprints/sprint-009/proof-runNN/…`, never the repo root): `wire/`, `screenshots/`,
  `logs/`. Report paths in the result JSON relative to that dir.
- Every verdict cites files you produced. Validate screenshot CONTENT (right ids/labels/
  screen), not just file existence.
- Redact: mask OTP as first digit + XXX; never print/quote Bearer/`eyJ`/`tok:` tokens —
  sed-redact wire dumps before writing them.
- Start detached logcats early; STOP them in cleanup; leave both devices signed in and
  the jeeber Online.
- Record wall-clock UTC (`date -u`) at the start and end of every phase; a duration you
  did not measure is `-1`, never guessed.

## Forbidden (anti-cheat — violation = overall FAIL)
- No backend-minted tokens for app actions; no direct API call standing in for a screen
  the user would tap; no OTP guessing/brute-force and no reading codes from server/logs —
  the customer SCREENSHOT is the only legitimate OTP source.
- One customer identity + one jeeber identity throughout; NEVER the super_login/seed seam
  on the main devices. Prove continuity via the [jeeb-diag] `sub` prefix (first 8 chars).
- Never restart/redeploy/kill/bounce the gateway, any service, Redis, or Postgres.
  Never wipe/reset/uninstall beyond what the mission specifies.
- A check that can't be done honestly is FAIL (or BLOCKED if a prior check made it
  unreachable) with evidence — never fabricate a pass, and never keep retrying a
  server-side rejection across variants (one honest failure + evidence, then follow the
  mission's gate: run-25 burned ~9 min retrying a 400 across 3 tiers).

## Fast nav paths (semantics ids, from the sprint-009 interaction atlas)
- Shell tabs: `shell_tab_requests` (0), `shell_tab_delivery` (1), `shell_tab_dashboard` (2,
  jeeber; unseen-request badge `shell_tab_dashboard_badge`), `shell_tab_earnings` (3),
  `shell_tab_profile` (4).
- Customer New Order entry (zero-orders hero): `_request_empty_state_new_order_button`
  on root `_request_empty_state_root` (leading underscore is real, not a typo).
- Jeeber feed root: `jeeber_feed_root`; tapping a feed card pushes `jeeber-request-detail`.
- Full per-screen id inventory: `docs/sprints/sprint-009/interaction-atlas/` (workspace
  docs repo) — treat it as the source of truth before grepping `lib/`.

## Launch contract (host side, for reference)
- Runs launch via `codex exec … --ignore-user-config` (REQUIRED or MCP init hangs), with a
  STRICT `--output-schema` (`additionalProperties:false` everywhere AND every property
  required — a lax schema kills the session at second zero with `400 invalid_json_schema`).
- Mission prompts are composed as stable preamble + per-run delta
  (`docs/testing/mission-preamble.md` + `delta-runNN.md`); the composed text is archived
  in the run's evidence dir.
