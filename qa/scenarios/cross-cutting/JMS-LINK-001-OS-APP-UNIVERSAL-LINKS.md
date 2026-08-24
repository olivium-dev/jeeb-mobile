# JMS-LINK-001 — OS-verified App Link and Universal Link

> Result: **NOT RUN**
>
> Owner: Android QA + iOS QA
>
> Last verified: Never

This release-candidate scenario proves that Android and iOS trust Jeeb's HTTPS
association files and hand a real Jeeb link to the installed store build. An
in-app router test, custom `jeeb://` scheme, `adb am start`, simulator launch,
sideloaded build, or browser redirect does not satisfy this scenario.

Execute it with the [pre-run checklist](../checklists/PRE-RUN.md), a copied
[per-scenario record](../checklists/PER-SCENARIO.md), and the
[evidence/privacy checklist](../checklists/EVIDENCE.md).

## Contract

| Field | Value |
|---|---|
| Priority / gate | P0 / Release candidate |
| Platforms | Android from Play Internal Testing; iOS from TestFlight |
| Native identity | `com.olivium.jeeb` |
| HTTPS host | `app.jeeb.fds-1.com` |
| Android association | `/.well-known/assetlinks.json` names `com.olivium.jeeb` and the **Play app-signing** certificate |
| iOS association | `/.well-known/apple-app-site-association` names `K5RDQ8J7AN.com.olivium.jeeb` |
| Target | One authorized `/chat/<synthetic-conversation-id>` fixture, with the real identifier redacted from evidence |
| Mutation | R0 link opening; the fixture is prepared and cleaned under its owning scenario |

## Preconditions

- [ ] The exact Android AAB and iOS IPA hashes in the run record are the builds
      delivered by Play Internal Testing and TestFlight.
- [ ] The apps were installed from those store channels after uninstalling any
      debug, developer-seam, or sideloaded copy.
- [ ] Android reports the domain as verified for `com.olivium.jeeb` and the
      served `assetlinks.json` includes the Play app-signing SHA-256, not merely
      the local upload-key certificate.
- [ ] iOS retrieves a valid AASA file without redirect, with JSON content type,
      and the signed app contains the matching Associated Domains entitlement.
- [ ] A synthetic, account-authorized conversation exists; the other account
      and an unknown/unauthorized identifier are available for negative checks.
- [ ] Normal phone/OTP authentication is used. Super Login Plus, demo users,
      mock transport, and crafted local role/KYC state are disabled.

## Acceptance scenarios

```gherkin
Feature: Operating-system verified Jeeb links
  As an authenticated Jeeb user
  I want a trusted HTTPS Jeeb link to open in the installed store app
  So that the operating system does not send me through an unsafe redirect

  Scenario: Store-delivered app opens an authorized HTTPS chat link
    Given the store-delivered Jeeb app is installed and the OS trusts the host
    And the current synthetic account may read the linked conversation
    When the user taps the HTTPS link outside Jeeb
    Then the operating system opens Jeeb without an app chooser or browser hop
    And Jeeb opens the authorized chat once with the correct safe back stack

  Scenario: Unauthorized HTTPS chat link fails closed
    Given the current synthetic account may not read the linked conversation
    When the user taps the HTTPS link outside Jeeb
    Then Jeeb shows the canonical unavailable or authorization surface
    And no protected chat content flashes before the rejection

  Scenario: Missing app falls back without claiming verification
    Given Jeeb is not installed on the device
    When the user opens the same HTTPS link
    Then the HTTPS service returns its documented safe web or store fallback
    And no custom-scheme loop or sensitive query value is exposed
```

## Required execution matrix

| Platform | Lifecycle | Source surface | Required observation |
|---|---|---|---|
| Android | Terminated and background | Chrome plus an OS message surface | Play-delivered app owns the verified link and opens exactly once |
| iOS | Terminated and background | Safari plus an OS message surface | TestFlight app receives the Universal Link and opens exactly once |
| Both | Authenticated wrong account | Same external link | Authorization fails closed before protected content |
| Both | Logged out | Same external link | Intent is retained only through normal auth and resumes once after authorization |

## Evidence and cleanup

- [ ] Record store channel, store build number, artifact SHA-256, package/bundle,
      device, OS, UTC timestamp, lifecycle state, and synthetic fixture alias.
- [ ] Retain sanitized HTTP status, content type, redirect count, and body hash
      for both well-known association files.
- [ ] Retain Android domain-verification state and iOS signed-entitlement proof;
      do not record device tokens, cookies, account IDs, or raw entity IDs.
- [ ] Screen-record the tap outside Jeeb, OS handoff, final target, and back
      destination; redact the link identifier and all chat content.
- [ ] Prove the authorized and unauthorized results through server read-back.
- [ ] Remove the synthetic conversation fixture and verify final state.

## Pass and stop rules

PASS requires every row in the execution matrix on the store-delivered builds.
Mark BLOCKED if either association file, store channel, device, normal OTP, or
fixture is unavailable. Mark FAIL if the browser remains open, an app chooser
appears after verified setup, the wrong app opens, the target opens twice, or
protected data flashes. Never replace a blocked store-delivery check with a
sideload, custom scheme, simulator, direct intent, or mock.
