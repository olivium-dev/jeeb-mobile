# PLAN P05 — Guardrail residuals: every ratchet floor to 0

Branch: `ux/api-error-handling-empty-states` @ `ecfd3cc1` (worktree
`/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`, base
`origin/main@ab610933`, draft PR https://github.com/olivium-dev/jeeb-mobile/pull/335,
verified `gh pr view 335` 2026-09-05: draft=true head=ecfd3cc1 state=OPEN).
Toolchain on this Mac: Flutter 3.44.2 stable (verified `flutter --version`).
Pure mobile change — no gateway edit, no deploy. Effort **M**.

---

## 0. Verified current state (what the ratchets actually count today)

Measured with the branch's own scanner (`test/guardrails/guardrail_sources.dart` —
`blankComments` + `scan`) via `$SCRATCH/p05/scan.dart`, run 2026-09-05 from the worktree root:

| Ratchet test | Scope | Floor today | Real hits today | Sites |
|---|---|---|---|---|
| `test/guardrails/no_omds_error_snackbar_test.dart` `showOmdsErrorSnackbar` | `lib` | **3** | **3** | `lib/core/observability/session_trace/presentation/widgets/obs_overlay_export_button.dart:33`; `lib/devtool/users/scenario_users_page.dart:109`; `lib/devtool/users/scenario_users_page.dart:123` |
| same file, raw `.showSnackBar(` | `lib/features` | 0 | 0 | (lib-wide there are 8 more in `lib/core/diagnostics` + `lib/devtool` — NOT this point, see §8) |
| `test/guardrails/no_omds_state_widgets_test.dart` `Omds(Error|Loading)State(` | `lib/features` | **1** | **0** | none — the only `lib/features` matches are doc comments (`chat_detail_screen.dart:1788,1927`, `reviews_list_screen.dart:178`, …) which `blankComments` strips. **Floor 1 is stale.** Lib-wide there are 4: `lib/devtool/users/fund_jeeber_wallet_picker_page.dart:107` (`OmdsLoadingState`), `:110` (`OmdsErrorState`); `lib/devtool/users/scenario_users_page.dart:370` (`OmdsLoadingState`); `lib/internal_devtool/internal_release_blocked_app.dart:21` (`OmdsErrorState`) |
| `test/guardrails/no_title_key_as_headline_test.dart` | `lib` | **1** | **1** | `lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart:480` `headline: l10n.availabilityDutyOffTitle` — the key is a "title key" only because the SAME file's `JeebInfoNote.warning(title: l10n.availabilityDutyOffTitle, …)` at `:457` matches the ratchet's `title:\s*l10n\.` heuristic |
| `test/guardrails/no_bare_pull_to_refresh_test.dart` | `lib/features` | 0 | 0 | lib-wide: `lib/devtool/users/fund_jeeber_wallet_picker_page.dart:66`, `lib/devtool/users/scenario_users_page.dart:203`, plus the kit's own `lib/core/widgets/jeeb/jeeb_pull_to_refresh.dart:46` (by design) |
| `test/guardrails/failure_identifier_coverage_ratchet_test.dart` | `lib` ids vs `test` corpus | 0 | 0 | **Constraint on this plan:** every NEW `identifier: '…_error|_retry_cta|_empty|_loading'` literal in `lib` must be quoted in at least one test file |
| `test/guardrails/no_hardcoded_error_copy_in_application_test.dart` | `lib/features/**/application` | 0 | 0 | — |

Floor history (`git show <sha>:test/guardrails/...`): `db83ba7a` 12 / 12+19 / 8 →
`a48444ba` 1 / 3+0 / 1 → unchanged through `7a0c386b`, `ecfd3cc1`. RULINGS R4 says
"Stage 2 lowers floors to 0"; Stage 2 lowered them to today's numbers and stopped.

**Stale claim in FINAL-REPORT §7(e):** "`onboarding_funding_screen.dart:349` title-as-headline".
On `origin/main@ab610933:349` that rung was `headline: l10n.walletHubTitle`; on the branch it is
already `headline: l10n.fundingWalletLoadingHeadline` (now
`lib/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart:397`, fixed in
`a48444ba`). The one remaining title-as-headline hit is `jeeber_feed_tab_view.dart:480`.

