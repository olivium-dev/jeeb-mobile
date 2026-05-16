# Test Plan — Live GPS Tracking

Maps to: **FR-8.3**, **US-7.1**
Backend: `geolocation-service` (Python FastAPI) + `realtime-comunication-service` (Elixir Phoenix Channels)
Owner: Mobile QA
Status: Draft v1 — JEEB-110

## 1. Scope

After the Jeeber sets the order to `picked_up`, the Client opens the
delivery detail screen and watches the Jeeber's pin move on a map. The
publish cadence is **every 5 seconds** (FR-8.3) and the staleness cliff
is **10 seconds** (no update for 2 cadences → "stale" badge).

In scope:
- Client-side rendering of live pin updates
- Jeeber-side GPS publication while in `picked_up` state
- Stale detection and recovery
- Geofence arrival detection at the drop-off
- Permission flows (location whileInUse / always, Android 14 partial-precise)
- Battery and accuracy under varied movement profiles

Out of scope:
- Map vendor switching (Google Maps vs Mapbox) — fixed at MVP
- Route preview / directions — separate ticket T-mobile-018

## 2. Architecture under test

```
[Jeeber app]                                             [Client app]
   │                                                          ▲
   │ POST /v1/locations  (every 5s while picked_up)           │
   ▼                                                          │
[geolocation-service] ──► Phoenix channel "delivery:{id}" ────┘
                          push every 5s, payload {lat,lng,heading,speed,accuracy,ts}
```

Invariants:

1. The Client never sees its own location echoed; only the Jeeber's.
2. The Jeeber stops publishing the moment status leaves `picked_up`
   (delivered, cancelled, or app killed gracefully).
3. The map's "last updated" timestamp is the *server-stamped* `ts`, not
   the device clock — so device-clock skew never lies about freshness.

## 3. Functional tests

### 3.1 Happy-path tracking (Client side)

| # | Step                                                                | Expected                                                                                  |
|---|---------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| 1 | Open delivery detail before Jeeber marks `picked_up`                | Map shows Client drop-off pin only; banner "Waiting for Jeeber to start the trip"        |
| 2 | Jeeber marks `picked_up`                                             | Within 5 s, blue pin appears at the Jeeber's location                                    |
| 3 | Jeeber walks 50 m down a street                                      | Pin moves smoothly with simple linear interpolation between updates (no teleporting)     |
| 4 | Jeeber stops at a traffic light                                      | Pin stays put; "Last updated 0s/2s/4s/0s ago" cycles back to 0 every cadence             |
| 5 | Jeeber marks `delivered`                                             | Live tracking stops; final position frozen on map; banner "Delivery complete"            |

### 3.2 Happy-path publishing (Jeeber side)

| # | Step                                                                  | Expected                                                                                  |
|---|-----------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| 1 | Tap "I picked up the order"                                           | Foreground service starts; persistent notification "Jeeb is sharing your location"        |
| 2 | Background the app for 10 minutes                                     | Updates continue every 5 s; Client confirms pin keeps moving                              |
| 3 | Lock the screen for 10 minutes                                        | Same — updates continue                                                                   |
| 4 | Force-stop the app from system settings                               | Client sees "stale" badge after 10 s, then "Tracking lost — Jeeber may have closed app"  |
| 5 | Tap "Delivered"                                                       | Foreground service stops within 2 s; persistent notification cleared                      |

### 3.3 Stale detection

| # | Scenario                                                                          | Expected mobile behaviour                                                            |
|---|-----------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| 1 | No update for 5 s (1 missed cadence)                                              | No visible change; "Last updated 5s ago" label updates                               |
| 2 | No update for 10 s (2 missed cadences)                                            | Pin grays out; badge "Pin may be outdated — last seen {time}"                        |
| 3 | No update for 60 s                                                                | Banner "Tracking lost. We're trying to reconnect."; ETA hidden                       |
| 4 | Recovery: update arrives after 60 s of silence                                    | Pin animates from old → new position over 1 s (visually obvious to user)             |
| 5 | Server timestamp goes backwards (out-of-order due to retry)                        | Older sample dropped silently; UI never moves backwards in time                      |
| 6 | Two updates arrive within < 1 s (catch-up after burst)                             | UI throttles to 1 update / 250 ms; pin still ends at the latest point               |

