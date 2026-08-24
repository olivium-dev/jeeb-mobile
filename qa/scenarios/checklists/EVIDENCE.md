# Evidence and privacy checklist

## Minimum evidence

- [ ] Scenario ID, run ID, UTC timestamp, build SHA, artifact hash, device/OS,
      environment, locale, and network profile are attached.
- [ ] Precondition and expected starting state are visible.
- [ ] Primary action and resulting target/state are visible.
- [ ] Receiver-side evidence exists for chat, push, offer, delivery, and other cross-actor outcomes.
- [ ] Server/product read-back exists for every write and includes only aliases/nonces.
- [ ] Store-gated evidence identifies Play Internal Testing or TestFlight,
      store build number, installed package/bundle, and artifact SHA-256.
- [ ] JMS-LINK-001 includes sanitized association-file HTTP metadata/body hash,
      OS verification state, external tap, handoff, target, and back-stack proof.
- [ ] Cleanup and final state are proven.
- [ ] Failure evidence identifies the exact failing step and category.

## Privacy review

- [ ] No real face, identity document, name, phone, email, address, precise
      location, account ID, delivery/request ID, private chat, OTP, token, or credential is readable.
- [ ] Screenshots/videos are cropped or redacted without hiding the tested outcome.
- [ ] Logs/network traces redact authorization, cookies, device tokens, payload text, and identifiers.
- [ ] KYC/chat/dispute attachments are synthetic and raw files are not versioned.
- [ ] Clarity dashboard evidence is masked and uses only canonical screen names.
- [ ] A human reviewer inspected every shareable artifact after automated redaction.
- [ ] Secret scan passes on the evidence folder.

## Provenance

- [ ] Evidence files have descriptive synthetic names.
- [ ] SHA-256/checksum is recorded for material artifacts.
- [ ] Source device/tool and capture method are recorded.
- [ ] Retention and deletion owner/date are recorded for ephemeral evidence.
- [ ] Existing .codex-proof content is not moved or staged accidentally.
- [ ] Installation evidence proves no debug, sideloaded, or developer-seam app
      supplied a store/OS acceptance result.

Reviewer:
Review decision: SHAREABLE / PRIVATE-ONLY / DESTROYED
Review timestamp:
