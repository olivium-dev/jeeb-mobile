# 01 · Authoritative screen count

**Date:** 2026-08-03 · **Branch:** `feat/redesign-24-migration` · **App @** `03c6c74` (PR #216)

---

## Headline

# 24 screens in scope

**Scope = the 24 `data-screen-label` frames on `Jeeb App Redesign.dc.html`.** Nothing else in the
package is a migration target.

**Why 24 and not another number:**

| Candidate | Number | Why it is not the answer |
|---|---|---|
| Frames in the whole package | 70 labeled (73 figures) | Spans three boards, two of which are not build specs. |
| Frames on the base board | **24** | ← **This.** The only board that is a 1:1 app spec. |
| Frames on Rich UI | 32 | Reference-only restyle. Adds 0 net-new buildable surfaces (see §4). |
| Frames on Social Ads | 14 | 6 are ad creatives at 1080×1080/1920 — not app screens at all. |
| App screens the board covers | 25 files | 24 designs → 25 files (08 folds into 07's file; 09 and 21 each span 2 files). |
| App screens that exist | 71 | The board is silent about 46 of them. **This is the real finding — §3.** |

The number to plan against is **24 designed screens → 25 files to edit**. The number to *worry*
about is **46 untouched surfaces** that will visibly diverge from the new design language.

---

## 1. Board inventory

Counted by `data-screen-label` attributes, reconciled against visible `<figcaption>`s.

| Board | `data-screen-label` | `<figcaption>` | Reconciliation | Status |
|---|---|---|---|---|
| `Jeeb App Redesign.dc.html` | **24** | 24 | Exact 1:1 | **IN SCOPE** |
| `Jeeb Rich UI.dc.html` | **32** | 35 | +3 captions are unlabeled variants of `E1 Empty home` (`E1 sample A · The empty pocket`, `sample B · Ask from the balcony`, `sample C · The beacon`) — alternates of one frame, not screens | Reference only |
| `Jeeb Social Ads.dc.html` | **14** | 6 | Only the 6 ad creatives carry captions (`Square · 1080×1080` / `Story · 1080×1920` × 3 concepts). The 8 walkthrough/app frames are labeled but uncaptioned | Marketing |
| **Total** | **70** | 65 | 73 `<figure>` elements | |

### 1a. The in-scope 24

`01 Onboarding` · `02 Registration` · `03 OTP verify` · `04 Client home` · `05 Voice recording` ·
`06 Transcription review` · `07 Request type` · `08 Tier catalog` · `09 Location picker` ·
`10 Request summary` · `11 Offers` · `12 Live tracking` · `13 OTP handover` · `14 Receipt confirm` ·
`15 Mutual rating` · `16 Jeeber home` · `17 Offer composer` · `18 Active delivery Jeeber` ·
`19 Earnings` · `20 Settings` · `21 Order chat` · `22 Become a Jeeber` · `23 Wallet` ·
`24 Order history`

### 1b. What Rich UI adds that the base board does not have

Rich UI's `R1`–`R23` are restyles of base screens. Set difference is exact:

```
base(24) − rich R-frames(23) = { Tier catalog }     rich − base = { }
```

So **Rich UI restyles 23 of the 24 and skips `08 Tier catalog` entirely.** Its 9 non-`R` frames are
the genuine additions:

| Rich UI frame | Adds | Already in the app? |
|---|---|---|
| `W1 Walkthrough say it` | walkthrough | **Yes** — `onboarding_screen.dart` builds a 3-page carousel (`_onboardingPages()`, three `_OnboardingPage(...)` at L172/179/188) |
| `W2 Walkthrough trusted` | walkthrough | Yes — same carousel |
| `W3 Walkthrough tracking` | walkthrough | Yes — same carousel |
| `E1 Empty home` (+3 variants) | empty state | **Yes** — `home_client/presentation/widgets/client_home_empty_view.dart` |
| `E2 Empty offers` | empty state | **Yes** — inline `OmdsEmptyState`, `client_offers_screen.dart:276` (`Key('offer-empty-state')`) |
| `E3 Empty jeeber feed` | empty state | **Yes** — `jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart` + `shell/widgets/jeeber_tab_empty_state.dart` |
| `E4 Empty history` | empty state | **Yes** — inline `OmdsEmptyState`, `order_history_screen.dart:290` (`Key('order-history-empty-...')`) |
| `L1 Log in` | email/password auth | **No — deliberately deleted** (see §4) |
| `L2 Sign up` | email/password auth | **No — deliberately deleted** (see §4) |

Every walkthrough and empty state Rich UI "adds" already ships as a page or widget inside a base-board
screen. Rich UI therefore adds **0 net-new buildable surfaces** — only `L1`/`L2`, which must not be built.

### 1c. Social Ads breakdown (14)

- **6 ad creatives** — `A/B/C — Square` + `A/B/C — Story`. Marketing assets, not app screens.
- **6 walkthrough frames** — `Walk 0 Splash` … `Walk 5 Pay cash`. Note: proposes a **6-step**
  walkthrough where the app ships **3** and Rich UI proposes **3**. Unresolved across boards; out of scope.
- **2 app frames** — `Redesign — Client home`, `Redesign V2 — Voice-first home`. Earlier explorations
  of `04 Client home`; the base board supersedes them.

---

## 2. The app's actual screens

### 2a. Screen files

```
find lib/features -name '*_screen.dart' -o -name '*_page.dart'   →  80
find lib          -name '*_screen.dart' -o -name '*_page.dart'   →  86   (0 are *_page.dart in features)
```

| Bucket | Count |
|---|---|
| All `*_screen.dart` / `*_page.dart` under `lib/` | **86** |
| − pure re-export shim (`features/onboarding/onboarding_screen.dart`, 8 lines, `export 'presentation/onboarding_screen.dart'`) | −1 |
| − not reachable from `main.dart` (§2c) | −14 |
| **Production-reachable screen files** | **71** |
| of which release-gated debug (`chat/presentation/dev_chat_preview_screen.dart`, `/dev-chat`) | 1 |

Reachability was computed as a transitive import **and export** walk from `lib/main.dart` with the
`lib/devtool/` subtree excluded (659 reachable Dart files). The export edge matters: the router
imports `features/onboarding/onboarding_screen.dart`, which only re-exports the real implementation —
an import-only walk wrongly marks the real onboarding screen dead.

### 2b. Routes

```
GoRoute( occurrences in app_router.dart      →  65
  − 2 non-declarations  (L530 `route is GoRoute` type test, L534 `_wrapGoRoute` signature)
  − 1 re-wrapper        (L543 `return GoRoute(` inside _wrapGoRoute, path: route.path)
= 62 declared routes
```

Cross-checked two independent ways, both landing on 62:

- `name:` string literals — **62**, all unique.
- `path:` string literals — **60**, all unique; **+2** constant paths (`_lockRoute = '/lock'` L280,
  `_accountStatusRoute = '/account-status'` L284) = **62**.

There are **no** `ShellRoute` / `StatefulShellRoute` declarations (count 0) — the tab shell is a plain
route at `/` mounting `ShellScreen`.

### 2c. The 14 files that are not production-reachable

| File | Why |
|---|---|
| `devtool/actions/actions_page.dart` | devtool harness |
| `devtool/catalog/catalog_screen.dart` | devtool harness (2 classes) |
| `devtool/dev_settings_page.dart` | devtool harness |
| `devtool/users/scenario_users_page.dart` | devtool harness |
| `features/tier_selection/presentation/tier_selection_screen.dart` | **route `/tier-selection` removed** — see §3a |
| `features/location/presentation/location_picker_screen.dart` | superseded duplicate — see §3b |
| `features/jeeber_request_feed/presentation/request_feed_screen.dart` | orphan; feed lives in `DashboardTab` |
| `features/deep_link_targets/kyc_status_screen.dart` | orphan; replaced by the KYC wizard (`app_router.dart:901`) |
| `features/delivery_status/presentation/delivery_status_screen.dart` | orphan |
| `features/goods_cost/presentation/goods_cost_screen.dart` | orphan |
| `features/client_unreachable/presentation/client_unreachable_screen.dart` | orphan |
| `features/prohibited_item_report/presentation/prohibited_item_report_screen.dart` | orphan |
| `features/biometric_login/presentation/biometric_prompt_screen.dart` | orphan (live lock is `biometric_auth/…/biometric_lock_screen.dart`) |
| `features/settings/presentation/screens/saved_addresses_screen.dart` | orphan duplicate of `location/…/saved_locations_screen.dart` |

All 14 are imported **only** by `lib/devtool/catalog/entries/batch_*.dart` (the widget-catalog harness)
or by nothing at all. **Do not migrate any of them.**

> **False positive to avoid:** `features/onboarding/presentation/onboarding_screen.dart` looks dead to
> an import-only walk (its sole `import` is from `batch_08_entries.dart`) but is **live** — the router
> reaches it through the `export` shim at `features/onboarding/onboarding_screen.dart`. It is screen
> `01` and must be migrated. See §5.

### 2d. Why 86 files ≠ 71 screens ≠ 62 routes

Four independent reasons, all verified:

1. **Dead code (86 → 71).** 14 files are devtool-only or orphaned; 1 is a re-export shim.
2. **Tabs are not routes.** `ShellScreen` (route `/`) hosts 5 tabs — `requests` (`HomeTab` →
   `ClientHomeScreen`), `delivery` (`OrdersTab` → `OrderHistoryScreen`), `dashboard` (`DashboardTab`
   → `JeeberHomeScreen`), `earnings` (`EarningsTab` → `EarningsDashboardScreen`), `profile`
   (`CustomerProfileScreen`). Five major screens, zero routes. *(A sixth file,
   `shell/tabs/chat_tab.dart`, declares `ChatTab` and is mounted nowhere — self-references only.)*
3. **Screens composed inside screens, not routed.** `OtpVerificationScreen` is mounted by
   `registration_screen.dart:194`, not by a route. `VoiceRecordingScreen` is mounted by
   `voice_request_screen.dart:26`. `ChatScreen` is mounted by `chat_detail_screen.dart:1722`.
4. **Routes without their own screen.** `/settings` has 5 child routes; several routes point at the
   same widget (`reviews-list` and `reviews-list-by-id`), and gate routes (`/lock`,
   `/account-status`) are redirect targets.

---

## 3. Coverage matrix

**24 designed screens → 25 production files.** `08` folds into `07`'s file; `09` and `21` each span two.

| # | Designed screen | Production file(s) | Note |
|---|---|---|---|
| 01 | Onboarding | `onboarding/presentation/onboarding_screen.dart` (547) | via export shim; holds W1–W3 |
| 02 | Registration | `registration/presentation/registration_screen.dart` (602) | |
| 03 | OTP verify | `registration/presentation/otp_verification_screen.dart` (409) | not routed; mounted by 02 |
| 04 | Client home | `home_client/presentation/client_home_screen.dart` (514) | shell `requests` tab |
| 05 | Voice recording | `voice_request/presentation/voice_recording_screen.dart` (692) | mounted by `voice_request_screen.dart` |
| 06 | Transcription review | `transcription/presentation/transcription_screen.dart` (262) | |
| 07 | Request type | `request_type/presentation/request_type_screen.dart` (391) | **also carries 08** |
| 08 | Tier catalog | *(same file as 07)* | ⚠ **§3a** |
| 09 | Location picker | `location/presentation/client_location_screen.dart` (1155) **+** `location/presentation/capture_location_screen.dart` (142) | ⚠ **§3b** |
| 10 | Request summary | `request_summary/presentation/request_summary_screen.dart` (150) | |
| 11 | Offers | `client_offers/presentation/client_offers_screen.dart` (512) | carries E2 |
| 12 | Live tracking | `live_tracking/presentation/live_tracking_screen.dart` (677) | |
| 13 | OTP handover | `otp_handover/presentation/otp_handover_screen.dart` (589) | |
| 14 | Receipt confirm | `delivery_receipt/presentation/delivery_receipt_screen.dart` (381) | |
| 15 | Mutual rating | `rating/presentation/mutual_rating_screen.dart` (352) | |
| 16 | Jeeber home | `jeeber_home/presentation/jeeber_home_screen.dart` (603) | shell `dashboard` tab; carries E3 |
| 17 | Offer composer | `offers/presentation/offer_submission_screen.dart` (841) | |
| 18 | Active delivery Jeeber | `active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart` (754) | |
| 19 | Earnings | `earnings/presentation/earnings_dashboard_screen.dart` (580) | shell `earnings` tab |
| 20 | Settings | `settings/presentation/screens/settings_screen.dart` (511) | ⚠ **§3c** |
| 21 | Order chat | `deep_link_targets/chat_detail_screen.dart` (1795) **+** `chat/presentation/chat_screen.dart` (1105) | the `/chat/:id` container + the thread |
| 22 | Become a Jeeber | `kyc/presentation/kyc_wizard_screen.dart` (302) | |
| 23 | Wallet | `wallet/presentation/wallet_hub_screen.dart` (543) | |
| 24 | Order history | `order_history/presentation/order_history_screen.dart` (348) | shell `delivery` tab; carries E4 |

### Three corrections to `screen-repo-map.md`

The existing map points three entries at files that are **not what the app runs**.

#### 3a. `08 Tier catalog` → the mapped file is dead code

Map says `tier_selection/presentation/tier_selection_screen.dart` (369 LOC). That file's only importer
is `devtool/catalog/entries/batch_11_entries.dart`. `app_router.dart:1088-1092`:

> `The legacy /tier-selection route (TierSelectionScreen) was removed here per the in-code CTO note: it
> was a dead duplicate of /request-type with an unwired onConfirmed. The create flow now standardizes
> on /request-type. TierSelectionScreen itself is kept for its widget tests.`

The live tier picker is inside `request_type_screen.dart`, which imports `TierSelectionCubit`,
`TierSelectionState`, `TierRepository`, `Tier` and renders `request_tier_card.dart`.

**Decision required:** the design draws `08` as a full standalone screen with a price-level meter, SLA
chip and vehicle class per card. The app has no standalone tier screen. Either (a) render the enhanced
catalog as a section of `/request-type`, or (b) re-introduce a route. **(a) is recommended** — (b)
resurrects a surface a prior CTO note deliberately deleted. Either way, do **not** edit
`tier_selection_screen.dart`; it is not on screen.

#### 3b. `09 Location picker` → the mapped file is a "coming soon" placeholder

There are **two** files named `location_picker_screen.dart` and **neither** is the real screen:

| File | LOC | Reality |
|---|---|---|
| `location/presentation/location_picker_screen.dart` | 461 | devtool-only; no production importer |
| `location/presentation/screens/location_picker_screen.dart` | **36** | mounted at `/location`, but is a placeholder: `OmdsEmptyStatePage` + `Icons.construction_outlined`, `'Location Picker coming soon. This screen is not yet available.'`, tagged `// ORPHAN (JEBV4-227, verified 2026-07-12): placeholder mounted at /location; zero callsites` |

The map points at the first (dead). The designer's own note confirms the real target: *"the shipped
picker is a form with the map behind a button"* — that is `client_location_screen.dart` (1155 LOC,
`/client-location`), whose "map behind a button" is `capture_location_screen.dart` (142 LOC,
`/capture-location`, reached via `location_select_new_location_cta` → `location-map-pin`).

**So `09` collapses two live screens into one map-first screen.** That is the single largest structural
change on the board and the only one that alters navigation. Route `/location` and both
`location_picker_screen.dart` files should be left alone (or deleted separately).

#### 3c. `20 Settings` → correct, but there are two settings screens

The map's `settings/presentation/screens/settings_screen.dart` (511 LOC) **is** right — it is what
users reach, mounted by `shell/tabs/profile_tab.dart`. But route `/settings` mounts a *different*
widget, `live_settings_screen.dart` (228 LOC), itself tagged `ORPHAN (JEBV4-227)` — nothing navigates
to it. Migrate `settings_screen.dart`; do not be misled by the route.

### 3d. The 46 surfaces the board is SILENT about — the real finding

71 production screens − 25 covered = **46 untouched**. These keep today's styling while 25 screens get
the new language, so the app will read as two products. Grouped by risk:

**Tier 1 — high traffic, on the main journey, will look broken next to redesigned neighbours (11)**

| Screen | LOC | Reached from |
|---|---|---|
| `deep_link_targets/delivery_detail_screen.dart` | 697 | `/orders/:id` — the order detail hub, sits between redesigned `24 Order history` and `12 Live tracking` |
| `escalate/presentation/escalate_screen.dart` | 739 | `order_chat_open_dispute` — opened **from** redesigned `21 Order chat` |
| `no_offer_timeout/presentation/no_offer_timeout_screen.dart` | 567 | `/requests/:id/waiting` — the state right before redesigned `11 Offers` |
| `cancellation/presentation/cancellation_screen.dart` | 317 | `/orders/:id/cancel` |
| `order_summary/presentation/order_summary_screen.dart` | 152 | `order_chat_view_summary_link` from `21` |
| `jeeber_request_detail/…/jeeber_request_detail_screen.dart` | 258 | between redesigned `16 Jeeber home` and `17 Offer composer` |
| `customer_profile/presentation/customer_profile_screen.dart` | 193 | shell **profile tab** — a top-level tab, 4 of 5 tabs are redesigned |
| `shell/shell_screen.dart` | 474 | the tab bar itself — **frames all 5 tabs** |
| `notifications/presentation/notifications_list_screen.dart` | 326 | header bell on every shell tab |
| `rating/presentation/rating_screen.dart` | 308 | `/orders/:id/feedback` — sibling of redesigned `15 Mutual rating` |
| `delivery_man_profile/presentation/delivery_man_profile_screen.dart` | 150 | tapped from redesigned `11 Offers` |

`shell_screen.dart` is the sharpest risk: it is the chrome around every redesigned screen. If the
board's navigation styling is not applied there, all 24 screens sit in an old-looking frame.

**Tier 2 — wallet / earnings money surfaces (6).** `23 Wallet` is redesigned but its whole subtree is
not: `wallet_activity_list_screen.dart` (392), `transaction_detail_screen.dart` (388),
`wallet_charge_info_screen.dart` (194), `customer_wallet_stub_screen.dart` (123),
`settlement_screen.dart` (291) + `settlement_detail_screen.dart` (165). Same for `19 Earnings`.

**Tier 3 — Jeeber onboarding / KYC funnel (6).** `22 Become a Jeeber` is redesigned but its funnel is
not: `dm_onboarding_screen.dart` (258), `onboarding_funding_screen.dart` (202),
`offer_kyc_gate_screen.dart` (260), `delivery_register_prompt_screen.dart` (96),
`kyc_rejected_screen.dart` (222), `account_status_screen.dart` (205).

**Tier 4 — settings subtree (7).** `20 Settings` is redesigned; its children are not:
`profile_edit_screen.dart` (293), `notification_prefs_screen.dart` (324),
`notification_preferences_screen.dart` (31), `password_security_screen.dart` (317),
`language_settings_screen.dart` (130), `saved_locations_screen.dart` (593),
`address_detail_form_screen.dart` (493).

**Tier 5 — auth / support / edge (16).** `support_ticket_screen.dart` (616),
`reviews_list_screen.dart` (563), `dispute_status_screen.dart` (423),
`display_name_setup_screen.dart` (276), `set_password_screen.dart` (244),
`biometric_lock_screen.dart` (141), `jeeber_pending_offers_screen.dart` (175),
`live_settings_screen.dart` (228), `diagnostics_screen.dart` (353),
`jeeber_request_unavailable_screen.dart` (62), `request_summary_unavailable_screen.dart` (29),
`profile_unavailable_screen.dart` (30), `rating_prompt_screen.dart` (46),
`location_picker_screen.dart` placeholder (36), `dev_chat_preview_screen.dart` (148, debug-gated),
`voice_request_screen.dart` (28, thin wrapper for `05`).

*Tiers verified to partition the 46 exactly: 11 + 6 + 6 + 7 + 16 = 46, none unassigned, none double-counted.*

> **Consistency debt.** Tiers 2–4 are *children of redesigned parents* — 19 screens the user reaches
> by one tap from a new-looking screen. They are the cheapest high-value follow-up wave. **Nine** of
> the 46 are already tagged `ORPHAN (JEBV4-227, verified 2026-07-12)` — `diagnostics_screen`,
> `rating_prompt_screen`, `jeeber_pending_offers_screen`, `screens/location_picker_screen`,
> `reviews_list_screen`, `live_settings_screen`, `profile_edit_screen`, `settlement_screen`,
> `settlement_detail_screen` — and are candidates for deletion rather than restyling.

---

## 4. Designed surfaces with no current screen

**In-scope board: zero.** All 24 designed screens have a real, substantial implementation — verified by
opening every mapped file (all present, 150–1795 LOC). **This migration creates no new screen files.**

Two designed surfaces need a *structural* decision, not a new file:

| Designed | Situation | Verified by |
|---|---|---|
| `08 Tier catalog` | Drawn standalone; live app has no standalone tier screen (it is a section of `/request-type`). A 369-LOC `tier_selection_screen.dart` exists but is unmounted dead code. | `app_router.dart:1088-1092`; only importer is `batch_11_entries.dart` |
| `09 Location picker` | Drawn as one map-first screen; live app splits it across `/client-location` (form) + `/capture-location` (map pin). The route literally named `/location` is a "coming soon" placeholder. | `location/presentation/screens/location_picker_screen.dart:1-30`; `app_router.dart:968-971`, `:1123-1132` |

**Out-of-scope board, flagged for the owner:** `Jeeb Rich UI` `L1 Log in` and `L2 Sign up` have **no**
current screen file — and must not be built. Verified absent: no `/login`, `/sign-up`, `/signup` or
`/recover` route exists, and no login/signup screen file exists. `app_router.dart:753-758` records why:

> `The hidden email/password auth funnel (/login, /sign-up, /recover, /recover/verify) was REMOVED in
> JEBV4-199 (Q-044 RATIFIED): the only end-user auth surfaces are phone-OTP (/register, above) +
> Apple/Google social (offered on it).`

Building `L1`/`L2` would resurrect a ratified deletion. They are correctly absent from the in-scope board.

---

## 5. Method

Every number was produced by command, not estimate.

| Claim | Command |
|---|---|
| Board frame counts | `grep -o 'data-screen-label="[^"]*"' <board> \| sort -u \| wc -l` |
| Figcaption reconciliation | Python regex over `<figure>`/`<figcaption>` pairs, flagging figures with no label |
| Rich UI set difference | Python set difference on normalized captions → `{Tier catalog}` |
| App screen files | `find lib -name '*_screen.dart' -o -name '*_page.dart'` → 86 |
| Production reachability | transitive `import` **+** `export` walk from `lib/main.dart`, `lib/devtool/` excluded → 659 files, 71 screens |
| Route count | `GoRoute(` occurrences minus 3 non-declarations; cross-checked against 62 unique `name:` and 60 `path:` literals + 2 constants |
| Dead-code claims | per-class `grep -rn` across `lib/`, comment-only lines discarded, then confirmed by import path |

**One trap worth recording:** class-name grep is not sufficient here. `LocationPickerScreen` and
`OnboardingScreen` are each declared in **two** files, so a name-based search reports the dead copy as
live. Both duplicates must be resolved by *import path*. Symmetrically, an import-only graph walk marks
the real `OnboardingScreen` dead because the router reaches it through an `export` shim. Only an
import+export walk keyed on file paths gives the right answer.
