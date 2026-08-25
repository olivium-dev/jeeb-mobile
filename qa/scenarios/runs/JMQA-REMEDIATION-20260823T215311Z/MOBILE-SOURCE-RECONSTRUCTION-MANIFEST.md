# Mobile source reconstruction — sanitized path manifest

Generated: `2026-08-24T15:58:24Z`

Base revision: `a88103459cb9c74df41b82a2675bd255a0b132fb`
Reconstruction branch: `release/staging-store-reconstruct-20260824`

## Selection summary

This manifest records the exact 188-file source selection immediately before
staging: 97 tracked deltas and 91 reviewed untracked files, including this
manifest. It is derived from the clean reconstruction worktree, not from the
mixed source index.

- Included: final tracked overlay plus explicitly reviewed, source-only untracked
  files required by its tests and release contracts.
- Excluded: `.codex-proof/**` (190 raw evidence files), `.claude/**` agent-memory
  edits (2 paths), build outputs, screenshots, device logs, archives, signer
  material, real provider configuration, and credentials.
- Protected Firebase/Maps inputs remain injected at build time; the two legacy
  tracked Android Firebase client files remain deleted.
- Pre-stage safety result: zero prohibited untracked paths, zero symlinks, zero
  untracked files over 1 MiB, and valid SwiftPM lockfile JSON.

## Exact selected files

