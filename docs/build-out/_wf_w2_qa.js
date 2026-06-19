export const meta = {
  name: 'jeeb-w2-qa',
  description: 'W2 on-device QA, hardened: cold-boot + uninstall/rebuild/install (no stale APK), run-once+incremental, 16 W2 flows + W1 offer-accept regression, 2 batches, PO sign-off',
  phases: [
    { title: 'QA-A', detail: 'Sonnet: cold-boot+clean-install, run W2 onboarding/kyc batch' },
    { title: 'QA-B', detail: 'Sonnet: run W2 offering/wallet/fulfil + W1 offer-accept regression' },
    { title: 'Signoff', detail: 'Opus PO: sign off greens, categorize reds + W1-regression check' },
  ],
}

const APP = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const MOCK = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mock-backend'
const OUT = APP + '/docs/build-out'
const RESULTS = OUT + '/66_W2_QA_RESULTS.md'
const BASE = 'Jeeb mobile build-out, W2 on-device QA (hardened). Context: ' + OUT + '/00_CTO_BRIEF.md, ' + OUT + '/41_GUARDRAILS_TESTING.md, ' + OUT + '/65_W2_TEST_PLAN.md (W2 ids + seeds), ' + OUT + '/62_SEAM_HARNESS.md (session/journey/kyc_status/wallet_state seam). App at ' + APP + ', mock at ' + MOCK + ' (:4010). Emulator AVD jeeb_test, host 10.0.2.2:4010, --device emulator-5554, JAVA_HOME via /usr/libexec/java_home. CRITICAL DISCIPLINE (W1 lessons): (a) AVOID STALE APK - uninstall then install a freshly-built APK; (b) run each flow EXACTLY ONCE, no inline fix, no re-run; (c) append each result row to ' + RESULTS + ' IMMEDIATELY (stall-safe); (d) per flow capture PASS/FAIL + failing step + category (APP_DEFECT/PRECONDITION/MOCK_GAP/FLOW_BUG).'

// ---------- Phase 1: QA-A (cold-boot + clean install + W2 onboarding/kyc) ----------
phase('QA-A')
const qaA = await agent(BASE + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - W2 RUN-ONCE BATCH A (setup + 9 flows).\n1. Mock up on :4010 (curl; restart from ' + MOCK + ' npm run dev if down).\n2. COLD-BOOT the emulator to clear memory pressure: kill any running emulator (adb -s emulator-5554 emu kill 2>/dev/null; pkill -f qemu-system 2>/dev/null), wait 5s, then start fresh: ~/Library/Android/sdk/emulator/emulator -avd jeeb_test -no-snapshot-save -no-audio -no-boot-anim in background; adb wait-for-device; poll sys.boot_completed=1.\n3. CLEAN INSTALL (no stale APK): cd ' + APP + ' ; /Users/oudaykhaled/flutter/bin/flutter build apk --debug --flavor dev --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010 ; ~/Library/Android/sdk/platform-tools/adb uninstall app.jeeb.mobile.dev 2>/dev/null ; ~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-dev-debug.apk\n4. Create ' + RESULTS + ' with header (date, "W2 Run 1", device/apk/mock lines) + a results table header.\n5. export JAVA_HOME via /usr/libexec/java_home. Run EACH flow once with: timeout 180 ~/.maestro/bin/maestro --device emulator-5554 test -e APP_ID=app.jeeb.mobile.dev --format JUNIT <flow> ; append a row to ' + RESULTS + ' immediately. Flows (9): jm-036-delivery-tab-kyc-gate, jm-037-remove-vehicle-field, jm-038-service-area-homebase-pin, jm-039-onboarding-photo-step-nav, jm-040-kyc-identity, jm-041-onboarding-funding, jm-042-kyc-pending-status, jm-043-kyc-rejected, jm-044-offer-kyc-gate.\nNo fixes, no re-runs. Return: the 9 results + confirm app installed + emulator up for batch B.', { label: 'w2qa:batch-a', phase: 'QA-A', model: 'sonnet' })

// ---------- Phase 2: QA-B (offering/wallet/fulfil + W1 regression) ----------
phase('QA-B')
const qaB = await agent(BASE + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - W2 RUN-ONCE BATCH B (9 flows). App installed + emulator up from batch A (re-boot/re-install once if the emulator died or apk missing). export JAVA_HOME via /usr/libexec/java_home. Run EACH once with timeout 180 ~/.maestro/bin/maestro --device emulator-5554 test -e APP_ID=app.jeeb.mobile.dev --format JUNIT <flow>, appending a row to ' + RESULTS + ' immediately. Flows (9): jm-045-offer-composer, jm-046-insufficient-balance-sheet, jm-047-jeeber-pending-offers, jm-048-delivery-feed, jm-051-mark-delivered, jm-053-wallet-hub, jm-054-wallet-charge-info, jm-028-offer-review, jm-029-accept-offer-confirm.\nNOTE: jm-028/jm-029 are W1 OFFER-ACCEPT REGRESSION checks - the offers-deadline derivation was re-touched in W2; if they FAIL on an expired/disabled Accept window, categorize MOCK_GAP (mock offers need fresh submittedAt/windowExpiresAt) and flag it prominently.\nNo fixes, no re-runs. After the last flow append a Summary section (total PASS/FAIL across all 18, counts by category, + an explicit W1-regression line for jm-028/029). Return: the 9 results + overall counts + reds with category + the W1-regression verdict.\n\n=== BATCH A ===\n' + qaA, { label: 'w2qa:batch-b', phase: 'QA-B', model: 'sonnet' })

// ---------- Phase 3: Sign-off ----------
phase('Signoff')
const signoff = await agent(BASE + '\n\nROLE: Product Owner (Opus) - W2 SIGN-OFF from the complete artifact ' + RESULTS + ' (read it). Using the ACs in 30_BACKLOG.md, write/update sign-offs at ' + OUT + '/signoffs/JM-###.md for every W2 item (036-048, 051, 053, 054): SIGNED for green flows (AC-to-evidence + DoD), PARTIAL/BLOCKED otherwise with exact category + precise owner action (engineer/backender/QA + file + fix). Return: W2 SIGNED count, the red list grouped by owner with file+fix, the W1 offer-accept regression verdict (jm-028/029 - did W2 break it?), and whether the jeeber spine (delivery-tab gate -> feed -> offer-gate -> composer -> reserve) is green end-to-end. If jm-028/029 regressed, make the mock fresh-timestamp fix the top P0.\n\n=== BATCH B / OVERALL ===\n' + qaB, { label: 'w2:signoff', phase: 'Signoff' })

return { qa_a: qaA, qa_b: qaB, signoff_summary: signoff }
