export const meta = {
  name: 'jeeb-final-hardening',
  description: 'Final hardening: fix the 6 failing widget tests + jm-063 AC6, un-AP-9 the W1/W2 cross-wave legs (targets now exist), restore full unit-green, representative cross-wave regression, consolidated final coverage report',
  phases: [
    { title: 'Fix', detail: 'widget tests + jm-063 AC6 (Opus); un-AP-9 cross-wave flows (Sonnet)' },
    { title: 'StaticGreen', detail: 'flutter analyze clean + full flutter test green' },
    { title: 'Regression', detail: 'Sonnet: clean rebuild + ~23 representative cross-wave flows, run-once' },
    { title: 'FinalReport', detail: 'Opus PO: consolidated 70_FINAL_REPORT.md coverage' },
  ],
}

const APP = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const OUT = APP + '/docs/build-out'
const COMMON = 'Jeeb mobile build-out, FINAL HARDENING. Context: ' + OUT + '/00_CTO_BRIEF.md, ' + OUT + '/68_W34_QA_RESULTS.md (W3/W4 19/20 green; jm-063 AC6 + 6 widget-test fails noted), ' + OUT + '/41_GUARDRAILS_TESTING.md (AP-9 pattern). App at ' + APP + '. All 62 screens are built + analyze-clean; per-wave on-device QA passed (W0/W1/W2/W3/W4). The W4/W3 cross-wave target screens (dispute, reviews, support, notifications, earnings, jeeber-onboarding) now EXIST and are green, so the W1/W2 flows that previously AP-9-deferred those legs can now assert the real targets.'

// ---------- Phase 1: Fix (parallel) ----------
phase('Fix')
const [tests, unap9] = await parallel([
  () => agent(COMMON + '\n\nROLE: Senior Principal Flutter Engineer (Opus) - RESTORE UNIT GREEN + jm-063 AC6. (1) Run `cd ' + APP + ' && /Users/oudaykhaled/flutter/bin/flutter test test/` and identify EVERY failing test (~6: customer_profile_screen_test, account_status_screen_test, dispute_status_screen_test, possibly otp_verification_screen_test). These fail because the screens were restructured (semantics-finder/widget-tree mismatches) — the on-device behavior is correct (Maestro passes). UPDATE the tests to match the current screen structure WITHOUT weakening their intent (assert the same behaviors via the current widget tree / Semantics identifiers). Do NOT gut tests to make them pass; align them. (2) Fix jm-063 AC6: the kyc-rejected screen `kyc_rejected_appeal_cta` must navigate to the support-ticket screen (`support_root`). Wire it in the kyc-rejected feature. Keep flutter analyze clean. GOAL: `flutter test test/` fully GREEN (0 failures). Return: the tests fixed + how, jm-063 AC6 fix, and the final flutter test pass/fail count.', { label: 'final:tests+jm063', phase: 'Fix' }),
  () => agent(COMMON + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - UN-AP-9 CROSS-WAVE LEGS. The cross-wave target screens now exist + are green, so update these flows to assert the REAL target instead of the AP-9 "tap-accepted + root-survives" placeholder:\n- jm-025-order-chat: order_chat_open_dispute now reaches dispute-open-evidence (assert dispute_root).\n- jm-028-offer-review: offer_card name tap reaches jeeber-profile-reviews (assert delivery_man_profile_screen_root / profile_view_all_reviews).\n- jm-032-order-tracking + jm-033-confirm-receipt: the dispute leg reaches dispute-open-evidence (assert dispute_root).\n- jm-035-customer-profile: the rows now reach real targets — register-delivery -> delivery_register_prompt/onboarding; password -> password_security_root; notifications -> notif_prefs_root; language -> language_settings_root; support/contact -> support_root; logout -> logout_delete_sheet. Assert the real destinations.\n- jm-053-wallet-hub: earnings row -> earnings_total_cash; see-all-activity -> wallet_activity_root.\nKeep id-only assertions; validate YAML parses. Only change the previously-AP-9-deferred steps; keep the rest. Return: per-flow edits.', { label: 'final:un-ap9', phase: 'Fix', model: 'sonnet' })
])

// ---------- Phase 2: Static green ----------
phase('StaticGreen')
const staticGreen = await agent(COMMON + '\n\nROLE: Build Integration Engineer (Opus). Confirm fully green after the test fixes: cd ' + APP + ' && /Users/oudaykhaled/flutter/bin/flutter analyze (must be 0 errors) ; /Users/oudaykhaled/flutter/bin/flutter test test/ (must be 0 failures — if any remain, fix the test alignment, do not weaken). Return: final analyze result + flutter test pass/fail count (target: all green).\n\n=== TEST-FIX OUTPUT ===\n' + tests, { label: 'final:static-green', phase: 'StaticGreen' })

// ---------- Phase 3: Regression (representative cross-wave) ----------
phase('Regression')
const regression = await agent(COMMON + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - CROSS-WAVE REGRESSION. Clean rebuild + install (uninstall+install fresh APK — no stale APK), then run a representative cross-wave set ONCE each (timeout 180, --device emulator-5554, JAVA_HOME via /usr/libexec/java_home), confirming no regression and that the un-AP-9d cross-wave legs work. Append results to ' + OUT + '/69_REGRESSION.md (create it; per-flow row immediately). Flows (~23): jm-006-splash-routing, jm-007-login, jm-024-create-flow, jm-025-order-chat, jm-028-offer-review, jm-029-accept-offer-confirm, jm-032-order-tracking, jm-033-confirm-receipt, jm-034-rating, jm-035-customer-profile, jm-036-delivery-tab-kyc-gate, jm-044-offer-kyc-gate, jm-045-offer-composer, jm-048-delivery-feed, jm-051-mark-delivered, jm-053-wallet-hub, jm-052-earnings-dashboard, jm-055-wallet-activity, jm-056-transaction-detail, jm-057-notifications-list, jm-060-dispute-open-evidence, jm-067-jeeber-profile-reviews, jm-068-reviews-list. Run-once, no fix, no re-run. Return: per-flow PASS/FAIL + overall count + any regression (a flow that was green before now red) flagged prominently.', { label: 'final:regression', phase: 'Regression', model: 'sonnet' })

// ---------- Phase 4: Final report ----------
phase('FinalReport')
const report = await agent(COMMON + '\n\nROLE: Tech Lead + PO - FINAL COVERAGE REPORT. Read all signoffs (' + OUT + '/signoffs/), the QA result docs (61/64/66/68 + 69_REGRESSION.md just written), and the regression output below. Write ' + OUT + '/70_FINAL_REPORT.md: the consolidated delivery state — (1) blueprint coverage: of 62 screens, how many SIGNED / partial / open; (2) per-wave flow pass summary (W0/W1/W2/W3/W4); (3) the end-to-end demo paths (customer: request->offer->accept->track->receipt->rate; jeeber: gate->onboarding->kyc->funding->feed->offer->reserve->mark-delivered->rate) — green or not; (4) known residuals + owners (e.g. W0 jm-008/009/021/022 P3 auth-edge; any regression-flagged); (5) the env/QA recipe + the hardening lessons (Firebase boot fix, seam-landing test, clean-rebuild discipline). Be honest and precise. Return: the headline coverage numbers + the demo-path verdict + the residual list.\n\n=== REGRESSION RESULTS ===\n' + regression, { label: 'final:report', phase: 'FinalReport' })

return { tests_fixed: !!tests, un_ap9: !!unap9, static_green: staticGreen, regression: regression, final_report: report }