### 3.4 Accuracy

The payload includes `accuracy` (meters). Tests:

| # | Accuracy reported          | Expected                                                                              |
|---|----------------------------|---------------------------------------------------------------------------------------|
| 1 | ≤ 25 m (good GPS)          | Solid pin, no halo                                                                    |
| 2 | 25–100 m (degraded)        | Pin with translucent halo radius                                                      |
| 3 | > 100 m                    | Pin replaced with a translucent circle ("approximate location")                       |
| 4 | Sample with `accuracy=0`   | Treated as missing — sample dropped, last good position retained                      |

### 3.5 Geofence arrival

When the Jeeber pin enters a 75 m radius around the Client drop-off:

| # | Step                                                                      | Expected                                                                                           |
|---|---------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| 1 | Pin enters 75 m radius                                                    | Banner "Jeeber is nearby"; haptic on Client device                                                 |
| 2 | Pin leaves and re-enters within 60 s                                      | Banner does not re-fire (debounced)                                                                |
| 3 | Pin enters but accuracy > 50 m                                             | No banner — debounced until accuracy improves or pin moves further inside                          |
| 4 | Geofence enter while app is backgrounded                                  | Local notification fired (channel `delivery_arrival`)                                              |

## 4. Permissions

Per `mobile-accessibility-flow-tests` and `flutter-deep-linking-app-links`:

### 4.1 Jeeber-side prompts

| # | OS / version                  | Permission asked                       | Expected                                                                                       |
|---|-------------------------------|----------------------------------------|------------------------------------------------------------------------------------------------|
| 1 | Android 14                    | Foreground location → then "Allow all the time" | Two-step prompt; if user picks "Approximate" we show coach-mark "We need precise to track" |
| 2 | Android 13                    | Foreground location, then background    | After accepting `whileInUse`, status flip to `picked_up` triggers second prompt for `always` |
| 3 | iOS 17                        | While Using → upgrade to Always          | First prompt at sign-up; upgrade prompt only at `picked_up` (not earlier — App Store rule)   |
| 4 | Any                           | User denies                              | Cannot mark `picked_up`; CTA disabled with "Enable location to start the trip" + Settings link |
| 5 | iOS                           | Background revoked mid-trip              | App posts a foreground notification "Tap to resume tracking"; map on Client side goes stale  |

### 4.2 Client-side prompts

The Client only needs to *view* the map; no foreground service. Location
is requested only if the Client taps "Center on me".

## 5. Network resilience

| # | Disruption                                                                              | Expected                                                                                  |
|---|-----------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| 1 | Phoenix channel drops (server restart)                                                  | Client reconnect with backoff 1/2/4/8/15/30 s; pin stays at last position; "Reconnecting…" |
| 2 | Wi-Fi → cellular handoff during reconnect                                               | Reconnects within 5 s; no stuck banner                                                    |
| 3 | Jeeber loses network for 30 s while moving                                              | Jeeber-side queue holds samples (≤ 60 s); on reconnect, batch-send; Client sees catch-up animation |
| 4 | Jeeber loses network for > 60 s                                                         | Older samples dropped (server rejects > 60 s old); only the latest is published           |
| 5 | Server returns 429 (rate-limited Jeeber publish)                                        | Client retries with `Retry-After`; Client side simply sees a stale-badge during the gap   |

## 6. Battery and CPU

Run on Pixel 4a (Tier 2 device) with `adb shell dumpsys batterystats`:

| # | Profile                                              | Budget                                  |
|---|------------------------------------------------------|-----------------------------------------|
| 1 | 30-min stationary trip with screen off                | < 4% battery; CPU avg < 2%              |
| 2 | 60-min moving trip with screen on (Maps showing)      | < 12% battery                           |
| 3 | Background-only tracking, screen off                  | Foreground service notification persists; no thermal throttling warnings |

If any budget breaches: file Sev-2.

## 7. Movement profiles (synthetic GPX)