```text
??	android/app/src/dev/AndroidManifest.xml
??	android/app/src/dev/res/xml/network_security_config.xml
??	docs/observability/microsoft-clarity.md
??	ios/ExportOptions.Internal.plist
??	ios/Flutter/Profile.xcconfig
??	ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
??	ios/Runner/Runner.Release.entitlements
??	lib/core/analytics/clarity/application/clarity_controller.dart
??	lib/core/analytics/clarity/data/microsoft_clarity_adapter.dart
??	lib/core/analytics/clarity/data/shared_prefs_clarity_consent_store.dart
??	lib/core/analytics/clarity/domain/clarity_analytics_port.dart
??	lib/core/analytics/clarity/domain/clarity_consent_store.dart
??	lib/core/analytics/clarity/domain/clarity_consent.dart
??	lib/core/analytics/clarity/presentation/clarity_navigator_observer.dart
??	lib/core/session/auth_loss_signals.dart
??	lib/features/settings/presentation/widgets/settings_analytics_card.dart
??	pubspec.lock
??	qa/scenarios/_templates/SCENARIO.md
??	qa/scenarios/checklists/EVIDENCE.md
??	qa/scenarios/checklists/INDEX.md
??	qa/scenarios/checklists/PER-SCENARIO.md
??	qa/scenarios/checklists/PRE-RUN.md
??	qa/scenarios/checklists/RELEASE.md
??	qa/scenarios/cross-cutting/INDEX.md
??	qa/scenarios/cross-cutting/JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md
??	qa/scenarios/cross-cutting/LOCALE-ACCESSIBILITY-SECURITY.md
??	qa/scenarios/cross-cutting/PUSH-DEEP-LINK-LIFECYCLE.md
??	qa/scenarios/cross-cutting/RESILIENCE-CONCURRENCY.md
??	qa/scenarios/features/AUTH-SESSION.md
??	qa/scenarios/features/CLARITY-PRIVACY.md
??	qa/scenarios/features/DELIVERY-CHAT-COD.md
??	qa/scenarios/features/INDEX.md
??	qa/scenarios/features/KYC-ROLE.md
??	qa/scenarios/features/REQUEST-OFFER.md
??	qa/scenarios/features/SETTINGS-NOTIFICATIONS-SUPPORT.md
??	qa/scenarios/GATE-MATRIX.md
??	qa/scenarios/INDEX.md
??	qa/scenarios/journeys/INDEX.md
??	qa/scenarios/journeys/JMS-JHP-001-CUSTOMER-REQUEST.md
??	qa/scenarios/journeys/JMS-JHP-002-JEEBER-KYC-OFFER.md
??	qa/scenarios/journeys/JMS-JHP-003-TWO-PERSONA-COD.md
??	qa/scenarios/README.md
??	qa/scenarios/RECORD-CONTRACT.md
??	qa/scenarios/runs/INDEX.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/AUTH-PROVENANCE.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/BLOCKERS.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/DEFECTS.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/EVIDENCE-INDEX.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/LESSONS.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/LOG-SUMMARY.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/MANUAL-ACTION-LEDGER.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/README.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/REPORT.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/RESULTS.jsonl
??	qa/scenarios/runs/JMQA-20260823T183728Z/RUN-STATE.md
??	qa/scenarios/runs/JMQA-20260823T183728Z/TEST-DATA.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/AGENT-LEDGER.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/BLOCKERS.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/CHECKLIST.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/DATA.json
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/INDEX.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/MOBILE-SOURCE-RECONSTRUCTION-MANIFEST.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/MOBILE-SOURCE-RECONSTRUCTION.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/REPORT.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/STAGING-STORE-AUDIT-20260824.md
??	qa/scenarios/runs/JMQA-REMEDIATION-20260823T215311Z/TEST-LOG.md
??	qa/scenarios/TRACEABILITY.md
??	test/core/analytics/clarity_consent_store_test.dart
??	test/core/analytics/clarity_controller_test.dart
??	test/core/analytics/clarity_navigator_observer_test.dart
??	test/core/analytics/clarity_privacy_gate_test.dart
??	test/core/config/clarity_policy_test.dart
??	test/core/delivery/delivery_status_vocab_test.dart
??	test/features/chat/chat_realtime_resolver_test.dart
??	test/features/settings/settings_analytics_card_test.dart
??	test/mobile_release_contract_test.dart
??	test/release/store_entrypoint_auth_surface_test.dart
??	test/support/test_jwt.dart
??	tool/build_signed_ios_internal_candidate.sh
??	tool/build_unsigned_ios_release_contract.sh
??	tool/check_ios_dependency_ownership.sh
??	tool/inspect_signed_ios_release.sh
??	tool/inspect_unsigned_ios_release.sh
??	tool/run_with_android_firebase_config.sh
??	tool/run_with_ios_firebase_config.sh
??	tool/test_android_firebase_config.sh
??	tool/test_android_release_signing.sh
??	tool/test_ios_firebase_config.sh
??	tool/validate_android_google_services.sh
??	tool/validate_ios_google_service_info.sh
??	tool/validate_ios_maps_api_key.sh
D	android/app/google-services.json
D	android/app/src/debug/res/xml/network_security_config.xml
D	android/app/src/dev/google-services.json
D	android/app/src/main/res/xml/network_security_config.xml
D	firebase-debug.log
M	.github/workflows/ci.yml
M	.github/workflows/flutter-ci.yml
M	.github/workflows/mobile-ci.yml
M	.gitignore
M	android/app/build.gradle
M	android/app/google-services.json.template
M	android/app/src/debug/AndroidManifest.xml
M	android/app/src/main/AndroidManifest.xml
M	android/app/src/main/kotlin/app/jeeb/mobile/MainActivity.kt
M	ios/Flutter/Release.xcconfig
M	ios/Podfile
M	ios/Podfile.lock
M	ios/Runner.xcodeproj/project.pbxproj
M	ios/Runner/AppDelegate.swift
M	ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
M	ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
M	ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png
M	ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md
M	ios/Runner/Base.lproj/LaunchScreen.storyboard
M	ios/Runner/GoogleService-Info.plist.template
M	ios/Runner/Info-dev.plist
M	ios/Runner/Info.plist
M	ios/Runner/Runner.entitlements
M	lib/app/app.dart
M	lib/app/jeeb_bootstrap.dart
M	lib/core/config/app_config.dart
M	lib/core/delivery/delivery_status_vocab.dart
M	lib/core/dev_seam/dev_seam_source.dart
M	lib/core/di/injection_container.dart
M	lib/core/network/auth_interceptor.dart
M	lib/core/network/mock_gateway_client.dart
M	lib/core/power/battery_optimization.dart
M	lib/core/router/app_router.dart
M	lib/core/session/session_cubit.dart
M	lib/devtool/catalog/entries/batch_11_entries.dart
M	lib/devtool/catalog/fixtures/kyc_rejected_screen_fixtures.dart
M	lib/devtool/catalog/fixtures/transaction_detail_screen_fixtures.dart
M	lib/devtool/dev_settings_page.dart
M	lib/devtool/devtool_shell.dart
M	lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart
M	lib/features/chat/data/chat_realtime_resolver.dart
M	lib/features/chat/data/dio_chat_gateway.dart
M	lib/features/chat/presentation/chat_screen.dart
M	lib/features/chat/presentation/widgets/order_chat_pinned_summary.dart
M	lib/features/deep_link_targets/chat_detail_screen.dart
M	lib/features/deep_link_targets/delivery_detail_screen.dart
M	lib/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart
M	lib/features/kyc_rejected/application/kyc_rejected_cubit.dart
M	lib/features/kyc_rejected/application/kyc_rejected_state.dart
M	lib/features/kyc_rejected/presentation/kyc_rejected_screen.dart
M	lib/features/offers/presentation/offer_composer_l10n.dart
M	lib/features/settings/presentation/screens/settings_screen.dart
M	lib/features/wallet/data/stub_wallet_transaction_repository.dart
M	lib/features/wallet/presentation/transaction_detail_l10n.dart
M	lib/features/wallet/presentation/wallet_activity_l10n.dart
M	lib/features/wallet/presentation/wallet_hub_l10n.dart
M	lib/l10n/app_ar.arb
M	lib/l10n/app_en.arb
M	lib/l10n/app_localizations.dart
M	lib/main_devtool.dart
M	lib/main.dart
M	pubspec.yaml
M	README.md
M	test/back_arrow_dead_at_root_test.dart
M	test/core/config/base_url_convention_test.dart
M	test/core/mock_gateway_client_test.dart
M	test/core/mock_gateway_mock_mode_test.dart
M	test/core/network/auth_interceptor_test.dart
M	test/core/network/unversioned_path_fallback_interceptor_test.dart
M	test/core/router/super_login_navigation_test.dart
M	test/core/router/w2_routes_resolve_test.dart
M	test/core/session/session_cubit_test.dart
M	test/devtool/dev_server_url_presets_test.dart
M	test/features/active_delivery_jeeber/active_delivery_push_landing_test.dart
M	test/features/chat/chat_header_a11y_test.dart
M	test/features/deep_link_targets/chat_detail_screen_role_aware_test.dart
M	test/features/jeeber_home/jeeber_e3_street_variant_test.dart
M	test/features/jeeber_onboarding_funding/onboarding_funding_screen_test.dart
M	test/features/kyc_rejected/kyc_rejected_midnight_test.dart
M	test/features/live_tracking/tracking_continuous_position_test.dart
M	test/features/offers/offer_composer_price_stepper_test.dart
M	test/features/offers/offer_composer_rtl_smoke_test.dart
M	test/features/offers/offer_composer_wallet_strip_test.dart
M	test/features/wallet/transaction_detail_screen_test.dart
M	test/features/wallet/wallet_charge_info_whatsapp_test.dart
M	test/features/wallet/wallet_hub_screen_test.dart
M	test/mb1/mb1_w1_4_build_line_test.dart
M	test/notification_prefs_screen_test.dart
M	test/previews/app/branded_splash_preview_test.dart
M	test/role_sync_test.dart
M	test/session_login_reregister_wiring_test.dart
M	test/super_login_real_login_parity_test.dart
```

