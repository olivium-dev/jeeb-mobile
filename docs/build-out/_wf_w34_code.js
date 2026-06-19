export const meta = {
  name: 'jeeb-w34-code',
  description: 'Final build wave W3 (wallet ledger/earnings) + W4 (notifications/dispute/support/account/reviews/settings) + 4 W2 residual fixes: parallel infra + ~18 engineers + static-green + review',
  phases: [
    { title: 'Infra', detail: 'integrator (W3/W4 routes+DI+l10n+shell), backend (W2m/W3m/S1/R1m + fix W1m/O1), seam (notif/dispute/reviews seeds)' },
    { title: 'Engineers', detail: '~18 engineers: W3(3) + W4(12) + 3 W2-residual one-liners' },
    { title: 'StaticGreen', detail: 'flutter analyze + test green' },
    { title: 'Review', detail: '5 cluster reviewers' },
  ],
}

const APP = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const MOCK = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mock-backend'
const OUT = APP + '/docs/build-out'
const COMMON = 'Jeeb mobile build-out, FINAL WAVE W3+W4 (+W2 residuals). READ FIRST: ' + OUT + '/00_CTO_BRIEF.md, ' + OUT + '/01_CTO_DECISIONS.md, ' + OUT + '/40_GUARDRAILS_ARCH.md, ' + OUT + '/41_GUARDRAILS_TESTING.md, ' + OUT + '/42_GUARDRAILS_MOCK.md, ' + OUT + '/30_BACKLOG.md (W3 items JM-052/055/056 + W4 items JM-057..068 with ACs + EXACT Semantics identifiers), ' + OUT + '/50_EXECUTION_PLAN.md (WAVE 3/4), ' + OUT + '/21_NAV_PLAN.md, ' + OUT + '/20_GAP_MAP.md (flutter targets), ' + OUT + '/62_SEAM_HARNESS.md, ' + OUT + '/66_W2_QA_RESULTS.md (the 4 W2 residuals). App at ' + APP + ', mock at ' + MOCK + ' (:4010). OMDS only; clean arch; flutter_bloc; GoRouter; GetIt; Dio. Every interactive/asserted widget carries Semantics(identifier:) EXACT per the backlog ACs. These W4 screens are the cross-wave targets W1/W2 AP-9-deferred (dispute/reviews/support/notifications/earnings) - building them lets the final hardening close those legs. Do NOT run flutter/emulator. CTO-D + R-F for gaps.'

// ---------- Phase 1: Infra ----------
phase('Infra')
const [integrator, backend, seam] = await parallel([
  () => agent(COMMON + '\n\nROLE: FINAL-WAVE INTEGRATOR (Opus). You alone edit app_router.dart, injection_container.dart, shell_screen.dart(+tabs), lib/l10n/*.arb. Leave app COMPILING. Per 50_EXECUTION_PLAN W3/W4 + 21_NAV_PLAN:\n- W3 routes: ADD /wallet/activity (wallet-activity, JM-055); /wallet/transactions/:id (transaction-detail, JM-056). (earnings dashboard JM-052 is the Earnings tab body.)\n- W4 routes: ADD /notifications (JM-057); /support (support-ticket, JM-063); /disputes/:id (dispute-status, JM-065); /profile/delivery-man/reviews (reviews-list, JM-068); register /settings/language (JM-059); /settings/password (password-security, JM-061). Flesh the /account-status body route (gate seeded in W0, JM-066). Dispute open+evidence (JM-060) extends the existing /orders/:id/escalate.\n- SHELL: the header BELL (orders_home_bell / delivery_tab_bell / customer_profile_bell) now routes to real /notifications (JM-057) - remove the coming-soon guard. The wallet chip -> wallet-hub already wired.\n- DI: register notif/support/dispute/reviews/ledger/txn repos (bind real Dio; stub markers only if a mock fix is pending).\n- l10n: all W3/W4 keys into both ARBs.\n- Create compiling stubs for new screens so routes resolve; engineers fill bodies.\nGATE: flutter analyze clean on touched files; flutter test test/core/router/ resolves new routes. Return: routes/names added, shell bell change, DI, l10n, stubs, analyze result.', { label: 'w34:integrator', phase: 'Infra' }),
  () => agent(COMMON + '\n\nROLE: FINAL-WAVE BACKENDER (Opus). Own ' + MOCK + ' ONLY. Land:\n1. W2m: wallet ledger - GET paginated typed rows (reserve/fee_won/released/refund/penalty/topup/gift) for JM-055.\n2. W3m: wallet txn-by-id - GET /wallet ledger row detail for JM-056.\n3. S1: support-ticket service (create/list) for JM-063.\n4. R1m: reviews-list source (per-jeeber, paginated) for JM-068.\n5. FIX the W2 residual MOCK_GAP (CRITICAL, jm-045 AC5 + jm-046): GET the jeeber wallet endpoint must HONOR user-jeeber-002 insufficient/empty seed (it currently falls back to user-client-001/enough); and POST /offer-service/v1/offers must return 402 {needed,available} when that jeeber wallet is insufficient. Verify with curl that seeding wallet=insufficient for user-jeeber-002 then POSTing an offer returns 402.\nConfirm disputes (POST/GET /v1/disputes) + notifications (list/prefs/read) are already mock-ready (the W4 dispute/notif screens use them). Keep npm build + npm test green. Append shapes to 42_GUARDRAILS_MOCK.md. Return: endpoints + the verified 402/wallet-seed fix.', { label: 'w34:backend', phase: 'Infra' }),
  () => agent(COMMON + '\n\nROLE: FINAL-WAVE SEAM (Opus). App seam only (lib/core/dev_seam/* + MainActivity.kt). Add any seam values W3/W4 flows need to start mid-state, extending the 62 pattern + keeping the seam_landing_test green: a notifications-populated seed (so /notifications shows typed rows), a dispute-open seed (so /disputes/:id shows a status), an account suspended seed (likely exists - confirm jeeb.seam.session=suspended lands on /account-status), a has-reviews seed for the jeeber profile. Reuse mock seed endpoints (backend provides data). Do NOT edit app_router/shell/DI/l10n (integrator) or the mock (backend). Update 62_SEAM_HARNESS.md + extend test/core/dev_seam/seam_landing_test.dart for any new landing. flutter analyze clean. Return: new seam values + landing screens.', { label: 'w34:seam', phase: 'Infra' }),
])

