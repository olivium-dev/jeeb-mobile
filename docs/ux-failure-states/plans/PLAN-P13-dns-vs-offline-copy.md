# PLAN P13 — DNS / unreachable-host vs device-offline copy

Branch: `ux/api-error-handling-empty-states` @ `ecfd3cc1` (worktree
`/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`,
draft PR https://github.com/olivium-dev/jeeb-mobile/pull/335). Plan only — no
repo file was changed while writing this. Effort **M**. Mobile-only; no gateway
change, no deploy.

## 1. Problem (with evidence)

Run-1 build first-screen: the dev build launched with the compile-time
placeholder base URL `https://gateway.dev.invalid` (no `JEEB_BASE_URL`
dart-define, no `dev.base_url_override`), device on Wi-Fi, and the client home
rendered:

- `client_home_error_headline` = "Couldn't load your home"
- `client_home_error_body` = **"Check your connection and try again."**
- no `offline_banner` node anywhere in the dump

Evidence: `scratchpad/device-evidence/build/first-screen-ui.xml`
(resource-ids `client_home_error`, `client_home_error_body`,
`client_home_retry_cta`), `device-evidence/VERDICTS.txt` lines 4–5,
`device-evidence/JUDGE-RUN1.md` gap "Build first-screen … blamed the user's
connection … no scenario distinguishes DNS failure from device-offline copy".

The user's connection was fine; the host does not exist (RFC 2606 `.invalid`
TLD). Verified from this Mac 2026-09-05: `dig +short gateway.dev.invalid` →
empty; `curl https://gateway.dev.invalid/` → `curl: (6) Could not resolve
host`. The live gateway was up the whole time
(`https://msi.olivium.space/gateway/health/ready` → 200).

The same copy would be shown in production to a user whose phone is online
but whose DNS/route to `jeeb` is broken (our outage, captive portal, bad
resolver) — telling them to fix something that is not theirs to fix.

## 2. Root cause (verified in code)

1. **Transport shape.** Dart raises
   `SocketException("Failed host lookup: '<host>'", osError: OSError(…, errno))`
   for DNS failure (`flutter/bin/cache/dart-sdk/lib/_internal/vm/bin/socket_patch.dart:590`,
   `:1173`, `createError` `:1893-1905`). On Android the OSError is
   "No address associated with hostname, errno = 7"; on iOS errno 8. dio 5.11.0
   turns every non-timeout `SocketException` into
   `DioExceptionType.connectionError` (`~/.pub-cache/hosted/pub.dev/dio-5.11.0/lib/src/adapters/io_adapter.dart:113-135`),
   and "Connection closed before full header was received" `HttpException`
   too (`:178-188`). Nothing downstream keeps the reason.
2. **Mapper collapses it.** `lib/core/network/app_failure_mapper.dart:63-64`
   (`connectionError`) and `:70-71` (`unknown` + `SocketException`) both
   return `NetworkFailure(offline: _offline, cause: err)`, where `_offline`
   (`:129`) is `!NetworkReachabilitySignals.instance.isOnline`. With the
   device online that is `NetworkFailure(offline: false)` — the model already
   carries the discriminator (`lib/core/network/app_failure.dart:77-87`, doc
   comment "offline or unreachable"; `test/core/network/app_failure_test.dart:94-96`
   "NetworkFailure distinguishes offline from unreachable").
3. **Copy ignores the discriminator.**
   `lib/core/widgets/jeeb/app_failure_copy.dart:17-23` matches
   `case NetworkFailure():` with no `offline` read and always returns
   `errorNetworkTitle` / `errorNetworkBody` ("No connection" / "Check your
   connection and try again.", `lib/l10n/app_en.arb:5783-5785`,
   `app_ar.arb:2289-2290`). Every failure surface goes through `failureCopy`
   (`jeeb_failure_block.dart:110-111`, `jeeb_snack.dart`,
   `jeeb_refresh_failed_note.dart`, 24 feature screens), so fixing the
   resolver fixes every screen.
