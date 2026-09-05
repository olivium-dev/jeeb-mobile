# PLAN P12 — naming and reachability nits (earnings empty CTA id; unreachable `ChatTab`)

Branch: `ux/api-error-handling-empty-states` @ `ecfd3cc1` (worktree
`/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`, draft PR #335).
All paths below are relative to that worktree unless prefixed `jeeb-gateway:`.
Planning only — nothing in this document has been applied.

## 0. Verdict in one paragraph

1. **Earnings id.** The observation is half-right. `<screen>_retry_cta` is the *error-rung* id and
   earnings already has it (`earnings_retry_cta`, `lib/features/earnings/presentation/earnings_dashboard_screen.dart:201`);
   the empty rung must NOT carry it (`test/features/earnings/earnings_dashboard_states_test.dart:140-150`
   asserts `earnings_retry_cta` findsNothing on the empty period — error-before-empty, R6).
   The real defect is that the app has no single grammar for the CTA *inside* an empty block:
   3 sites use `<screen>_empty_retry_cta`, 2 use `<screen>_empty_refresh_cta`, and the earnings one
   is asserted by no test. **Fix: rename both `_empty_refresh_cta` sites to `<screen>_empty_retry_cta`,
   assert them, register the grammar row, and repair the (vacuous) coverage ratchet that let this hide.**
2. **`ChatTab`.** Delete it and its private stack. It was unmounted from the shell on 2026-05-19
   (`b10e8cce`, PR #32), the nav blueprint has five frozen `shell_tab_<id>` targets with no chat tab,
   it re-renders the same `GET /v1/requests` list the Deliveries tab already shows, and every chat is
   reachable through `/chat/:id` from three product entry points. Wiring a 6th tab is a navigation
   blueprint change that needs its own plan and owner sign-off; it is not a "nit".

## 1. Evidence (verified 2026-09-05)

### 1.1 Earnings empty CTA
| Fact | Where |
|---|---|
| Error rung: `identifier: 'earnings_error'`, `retryIdentifier: 'earnings_retry_cta'`, `exitIdentifier: 'earnings_exit_cta'` | `lib/features/earnings/presentation/earnings_dashboard_screen.dart:197-205` |
| Empty rung: `JeebEmptyState.compact(identifier: 'earnings_empty', action: JeebCtaButton.outline(label: copy.emptyRefresh, identifier: 'earnings_empty_refresh_cta', onTap: cubit.refresh))` | `earnings_dashboard_screen.dart:255-268` |
| Label is `_pick('Refresh', 'تحديث')` (facade, not ARB — out of P12 scope, WP-9) | `lib/features/earnings/presentation/earnings_dashboard_l10n.dart:106` |
| Test: "earnings_empty renders on an empty period, WITHOUT a retry CTA" → `earnings_retry_cta` findsNothing | `test/features/earnings/earnings_dashboard_states_test.dart:140-150` |
| `earnings_empty_refresh_cta` appears in NO test file (only lib + the audited registry) | `grep -rn earnings_empty_refresh_cta test` → 0 hits |
| Registry entry | `lib/core/observability/session_trace/audited_interaction_identifiers.dart:225` |
| Sibling with the same shape: `jeeber_feed_empty_refresh_cta` | `lib/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart:162`; registry `:293`; asserted at `test/features/jeeber_home/jeeber_home_failure_identifiers_test.dart:71` |
| Majority shape (3 sites): `compose_tier_empty_retry_cta` (`lib/features/location/presentation/widgets/compose_tier_section.dart:164`), `compose_tier_sheet_empty_retry_cta` (`:373`), `tier_selection_empty_retry_cta` (`lib/features/tier_selection/presentation/tier_selection_screen.dart:153`) | registry `:97,104,773` |
| Grammar doc has no row for an empty-block action; only `<screenId>_<element>` with `_cta` in the vocabulary | `docs/build-out/41_GUARDRAILS_TESTING.md:38-60`; `docs/build-out/30_BACKLOG.md:18-21` |
| R6 contract text: "Identifier triple `<screen>_loading\|_empty\|_error` + `<screen>_retry_cta`" | `analysis/RULINGS.md` R6 |
| Device: run-2 recovery dump shows `earnings_empty` + `earnings_empty_refresh_cta` (jeeber with no earnings this period, real 200) | `device-evidence-2/outage-jeeber/REPORT.md` rows B3 and R3 (`03-baseline-earnings.xml`, `35-recover-earnings.xml`) |

### 1.2 The coverage ratchet is vacuous (found while verifying 1.1)
`test/guardrails/failure_identifier_coverage_ratchet_test.dart:37-38`:
```dart
bool asserted(String id) =>
    corpus.contains("'\$id'") || corpus.contains('"\$id"');
```
`"'\$id'"` is the literal five characters `'$id'`, not an interpolation, so `asserted()` returns the
same answer for every id. A probe (`scratchpad/ratchet_probe.dart`, run 2026-09-05) gives:
`declared=162 buggyAssertedForAll=true realUnasserted=26`. The test passes at `_kFloor = 0` while 26
declared `_error|_retry_cta|_empty|_loading` ids (incl. `compose_tier_empty_retry_cta`,
`tier_selection_empty_retry_cta`, `jeeber_feed_error`, `saved_locations_empty`, `waiting_retry_cta`)
are asserted by no test. Also: `_refresh_cta` is outside the regex, which is exactly why
`earnings_empty_refresh_cta` was invisible. The rename in §2 moves it under the regex; the ratchet
must be real for that to mean anything.

### 1.3 `ChatTab` reachability
| Fact | Where |
|---|---|
| Declared; test/preview seams only | `lib/features/shell/tabs/chat_tab.dart:35-48` (517 lines, 8 `@JeebPreview`s) |
| Shell tab list = requests / delivery / `_jeeberLandingTabId` / earnings / profile — no chat | `lib/features/shell/shell_screen.dart:352-418`; ids frozen per `:69,541` |
| Blueprint: "Tab targets: `shell_tab_<id>` (requests/delivery/profile/dashboard/earnings)" | `docs/build-out/30_BACKLOG.md:20-21`; `docs/build-out/41_GUARDRAILS_TESTING.md:50,56` |
| Removed from the shell on 2026-05-19 (`- page: const ChatTab(),` ×2) | `git show b10e8cce -- lib/features/shell/shell_screen.dart` (PR #32) |
| Already documented as unmounted | `docs/build-out/11_FLUTTER_INVENTORY.md:48-49,121`; `docs/redesign-2026-08/01-SCREEN-COUNT.md:162` |
| Only constructor sites outside its own file: catalog + tests | `lib/devtool/catalog/entries/batch_11_entries.dart:166-208`; `test/features/shell/chat_tab_states_test.dart:55`; `test/features/shell/chat_tab_row_contract_test.dart:30`; `test/previews/shell/chat_tab_preview_test.dart` |
| Its data source is the Deliveries list | `lib/features/chat/data/dio_chat_conversations_repository.dart:15` (`/v1/requests`) = `lib/features/order_history/data/dio_order_repository.dart:17` |
| Product chat entry points that remain | `lib/features/shell/tabs/dashboard_tab.dart:166` (`context.push('/chat/…')`), `lib/core/notifications/domain/notification_deep_link.dart:104`, `lib/core/router/app_router.dart:362` (`/chat/:id`) |
| Gateway route behind it exists and is auth-gated (RFC 7807) | `GET https://msi.olivium.space/gateway/v1/requests` → `401 application/problem+json` (probe 2026-09-05); `jeeb-gateway:origin/main@6679f6e src/JeebGateway/Controllers/RequestsController.cs:23,322` |
| A real inbox endpoint exists if an inbox is ever wanted — NOT what ChatTab uses | `jeeb-gateway:origin/main src/JeebGateway/Controllers/JeebConversationsController.cs:163` (`GET v1/conversations`) |
| Private stack used by nothing else in `lib/` | `ChatConversationsRepository/Cubit/State/Summary` consumers: `chat_tab.dart`, `chat_tab_fixtures.dart`, `batch_11_entries.dart`, `chat_di.dart` only |
| Registry aliases for its ids | `audited_interaction_identifiers.dart:1060-1064` (`chat_tab_empty/_error/_loading/_partial_note/_refresh_error` → `conversation_tab_*`) |
| ARB copy used only by it | `lib/l10n/app_en.arb:5889-5892,6484-6485`; `lib/l10n/app_ar.arb:2343-2344,2645`; accessors `lib/l10n/app_localizations.dart:3398-3399,3710`. **`navChat` is NOT its own — keep it** (`lib/features/deep_link_targets/chat_detail_screen.dart:1533`). |
| Floors that a deletion must respect | catalog ≥87 screens / ≥282 states (`test/devtool/catalog_size_test.dart`; current ≈95/≈496 by `CatalogEntry(`/`CatalogState(` count); preview INV-7 counts *uncovered* widgets ≤247 (`test/previews/preview_structure_test.dart:14,184-210`) — deleting a covered widget cannot raise it |

## 2. Change A — one empty-block action grammar

Target grammar (new row for `41_GUARDRAILS_TESTING.md §1.1`):

| widget kind | id form | example |
|---|---|---|
| **Action inside an empty block** (re-issues the read from `<screen>_empty`) | `<screen>_empty_retry_cta` | `earnings_empty_retry_cta`, `tier_selection_empty_retry_cta` |

Rule text to add under the table: "`<screen>_retry_cta` / `<screen>_exit_cta` belong to the
`JeebFailureBlock` error rung only. An empty rung never carries `<screen>_retry_cta`
(error-before-empty, RULINGS R6); its own action is `<screen>_empty_retry_cta`."

### A1 `lib/features/earnings/presentation/earnings_dashboard_screen.dart`
- Line 265: `identifier: 'earnings_empty_refresh_cta',` → `identifier: 'earnings_empty_retry_cta',`.
- Nothing else changes (label stays `copy.emptyRefresh`, `onTap: cubit.refresh`, `expand: false`).

### A2 `lib/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart`
- Line 162: `identifier: 'jeeber_feed_empty_refresh_cta',` → `identifier: 'jeeber_feed_empty_retry_cta',`.

### A3 `lib/core/observability/session_trace/audited_interaction_identifiers.dart`
- Line 225: `'earnings_empty_refresh_cta',` → `'earnings_empty_retry_cta',` (same slot; still sorted between `earnings_empty` and `earnings_error`).
- Line 293: `'jeeber_feed_empty_refresh_cta',` → `'jeeber_feed_empty_retry_cta',` (same slot).
- Do NOT add aliases; do not touch any other entry. The registry must stay exact-value (header comment, `:1-6`).

### A4 `test/features/earnings/earnings_dashboard_states_test.dart`
- Rename the test at `:140-141` to `'$tag: earnings_empty renders on an empty period with earnings_empty_retry_cta and WITHOUT the error retry CTA'`.
- Inside it, keep `find.bySemanticsIdentifier('earnings_retry_cta'), findsNothing` and add:
  ```dart
  expect(find.bySemanticsIdentifier('earnings_empty_retry_cta'), findsOneWidget);
  ```
- Add one more `testWidgets` in the same `for (locale)` loop: pump `_SeededRepo(_empty)`, `tester.tap(find.bySemanticsIdentifier('earnings_empty_retry_cta'))`, `pump()`, then assert `earnings_loading` findsNothing and `earnings_empty` findsOneWidget (R6: `refresh()` never flips to loading). Use the existing `_pump` + `useReduceMotion(tester)` + `ensureSemantics()` pattern at `:113-137`. EN+AR come from the loop.

### A5 `test/features/jeeber_home/jeeber_home_failure_identifiers_test.dart`
- Line 71: `'jeeber_feed_empty_refresh_cta'` → `'jeeber_feed_empty_retry_cta'`. Test title at `:54-55` ("…and its refresh CTA") may stay.

### A6 Repair the ratchet — `test/guardrails/failure_identifier_coverage_ratchet_test.dart`
- Line 38: `corpus.contains("'\$id'") || corpus.contains('"\$id"')` → `corpus.contains("'$id'") || corpus.contains('"$id"')`.
- Line 11 (`const int _kFloor = 0;`): set to the number the repaired test reports on first run (expected **26** after A1–A5; run `flutter test test/guardrails/failure_identifier_coverage_ratchet_test.dart` — the failure message lists the sites). Replace the comment at `:10` with: `/// 26 pre-existing unasserted ids measured 2026-09-05 (registry was vacuous before). Never raise.` (2 lines max).
- Do not sweep the 26 in this PR; list them in the PR description as WP-9 debt (the probe output is in `scratchpad/ratchet_probe.dart` run log: address_form_save_error, biometric_prompt_loading, chat_screen_empty, chat_screen_loading, compose_tier_empty_retry_cta, compose_tier_sheet_empty_retry_cta, compose_tier_sheet_loading, current_location_gps_retry_cta, jeeber_feed_error, jeeber_home_feed_loading, kyc_wizard_tos_error, location_search_empty, location_search_error, location_search_retry_cta, location_select_saved_addresses_retry_cta, offer_status_filter_empty, order_detail_loading, pending_offers_loading, prohibited_item_report_photo_error, saved_locations_empty, saved_locations_mutation_error, super_login_plus_picker_loading, support_reply_attach_error, support_thread_send_error, tier_selection_empty_retry_cta, waiting_retry_cta).

### A7 `docs/build-out/41_GUARDRAILS_TESTING.md`
- Insert the table row and rule text from the top of §2 after line 50 (the `Screen root` row) / after line 60 respectively.

## 3. Change B — delete `ChatTab` and its private stack

Owner decision required first (see §6). Once "delete" is confirmed:

### B1 Delete files (git rm)
- `lib/features/shell/tabs/chat_tab.dart`
- `lib/features/chat/application/chat_conversations_cubit.dart`
- `lib/features/chat/application/chat_conversations_state.dart`
- `lib/features/chat/data/dio_chat_conversations_repository.dart`
- `lib/features/chat/domain/chat_conversation_summary.dart`
- `lib/devtool/catalog/fixtures/chat_tab_fixtures.dart`
- `test/features/shell/chat_tab_states_test.dart`
- `test/features/shell/chat_tab_row_contract_test.dart`
- `test/previews/shell/chat_tab_preview_test.dart`
- `test/features/chat/chat_conversations_repository_failure_test.dart`
Before deleting, re-run `grep -rn "ChatConversationsRepository\|ChatConversationsCubit\|ChatConversationsState\|ChatConversationSummary\|ChatConversationsPage\|chat_tab_fixtures\|chatTabPreviewTransportLog" lib test` and confirm the only hits are the files above plus B2/B3. Any other hit = stop and report.

### B2 `lib/devtool/catalog/entries/batch_11_entries.dart`
- Remove imports at `:9` (`chat_conversations_cubit.dart`), `:10` (`chat_tab.dart`), `:37` (`fixtures/chat_tab_fixtures.dart`). Keep `dart:async` (`unawaited` still used at `:503,547`).
- Remove `_chatTabEntry,` from `batch11Entries` at `:56`.
- Delete `final CatalogEntry _chatTabEntry = …` (`:166-199`) and `Widget _chatTabRefreshed()` (`:201-208`). Keep `_tabPreview` (used by HomeTab/OrdersTab entries).

### B3 `lib/features/chat/chat_di.dart`
- Remove the `ChatConversationsRepository` block (`:13-17`) and imports `data/dio_chat_conversations_repository.dart` (`:5`) and `domain/chat_conversation_summary.dart` (`:7`). Keep the `ChatOutbox` registration (used by chat screens) and the `Dio`/`GetIt`/`SharedPreferences` imports it needs. `injection_container.dart:542` keeps calling `registerChatDependencies(sl)` unchanged.

### B4 `lib/core/observability/session_trace/audited_interaction_identifiers.dart`
- Delete the 5 alias lines `:1060-1064` (`chat_tab_empty`, `chat_tab_error`, `chat_tab_loading`, `chat_tab_partial_note`, `chat_tab_refresh_error`). `chat_tab_row_<id>` is dynamic and was never registered.

### B5 ARB + accessors (dead copy)
- `lib/l10n/app_en.arb`: delete `:5889-5892` (`chatTabEmptyTitle` + `@`, `chatTabEmptyBody` + `@`) and `:6484-6485` (`chatTabLoadingHeadline` + `@`). Mind trailing commas on the neighbouring lines.
- `lib/l10n/app_ar.arb`: delete `:2343-2344` and `:2645`.
- `lib/l10n/app_localizations.dart`: delete getters `:3398-3399` and `:3710`.
- Keep `navChat` (still used at `chat_detail_screen.dart:1533`).
- Run `bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze` and `bash qa/t-mob-fix-002/ar_plurals_check.sh`: all strict counters must stay 0.

### B6 Docs (two one-line edits; history docs untouched)
- `docs/build-out/11_FLUTTER_INVENTORY.md:48-49` note → "`shell/tabs/chat_tab.dart` was deleted 2026-09 (unmounted since PR #32; chat is reached via `/chat/:id`)." and `:121` bullet → same wording.
- Leave `docs/redesign-2026-08/01-SCREEN-COUNT.md:162` and `docs/previews/*` as dated history.

### B7 Floors
- `test/devtool/catalog_size_test.dart`: unchanged (95→94 screens ≥87; ~496→~489 states ≥282).
- `test/previews/preview_structure_test.dart:14` `_coverageFloor = 247`: unchanged (INV-7 counts *uncovered* widgets; ChatTab's widgets were covered). If INV-7 fails anyway, run `dart run tool/preview_coverage.dart` and report — do not edit the floor without that output.
- Coverage: −842 covered lib lines out of 67,027 (84.65% → ≈84.5%); floor 79%.

## 4. Order of execution (one implementer, one commit or two)
1. `git -C <worktree> status` clean; `git fetch origin`; confirm HEAD `ecfd3cc1`.
2. Change A (A1→A7). `git add -A`. Run `flutter test test/features/earnings test/features/jeeber_home test/guardrails/failure_identifier_coverage_ratchet_test.dart` → set `_kFloor` per A6 → re-run green.
3. Change B (B1→B6) only after the owner decision in §6 is "delete". `git rm` first, then edits, then `git add -A` BEFORE any `flutter test` (mb1 residual-receipts fails on untracked .dart, R6).
4. Reconciled (C1): TWO commits on TWO branches. Change A → `chore(ux): one empty-block action id grammar; repair identifier ratchet` is the FIRST of the three commits allowed on PR #335 (batched with P11 and P10's CI fix, one push). Change B → `chore(chat): delete unmounted ChatTab stack` on follow-up branch `chore/delete-chat-tab` off post-merge `main`, only after OD-9 = YES and after P09 S1.6 has been captured (C6); it is the LAST item of the wave-2 l10n order (C10).

## 5. Gates (all must pass, in this order)
- `dart analyze --fatal-infos .`
- `bash tool/check_design_tokens.sh`
- `bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze` (strict counters 0) and `bash qa/t-mob-fix-002/ar_plurals_check.sh` (0 missing AR forms)
- `flutter test test/core/observability/session_trace/secret_redactor_test.dart` (the analyzer-based "every resolved static production identifier is classified" test — 2-minute budget; this is the one that proves A3/B4 are exact)
- `flutter test test/guardrails/` (all ratchets, incl. the repaired one at its new floor)
- `flutter test test/devtool/catalog_size_test.dart test/previews/preview_structure_test.dart test/tools/catalog_smoke_test.dart`
- `flutter test --exclude-tags capture --coverage` → expect ~10,5xx pass / 0 fail; coverage ≥79% (was 84.65%). Never `--update-goldens`.

## 6. Owner decision (exact)
**"Delete `ChatTab` and its conversations stack (recommended) — YES / NO."**
If NO ("wire it"), this plan stops at Change A; a 6th shell tab is a nav-blueprint change (frozen
`shell_tab_<id>` set, `JeebPillNav` slot order R1, Maestro flows, `30_BACKLOG.md`/`41_GUARDRAILS_TESTING.md`
updates) and should be built on `GET /v1/conversations` (JeebConversationsController.cs:163), not on
the current `/v1/requests` re-render — that needs a separate plan, not this one.
Secondary (no answer = accept): the empty-block action grammar is `<screen>_empty_retry_cta`, and the
`jeeber_feed` sibling is renamed in the same PR so the app ends with one shape (5/5 sites).

## 7. Real-device validation (SM-A336B RZCT505K7WF, real UI, super-login OK)
Change A is the only user-visible part; Change B has no product surface.
1. Build/install (never uninstall): `flutter build apk --debug` in the worktree, `adb -s RZCT505K7WF install -r build/app/outputs/flutter-apk/app-debug.apk`. Open the Dev Tool alias (`app.jeeb.mobile.dev` / `com.olivium.jeeb.LegacyDevToolLauncher`), set Server URL to `https://msi.olivium.space/gateway` (`dev.base_url_override`), Apply & Restart. Check `/data/local/tmp/jeeb-dev-seam.json` is absent first (stale-token trap).
2. Super-login as the jeeber used in run 2 (the devtool jeeber whose Earn tab showed `earnings_empty` — run-2 B3), tap `shell_tab_earnings`.
3. `adb -s RZCT505K7WF shell uiautomator dump /sdcard/p12-earn-en.xml && adb pull /sdcard/p12-earn-en.xml`: MUST contain `earnings_empty` and `earnings_empty_retry_cta`; MUST NOT contain `earnings_empty_refresh_cta` or `earnings_retry_cta`.
4. Tap the node with resource-id `earnings_empty_retry_cta`; dump again at t≈1s: `earnings_empty` still present, `earnings_loading` absent (refresh never flips to loading).
5. Settings → Arabic; repeat 3 (`p12-earn-ar.xml`): same ids, label `تحديث`, RTL layout.
6. Requests tab (jeeber online; Reconciled C7: `defb1f07-…` is cancelled by P04 Part A, so the feed is empty unless another run has a ledgered request open — check `device-evidence-4/CREATED.jsonl`): dump MUST show `jeeber_feed_empty_state` + `jeeber_feed_empty_retry_cta`. If the feed has rows, this item is test-only (A5) and is recorded as such.
7. Change B: in the Dev Tool Screen Catalog, group `shell` no longer lists `ChatTab`; product shell still shows exactly five tabs (`shell_tab_requests/delivery/dashboard/earnings/profile` in a dump). Open any active order → chat still opens via `/chat/:id`.
8. Save dumps + screenshots under `scratchpad/device-evidence-4/p12/` with a REPORT.md table keyed by the ids above.

## 8. Risks
- Renaming an id that a Maestro/QA flow keyed on: `grep -rn "earnings_empty_refresh_cta\|jeeber_feed_empty_refresh_cta" docs qa .maestro maestro` → 0 hits today; the only recorded use is run-2's evidence file (history).
- The repaired ratchet will FAIL until `_kFloor` is set to the measured count; that failure is the point — do not "fix" it by reverting the escaping.
- `secret_redactor_test` is analyzer-driven over all of `lib/` (2-minute timeout); a stale registry entry does not fail it, a missing one does — so A3/B4 must add the two new ids and may not leave `earnings_empty_refresh_cta` unreferenced only by accident. Keep the file exact.
- Deleting `chat_tab_fixtures.dart` removes `CannedChatConversationsRepository`/`StalledChatConversationsRepository`; the B1 grep guards against a hidden consumer.
- Coverage dips ≈0.15 pt; still 5 pt above the floor.
- `lib/devtool/catalog/**` and `lib/core/observability/**` are R2 collision surfaces — this is a post-Stage-2 single-agent change, so editing them is allowed, but it must not run in parallel with another P-point that edits `batch_11_entries.dart` or the registry (P04/P10 do not).

## 9. Effort
M — ~20 files, mostly deletions; gates ≈15 min; device validation ≈20 min.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C1/C11): Change A rides PR #335 (tiny, and it makes the coverage ratchet honest for every reviewer and
  every later plan); P10 lane 0B is told the 0→26 floor is a repair. Change B is a follow-up PR (`chore/delete-chat-tab`).
- Reconciled (C6): the ChatTab question is asked ONCE as OD-9 (this plan's wording); P09 D-P09-1 points here. P09 S1.6
  (catalog ChatTab states) must be captured before Change B lands. R2's "never delete a catalog entry" is overridden only
  by an explicit YES to OD-9; the answer is recorded in the PR body.
- Reconciled (C8): P05's picker CTA is renamed to `devtool_wallet_funding_picker_empty_retry_cta` to satisfy the new
  grammar row; P06's `jeeber_home_greeting_retry_cta` is an error-rung id and conforms.
- Reconciled (C9/C16): registry (`audited_interaction_identifiers.dart`) edit order = P12-A (on #335) → P06 → P05 → P03;
  `jeeber_no_requests_view.dart` edit order = P12-A (line 162) → P05 WI-1 (lines 137-142).
- Reconciled (C12): evidence dir `scratchpad/device-evidence-4/p12/` (unchanged).
- Owner decision renumbered: OD-9 (delete ChatTab — YES/NO; secondary grammar row accepted by default).
