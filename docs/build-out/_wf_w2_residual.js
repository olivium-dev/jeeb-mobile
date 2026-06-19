export const meta = {
  name: 'jeeb-w2-residual',
  description: 'Close W2 residuals: backend (offer-402 O1 + honor jeeber wallet seed W1m + withdraw) + gate-logic reconciliation (JM-036/044) + flow seeds, then verify the 7 residual flows, sign off W2',
  phases: [
    { title: 'Fix', detail: 'backend (O1/W1m/withdraw) + gate-logic (JM-036/044 feed-vs-register)' },
    { title: 'FlowFix', detail: 'Sonnet: align jm-044/048 + jm-028/029 flow seeds to the gate doc' },
    { title: 'StaticGreen', detail: 'flutter analyze + test green' },
    { title: 'Verify', detail: 'Sonnet: clean rebuild+install, run the 7 residual flows (fast now Firebase is fixed)' },
    { title: 'Signoff', detail: 'Opus PO: sign off W2' },
  ],
}

const APP = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const MOCK = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mock-backend'
const OUT = APP + '/docs/build-out'
const RESULTS = OUT + '/66_W2_QA_RESULTS.md'
const COMMON = 'Jeeb mobile build-out, W2 RESIDUALS (close W2). Context: ' + OUT + '/00_CTO_BRIEF.md, ' + OUT + '/66_W2_QA_RESULTS.md (W2 closer report: 11/16 green; residuals jm-044/045/046/047/048 + jm-028/029 AC3 — read the per-flow root causes), ' + OUT + '/65_W2_TEST_PLAN.md, ' + OUT + '/62_SEAM_HARNESS.md, ' + OUT + '/42_GUARDRAILS_MOCK.md, ' + OUT + '/30_BACKLOG.md (D38 KYC-gates-offering). App at ' + APP + ', mock at ' + MOCK + ' (:4010). Boot is now fast (Firebase timeout fix). Apply CTO-D + R-F for gaps.'

// ---------- Phase 1: backend + gate (parallel, disjoint repos) ----------
phase('Fix')
const [backend, gate] = await parallel([
  () => agent(COMMON + '\n\nROLE: Principal Backender (Opus). Own ' + MOCK + ' ONLY. Close the W2 money-path mock gaps so jm-045/046/047 can pass:\n1. W1m: GET /wallet (and the jeeber wallet endpoint the app reads for user-jeeber-002) must HONOR the /__mock/seed/wallet state: state=sufficient -> affordabilityState "enough" + ample balance; insufficient -> "top_up" + balance below the offer fee; empty -> zero. Currently it always returns "enough" regardless of the seed (the W2 closer flagged this) — make the seeded state actually drive the response for user-jeeber-002.\n2. O1: POST /offer-service/v1/offers returns 402 {needed, available} when the jeeber wallet is insufficient for the 10% reserve, and on success emits the reserve ledger row.\n3. jm-047 withdraw: DELETE /offer-service/v1/offers/:id (or the withdraw route the app calls) removes the offer from the jeeber pending list so the row disappears.\nKeep npm run build + npm test green. Append the final shapes to 42_GUARDRAILS_MOCK.md. Return: endpoints changed + how the wallet seed now drives affordability + the 402 contract.', { label: 'res:backend', phase: 'Fix' }),
  () => agent(COMMON + '\n\nROLE: Senior Principal Flutter Engineer (Opus) - GATE LOGIC (JM-036/044). The W2 closer found: the DELIVERY-tab gate shows delivery_register_prompt for ANY non-approved jeeber, so a registered-but-pending jeeber never reaches the feed, and the offer-KYC-gate (JM-044, which triggers when an unapproved jeeber taps make-offer ON the feed) is unreachable. Per D38 (KYC gates OFFERING, not feed-browsing) + the existence of the offer-kyc-gate screen: a jeeber who has REGISTERED (completed onboarding / kyc submitted = kyc_status pending) should BROWSE the feed; tapping feed_make_offer_cta routes to offer-kyc-gate until approved. Only a NOT-registered user (kyc_status none / never onboarded) sees delivery_register_prompt. Reconcile the DELIVERY-tab gate (lib/features/jeeber_home/...) accordingly: map kyc_status none->register-prompt, pending/submitted->feed (offering gated), approved->feed (offering allowed), rejected->kyc-rejected. Keep it backed by real kyc_status (seam-seedable). Confirm jm-036 still passes for the none + approved cases. flutter analyze clean. Touch only the jeeber_home gate feature files (not app_router/shell/DI). Return: the exact kyc_status->screen mapping (so QA seeds the right value) + files changed.', { label: 'res:gate', phase: 'Fix' }),
])

