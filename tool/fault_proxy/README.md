# P08 local fault proxy

Tooling only. Python 3.9+ standard library; no gateway/app injection code, deployment, or natural-rate-limit traffic. The current branch is `ux/api-error-handling-empty-states` (#335), per OD-0 widen. The original P08 separate-branch and scope-freeze instructions are superseded. No device run is implied by these files.

## Safety envelope

- CLI binds **127.0.0.1:8089 only**, forwarding only `/gateway/` origin-form targets to **https://msi.olivium.space**. No redirects are followed. A staging origin was not verified in the scoped repository sources, so staging is deliberately unavailable; never guess or use the production `jeeb.fds-1.com` origin.
- Local control requests reject browser Origin headers and non-loopback Host headers. This is a local development tool, not a multi-user security boundary: trusted local processes can control it. Do not expose the port through a network tunnel or port share.
- Authorization and request bodies pass through to the selected gateway in memory; **logs contain no headers, bodies, query values, or opaque path segments**. Request IDs and tokens must never be pasted into rules. Credential-header matchers are rejected. Treat captured UI images as private account data.
- Rules are anchored at both ends under `^/gateway/`; their `times` counter is atomic per rule, zero means unlimited. Invalid changed files fail closed with 503 instead of silently forwarding. Successful file reload resets counters; malformed control PUT leaves the prior rules intact. PUT/DELETE override memory until the rules file changes; they do not overwrite it.
- Only scenarios S06/S07/S08 may inject 401/403. Availability's `/jeebers/me/availability` (including a versioned spelling) must never receive a manufactured 404. Custom rules are checked at load/control time and again against the actual decoded request path, including query-specific regexes. A forbidden match returns an explicit proxy 503 without injecting the 404 or forwarding upstream. `respond.drop: true` resets the connection; classify this separately from HTTP scenarios.
- Request/response bodies are bounded at 64 MiB; rules at 1 MiB. Chunked requests are rejected rather than ambiguously framed. HTTP responses preserve binary/compressed bytes and end-to-end headers. Each downstream connection closes after one response.
- `body_file` is relative to the rules file and must resolve inside its directory (including symlink checks). Catalogue bodies are inline so copying a scenario into an evidence directory works without implicit asset paths. `bodies/cloudflare-503.html` is a reusable non-secret sample; copy it beneath your rules directory if using `body_file`.

## Offline gates (no phone or real gateway)

```sh
bash tool/test_fault_proxy.sh
flutter test --no-pub test/core/network/fault_proxy_scenarios_test.dart
dart analyze --fatal-infos test/core/network/fault_proxy_scenarios_test.dart
python3 -B tool/fault_proxy/catalogue.py
```

The Python suite injects an in-process loopback stub connection, never a live upstream. The public CLI cannot select that test seam. If the host prohibits local socket binding, record the denied test execution; do not escalate or substitute live traffic. The Dart suite uses an in-memory adapter and real Dio decoding for malformed JSON/HTML/list responses, then checks model and EN/AR copy against each scenario's `expect` metadata.

S07's Dart case supplies the auth interceptor's recovering marker to verify the mapper/copy contract; only a separate auth integration/device run can prove that the refresh chain sets it and preserves the session. S11 intentionally preserves the plan's `/requests/offer-already-exists` type: current `GatewayProblem.typeSuffix` accepts `/errors/` types only, so its actual suffix is null, not the plan's claimed string. Conflict classification/copy still applies. This discrepancy is recorded in S11 metadata; this tooling does not change the shared parser.

## Scenario catalogue and evidence contract

`scenarios/S00-*.json` through `S16-*.json` are authoritative for rules, expected copy **keys** (resolved from current EN/AR ARBs), target IDs, modes, and hit counts. Generate the current checklist with `python3 -B tool/fault_proxy/catalogue.py`; append Observed and Verdict columns to the private run report. S14 includes a JSON-list variant under `variants`; replace its first rule's `respond` with that object to exercise the second shape. S17 is dropped: P07 owns Arabic device acceptance, reusing these same fixtures.

Cold scenarios S01–S14 target Profile; S06 must run **last** because it terminates the session. S15 first loads a healthy Profile, then faults refresh; S16 first loads healthy Deliveries, then faults refresh. Metadata identifies the expected cold block or warm note/snack: do not apply cold placeholder checks to the healthy stale content that warm scenarios must retain. `customer_profile_refresh_failed` denotes the family prefix; record actual rendered child identifiers in the report.

## Authorized device run (manual operator only)

These steps are a runbook, not a scheduled task. Coordinate the serial device queue first. Use the approved dev debug build and existing protected build wrappers; do not copy provider secrets into evidence. Record current Git SHA, APK SHA-256, device serial and actual Android version, baseline URL/locale/radios/session, and start time. Historical Android 14/16, account names, review counts and five-card counts are not current facts: measure them afresh.

Never uninstall, clear app data, mint a session from a script, or mutate gateway entities to manufacture evidence. An authorized build install uses `adb -s SERIAL install -r APK`. Creating test entities, cleanup, deployment and route flips retain their separate owner/workflow gates.

1. Create a private evidence directory outside the repo, e.g. the current session's `device-evidence-4/p08/`. Set `EV` to its absolute path and `SERIAL` to the verified device serial; do not put credentials in environment or command lines for this proxy. Copy `tool/fault_proxy/scenarios/S00-passthrough.json` to `$EV/rules.json`. Keep one foreground proxy terminal:

   ```sh
   python3 -B tool/fault_proxy/fault_proxy.py --listen 127.0.0.1:8089 --upstream https://msi.olivium.space --rules "$EV/rules.json" --log "$EV/proxy.log"
   ```

2. In another terminal, `bash tool/fault_proxy/device/run_preflight.sh --serial "$SERIAL"` checks the local proxy, S00, MSI readiness and the explicitly selected device, then maps only `tcp:8089`. It refuses a conflicting mapping and does not start background processes or alter app settings. After a USB replug, check the mapping and repeat preflight only with S00 active.
3. Manually open the existing Dev Tool Server URL editor, save `http://127.0.0.1:8089/gateway`, then Apply & Restart. Verify the active override. Use only approved Super Login Plus UI access if the workflow requires an account. Load home, Deliveries and Profile and record actual baseline rows/identity. S00 must show successful pass-through for the target reads; stop if baseline is not transparent.
4. Capture only non-sensitive UI with `bash tool/fault_proxy/device/dump.sh --serial "$SERIAL" --output-prefix "$EV/00-baseline-profile" --screen-confirmed-safe`. It returns XML + PNG and prints `(cx,cy) id|desc|text`, refuses overwrite, and refuses detected token/password UI before saving. Never use it on credential/token screens; the operator's screen check is required because screenshots can include text outside accessibility nodes. It does not clear logcat or save raw logcat: the app-side ledger is captured separately by `bash tool/fault_proxy/device/logcat.sh --serial "$SERIAL" --output-prefix "$EV/Sxx/logcat"`, which reads `adb logcat -d -s flutter`, keeps only the app's already-redacted `[http→]`/`[http←]`/`[http✗]` wire lines (`lib/core/network/redacting_log_interceptor.dart`), drops every other flutter line, writes 0600 without overwriting, and refuses to save at all if a credential-shaped string appears.
5. Clear the app log buffer with `adb -s "$SERIAL" logcat -c` immediately before each scenario load, so the slice you save covers that load only. An empty ledger is reported as a failure, never as a zero-hit result.

## Per-scenario procedure

1. Create the scenario evidence directory (`mkdir -p "$EV/Sxx"`), then select the exact existing filename, e.g. `cp tool/fault_proxy/scenarios/S03-html-503.json "$EV/rules.json"`. Verify `curl --noproxy '*' -sS http://127.0.0.1:8089/__fault/rules` reports the desired scenario. Count only matching FAULT events for the target rule before/after the action, not all proxy log lines.
2. For cold scenarios, manually re-enter the app after force-stop (if authorized for the session) and open Profile. For warm scenarios, load healthy data **before** activating the fault, then trigger refresh. Capture distinct evidence prefixes at roughly 2, 6 and 12 seconds; fast failures may skip visible loading.
3. Cold Profile must never fabricate "Add your name", "No reviews yet", or `?` while loading/retrying. Settled state must match the scenario's error headline/body keys and required CTA: retryable copy gets Retry; S08/S09/S10 get Go back and no retry; S06 routes to registration with the session-expiry note. Assert semantics identifiers, not coordinates. S13/S14 must settle, not spin indefinitely.
4. Compare wire hits with metadata: S01 500 has one; S02/S03/S04 have three GET attempts; S09 may have a versioned then unversioned 404. Count the app side independently from the saved ledger slice: `grep -c '\[http✗\].*GET /v1/users/me' "$EV/Sxx/logcat.txt"` must equal that scenario's FAULT count for the target rule, and must be exactly three per load for S02–S04. A proxy count without a matching ledger count is not a verified hit count. S05 has one network hit then zero additional hits for Retry within 30 seconds, while Deliveries remains healthy. Clear S05 before expiry when verifying recovery; otherwise it will inject another 429.
5. S07 must show a 401 profile read and one 503 refresh POST, no registration route, and recovering copy. Retry within the 20-second auth cooldown must not cause another refresh. Clear rules, wait for cooldown, and verify the same session recovers. This is not proven by the metadata-only flag in the Dart test.
6. S15 retains the measured healthy identity and shows a refresh-failure note. S16 retains measured cards and shows the refresh snack. Check Retry/Dismiss and auto-dismiss within the current configured duration; cite only selected already-redacted `snack_shown`/`snack_closed` events if available. Do not save raw logcat; save the redacted wire ledger through `logcat.sh` as above. A dead reverse/drop is a transport result, not a passed 4xx/5xx scenario; on P13 builds it must not falsely claim the whole device is offline.
7. Restore S00, Retry or re-enter the screen, and capture recovery with the real baseline identity/data. Copy only sanitized proxy-log slices into the scenario evidence directory, next to that scenario's `logcat.txt` ledger slice, so `$EV/Sxx/` carries both independent counters. Perform a copy-hygiene check on the **failure-screen** XML for exception/socket/Dio/raw status/URL/trace text, excluding the intentional Dev Tool override screen. Record failures honestly.
8. Run S14's second JSON-list variant as a separate sample. Run S06 last: document whether refresh occurred, verify registration and expiry note, clear faults, then restore the approved session through the real Super Login Plus UI. P07 owns EN→AR→EN device coverage and restoration.

## Teardown and report

First select S00. Restore the app's recorded original gateway URL, locale, radio and session state through the real UI; Apply & Restart and capture non-sensitive recovery evidence. Then run `bash tool/fault_proxy/device/run_teardown.sh --serial "$SERIAL" --app-restored`. It clears in-memory rules and removes **only** that device's `tcp:8089` reverse, never all mappings. Stop the foreground proxy with Ctrl-C; no PID guessing or broad process kills. Confirm real-data recovery and perform any separately approved ledger sweep/audit. Do not assume historical request IDs still exist or are pending.

`REPORT.md` must name the tested head/build, actual device version, transparent baseline, scenario/variant samples, expected/observed wire counts, UI IDs/copy, recovery, remaining NOT EXERCISED rows and residual state. Offline test success is not device acceptance, release readiness, or a completed backend workflow. A device failure becomes a separately reviewed fix with a fresh run; these scripts do not modify product code.