// ---------- Phase 2: Engineers ----------
phase('Engineers')
const ITEMS = [
  { jm: 'JM-052', label: 'earnings-dashboard', file: 'lib/features/earnings/.../earnings dashboard (Earnings tab)', note: 'Fee-only reframe (D41/D44): earnings_total_cash (net off-wallet COD), earnings_fees_paid (captured 10%), member-since; links to wallet-hub + wallet-activity. NOT gross/commission.' },
  { jm: 'JM-055', label: 'wallet-activity', file: 'NEW lib/features/wallet/.../wallet_activity_list (route /wallet/activity)', note: 'Typed ledger rows wallet_activity_row_<id> (Reserve/Fee-won/Released/Refund/Penalty/Top up/Gift) amount+sign+icon+ref; infinite scroll+skeletons (D73); tap -> transaction-detail. Reads W2m.' },
  { jm: 'JM-056', label: 'transaction-detail', file: 'NEW lib/features/wallet/.../transaction_detail (route /wallet/transactions/:id)', note: 'Per-type txn_detail (Fee-won=exact 10%+pinned price; Refund/Penalty+dispute link); txn_detail_order_link -> order-summary; txn_detail_dispute_link -> dispute-open-evidence. Reads W3m.' },
  { jm: 'JM-057', label: 'notifications-list', file: 'NEW lib/features/notifications/.../ (route /notifications)', note: 'Typed notif_row_<id> (offer/accepted/status/low-balance/fee/refund/topup/KYC) + timestamp; per-row deep-link dispatch per D84; empty state; mark-read. Reads notification-service.' },
  { jm: 'JM-058', label: 'notification-prefs', file: 'lib/features/settings/.../notification_prefs_screen (/settings/notifications)', note: 'Categories offers/order-status/wallet/marketing, transactional locked (D64); debounced PATCH prefs; push-only note.' },
  { jm: 'JM-059', label: 'language-settings', file: 'lib/features/.../language_settings_screen (register /settings/language)', note: 'language_arabic_option -> instant RTL flip; back -> customer-profile.' },
  { jm: 'JM-060', label: 'dispute-open-evidence', file: 'extend lib/features/escalate/.../EscalateScreen (/orders/:id/escalate); retire dead dispute_screen.dart', note: 'dispute_reason + dispute_photos (image_picker <=5) + dispute_voice (D53) + auto-attached chat/GPS timeline; submit POST /v1/disputes -> dispute-status; support link.' },
  { jm: 'JM-061', label: 'password-security', file: 'NEW /settings/password', note: 'current/new/confirm + validation; social-only accounts -> auth-set-password?mode=in-app-social (D90); back -> customer-profile.' },
  { jm: 'JM-062', label: 'logout-delete', file: 'extend lib/features/settings/.../SettingsScreen account section', note: 'logout_confirm_cta/delete_confirm_cta -> clear session -> splash (D5); reachable from account-status.' },
  { jm: 'JM-063', label: 'support-ticket', file: 'NEW lib/features/support/.../ (route /support)', note: 'support_category+support_body+support_attach+support_order_link; submit -> confirmation -> customer-profile; reads S1. Reachable from account-status/dispute-status/kyc-rejected (D76).' },
  { jm: 'JM-064', label: 'rate-the-app', file: 'thin in_app_review handler from customer-profile row', note: 'customer_profile_rate_app_row -> native store-review sheet; returns to profile.' },
  { jm: 'JM-065', label: 'dispute-status', file: 'NEW /disputes/:id', note: 'dispute_status_state (Open/Resolved) + outcome (refund/penalty, D2) + evidence summary; support link; back -> order-chat. Reads /v1/disputes.' },
  { jm: 'JM-066', label: 'account-status', file: 'flesh lib/features/account_status/.../account_status_screen (route + W0 gate exists)', note: 'Suspended/locked body: account_status_support_cta -> support-ticket; account_status_signout_cta -> logout-delete. Gate already forces this for status=suspended/locked (D5).' },
  { jm: 'JM-067', label: 'jeeber-profile-reviews', file: 'lib/features/delivery_man_profile/.../DeliveryManProfileScreen (/profile/delivery-man)', note: 'Remove Helpful/Reply (D57); profile_view_all_reviews -> reviews-list; cold-start hide score until N>=5 (D59); first-name attribution (D58); close -> offer-review.' },
  { jm: 'JM-068', label: 'reviews-list', file: 'NEW /profile/delivery-man/reviews', note: 'Infinite scroll+skeletons (D73); reviewer first name (D58); cold-start hide<5+New badge (D59); review_<id>_report_cta (D27); back -> jeeber-profile-reviews. Reads R1m.' },
  { jm: 'JM-044r', label: 'w2res-gate-register', file: 'lib/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart', note: 'W2 RESIDUAL one-liner: gate_register_link must navigate to delivery_register_prompt (currently mis-wired to jeeber_feed_root). Fix the route target.' },
  { jm: 'JM-047r', label: 'w2res-pending-back', file: 'lib/features/jeeber_home/.../jeeber_feed_tab_view.dart', note: 'W2 RESIDUAL one-liner: add Semantics(identifier: "pending_offers_back") to the existing back control on the pending-offers sub-tab.' },
  { jm: 'JM-028r', label: 'w2res-offer-cancel', file: 'lib/features/client_offers/.../client_offers_screen.dart', note: 'W2 RESIDUAL one-liner: add Semantics(identifier: "offer_review_cancel_cta") to the offer-review cancel control + wire it to cancel-request-confirm (JM-030).' },
]
const engResults = await parallel(ITEMS.map((it) => () =>
  agent(COMMON + '\n\nROLE: Senior Principal Flutter Engineer (Opus). Implement ' + it.jm + ' (' + it.label + '). Target: ' + it.file + '. ' + it.note + '\n\nRead the relevant ACs in 30_BACKLOG.md + the gap in 20_GAP_MAP.md; expose EVERY named Semantics(identifier:) exactly. Wire data to the real mock endpoints (per 42 + backend output below). Touch ONLY your feature file(s); do NOT edit app_router/injection_container/.arb/shell (integrator did those; reference its routes/keys). Missing route/key -> append to ' + OUT + '/50_ROUTE_REQUESTS.md. Do NOT run flutter/emulator. Return: files changed, exact ids exposed, endpoints wired, gaps.\n\n=== INTEGRATOR ===\n' + integrator + '\n\n=== BACKEND ===\n' + backend + '\n\n=== SEAM ===\n' + seam,
    { label: 'eng:' + it.label, phase: 'Engineers' })
)).then(r => r)