4. **The test locks the wrong behaviour in.**
   `test/core/widgets/app_failure_copy_test.dart:82-83` defines
   `_blamesConnectivity(f) => f is NetworkFailure || f is TimeoutFailure` and
   asserts (`:99-118`) that the body of `NetworkFailure()` (offline:false)
   *must* mention connection vocabulary. The programme rule (RULINGS R6 "only
   Network/Timeout blame connectivity") was implemented as "always blame", not
   "may blame when there is evidence".
5. **Reachability evidence is available and already wired.**
   `NetworkReachabilitySignals` is bound at app start to `connectivity_plus`
   (`lib/app/app.dart:414-430`, `lib/core/network/connectivity_reachability_source.dart`);
   `isOnline` reads unknown-as-online by design
   (`network_reachability_signals.dart:50-51` "never blame connectivity without
   evidence"); the `OfflineBanner` (`lib/features/offline_mode/presentation/offline_banner.dart:41-48`,
   key `offlineBannerMessage`) already tells the user when the device has no
   transport. So `offline: true` is the only case in which "Check your
   connection" is honest, and in that case the banner is on screen too.

Important nuance (drives the copy): in airplane mode Android ALSO returns
"Failed host lookup" errno 7. The errno therefore cannot tell offline from
unresolvable; **the reachability bus is the discriminator, the errno is
diagnostics**. And because `isOnline` reads unknown-as-online (cold-start
race with the connectivity seed, or Wi-Fi with no upstream), the
`offline:false` copy must not assert "your device is online".

## 3. Design

### 3.1 Model — `lib/core/network/app_failure.dart`

Add, next to `AppFailureKind`:

```dart
/// Transport evidence behind a NetworkFailure; diagnostics + tests, not copy.
enum NetworkFailureReason { unknown, hostLookup, refused, unreachable, closed, tls }
```

`NetworkFailure` gains `final NetworkFailureReason reason` (constructor param
`this.reason = NetworkFailureReason.unknown`, positioned after `offline`; all
existing `const NetworkFailure(offline: true)` / `const NetworkFailure()` call
sites — 15 in lib incl. `lib/devtool/catalog/**` — keep compiling). Keep
`offline` exactly as is (semantics unchanged: reachability said no transport).
Include `reason` in `==`, `hashCode`, `toString`
(`'NetworkFailure(offline: $offline, reason: ${reason.name})'`). Add doc:
"copy keys on [offline] only; [reason] is what the transport said". No
interface signature changes anywhere (R3 satisfied).

### 3.2 Mapper — `lib/core/network/app_failure_mapper.dart`

Add a pure, exported classifier (unit-testable, no Dio):

```dart
/// What the transport said. Message prefixes are Dart-SDK literals
/// (socket_patch.dart "Failed host lookup"); errnos: Android/Linux then Darwin.
NetworkFailureReason classifyTransportError(Object? err) {
  if (err is SocketException) {
    final String msg = err.message;
    final int? code = err.osError?.errorCode;
    if (msg.startsWith('Failed host lookup') ||
        code == 7 || code == 8 || code == -2 || code == -3 || code == -5) {
      return NetworkFailureReason.hostLookup;   // EAI_NODATA/EAI_NONAME/EAI_AGAIN
    }
    if (code == 111 || code == 61 || msg.contains('refused')) return NetworkFailureReason.refused;
    if (code == 101 || code == 113 || code == 51 || code == 65 || msg.contains('unreachable')) {
      return NetworkFailureReason.unreachable;  // ENETUNREACH/EHOSTUNREACH
    }
    if (code == 104 || code == 54 || msg.contains('reset') || msg.contains('closed')) {
      return NetworkFailureReason.closed;
    }
    return NetworkFailureReason.unknown;
  }
  if (err is TlsException) return NetworkFailureReason.tls;   // HandshakeException, CertificateException
  if (err is HttpException) return NetworkFailureReason.closed; // dio's "closed before full header" path
  return NetworkFailureReason.unknown;
}
```

Import `dart:io show HttpDate, HttpException, SocketException, TlsException`
and `../diagnostics/diag.dart`. Replace the three `NetworkFailure(...)`
constructions in `mapDioException` with one private helper:

```dart
NetworkFailure _networkFailure(DioException error, Object? err, {bool? offline}) {
  final NetworkFailureReason reason = classifyTransportError(err);
  final bool isOffline = offline ?? _offline;
  Diag.event('network_failure_classified', <String, Object?>{
    'reason': reason.name,
    'offline': isOffline,
    'reachability': NetworkReachabilitySignals.instance.knownOnline, // null = seed not resolved
    'errno': err is SocketException ? err.osError?.errorCode : null,
    'placeholderHost': error.requestOptions.uri.host.endsWith('.invalid'),
    'dioType': error.type.name,
  });
  return NetworkFailure(offline: isOffline, reason: reason, cause: err);
}
```

- `connectionError` → `_networkFailure(error, err)`.
- `badCertificate` → `_networkFailure(error, err, offline: false)` (reason
  resolves to `tls` when `err is TlsException`; if dio passed no error object
  it stays `unknown` — acceptable, `badCertificate` is the dio-side proof).
- `unknown` branch: `if (err is SocketException || err is TlsException) return _networkFailure(error, err);`
  (extends the existing SocketException-only test at
  `:70-72`; a TLS handshake failure today falls to `UnknownFailure`).

Never put the host name, URL, or `err.toString()` in the Diag payload (Diag
output reaches logcat/crash logs); `placeholderHost` is a bool on purpose.

`RetryInterceptor.isTransient` (`retry_interceptor.dart:57-60`: retries
`connectionError` twice, 300 ms base backoff, while online) is **not**
changed — a DNS failure now surfaces in ≈1–2 s instead of the 25 s connect
timeout, which is already the right shape. PR #330 token-refresh files
(`auth_interceptor.dart`) are untouched.

### 3.3 Reachability — `lib/core/network/network_reachability_signals.dart`

Add one public getter next to `debugOnline` (`:53`):
`bool? get knownOnline => _online;` (null = no evidence yet). No behaviour
change; used only by the Diag event above. Do not touch `isOnline`.

### 3.4 Copy — `lib/core/widgets/jeeb/app_failure_copy.dart`

```dart
case NetworkFailure(:final bool offline):
  return offline
      ? (title: l10n.errorNetworkTitle, body: l10n.errorNetworkBody, action: l10n.actionRetry, retryable: true)
      : (title: l10n.errorUnreachableTitle, body: l10n.errorUnreachableBody, action: l10n.actionRetry, retryable: true);
```

Update the file's header comment: "only `NetworkFailure(offline: true)` and
`TimeoutFailure` may tell the user to check their connection; an unreachable
host with transport present says Jeeb could not be reached."

`failureBlamesConnectivity` (`network_reachability_signals.dart:12-14`) stays
`network || timeout`: a reconnect edge (Wi-Fi→LTE) can still fix a DNS/route
failure, so snack auto-clear on reconnect and the refresh-note behaviour are
unchanged.

### 3.5 ARB + accessors — `lib/l10n/app_en.arb`, `app_ar.arb`, `app_localizations.dart`

Append after `errorTimeoutBody` (EN after line 5789 block; AR after line 2292):

| key | EN | AR |
|---|---|---|
| `errorUnreachableTitle` | Can't reach Jeeb | تعذّر الوصول إلى جيب |
| `errorUnreachableBody` | Jeeb couldn't be reached. If you're on Wi-Fi, check it has internet access, then try again. | تعذّر الوصول إلى جيب. إذا كنت تستخدم Wi-Fi فتأكّد من أنه متصل بالإنترنت، ثم حاول مجددًا. |

EN `@` metadata (AR ARB carries none — keep it that way):
- `@errorUnreachableTitle`: "Shared failure copy: NetworkFailure(offline:false) — transport present, host not answering (DNS/refused/route/TLS). Never 'No connection': the device has one."
- `@errorUnreachableBody`: "Shared failure copy: NetworkFailure(offline:false) body. Must not instruct 'check your connection' and must not claim the device is online (reachability may be unknown)."

Accessors in `app_localizations.dart` next to `:3357-3358`:
`String get errorUnreachableTitle => _get('errorUnreachableTitle');`
`String get errorUnreachableBody => _get('errorUnreachableBody');`

Owner alternative (see §8): fully neutral body "Jeeb couldn't be reached right
now. Try again in a moment." / "تعذّر الوصول إلى جيب الآن. حاول مجددًا بعد لحظات."

Why this wording: it is true in every `offline:false` sub-case (our DNS/outage,
dead Wi-Fi upstream, captive portal, placeholder dev URL, cold-start seed race)
and it names no plumbing (`server`, `gateway`, `dns`, `host`, `http` all
absent — the copy test's banned list is extended with `dns`, `lookup`,
`resolve`, `host`).

### 3.6 Preview + catalog (kit convention, never delete)

- `lib/core/widgets/jeeb/jeeb_failure_block.dart` after `jeebFailureBlockNetwork` (`:180-190`): add
  `@JeebPreview(group: 'core', name: 'Unreachable host (retry)', size: _jeebFailureBlockBox, matrix: true)`
  `Widget jeebFailureBlockUnreachable()` with
  `failure: const NetworkFailure(reason: NetworkFailureReason.hostLookup)`.
  INV-7 (`test/previews/preview_structure_test.dart:14`, floor 247) counts
  widgets, so adding a preview to an existing widget cannot lower coverage.
- `lib/devtool/catalog/fixtures/client_home_screen_fixtures.dart`: add
  `class UnreachableClientHomeRepository implements ClientHomeRepository`
  (copy of `ForbiddenClientHomeRepository` at `:71-77`, throwing
  `const NetworkFailure(reason: NetworkFailureReason.hostLookup)`) and
  `static ClientHomeRepository unreachableRepository()`.
- `lib/devtool/catalog/entries/batch_04_entries.dart`: append to
  `_clientHomeEntry.states` (after 'Forbidden — no inert retry', `:244-250`):
  `CatalogState("Cold load failed — can't reach Jeeb (host unresolved)", (_) => _clientHome(repository: ClientHomeScreenPreviewFixtures.unreachableRepository(), initialTab: ClientHomeTab.inProgress))`.
  Do NOT run `catalog_capture_test.dart --update-goldens` (R6).

## 4. Fix steps (ordered)

1. jeeb-mobile `lib/core/network/app_failure.dart`: add `NetworkFailureReason`, the `reason` field on `NetworkFailure`, `==`/`hashCode`/`toString` (§3.1).
2. jeeb-mobile `lib/core/network/network_reachability_signals.dart`: add `bool? get knownOnline` (§3.3).
3. jeeb-mobile `lib/core/network/app_failure_mapper.dart`: add `classifyTransportError`, `_networkFailure` with the Diag event, rewire the three branches, widen the `unknown` branch to `TlsException` (§3.2).
3b. Reconciled (C3) — jeeb-mobile legacy sites: 22 `lib/` sites map a per-feature `Failure.network` enum to
   `const NetworkFailure()` (offline:false) and would render the new unreachable copy while the device is offline:
   `lib/core/role/role_sync.dart:72`, `features/settings/presentation/screens/profile_edit_screen.dart:222`,
   `features/offers/presentation/offer_submission_screen.dart:354`, `features/cancel_request/presentation/cancel_request_sheet.dart:120`,
   `features/rating/domain/rating_repository.dart:59`, `features/settlement/application/settlement_cubit.dart:156`,
   `features/delivery_receipt/presentation/delivery_receipt_screen.dart:650`, `features/otp_handover/presentation/otp_handover_screen.dart:287`,
   `features/tier_selection/cubit/tier_selection_cubit.dart:33`, `features/live_tracking/application/live_tracking_cubit.dart:186`,
   `features/account_status/application/account_status_cubit.dart:79`, `features/client_offers/domain/offers_repository.dart:109`,
   `features/no_offer_timeout/domain/waiting_repository.dart:38`, `features/earnings/application/earnings_cubit.dart:153`,
   `features/notification_prefs/application/notification_prefs_cubit.dart:176`, `features/wallet/application/wallet_hub_cubit.dart:81`,
   `features/wallet/application/transaction_detail_cubit.dart:68`, `features/wallet/application/wallet_ledger_cubit.dart:147`,
   `features/order_summary/presentation/order_summary_screen.dart:263`, `features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart:940`,
   `features/deep_link_targets/chat_detail_screen.dart:1162`, `features/request_summary/application/request_summary_cubit.dart:131`
   (catalog fixtures in `lib/devtool/catalog/entries/batch_04/05_entries.dart` are deliberate and stay).
   Add to `app_failure_mapper.dart` an exported `NetworkFailure networkFailureFromReachability({Object? cause}) =>
   NetworkFailure(offline: _offline, cause: cause)` (2-line doc) and switch each site to it (prefer carrying the
   classified `AppFailure` where the exception already has one, e.g. `e.appFailure ?? networkFailureFromReachability()`).
   Add `test/guardrails/no_offline_blind_network_failure_test.dart`: ratchet on `const NetworkFailure()` under
   `lib/features` + `lib/core/role`, floor = count remaining after the sweep (target 0), never raised.
4. jeeb-mobile `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart`: the two keys + two getters (§3.5). Check `jq . lib/l10n/app_en.arb >/dev/null` and same for AR.
5. jeeb-mobile `lib/core/widgets/jeeb/app_failure_copy.dart`: branch on `offline` (§3.4).
6. jeeb-mobile `lib/core/widgets/jeeb/jeeb_failure_block.dart`: `jeebFailureBlockUnreachable` preview (§3.6).
7. jeeb-mobile `lib/devtool/catalog/fixtures/client_home_screen_fixtures.dart` + `lib/devtool/catalog/entries/batch_04_entries.dart`: fixture + appended CatalogState (§3.6).
8. jeeb-mobile tests (§5). `git add -A` every new file BEFORE `flutter test` (mb1 residual-receipts test fails on untracked .dart — R6).
9. Gates (§6). Fix anything red; never lower a ratchet floor.
10. Device proof (§7); write `scratchpad/device-evidence-4/p13/REPORT.md`.
11. Reconciled (C1): commit on follow-up branch `fix/unreachable-host-copy` (stacked now, `git rebase --onto origin/main ux/api-error-handling-empty-states fix/unreachable-host-copy` after the #335 squash) — the FIRST wave-2 mobile PR, because P05/P06/P07/P09 expectations depend on it: `fix(ux): unreachable host no longer blames the user's connection — NetworkFailure.reason + offline-aware copy (P13)`; push; link the evidence dir in the PR. No deploy involved.

## 5. Tests

All new tests assert by `find.bySemanticsIdentifier`, pump EN **and** AR
(`kFailureLocales` from `test/core/widgets/jeeb/jeeb_failure_test_harness.dart`),
`useReduceMotion(tester)` before `pumpAndSettle` (R6).

1. `test/core/network/app_failure_mapper_test.dart` — new group `'transport reasons'`
   (fixture pattern: `:72-100`; `NetworkReachabilitySignals.instance.debugObserve` / `debugReset` in tearDown):
   - `connectionError` + `SocketException("Failed host lookup: 'gateway.dev.invalid'", osError: OSError('No address associated with hostname', 7))`, bus online → `NetworkFailure(offline: false, reason: hostLookup)`.
   - same, bus `debugObserve(online: false)` → `offline: true, reason: hostLookup` ("airplane mode gives the same errno; the bus decides").
   - same, after `debugReset()` (no evidence) → `offline: false` (documents the unknown-reads-online rule).
   - `OSError('Connection refused', 111)` and `61` → `refused`; `101`/`113`/`51`/`65` → `unreachable`; `104`/`54` → `closed`.
   - `unknown` type + `HandshakeException('bad')` → `NetworkFailure(reason: tls)` (today: `UnknownFailure` — regression-proof the widening).
   - `badCertificate` → `NetworkFailure(reason: tls, offline: false)`.
   - existing `SocketException('closed')` test (`:92-100`) now also asserts `reason == closed`.
   - `classifyTransportError(null)`/`classifyTransportError(StateError('x'))` → `unknown`.
   - Diag: wrap one mapping in `Diag` capture (see how `network_reachability_signals_test.dart` observes `Diag.event`, or assert via `Diag` test hook if one exists; otherwise assert no throw) and verify the payload has no `'invalid'`/host substring — only `placeholderHost: true`.
2. `test/core/network/app_failure_test.dart`: `:94-96` add reason assertions; `:204` equality — `NetworkFailure(reason: hostLookup) != NetworkFailure()`; `:242-243` toString → `'NetworkFailure(offline: true, reason: unknown)'` and a `hostLookup` case; kind table unchanged.
3. `test/core/widgets/app_failure_copy_test.dart`:
   - `_kAllFailures` += `NetworkFailure(reason: NetworkFailureReason.hostLookup)`, `NetworkFailure(reason: refused)`, `NetworkFailure(offline: true, reason: hostLookup)`.
   - `_blamesConnectivity` → `f is TimeoutFailure || (f is NetworkFailure && f.offline)`; the vocabulary group skips `NetworkFailure(offline: false)` (its copy is governed by the new group).
   - New group `'failureCopy · an unreachable host never blames the user's connection'`: for every `NetworkFailure(offline: false)` in EN: `body` does not contain `'check your connection'`, `body != en.errorNetworkBody`, `title != en.errorNetworkTitle`, `body == en.errorUnreachableBody`; AR: body does not contain `'تحقّق من اتصالك'`, `!= ar.errorNetworkBody`, `== ar.errorUnreachableBody`. And the mirror: `NetworkFailure(offline: true, reason: hostLookup)` still gets `errorNetworkBody` in both locales ("the errno is not the discriminator").
   - `_kBannedEn` += `'dns'`, `'lookup'`, `'resolve'`, `'host'`.
4. `test/core/widgets/jeeb/jeeb_failure_block_test.dart`: `_kKinds` += `'unreachable': NetworkFailure(reason: NetworkFailureReason.hostLookup)` (the loop renders title/body by identifier in EN+AR automatically); plus one explicit test: pump `wallet_hub_error` with offline:true then offline:false, assert `find.text(l10n.errorNetworkBody)` vs `find.text(l10n.errorUnreachableBody)` are mutually exclusive, both locales.
5. `test/core/widgets/jeeb/jeeb_snack_test.dart`: one case — `showJeebErrorSnack(failure: NetworkFailure(reason: hostLookup))` shows `errorUnreachableBody` and still `clearOnReconnect` (behaviour unchanged).
6. `test/client_home_screen_test.dart` (group at `:1272`): new widget test using a `_UnreachableClientHome implements ClientHomeRepository` throwing `NetworkFailure(reason: hostLookup)`; for both locales assert `client_home_error` present, `client_home_error_body` semantics label == `l10n.errorUnreachableBody`, `client_home_retry_cta` present, and `find.bySemanticsIdentifier('offline_banner')` finds nothing.
7. l10n: `test/l10n/runtime_parity_test.dart` picks the new keys up automatically; `qa/t-mob-fix-002/l10n_parity_check.sh --analyze` and `qa/t-mob-fix-002/ar_plurals_check.sh` must stay at their current counters (no plurals added).
8. Previews: `flutter test test/previews` (INV-7 floor 247 must not drop; a new preview cannot drop it).

## 6. Gates (all must be green before device proof)

```
cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors
git add -A
dart analyze --fatal-infos .
flutter test --exclude-tags capture            # baseline 10539 pass / 0 fail / 109 skip; coverage floor 79 % (landed 84.65 %)
qa/t-mob-fix-002/l10n_parity_check.sh --analyze
qa/t-mob-fix-002/ar_plurals_check.sh
tool/check_design_tokens.sh
```
Flutter 3.44.2 / Dart 3.10.2 pinned. Guardrail ratchets (`showOmdsErrorSnackbar`,
raw `ScaffoldMessenger.showSnackBar`, `OmdsErrorState`/`OmdsLoadingState`,
preview floor) are untouched by this change; if any ratchet moves, stop and
investigate — this plan adds no banned pattern.

## 7. Device proof (real UI, SM-A336B RZCT505K7WF, Android 14)

Rules: `adb install -r` only, never uninstall, no Clear Local Data; this Mac is
off the MSI LAN so the real gateway is `https://msi.olivium.space/gateway`
(preflight `curl -s -o /dev/null -w '%{http_code}' https://msi.olivium.space/gateway/health/ready` → 200).
Session on the phone is the existing client `devtool_client_1788592148874`
(or Karim via Dev Tool → Scenario Users → Super Login Plus for a jeeber view;
super-login is allowed for non-login features).

Build/install exactly as `device-evidence-2/build/REPORT.md` (copy the two
gitignored `google-services.json` files from the main clone, verify
`project_id` = `jeeb-5a293`, pass `-PMAPS_API_KEY=<key>` as a Gradle property):

```
flutter build apk --debug --flavor dev -t lib/main.dart -Pjeeb.devtool=true -PMAPS_API_KEY=<key> --dart-define=JEEB_DEVTOOL_ENABLED=true
adb -s RZCT505K7WF install -r build/app/outputs/flutter-apk/app-dev-debug.apk
```

Evidence dir: `scratchpad/device-evidence-4/p13/` — for every step a
`NN-<name>.png` + `NN-<name>.xml` (`adb shell uiautomator dump` then pull), a
running `adb logcat -s jeeb-diag flutter > logcat.txt`, and `REPORT.md` with a
PASS/FAIL table. Assert by `resource-id`, never by pixel.

Scenario U — unreachable host, device online (the P13 case itself):
1. Wi-Fi ON. Open the Dev Tool (launcher alias `app.jeeb.mobile.dev/com.olivium.jeeb.LegacyDevToolLauncher`) → Server URL → type `https://gateway.dev.invalid` → Save → **Apply & Restart** (override key `dev.base_url_override` beats every dart-define and skips the cleartext policy — nothing applies before Apply & Restart).
2. Within ≈3 s of the home appearing dump the UI. **PASS iff** `client_home_error` present, `client_home_error_body` content-desc == "Jeeb couldn't be reached. If you're on Wi-Fi, check it has internet access, then try again.", `client_home_retry_cta` present, **no** `offline_banner` node, and logcat has `network_failure_classified` with `reason=hostLookup offline=false placeholderHost=true`.
3. Tap `client_home_retry_cta`; assert `client_home_loading` appears (no placeholder copy) then the same error body again.
4. Optional but cheap: Server URL → `http://127.0.0.1:9` → Apply & Restart → same body, logcat `reason=refused errno=111` (proves the refused path on the same copy).

Scenario O — device offline (control; proves the bus is the discriminator):
5. Keep the `.invalid` override. Airplane mode ON (`adb shell cmd connectivity airplane-mode enable`, or Quick Settings by hand). Tap `client_home_retry_cta`.
6. **PASS iff** `offline_banner` present with the `offlineBannerMessage` content-desc, `client_home_error_body` == "Check your connection and try again.", and logcat shows `reason=hostLookup offline=true` (same errno 7 as U — only `offline` differs).
7. Airplane mode OFF → banner disappears without a tap (existing F5/F6 behaviour); tap Retry → back to the Scenario-U body.

Scenario A — Arabic:
8. Restore the override to `https://msi.olivium.space/gateway` → Apply & Restart → home loads; Profile → Language → العربية (real UI). Set the `.invalid` override again → Apply & Restart. Assert `client_home_error_body` == "تعذّر الوصول إلى جيب. إذا كنت تستخدم Wi-Fi فتأكّد من أنه متصل بالإنترنت، ثم حاول مجددًا." Then airplane mode ON + Retry → "تحقّق من اتصالك وحاول مجددًا." + `offline_banner`. Airplane OFF.

Restore:
9. Language back to English; Server URL → `https://msi.olivium.space/gateway` → Apply & Restart; dump `99-restored.xml` showing `client_home_root` with no `client_home_error`, session still `devtool_client_1788592148874` (no login wall). Note the run in `REPORT.md` with SHA, APK size, timestamps.

Timing note for the judge: DNS failure surfaces in ≈1–2 s (two retry
attempts × 300–600 ms backoff), not the 25 s seen in the TCP-blackhole
outage runs — dump promptly or the loading rung will be missed.

## 8. Owner decision

Copy approval for the new `offline:false` state — **YES** = ship
"Can't reach Jeeb" / "Jeeb couldn't be reached. If you're on Wi-Fi, check it
has internet access, then try again." (+ AR above); **NO** = ship the fully
neutral body "Jeeb couldn't be reached right now. Try again in a moment." /
"تعذّر الوصول إلى جيب الآن. حاول مجددًا بعد لحظات." Everything else in this plan is
the same under both answers.

## 9. Risks

- Copy-test flip: the existing `_blamesConnectivity` rule is inverted for
  `NetworkFailure(offline:false)`; any feature test that hard-codes
  `errorNetworkBody` for a non-offline `NetworkFailure()` will fail — the 12
  files that reference `errorNetworkBody`/"Check your connection" in `test/`
  (e.g. `test/features/tier_selection/tier_selection_failure_copy_test.dart`,
  `test/features/earnings/earnings_dashboard_states_test.dart`) must be
  re-read; fix by switching the fixture to `NetworkFailure(offline: true)`
  where the scenario is "no transport", or to `errorUnreachableBody` where it
  is "host down".
- `toString` change (`app_failure_test.dart:242`) and any golden/log text that
  embeds `NetworkFailure(offline: true)` — grep `test/` for the literal.
- `lib/devtool/catalog/**` compiles unchanged (constructor param is optional),
  but every `implements ClientHomeRepository` fixture must still satisfy the
  interface — no signature change, so none should break (R3).
- Cold-start seed race: for the first few hundred ms `knownOnline` is null →
  `offline:false` → unreachable copy even in airplane mode; the banner then
  appears when the seed resolves. Accepted (copy makes no online claim); the
  Diag payload records `reachability: null` so the judge can recognise it.
- Wi-Fi with no upstream / captive portal produces the unreachable copy; the
  Wi-Fi clause is what keeps that honest — if the owner picks the neutral
  variant this sub-case loses its hint.
- Unrelated CI red on `origin/main` is a known trap (memory: local mobile gate
  skew); judge from the worktree gate figures in §6, not from the main clone.

## 10. Non-goals

- No RetryInterceptor policy change; no gateway change; no new screen; no
  change to `isOnline` semantics; no devtool "placeholder URL" banner (the
  Diag `placeholderHost` bool is the traceability hook — a launcher-banner
  hint is a separate point if the owner wants it).
- Timeout copy ("The connection timed out before we got an answer") is left as
  is — it does not instruct the user to fix their connection.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C3) — downstream contracts that change with this plan and were edited accordingly: P06 (`_classify` uses
  `networkFailureFromReachability`, fixtures `NetworkFailure(offline: true)`), P07-F6 (AR guard allowlist gains `Wi-Fi`
  for `errorUnreachableBody`), P09 §1.3/S2.3 (`drop` on a P13 build → unreachable copy), P08 risk note (dead `adb
  reverse` → "Can't reach Jeeb"). RULINGS R6 "only Network/Timeout blame connectivity" is refined to "only
  `NetworkFailure(offline: true)` and `TimeoutFailure`"; record that refinement in `docs/adr/0004-app-failure-model.md` (P10 §6).
- Reconciled (C3): the 19 test files that reference `errorNetworkBody`/"Check your connection" (probe 2026-09-05:
  client_offers_screen_test, jeeb_empty_state_reason_test, cancel_request_terminal_cta_test, earnings_dashboard_states_test,
  funding_wallet_headline_test, request_feed_states_midnight_test, kyc_wizard_load_status_failure_test, waiting_screen_test,
  offer_kyc_gate_retry_test, offer_composer_error_l10n_test, order_summary_screen_test, display_name_cubit_failure_carry_test,
  request_summary_failure_copy_test, live_settings_midnight_test, tier_selection_failure_copy_test, transaction_detail_terminal_cta_test,
  cancel_request_sheet_preview_test, tier_selection_screen_preview_test, super_login_picker_test) plus 65 `NetworkFailure()`
  fixtures are the blast radius of §9 risk 1 — budget the sweep.
- Reconciled (C10/C9): first in the wave-2 l10n order; no registry entry needed (no new identifier).
- Reconciled (C12/C18): evidence dir `scratchpad/device-evidence-4/p13/` (unchanged); record the actual Android version.
- Owner decision renumbered: OD-17 (copy variant; default YES wording if unanswered).
