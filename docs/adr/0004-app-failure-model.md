# ADR 0004 — One failure model and one presentation contract

Date: 2026-09-06. Status: implemented on draft PR #335; integrated runtime, device and release acceptance remain separate gates.

## Decision

`AppFailure` (`lib/core/network/app_failure.dart`) is the sealed failure model. `AppFailure.of` and `AppFailureInterceptor` (`lib/core/network/app_failure_mapper.dart`) adapt transport errors once; `GatewayProblem` (`lib/core/network/gateway_problem.dart`) parses structured problem details. Feature state carries a typed failure, not transport prose. The shared `failureCopy` resolver (`lib/core/widgets/jeeb/app_failure_copy.dart`) and the presentation kit — `lib/core/widgets/jeeb/jeeb_failure_block.dart`, `jeeb_snack.dart`, `jeeb_refresh_failed_note.dart`, `jeeb_state_host.dart` — select presentation and localized actions.

## Contract for feature and branch integration

- Catch `AppFailure` subtypes, never `DioException`, above the transport boundary (RULINGS R3, PLAN-P10 §6.2). `AppFailure.of`, `AppFailureInterceptor` and the `lib/features/**/data/` adapters own transport exceptions; cubits, widgets and any branch rebased onto this see typed failures only. The transport catches still standing in `lib/features/deep_link_targets/chat_detail_screen.dart` and `lib/features/auth/social/social_auth_service.dart` are outstanding debt, not precedent.
- Repositories report failed reads as failures, never fabricated empty collections. Keep healthy sources visible when a sibling read fails. Preserve drafts and previously loaded data on failed refresh; refresh does not enter a cold-loading state.
- Render failure before empty. An unrecoverable state offers a meaningful exit, not an inert retry. Recovering authentication failures remain retryable without implying the session was terminated.
- Use `<screen>_loading`, `<screen>_empty`, `<screen>_error`, and error-rung `<screen>_retry_cta` or `_exit_cta`. An empty block's action is `<screen>_empty_retry_cta`. Add exact identifier classification and EN/AR semantic assertions.
- Only `NetworkFailure(offline: true)` and timeouts may blame connectivity. An unreachable destination uses the distinct Jeeb-unreachable copy, including when reachability is unknown. `NetworkFailure.reason` is diagnostic evidence, not the copy discriminator. Legacy enum adapters use `networkFailureFromReachability()`.
- Reconnect can invalidate both offline and unreachable failures; server failures stay until answered or explicitly dismissed. Snacks remain bounded: four seconds without an action, eight with one. The positive `JEEB_DEV_SNACK_ACTION_MS` override is dev-affordance-gated; explicit caller durations take precedence. Causal diagnostics do not include request URLs, credentials or raw exception prose.
- Reuse the shared failure copy instead of adding feature-local failure resolvers. Maintain EN/AR resources and hand-authored accessors together; preserve the owner's Levantine register decision. No generated localization replacement.
- Audit all interface implementors, including catalog fixtures, before changing a repository signature. Prefer classified exceptions or a narrowly scoped companion interface over widening an existing contract.

The OMDS error-snack, state-widget, bare-refresh and title-as-headline ratchets now have zero ceilings in their documented scopes. The separate exact-identifier assertion debt ceiling is still 26; this is outstanding coverage debt, not permission to add missing assertions. Design-token checks are diff-scoped. Never regenerate catalog goldens to silence a behavior failure.

## Branch notes

- **PR #328** (open on 2026-09-07): after #335 lands, `.github/workflows/flutter-ci.yml` resolves as the union of both sides — the Firebase-identity step and the design-token step, keeping `fetch-depth: 0`; `lib/app/app.dart` keeps the `OfflineCubit` provider and `OfflineBannerHost`.
- **PR #268** (open on 2026-09-07): no overlapping file; merge main normally.
- **Any branch adding a screen**: ship `<screen>_loading`, `<screen>_empty`, `<screen>_error` and `<screen>_retry_cta` identifiers with EN/AR tests, a catalog fixture under `lib/devtool/catalog/fixtures/` plus its catalog entry, and a preview. The preview floor in `test/previews/preview_structure_test.dart` is 247 and only ever rises.
- **Carried owner-confirm items** (Reconciled C14, not blockers for #335): (a) DM-onboarding submit route constant → P01; (b) gateway `/v1/notifications` rows carrying `ref` for offer rows only → P02; (c) create-request description min-length validation → P03; (d) the stray test request → P04; (e) ratchet residuals → P05.

## Related work and acceptance boundaries

P02 adds notification kinds while retaining canonical `ref` and existing parser fallbacks; chat navigation must preserve inbox Back behavior. Gateway target projection and post-deploy captures are still distinct work. P03 binds description validation inline and versions acknowledgments; backend validation/moderation acceptance needs its gateway change. P01 v3 governs onboarding preparation and its gated route flip.

Wallet integration follows the corrected P15 dependency train, not the old epic integration suggestion. Check current source heads and shared Program/config/registry/OpenAPI changes before preparing that train. Historical PR overlap lists are not current merge evidence.

This ADR authorizes no deployment, migration, upstream security filing, merge or release. The latest continuation report distinguishes local code, executed checks, unexecuted checks and owner gates; previous build/device evidence cannot validate a newer head.