## Gate state at capture

- Pinned Flutter 3.44.2 dependency lock check: PASS.
- Clarity/privacy focused tests: 32 passed, 0 failed.
- First full-suite reconstruction run: 7,866 passed, 66 skipped, 2 expected
  tracking-receipt failures because selected new files were not staged yet.
- Diagnostic rerun: same two failures; application behavior suites did not fail.
- Exact 188-file selection staged with no unstaged source overlay: PASS.
- Tracking-receipt suites after staging: 23 passed, 0 failed.
- Final exact non-capture suite: 7,868 passed, 66 intentionally skipped,
  0 failed in 500.365 seconds.
- Full Flutter analysis and `dart analyze --fatal-infos .`: no issues.
- Android/iOS identity, protected Firebase/Maps injection, signing-negative,
  SwiftPM/CocoaPods ownership, no-Super-Login/Dev-Tool, transport, COD,
  forbidden-host, diff, and staged-secret gates: PASS.
- Unsigned iOS Release: compiled successfully as a 77 MiB `Runner.app`; the
  synthetic compile configuration and protected provider files were removed.
- Required next step: commit and independently review this exact selection,
  then force-clean rebuild, inspect, validate, and hash the signed AAB and IPA
  from the approved revision before any store upload.

## Post-selection lineage — append-only reconciliation

The 188-file manifest above remains the exact initial selection and is not
rewritten to impersonate later commits.

- Initial coherent reconstruction: `e208a4c8906330c8df126f2391ae149a8291e6f6`.
- Main reconciliation: `8788a24ddec1e14ca9641bc6b8e4e2854991e87f`,
  incorporating `origin/main` `0c26c159c9714b812bd2a0f6ec3cc9488c7d39c8`.
- Current source-bearing hardening: `e07d4542`; committed development passcode
  fallback removed and courier tracking made WSS-only outside dev.
- Current source diff from `origin/main`: 194 files, 12,392 insertions, 4,510
  deletions.
- CI-equivalent Flutter 3.44.2 gate: 7,882 passed, 66 intentionally skipped,
  0 failed in about 329 seconds; focused credential/transport tests 22/22 and
  focused fatal-info analysis pass.
- Remote CI, independent exact-head review, signed artifact rebuilds,
  store delivery, and physical acceptance remain open. No protected input was
  added to this lineage.
