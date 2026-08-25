# Microsoft Clarity mobile analytics

Jeeb's Microsoft Clarity project is `y6laxxj143`. A Clarity project ID is
public routing configuration, not a credential. The app deliberately has no
committed Dart default for it.

## Build configuration and kill switch

Production capture requires all three defines on a release build:

```text
--dart-define=JEEB_CLARITY_ENABLED=true
--dart-define=JEEB_CLARITY_PROJECT_ID=y6laxxj143
--dart-define=JEEB_CLARITY_PRIVACY_APPROVED=true
```

`JEEB_CLARITY_ENABLED` defaults to `false`, and
`JEEB_CLARITY_PROJECT_ID` defaults to empty. Missing, disabled, malformed, or
non-release configuration prevents SDK initialization.
`JEEB_CLARITY_PRIVACY_APPROVED` also defaults to `false`; the release owner may
set it only after the privacy, minor-use, and store-disclosure gates below are
approved. Debug, profile, tests, CI, catalog previews, and `DevToolApp` never
capture. Omitting `JEEB_CLARITY_ENABLED` is the shipment kill switch, but a
rebuild cannot stop already-installed versions. Before production enablement,
the release owner must also verify and document the Microsoft project-side
emergency stop used for an immediate incident response.

## Consent, identity, and masking

Clarity is independent of marketing-notification preferences. Jeeb uses a
three-state `unknown / granted / denied` choice under the versioned local key
`privacy.clarity_consent.v1`; a missing, corrupt, or unreadable value is
`unknown` and therefore off. Denial persists. A grant is deliberately valid
only for the current app process: after a process restart any stored grant is
cleared best-effort and read as `unknown`, so the user must opt in again.

Capture starts only when all four gates are open: release build configuration,
an authenticated Jeeb session, an explicit current-process grant, and a valid
product UI context after the first frame. Grant applies ads consent `false` and
analytics consent `true`. The SDK lifecycle/gesture wrapper is mounted only
after those gates initialize Clarity, preserving heatmap input and foreground /
background visibility without any pre-consent capture. Revocation closes the in-memory gate immediately,
then applies analytics consent `false`, confirms the SDK is paused, and
persists denial with bounded retries. A failure remains visibly actionable in
Settings. Storage or SDK failures keep the application gate closed and never
block startup or account flows.

The whole bootstrap and routed product UI are wrapped in `ClarityMask`,
including the splash, push banners, and overlays. There are no
`ClarityUnmask` sites. Before release, a Clarity
project administrator must also set the dashboard masking mode to **Strict**;
the app-side mask is defense in depth, not a substitute for that admin control.

Jeeb never sends an account ID, custom user ID, custom session ID, custom tag,
custom event, route parameter, URI, query string, route extras, semantic ID, or
user-entered text. Navigation reports only a closed allowlist of canonical
screen names such as `chat-detail` and `transaction-detail`. Unknown input is
reported as `unknown`. Backgrounding pauses capture; resume still passes all
configuration, authentication, and consent gates. Logout, account deletion,
and terminal 401 auth loss create a new anonymous Clarity session boundary,
pause, and clear the local grant. A later login—including another account on
the same device—must explicitly opt in again.

## Supported capture matrix

| Platform | Validated capture range | Lower Jeeb OS floors |
| --- | --- | --- |
| Android | API 29–36 | The app still runs from minSdk 24, but Clarity does not send below API 29. |
| iOS | iOS 15–18 | The app still runs on iOS 14, but Clarity does not send there. |

The Jeeb platform floors remain Android 24 and iOS 14; do not raise them for
analytics.

## Release gates

No production enablement is permitted until all of these are complete:

- Privacy review approves the disclosure, retention, Microsoft subprocessor
  treatment, and handling for minors/minor-use accounts.
- Google Play Data safety and Apple App Privacy/store disclosures accurately
  describe masked session recordings and interaction analytics.
- A Clarity administrator confirms Strict masking in project `y6laxxj143`.
- Synthetic Android and iOS validation passes using test-only accounts and
  non-sensitive content: grant, capture an allowlisted navigation sequence,
  verify masked playback/heatmaps, revoke, confirm capture stops, log out,
  confirm the anonymous session boundary, and exercise the build kill switch.
- The static privacy gate and focused consent/controller/navigation/UI tests
  pass on the exact release candidate.

## Validation caveat

Do not use real customer or courier data to validate this integration. This
repository and its automated tests cannot prove dashboard ingestion, Strict
masking configuration, store-console disclosures, or Microsoft-side deletion
and retention behavior. Those checks require the synthetic device run and
administrator evidence described above. Until that evidence exists, keep the
production define off and treat the dashboard as containing no approved
production data.
