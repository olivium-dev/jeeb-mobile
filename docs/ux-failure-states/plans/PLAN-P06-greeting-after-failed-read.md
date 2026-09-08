# PLAN P06 — Jeeber-home greeting after a FAILED `GET /v1/users/me` read

- Programme: `ux/api-error-handling-empty-states` (jeeb-mobile draft PR #335), worktree
  `/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors` @ `ecfd3cc1`
- Scope: mobile only; one new branch commit on the existing branch. No new repo, no deploy.
- Effort: **M** (2 lib files change materially, 3 lib files get one-line wiring, 4 test files, 1 registry).

## 1. Problem (verified)

After a failed cold `GET /v1/users/me`, the jeeber dashboard band greets "Welcome back"
over a `?` disc — a fabricated identity — and never recovers for the life of the tab.

Evidence:

- `lib/core/session/greeting_profile_cubit.dart:65-76` — `load()` catches `on Object`,
  sets `profile = null`, then `emit(state.copyWith(status: GreetingProfileStatus.resolved))`.
  The enum at `:11` is `{ idle, loading, resolved }`: a failed read and a landed-nameless
  read are the same state. The failure kind is thrown away.
- `lib/features/jeeber_home/presentation/widgets/jeeber_home_greeting.dart:91-94` —
  `_readPending` is true only while `isLoading`; "every terminal state — landed, landed
  nameless, failed — falls through to the fallback greeting" (its own doc comment).
  `:67-73` then renders `l10n.homeGreetingFallback` ("Welcome back" / "مرحبًا بعودتك") +
  `JeebAvatar.header(initial: '')`, which `lib/core/widgets/jeeb/jeeb_avatar.dart:289`
  normalises to `'?'`.
- No recovery path. The only re-pull is `ProfileRefreshSignals` (`greeting_profile_cubit.dart:52`,
  fired on display-name save). Reconnect (`NetworkReachabilitySignals`) and resume
  (`AppResumeSignals`) are not wired (`lib/features/shell/tabs/dashboard_tab.dart:143-148`).
  The dashboard's own retry, `jeeber_home_load_error_retry_cta`, calls only
  `context.read<AvailabilityCubit>().load()` (`lib/features/jeeber_home/presentation/jeeber_home_screen.dart:389-392`).
- The cubit lives as long as the tab: shell hosts tabs in an `IndexedStack`
  (`lib/features/shell/shell_screen.dart:161`) and the provider at `dashboard_tab.dart:143`
  is not keyed, so `JeeberKycGateBuilder` rebuilds reuse the same cubit. A failed cold read
  is therefore stale until the app is killed.
- Two existing tests pin the wrong behaviour and must change:
  `test/core/session/greeting_profile_cubit_test.dart:125-134` ("a FAILED load() still ends
  in `resolved`") and `test/features/jeeber_home/jeeber_home_greeting_loading_test.dart:127-137`
  ("a FAILED getMe falls back").
- Device: run 3 proved the LOADING band (`device-evidence-3/REPORT.md` A8, `17-jeeberhome-t8.xml`)
  and recovery after **Apply & Restart** (A10, `23-recovered-home.xml`: `desc="Ahlan, Karim"`,
  `jeeber_home_avatar`="K"). Restart creates a fresh cubit, so the in-place failed→fallback
  path was never exercised; `FINAL-REPORT.md §7(f)` lists it as not done. The only device
  capture of the fabricated band is the client side during loading
  (`device-evidence/outage/10-jeeber-home.xml`: `content-desc="?\nGood morning\nWelcome back"`).

Gateway contract (`git -C jeeb-gateway show origin/main:src/JeebGateway/Auth/OtpSignIn/UsersMeController.cs`,
origin/main `6679f6e`):

- `:117-124` GET `v1/users/me` produces 200 / 401 / 502 / 503.
- `:151-186` a user-management display read failure is **swallowed**: the response is 200
  with `Name`/`Email`/`AvatarUrl` = null ("display fields are BEST-EFFORT"). Mobile cannot
  distinguish "backend degraded" from "account has no name" — so **resolved-nameless keeps the
  fallback greeting**; only a *thrown* read becomes `failed`.
- Failures that DO reach mobile as exceptions: 401 bearer (live-proven:
  `curl https://msi.olivium.space/gateway/v1/users/me` → `401 application/problem+json`
  `{"type":"…rfc9110#section-15.5.2","title":"Unauthorized","status":401,"traceId":"00-…"}`,
  `x-correlation-id` header), 503 `UpstreamDisabled()` (`:128`), 5xx/52x, and transport
  (connect/timeouts → `NetworkFailure`/`TimeoutFailure` via `AppFailure.of`).
- `lib/features/customer_profile/data/dio_customer_profile_repository.dart:33-39` already throws
  `CustomerProfileRepositoryException.classified(_map(e), appFailure: AppFailure.of(e))`, so
  the classified `AppFailure` is available to the cubit today and simply dropped.

## 2. Target behaviour

| Cubit status | Band renders | Ids emitted |
|---|---|---|
| `loading` (unchanged) | pending disc, eyebrow, empty name line | `jeeber_home_greeting_loading`, `jeeber_home_avatar` |
| `resolved`, name | "Ahlan, {first}" + initial/avatar | `jeeber_home_avatar` |
| `resolved`, nameless (200 with null display) | "Welcome back" + `?` — unchanged, indistinguishable by contract | `jeeber_home_avatar` |
| **`failed`** (new) | pending disc (no letter), eyebrow "Jeeber dashboard", name line = `customerProfileLoadErrorTitle` ("Couldn't load your profile" / "تعذّر تحميل ملفك"), and under the row a `JeebInfoNote.error` strip: `failureCopy(l10n, failure).body` + refresh icon button when `failure.isRetryable` | `jeeber_home_greeting_error` (strip node: id + label + liveRegion on ONE node, as `jeeb_refresh_failed_note.dart:77-84`), `jeeber_home_greeting_retry_cta`, `jeeber_home_avatar` |
| threaded `name` non-empty (unregistered path `'Kamal'`, `dashboard_tab.dart:160`) | greets the threaded name regardless of status — unchanged | |

Recovery from `failed` (any of these re-runs `load()`, which from `failed` flips to `loading`
— the F4 band — then to `resolved` or back to `failed`):

1. Tap `jeeber_home_greeting_retry_cta`.
2. Offline→online edge (`NetworkReachabilitySignals.instance.stream`) — **only** when
   `failureBlamesConnectivity(failure)` (R6: only Network/Timeout blame connectivity).
3. App resume (`AppResumeSignals.instance.stream`) — any failed kind.
4. The dashboard's availability retry (`jeeber_home_load_error_retry_cta`) also retries a failed greeting.
5. `ProfileRefreshSignals` (existing) — unchanged.

Warm rule (R6 "refresh never flips to loading"): a failure AFTER a successful read keeps the
person on screen (`resolved` + name), never shows the strip; log `Diag.event` only.

Non-retryable kinds: `UnauthorizedFailure(recovering: false)` → strip body
`errorSessionExpiredBody`, **no** retry button (the session-loss flow owns the exit);
`ForbiddenFailure`/`NotFound` cannot occur on this route (controller above) but render via the
same `failureCopy` branch with no retry. No exit CTA on a decorative band — the strip is
informational; the screen-level `jeeber_home_error` block already carries the exit for the
tab-blocking case.

No new ARB keys: `customerProfileLoadErrorTitle` (EN `app_en.arb:5510`, AR `app_ar.arb:2088`),
`actionRetry` (`:5831`/`:2313`) and the `failureCopy` family already exist in both locales.
l10n parity is untouched.

## 3. Fix steps (ordered; every path is under the mobile worktree above)

### Step 1 — `lib/core/session/greeting_profile_cubit.dart`

1. Imports: add `'../diagnostics/diag.dart'`, `'../network/app_failure.dart'`,
   `'../network/network_reachability_signals.dart'` (for `failureBlamesConnectivity`).
2. Enum: `enum GreetingProfileStatus { idle, loading, resolved, failed }`. Update the doc comment
   (max 2 lines): `resolved` = a read landed (named or not); `failed` = the cold read threw.
3. State: add `final AppFailure? failure;` (constructor param `this.failure`), `bool get isFailed =>
   status == GreetingProfileStatus.failed;`, `copyWith(..., AppFailure? failure, bool clearFailure = false)`
   → `failure: clearFailure ? null : (failure ?? this.failure)`; add `failure` to `props`.
4. Constructor: add `Stream<void>? reconnectSignals, Stream<void>? resumeSignals`. Subscribe:
   `_reconnectSub = reconnectSignals?.listen((_) => _retryIfFailed(reason: 'reconnect', connectivityOnly: true));`
   `_resumeSub = resumeSignals?.listen((_) => _retryIfFailed(reason: 'resume'));`
   Cancel both in `close()` (same pattern as `_refreshSubscription`, `:90-95`).
5. `load()` becomes:
   ```dart
   Future<void> load() async {
     final repo = _repository;
     if (repo == null || _inFlight) return;
     _inFlight = true;
     // Cold read and retry-from-failed blank the band; a refresh keeps the person.
     if (state.status == GreetingProfileStatus.idle || state.isFailed) {
       emit(state.copyWith(status: GreetingProfileStatus.loading, clearFailure: true));
     }
     try {
       _emitFrom(await repo.fetchProfile());
     } on Object catch (e) {
       _emitFailure(_classify(e));
     } finally {
       _inFlight = false;
     }
   }
   ```
   `bool _inFlight = false;` — resume + reconnect fire together on a foreground regain
   (`jeeber_active_deliveries_banner.dart:83` documents the same race); the guard keeps one read.
6. `_emitFailure(AppFailure f)`:
   ```dart
   void _emitFailure(AppFailure failure) {
     Diag.event('greeting_profile_read_failed', {'kind': failure.kind.name, 'warm': state.name != null});
     if (state.name != null) return; // warm: keep the person, never the strip
     emit(state.copyWith(status: GreetingProfileStatus.failed, failure: failure));
   }
   ```
   (`GreetingProfileState` is Equatable and `AppFailure` overrides `==`, `app_failure.dart:53-63`.)
7. `_classify(Object e)`:
   ```dart
   AppFailure _classify(Object e) {
     if (e is CustomerProfileRepositoryException) {
       return e.appFailure ??
           switch (e.failure) {
             CustomerProfileFailure.network => networkFailureFromReachability(cause: e), // Reconciled C3: P13 helper, offline-aware
             CustomerProfileFailure.unauthorized => const UnauthorizedFailure(),
             CustomerProfileFailure.unknown => UnknownFailure(cause: e),
           };
     }
     return AppFailure.of(e);
   }
   ```
   (The legacy `CustomerProfileRepositoryException(f)` constructor has `appFailure == null` —
   `customer_profile_repository.dart:7-8`; the test doubles use it.)
8. Public `Future<void> retryIfFailed()` → `_retryIfFailed(reason: 'dashboard_retry')`. Private:
   ```dart
   Future<void> _retryIfFailed({required String reason, bool connectivityOnly = false}) async {
     if (!state.isFailed) return;
     final f = state.failure;
     if (connectivityOnly && (f == null || !failureBlamesConnectivity(f))) return;
     Diag.event('greeting_profile_reload', {'reason': reason});
     await load();
   }
   ```
   `_emitFrom` (`:80-88`) is unchanged — it already emits a fresh `resolved` state with `failure` null.
9. Keep the `refreshSignals` path as is (`load()`); from `failed` it now shows the loading band
   first, which is the F4-correct frame.

### Step 2 — `lib/features/jeeber_home/presentation/widgets/jeeber_home_greeting.dart`

1. Add constants next to `loadingIdentifier` (`:32`):
   `static const String failedIdentifier = 'jeeber_home_greeting_error';`
   `static const String retryIdentifier = 'jeeber_home_greeting_retry_cta';`
2. Add imports: `'../../../../core/network/app_failure.dart'`,
   `'../../../../core/widgets/jeeb/app_failure_copy.dart'`,
   `'../../../../core/widgets/jeeb/jeeb_info_note.dart'`, `'package:omds/omds.dart'` is already there.
3. `build()`: after `pending`, compute
   `final failed = !pending && _readFailed(profile, rawName);` where
   ```dart
   static bool _readFailed(GreetingProfileState? profile, String? rawName) {
     if (profile == null || !profile.isFailed) return false;
     return (rawName ?? '').trim().isEmpty;
   }
   ```
   `_readPending` stays exactly as is (`failed` is not `isLoading`, so it already returns false).
4. Header row: `name: (pending || failed) ? (failed ? l10n.customerProfileLoadErrorTitle : '') : _resolveGreeting(...)`,
   `avatar: (pending || failed) ? const _PendingAvatarDisc() : JeebAvatar.header(...)`. The
   eyebrow stays. (`name:` is not a `title:`/`headline:` argument, so
   `test/guardrails/no_title_key_as_headline_test.dart:11-12` does not fire.)
5. Return shape:
   - `pending` → unchanged `Semantics(identifier: loadingIdentifier, container: true, child: band)`.
   - `failed` → `Column(crossAxisAlignment: stretch, mainAxisSize: min, children: [band, _GreetingFailedStrip(failure: profile!.failure ?? const UnknownFailure(), onRetry: () => context.read<GreetingProfileCubit>().load())])`.
     The cubit is guaranteed present when `profile != null`.
   - else → `band`.
6. New private widget `_GreetingFailedStrip` in the same file (mirror
   `lib/core/widgets/jeeb/jeeb_refresh_failed_note.dart:67-118`, without the dismiss button and
   without its own reconnect subscription — the cubit owns recovery):
   ```dart
   class _GreetingFailedStrip extends StatelessWidget {
     const _GreetingFailedStrip({required this.failure, required this.onRetry});
     final AppFailure failure;
     final VoidCallback onRetry;
     @override
     Widget build(BuildContext context) {
       final l10n = AppLocalizations.of(context);
       final copy = failureCopy(l10n, failure);
       final scheme = Theme.of(context).colorScheme;
       final bool canRetry = copy.retryable && failure.isRetryable;
       return Padding(
         padding: const EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.small, Spacing.xLarge, 0),
         // Id, label and liveRegion on ONE node — an announced node with no text reads as silence.
         child: Semantics(
           identifier: JeeberHomeGreeting.failedIdentifier,
           label: copy.body,
           liveRegion: true,
           container: true,
           explicitChildNodes: true,
           child: JeebInfoNote.error(
             icon: Icons.sync_problem,
             text: copy.body,
             trailing: canRetry
                 ? Semantics(
                     identifier: JeeberHomeGreeting.retryIdentifier,
                     button: true,
                     container: true,
                     child: IconButton(
                       icon: const Icon(Icons.refresh),
                       color: scheme.onErrorContainer,
                       tooltip: l10n.actionRetry,
                       onPressed: onRetry,
                     ),
                   )
                 : null,
           ),
         ),
       );
     }
   }
   ```
   Check `JeebInfoNote.error` asserts (`jeeb_info_note.dart:268-292`): `icon xor leading`,
   `text xor label`, `trailing xor linkLabel` — all satisfied.
7. Previews (file tail, keep the `_jeeberHomeGreetingHosted` helper): add
   `jeeberHomeGreetingFailedNetwork` (`GreetingProfileState(status: failed, failure: NetworkFailure(offline: true))`, name
   `'getMe failed · network · retry'`) and `jeeberHomeGreetingFailedSessionExpired`
   (`UnauthorizedFailure()`, name `'getMe failed · session expired · no retry'`), group `'jeeber_home'`,
   size `Size(390, 200)` (the strip adds a row). Update the class doc comment (2 lines max per comment).

### Step 3 — `lib/features/jeeber_home/presentation/jeeber_home_screen.dart`

At `:389-392` change the retry to also re-pull the greeting:
```dart
onRetry: () {
  context.read<AvailabilityCubit>().load();
  _retryGreetingIfFailed(context);
},
```
with, in the same file (top-level or on the state class):
```dart
/// The greeting cubit is ambient only under DashboardTab; catalog/tests mount without it.
void _retryGreetingIfFailed(BuildContext context) {
  try {
    unawaited(context.read<GreetingProfileCubit>().retryIfFailed());
  } on ProviderNotFoundException {
    return;
  }
}
```
Import `'../../../core/session/greeting_profile_cubit.dart'` and `'package:flutter_bloc/flutter_bloc.dart'`
(already imported — check `:1-40`); `ProviderNotFoundException` comes from `package:provider` re-exported
by flutter_bloc — if the analyzer cannot resolve it, catch `on Object` (matches `_readGreetingProfile`'s style at `jeeber_home_greeting.dart:98-103`).

### Step 4 — `lib/features/shell/tabs/dashboard_tab.dart:143-148`

```dart
BlocProvider<GreetingProfileCubit>(
  create: (_) => GreetingProfileCubit(
    repository: _resolveGreetingRepository(),
    refreshSignals: _profileRefreshStream(),
    reconnectSignals: NetworkReachabilitySignals.instance.stream,
    resumeSignals: AppResumeSignals.instance.stream,
  )..load(),
),
```
Import `'../../../core/network/network_reachability_signals.dart'`; `app_resume_signals.dart` is already imported (`:12`).

### Step 5 — `lib/features/shell/tabs/home_tab.dart:71-77` (client tab, wiring only)

Pass the same two streams (`NetworkReachabilitySignals.instance.stream`, `AppResumeSignals.instance.stream`)
so the client greeting also recovers from a failed cold read. `ClientHomeGreeting` ignores
`status` entirely (`client_home_greeting.dart:56-100`), so a `failed` value changes nothing
visually there — adopting the failed band on the client side is a separate pending point (see §7).

### Step 6 — `lib/core/observability/session_trace/audited_interaction_identifiers.dart`

Insert, keeping the set sorted around `:322`:
`'jeeber_home_greeting_error',` (before `'jeeber_home_greeting_loading'`) and
`'jeeber_home_greeting_retry_cta',` (after it). Required by
`test/core/observability/session_trace/secret_redactor_test.dart:546-571` ("every resolved static
production identifier is classified" — it resolves `static const` identifiers through the analyzer).

### Step 7 — tests (Section 4). `git add` every new file BEFORE `flutter test` (R6).

### Step 8 — gates, commit, PR

```
cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors
dart analyze --fatal-infos .
flutter test --exclude-tags capture            # baseline 8257 pass / 0 fail on this worktree
tool/check_design_tokens.sh
flutter test test/guardrails test/previews test/l10n test/core/observability   # the ratchets, explicitly
```
Reconciled (C1): commit on follow-up branch `fix/jeeber-greeting-failed-read` (stacked now, `git rebase --onto origin/main …`
after the #335 squash), PR against `main`; lands after P13 and P05 in the wave-2 order. Message:
`fix(ux): jeeber greeting distinguishes a failed /users/me read from a nameless one (P06)`.

## 4. Tests

All widget tests: `wrapForTest(..., locale:)` from `test/support/sync_app_localizations.dart:34`,
`useReduceMotion(tester)` before `pumpAndSettle`, loop `for (final locale in [Locale('en'), Locale('ar')])`,
assert by `find.bySemanticsIdentifier('<literal>')`. **Write the identifier literals in the test source
(`'jeeber_home_greeting_error'`, `'jeeber_home_greeting_retry_cta'`), not the static consts** —
`test/guardrails/failure_identifier_coverage_ratchet_test.dart:11,35-37` (floor 0) greps the test
corpus for the quoted literal.

### 4.1 `test/core/session/greeting_profile_cubit_test.dart` (edit)

- Replace `:125-134` with: `a FAILED cold load() ends in failed with the classified failure` →
  `status == failed`, `failure is NetworkFailure`, `name == null`.
- `classified exception carries its AppFailure through` — throw
  `CustomerProfileRepositoryException.classified(unknown, appFailure: ServerFailure(status: 503))` →
  `state.failure == const ServerFailure(status: 503)`.
- `legacy exception maps by kind` — `unauthorized` → `UnauthorizedFailure`, `unknown` → `UnknownFailure`.
- `retry from failed flips loading → resolved` — scripted repo throws once then returns `name: 'Ahmad'`;
  record statuses: `[loading, failed, loading, resolved]`; `failure == null` at the end.
- `a failure after a successful read keeps the person (warm)` — success then throw on refresh →
  status stays `resolved`, `name == 'Ahmad'`, `failure == null`, no `loading` emitted.
- `reconnect signal retries only connectivity failures` — failed with `NetworkFailure` + reconnect
  emit → repo called again; failed with `ServerFailure(status: 503)` + reconnect emit → NOT called.
- `resume signal retries any failed kind` — `ServerFailure` + resume emit → called again.
- `retryIfFailed() is a no-op when resolved` and `when idle`.
- `concurrent signals produce ONE read` — resume + reconnect on the same tick → repo `fetchProfile`
  call count == 1 (use a Completer-backed repo, complete after both emits).
- `close() cancels reconnect/resume subscriptions` — emit after close: no throw, state untouched.
- Keep the existing success/normalise/no-repo/refresh tests as they are.

### 4.2 `test/features/jeeber_home/jeeber_home_greeting_failed_test.dart` (new)

Harness identical to `jeeber_home_greeting_loading_test.dart:46-67` plus `reconnectSignals`/
`resumeSignals` StreamControllers passed into the cubit. Repos: `_FailingRepository` (throws
`classified(network, appFailure: const NetworkFailure(offline: true))` — Reconciled C3: after P13 a default
`NetworkFailure()` (offline:false) renders `errorUnreachableBody`, so the fixture must say offline:true to assert `errorNetworkBody`), `_SessionExpiredRepository`
(`UnauthorizedFailure()`), `_ThenSucceeds` (throws first, then `CustomerProfileViewData(name: 'Karim TestJeeber')`).

Per locale EN+AR:

1. `a FAILED getMe renders the failed band, not the fallback` — after `pumpAndSettle`:
   `find.bySemanticsIdentifier('jeeber_home_greeting_error')` findsOneWidget;
   `'jeeber_home_greeting_retry_cta'` findsOneWidget; `find.text(l10n.homeGreetingFallback)` findsNothing;
   `find.text('?')` findsNothing; `find.text(l10n.customerProfileLoadErrorTitle)` findsOneWidget;
   `find.text(l10n.errorNetworkBody)` findsOneWidget; `find.text(l10n.jeeberDashboardEyebrow)` findsOneWidget;
   `'jeeber_home_greeting_loading'` findsNothing; `'jeeber_home_avatar'` findsOneWidget.
2. `the error node carries the body as its label and is a live region` — `tester.getSemantics(find.bySemanticsIdentifier('jeeber_home_greeting_error'))`
   has `label == l10n.errorNetworkBody` and `hasFlag(SemanticsFlag.isLiveRegion)`.
3. `retry recovers to the real person` — `_ThenSucceeds`; tap retry; `pump()` → loading band present
   (`'jeeber_home_greeting_loading'`), error absent; `pumpAndSettle()` → `find.text(l10n.jeeberGreetingAhlan('Karim'))`
   findsOneWidget, error + loading absent, avatar desc "K".
4. `session expired shows no retry` — `_SessionExpiredRepository`: error node present,
   `find.text(l10n.errorSessionExpiredBody)` findsOneWidget, `'jeeber_home_greeting_retry_cta'` findsNothing.
5. `reconnect edge recovers a connectivity failure without a tap` — `_ThenSucceeds`; add to the
   reconnect controller; `pumpAndSettle` → greets Karim, error absent.
6. `a threaded name is never a failed band` — `_FailingRepository` + `name: 'Kamal'` →
   `jeeberGreetingAhlan('Kamal')`, error absent.
7. `a landed nameless profile keeps the fallback (contract: 200 with null display)` — keep the
   existing `_NamelessRepository` case in the loading test file; do not move it.

Edit `test/features/jeeber_home/jeeber_home_greeting_loading_test.dart:127-137`: the case becomes
`a FAILED getMe leaves the loading band for the failed band` (loading absent, error present,
fallback absent).

### 4.3 `test/features/jeeber_home/jeeber_home_retry_reloads_greeting_test.dart` (new)

Mount `JeeberHomeScreen` as `jeeber_home_failure_identifiers_test.dart:31-45` does, with
`AvailabilityCubit` whose gateway throws `AvailabilityGatewayException` (see
`test/features/jeeber_home/availability_load_failure_test.dart` for the throwing gateway) and an
ambient `GreetingProfileCubit` on a `_ThenSucceeds` repo (failed after first load). Tap
`'jeeber_home_load_error_retry_cta'`; `pumpAndSettle`; assert `cubit.state.status == resolved` and
`name == 'Karim TestJeeber'`. Second test: mount WITHOUT the greeting provider, tap retry → no throw.

### 4.4 `test/previews/jeeber_home/jeeber_home_greeting_preview_test.dart` (edit)

Add both new previews to `_previews` with `expectedText` `"Couldn't load your profile"`; add
`'the failed network preview has a retry cta'` (`'jeeber_home_greeting_retry_cta'` findsOneWidget,
`find.text('Welcome back')` findsNothing) and `'the session-expired preview has none'`; extend the
`carries no loading tag` loop with both. `test/previews/preview_structure_test.dart` (INV-7 floor 247)
counts previews per widget — adding previews only raises the count.

### 4.5 Guardrail/registry expectations after the change

- `secret_redactor_test` classification passes because of Step 6.
- `failure_identifier_coverage_ratchet_test` stays at 0 because 4.2 quotes both literals.
- `test/l10n/runtime_parity_test.dart` and `en_fallback_test.dart` untouched (no ARB change).
- `dart analyze --fatal-infos .` clean; comments ≤ 2 lines.

## 5. Validation on the real device (SM-A336B `RZCT505K7WF`, `app.jeeb.mobile.dev`)

Rules: `adb install -r` only, never uninstall, never "Clear Local Data"; sessions via Dev Tool →
Super Login → Super Login Plus → "Karim" (jeeber `106078a3-…`); product activity
`am start -n app.jeeb.mobile.dev/com.olivium.jeeb.MainActivity`; dumps with
`device-evidence-3/dumpui.sh <name> [delay]` pointed at a new dir
`$SCRATCH/device-evidence-4/` (copy the script, edit `EV=`). Build: `flutter build apk --debug`
(or the flavor recipe in `device-evidence-3/REPORT.md` "Build note": copy the two gitignored
`google-services.json` from `jeeb-mobile/` and `MAPS_API_KEY` into `android/local.properties`).

### 5.1 Baseline reproduction (BEFORE installing the fix) — proves P06 is real in place

1. `adb shell cmd connectivity airplane-mode enable`; `am force-stop`; `am start …MainActivity`.
2. Dashboard tab → `dumpui 01-outage-home` → expect `jeeber_home_error` (availability failed; band not mounted).
3. `adb shell cmd connectivity airplane-mode disable`; wait 5 s; tap `jeeber_home_load_error_retry_cta`
   (coordinates from the dump); `dumpui 02-baseline-bug 3`.
4. **Expected on `ecfd3cc1`: `content-desc="Welcome back"` and `jeeber_home_avatar` desc `"?"`** — the bug.

### 5.2 Reconnect + dashboard-retry recovery (AFTER the fix)

Repeat 5.1 steps 1-3 → `dumpui 03-fixed-after-retry 3`: expect `desc="Ahlan, Karim"`, avatar `"K"`,
no `jeeber_home_greeting_error`. `adb logcat -d | grep -E 'greeting_profile_(read_failed|reload)'`
→ expect `read_failed kind=network` then `reload reason=reconnect` (or `dashboard_retry`) — verify
the Diag sink reaches logcat in `lib/core/diagnostics/diag.dart:26` first; if it does not, the UI dump is the proof.

### 5.3 The failed band itself (partial outage: `/v1/users/me` 503, everything else live)

1. Reconciled (C2): `plans/p06-proxy.py` is retired — use the single shared fault proxy from P08
   (`tool/fault_proxy/fault_proxy.py --listen 127.0.0.1:8089 --upstream https://msi.olivium.space --rules $EV/rules.json`)
   with one rule `{"id":"users-me-503","match":{"method":"GET","path":"^/gateway/(v1/)?users/me(\\?.*)?$"},"times":0,"respond":{"status":503,"headers":{"Content-Type":"application/problem+json"},"body":"{\"type\":\"https://httpstatuses.com/503\",\"title\":\"Service Unavailable\",\"status\":503}"}}`;
   the "flag file" becomes `PUT /__fault/rules` / `DELETE /__fault/rules` (or swap `rules.json`, hot-reloaded).
2. `adb -s RZCT505K7WF reverse tcp:8089 tcp:8089` (phone `127.0.0.1:8089` → Mac proxy; the Mac is off
   the MSI LAN, so the proxy uses the Cloudflare URL).
3. Dev Tool (`am start -n app.jeeb.mobile.dev/com.olivium.jeeb.LegacyDevToolLauncher`) → Server URL →
   type `http://127.0.0.1:8089/gateway` (P08 convention: path forwarded verbatim, so the `/gateway` prefix stays) → **Apply & Restart**.
   Session survives the switch (same account, same token).
4. Dashboard → `dumpui 10-failed-band-en 4`. Expect: `jeeber_home_root`, `availability_card` (live),
   `jeeber_home_avatar` with NO letter, `desc="Jeeber dashboard"`, `desc="Couldn't load your profile"`,
   node `jeeber_home_greeting_error` with `content-desc` = the 503 body copy
   (`errorServiceUnavailableBody` — a 503 is `ServerFailure(unavailable: true)`), `jeeber_home_greeting_retry_cta`
   present; NO "Welcome back", NO `?`.
5. `rm /tmp/p06-fail-users-me`; tap `jeeber_home_greeting_retry_cta`; `dumpui 11-retry-t1 0.7` (expect
   `jeeber_home_greeting_loading`) and `dumpui 12-recovered 3` (expect `Ahlan, Karim`, avatar `K`, error absent).
6. AR: Profile tab → `customer_profile_language_row` → `language_arabic_option`; `touch` the flag;
   `am force-stop` + `am start …MainActivity`; dashboard → `dumpui 20-failed-band-ar 4`: expect
   `desc="تعذّر تحميل ملفك"` and `desc="لوحة الجيبر"`, `jeeber_home_greeting_error` present. Remove the
   flag, tap retry → `dumpui 21-recovered-ar 3`: `أهلاً، Karim`. Switch language back to English.
7. Restore: Dev Tool → Server URL → `https://msi.olivium.space/gateway` → Apply & Restart;
   `adb reverse --remove tcp:8089`; stop the proxy; `dumpui 30-final-baseurl` on the Server URL
   screen (as `58-final-baseurl.xml` did). Airplane mode off. Session left on Karim.

Write `device-evidence-4/REPORT.md` with the per-assertion table (same format as run 3) and the
logcat excerpt.

## 6. Risks

- **Contract blind spot:** the gateway returns 200 with null display when user-management is
  down (`UsersMeController.cs:151-186`), so a real backend degradation still greets "Welcome back".
  Closing that needs a gateway field (e.g. `displayDegraded: true`) — out of scope, listed in §7.
- **A red strip on a decorative band** could nag if `/users/me` alone stays broken; mitigated by
  auto-recovery on reconnect/resume/dashboard-retry and by the fact that the same outage usually
  fails availability first (full `jeeber_home_error`). No dismiss by design; add one only if the
  owner asks.
- **Identifier classification test** (`secret_redactor_test`) uses the analyzer over all of `lib/`;
  forgetting Step 6 fails the suite with `Unclassified static interaction identifiers`.
- **`ProviderNotFoundException`** name resolution in Step 3 — fall back to `on Object`.
- **Single-flight guard** must reset in `finally`; a thrown `emit` after `close()` would leak
  `_inFlight = true` — `Cubit.emit` after close throws `StateError`, which the `finally` still handles.
- **Client greeting** now receives `failed` states but ignores them; harmless, but the client's
  "Welcome back + ?" during loading (`device-evidence/outage/10-jeeber-home.xml`) remains a separate point.
- Device 5.3 relies on `adb reverse` + cleartext override; if the override refuses `http://127.0.0.1`,
  run the proxy with TLS off is impossible — fall back to 5.1/5.2 only and keep 5.3 as test-only proof.

## 7. Dependencies / follow-ups (not blocking)

- Gateway (owner-gated, separate PR on `jeeb-gateway`): add `displayDegraded` to `UsersMeResponse`
  when the UM display read is swallowed (`UsersMeController.cs:172-186`), so mobile can render the
  failed band instead of "Welcome back" in that case.
- Client home greeting: adopt the same loading/failed band (`client_home_greeting.dart`) — new pending point.
- PR #335 remains a draft; this lands as one more commit on the same branch.

## 8. Owner decision

None required. Defaults taken: reuse `customerProfileLoadErrorTitle` as the band's failed line
(no new ARB keys); no dismiss control on the strip; reconnect auto-retry limited to
Network/Timeout kinds per R6.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C3): depends on P13 landing first — `_classify` uses P13's `networkFailureFromReachability()` for the
  legacy `CustomerProfileFailure.network` case and the failing-repo fixtures use `NetworkFailure(offline: true)`;
  §5.3 asserts `errorServiceUnavailableBody` (503) which P13 does not touch. §5.1/5.2 (airplane mode) go through the
  real mapper and yield `offline: true` → `errorNetworkBody`, unchanged.
- Reconciled (C2): §5.3 uses the shared P08 proxy on port 8089 with override `http://127.0.0.1:8089/gateway`;
  `plans/p06-proxy.py` is not to be used (delete it once P08 D1 exists).
- Reconciled (C9/C16): Step 6 registry edit serializes after P12 Change A (already on `main` by then) and before P05's
  registry additions — rebase order P13 → P05 → P06 means P06 rebases over P05's registry lines; keep the set sorted.
- Reconciled (C12/C18): evidence dir `scratchpad/device-evidence-4/p06/`; record the phone's actual Android version
  (`getprop ro.build.version.release`, P08 measured 16 / SDK 36) in REPORT.md line 1.
- No owner decision.
