# Jeeb Diagnostic Event Stream (`[jeeb-diag]`)

A single, greppable stream of structured JSON lines that tells you **exactly
which screens opened, which APIs were called, and which domain events fired**
during a device run — without a debugger, a rebuild, or `adb push`.

- **Tag:** every line starts with the literal prefix `[jeeb-diag]`.
- **Format:** `[jeeb-diag] ` followed by ONE line of JSON (one event per line, `jq`-able).
- **Active only in debug/dev builds.** The stream is gated on
  `Diag.enabled == kDebugMode || bool.fromEnvironment('JEEB_DIAG')`. In a
  release build with no define, every `Diag.*` call is an early-return no-op and
  the `jsonEncode` cost is never paid.
- **Redaction is by design.** No `Authorization` header, request/response body,
  token, or query string ever reaches a line. Secrets that would be useful for
  correlation are reduced to a non-reversible handle `tok:<fnv8>~<last4>`.
- **Persisted on device** (diag-persistence lane): every line is ALSO teed into
  a per-session JSONL file so a run can be exported *after the fact* — see
  [Persistence](#persistence-on-device-session-files) and
  [Export](#export-getting-a-session-off-the-device) below.

Source: `lib/core/diagnostics/` (`Diag`, `DiagNavObserver`, `DiagDioInterceptor`,
`DiagRedaction`, `DiagFileSink`, `DiagExport`, `DiagnosticsScreen`).

---

## How to watch it

```bash
# Android — live, filtered to just the diagnostic stream
adb logcat | grep '\[jeeb-diag\]'

# Strip the tag and pretty-print / filter with jq
adb logcat | sed -n 's/.*\[jeeb-diag\] //p' | jq .

# Only API calls that were NOT 2xx
adb logcat | sed -n 's/.*\[jeeb-diag\] //p' | jq 'select(.t=="api" and (.status<200 or .status>=300))'

# Only navigation pushes (which screens opened, in order)
adb logcat | sed -n 's/.*\[jeeb-diag\] //p' | jq 'select(.t=="nav" and .evt=="push") | .route'

# Every domain event of a given name
adb logcat | sed -n 's/.*\[jeeb-diag\] //p' | jq 'select(.t=="evt" and .name=="offer_submitted")'
```

```bash
# iOS Simulator
xcrun simctl spawn booted log stream --style compact | grep '\[jeeb-diag\]'

# Flutter tooling (any target)
flutter logs | grep '\[jeeb-diag\]'
```

To force the stream on in a **profile** build for a device run:
`flutter run --profile --dart-define=JEEB_DIAG=true`.

---

## Persistence: on-device session files

In debug/dev builds every emitted line is ALSO appended (buffered, async, off
the UI thread) to a per-session **JSONL** file, so a run can be analysed after
the fact without a live logcat tail. Implemented by `DiagFileSink`, installed
fire-and-forget in `Bootstrap.minimal` (cold-start events are buffered in
memory until the file is ready — first paint is never held).

### File layout

```
<application support dir>/diag/<sessionStart>-<role>.jsonl
```

| platform | concrete path |
|----------|---------------|
| Android (dev flavor) | `/data/user/0/app.jeeb.mobile.dev/files/diag/2026-07-03T10-30-15-123Z-client.jsonl` |
| Android (prod id, dev build) | `/data/user/0/app.jeeb.mobile/files/diag/…` |
| iOS | `<app sandbox>/Library/Application Support/diag/…` |

The file name is the session-start UTC timestamp (ISO-8601 with `:`/`.`
replaced by `-`, millisecond precision) plus the active role at launch
(`client` / `jeeber` / `unknown`), so names sort chronologically and a shelf of
files from two phones can be told apart at a glance.

The file body is the logcat payload **minus the `[jeeb-diag] ` prefix** — pure
JSONL, directly `jq`-able:

```bash
jq 'select(.t=="api" and .status>=400)' 2026-07-03T10-30-15-123Z-client.jsonl
```

**Line 1 is always the session header** (`t: "session"`):

```json
{"t":"session","v":1,"appVersion":"1.0.0+1","buildSha":"0f39e81","os":"android","osVersion":"…","model":"Pixel 8","role":"client","file":"/data/user/0/…/diag/….jsonl","ts":"2026-07-03T10:30:15.000Z"}
```

| field | meaning |
|-------|---------|
| `v` | session-file schema version (1) |
| `appVersion` | pubspec version; override per lane via `--dart-define=JEEB_APP_VERSION` |
| `buildSha` | git sha when the build passes `--dart-define=JEEB_BUILD_SHA=<sha>`; omitted otherwise |
| `os` / `osVersion` / `model` | device fingerprint (model via device_info_plus, best-effort) |
| `role` | active role at session start |

The user identity appears ONLY as a `session_meta` event carrying the **first 8
chars of the sub/userId** (`{"name":"session_meta","data":{"subPrefix":"a1b2c3d4"}}`)
once the keystore read resolves — never the full sub, never a token.

An `exportinfo` event is emitted at session start **into logcat and the file**,
so any log grab reveals where the files live on that device:

```
[jeeb-diag] {"t":"evt","name":"exportinfo","data":{"file":"/data/user/0/app.jeeb.mobile.dev/files/diag/2026-07-03T10-30-15-123Z-client.jsonl","dir":"/data/user/0/app.jeeb.mobile.dev/files/diag"},"ts":"…"}
```

### Rotation policy (size-capped, oldest-first)

| knob | default | behaviour |
|------|---------|-----------|
| `maxSessions` | 5 | at most 5 session files kept (current included); older ones pruned **oldest-first** at session start |
| `maxTotalBytes` | 20 MB | total diag-dir size pruned to this at session start, oldest-first |
| `maxSessionBytes` | 10 MB | a single session stops persisting here — one `diag_session_capped` marker is written, further lines are dropped (logcat keeps flowing) |

### Write/flush semantics (the never-block, never-crash contract)

- `add` only appends to an in-memory buffer (never touches the disk on the
  caller's stack). A serialized async chain performs the appends.
- The buffer hits disk when it reaches 32 lines, immediately when a FAILURE
  record passes (api status ≥ 400 / null, evt name containing `error`/`fail`),
  and on app lifecycle pause/detach (`Diag.flushPersistent`).
- ALL IO is fail-soft: the first hard IO error trips a breaker and persistence
  silently stops for the session; the logcat stream is never affected and the
  app can never crash from diagnostics.
- **Release builds write NOTHING**: the sink is gated on `Diag.enabled` at
  install time and re-checked inside `start()`/`add()` (pinned by tests — no
  directory is even created).

---

## Export: getting a session off the device

### 1. `adb` (no UI needed)

The files are in the app's PRIVATE storage, so plain `adb pull` cannot see
them; for a **debuggable** build use `run-as`:

```bash
# One file (grab the exact path from the exportinfo line in logcat):
adb exec-out run-as app.jeeb.mobile.dev \
  cat 'files/diag/2026-07-03T10-30-15-123Z-client.jsonl' > session.jsonl

# Everything at once:
adb exec-out run-as app.jeeb.mobile.dev tar c files/diag | tar x

# Don't know the file name? List first:
adb shell run-as app.jeeb.mobile.dev ls -l files/diag
```

Substitute the applicationId for the flavor on the device:
`app.jeeb.mobile.dev` (dev), `app.jeeb.mobile.staging` (staging),
`app.jeeb.mobile` (production id, debug build). The exact command for the
newest session is also shown (and copyable) inside the in-app Diagnostics
screen, generated by `DiagExport.adbPullCommand` — the shape is pinned by
`test/core/diagnostics/diag_export_test.dart` so this doc cannot drift from
the code.

### 2. In-app (Settings → Diagnostics, dev builds only)

A minimal dev tool (`DiagnosticsScreen`, route `/settings/diagnostics`), listed
in Settings → About as **Diagnostics** — visible only when `Diag.enabled`:

- lists the persisted sessions (newest first, size + timestamp, the live one
  marked "(current)");
- **tap a row / the share icon** → flushes the live sink, then opens the
  platform share sheet with the JSONL file (share_plus) — mail/Drive/Slack it
  to whoever is debugging;
- **copy icon** → copies the absolute on-device path (fallback when no share
  target exists);
- the Export section shows the diag folder path and the exact `adb` one-liner,
  both copyable.

---

## Event schemas

Every record carries a `t` discriminator (`nav` | `api` | `evt`) and an
ISO-8601 UTC `ts`.

### 1. Navigation — `t: "nav"`

Emitted by `DiagNavObserver`, registered on the app `GoRouter` (`observers:`).

```json
{"t":"nav","evt":"push","route":"/orders/:id","name":"delivery-detail","params":{"id":"d-42"},"prev":"/home","ts":"2026-07-02T10:30:15.000Z"}
```

| field   | meaning |
|---------|---------|
| `evt`   | `push` \| `pop` \| `replace` |
| `route` | route path / pattern (query-stripped) |
| `name`  | route name for named routes; location otherwise (query-stripped) |
| `params`| path params / route arguments (sensitive keys redacted) |
| `prev`  | the previous route (query-stripped): the screen you came FROM on push/replace, the screen you LEFT on pop; omitted when unknown |

> Query strings are **never** logged — they can carry tokens (`?resetToken=…`).
> Because a `NavigatorObserver` only sees `RouteSettings.name`, `route` and
> `name` coincide for go_router named routes; both are always query-stripped.
> The observer also keeps `Diag.currentScreen` up to date — that is what api
> records stamp as `screen`.

### 2. API calls — `t: "api"`

Emitted by `DiagDioInterceptor`, added to the shared `DioClient` factory.

```json
{"t":"api","m":"GET","path":"/v1/requests","status":201,"ms":123,"reqId":"corr-42","seq":17,"screen":"/jeeber/requests/:id","ts":"2026-07-02T10:30:15.000Z"}
```

| field    | meaning |
|----------|---------|
| `m`      | HTTP method (upper-cased) |
| `path`   | request path, **query-stripped** |
| `status` | HTTP status; `null` on a transport failure (timeout/no response) |
| `ms`     | wall-clock duration in milliseconds |
| `reqId`  | `x-correlation-id` / `x-request-id` header if present (an opaque trace id, not a secret) |
| `seq`    | monotonic per-session sequence number, assigned at REQUEST time — concurrent calls keep distinct ordered ids even when responses land out of order |
| `screen` | the route active when the call FIRED (`Diag.currentScreen`), surviving a mid-flight navigation; omitted before the first navigation |

> **Path + status + duration only.** This interceptor never reads the
> `Authorization` header, the body, or the query string.

### 3. Domain events — `t: "evt"`

Emitted by `Diag.event(name, data)` at key seams. The `data` payload is
defensively scrubbed (`DiagRedaction.scrubMap`).

```json
{"t":"evt","name":"offer_submitted","data":{"requestId":"r-1","priceUsd":12.5,"etaMinutes":20},"ts":"2026-07-02T10:30:15.000Z"}
```

Currently wired seams:

| `name`                | fires when… | key `data` fields |
|-----------------------|-------------|-------------------|
| `push_received`       | a push arrives (foreground or background) | `mode` (`foreground`\|`background`), `id`, `category` |
| `push_tapped`         | a notification/banner tap is routed | `id`, `category`, `deepLink`, `resolved` |
| `session_auth`        | the session gate re-classifies auth state | `status` (**never a token**) |
| `offer_submitted`     | a Jeeber offer POST succeeds | `requestId`, `priceUsd`, `etaMinutes` |
| `offer_accept_result` | a client accept resolves | `offerId`, `status`, `failure?` |
| `chat_message_send`   | a chat message send acks/fails | `deliveryId`, `result` |
| `delivery_status`     | the client observes a delivery phase change | `deliveryId`, `phase` |
| `role_switch`         | the active role ACTUALLY changes (settings toggle, getMe sync, seam) — RoleCubit is the single choke point | `from`, `to` |
| `push_permission`     | the push-permission state transitions at bootstrap/re-bootstrap | `from`, `to` (`notDetermined`\|`granted`\|`denied`) |
| `connectivity`        | the OfflineCubit status actually flips | `status` (`online`\|`offline`) |
| `session_meta`        | the keystore userId resolves after session start | `subPrefix` (**first 8 chars only — never the full sub**) |
| `exportinfo`          | a persisted session file opens (session start) | `file`, `dir` (the on-device paths) |
| `diag_session_capped` | the session file hit `maxSessionBytes` (file-only marker) | `maxSessionBytes` |
| `diag_lines_dropped`  | the in-memory buffer overflowed before a flush (file-only marker) | `count` |

---

## Redaction contract (the security rule)

- Sensitive **headers** (`Authorization`, `Cookie`, `x-api-key`, …) → handle.
- Sensitive **body/data keys** (`accessToken`, `refreshToken`, `fcmToken`,
  `password`, `otp`, …) → handle, recursively.
- **Query strings** are dropped from every logged path.
- The handle `tok:<fnv8>~<last4>` is stable (same secret ⇒ same handle) so you
  can still correlate "same token across two lines", but it is non-reversible
  and only ever exposes the final 4 characters.

The same primitives back `RedactingLogInterceptor`, which replaced the raw
`LogInterceptor` that used to print full bearer JWTs and FCM tokens to logcat.

---

## Rule for run missions

**Run missions SHOULD assert on `jeeb-diag` lines**, not on screenshots or
guesswork. A device-run check is expected to:

1. Filter logcat on `[jeeb-diag]`.
2. Assert the expected `nav` `route`s appear in order (the screens that opened).
3. Assert the expected `api` `path`+`status` pairs appear (the calls that fired).
4. Assert the expected `evt` `name`s appear (the domain events that happened).
5. Assert **no** secret ever appears — grep the stream for `Bearer`, a raw JWT,
   or a known FCM token and expect zero matches.

Example gate:

```bash
adb logcat -d | grep '\[jeeb-diag\]' > run.log
jq -e 'select(.t=="nav" and .route=="/jeeber/requests/:id")' < <(sed -n 's/.*\[jeeb-diag\] //p' run.log) >/dev/null \
  || { echo "FAIL: jeeber request detail never opened"; exit 1; }
! grep -Eq 'Bearer |eyJ[A-Za-z0-9_-]{10,}\.' run.log \
  || { echo "FAIL: a token leaked into the diag/log stream"; exit 1; }
```
