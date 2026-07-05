# Super-login (debug-only test auth)

Two debug-only affordances on the **login** screen let a tester sign in as a real
backend user without the phone/OTP funnel. Both are `kDebugMode`-gated and
dead-code-eliminated from release builds. Neither ever mints a client-side token —
they exchange a passcode with the gateway for a **real** gateway session.

## The two entry points

| Link | Flow |
| --- | --- |
| **Super user login** | Opens a credential sheet pre-filled with a dev userId + the SuperAdmin passcode. Submits `POST /api/User/user-id-login`. |
| **Super user login plus** | Opens a picker of demo users (`GET /api/User/demo-users`), then the same sheet pre-filled with the tapped user's `userId`. |

Both end at the same call: `POST /api/User/user-id-login` with
`{ userId, superAdminPassCode }`. On success the app persists the **real**
gateway `authToken`/`refreshToken` via `AuthTokenStore`.

## Endpoints (what the client calls)

- **Roster:** `GET /api/User/demo-users` — anonymous, no body. Returns
  `{ users: [ { userId, name, role, passcode } ] }` in one shot (no pagination).
  The client **ignores** each row's `passcode`; it re-uses the single passcode
  from `AppConfig`.
- **Login:** `POST /api/User/user-id-login` with `{ userId, superAdminPassCode }`.
  Returns a gateway-minted `{ userId, authToken, refreshToken? }`.

## The passcode

`AppConfig.superAdminPassCode` resolves in order:
1. `--dart-define=JEEB_SUPERADMIN_PASSCODE=<value>` (any build), else
2. in `kDebugMode` a committed dev fallback, else
3. empty (release — the surface is gated out anyway).

`tool/run_msi_dual.sh` does **not** pass the define, so device runs use the debug
fallback. The passcode is sent in the login body only; it is never logged (the
debug HTTP logger redacts it, including nested roster `passcode` fields).

## Gateway prerequisites (owner-controlled config)

- `SuperLogin__OpenMode=true` — required for `GET /api/User/demo-users` to serve
  the roster (default `false` → 404, prod-safe). Set on the MSI demo env.
- `DemoUsers__*` — the roster rows (userId/name/role/passcode).
- `SuperAdmin__PassCode` — the passcode user-management validates on
  `user-id-login`. **This must match the passcode the app sends** (the
  `AppConfig` fallback / `--dart-define`). The roster row `passcode` is unrelated
  to login (the client discards it).

## Reliability notes

- The gateway tolerates the upstream user-management returning **201 Created**
  (not 200) on `user-id-login`: it extracts the `userId` and mints its own
  gateway session, so a correct passcode always yields a usable session.
- If the passcode is missing entirely, the plus/basic links surface an explicit
  "Dev build missing SuperAdmin passcode" message instead of a generic gateway
  error.
