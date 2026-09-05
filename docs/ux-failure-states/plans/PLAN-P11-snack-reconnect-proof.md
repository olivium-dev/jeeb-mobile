# PLAN P11 — isolated device proof that the refresh-failed snack clears ON RECONNECT (F6 `clearOnReconnect`)

Pending point: `P11-snack-reconnect-proof`. Planning only; no repo file was changed while writing this.
Repo: `olivium-dev/jeeb-mobile`. Branch `ux/api-error-handling-empty-states` @ `ecfd3cc1` on `origin/main@ab610933`.
Worktree: `/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`.
PR: https://github.com/olivium-dev/jeeb-mobile/pull/335 (draft).
Device: SM-A336B `RZCT505K7WF` (Android 14, USB adb). Gateway: `https://msi.olivium.space/gateway`.
Scratchpad root (`$S` below): `/private/tmp/claude-501/-Users-oudaykhaled-Desktop-olivium-jeeb/6a29e634-9ff5-4e5b-b358-a1a84368ab4f/scratchpad`.

---

## 0. Verified current state (2026-09-05, code + logs + live device)

| # | Fact | Evidence |
|---|---|---|
| S1 | The mechanism: `_show` in `lib/core/widgets/jeeb/jeeb_snack.dart:145-160` subscribes to `NetworkReachabilitySignals.instance.stream` when `clearOnReconnect` is true and calls `controller.close()` on the first emission; the subscription is cancelled when `controller.closed` completes. `controller.close()` is Flutter's `hideCurrentSnackBar()` (`/Users/oudaykhaled/flutter/packages/flutter/lib/src/material/scaffold.dart:340-342`), so the closed reason is `SnackBarClosedReason.hide`. | file:line above; Flutter 3.44.2 |
| S2 | `clearOnReconnect` defaults to `failure != null && failureBlamesConnectivity(failure)` (`jeeb_snack.dart:49-51`; `lib/core/network/network_reachability_signals.dart:12-14` = only `network`/`timeout` kinds). **No production caller passes it explicitly** (`grep -rn clearOnReconnect lib` → only `jeeb_snack.dart`). The Deliveries snack (`lib/features/order_history/presentation/order_history_screen.dart:113-120`, identifier `order_history_refresh_failed_snack`) gets it through `NetworkFailure(offline: true)` — the default path is the one under test. | grep + file:line |
| S3 | Lifetime: `persist: false` + `duration ?? (hasAction ? kJeebSnackActionDuration /*8 s*/ : kJeebSnackDuration /*4 s*/)` (`jeeb_snack.dart:13-16, 118-123`). Flutter derives `persist` from `action != null` (`snack_bar.dart:303`), which is why F6 existed. | file:line |
| S4 | **No observability**: `_show` emits no `Diag` event. The only reconnect traces are `network_reachable{count}` (`network_reachability_signals.dart:107`) and `connectivity{status:"online"}` (`lib/features/offline_mode/application/offline_cubit.dart:41`). Nothing in logcat says *why* a snack left (timeout vs reconnect vs action). | grep `Diag` in jeeb_snack.dart → 0 hits |
| S5 | Unit coverage exists: `test/core/widgets/jeeb/jeeb_snack_test.dart:361-518` (`F6 · a snack has a bounded life`): persist false + 8 s; gone after 8 s; reconnect edge retires a connectivity snack (EN + AR); leaves a `ServerFailure(500)` snack; never kills the replacement snack. Reconnect is simulated with `debugObserve(online:false)` then `(online:true)`. | file:line |
| S6 | Device evidence is confounded by design of the test, not by a defect: run 2 `$S/device-evidence-2/offline-a11y/REPORT.md` assertion 7 = bounded ~8–10 s; assertion 9 = snack gone in the *same* 4 s poll window in which `ping` flipped UP (`reconnect-timeline2.txt`: `t=4s snack=1 net=DOWN`, `t=8s snack=0 net=UP`). Run 1 (`$S/device-evidence/offline/logcat.txt:6171`) shows `network_reachable` at 09:59:15.5, ~4 s after the radios were enabled. | evidence files |
| S7 | **Live probe today** (`$S/p11/reconnect-timing-probe.txt`, script `$S/p11/probe.sh`): the phone has **no SIM** (`getprop gsm.sim.state` = `ABSENT,ABSENT`, `mDataRegState=OUT_OF_SERVICE`) → `svc data enable` **never** produced an active default network in 30 s; `settings get global mobile_data` still prints `1` (misleading, as run 1/2 noted). Wi-Fi-only: OS `Active default network` back **4.4 s** after `svc wifi enable`; the running app (pid 14441) logged `network_reachable` at 18:54:32.94 vs the enable command at 18:54:28.7 → **app-observed reconnect edge ≈ 4.2 s after the command**. Radios restored exactly (`wifi_on=1 mobile_data=1`, default network 135). | probe output |
| S8 | Consequence: with an 8 s snack, the earliest possible reconnect edge lands at t≈4–5 s after the snack appears, plus 1–2 s per `uiautomator dump`, leaving ≤3 s of margin before natural expiry. **Timing alone cannot isolate `clearOnReconnect` on this device.** A longer-lived snack variant *and* a causal discriminator in the log are both required. | S3 + S7 |
| S9 | Build inputs are in place in the worktree: `android/app/google-services.json` (1566 B) and `android/app/src/dev/google-services.json` (2938 B, project `jeeb-5a293`); `MAPS_API_KEY` must be passed as `-PMAPS_API_KEY=` (value in `/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/android/local.properties`; `flutter build` rewrites the worktree's `local.properties`). Installed APK on the phone: `versionName=1.0.0-dev`, `lastUpdateTime=2026-09-05 14:02:58` (run 3, `ecfd3cc1`). | `$S/device-evidence-2/build/REPORT.md`; `adb shell dumpsys package app.jeeb.mobile.dev` |
| S10 | `Diag` seams: `Diag.event` is on in debug builds (`lib/core/diagnostics/diag.dart:23`), lines are `[jeeb-diag] {json}` (`diag.dart:16,136-139`, sink = `developer.log` + `debugPrint` → logcat `I/flutter`). `DiagRedaction.scrubMap` only redacts `kSensitiveDataKeys` (`diag_redaction.dart:12-…`: authorization/token/password/…) — `identifier`, `reason`, `elapsedMs` pass through. Test seams: `Diag.enabledOverride`, `Diag.sink`, `Diag.clock`, `Diag.resetForTest()` (`diag.dart:20-52`). | file:line |
| S11 | Compile-time flag convention: `bool.fromEnvironment` constants in `lib/core/dev_flags.dart:4-42`, `kDevAffordancesAllowed = kDevToolEnabled || kDebugMode` (line 42), shape-asserted by `test/core/dev_flags_test.dart`. No `int.fromEnvironment` exists in `lib/` yet. The staging RC workflow (`.github/workflows/trusted-mobile-rc.yml:304-308`) passes only its own dart-defines, so a new define defaults off there. | file:line |
| S12 | The Dev Tool is a separate `MaterialApp` on `Bootstrap.minimal()` (`lib/devtool/devtool_shell.dart:116-123`) with its own `ScaffoldMessenger`; a probe hosted there would not be the real product UI (real-flow standard). Rejected as the proof surface. | file:line |

**Root cause of the pending point**: the mechanism is correct and unit-proven (S5); the device proof is confounded because the 8 s expiry and the Wi-Fi reconnect edge (~4.2 s, no SIM fallback) fall in the same poll window (S6–S8), and the code leaves no trace that distinguishes a `timeout` close from a `reconnect` close (S4).

---

## 1. Design (two small changes, no behaviour change in store/staging builds)

**C1 — make the close cause observable (product code, all builds where Diag is on).**
`_show` emits `snack_shown` right after `showSnackBar` and `snack_closed` when `controller.closed` completes, with `reason` = `'reconnect'` when *our* listener retired it, else `SnackBarClosedReason.name` (`timeout`, `action`, `swipe`, `hide`, `remove`, `dismiss`). This turns "the snack is gone" into "the snack was closed BY the reconnect edge N ms after it was shown" — the causal discriminator that no timing window can provide.

**C2 — a dev-affordance-gated, compile-time stretch of the action-snack lifetime (proof build only).**
`--dart-define=JEEB_DEV_SNACK_ACTION_MS=30000` makes action-bearing snacks live 30 s in a debug/Dev-Tool build; it is `int.fromEnvironment(..., defaultValue: 0)` and only honoured under `kDevAffordancesAllowed`, so it const-folds to the 8 s constant in release. With a 30 s snack the reconnect edge at t≈5–6 s leaves a ≥20 s margin — the visual proof is unambiguous even without C1.

Rejected alternatives: (a) runtime pref `dev.snack_action_ms` — needs async `SharedPreferences` plumbing into a synchronous kit function; (b) Dev Tool catalog/action probe — not the real UI (S12); (c) `svc data`-only fast reconnect — impossible, no SIM (S7); (d) making the offline snack permanently longer in product — changes F6's bound for every user to serve a test.

---

## 2. Fix steps (ordered; every step names repo + file)

1. **jeeb-mobile `lib/core/dev_flags.dart`** — append after line 42 (`kDevAffordancesAllowed`):
   ```dart
   /// Proof-only stretch of action-bearing snacks (ms); 0 = product default.
   /// Honoured only under [kDevAffordancesAllowed]; inert in store builds.
   const int kDevSnackActionMsOverride = int.fromEnvironment(
     'JEEB_DEV_SNACK_ACTION_MS',
     defaultValue: 0,
   );
   ```
2. **jeeb-mobile `lib/core/widgets/jeeb/jeeb_snack.dart`**
   - Add imports: `'../../dev_flags.dart'` and `'../../diagnostics/diag.dart'`.
   - After `kJeebSnackActionDuration` (line 16) add:
     ```dart
     /// The product bound stays [kJeebSnackActionDuration]; a Dev-Tool/debug
     /// build may stretch it via JEEB_DEV_SNACK_ACTION_MS for device proofs.
     Duration get jeebSnackActionDuration =>
         kDevAffordancesAllowed && kDevSnackActionMsOverride > 0
         ? const Duration(milliseconds: kDevSnackActionMsOverride)
         : kJeebSnackActionDuration;
     ```
   - In `_show` replace lines 110-160 so the body becomes (keep the `SnackBar(...)` construction as-is except `duration: life`):
     ```dart
     final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
     final TextStyle? base = Theme.of(context).snackBarTheme.contentTextStyle;
     final bool hasAction = actionLabel != null && onAction != null;
     final Duration life =
         duration ?? (hasAction ? jeebSnackActionDuration : kJeebSnackDuration);
     messenger.hideCurrentSnackBar();
     final DateTime shownAt = DateTime.now();
     final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
         messenger.showSnackBar(SnackBar(/* unchanged, but */ duration: life, /* ... */));
     Diag.event('snack_shown', <String, Object?>{
       'identifier': identifier,
       'hasAction': hasAction,
       'clearOnReconnect': clearOnReconnect,
       'durationMs': life.inMilliseconds,
     });
     bool settled = false;
     bool retiredByReconnect = false;
     StreamSubscription<void>? reconnected;
     if (clearOnReconnect) {
       reconnected = NetworkReachabilitySignals.instance.stream.listen((void _) {
         if (settled) return;
         settled = true;
         retiredByReconnect = true;
         // `controller.close()` and not `hideCurrentSnackBar()`: a later snack
         // must survive the reconnect that retires this one.
         controller.close();
       });
     }
     unawaited(
       controller.closed.then((SnackBarClosedReason reason) {
         settled = true;
         unawaited(reconnected?.cancel());
         Diag.event('snack_closed', <String, Object?>{
           'identifier': identifier,
           'reason': retiredByReconnect ? 'reconnect' : reason.name,
           'elapsedMs': DateTime.now().difference(shownAt).inMilliseconds,
         });
       }),
     );
     ```
     Notes: use `DateTime.now()`, NOT `Diag.clock` — it is `@visibleForTesting` (`diag.dart:30-31`) and `dart analyze --fatal-infos` rejects it from `lib/`. Keep the existing `Key('${identifier}_retry_cta')` action, `persist: false`, colours and Semantics untouched. Comments max 2 lines. Event names contain neither `error` nor `fail`, so `Diag._isFailureRecord` will not force a persistent flush.
3. **jeeb-mobile `test/core/widgets/jeeb/jeeb_snack_test.dart`** — add `import 'dart:convert';` and `import 'package:jeeb_mobile/core/diagnostics/diag.dart';`, plus a helper:
   ```dart
   List<Map<String, Object?>> _diagEvents(List<String> lines, String name) => lines
       .map((l) => jsonDecode(l.substring(Diag.prefix.length + 1)) as Map<String, Object?>)
       .where((r) => r['t'] == 'evt' && r['name'] == name)
       .map((r) => r['data'] as Map<String, Object?>)
       .toList();
   ```
   New group `'F6 · the close cause is observable'` (same `setUp`/`tearDown` as the existing F6 group, plus `Diag.enabledOverride = true; Diag.sink = lines.add; addTearDown(Diag.resetForTest);`):
   - `'snack_shown carries clearOnReconnect for a connectivity snack'` — fire `showJeebErrorSnack(failure: NetworkFailure(offline:true), onRetry: (){})` → one `snack_shown` with `identifier == 'order_history_refresh_failed_snack'`, `clearOnReconnect == true`, `hasAction == true`, `durationMs == kJeebSnackActionDuration.inMilliseconds`.
   - `'a reconnect closes it with reason=reconnect'` — same fire, `reconnect()`, `pumpAndSettle` → `snack_closed.reason == 'reconnect'`, snack gone by identifier.
   - `'natural expiry closes it with reason=timeout'` — fire, `tester.pump(kJeebSnackActionDuration)`, `pumpAndSettle` → `reason == 'timeout'`.
   - `'Retry closes it with reason=action'` — fire, `tester.tap(find.byKey(const Key('order_history_refresh_failed_snack_retry_cta')))`, `pumpAndSettle` → `reason == 'action'`.
   - `'a 500 snack is shown with clearOnReconnect=false and survives reconnect'` — `ServerFailure(status: 500)` → `snack_shown.clearOnReconnect == false`; after `reconnect()` no `snack_closed` and `find.byType(SnackBar)` findsOneWidget.
   - Run each of the first two for `Locale('en')` and `Locale('ar')` (identifier assertions are locale-independent; the ruling requires EN+AR pumps).
4. **jeeb-mobile `test/core/dev_flags_test.dart`** — add a test `'the snack stretch is inert unless a dev build asks for it'`: `expect(kDevSnackActionMsOverride, const int.fromEnvironment('JEEB_DEV_SNACK_ACTION_MS', defaultValue: 0));` and `expect(jeebSnackActionDuration, kJeebSnackActionDuration)` (define is unset under `flutter test`); plus a source-shape assertion that `lib/core/widgets/jeeb/jeeb_snack.dart` contains `kDevAffordancesAllowed && kDevSnackActionMsOverride > 0` (mirrors the file's existing gate-shape tests).
5. **Gates (worktree)** — `git add` the touched files first (RULINGS R6), then:
   `dart analyze --fatal-infos .` → clean;
   `flutter test test/core/widgets/jeeb/jeeb_snack_test.dart test/core/dev_flags_test.dart` → green;
   `flutter test --exclude-tags capture` → baseline 0 failures (guardrail ratchets included; no new identifiers, no ARB change, so `secret_redactor_test` inventory and l10n parity are unaffected — still run `qa/t-mob-fix-002/l10n_parity_check.sh --analyze` and `tool/check_design_tokens.sh` because CI does).
6. **Commit** on `ux/api-error-handling-empty-states` (never a new repo; same branch/PR): `fix(ux): F6 snack closes are observable in Diag; dev-only lifetime stretch for device proofs`. Sequence it BEFORE P10's "mark ready for review" step (`ci.yml` concurrency cancels in-flight CI on every push — P10 S5).
   Reconciled (C1): #335 is scope-frozen with exactly three allowed commits — P12 Change A, this one, then P10's CI
   fix — pushed as ONE batch. If OD-16 (C2 define) is unanswered when the batch is ready, commit C1 only (Diag events)
   and run the proof on the 8 s snack relying on `reason="reconnect"`; C2 then becomes a follow-up.
7. **Build the proof APK** (jeeb-mobile worktree):
   ```
   MAPS_KEY=$(grep MAPS_API_KEY /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/android/local.properties | cut -d= -f2)
   flutter build apk --debug --flavor dev -t lib/main.dart -Pjeeb.devtool=true -PMAPS_API_KEY="$MAPS_KEY" \
     --dart-define=JEEB_DEVTOOL_ENABLED=true --dart-define=JEEB_DEV_SNACK_ACTION_MS=30000
   cp build/app/outputs/flutter-apk/app-dev-debug.apk $S/p11/app-dev-debug-snack30s.apk
   adb -s RZCT505K7WF install -r $S/p11/app-dev-debug-snack30s.apk      # install -r ONLY, never uninstall
   ```
8. **Device proof** — evidence dir `$S/device-evidence-4/snack-reconnect/`; helper `$S/p11/snack-proof.sh` (write it from the snippets below; `$S/device-evidence-3/dumpui.sh` + `show.py` are the dump/parse pattern to copy).
   Preflight: `curl -s -o /dev/null -w '%{http_code}' https://msi.olivium.space/gateway/health/ready` → 200; `adb shell settings get global wifi_on` → save as `radios-before.txt`; `adb shell 'dumpsys connectivity 2>/dev/null | grep "Active default network"'` (pipe through `2>/dev/null`, `grep -m1` spams "Broken pipe"); confirm Dev Tool home shows "Server URL override active — https://msi.olivium.space/gateway"; confirm the session is a jeeber with deliveries (Karim TestJeeber via Dev Tool → Super Login → Super Login Plus → search "Karim" → first row, exactly as run 2), then `am start -n app.jeeb.mobile.dev/com.olivium.jeeb.MainActivity`, open the **Deliveries** tab (`order_history_root`, ≥1 `order_history_card_*`).
   Helpers:
   ```
   D="adb -s RZCT505K7WF shell"; EV=$S/device-evidence-4/snack-reconnect
   dump(){ $D uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb -s RZCT505K7WF pull /sdcard/ui.xml $EV/$1.xml >/dev/null; adb -s RZCT505K7WF exec-out screencap -p > $EV/$1.png; }
   has(){ grep -c "resource-id=\"$1\"" $EV/$2.xml; }          # node count by semantics identifier
   diag(){ $D logcat -d -v time | grep -E "snack_shown|snack_closed|network_(un)?reachable|\"connectivity\"" | tr -d '\r'; }
   ptr(){ B=$(grep -o 'resource-id="order_history_card_[^"]*"[^>]*bounds="\[[0-9]*,[0-9]*\]' $EV/$1.xml | head -1 | grep -o '\[[0-9]*,[0-9]*\]$' | tr -d '[]'); X=${B%,*}; Y=${B#*,}; $D input swipe $((X+300)) $((Y+40)) $((X+300)) $((Y+940)) 400; }
   ```
   **Run A — reconnect closes the snack (the proof):**
   1. `$D logcat -c`; `dump A00-baseline` → `has order_history_root` = 1, `has offline_banner` = 0.
   2. `$D svc wifi disable; $D svc data disable` (data is inert without a SIM, toggled for parity with run 2). Wait until `diag` shows `network_unreachable` (≤10 s) and `dump A01-offline` shows `has offline_banner` = 1.
   3. `ptr A01-offline`; poll `dump A02-snack-t$i` every 1 s until `has order_history_refresh_failed_snack` = 1 → record `T0=$(date +%s)`. `diag` must now contain `snack_shown … "identifier":"order_history_refresh_failed_snack","hasAction":true,"clearOnReconnect":true,"durationMs":30000`.
   4. Immediately `$D svc wifi enable`; record `TE=$(date +%s)` (expect TE−T0 ≤ 2 s).
   5. Poll `dump A03-t$i` every 1 s for up to 20 s; record the first `i` with `has order_history_refresh_failed_snack` = 0 → `T1`. Also record `has offline_banner`.
   6. `dump A04-post-reconnect` at T0+20 s (snack must still be absent; ≥1 `order_history_card_*` present, no Retry tap performed).
   7. `diag > $EV/logcat-runA.txt`. **PASS iff all of**: (i) `snack_closed` for that identifier has `"reason":"reconnect"` and `elapsedMs` < 15000 (the 30 s timer therefore had ≥15 s left); (ii) its logcat timestamp is within 1 s of `network_reachable`; (iii) T1−T0 ≤ 15 s; (iv) `offline_banner` = 0 at T1; (v) nothing was tapped after the PTR. Write `timeline-runA.txt` with T0/TE/T1 and the per-second snack/banner counts.
   **Run B — negative control (same build, no reconnect):**
   1. `$D svc wifi disable` again → wait for `network_unreachable` + banner; `ptr`; on snack appearance record `T0b`; do NOT re-enable Wi-Fi.
   2. `dump B01-t10` at +10 s, `B02-t20` at +20 s, `B03-t25` at +25 s → snack count must be 1 each; `B04-t33` at +33 s → 0.
   3. `diag > $EV/logcat-runB.txt`: `snack_closed … "reason":"timeout","elapsedMs"` ≈ 30000 (29 000–32 000), and no `network_reachable` between T0b and the close. This proves the run-A close was not expiry.
   4. `$D svc wifi enable`; wait for banner = 0; `dump B05-recovered`.
   **Run C — regression control on the default build (leaves the phone on a non-stretched APK):**
   1. Rebuild WITHOUT `--dart-define=JEEB_DEV_SNACK_ACTION_MS` (same command otherwise); `adb install -r`; cold start; Deliveries tab.
   2. Offline → `ptr` → `snack_shown … "durationMs":8000` in `diag`; stay offline; `dump C01-t2`, `C02-t6` (snack = 1), `C03-t11` (snack = 0); `snack_closed … "reason":"timeout"` with `elapsedMs` 8 000–10 000. Reconnect; `dump C04-recovered`.
   **Optional Run D (AR, closes part of FINAL-REPORT §7f)**: switch the app language to Arabic in Settings, repeat run A once; the snack node's `content-desc` must be the AR `errorNetworkBody`, the identifier unchanged, `reason":"reconnect"` again. Restore EN.
   **Teardown**: `$D svc wifi enable; $D svc data enable`; `settings get global wifi_on` = 1, `Active default network` ≠ none → `radios-after.txt`. No uninstall, no "Clear Local Data", session left as found.
9. **REPORT.md** in `$EV` (same shape as `$S/device-evidence-2/offline-a11y/REPORT.md`): build SHA + APK + install line, radio table, assertion table (A i–v, B, C, D), verbatim `snack_shown`/`snack_closed`/`network_reachable` logcat lines with timestamps, semantics dump excerpt, evidence-file table, device hygiene. Then add a one-paragraph "F6 device-isolated" note + evidence path to the PR #335 body/`$S/pr-body.md`, and drop the caveat text from FINAL-REPORT §3 run 2 (`$S/FINAL-REPORT.md:149-154`) by appending "isolated in run 4".

No gateway change, no deploy, no owner-gated action is involved (mobile-only, debug/Dev-Tool builds only).

---

## 3. Files

- `jeeb-mobile:lib/core/dev_flags.dart` (edit, +7 lines)
- `jeeb-mobile:lib/core/widgets/jeeb/jeeb_snack.dart` (edit, ~+30/−12)
- `jeeb-mobile:test/core/widgets/jeeb/jeeb_snack_test.dart` (edit, new group)
- `jeeb-mobile:test/core/dev_flags_test.dart` (edit, one test)
- Non-repo: `$S/p11/snack-proof.sh`, `$S/device-evidence-4/snack-reconnect/{REPORT.md, A*/B*/C*.xml+png, logcat-run*.txt, timeline-run*.txt, radios-before/after.txt}`, `$S/p11/app-dev-debug-snack30s.apk`

---

## 4. Tests

- `jeeb_snack_test.dart` new group (EN+AR where noted): `snack_shown` fields for a connectivity snack; `reason=reconnect` on the edge; `reason=timeout` on expiry; `reason=action` on Retry; `ServerFailure` → `clearOnReconnect=false` + survives reconnect + no `snack_closed`.
- Existing F6 group stays green unchanged (`kJeebSnackActionDuration` is still the duration under `flutter test`, define unset).
- `dev_flags_test.dart`: override default 0; `jeebSnackActionDuration == kJeebSnackActionDuration`; source-shape guard on the `kDevAffordancesAllowed &&` gate.
- Guardrails untouched by construction: no new Semantics identifier (inventory test), no ARB keys (parity), no design tokens, no `ScaffoldMessenger.showSnackBar` outside the kit.

---

## 5. Validation on the real device / live gateway

Real UI only (Deliveries tab pull-to-refresh, real `GET /v1/deliveries` against `https://msi.olivium.space/gateway`, super-login OK per A17). Proof = three independent signals agreeing in run A: (1) visual/semantics: `order_history_refresh_failed_snack` disappears ≤15 s after it appeared while the build's lifetime is 30 s (`snack_shown.durationMs=30000` in the same log); (2) causal: `snack_closed.reason="reconnect"` with `elapsedMs` < 15000, stamped within 1 s of `network_reachable`; (3) negative control run B on the same build: `reason="timeout"` at ~30 s with no reconnect. Run C proves the shipped bound is still 8 s (`durationMs=8000`, `timeout` at ~8–10 s), matching run-2 assertion 7. Radios restored, no uninstall, phone left on the default build.

---

## 6. Risks

- Wi-Fi reassociation is occasionally slow (>10 s): the 30 s lifetime keeps ≥15 s margin; `reason=reconnect` is the primary discriminator, the timing bound is secondary. If Wi-Fi does not come back within 25 s, abort the run (do not count it), restore radios, repeat.
- A dev-only compile-time knob lands in product code (`jeeb_snack.dart`): const-folded away in release (`kDevAffordancesAllowed` is a compile-time const) and shape-tested; staging RC workflow does not pass it. If the owner declines C2, run the proof with C1 only and accept a tight visual window (the `reason` field still isolates the cause).
- `snack_shown`/`snack_closed` add two Diag lines per snack in debug/JEEB_DIAG builds only; a replaced snack logs `reason="hide"` (from `hideCurrentSnackBar()` at the top of `_show`) — expected, documented in the test names.
- `Diag.clock`/`Diag.sink`/`Diag.enabledOverride` are `@visibleForTesting`: only tests may touch them; production code uses `Diag.event` + `DateTime.now()` (else `--fatal-infos` fails).
- `controller.close()` asserts `_snackBars.first == controller` in debug (`scaffold.dart:341`): the `settled` guard is kept so a late edge never closes a snack that has already gone.
- Extra commit re-triggers PR #335 CI; the `Flutter stage / Test` job is already at the 20-min cap (P10 S3/S4) — land this before P10's mark-ready and let P10's timeout fix carry it.
- Device: SIM absent, so `svc data` cannot reconnect anything — never rely on it; never uninstall; do not run while someone is using the phone (the radios go down ~30 s per run).

---

## 7. Dependencies / owner decision

- Sequencing with `P10-pr-readiness` (commit before RFR; CI timeout margin).
- Owner: **approve the dev-affordance-gated compile-time define `JEEB_DEV_SNACK_ACTION_MS` (C2, inert in store/staging builds)?** If no, execute C1 + runs A/B with the 8 s snack and rely on `reason="reconnect"` alone.

Effort: **M** (code + tests ≈ 1 h; two builds + three device runs + report ≈ 1.5 h).

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C1): one of the three commits allowed on PR #335 (batched with P12-A and the CI fix); its device proof
  does not gate `gh pr ready` but should be run on the batched head SHA right after the P10 §7.1 smoke (same build,
  plus the 30 s proof build if C2 is approved — leave the phone on the default build afterwards, run C).
- Reconciled (C15): P13 later edits `test/core/widgets/jeeb/jeeb_snack_test.dart` (one case) and `app_failure_copy.dart`;
  P11 lands first, so P13 rebases over the new `F6 · the close cause is observable` group — no textual overlap expected.
  P08 S16 may cite `snack_shown`/`snack_closed` once this is on `main`.
- Reconciled (C12/C18): evidence dir `scratchpad/device-evidence-4/snack-reconnect/` (unchanged); record the actual
  Android version (P08 measured 16 / SDK 36) on REPORT.md line 1.
- Owner decision renumbered: OD-16 (`JEEB_DEV_SNACK_ACTION_MS` define).
