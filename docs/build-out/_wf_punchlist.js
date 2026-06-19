export const meta = {
  name: 'jeeb-punchlist',
  description: 'Final punch-list: wire the 4 cross-wave nav legs (R-1..R-4) + jm-063 + W0 P3 auth edges (RC-9/RC-10/RC-7), fix jm-036 flow assertion, static-green, verify affected flows, update final report',
  phases: [
    { title: 'Fix', detail: 'app nav wires + W0 auth edges (Opus); flow fixes (Sonnet)' },
    { title: 'StaticGreen', detail: 'analyze + full unit test green' },
    { title: 'Verify', detail: 'Sonnet: rebuild + run the ~11 affected flows' },
    { title: 'Report', detail: 'Opus PO: update 70_FINAL_REPORT.md' },
  ],
}

const APP = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const OUT = APP + '/docs/build-out'
const COMMON = 'Jeeb mobile build-out, FINAL PUNCH-LIST. Context: ' + OUT + '/70_FINAL_REPORT.md + ' + OUT + '/69_REGRESSION.md (the residual list R-1..R-4 + jm-063 + jm-036 + W0 P3), ' + OUT + '/30_BACKLOG.md, ' + OUT + '/41_GUARDRAILS_TESTING.md. App at ' + APP + '. All 62 screens built, analyze-clean, 1488 unit tests green, both demo paths green. These are the LAST small nav-wiring/flow items.'

phase('Fix')
const [app, qa] = await parallel([
  () => agent(COMMON + '\n\nROLE: Senior Principal Flutter Engineer (Opus) - NAV WIRES + W0 AUTH EDGES. Make these precise fixes (each: edit, keep analyze clean):\n- R-1 jm-032: in the order-tracking screen (live_tracking), wire tracking_dispute_cta to navigate to the dispute-open-evidence route (/orders/:id/escalate -> dispute_root).\n- R-2 jm-034: rating_submit_cta must navigate back to the Requests shell (so orders_home_new_order_fab is visible) after submit.\n- R-3 jm-035: customer_profile_register_delivery_row must navigate to delivery_register_prompt.\n- R-4 jm-053: in lib/features/wallet/presentation/wallet_hub_screen.dart lines ~267/280, replace _comingSoon(context) with context.goNamed(\'earnings\') for wallet_earnings_row and context.goNamed(\'wallet-activity\') for wallet_see_all_activity (the file TODO). Confirm those route names match app_router.\n- jm-063 AC6: kyc_rejected_appeal_cta must navigate to the support-ticket screen (support_root).\n- W0 RC-9 (jm-007 AC6): in lib/core/router/app_router.dart, the biometric gate must NOT send a logged-out enrolled user to /lock (guard with && !session.isUnauthenticated so they land /login). [If already present, confirm.]\n- W0 RC-7 (jm-021/022): make each OmdsOtpInput cell an editable Semantics leaf so Maestro inputText reaches it (per-cell identifier <id>_<index>); locate OmdsOtpInput. [If already fixed, confirm.]\nKeep flutter analyze clean. Do NOT touch flows. Return: per-item file+change, and which were already done.', { label: 'pl:app', phase: 'Fix' }),
  () => agent(COMMON + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - FLOW FIXES. \n- jm-036 AC4: the app now navigates delivery_tab_bell -> notifications_root (real, un-AP-9d); update the flow assertion from the retired AP-9 placeholder (jeeber_feed_root) to assert notifications_root.\n- jm-008/jm-009 (RC-10): ensure the signup/otp flows drive the _register_hero phone-entry step (assert _register_hero, enter phone 0501234567, send code) before asserting phone_otp_input (mirror jm-018 AC1).\n- jm-021/jm-022: once the app per-cell OTP fix lands (see app agent), enter the recovery code by tapping each cell verify_code_input_0..5 with one digit each.\nKeep id-only assertions; validate YAML. Return: per-flow edits.', { label: 'pl:qa', phase: 'Fix', model: 'sonnet' })
])

phase('StaticGreen')
const sg = await agent(COMMON + '\n\nROLE: Build Integration Engineer (Opus). cd ' + APP + ' && /Users/oudaykhaled/flutter/bin/flutter analyze (0 errors) ; flutter test test/ (0 failures — fix alignment if the nav changes broke a widget test, do not weaken). Return: analyze + test counts.\n\n=== APP FIXES ===\n' + app, { label: 'pl:static', phase: 'StaticGreen' })

phase('Verify')
const verify = await agent(COMMON + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - VERIFY. Clean install (uninstall+rebuild+install fresh APK), boot fast (Firebase fix). export JAVA_HOME via /usr/libexec/java_home. Run EACH once (timeout 180, --device emulator-5554): jm-032-order-tracking, jm-034-rating, jm-035-customer-profile, jm-053-wallet-hub, jm-063-support-ticket, jm-036-delivery-tab-kyc-gate, jm-007-login, jm-008-signup, jm-009-phone-otp, jm-021-verify-code, jm-022-set-password. Append results to ' + OUT + '/69_REGRESSION.md (Punch-list verify section). No fixes, no re-runs. Return: per-flow PASS/FAIL + which residuals are now closed.', { label: 'pl:verify', phase: 'Verify', model: 'sonnet' })

phase('Report')
const report = await agent(COMMON + '\n\nROLE: Tech Lead/PO - UPDATE FINAL REPORT. Update ' + OUT + '/70_FINAL_REPORT.md with the punch-list verify outcome below: refresh the residual list (mark R-1..R-4/jm-063/jm-036/W0-edges CLOSED or still-open), the per-wave + overall flow pass counts, and the final blueprint coverage (screens SIGNED/62). Update the signoffs/JM-###.md for any now-green items. Return: the final headline — screens signed/62, overall flow pass rate, both demo-path verdicts, and the definitive remaining-residual list (should be near-zero).\n\n=== PUNCH-LIST VERIFY ===\n' + verify, { label: 'pl:report', phase: 'Report' })

return { app: !!app, qa: !!qa, static_green: sg, verify: verify, final: report }
