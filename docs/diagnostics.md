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

Source: `lib/core/diagnostics/` (`Diag`, `DiagNavObserver`, `DiagDioInterceptor`,
`DiagRedaction`).

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

## Event schemas

Every record carries a `t` discriminator (`nav` | `api` | `evt`) and an
ISO-8601 UTC `ts`.

### 1. Navigation — `t: "nav"`

Emitted by `DiagNavObserver`, registered on the app `GoRouter` (`observers:`).

```json
{"t":"nav","evt":"push","route":"/orders/:id","name":"delivery-detail","params":{"id":"d-42"},"ts":"2026-07-02T10:30:15.000Z"}
```

| field   | meaning |
|---------|---------|
| `evt`   | `push` \| `pop` \| `replace` |
| `route` | route path / pattern (query-stripped) |
| `name`  | route name for named routes; location otherwise (query-stripped) |
| `params`| path params / route arguments (sensitive keys redacted) |

> Query strings are **never** logged — they can carry tokens (`?resetToken=…`).
> Because a `NavigatorObserver` only sees `RouteSettings.name`, `route` and
> `name` coincide for go_router named routes; both are always query-stripped.

### 2. API calls — `t: "api"`

Emitted by `DiagDioInterceptor`, added to the shared `DioClient` factory.

```json
{"t":"api","m":"GET","path":"/v1/requests","status":201,"ms":123,"reqId":"corr-42","ts":"2026-07-02T10:30:15.000Z"}
```

| field    | meaning |
|----------|---------|
| `m`      | HTTP method (upper-cased) |
| `path`   | request path, **query-stripped** |
| `status` | HTTP status; `null` on a transport failure (timeout/no response) |
| `ms`     | wall-clock duration in milliseconds |
| `reqId`  | `x-correlation-id` / `x-request-id` header if present (an opaque trace id, not a secret) |

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