// ---------- Phase 2: flow seeds (Sonnet) ----------
phase('FlowFix')
const flowFix = await agent(COMMON + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - W2 RESIDUAL FLOW SEEDS. Align flows to the gate mapping + backend (below):\n1. jm-044-offer-kyc-gate + jm-048-delivery-feed: seed the kyc_status that makes the DELIVERY tab show the FEED (per the gate doc - likely pending/submitted) so feed_make_offer_cta is reachable; jm-044 then asserts make-offer -> offer_kyc_gate; jm-048 asserts the feed + make-offer routing.\n2. jm-045-offer-composer + jm-046-insufficient-balance: ensure jm-045 seeds wallet_state=sufficient (offer sends, returns to feed) and jm-046 seeds wallet_state=insufficient (402 -> insufficient_balance_sheet) per the backend contract.\n3. jm-047-jeeber-pending-offers: after withdraw the row should disappear (backend fixed) - assert it.\n4. jm-028/029 (W1 regression AC3): the Replies->Check-Offers opens a base-fixture request instead of the seeded offers_received request. Fix the flow so it opens the seeded request (offer-001/002 on the offers_received seed) before asserting offer_accept_sheet. (App accept logic is correct per the closer.)\nKeep id-only assertions; validate YAML. Return: per-flow edits.\n\n=== GATE MAPPING ===\n' + gate + '\n\n=== BACKEND CONTRACT ===\n' + backend, { label: 'res:flowfix', phase: 'FlowFix', model: 'sonnet' })

// ---------- Phase 3: static green ----------
phase('StaticGreen')
const staticGreen = await agent(COMMON + '\n\nROLE: Build Integration Engineer (Opus). Make statically green after the gate + (mock is separate repo) changes: cd ' + APP + ' && /Users/oudaykhaled/flutter/bin/flutter analyze (fix new errors) ; flutter test test/ (report; the seam_landing + gate tests must stay green). Return: analyze result + test summary + files fixed.\n\n=== GATE ===\n' + gate, { label: 'res:static-green', phase: 'StaticGreen' })

// ---------- Phase 4: verify (Sonnet, fast now) ----------
phase('Verify')
const verify = await agent(COMMON + '\n\nROLE: Senior Principal QA Engineer (Sonnet) - W2 RESIDUAL VERIFY. Boot is fast now (Firebase fix). Steps: mock up on :4010 (restart if down); ensure emulator jeeb_test up; CLEAN INSTALL: cd ' + APP + ' ; /Users/oudaykhaled/flutter/bin/flutter build apk --debug --flavor dev --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010 ; adb uninstall app.jeeb.mobile.dev 2>/dev/null ; adb install -r build/app/outputs/flutter-apk/app-dev-debug.apk. export JAVA_HOME via /usr/libexec/java_home. Run EACH once (timeout 180): jm-044-offer-kyc-gate, jm-045-offer-composer, jm-046-insufficient-balance-sheet, jm-047-jeeber-pending-offers, jm-048-delivery-feed, jm-028-offer-review, jm-029-accept-offer-confirm. Append/update each row in ' + RESULTS + ' (Residual Verify section). No fixes, no re-runs. Return: per-flow PASS/FAIL + category for any remaining red.', { label: 'res:verify', phase: 'Verify', model: 'sonnet' })

// ---------- Phase 5: signoff ----------
phase('Signoff')
const signoff = await agent(COMMON + '\n\nROLE: Product Owner (Opus) - W2 FINAL SIGN-OFF. Using the residual verify results below + the W2 closer report + ACs in 30_BACKLOG.md, update ' + OUT + '/signoffs/JM-###.md for all W2 items (036-048, 051, 053, 054): SIGNED for green, PARTIAL/BLOCKED with exact owner action otherwise. Return: W2 SIGNED count (of 16), the jeeber spine end-to-end status (gate->onboarding->kyc->funding->feed->offer-gate->composer->reserve->mark-delivered->rate), any remaining residual + owner, and confirm jm-028/029 (W1) green.\n\n=== RESIDUAL VERIFY ===\n' + verify, { label: 'res:signoff', phase: 'Signoff' })

return { backend: !!backend, gate: !!gate, flow_fix: !!flowFix, static_green: staticGreen, verify: verify, signoff: signoff }