**UX defect behind the title hit:** in `jeeber_feed_tab_view.dart`, when the jeeber is off duty the
page renders BOTH `_OfflineBanner` (`:254`, `JeebInfoNote.warning` "You're off duty / Go online to
start receiving requests.") AND `_OfflineEmptyBody` (`:382` via `_feedSlivers(isOffline)`) with the
identical two lines — the copy repeats on one screen. `jeeber_no_requests_view.dart:139,142`
(`JeeberFeedEmptyBlock(isOnline:false)`) uses the same pair through a ternary (invisible to the
ratchet regex, but the same duplication if ever rendered; its only caller passes `isOnline: true`,
`jeeber_feed_tab_view.dart:773`).

`tool/check_design_tokens.sh` already rejects `showOmdsErrorSnackbar`, `Omds(ErrorState|LoadingState)(`,
bare `OmdsPullToRefresh(` and raw `.showSnackBar(` for changed `lib/features` files (CI:
`.github/workflows/ci-flutter-stage.yml:49`, `flutter-ci.yml:54`) — nothing to change there.

Live dev gateway (validation target) verified 2026-09-05: `https://msi.olivium.space/gateway/health/ready` → 200;
`GET /gateway/dev/data/users` unauthenticated → RFC 7807 401 (the Dev Tool roster needs its minted session).

Theme facts that make the Dev Tool migration safe: `lib/devtool/devtool_shell.dart:123-128` runs a
`MaterialApp` on `AppTheme.light()/dark()` with the l10n delegates (`:130`); the kit falls back when an
extension is missing — `context.jeebRoles` (`lib/core/theme/jeeb_color_roles.dart:244-249`),
`context.jeebText` (`jeeb_text_styles.dart:169`), `JeebSemanticColors.midnight()` fallback
(`jeeb_empty_state.dart:463-465`). `JeebEmptyState` imports no l10n
(`jeeb_empty_state.dart:1-11`); `JeebFailureBlock` needs `AppLocalizations` + an `AppFailure`
(`jeeb_failure_block.dart:1-10,115-117`). `showJeebErrorSnack` uses `ScaffoldMessenger.of(context)`
(`jeeb_snack.dart:108-115`) exactly like the OMDS one
(`omds-flutter/omds_library/lib/src/feedback/omds_dialogs.dart:326`) — no messenger regression.
`preview_structure_test` INV-7 does not count `lib/devtool/`, `lib/internal_devtool/`,
`lib/core/observability/` or private widgets (`tool/preview_inventory.dart:36-48,120`) — no new previews needed.

---

## 1. Root cause

1. Stage 2 (`a48444ba`) lowered floors to the then-observed counts and never ran the "to 0" pass.
2. The three residual sites sit outside every WP fence (R5 ownership covers `lib/features/**` +
   named core wiring files): the obs-overlay export button (`lib/core/observability`), the Dev Tool
   (`lib/devtool`), and the internal-release policy screen (`lib/internal_devtool`).
3. The Omds-state floor of 1 counted nothing real (0 hits in `lib/features`); the "1 remaining widget
   in production" is `internal_release_blocked_app.dart:21`, which the ratchet's `lib/features` scope
   never scanned.
4. The title ratchet cannot tell an app-bar `title:` from a `JeebInfoNote.title:`; the honest fix is
   distinct copy for the duty-off empty body (which also removes on-screen duplication), not a rename.

---

## 2. Work items (execute in order; one commit is fine)

Every file path is repo `olivium-dev/jeeb-mobile`, worktree
`/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`. Comments ≤2 lines.
Do not touch `lib/core/network/token_refresh_interceptor.dart` or anything PR #330 owns.

### WI-1 — Duty-off empty body gets its own copy (zeroes `no_title_key_as_headline`)

**`lib/l10n/app_en.arb`** — insert after line 5919 (`"@availabilityDutyOffSubtitle": …`):
```json
  "jeeberFeedDutyOffEmptyHeadline": "No requests while you're off duty",
  "@jeeberFeedDutyOffEmptyHeadline": {"description": "P05: duty-off feed empty body headline. Distinct from availabilityDutyOffTitle, which the banner above it already shows."},
  "jeeberFeedDutyOffEmptyBody": "Go online and nearby requests will show up here.",
  "@jeeberFeedDutyOffEmptyBody": {"description": "P05: duty-off feed empty body."},
```
**`lib/l10n/app_ar.arb`** — insert after line 2358 (`"availabilityDutyOffSubtitle"`):
```json
  "jeeberFeedDutyOffEmptyHeadline": "لا طلبات أثناء توقفك عن الدوام",
  "jeeberFeedDutyOffEmptyBody": "فعّل الاتصال لتظهر لك الطلبات القريبة هنا.",
```
**`lib/l10n/app_localizations.dart`** — hand-maintained (no `l10n.yaml`; getters are
`String get x => _get('x');`). Add next to the other `availability*` getters:
```dart
  String get jeeberFeedDutyOffEmptyHeadline => _get('jeeberFeedDutyOffEmptyHeadline');
  String get jeeberFeedDutyOffEmptyBody => _get('jeeberFeedDutyOffEmptyBody');
```
**`lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart:480-481`** (`_OfflineEmptyBody`):
```dart
        headline: l10n.jeeberFeedDutyOffEmptyHeadline,
        body: l10n.jeeberFeedDutyOffEmptyBody,
```
Leave `_OfflineBanner` (`:439-461`) untouched.

**`lib/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart:137-142`** — same two keys in the
`isOnline` ternaries (`: l10n.jeeberFeedDutyOffEmptyHeadline,` / `: l10n.jeeberFeedDutyOffEmptyBody,`)
so the duty-off empty copy is single-sourced.

**Tests**
- `test/features/jeeber_home/availability_duty_off_copy_test.dart` (EN+AR loop already there): after the
  existing `jeeber_feed_offline_empty_state` expectation add
  ```dart
      expect(
        find.descendant(
          of: find.bySemanticsIdentifier('jeeber_feed_offline_empty_state'),
          matching: find.text(l10n.jeeberFeedDutyOffEmptyHeadline),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.bySemanticsIdentifier('jeeber_feed_offline_empty_state'),
          matching: find.text(l10n.jeeberFeedDutyOffEmptyBody),
        ),
        findsOneWidget,
      );
      // The banner still owns the duty-off title; the body must not repeat it.
      expect(
        find.descendant(
          of: find.bySemanticsIdentifier('jeeber_feed_offline_empty_state'),
          matching: find.text(l10n.availabilityDutyOffTitle),
        ),
        findsNothing,
      );
  ```
  The existing `find.text(l10n.availabilityDutyOffTitle), findsWidgets` stays true (banner).
- `test/jeeber_feed_tier_filter_test.dart:326` asserts the title `findsWidgets` — still satisfied by the banner; no edit.

### WI-2 — Obs overlay export feedback → `showJeebErrorSnack` / `showJeebSuccessSnack`

**`lib/core/observability/session_trace/presentation/widgets/obs_overlay_export_button.dart`**
- Add import `import '../../../../widgets/jeeb/jeeb_snack.dart';` (keep `package:omds/omds.dart` — `Spacing`, `OmdsLoadingButton` still used).
- Replace `_showFeedback` (`:27-35`):
```dart
  void _showFeedback() {
    final message = widget.controller.lastExportMessage;
    if (message == null) return;
    if (widget.controller.lastExportSucceeded) {
      showJeebSuccessSnack(
        context,
        identifier: 'devtool_session_logs_export_success',
        message: message,
      );
    } else {
      showJeebErrorSnack(
        context,
        identifier: 'devtool_session_logs_export_error',
        message: message,
      );
    }
  }
```
**Test** `test/core/observability/session_trace/obs_overlay_controls_widget_test.dart`
- In the existing "Start, Stop, Clear view, and Export…" test, right after `expect(controller.lastExportSucceeded, isTrue);` add
  `expect(find.bySemanticsIdentifier('devtool_session_logs_export_success'), findsOneWidget);`
  (success sets `lastExportMessage = 'Shared N local trace file(s).'`, `obs_overlay_controller.dart:284-286`).
- Add a new `testWidgets('Export failure surfaces the error snack', …, skip: !kObsCompiledIn)` that builds
  `ObsOverlayController(install: () async => true, buildExportBundle: (_, _) async => null)` (null bundle →
  `lastExportSucceeded=false`, message `'No session file yet — start recording first.'`,
  `obs_overlay_controller.dart:233-238`), pumps the same `MaterialApp(theme: AppTheme.midnight(), home: Scaffold(body: ObsOverlayExportButton(controller: controller)))`,
  taps `find.bySemanticsIdentifier('devtool.session_logs.export')`, `pumpAndSettle()`, then
  `expect(find.bySemanticsIdentifier('devtool_session_logs_export_error'), findsOneWidget);`.
- These tests are skip-gated by `kObsCompiledIn`; run them for real once with
  `flutter test --dart-define=JEEB_DEVTOOL_ENABLED=true --dart-define=JEEB_OBS_OVERLAY=true test/core/observability/session_trace/obs_overlay_controls_widget_test.dart`
  (`observability_config.dart:7`, `dev_flags.dart:4`).

### WI-3 — Dev Tool failure mapper (new, tiny; used by WI-4/WI-5)

**New `lib/devtool/gateway/dev_gateway_failure.dart`:**
```dart
import 'package:dio/dio.dart';

import '../../core/network/app_failure.dart';
import 'dev_gateway_client.dart';

/// Maps a Dev Tool read failure onto the kit's failure family by status code.
AppFailure devGatewayFailure(Object error) {
  if (error is AppFailure) return error;
  if (error is DioException) return AppFailure.of(error);
  if (error is DevGatewayException) {
    return switch (error.statusCode) {
      401 => UnauthorizedFailure(cause: error),
      403 => ForbiddenFailure(cause: error),
      404 => NotFoundFailure(cause: error),
      410 => GoneFailure(cause: error),
      429 => RateLimitedFailure(cause: error),
      final int s when s >= 500 => ServerFailure(status: s, cause: error),
      _ => UnknownFailure(cause: error),
    };
  }
  return UnknownFailure(cause: error);
}

/// The gateway-authored hint (e.g. "Enable Features:DevEndpoints"), or null so
/// the copy family's body stands. Never `toString()` (R6).
String? devGatewayMessage(Object error) =>
    error is DevGatewayException ? error.message : null;
```
(`DevGatewayException.statusCode` is populated by `fromDio`, `dev_gateway_client.dart:881-886`; constructors verified at
`app_failure.dart:79-90,128-140,161-170,193-200,225-247,291-300,325-332`.)

**New test `test/devtool/dev_gateway_failure_test.dart`:** 401→`UnauthorizedFailure`; 503→`ServerFailure` with `status==503`
and `isRetryable`; `DevGatewayException('x')` (null status)→`UnknownFailure`; `DioException(type: connectionTimeout)`→`TimeoutFailure`
(via `AppFailure.of`); `devGatewayMessage` returns the message for `DevGatewayException` and null for `StateError`.

### WI-4 — Scenario Users page (2 snack sites + loading/error/empty rung + PTR)

**`lib/devtool/users/scenario_users_page.dart`**
- Imports to add:
  ```dart
  import '../../core/widgets/jeeb/jeeb_empty_state.dart';
  import '../../core/widgets/jeeb/jeeb_failure_block.dart';
  import '../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
  import '../../core/widgets/jeeb/jeeb_snack.dart';
  import '../gateway/dev_gateway_failure.dart';
  ```
- `:109` and `:123` → `showJeebErrorSnack(context, identifier: 'devtool_scenario_users_action_error', message: e.message);`
- The three `showOmdsSuccessSnackbar(context, message: …)` (`:93-100`, `:103`, `:117`) →
  `showJeebSuccessSnack(context, identifier: 'devtool_scenario_users_action_success', message: …)` (one transient surface per page).
- `:203` `body: OmdsPullToRefresh(` → `body: JeebPullToRefresh(` (same `onRefresh`/`child`, `jeeb_pull_to_refresh.dart:11-19`).
- `_ScenarioRosterSnapshot.build` (`:366-384`) becomes:
```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (snapshot.connectionState == ConnectionState.waiting) {
      return JeebEmptyState.compact(
        identifier: 'devtool_scenario_users_roster_loading',
        status: JeebEmptyStateStatus.loading,
        reason: JeebEmptyStateReason.loading,
        variant: JeebEmptyStateVariant.balcony,
        headline: l10n.scenarioUsersRosterLoadingHeadline,
      );
    }
    final error = snapshot.error;
    if (error != null) {
      return JeebFailureBlock.compact(
        failure: devGatewayFailure(error),
        identifier: 'devtool_scenario_users_roster_error',
        bodyOverride: devGatewayMessage(error),
        variant: JeebEmptyStateVariant.balcony,
        onRetry: onRetry,
        onExit: () => Navigator.of(context).maybePop(),
      );
    }
    final users = snapshot.data ?? const <DevUser>[];
    if (users.isEmpty) {
      return JeebEmptyState.compact(
        identifier: 'devtool_scenario_users_roster_empty',
        reason: JeebEmptyStateReason.nothingYet,
        variant: JeebEmptyStateVariant.balcony,
        headline: l10n.scenarioUsersEmpty,
      );
    }
    return _ScenarioRosterList(users: users, onAddMoney: onAddMoney);
  }
```
  (`JeebFailureBlock` derives `devtool_scenario_users_roster_retry_cta` / `_exit_cta` from the id, `jeeb_failure_block.dart:104-107,119-135`; a 401/403 gets the exit pill, never an inert Retry — R6.)
- Delete `_ScenarioRosterError` (`:388-411`) — private, uncounted by INV-7.
- If `package:omds/omds.dart` symbols remain (`OMDSAppBar`, `OmdsRadioTile`, `OmdsTextField`, `OmdsCheckboxTile`, `OmdsLoadingButton`, `OMDSSectionCard`, `OMDSOutlinedButton`, `OmdsPrimaryButton`, `OmdsSettingsRow`, `OmdsSlideRoute`) keep the import; `dart analyze --fatal-infos` flags an unused one.

**l10n (with WI-1's edits):** EN after `"scenarioUsersEmpty"` (`app_en.arb:5782`):
```json
  "scenarioUsersRosterLoadingHeadline": "Loading seeded users…",
  "@scenarioUsersRosterLoadingHeadline": {"description": "P05: Dev Tool roster loading rung; a *LoadingHeadline, never the Roster title."},
```
AR after `app_ar.arb:2288`: `"scenarioUsersRosterLoadingHeadline": "جارٍ تحميل المستخدمين…",` ; accessor
`String get scenarioUsersRosterLoadingHeadline => _get('scenarioUsersRosterLoadingHeadline');` next to `scenarioUsersEmpty` (`app_localizations.dart:191`).
`scenarioUsersRetry` becomes unreferenced after WI-4+WI-5 (`grep -rn scenarioUsersRetry lib test` → only the two pages today; no test pins it): delete the key from EN (`:5781`), AR (`:2287`) and the getter (`app_localizations.dart:190`) — orphan getters are warn-only but dead keys are WP-9 debt.

### WI-5 — Fund-wallet picker page (loading/error/empty rung + PTR)

**`lib/devtool/users/fund_jeeber_wallet_picker_page.dart`**
- Imports: `../../core/widgets/jeeb/jeeb_cta_button.dart`, `jeeb_empty_state.dart`, `jeeb_failure_block.dart`, `jeeb_pull_to_refresh.dart`, `../gateway/dev_gateway_failure.dart`.
- `:66` `body: OmdsPullToRefresh(` → `body: JeebPullToRefresh(`.
- `_JeeberPickerSnapshot.build` (`:103-125`) becomes:
```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (snapshot.connectionState == ConnectionState.waiting) {
      return JeebEmptyState.compact(
        identifier: 'devtool_wallet_funding_picker_loading',
        status: JeebEmptyStateStatus.loading,
        reason: JeebEmptyStateReason.loading,
        variant: JeebEmptyStateVariant.pocket,
        headline: l10n.walletFundingPickerLoading,
      );
    }
    if (snapshot.error case final error?) {
      return JeebFailureBlock.compact(
        failure: devGatewayFailure(error),
        identifier: 'devtool_wallet_funding_picker_error',
        headlineOverride: l10n.walletFundingPickerErrorTitle,
        bodyOverride: devGatewayMessage(error),
        variant: JeebEmptyStateVariant.pocket,
        onRetry: onRetry,
        onExit: () => Navigator.of(context).maybePop(),
      );
    }
    final jeebers = snapshot.data ?? const <DevUser>[];
    if (jeebers.isEmpty) {
      return JeebEmptyState.compact(
        identifier: 'devtool_wallet_funding_picker_empty',
        reason: JeebEmptyStateReason.nothingYet,
        variant: JeebEmptyStateVariant.pocket,
        headline: l10n.walletFundingPickerEmptyTitle,
        body: l10n.walletFundingPickerEmptyBody,
        action: JeebCtaButton.outline(
          label: l10n.actionRetry,
          leadingIcon: Icons.refresh,
          expand: false,
          identifier: 'devtool_wallet_funding_picker_empty_retry_cta',
          onTap: onRetry,
        ),
      );
    }
    return _JeeberPickerList(jeebers: jeebers, onSelected: onSelected);
  }
```
  (`walletFundingPickerLoading` = "Loading Jeeber wallets…" is not a `*Title` key — safe as headline; `walletFundingPickerErrorTitle` is only ever a headline, never an app-bar `title:`, so the title ratchet stays 0.)
- Delete `_errorMessage` (`:216-217`) — it `toString()`s.

**Test `test/devtool_wallet_funding_test.dart`** (harness `_testApp` `:1171-1182` is a plain `MaterialApp` — the kit's fallbacks cover it):
- Add `import 'support/midnight_test_harness.dart';` and call `useReduceMotion(tester);` as the FIRST line of every `testWidgets` body that pumps `ScenarioUsersPage` or `FundJeeberWalletPickerPage` (`:963`, `:979`, `:1037`, `:1057`, `:1075`, `:1096`, `:1123`, `:1147`, and the scenario-users case at `:157` if it pumps the page). Without it the loading rung's looping illustration makes `pumpAndSettle` throw.
- `:963-977` rename to "Scenario Users roster shows the JEEB loading rung"; replace `find.byType(OmdsLoadingState)` with `find.bySemanticsIdentifier('devtool_scenario_users_roster_loading')`.
- Add a sibling test: `_WalletFundingDio(rosterFailureCalls: 1)` (throws `503`, `:1440-1448`) → `pumpAndSettle` → `find.bySemanticsIdentifier('devtool_scenario_users_roster_error')` + `'devtool_scenario_users_roster_retry_cta'` findsOneWidget; tap retry → roster renders. Also one empty case (`rosterUsers: []`) → `'devtool_scenario_users_roster_empty'`.
- `:1037-1055`: rename "wallet picker renders the JEEB loading and empty rungs"; `find.byType(OmdsLoadingState)` → `'devtool_wallet_funding_picker_loading'`; `find.byType(OmdsEmptyState)` + `find.text('No Jeeber accounts found')` → `find.bySemanticsIdentifier('devtool_wallet_funding_picker_empty')` and `'devtool_wallet_funding_picker_empty_retry_cta'`.
- `:1057-1073`: rename "wallet picker shows the JEEB failure block and retries the real roster"; `find.byType(OmdsErrorState)` → `'devtool_wallet_funding_picker_error'`; `find.text('Retry')` → `find.bySemanticsIdentifier('devtool_wallet_funding_picker_retry_cta')`.
- Add an action-snack case: `ScenarioUsersPage` with a Dio whose `/dev/seed/user` returns 403 → tap `devtool.scenarioUsers.create` → `pump()` → `find.bySemanticsIdentifier('devtool_scenario_users_action_error')` findsOneWidget (check `_WalletFundingDio` for a seed-failure knob; add `seedFailureStatus` if absent).
- Drop the now-unused `package:omds/omds.dart` import if nothing else in the file uses it.

### WI-6 — Internal-release blocked screen

**`lib/internal_devtool/internal_release_blocked_app.dart`** — replace the `OmdsErrorState` (`:21-27`):
```dart
    home: const Scaffold(
      body: SafeArea(
        child: JeebEmptyState(
          identifier: 'internal_release_blocked_error',
          status: JeebEmptyStateStatus.error,
          reason: JeebEmptyStateReason.failed,
          variant: JeebEmptyStateVariant.parcel,
          headline: 'Internal build blocked',
          body:
              "This build's signed internal-release policy does not match "
              'the staging contract.',
        ),
      ),
    ),
```
Import `'../core/widgets/jeeb/jeeb_empty_state.dart'`; drop `package:omds/omds.dart` if unused. Keep the class and
`const InternalReleaseBlockedApp()` — `test/internal_devtool/internal_android_contract_test.dart:106` pins the literal.
Why not `JeebFailureBlock`: this `MaterialApp` deliberately has no localization delegates (`:14-19`) and the message is a
build-policy statement, not an `AppFailure`; there is no CTA because there is nowhere to exit to (the whole app IS the block).

**New test `test/internal_devtool/internal_release_blocked_app_test.dart`:** `useReduceMotion(tester)`; `pumpWidget(const InternalReleaseBlockedApp())`;
`pump()`; expect `find.bySemanticsIdentifier('internal_release_blocked_error')` findsOneWidget and `find.text('Internal build blocked')` findsOneWidget.
(`test/release/devtool_import_closure_test.dart` only polices edges INTO `lib/devtool/`; `lib/internal_devtool → lib/core/widgets/jeeb` is allowed.)

### WI-7 — Ratchets to 0 and lib-wide

- `test/guardrails/no_omds_error_snackbar_test.dart:9` → `const int _kOmdsErrorSnackbarFloor = 0;` (raw-`showSnackBar` scope stays `lib/features`, floor 0 — see §8).
- `test/guardrails/no_omds_state_widgets_test.dart`: `_kFloor = 0`; `scan('lib', …)` instead of `'lib/features'`; test name "OmdsErrorState / OmdsLoadingState do not spread in lib".
- `test/guardrails/no_title_key_as_headline_test.dart:9` → `const int _kFloor = 0;`.
- `test/guardrails/no_bare_pull_to_refresh_test.dart`: `scan('lib', RegExp(r'\bOmdsPullToRefresh\s*\('), skipPaths: const ['lib/core/widgets/jeeb/jeeb_pull_to_refresh.dart'])`, floor 0, name "…in lib".
- In each header/doc comment replace "Stage 2 drives this to 0" with "Floors are 0 since P05 (2026-09-05); never raise." (≤2 lines).
- Sanity: `flutter test test/guardrails` must report every ratchet at exactly its floor (a hit count BELOW a floor prints "The floor is now too high"; there must be none).

### WI-8 — Gates (run from the worktree root, in this order)

1. `git add -A` (R6: the mb1 residual-receipts test fails on untracked `.dart`).
2. `dart analyze --fatal-infos .` → clean.
3. `flutter test test/guardrails` → 7/7 green at floor 0 with no "too high" message.
4. `flutter test --exclude-tags capture` → 0 failures (baseline 10539 pass / 109 skip; expect + ~8 new).
5. `flutter test --dart-define=JEEB_DEVTOOL_ENABLED=true --dart-define=JEEB_OBS_OVERLAY=true test/core/observability/session_trace/obs_overlay_controls_widget_test.dart test/devtool test/internal_devtool/full_devtool_launcher_widget_test.dart test/devtool_wallet_funding_test.dart` → green (the RC lane runs the devtool suite with the define; main-green ≠ RC-green).
6. `flutter test --exclude-tags capture --coverage` then confirm `coverage/lcov.info` ≥ 79% (was 84.65%).
7. `bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze` → all strict counters 0; `bash qa/t-mob-fix-002/ar_plurals_check.sh` → 0 missing.
8. `bash tool/check_design_tokens.sh` (diff-scoped vs `origin/main`) → OK; `dart run tool/preview_coverage.dart` → floor 247 unchanged.
9. Commit: `chore(guardrails): every ratchet floor to 0 — Dev Tool, obs export and internal-release surfaces on the JEEB kit; duty-off empty body gets its own copy`.
   Reconciled (C1): NOT on PR #335 — commit on follow-up branch `chore/guardrail-floors-zero` (stacked now, rebased onto
   `main` after the #335 squash, `git rebase --onto`). Land after P13 in the serialized l10n order (C10).

---

## 3. Device validation (real device, real UI)

Device SM-A336B `RZCT505K7WF`, alias `app.jeeb.mobile.dev` / `com.olivium.jeeb.LegacyDevToolLauncher`. **Install `-r` only; never uninstall; never tap "Clear Local Data".** This Mac is off the MSI LAN — use `https://msi.olivium.space/gateway`.

Build (worktree needs the two gitignored files first — `device-evidence-2/build/REPORT.md:18-33`):
```
cp /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/android/app/src/dev/google-services.json android/app/src/dev/
cp /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/android/app/google-services.json android/app/
# verify "project_id": "jeeb-5a293" in both (never alrahmah)
flutter build apk --debug --flavor dev -t lib/main.dart -Pjeeb.devtool=true -PMAPS_API_KEY=<key from jeeb-mobile android/local.properties> \
  --dart-define=JEEB_DEVTOOL_ENABLED=true --dart-define=JEEB_OBS_OVERLAY=true
adb -s RZCT505K7WF install -r build/app/outputs/flutter-apk/app-dev-debug.apk
```
Cold-start twice after install (secure-storage race). Evidence → `$SCRATCH/device-evidence-4/p05/` (`uiautomator dump` XML + PNG per assertion, table in `REPORT.md`).

| # | Scenario | Steps | PASS when (assert by `content-desc`/identifier, never text) |
|---|---|---|---|
| V1 | Scenario Users roster failure + retry | Dev Tool → Dev Settings → Server URL → type `https://10.255.255.1:1` → Apply & Restart → Dev Tool → Scenario Users | `devtool_scenario_users_roster_loading` shows first; then `devtool_scenario_users_roster_error` + `devtool_scenario_users_roster_retry_cta`, body carries "could not reach the gateway… Check the Dev Tool Server URL." Restore `https://msi.olivium.space/gateway` → Apply & Restart → super-login → roster rows render |
| V2 | Scenario Users action snack | With the bad URL, tap `devtool.scenarioUsers.create` | `devtool_scenario_users_action_error` snack in `errorContainer` colours, auto-dismisses ≤ ~5 s (no action ⇒ 4 s `kJeebSnackDuration`) |
| V3 | Fund-wallet picker failure + retry | Bad URL → Dev Tool → Fund Jeeber wallet | `devtool_wallet_funding_picker_error` + `devtool_wallet_funding_picker_retry_cta`; restore URL → tap retry → jeeber rows (`devtool.walletFunding.jeeber.*`) |
| V4 | Session Logs export error | Dev Tool → Session Logs → do NOT start recording → tap `devtool.session_logs.export` | `devtool_session_logs_export_error` snack "No session file yet — start recording first."; then Start → Stop → Export → share sheet → `devtool_session_logs_export_success` |
| V5 | Duty-off empty body (EN + AR) | Super-login as an approved jeeber (Karim TestJeeber, or Scenario Users → jeeber + "Approve KYC") → Requests tab → toggle Offline | banner `JeeberFeedTabView.offlineBannerKey` shows "You're off duty"; `jeeber_feed_offline_empty_state` shows "No requests while you're off duty / Go online and nearby requests will show up here." — the two lines are NOT repeated. Settings → Language → العربية → same node shows "لا طلبات أثناء توقفك عن الدوام" |
| V6 | Internal-release blocked screen | Not a user flow (build-policy mismatch in the android-internal flavour only); covered by the new widget test. Optional: `flutter build apk --flavor internal` with a deliberately mismatched policy → `internal_release_blocked_error` node | widget test green |

---

## 4. Risks

- `pumpAndSettle` timeouts: every test that pumps a page whose loading rung is now a `JeebEmptyState` must call `useReduceMotion(tester)` first (R6) — the whole of `test/devtool_wallet_funding_test.dart` Scenario Users/picker cases.
- `failure_identifier_coverage_ratchet` (floor 0) fails the build if any new snake_case id (`…_loading|_empty|_error|_retry_cta`) is not quoted in a test: the ids introduced are exactly `devtool_session_logs_export_error`, `devtool_scenario_users_action_error`, `devtool_scenario_users_roster_loading`, `devtool_scenario_users_roster_error`, `devtool_scenario_users_roster_empty`, `devtool_wallet_funding_picker_loading`, `devtool_wallet_funding_picker_error`, `devtool_wallet_funding_picker_empty`, `devtool_wallet_funding_picker_empty_retry_cta`, `internal_release_blocked_error` — each named in WI-2/4/5/6 tests.
- l10n parity is strict: the 3 new keys must land EN + AR + getter in the same commit; `scenarioUsersRetry` deletion must remove all three too.
- Dev Tool runs the light/dark `AppTheme`, not Midnight; kit art is Midnight-tuned but renders via fallbacks — check V1/V3 screenshots for legibility in light theme.
- 401/403 on Dev Tool reads now show an exit pill instead of Retry (by R6); re-login is the fix path, which the body hint states.
- The obs tests only execute under `JEEB_OBS_OVERLAY`; step 5 of WI-8 is mandatory, not optional.

## 5. Dependencies

None on other pending points. Not in scope (separate follow-up, not P05): the 8 raw `.showSnackBar(` sites outside `lib/features`
(`lib/core/diagnostics/diagnostics_screen.dart:188`, `lib/devtool/dev_settings_page.dart:45,55,156`, `lib/devtool/devtool_shell.dart:294`,
`lib/devtool/diagnostics/chat_push_diagnostics_page.dart:99`, `lib/devtool/super_login/full_roster_login.dart:87,107`) — widen that ratchet to `lib` only after they migrate.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C8): the empty-block action id follows P12's grammar row `<screen>_empty_retry_cta`; the picker CTA is
  `devtool_wallet_funding_picker_empty_retry_cta` (edited above in WI-5, the test list and §4).
- Reconciled (C9): `secret_redactor_test` scans all of `lib/` (incl. `lib/devtool`, `lib/internal_devtool`,
  `lib/core/observability`) for literal identifiers — add WI-3b: insert the 10 new ids in sorted position in
  `lib/core/observability/session_trace/audited_interaction_identifiers.dart` in the same commit
  (`devtool_scenario_users_action_error`, `devtool_scenario_users_action_success`, `devtool_scenario_users_roster_loading|_error|_empty`,
  `devtool_wallet_funding_picker_loading|_error|_empty`, `devtool_wallet_funding_picker_empty_retry_cta`,
  `devtool_session_logs_export_success|_error`, `internal_release_blocked_error`).
- Reconciled (C11/P12): after P12 Change A the coverage ratchet is real (floor 26 measured on `ecfd3cc1`); every P05 id
  is quoted by a test so the count must not move — if it does, the missing assertion is the bug, not the floor.
- Reconciled (C16): WI-1 edits `jeeber_no_requests_view.dart:137-142`; P12 A2 edits line 162 of the same file and
  lands first (on #335) — rebase, no textual overlap expected.
- Reconciled (C1/C10): landing order in wave 2 = P13 → **P05** → P06 → P07 → P02 → P03 → P12-B; hand-merge
  `app_en.arb`/`app_ar.arb`/`app_localizations.dart` each time and re-run the parity scripts.
- Reconciled (C12): evidence dir `scratchpad/device-evidence-4/p05/` (unchanged). No owner decision.
