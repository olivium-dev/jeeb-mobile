# CTO rulings — ux/api-error-handling-empty-states (2026-09-05)

These resolve the "Critic gaps" in UX-API-AUDIT.md. They are binding on every implementer.

## R1 Execution shape
- Stage 0.0: `app_failure.dart` + `gateway_problem.dart` (model only) land first.
- Stage 0: WP-0A (network/session/offline/DI) and WP-0B (kit/copy/ARB/gates) in parallel, same worktree, disjoint files. Neither imports the other's NEW files. WP-0A keeps `_BootstrapErrorApp` on `JeebEmptyState`; conversion to `JeebFailureBlock` is a Stage-1 core follow-up.
- Stage 1: WP-1..8 in parallel in the same worktree. Stage 2: integration (DI wiring, catalog entries, WP-9 ARB consolidation) by ONE agent. Then review gate, then device validation.

## R2 Collision surfaces (never edited by feature WPs in Stage 1)
`lib/l10n/**`, `lib/core/di/injection_container.dart`, `lib/core/router/app_router.dart`, `lib/devtool/catalog/entries/**`, `lib/main.dart`, `lib/core/notifications/application/push_notification_handler.dart`, `lib/core/widgets/jeeb/**`, `lib/core/network/**`.
- Missing ARB key in Stage 1 → use the nearest shared key (`errorGenericBody`, `actionRetry`, …) AND append the wanted key to `$SCRATCH/stage1/missing-keys-<wp>.md` (key, en, ar, where). Stage 2 adds them and swaps.
- New repository needing DI → create `lib/features/<feature>/<feature>_di.dart` exposing `void register<Feature>Dependencies(GetIt getIt)`; Stage 2 calls it from injection_container. Screen keeps the existing `_resolveRepository()` seam with an `isRegistered` guard.
- New catalog states → put fixtures under `lib/devtool/catalog/fixtures/<feature>_*` and list the wanted `CatalogState` entries in `$SCRATCH/stage1/catalog-entries-<wp>.md`; Stage 2 appends them to the batch files. Never delete a catalog entry.
- No screen/route deletions in Stage 1 (UX-05, CUNR-01, PIR-01, LR-35: fix in place, do not delete).

## R3 `implements`-widening trap
Before changing ANY method signature or return type on a repository/gateway/service interface, grep all implementors (`grep -rn "implements <Name>\|extends <Name>" lib test`). If any implementor is outside your fence (esp. `lib/devtool/**`, `test/**` of another WP), you MUST NOT change the signature. Prefer: throw an `AppFailure` subtype (no signature change) over new result types; where an outcome type is truly needed, add a NEW method with a new name on a NEW small interface and keep the old one. NET-05/F3/F5/UX-15/UX-16/DMP-01: apply this rule.

## R4 Kit decisions (WP-0B)
- `JeebEmptyState.identifier` stays optional + `assert(identifier == null || identifier.isNotEmpty)`. Add `reason`, `secondaryAction`, `liveRegion`. `status:` remains valid.
- `JeebFailureBlock` default + `JeebFailureBlock.compact` named constructor (kit convention).
- `showJeebErrorSnack` passes explicit `backgroundColor: colorScheme.errorContainer` + `contentTextStyle` (theme hard-codes surfaceHigh). `showJeebSuccessSnack` reads `JeebColorRoles.of(context).successContainer`.
- Plural sets (`errorRateLimitedRetryIn*`, `registrationOtpRateLimitedSeconds*`, `otpHandoverAttemptsRemaining*`) are the sanctioned `l10n.x(n)` exception; add bases to `test/l10n/plural_forms_test.dart`.
- Guardrail tests ship as RATCHETS: measure today's count of banned patterns (`showOmdsErrorSnackbar`, raw `ScaffoldMessenger.showSnackBar` in features, bare `OmdsPullToRefresh`, `OmdsErrorState`/`OmdsLoadingState` in features, English literals returned from `_mapError`-shaped functions) and assert count <= floor. Stage 2 lowers floors to 0.
- `test/previews/preview_structure_test.dart` INV-7 floor 247: every new widget ships previews + preview test in the same change. Never raise the floor.

