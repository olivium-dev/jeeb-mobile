# Pre-run checklist

## Authorization and scope

- [ ] The exact JMS scenario IDs are listed.
- [ ] This run is separately authorized; the scenario document alone is not authorization.
- [ ] Environment is the exact authorized lane named by the run. The current
      store-candidate lane is staging at `https://app.jeeb.fds-1.com`; production
      remains out of scope.
- [ ] DNS/configuration is checked and nothing can communicate with the
      forbidden host named in workspace policy.
- [ ] External SMS, push, social, KYC, map, or Clarity activity has explicit test-mode approval.
- [ ] Live staging probes prove normal OTP is available, Super Login Plus and
      demo users are closed, voice is real, WSS upgrades, and the association
      files are live before a store/device scenario starts.

## Build and app

- [ ] Git SHA, branch, flavor, version, package ID, signing identity class, artifact path, size, and SHA-256 are recorded.
- [ ] The artifact is freshly built and installed cleanly when the scenario requires it.
- [ ] Release tests use the exact release candidate, not a debug substitute.
- [ ] For store/OS scenarios, the candidate was installed from Play Internal
      Testing or TestFlight; no sideload, simulator, custom scheme, or direct
      intent is substituted.
- [ ] Package/bundle is `com.olivium.jeeb`, Firebase project is `jeeb-5a293`,
      and the native registration IDs match the artifact.
- [ ] Stable semantic identifiers are visible; no new flow relies on coordinates or localized text.

## Synthetic data

- [ ] Every account is synthetic, owner-controlled, adult, disposable/resettable, and identified by alias only.
- [ ] Request/chat/location/KYC/evidence content is visibly synthetic and non-sensitive.
- [ ] No credential, phone, OTP, token, account ID, precise location, or media value appears in the run plan.
- [ ] Before-state is captured for every entity that may change.
- [ ] A unique non-sensitive run nonce and cleanup owner are assigned.

## Mutation safety

- [ ] R0/R1/R2/R3 mutation class is recorded.
- [ ] R2/R3 writes have explicit confirmation and an idempotency/reconciliation plan.
- [ ] Unknown-result recovery queries current state before retry.
- [ ] Account deletion uses a dedicated disposable account and is treated as irreversible.
- [ ] KYC media, messages, pushes, location, support/dispute evidence, and Clarity use synthetic content only.
- [ ] COD scenarios simulate direct cash only and cannot call any electronic payment/refund path.

## Device matrix

- [ ] Android emulator/API target recorded.
- [ ] Mid-range physical Android recorded.
- [ ] High-end physical Android recorded where performance/graphics matter.
- [ ] iOS simulator recorded where supported.
- [ ] Physical iOS recorded for RC native permissions/push/VoiceOver/social flows.
- [ ] Android App Link and iOS Universal Link verification state is recorded
      for JMS-LINK-001, including association-file hashes and redirect count.
- [ ] OS version, locale, font scale, screen size/orientation, battery saver,
      permissions, connectivity, time zone, and available storage are recorded.
- [ ] Any unavailable platform/device is BLOCKED with reason, not silently skipped.

Pre-run decision: READY / NOT READY
Approver:
Timestamp:
