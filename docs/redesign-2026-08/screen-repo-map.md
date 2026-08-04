# Screen → repo file map (CORRECTED 2026-08-03)

> ⚠️ **READ THIS BEFORE YOU EDIT ANYTHING.** The original map shipped in the design package
> (`github.md`) points **three** of its 24 entries at files the app does not run — dead code, a
> devtool-only copy, and a "coming soon" placeholder. Those errors were propagated into the
> per-screen agent prompts. **The file path in your prompt may be wrong. This table wins.**
>
> Verified by transitive import+export walk from `lib/main.dart` (devtool excluded) → 659 reachable
> files / 71 production screens. Full derivation in `01-SCREEN-COUNT.md` §3.

## The four corrections

| # | Screen | ❌ Prompt / `github.md` says | ✅ Actually edit | Evidence |
|---|---|---|---|---|
| **08** | Tier catalog | `tier_selection/presentation/tier_selection_screen.dart` (369) — **DEAD**, only importer is `devtool/catalog/entries/batch_11_entries.dart` | **`request_type/presentation/request_type_screen.dart`** — the live tier picker is a section of it | `app_router.dart:1088-1092`: the legacy `/tier-selection` route "was a dead duplicate of /request-type"; "The create flow now standardizes on /request-type" |
| **09** | Location picker | `location/presentation/location_picker_screen.dart` (461) — **devtool-only, no production importer** | **`location/presentation/client_location_screen.dart`** (1155, `/client-location`) **+** **`location/presentation/capture_location_screen.dart`** (142, `/capture-location`) | There are **two** files with that name; the one mounted at `/location` is 36 LOC of `OmdsEmptyStatePage` + "Location Picker coming soon", tagged `// ORPHAN (JEBV4-227)` |
| **21** | Order chat | `chat/presentation/chat_screen.dart` (1105) alone | **`deep_link_targets/chat_detail_screen.dart`** (1795, the `/chat/:id` container) **+** `chat/presentation/chat_screen.dart` (the thread) | The container is what the route mounts; the pinned header lives with it |
| **20** | Settings | `settings/presentation/screens/settings_screen.dart` (511) — **this is correct** | same — but **do not** be misled by route `/settings`, which mounts a *different* widget, `live_settings_screen.dart` (228), itself tagged `ORPHAN (JEBV4-227)` with nothing navigating to it | mounted by `shell/tabs/profile_tab.dart` |

**Rule of thumb that would have caught all of these:** before editing, confirm the file is reachable
from `lib/main.dart`. A class name is not enough — `LocationPickerScreen` and `OnboardingScreen` are
each declared in **two** files, so a name-based grep finds the dead copy first.

## Structural decisions (not new files)

**Zero new screen files are needed.** All 24 designed screens have a real implementation
(150–1795 LOC, every one verified present).

- **08 Tier catalog** is drawn standalone, but the app has no standalone tier screen.
  **Recommended: render the enhanced catalog as a section of `/request-type`** rather than
  re-introducing a route a prior CTO note deliberately deleted.
- **09 Location picker** is drawn as one map-first screen; the app splits it across
  `/client-location` (form) + `/capture-location` (map pin). This is **the only board change that
  alters navigation** — treat it as the highest-risk item on the board.

## ⛔ Do not build

`Jeeb Rich UI`'s **L1 Log in** and **L2 Sign up** have no current screen file and **must not be
created**. `app_router.dart:753-758`: the email/password funnel (`/login`, `/sign-up`, `/recover`)
was **REMOVED in JEBV4-199 (Q-044 RATIFIED)**; the only end-user auth is phone-OTP + Apple/Google
social. Building them would resurrect a ratified deletion. They are correctly absent from the
in-scope board.

---

## Canonical map — 24 designed screens → 25 production files

| # | Designed screen | Production file(s) |
|---|---|---|
| 01 | Onboarding | `onboarding/presentation/onboarding_screen.dart` |
| 02 | Registration | `registration/presentation/registration_screen.dart` |
| 03 | OTP verify | `registration/presentation/otp_verification_screen.dart` *(not routed; mounted by 02)* |
| 04 | Client home | `home_client/presentation/client_home_screen.dart` |
| 05 | Voice recording | `voice_request/presentation/voice_recording_screen.dart` |
| 06 | Transcription review | `transcription/presentation/transcription_screen.dart` |
| 07 | Request type | `request_type/presentation/request_type_screen.dart` |
| **08** | **Tier catalog** | ***same file as 07*** |
| **09** | **Location picker** | **`location/presentation/client_location_screen.dart` + `location/presentation/capture_location_screen.dart`** |
| 10 | Request summary | `request_summary/presentation/request_summary_screen.dart` |
| 11 | Offers | `client_offers/presentation/client_offers_screen.dart` |
| 12 | Live tracking | `live_tracking/presentation/live_tracking_screen.dart` |
| 13 | OTP handover | `otp_handover/presentation/otp_handover_screen.dart` |
| 14 | Receipt confirm | `delivery_receipt/presentation/delivery_receipt_screen.dart` |
| 15 | Mutual rating | `rating/presentation/mutual_rating_screen.dart` |
| 16 | Jeeber home | `jeeber_home/presentation/jeeber_home_screen.dart` |
| 17 | Offer composer | `offers/presentation/offer_submission_screen.dart` |
| 18 | Active delivery Jeeber | `active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart` |
| 19 | Earnings | `earnings/presentation/earnings_dashboard_screen.dart` |
| 20 | Settings | `settings/presentation/screens/settings_screen.dart` |
| **21** | **Order chat** | **`deep_link_targets/chat_detail_screen.dart` + `chat/presentation/chat_screen.dart`** |
| 22 | Become a Jeeber | `kyc/presentation/kyc_wizard_screen.dart` |
| 23 | Wallet | `wallet/presentation/wallet_hub_screen.dart` |
| 24 | Order history | `order_history/presentation/order_history_screen.dart` |

All paths relative to `lib/features/` unless noted.

---

## ⚠️ The 46 surfaces the board is silent about

71 production screens − 25 covered = **46 untouched**. They keep today's styling while 25 get the new
language, so **the app will read as two products**. Eleven are Tier 1 — high traffic, on the main
journey, directly adjacent to a redesigned screen:

`deep_link_targets/delivery_detail_screen.dart` (697, `/orders/:id` — sits *between* redesigned 24 and
12) · `escalate/…/escalate_screen.dart` (739 — opened *from* redesigned 21) ·
`no_offer_timeout/…` (567 — the state right *before* redesigned 11) · `cancellation/…` (317) ·
`order_summary/…` (152 — reached from 21) · `jeeber_request_detail/…` (258 — between redesigned 16
and 17) · `customer_profile/…` (193 — a top-level tab, while 4 of 5 tabs get redesigned) ·
**`shell/shell_screen.dart` (474 — the tab bar that frames all five tabs)** ·
`notifications/…/notifications_list_screen.dart` (326 — the header bell on every tab).

This is **not** in scope and must not be silently expanded into. It is the top item for the owner's
follow-up decision. See `01-SCREEN-COUNT.md` §3d for the full 46.