## R5 Ownership additions (from critic A1/A2/A4)
- `lib/features/photo_attachment/**` → WP-7. `lib/features/shell/tabs/home_tab.dart` → WP-3. `lib/features/shell/tabs/dashboard_tab.dart`, `shell_screen.dart`, `tab_visibility.dart`, `widgets/jeeber_tab_empty_state.dart` → WP-2. `shell/tabs/profile_tab.dart` → WP-8. `lib/features/onboarding/**` → WP-8 (confirm no network surface). `lib/core/realtime/phoenix_v2_frame.dart` bare catch → WP-1. `lib/core/observability/session_trace/audited_interaction_identifiers.dart` → WP-0A. `lib/features/deep_link_targets/dev_chat_detail_fixtures.dart` → WP-1. `account_status` refresh-blanks + 44th enum → WP-8. `onboarding_funding_screen.dart:349` title-as-headline → WP-5. All 12 `OmdsErrorState`/16 `OmdsLoadingState` production sites go to the WP that owns the file.
- `*_l10n.dart` facades: owned by the feature WP whose tree contains them (reduce to accessors where WP-0B budgeted keys; otherwise leave). WP-9 = Stage 2 only touches `lib/l10n/**` + dead-key deletion.
- SHELL-03: `DeliveryStatusAlias` does not exist; use `OrderRequestStatus.parse` (lib/features/order_history/domain/order_summary.dart:15) read-only import.

## R6 Non-negotiables in every change
- Comments max 2 lines, avoid unless necessary. No new `*_l10n.dart` resolvers. No `e.toString()`/`$e` in user-facing text. Error branch before empty branch. `refresh()` never flips to loading. Only Network/Timeout failures blame connectivity. Unrecoverable kinds get an exit CTA, never inert Retry. Identifier triple `<screen>_loading|_empty|_error` + `<screen>_retry_cta`, `container: true`. Tests assert by `find.bySemanticsIdentifier`, pump EN+AR, `useReduceMotion(tester)` before pumpAndSettle over JeebEmptyState.
- `git add` every new file BEFORE running `flutter test` (mb1 residual-receipts test fails on untracked .dart). Never `--update-goldens` on catalog_capture. Gate = `dart analyze --fatal-infos .` (not `flutter analyze`) + `flutter test --exclude-tags capture`. Baseline on this worktree: analyze clean, 8257 pass / 0 fail.

## R7 Stage-1 rulings after the lane cross-check (stage1/CROSS-CHECK.md)
- WP-8 is SPLIT: WP-8a (auth & identity: registration, auth, biometric_login, biometric_auth, password_security, profile_name, language, lib/core/locale/**; carries the V1 `OtpSendResultService` fix — no mixin on OtpService) and WP-8b (settings, account_status, notification_prefs, kyc, kyc_rejected, offer_kyc_gate, jeeber_onboarding, shell/tabs/profile_tab.dart, lib/core/session/jeeber_kyc_status_gate.dart, lib/core/onboarding/**, lib/core/router/profile_unavailable_screen.dart, lib/core/notifications/presentation/**).
- `lib/features/offline_mode/**` = WP-0A (Stage 0). `lib/core/router/app_router.dart` = nobody in Stage 1 (Stage 2 wanted list). Screen/route deletions: none.
- Ordering: WP-2 does item 73 (banner catch) FIRST; WP-1 does A2.1 (fetchAccepted throws) LAST. WP-2 re-runs dashboard_tab tests at the end (WP-8b widens JeeberKycStatus/Destination).
- Pre-Stage-1 core follow-up (single agent, after Stage 0 commit): append the 73 net-new ARB keys from CROSS-CHECK §4 (EN+AR+accessors), `JeebFailureBlock(retryIdentifier:)` / `exitIdentifier:` overrides, `showJeebSnack(duration:)`, confirm `JeebFailureBlock.compact` + optional `identifier`, `_BootstrapErrorApp` → JeebFailureBlock.
- Lanes scope `dart analyze` to their own dirs while Stage 1 runs (other fences may be transiently red); the whole-tree gate runs once in Stage 2.
- UX-05 (DM onboarding submit): WP-8b verifies the route in gateway source (`git -C jeeb-gateway show origin/main:<file>` after fetch); if found, wire it; if not, land the fail-safe contract (404/405/501 resolve, 409 typed, else AppFailure) against the documented path and record it in stage1/OWNER-CONFIRM.md.
