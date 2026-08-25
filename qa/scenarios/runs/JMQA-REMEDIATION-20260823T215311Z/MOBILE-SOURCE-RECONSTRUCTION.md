# Mobile source reconstruction runbook

> Status: SOURCE RECONSTRUCTED AND HARDENED; REMOTE CI, INDEPENDENT REVIEW, AND STORE ARTIFACT REBUILD REQUIRED
>
> Source snapshot: `origin/main` / `a8810345` plus the preserved working-tree
> overlay audited at 2026-08-24 14:44 UTC

## Objective

Recreate the exact passing mobile release source in clean, reviewable worktrees
without committing the current mixed index, losing user work, or importing raw
device/signing evidence. The reconstructed revision must preserve the green
source gate, explain each intentional count change, and then produce newly
inspected AAB and IPA artifacts whose hashes are bound to that revision.

## Frozen input facts

| Item | Audited value |
|---|---|
| Base revision | `a8810345`, equal to `origin/main` at audit time |
| Staged tracked paths | 60 |
| Unstaged tracked paths | 92 |
| Paths present in both sets | 19 |
| Unique changed tracked paths | 133 |
| Untracked paths | 245 |
| Current index | Not build-coherent; must not be committed |
| Full working-tree source suite | 7,868 passed, 66 skipped, 0 failed |

The 19 staged/unstaged collision paths are:

```text
.github/workflows/ci.yml
.gitignore
ios/Flutter/Profile.xcconfig
ios/Podfile.lock
ios/Runner/Runner.Release.entitlements
lib/core/config/app_config.dart
lib/core/session/session_cubit.dart
lib/l10n/app_ar.arb
lib/l10n/app_en.arb
pubspec.lock
pubspec.yaml
test/core/session/session_cubit_test.dart
test/mobile_release_contract_test.dart
tool/build_unsigned_ios_release_contract.sh
tool/check_ios_dependency_ownership.sh
tool/inspect_unsigned_ios_release.sh
tool/run_with_ios_firebase_config.sh
tool/test_ios_firebase_config.sh
tool/validate_ios_google_service_info.sh
```

For every collision, the intended final content is the preserved working-tree
file, not the staged/index version in isolation. Tests move with the product
implementation they require.

## Prohibited inputs

Do not import or commit:

- `.codex-proof/**`, screenshots, device dumps, logs, binaries, archives, or
  signer/private-key material;
- `build/**`, protected Firebase/Maps files, provider credentials, OTPs,
  transcripts, tokens, or tester personal data;
- `firebase-debug.log` or generated local console diagnostics;
- Super Login Plus, demo-user, fake-provider, sideload, LAN, cleartext, UPG, or
  locked forbidden-host compatibility paths.

The existing dirty worktree is evidence and a reconstruction source only. Keep
it read-only until the new revision is independently accepted.

## Reconstruction lanes

Use stacked, clean branches/worktrees so file ownership never overlaps while a
writer is active. Each lane must include its implementation and dependent tests
in the same reviewable change.

| Order | Lane | Scope | Minimum gate |
|---|---|---|---|
| 1 | Clarity/privacy | Consent model/store/controller, adapter, navigator observer, settings surface, privacy documentation and tests | Consent-off network silence, redaction/privacy tests, focused analysis |
| 2 | Native release identity | `com.olivium.jeeb`, staging defines, Firebase templates, Maps restrictions, signing/entitlements, app links, API 36, launch assets, protected build/inspection tooling | Android/iOS release contracts and protected-config negative tests |
| 3 | Product auth surface | Product entry removal of Super Login/Dev Tool and native seams; guarded developer entry remains separate | Store-entry auth-surface and binary forbidden-string tests |
| 4 | Realtime/chat | Scoped descriptor consumption, HTTPS→WSS resolution, unresolved compose-ID guard, chat screen/deep-link behavior | Resolver/gateway/deep-link contracts, no wildcard mint, no request for empty/`new` IDs |
| 5 | Delivery/KYC/navigation | Physical-QA-derived delivery, KYC, offer, wallet display, accessibility/localization, and route corrections | Affected widget/unit tests plus OMDS/RTL/accessibility checks |
| 6 | Scenario documentation | `qa/scenarios/**` only | 95 unique IDs, links/fences/JSON/supersession/secret scan |

If a path belongs to more than one lane, assign one writer and carry the final
combined content in the later dependent lane. Do not have parallel writers edit
the same branch or worktree.

## Freeze and verification checklist

- [x] Record the clean base revision and create the first isolated worktree.
- [x] Produce a sanitized path manifest; exclude every prohibited input above.
- [x] Delete the two legacy real Android Firebase client-config files from the
      reconstructed revision, retain only templates/protected injection, and
      retain the recorded provider restrictions/security disposition. Official
      Firebase guidance does not require rotation/history rewrite for this
      Firebase-only public client identifier.
- [x] Reconstruct each lane with implementation and its dependent tests.
- [x] Require each lane's focused tests, formatter/analyzer, diff check, and
      secret scan before review.
- [ ] Require the final stacked revision to have a clean index/worktree.
- [x] Run the exact full non-capture Flutter suite; source-bearing commit
      `e07d4542` passes 7,882, skips 66 intentionally, and fails 0. The two-test
      increase over merged head `8788a24d` is the passcode-fallback and
      cleartext-courier-socket regression coverage.
- [x] Run all release, identity, Firebase/Maps, no-Super-Login, no-Dev-Tool,
      transport, COD, and forbidden-host gates.
- [ ] Obtain independent mobile code, QA, Product Owner, Tech Lead, security,
      and CODEOWNER review for the exact final revision.
- [ ] Force-clean rebuild AAB and IPA from that revision using protected inputs.
- [ ] Inspect signatures, package/bundle, API, entitlements, staging origin,
      Firebase/Maps, association host, and forbidden surfaces.
- [ ] Repeat Apple validation and record new artifact hashes/sizes.
- [ ] Bind revision SHA, CI run, build logs, and artifact hashes in
      [REPORT.md](REPORT.md) without protected values.
- [ ] Only then evaluate Play Internal/TestFlight upload eligibility.

The clean reconstruction began as one coherent 188-file selection on
`release/staging-store-reconstruct-20260824` from base `a8810345`, committed as
`e208a4c8`, then reconciled with main in `8788a24d`. Source-bearing security
commit `e07d4542` removes the committed development passcode fallback and
requires WSS for courier tracking outside the dev flavor. Its CI-equivalent
suite passes 7,882 tests with 66 intentional skips and zero failures in about
329 seconds; its focused security suite passes 22/22 and focused fatal-info
analysis is clean. Prior full analysis, privacy/chat/release, protected native
configuration, signing-negative, dependency-ownership, diff, and secret gates
remain green. An unsigned iOS Release compiled successfully after removing only
rebuildable local caches. No signed store candidate has been rebuilt from an
approved final commit.

## Abort conditions

Stop reconstruction and preserve evidence if any selected path contains a
secret, raw personal/device data, an unexplained generated binary, an
unreviewed payment path, a forbidden host, or a required change whose ownership
cannot be determined. Do not resolve uncertainty by dropping the file or
committing the current index.
