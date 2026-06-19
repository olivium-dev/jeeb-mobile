export const meta = {
  name: 'jeeb-w34-qa',
  description: 'W3+W4 on-device QA + W2 residual verify: clean reinstall, run-once+incremental, 15 W3/W4 flows + 5 W2-residual flows, 2 batches, PO sign-off',
  phases: [
    { title: 'QA-A', detail: 'Sonnet: clean install, run W3 + W4 batch 1 (10 flows)' },
    { title: 'QA-B', detail: 'Sonnet: W4 batch 2 + W2 residual/verify (10 flows)' },
    { title: 'Signoff', detail: 'Opus PO: sign off W3/W4 + close W2 residuals' },
  ],
}

const APP = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const MOCK = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mock-backend'
const OUT = APP + '/docs/build-out'
const RESULTS = OUT + '/68_W34_QA_RESULTS.md'
const BASE = 'Jeeb mobile build-out, W3+W4 on-device QA + W2 residual verify. Context: ' + OUT + '/00_CTO_BRIEF.md, ' + OUT + '/41_GUARDRAILS_TESTING.md, ' + OUT + '/67_W34_TEST_PLAN.md (W3/W4 ids + the seam/mock seeds these flows need), ' + OUT + '/66_W2_QA_RESULTS.md (W2 residuals jm-044/047/028/045/046), ' + OUT + '/62_SEAM_HARNESS.md. App at ' + APP + ', mock at ' + MOCK + ' (:4010). Emulator jeeb_test, host 10.0.2.2:4010, --device emulator-5554, JAVA_HOME via /usr/libexec/java_home. Boot is fast now (Firebase timeout fix). DISCIPLINE: clean reinstall (uninstall then install fresh APK — no stale APK); run each flow EXACTLY ONCE, no inline fix, no re-run; append each row to ' + RESULTS + ' IMMEDIATELY; categorize fails APP_DEFECT/PRECONDITION(missing seam/mock seed)/MOCK_GAP/FLOW_BUG. If a flow fails because its journey/seam seed (e.g. jeeber_wallet_ledger, has_notifications, has_open_dispute, jeeber_has_reviews, account suspended, account_type=social_only) is not implemented, mark PRECONDITION and name the exact missing seed (do NOT fix).'

phase('QA-A')
const qaA = await agent(BASE + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - W3/W4 RUN-ONCE BATCH A (setup + 10 flows).\n1. Mock up on :4010 (curl; restart from ' + MOCK + ' npm run dev if down).\n2. Ensure emulator jeeb_test up (boot if needed: ~/Library/Android/sdk/emulator/emulator -avd jeeb_test -no-snapshot-save -no-audio -no-boot-anim & ; adb wait-for-device; poll sys.boot_completed=1).\n3. CLEAN INSTALL: cd ' + APP + ' ; /Users/oudaykhaled/flutter/bin/flutter build apk --debug --flavor dev --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010 ; adb uninstall app.jeeb.mobile.dev 2>/dev/null ; adb install -r build/app/outputs/flutter-apk/app-dev-debug.apk\n4. Create ' + RESULTS + ' with header (date "W3+W4 Run 1", device/apk/mock) + results table header.\n5. export JAVA_HOME via /usr/libexec/java_home. Run EACH once: timeout 180 ~/.maestro/bin/maestro --device emulator-5554 test -e APP_ID=app.jeeb.mobile.dev --format JUNIT <flow> ; append a row immediately. Flows (10): jm-052-earnings-dashboard, jm-055-wallet-activity, jm-056-transaction-detail, jm-057-notifications-list, jm-058-notification-prefs, jm-059-language-settings, jm-060-dispute-open-evidence, jm-061-password-security, jm-062-logout-delete, jm-063-support-ticket.\nNo fixes/re-runs. Return: 10 results + confirm app installed + emulator up for batch B.', { label: 'w34qa:a', phase: 'QA-A', model: 'sonnet' })

phase('QA-B')
const qaB = await agent(BASE + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - BATCH B (10 flows). App installed + emulator up from A (re-boot/re-install once if needed). export JAVA_HOME via /usr/libexec/java_home. Run EACH once (timeout 180), append immediately. Flows (10): jm-064-rate-the-app, jm-065-dispute-status, jm-066-account-status, jm-067-jeeber-profile-reviews, jm-068-reviews-list, jm-044-offer-kyc-gate, jm-047-jeeber-pending-offers, jm-028-offer-review, jm-045-offer-composer, jm-046-insufficient-balance-sheet.\nNOTE: jm-044/047/028 verify the W2 one-liner residual fixes; jm-045/046 verify the W2 backend wallet-seed/402 fix. After the last flow append a Summary (total PASS/FAIL across all 20, counts by category, + explicit lines: W3/W4 pass count, W2-residual pass count). Return: 10 results + overall counts + reds by category (separating PRECONDITION/missing-seed from real APP_DEFECT).\n\n=== BATCH A ===\n' + qaA, { label: 'w34qa:b', phase: 'QA-B', model: 'sonnet' })

phase('Signoff')
const signoff = await agent(BASE + '\n\nROLE: Product Owner (Opus) - W3/W4 + W2-RESIDUAL SIGN-OFF from the complete artifact ' + RESULTS + ' (read it). Using ACs in 30_BACKLOG.md, write/update ' + OUT + '/signoffs/JM-###.md for W3 (052,055,056) + W4 (057-068) + the W2 residuals (044,047,028,045,046): SIGNED for green, PARTIAL/BLOCKED otherwise with exact category + precise owner action (engineer/backender/QA + file + fix). Return: W3/W4 SIGNED count, W2 now fully closed? (044/047/028/045/046 status), the red list grouped by owner (separating missing-seam-seed PRECONDITION items — which need the backender to wire the seed — from real app defects), and a one-line overall blueprint coverage estimate (signed screens / 62).\n\n=== BATCH B / OVERALL ===\n' + qaB, { label: 'w34:signoff', phase: 'Signoff' })

return { qa_a: qaA, qa_b: qaB, signoff_summary: signoff }
