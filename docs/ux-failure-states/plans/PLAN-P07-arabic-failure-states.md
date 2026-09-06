# PLAN P07 — Arabic failure states validated on the real device

> Session helper note: `dump.sh` meant an adb UI-automator dump plus pull/identifier parsing; `shot.sh` meant an adb screenshot. Recreate these helpers locally or use the reviewed P08 tooling when it lands; they are not shipped with this historical plan.

Branch `ux/api-error-handling-empty-states` (worktree `/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`, `ecfd3cc1` on `origin/main@ab610933`, draft PR #335).
Device SM-A336B `RZCT505K7WF`, Android 14, app `app.jeeb.mobile.dev`, install `-r` only, never uninstall.
Owner rules that bind this plan: no new repo; Flutter 3.44.2; gates = `dart analyze --fatal-infos .` + `flutter test --exclude-tags capture` (79 % floor) + l10n parity + AR plurals + `tool/check_design_tokens.sh`; comments ≤ 2 lines; identifier grammar `<screen>_loading|_empty|_error` + `<screen>_retry_cta`; tests assert by identifier in EN **and** AR; PR #330 token-refresh invariants untouched; deploys owner-gated (nothing here deploys anything).

---

## 0. Verified current state (what is true today, with evidence)

| # | Fact | Evidence |
|---|---|---|
| 0.1 | AR was **never** checked on any failure state on a device. Run 1 checked AR only on happy/empty screens (settings, order history, saved addresses, Earn-tab empty, profile). | `device-evidence/JUDGE-RUN1.md` gaps[7]; `device-evidence/empty/35-settings-ar.xml`, `37-orderhistory-ar.xml`, `39-saved-ar.xml`; `FINAL-REPORT.md` §7 f |
| 0.2 | Runs 2 and 3 were EN only: every content-desc in `device-evidence-2/offline-a11y/REPORT.md` ("You're offline…", "Check your connection…", "Retry", "Dismiss") and `device-evidence-2/outage-jeeber/REPORT.md` ("This is taking too long", "Couldn't load orders") is English. | those two files, assertion tables |
| 0.3 | Locale is an **in-app preference**, not the device locale: `LocaleCubit._resolveInitial` = dev-seam `jeeb.locale` (debug only) → SharedPreferences `app.locale.languageCode` → device locale → `en`. Device is `en-NL` (`adb shell getprop persist.sys.locale`). The pref survives `install -r` and Apply & Restart. | `lib/core/locale/locale_cubit.dart:55-72`; `lib/core/dev_seam/dev_seam_config.dart:156` |
| 0.4 | The only real-UI locale switch is the Settings pill `settings_language_ar_option` / `settings_language_en_option` (`JeebSegmentedToggle` → `LocaleCubit.setLocale`) and the Language screen (`language_arabic_option`, route `/settings/language`, reached from the customer profile). Both live **inside the loaded state** of a network-backed screen — under an outage Settings renders `settings_error` (+ `settings_retry_cta`, exit = sign-out) and Profile renders `customer_profile_load_error`, so the pill is unreachable. **Consequence: switch to AR while the real gateway is up, then inject faults; restore the gateway before switching back.** | `lib/features/settings/presentation/widgets/settings_language_toggle.dart:27-45`; `settings_screen.dart:225-262`; `language_settings_screen.dart:107-116`; `customer_profile_screen.dart:224`; run-2 outage report F4.6 |
| 0.5 | `setLocale` also pushes the preference to the gateway; an offline push flips `hasPendingLanguagePush` and shows `language_sync_pending_note` (AR "ستتم مزامنة لغتك عند عودة الاتصال."). `syncFromServer` never reverts a pending local change. | `locale_cubit.dart:78-118,120-132`; ARB `languageSyncPendingBody` |
| 0.6 | All failure copy resolves from the ARB only: `failureCopy()` never reads gateway `title`/`detail`; the app sends no `Accept-Language`; the live gateway returns English RFC 7807 regardless of `Accept-Language: ar` (`{"title":"Unauthorized","status":401}` for both). The only `problem.detail` consumer (`KycSubmitFieldException.detail`) is discarded — `kyc_wizard_cubit.dart:246-253` maps `e.field` only. **No gateway localisation work is needed for this point.** | `lib/core/widgets/jeeb/app_failure_copy.dart:15-113`; `grep -rn Accept-Language lib` = 0; live probe `curl -H 'Accept-Language: ar' https://msi.olivium.space/gateway/v1/users/me` → 401 problem+json, English title; `lib/features/kyc/data/dio_kyc_gateway.dart:88` |
| 0.7 | Every failure-family ARB key (505 keys matching error/invalid/failed/…/loading) has a non-empty, non-identical AR value; 0 use Arabic-Indic digits; the plural sets `errorRateLimitedRetryIn*`, `registrationOtpRateLimitedSeconds*`, `otpHandoverAttemptsRemaining*` have all six AR forms with correct Few ("ثوانٍ"/"محاولات") vs Many ("ثانية"/"محاولة"). `_cldrPlural` implements AR rules (0→Zero, 1, 2, %100∈3..10→Few, 11..99→Many, else Other) and substitutes **Western digits** (`'$count'`). | scratch audit over `lib/l10n/app_ar.arb`; `lib/l10n/app_localizations.dart:1130-1146` |
| 0.8 | AR copy defects found by the audit (fixed in §2): (a) `registrationSocialErrorNetwork` AR contains Latin brand token "Jeeb" while the rest of the AR ARB uses "جيب" 114× vs "Jeeb" 7× (`errorServiceUnavailableBody` = "جيب غير متاح مؤقتًا…"); (b) `offerComposerPriceRequired` AR uses Arabic-Indic "٠" while the ar-LB standard in `qa/t-mob-fix-002/ar-visual-checklist.md` (matrix "Numeral system: Western 0–9") and every plural set use Western digits; (c) register drift: `orderHistoryLoadingHeadline` "عم نجيب طلباتك" and `jeeberTabsLoadingHeadline` "عم نتحقق من حسابك" are Levantine dialect while every sibling loading headline is MSA ("جارٍ تحميل أرباحك", "جارٍ تحميل ملفك", "نتحقّق من حالة توفّرك"). | ARB values printed in the audit; `qa/t-mob-fix-002/ar-visual-checklist.md` test matrix |
| 0.9 | Copy defect in both languages: `otp_verification_screen.dart:589` renders `registrationOtpRateLimitedSeconds(retryAfterSeconds ?? 0)` — the gateway's local OTP burst guard (3/phone/60 s) emits **429 without `Retry-After`** (`AuthOtpController.cs:144-147` → `OtpSignInProblems.Problem(...)` has no retryAfter; `dio_otp_service.dart:46-49` passes `retryAfter: null`), so the Zero branch "Request a new code **now**." / "اطلب رمزًا جديدًا الآن." is shown to a throttled user. | gateway `origin/main@6679f6e` `src/JeebGateway/Auth/OtpSignIn/AuthOtpController.cs:141-147`, `OtpRequestRateLimiter.cs:53-60`; mobile files cited |
| 0.10 | Kit RTL hygiene is clean at source: 0 non-directional hazards (`EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, forced `TextDirection.ltr`) in `jeeb_empty_state.dart`, `jeeb_failure_block.dart`, `jeeb_info_note.dart`, `jeeb_cta_button.dart`, `jeeb_snack.dart`, `jeeb_refresh_failed_note.dart`, `jeeb_state_host.dart`, `offline_banner*.dart`; OMDS `omds_primary_button.dart` also clean. Headline/body are `TextAlign.center`; CTA rows are `Row`s (mirror automatically); `JeebCtaButton.mirrorIcons` defaults false (the Retry `Icons.refresh` glyph is not flipped — accepted, symmetric). Illustrations are deliberately un-mirrored (run-1 note). | grep results; `jeeb_cta_button.dart:305-316,472-497`; `jeeb_empty_state.dart:392-420` |
| 0.11 | Existing tests pump AR for **copy** only: `kFailureLocales = [en, ar]` loops in `jeeb_failure_block_test.dart:57`, `jeeb_snack_test.dart:133,437`, `jeeb_refresh_failed_note_test.dart:28,192`, `offline_banner_test.dart:82,150`. **No test asserts RTL geometry** (which side Retry/Dismiss land on, action-vs-content order in the snack, banner action side). `catalog_capture_test.dart` has no locale parameter (EN captures only). | files cited; `test/tools/catalog_capture_test.dart:100-115` |
| 0.12 | The snack's Retry is a `SnackBarAction` with `Key('<id>_retry_cta')`, **not** a semantics identifier — on device it is only findable as the sibling `android.widget.Button` by content-desc (EN "Retry" in run 2; AR will be "إعادة المحاولة"). | `jeeb_snack.dart:133-142`; `offline-a11y/REPORT.md` semantics dump |
| 0.13 | Fault injection on device is possible without touching the gateway: the dev flavor's `network_security_config.xml` permits cleartext to `127.0.0.1`/`localhost`; `dev.base_url_override` accepts any URL; so `adb reverse tcp:8089 tcp:8089` + a Mac-hosted RFC 7807 fault server at `http://127.0.0.1:8089` exercises 5xx/429/404/409/422 bodies that the blackhole (`http://10.255.255.1:9`, connect-timeout only) never could. Mapper: 429 → `RateLimitedFailure(retryAfter)` from `Retry-After` seconds; ≥500 → `ServerFailure(unavailable: status==503, retryAfter)`; `RetryInterceptor` retries 502/503/504 twice; `RateLimitInterceptor` suppresses the path-prefix scope for `retryAfter`. | `android/app/src/dev/res/xml/network_security_config.xml`; `lib/core/config/dev_base_url.dart`; `app_failure_mapper.dart:27-35,88,114-123`; `retry_interceptor.dart:13,64-65`; `rate_limit_interceptor.dart:30-91` |
| 0.14 | Build prerequisites for the worktree (both gitignored, copied from the main clone): `android/app/google-services.json` + `android/app/src/dev/google-services.json` (`project_id` must be `jeeb-5a293`), and `MAPS_API_KEY` must be passed as `-PMAPS_API_KEY=…` (present in `jeeb-mobile/android/local.properties`; `flutter build` rewrites `local.properties`). | `device-evidence-2/build/REPORT.md`; `android/app/build.gradle:25-27` |

---

## 1. Scope

"Failure state" = the five surfaces the programme landed, in Arabic, on the real device, driven through the real UI:

1. **Offline banner** (`offline_banner`, `offline_banner_dismiss_cta`) — `OfflineBanner`/`OfflineBannerHost`.
2. **Refresh-failed surfaces** — snack (`<screen>_refresh_failed_snack` + sibling Retry button) and note (`<screen>_refresh_failed_note` + `_retry_cta`/`_dismiss_cta`).
3. **Failure blocks** (`<screen>_error`, `_error_headline`, `_error_body`, `<screen>_retry_cta` / `_exit_cta`) for every `AppFailure` kind reachable on device.
4. **Validation copy** — inline field errors (`recipient_phone_input` errorText) and the countdown/attempt plurals.
5. **Loading headlines** that precede each failure (`<screen>_loading`), because the AR register drift (0.8c) is visible only there.

Out of scope (recorded, not attempted): 401/session-expired on device (it would sign the account out through the PR #330 lane — copy is covered by unit tests in EN+AR); chat surfaces (unreachable in the shell per run-1 gap); TalkBack Arabic TTS (needs an AR TTS engine installed; optional extra).

---

## 2. Code fixes anticipated (do these BEFORE the device run so the run validates the fixed build)

All in the worktree above, on the existing branch. `git add` every new file before `flutter test`.

### P07-F1 — AR brand token in failure copy
File `lib/l10n/app_ar.arb`, key `registrationSocialErrorNetwork`:
`"تعذّر الاتصال بـ Jeeb. تحقّق من اتصالك وحاول مجددًا."` → `"تعذّر الاتصال بجيب. تحقّق من اتصالك وحاول مجددًا."`
(Parity with `errorServiceUnavailableBody` "جيب غير متاح مؤقتًا…" and the 114 other "جيب" usages. Do not touch non-failure keys such as `settingsUnregisterJeeberTitle` — WP-9 scope.)

### P07-F2 — Western digits in validation copy
File `lib/l10n/app_ar.arb`, key `offerComposerPriceRequired`: `"أدخل سعراً أكبر من ٠"` → `"أدخل سعراً أكبر من 0"`. (The other 17 Arabic-Indic literals are hero/marketing copy, not failure copy — list them in the PR body as a WP-9 follow-up, do not change here.)

### P07-F3 — 429 without Retry-After must not say "now"
File `lib/features/registration/presentation/otp_verification_screen.dart:588-589`:
```dart
case RegistrationOtpError.rateLimited:
  final int? seconds = retryAfterSeconds;
  return seconds == null
      ? l10n.errorRateLimitedBody
      : l10n.registrationOtpRateLimitedSeconds(seconds);
```
(`errorRateLimitedBody` = "Wait a moment before trying again." / "انتظر لحظة قبل المحاولة مجددًا." — already in both ARBs.) Test: extend `test/otp_verification_screen_test.dart` with a rate-limited state whose `retryAfterSeconds` is null, asserting `find.text(l10n.errorRateLimitedBody)` in EN and AR and `findsNothing` for the Zero-branch string.

### P07-F4 — AR register drift on loading headlines (OWNER-CONFIRM, see §7)
File `lib/l10n/app_ar.arb`: `orderHistoryLoadingHeadline` → `"جارٍ تحميل طلباتك"`, `jeeberTabsLoadingHeadline` → `"جارٍ التحقق من حسابك"`. Apply only if the owner confirms "system copy = MSA" (default in this plan). If the owner prefers Levantine for all system copy, invert: leave these two and open a WP-9 ticket to convert the MSA siblings — do NOT ship a mix.

### P07-F5 — RTL geometry tests (new, `test/core/widgets/jeeb/jeeb_failure_rtl_test.dart`)
Use `wrapMidnight(child, locale: const Locale('ar'))` from `jeeb_failure_test_harness.dart`. Assert, in AR only (EN mirror as control):
- `Directionality.of(tester.element(find.byType(JeebFailureBlock))) == TextDirection.rtl`.
- `JeebFailureBlock(failure: TimeoutFailure(...), identifier: 'x_error', onRetry: …)`: retry CTA centre `dx` within 8 px of the host width / 2; the `Icons.refresh` glyph's `dx` **greater** than the label's `dx` (leading icon sits to the right in RTL).
- `JeebRefreshFailedNote(identifier: 'x_refresh_failed', onRetry, onDismiss)`: `tester.getTopLeft(bySemanticsIdentifier('x_refresh_failed_dismiss_cta')).dx < tester.getTopLeft(bySemanticsIdentifier('x_refresh_failed_retry_cta')).dx` (dismiss is leftmost in RTL) and the inverse in EN.
- `showJeebErrorSnack(... onRetry)`: `find.byKey(Key('x_snack_retry_cta'))` centre `dx` < content text centre `dx` in AR; inverse in EN.
- `OfflineBanner` (host from `offline_banner_test.dart`): `offline_banner_dismiss_cta` centre `dx` < `Icons.cloud_off` centre `dx` in AR; inverse in EN.
- Every asserted node's label byte-equals the ARB AR value (`AppLocalizations.of(ctx).<key>`), contains no `[A-Za-z]{3,}` and no `[٠-٩]`.
Ship previews? None needed — no new widget (INV-7 floor untouched).

### P07-F6 — AR failure-copy guard (new, `test/l10n/ar_failure_copy_guard_test.dart`)
Load both ARBs from disk (pattern of `test/l10n/runtime_parity_test.dart`). For every non-`@` key matching `/(error|invalid|failed|unavailable|denied|cannot|couldn|retry|offline|timeout|expired|tooMany|rateLimit|refreshFailed|loading|required)/i`: AR value non-empty, ≠ EN, no `[٠-٩]`, and — after stripping `{placeholders}` and the allowlist `PDF|GPS|JPEG|PNG|Face ID|Google|Apple|OTP|SMS|E\.164|Wi-Fi` — no `[A-Za-z]{2,}`. (Reconciled C3: `Wi-Fi` is in the allowlist because P13's `errorUnreachableBody` AR value legitimately carries it.) Expected after F1/F2: 0 violations; ship as a hard `expect(violations, isEmpty)` (it is not a ratchet — the floor is already 0).

### P07-F7 — AR catalog capture switch (optional, S)
`test/tools/catalog_capture_test.dart`: add `const String _kCaptureLocale = String.fromEnvironment('CATALOG_LOCALE', defaultValue: 'en');`, pass `locale: Locale(_kCaptureLocale)` to `MaterialApp.router`, and write goldens to `'../../docs/redesign-2026-08/actual${_kCaptureLocale == 'en' ? '' : '-$_kCaptureLocale'}/$name.png'`. Run once for a pre-device visual sweep of all 322 catalog states in AR: `flutter test test/tools/catalog_capture_test.dart --update-goldens --tags capture --dart-define=CATALOG_LOCALE=ar` (the sanctioned screenshot recipe; the `actual*` output is not tracked — do not `git add` the PNGs). Eyeball every `*_error*`, `*_refresh_failed*`, `*offline*`, `*_loading*` PNG for clipped CTAs, Latin residue, wrong-side icons before touching the phone.

### P07-F8 — DROPPED (Reconciled C2)
The repo ships ONE fault tool: P08's `tool/fault_proxy/fault_proxy.py` (rules JSON, pass-through, hot reload,
stdlib, unit-tested). A P07 "mode" is a rule: `{"match":{"path":"^/gateway/(v1/)?deliveries"},"times":0,"respond":{"status":503,"headers":{"Content-Type":"application/problem+json","Retry-After":"30"},"body":"…problem+json…"}}`;
change status/Retry-After by `PUT /__fault/rules`. Scope rules to the screen under test (`deliveries`, `requests`) so
`/v1/users/me` and tiers stay live — this removes the §6 risk of an earlier identity failure masking the target one.
Never add a 401/403 rule in this plan (PR #330 lane).

---

## 3. Device run protocol (`$SCRATCH/device-evidence-4/p07-ar/`)

`$SCRATCH` = a local session scratch directory outside the repository. Reuse `dump.sh` (ui.xml + parsed ids) and `shot.sh` (png) with the evidence dir changed. Name files `NN-<scenario>-<step>.{xml,png}`.

### 3.1 Build + install (after §2 is committed)
```
cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors
cp ../../jeeb-mobile/android/app/google-services.json android/app/google-services.json
cp ../../jeeb-mobile/android/app/src/dev/google-services.json android/app/src/dev/google-services.json
grep -q '"project_id": "jeeb-5a293"' android/app/src/dev/google-services.json || exit 1
KEY=$(grep '^MAPS_API_KEY=' ../../jeeb-mobile/android/local.properties | cut -d= -f2)
flutter build apk --debug --flavor dev -t lib/main.dart -Pjeeb.devtool=true -PMAPS_API_KEY=$KEY --dart-define=JEEB_DEVTOOL_ENABLED=true
adb -s RZCT505K7WF install -r build/app/outputs/flutter-apk/app-dev-debug.apk
```
Record the commit SHA under test in `REPORT.md` line 1.

### 3.2 Preflight
- `curl -s -o /dev/null -w '%{http_code}' https://msi.olivium.space/gateway/health/ready` → 200.
- Dev Tool (`am start -n app.jeeb.mobile.dev/com.olivium.jeeb.LegacyDevToolLauncher`) → Server URL shows `https://msi.olivium.space/gateway`. If the seam file `/data/local/tmp/jeeb-dev-seam.json` exists, note it (stale-token trap) but do not delete unless auth is broken.
- Account: **Karim TestJeeber** via Dev Tool → Super Login → Super Login Plus → search "Karim" (dual role, 5 active deliveries). Client scenarios use `devtool_client_1788592148874` the same way.
- Radios: record `wifi_on`/`mobile_data` before; restore identically after.
- Start the shared fault proxy on the Mac (Reconciled C2): `python3 tool/fault_proxy/fault_proxy.py --listen 127.0.0.1:8089 --upstream https://msi.olivium.space --rules $EV/rules.json --log $EV/proxy.log` with an empty rules file, and `adb -s RZCT505K7WF reverse tcp:8089 tcp:8089` (re-run after any USB reconnect). Device override for the C rows = `http://127.0.0.1:8089/gateway`.

### 3.3 Switch to Arabic — ORDER MATTERS (0.4)
With the real gateway active: Profile tab → Settings → tap `settings_language_ar_option`. Dump `10-settings-ar.xml`: `settings_back` bounds x1 ≥ 850 (mirrored app bar, run-1 reference `[889,108][1024,243]`), `settings_language_ar_option` left of `settings_language_en_option`. Check logcat for `language_push_failed` (must be absent). Only now inject faults.

### 3.4 Scenario list by screen (AR active for all rows)

Assertion shorthand — for every failure node: **C** = content-desc byte-equals the ARB AR value named; **L** = no `[A-Za-z]{3,}` and no `[٠-٩]` in that node; **G** = the geometry rule stated; **S** = screenshot read visually for clipped/ellipsised CTA label, wrong-side icon, trailing period on the left end of the line.

| # | Screen / entry | Fault | Nodes and expected AR copy | RTL geometry (G) |
|---|---|---|---|---|
| A1 | Deliveries tab (`order_history_root`), list warm | Radios OFF (`svc wifi disable; svc data disable`) | `offline_banner` C=`offlineBannerMessage` "أنت غير متصل. لن يتم تحميل بعض الأشياء حتى تعود للاتصال."; `offline_banner_dismiss_cta` C=`commonDismiss` "إغلاق" | dismiss button x2 < 400 (EN reference `[799..1058]`); `cloud_off` glyph on the right edge (S) |
| A2 | same, pull-to-refresh offline | radios OFF | `order_history_refresh_failed_snack` C=`errorNetworkBody` "تحقّق من اتصالك وحاول مجددًا."; sibling Button C=`actionRetry` "إعادة المحاولة" | Button x2 < snack-text x1 (EN reference text `[87..790]`, button `[813..1015]`); label not ellipsised (S) |
| A3 | same, radios ON, no tap | — | banner and snack gone ≤ 10 s (parity with run-2 assertions 8–9) | — |
| A4 | Dismiss while offline | radios OFF again | tap `offline_banner_dismiss_cta` → node count 0; radios ON | — |
| B1 | Requests tab (jeeber home) cold start | Server URL `http://10.255.255.1:9` (blackhole) → Apply & Restart | `jeeber_home_loading` C=`availabilityLoadingHeadline` "نتحقّق من حالة توفّرك"; then `jeeber_home_error_headline` C=`errorTimeoutTitle` "استغرق هذا وقتًا طويلًا", `jeeber_home_error_body` C=`errorTimeoutBody`, `jeeber_home_load_error_retry_cta` C="إعادة المحاولة" | retry CTA |centre.x − 540| ≤ 12; refresh glyph to the RIGHT of the label (S) |
| B2 | Deliveries | blackhole | `order_history_loading` C=`orderHistoryLoadingHeadline` (post-F4 "جارٍ تحميل طلباتك"); `order_history_error_headline` C=`orderHistoryErrorTitle` "تعذّر تحميل الطلبات"; `order_history_error_body` C=`errorTimeoutBody`; `order_history_retry_cta` | as B1; tap retry → loading again → error again |
| B3 | Earnings | blackhole | `earnings_loading` C=`earningsLoadingHeadline` "جارٍ تحميل أرباحك"; `earnings_error_headline` C=`errorTimeoutTitle`; `earnings_retry_cta` | as B1 |
| B4 | Profile | blackhole | `customer_profile_loading` C=`customerProfileLoadingHeadline` "جارٍ تحميل ملفك"; `customer_profile_load_error_headline` C=`errorTimeoutTitle`; `customer_profile_retry_cta`; NO "أضف اسمك"/placeholder nodes | as B1 |
| B5 | Settings (from Profile) | blackhole | `settings_loading`; `settings_error` + `settings_retry_cta` C="إعادة المحاولة" + `settings_exit_cta`/sign-out C=`appBarSignOut` — **do not tap the exit** | outline retry and primary exit stacked, both centred |
| B6 | Notifications (bell) | blackhole | `notifications_loading` → `notifications_error` + `notifications_retry_cta` | as B1 |
| C1 | Deliveries | fault proxy rule on `^/gateway/(v1/)?deliveries` `503 Retry-After:30` (Server URL `http://127.0.0.1:8089/gateway` → Apply & Restart) | after the RetryInterceptor's 2 attempts: `order_history_error_headline` C=`orderHistoryErrorTitle`; body C=`errorRateLimitedRetryInMany` with count 30 → "حاول مجددًا بعد 30 ثانية." (Western digits, L) | as B1 |
| C2 | Deliveries, Retry taps over time | same | each Retry shows the remaining window: expect the branch to move Many (≥11) → Few (3–10, "ثوانٍ") → Two ("ثانيتين") → One ("ثانية واحدة") → Zero ("حاول مجددًا الآن.") as `Retry-After` is re-served at 30 each time — so instead set modes explicitly: `retry=5` → Few, `retry=2` → Two, `retry=1` → One, `retry=0` → Zero, `retry=90` → fallback `errorServiceUnavailableBody` "جيب غير متاح مؤقتًا. حاول مجددًا بعد لحظات." (L: contains "جيب", not "Jeeb") | — |
| C3 | Settings, list warm (real gateway, `SettingsStatus.loaded`) | radios OFF, then pull-to-refresh (the base URL cannot change without Apply & Restart, so the warm-refresh failure is produced offline, not by the fault server) | `settings_refresh_failed_note` C=`errorNetworkBody` "تحقّق من اتصالك وحاول مجددًا."; `settings_refresh_failed_note_retry_cta` tooltip C=`actionRetry`; `settings_refresh_failed_note_dismiss_cta` C=`actionDismiss` "إغلاق"; radios ON → note self-dismisses (`dismissOnReconnect`) | dismiss x1 < retry x1 (dismiss is leftmost in RTL); note text right-aligned, `sync_problem` glyph on the right (S) |
| C4 | Deliveries | fault `429 retry=30` | `order_history_error_headline` C=`errorRateLimitedTitle` "محاولات كثيرة"; body C=`errorRateLimitedRetryInMany`(30); subsequent Retry taps within 30 s are suppressed client-side (`RateLimitSuppression`) and show the decreasing remaining seconds → capture at least one Few frame | as B1 |
| C5 | Deliveries | fault `404` | `order_history_error_headline` C=`errorNotFoundTitle` "غير موجود"; body C=`errorNotFoundBody` "لم يعد هذا متاحًا."; **no** `order_history_retry_cta` (not retryable); `order_history_exit_cta` only if the screen wires `onExit` (record which) | exit CTA centred; label "رجوع" not ellipsised |
| C6 | Deliveries | fault `409` | headline C=`errorGenericTitle` "حدث خطأ ما"; body C=`errorConflictBody` "تغيّر شيء أثناء عملك. حدّث وحاول مجددًا."; retry present | as B1 |
| C7 | Deliveries | fault `422` | headline C=`errorGenericTitle`; body C=`errorValidationBody` "راجع التفاصيل وحاول مجددًا."; retry present | as B1 |
| C8 | Client home (`devtool_client_…`) | fault `503 retry=30` | `client_home_loading` → `client_home_error` + retry; body as C1 | as B1 |
| D1 | Create request → recipient phone (client, real gateway) | type `123` in `recipient_phone_input`, blur | errorText C=`recipientPhoneInvalid` "أدخل رقم هاتف لبناني صالح." | digits stay LTR inside the field; the error line is right-aligned below it (S) — this is the one place an LTR-pinned field meets RTL copy |
| D2 | Notifications list (Karim, real gateway) | tap any row | `notifications_cannot_open` C=`notificationsCannotOpen` "لا يمكن فتح هذا الإشعار."; `notifications_root` still present | snack text right-aligned (S) |
| D3 | Notifications (client, real gateway) | — | `notifications_empty` C=`notificationsEmptyTitle` "لقد اطّلعت على كل شيء" | centred |
| E1 | Cold start in AR under blackhole (already B1) | — | proves the AR pref survives Apply & Restart | — |

Optional (only if time allows, real-flow heavy): registration 429 after F3 with test phone `+9613000077` (needs sign-out → re-login via Super Login Plus afterwards) → `phone_otp_*` error C=`errorRateLimitedBody` "انتظر لحظة قبل المحاولة مجددًا." (not the Zero branch); door-OTP wrong code → `otpHandoverAttemptsRemainingTwo` "تبقّت محاولتان." (needs a live delivery).

### 3.5 Machine checks (write `$SCRATCH/device-evidence-4/p07-ar/ar_assert.py`)
Input: ui.xml, list of `(identifier, arbKey)` pairs, geometry rules. For each pair: find the node by `resource-id`, compare `content-desc` (fallback `text`) to `app_ar.arb[arbKey]` after NFC normalisation; flag Latin `[A-Za-z]{3,}` and `[٠-٩]`; evaluate bounds rules (`x1<`, `|cx-540|<=12`). Print a PASS/FAIL table; paste it into `REPORT.md`. Snack Retry: locate the `android.widget.Button` whose content-desc equals `app_ar.arb['actionRetry']`.

### 3.6 Restore (mandatory, in this order)
1. Dev Tool → Server URL → `https://msi.olivium.space/gateway` → Save → Apply & Restart; `adb reverse --remove tcp:8089`; stop the fault server.
2. Radios ON; ping 8.8.8.8 UP.
3. Settings (loaded) → `settings_language_en_option`; dump `99-settings-en.xml` (`settings_back` x1 ≤ 150).
4. Leave the Karim session; no uninstall, no Clear Local Data.
5. `REPORT.md`: SHA, per-assertion table (C/L/G/S columns), evidence file list, residual state.

---

## 4. RTL-specific risk register (what the run is looking for)

| Risk | Where it would show | Status today | Check |
|---|---|---|---|
| Retry/Dismiss on the wrong side | `JeebRefreshFailedNote` trailing `Row`, snack `SnackBarAction`, banner `actions` | `Row`-based → Flutter mirrors; no test proves it | F5 + A2/C3 geometry |
| Leading `Icons.refresh` glyph position | `JeebCtaButton.outline(leadingIcon)` | row mirrors, glyph not flipped (by design) | B1 S |
| Directional glyph not mirrored | `arrow_back` (auto-mirrors), `cloud_off`/`sync_problem`/`close` (symmetric) | fine | A1 S |
| Mixed-direction runs in failure copy | AR string containing a Latin token: `registrationSocialErrorNetwork` ("Jeeb"), countdown digits, identifiers (`ORD-…`, `+961…`) | brand token fixed by F1; digits are Western by design; **no failure copy interpolates an identifier** (`bodyOverride` grep = 0 in features) | F6 guard; C1 L |
| `MixedDirectionText.detectDirection` first-char heuristic | not used on any failure surface (rating/delivery cards only) | n/a | — |
| Arabic-Indic vs Western digits | plural sets substitute Western; 18 literal keys use Arabic-Indic (1 validation key) | F2 fixes the validation key; rest WP-9 | F6 guard |
| AR plural forms | `_cldrPlural` Few/Many boundaries; Zero on null | correct; F3 fixes the null→Zero misuse | C2/C4 branches |
| CTA label expansion ("Retry" 5 → "إعادة المحاولة" 15 chars) | `JeebCtaButton` `maxLines: 1, ellipsis`; snack action width | `expand: false` pills size to content; snack may wrap to two rows (allowed) | S on every CTA |
| Register drift (dialect vs MSA) | loading headlines | F4 (owner) | B2 C |
| Locale switch unreachable under outage | Settings/Profile error states hide the pill | inherent — protocol §3.3 | — |
| Trailing punctuation placement | AR sentences ending "." | correct with paragraph direction RTL | S |
| Semantics label = AR text | banner/note/snack carry `label:` + `liveRegion` | content-desc will be AR | C on every node |

---

## 5. Gates and PR steps

1. Implement F1–F3, F5, F6, F8 (+F4 if confirmed, +F7 optional). `git add -A` before testing.
2. `dart analyze --fatal-infos .` clean.
3. `flutter test --exclude-tags capture` — expect ≥ 10539 pass / 0 fail; coverage ≥ 79 % (was 84.65 %).
4. `bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze` (strict counters 0) and `bash qa/t-mob-fix-002/ar_plurals_check.sh` (21 sets, 0 missing) and `bash tool/check_design_tokens.sh`.
5. `flutter test test/l10n/plural_forms_test.dart test/core/widgets/jeeb/ test/offline_banner_test.dart test/otp_verification_screen_test.dart` green.
6. Reconciled (C1): commit `fix(l10n): AR failure copy — brand token, Western digits, 429-without-Retry-After; RTL geometry tests` on follow-up branch `fix/ar-failure-copy` (stacked now, `git rebase --onto origin/main …` after the #335 squash; lands after P13/P05/P06 in the l10n order C10); push; update PR #335 body with the §3 REPORT link and the WP-9 follow-up list (17 Arabic-Indic hero keys, `settingsUnregisterJeeberTitle`).
7. Device run per §3 against the pushed SHA; attach `device-evidence-4/p07-ar/REPORT.md`.

---

## 6. Risks
- Fault-server modes switch the whole gateway at once; `/v1/users/me` and the tiers call fail too — screens that gate on identity may show a different (earlier) failure than the one targeted; record what actually rendered.
- `RateLimitInterceptor` suppression persists per scope until `Retry-After` elapses — wait it out (or restart the app) between C4 modes.
- A 5xx on `/v1/auth/refresh` is never triggered because the fault server emits no 401 — keep it that way (PR #330 lane).
- AR pref is pushed to the gateway (`_pushRemote`); Karim's server-side language becomes `ar` until §3.6 step 3 restores `en`.
- Register decision (F4) is brand voice — do not ship a partial mix.

## 7. Owner decision
Confirm system/loading copy register = MSA ("جارٍ …") so F4 converts the two Levantine headlines; otherwise say "Levantine" and F4 becomes a WP-9 ticket to convert the MSA siblings instead.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C17): P07 is the on-device **Arabic authority**. P08 S17 (AR repeats) is folded in here and removed
  from P08; P09 keeps only its two AR spot checks (S2.7, S6.5). The EN kind matrix (500/503/429/404/409/422 on
  Profile/Deliveries) is P08's — do not duplicate it in EN here; rows C1–C8 run in AR only.
- Reconciled (C2): F8 dropped; all C rows use the shared P08 proxy with path-scoped rules (deliveries / requests),
  port 8089, override `http://127.0.0.1:8089/gateway`. C3 (warm refresh note) stays radios-OFF as written.
- Reconciled (C3): with P13 landed, a `drop`/refused rule while the device is online renders
  `errorUnreachableTitle/Body` ("تعذّر الوصول إلى جيب…"), NOT `errorNetworkBody`; only radios-OFF rows (A1–A4, C3) and
  the blackhole rows (B*) keep the connectivity/timeout copy. F6's allowlist carries `Wi-Fi` for that key.
- Reconciled (C10): F1/F2/(F4) ARB edits serialize after P13/P05/P06 and before P02/P03/P12-B.
- Reconciled (C12/C18): evidence dir `scratchpad/device-evidence-4/p07-ar/`; record the actual Android version
  (P08 measured 16 / SDK 36, not 14) on REPORT.md line 1.
- Owner decision renumbered: OD-7 (MSA vs Levantine for the two loading headlines).