// ---------- Phase 3: Static green ----------
phase('StaticGreen')
const staticGreen = await agent(COMMON + '\n\nROLE: Build Integration Engineer (Opus). All W3/W4 + residual engineers done. Make STATICALLY GREEN: cd ' + APP + ' && /Users/oudaykhaled/flutter/bin/flutter analyze (fix new errors). Then flutter test test/ (report; seam_landing + gate tests must stay green). Bounded effort. Return: analyze (CLEAN of errors), test summary, files fixed.\n\n=== ENGINEER OUTPUTS ===\n' + JSON.stringify(engResults.map((r, i) => ({ jm: ITEMS[i].jm, s: typeof r === 'string' ? r.slice(0, 800) : r }))), { label: 'w34:static-green', phase: 'StaticGreen' })

// ---------- Phase 4: Review ----------
phase('Review')
const CLUSTERS = [
  { key: 'wallet-w3', items: 'JM-052, JM-055, JM-056' },
  { key: 'notifications+settings', items: 'JM-057, JM-058, JM-059, JM-064' },
  { key: 'dispute+support+account', items: 'JM-060, JM-065, JM-063, JM-066, JM-061, JM-062' },
  { key: 'reviews', items: 'JM-067, JM-068' },
  { key: 'w2-residuals', items: 'JM-044r, JM-047r, JM-028r' },
]
const reviews = await parallel(CLUSTERS.map((c) => () =>
  agent(COMMON + '\n\nROLE: Senior Principal Flutter Engineer - CODE REVIEW (Opus) for the ' + c.key + ' cluster: ' + c.items + '. Read the files. Review vs ACs (30_BACKLOG), identifier contract (exact ids, no leading underscores), 40_GUARDRAILS_ARCH (clean arch, OMDS, l10n, no shared-file edits), decisions (D57 no helpful/reply, D64 notif categories, D2/D53 dispute, D5 account-status). Return one verdict per item: {jm, approved, must_fix:[], nits:[], identifiers_ok}. Block only on real violations.',
    { label: 'review:' + c.key, phase: 'Review' })
)).then(r => r)

return { integrator: !!integrator, backend: !!backend, seam: !!seam, engineers: engResults.length, static_green: staticGreen, reviews: reviews.length }
