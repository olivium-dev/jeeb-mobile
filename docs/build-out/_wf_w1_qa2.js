export const meta = {
  name: 'jeeb-w1-qa2',
  description: 'W1 on-device QA, RELIABLE: run-once-and-report only (no inline fix), incremental writes, split across 2 sequential QA agents, then PO sign-off from the complete artifact',
  phases: [
    { title: 'QA-A', detail: 'Sonnet: build+install+boot, run W0 reds + W1 first half, append results' },
    { title: 'QA-B', detail: 'Sonnet: run W1 second half (app already installed), append results' },
    { title: 'Signoff', detail: 'Opus PO: sign off greens, categorize reds with owner actions' },
  ],
}

const APP = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const MOCK = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mock-backend'
const OUT = APP + '/docs/build-out'
const RESULTS = OUT + '/64_W1_QA_RESULTS.md'
const BASE = 'Jeeb mobile build-out, W1 on-device QA (reliable re-run). Context: ' + OUT + '/00_CTO_BRIEF.md, ' + OUT + '/41_GUARDRAILS_TESTING.md, ' + OUT + '/60_W0_TEST_PLAN.md + ' + OUT + '/63_W1_TEST_PLAN.md (identifier + seed contracts), ' + OUT + '/62_SEAM_HARNESS.md (jeeb.seam.session + jeeb.seam.journey). App at ' + APP + ', mock at ' + MOCK + '. Android emulator jeeb_test, host 10.0.2.2:4010, --device emulator-5554, JAVA_HOME via /usr/libexec/java_home. CRITICAL DISCIPLINE: run each flow EXACTLY ONCE. Do NOT fix flows or app code. Do NOT re-run. Append the result row to ' + RESULTS + ' IMMEDIATELY after each flow (so a stall still leaves a complete partial artifact). Per flow capture: PASS/FAIL, the failing step text from maestro output, and a category guess (APP_DEFECT=id missing/screen wrong, PRECONDITION=seed/state not set, MOCK_GAP=endpoint/data missing, FLOW_BUG=yaml/selector/timeout).'

// ---------- Phase 1: QA-A (build + W0 reds + W1 first half) ----------
phase('QA-A')
const qaA = await agent(BASE + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - RUN-ONCE BATCH A. Setup + first 12 flows.\n1. Mock up on :4010 (curl; restart from ' + MOCK + ' npm run dev if down).\n2. Boot emulator jeeb_test (emulator -avd jeeb_test -no-snapshot-save -no-audio -no-boot-anim background; adb wait-for-device; poll sys.boot_completed=1).\n3. Build+install ONCE: cd ' + APP + ' ; /Users/oudaykhaled/flutter/bin/flutter build apk --debug --flavor dev --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010 ; adb install -r build/app/outputs/flutter-apk/app-dev-debug.apk\n4. Create ' + RESULTS + ' with a header (date "Run: reliable re-run", device/apk/mock lines) and a markdown results table header.\n5. export JAVA_HOME via /usr/libexec/java_home. Run EACH of these flows exactly once with: timeout 180 ~/.maestro/bin/maestro --device emulator-5554 test -e APP_ID=app.jeeb.mobile.dev --format JUNIT <flow> (wrap so a hung flow is killed at 180s and counts as FAIL/timeout). After EACH flow append one table row to ' + RESULTS + ' immediately. Flows (12): jm-007-login, jm-008-signup, jm-009-phone-otp, jm-021-verify-code, jm-022-set-password, jm-023-requests-home, jm-024-create-flow, jm-025-order-chat, jm-026-waiting-no-coverage, jm-027-replies-sub-tab, jm-028-offer-review, jm-029-accept-offer-confirm.\nDo NOT fix anything; do NOT re-run. Return: the 12 results (flow, PASS/FAIL, failing step, category) and confirm the app is installed + emulator up for batch B.', { label: 'qa:batch-a', phase: 'QA-A', model: 'sonnet' })

// ---------- Phase 2: QA-B (W1 second half) ----------
phase('QA-B')
const qaB = await agent(BASE + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - RUN-ONCE BATCH B. The app is already installed and emulator jeeb_test is up (batch A did setup; if the emulator died, re-boot it; if the apk is missing, rebuild+install once). export JAVA_HOME via /usr/libexec/java_home. Run EACH of these flows exactly once with timeout 180 ~/.maestro/bin/maestro --device emulator-5554 test -e APP_ID=app.jeeb.mobile.dev --format JUNIT <flow>, appending a row to ' + RESULTS + ' immediately after each. Flows (8): jm-030-cancel-request-confirm, jm-031-order-summary-pinned, jm-032-order-tracking, jm-033-confirm-receipt, jm-034-rating, jm-035-customer-profile, jm-049-saved-addresses, jm-050-address-detail-form.\nDo NOT fix anything; do NOT re-run. After the last flow, append a Summary section to ' + RESULTS + ' (total PASS/FAIL across all 20 = batch A 12 + batch B 8, counts by category). Return: the 8 results + the overall PASS/FAIL counts (W0-reds vs W1) + the list of reds with category.\n\n=== BATCH A RESULTS ===\n' + qaA, { label: 'qa:batch-b', phase: 'QA-B', model: 'sonnet' })

// ---------- Phase 3: Sign-off ----------
phase('Signoff')
const signoff = await agent(BASE + '\n\nROLE: Product Owner (Opus) - W0+W1 SIGN-OFF from the COMPLETE artifact ' + RESULTS + ' (read it). Using the ACs in 30_BACKLOG.md, write/update sign-offs at ' + OUT + '/signoffs/JM-###.md for W0 items (007,008,009,021,022) and all W1 items (023-035,049,050): SIGNED for green flows (AC-to-evidence + DoD), PARTIAL/BLOCKED otherwise with exact category + precise owner action (engineer/backender/QA + file + fix). Return: is W0 now closed? W1 SIGNED count? the full red list grouped by owner (app-eng / backender / QA) with file+fix for each, and whether the customer demo path (jm-024 create -> jm-025 chat/broadcast -> jm-028/029 offer/accept -> jm-031/032 summary/track -> jm-033 receipt -> jm-034 rate) is green end-to-end.\n\n=== BATCH B / OVERALL RESULTS ===\n' + qaB, { label: 'w1:signoff2', phase: 'Signoff' })

return { qa_a: qaA, qa_b: qaB, signoff_summary: signoff }