Use `mock_location_provider` (Android dev option) and Xcode location
simulator with these GPX traces shipped in `qa/fixtures/gpx/`:

| Profile          | File                       | What it stresses                                        |
|------------------|----------------------------|---------------------------------------------------------|
| `walking-15min`  | `qa/fixtures/gpx/walk.gpx` | Slow movement, frequent stops                           |
| `cycling-30min`  | `qa/fixtures/gpx/cycle.gpx`| Smooth medium-speed                                     |
| `driving-urban`  | `qa/fixtures/gpx/urban.gpx`| Tunnel section (GPS lost 90 s) → tests stale + recovery |
| `driving-highway`| `qa/fixtures/gpx/hwy.gpx`  | High speed, large pin jumps; tests interpolation        |
| `teleport`       | `qa/fixtures/gpx/jump.gpx` | 200 m sudden jump; pin must reject (likely spoof) and label "GPS jump detected" |

## 8. Map UI tests

| # | Scenario                                                       | Expected                                                                            |
|---|----------------------------------------------------------------|-------------------------------------------------------------------------------------|
| 1 | Tap "Re-center"                                                | Map re-frames to fit Jeeber + drop-off pins with 64dp padding                       |
| 2 | Pinch-zoom out                                                 | Auto-recenter disabled; banner "Auto-follow paused — tap to resume"                 |
| 3 | Rotate device                                                  | Map state preserved; no flicker                                                     |
| 4 | RTL locale (Arabic)                                            | Map controls (zoom, recenter) mirror to left side                                   |
| 5 | Dark mode                                                      | OMDS dark map style applied; pins remain high-contrast                              |
| 6 | Switch app → return after 10 min                               | Map state restored from BLoC; live updates resume without full re-fetch             |

## 9. Test inventory

### 9.1 Unit (`test/features/tracking/`)

- `location_sample_test.dart` — accuracy buckets, ts ordering, dedupe
- `staleness_calculator_test.dart` — fresh / warning / stale / lost transitions
- `geofence_test.dart` — enter/exit with debounce
- `interpolator_test.dart` — animation between samples; rejects backward time

### 9.2 Widget (`test/features/tracking/presentation/`)

- `tracking_map_widget_test.dart` — pin renders, halo respects accuracy
- `stale_banner_test.dart` — fresh/stale/lost states
- `permission_gate_test.dart` — denied / partial / granted flows

### 9.3 Integration (`integration_test/tracking/`)

- `flow_pickup_to_delivered_test.dart` — Patrol drives Jeeber side end-to-end with mocked Phoenix channel
- `flow_stale_recovery_test.dart` — fake clock jumps; asserts banners
- `flow_permission_test.dart` — Patrol grants/denies native dialogs

### 9.4 E2E (`qa/maestro/tracking/`) — added in T-qa-009

- `flow_two_device_tracking.yaml` — Maestro Cloud, two devices, real backend
- `flow_background_kill.yaml` — single device, force-stop mid-trip

## 10. Test data

Seeded in `jeeb-infrastructure/seeds/qa-tracking.sql`:

- Delivery `qa-delivery-tracking-001` — `picked_up` with active publisher, used as default test channel
- Delivery `qa-delivery-tracking-stale` — `picked_up` but no recent samples (stale-badge fixture)
- Delivery `qa-delivery-tracking-lost` — > 60 s with no updates (lost-tracking fixture)

## 11. Risks and assumptions

- **Assumption**: geolocation-service stamps `ts` server-side. If it
  trusts the device clock, every staleness test in §3.3 must instead
  test for skew tolerance (probably ± 30 s).
- **Assumption**: 75 m geofence radius is correct. PM has not signed
  off; if it changes, only §3.5 needs an update.
- **Risk**: Android 14 "approximate-only" location returns ~1 km
  precision — UI must not display a confidently-positioned pin in
  this mode. Tracked in §3.4 row 3 + §4.1 row 1.
- **Risk**: iOS 17 returns `kCLErrorDenied` once and then silently
  fails afterwards if the user revokes — we must observe `CLAuthorizationStatus`
  changes via `locationManager(_:didChangeAuthorization:)`. Tested
  in `flow_permission_test.dart`.
