# 13 — Design vs Implementation: honest reconciliation

Date: 2026-08-03. Input: 24 per-screen audits (design frame vs catalog capture vs source).
This document triages those audits: spot-checks them, extracts the cross-screen patterns,
ranks what survives by user impact, and separates real defects from ambiguities and
documented refusals. **It does not round up.** The previous reporting oversold fidelity;
this document also does not round *down* — several "defects" were auditor error and are
dropped below, with reasons.

---

## 0. Triage: what was spot-checked, what was dropped

Spot-checked directly (design PNG + capture + cited `file:line`):

| Check | Result |
|---|---|
| 03 extra "Verify" CTA — `otp_verification_screen.dart:273` | **Confirmed.** Pill exists in capture and code; board draws a bare spacer. |
| 10 whole-ticket ErrorBox — `request_ticket.dart:95` | **Confirmed.** `context.canPop()` in build; all 3 captures are a red RenderErrorBox. |
| 04 replies card dual CTA — `replies_card.dart:207-238` | **Confirmed.** "Accept" + "Check Offers"; board draws one "View offers" pill. |
| 07 wrong row component + badge on Flash — `request_type_screen.dart:269`, `tier_repository.dart:64,133` | **Confirmed.** Design frame shows compact radio rows, badge on **Standard**, red pin, two-line "Deliver to". Shipped screen renders 08's catalog rows, badge on **Flash**, navy pin, address-less card. |
| 01 copy strings — `app_en.arb:578,582` | **Confirmed.** "Voice-first deliveries" / "Tap to talk…" verbatim in ARB. |
| 09 saved-addresses crash — capture + `saved_locations_screen.dart:57` | **Confirmed** as a crash *in the capture set* (solid ErrorWidget). Root cause not isolated by the auditor; the screen self-resolves a repository via DI (`_resolveRepository`), which the bare catalog harness does not bootstrap — most likely a harness-only throw, **but `/settings/addresses` mounts this widget in production, so it must be re-run with the exception visible before it can be closed as harness.** |
| Font stack — `pubspec.yaml:312-322`, `jeeb_text_styles.dart:217`, `grep fontFamilyFallback lib/` | **Confirmed.** Inter 400–700 only, family hard-pinned, zero fallback declarations in `lib/`. |
| Capture harness fonts — `test/tools/catalog_capture_test.dart:42`, `test/support/load_test_fonts.dart` | **Confirmed.** Harness loads Inter + MaterialIcons + a subset Noto Arabic golden face. **No emoji font.** |

Every cited `file:line` I opened was accurate. The auditors cited honestly. Two classes of
finding do **not** hold up as charged and are reclassified:

**Dropped / downgraded:**

1. **Emoji tofu as an app defect** (charged as *major* on 01, 04, 12; *minor* on 02-flag).
   The harness loads no emoji face, so tofu in captures is expected there. On a real device
   the Flutter engine falls back to the platform emoji font (Apple Color Emoji / Noto Color
   Emoji) even when `fontFamily` is pinned. The auditors on 07, 08, 16, 23, 24 reached this
   conclusion themselves; the auditors on 01, 04, 12 charged the same symptom as a code bug.
   **Reclassified: unverified-on-device, almost certainly harness.** Action kept (cheap
   insurance): add an explicit `fontFamilyFallback` and take **one on-device screenshot** of
   any tier chip to close the question for all screens at once. Until that screenshot
   exists, the entire ⚡🚀🟦🤝🌿 lexicon is *unverified*, not *broken*.
2. **The "dropped ج" in Arabic runs** (01, 02). A font fallback never deletes letters; the
   subset golden Arabic face in the harness is the likely culprit. Reclassified: harness.
   The *underlying* real defect stands and is Pattern C below: the board's Arabic display
   face (`--font-arabic`, Baloo Bhaijaan 2) is not bundled at all, so on device Arabic
   renders in the platform naskh, never in the brand face — that part is code-verified.
3. **10-request-summary "unrecognisable"** — wrong verdict word. The screen did not render
   *at all* in the harness (GoRouter assert). It is **unverified**, not unrecognisable; no
   evidence exists either way about its fidelity. The two required actions are real (see P0).
4. **15 tag order "flex-wrap artefact" rationale** — the auditor is right that the in-code
   justification is wrong (flex-wrap preserves source order), kept as minor.

---

## 1. Verdict table (adjusted, per screen)

"Structure" = bands, geometry, tokens, chrome. "Content" = the facts/copy the board draws.

| Screen | Verdict | One-line truth |
|---|---|---|
| 01-onboarding | **Close** | Layout faithful; slide-1 headline+body are different (weaker) copy; ink swap on Skip/body; no Arabic brand face. |
| 02-registration | **Close** | Structure right; social pills clip to two identical "Continue with" labels; box-in-a-box phone field; warm/cool inks swapped. |
| 03-otp-verify | **Close** | Faithful except a large unspecified Verify pill in the board's empty band and brown-for-periwinkle inks. |
| 04-client-home | **Close in layout, off-spec in promises** | Hero promises tap not hold; replies card splits the single CTA in two; waveform/reach/"Broadcasting" — the designed liveness — all absent. |
| 05-voice-recording | **Diverged** (downgraded from "close") | The entire LIVE TRANSCRIPT band — the top ~70% of the frame — is empty; waveform is a non-spec Lottie profile. Two matches don't offset a missing screen-half. |
| 06-transcription-review | **Close, minus its reason to exist** | Structure faithful, but the low-confidence orange underline — the screen's headline feature — is not rendered. |
| 07-request-type | **Diverged** (confirmed) | Renders screen 08's comparison-table row instead of 07's compact radio row; badge on the wrong tier; no destination. |
| 08-tier-catalog | **Close** (as absorbed into 07) | Catalog anatomy itself is faithful; no pre-selection; 08's own title/CTA ship nowhere (route deleted, documented). |
| 09-location-picker | **Diverged — worst screen** | The map never ships on the production route; `/location` still mounts the pre-redesign Material picker; no search anywhere; lat/long instead of an address. |
| 10-request-summary | **UNVERIFIED** | All captures are a harness crash (`canPop` without a router). Zero rendered evidence for or against the ticket. |
| 11-offers | **Close** | Cards right; title/ETA copy off-register; distance replaced by vehicle; layout starves the name column. |
| 12-live-tracking | **Close** | Header denser than board; courier card missing rating + call circle (policy never reconciled); map itself unverifiable in harness. |
| 13-otp-handover | **Close** | Faithful except an added filled "Rate your Jeeber" CTA that outweighs the board's dispute pill; arrival banner unverified (fixture). |
| 14-receipt-confirm | **Close** | Faithful; money emphasis is flat (w800 face missing + no size step); proof timestamp blocked on gateway. |
| 15-mutual-rating | **Close, with a dead feature** | The personalised headline/avatar/blind-note is dead code on every production path — no caller passes the name. |
| 16-jeeber-home | **Close in shell, missing its headline features** | No auto-offline timer/zone/Extend, no rating pill, no waveform, no cash-due; plus two unspecified bands added. |
| 17-offer-composer | **Close** | Money math implemented but never visually verified (fixture gap); 4-pill ETA row vs board's 3; no default ETA. |
| 18-active-delivery-jeeber | **Close** | Third "Costs" pill dead behind an unwired callback; fee/goods split missing (gateway gap); 5-segment stepper vs board's 4. |
| 19-earnings | **Close** | Rating replaced by join date in the hero; rows have no tier and are looser; copy drift. |
| 20-settings | **Close** | Extra MORE band kills the board's empty band and slices a row at the fold; two notification labels off-board. |
| 21-order-chat | **Close, with one loud divergence** | An off-palette green banner band replaces the quiet timeline chip; send-not-mic is a documented refusal; pinned strip shows ref+bare price instead of item+cash. |
| 22-become-a-jeeber | **Close** | Contract-required ID band splits the board's 3-row checklist and pushes the selfie below the fold; encryption promise dropped (legal hold). |
| 23-wallet | **Close** | Faithful; reserved-count and "included" clauses missing; success-note and pill tints off-token. |
| 24-order-history | **Structurally close, informationally divergent** | Rows are the right shape carrying the wrong facts: no item title, no Jeeber name/rating, no ETA, no Re-broadcast. |

**Overall:** roughly **19 of 24 screens are genuinely close** in structure, tokens and
geometry — the redesign's visual system did ship. But **07, 09 and 05 are not the board**,
**10 is unproven**, and across nearly every close screen the *designed content* — the
waveform marks, reach counts, ratings, names, timestamps, fee splits, ETAs that the
designer's notes call the "enhancements" — **did not ship**, mostly because the wire
contract has no fields for them. The app looks like the board and informs like the old app.

---

## 2. Cross-screen patterns (fix once, fix everywhere)

### Pattern A — The wire contract can't carry the board's facts (≈20 majors across 12 screens)
The single biggest bucket. The board's per-screen "enhancements" nearly all require fields
the gateway doesn't send; the code consistently (and honestly) ships `TODO(redesign-24):
omitted, not faked` instead. Individually these read as per-screen defects; together they
are **one backend contract workstream**:

| Missing field(s) | Blocks | Where |
|---|---|---|
| voice note flag/duration on request rows | 04 waveform+duration, 16 waveform | `pending_requests_tab.dart:221`, `jeeber_feed_tab_view.dart:782` |
| broadcast reach count | 04 "12 Jeebers reached" | `pending_requests_tab.dart:252` |
| offer distance (km) | 11 "3 km away" | `offer_card.dart:437` |
| courier rating + masked phone | 12 ★ run + call circle | `tracking_courier_card.dart:67` |
| proof capture timestamp | 14 "Proof of delivery · 9:38" | `proof_photo_hero.dart:99` |
| counterpart display name on rate route | 15 "How was Karim?" + blind note | 3 route builders, see P1 |
| goods-cost split | 18 "collect $8 + $6.50 goods" | `active_delivery_jeeber_screen.dart:619` |
| tier + item name on earnings rows | 19 row anchor + title | `earnings_summary.dart:17` |
| item description, jeeberName, rating, ETA on `GET /v1/requests` | 24 all four row facts | `order_summary.dart:96` |
| reverse-geocode + geocode-search | 09 address card + search field | `capture_picker_sheet.dart:152` |
| reply latency + presence | 21 header subtitle + dot | `chat_app_bar.dart:96,111` |
| live-reserve count | 23 "1 live offer ·" | `wallet_repository.dart` |
| period-scoped rating | 19 hero stat #3 | `earnings_dashboard_screen.dart:429` |

**Action:** raise these as ONE gateway contract request with this table attached. Until it
lands, the redesign is visually done and functionally half-delivered — that sentence
belongs in any status report.

### Pattern B — Muted ink: periwinkle #777FC0 replaced by warm brown #5C4038 everywhere
`onSurfaceVariant` is mapped to `_jeebSubtitle = 0xFF5C4038` (`app_theme.dart:19,73`) and a
contrast test guards it, because the board's periwinkle fails AA (~4.0:1) on white. Result:
on **01, 02, 03, 06, 12, 13, 21, 24** (at least) the board's cool secondary voice reads
warm brown, and screens that mix the two (13, 12) show two unrelated muted hues side by
side. The AA concern is legitimate; the wholesale hue-family swap was never ratified.
**Action (one decision, ~8 screens):** mint an AA-passing *darkened periwinkle* role
(≈#5A61A0) in `jeeb_semantic_colors.dart`, point the muted-text call sites at it, keep the
contrast test. Get the designer to sign the new value.

### Pattern C — Font stack: the board's typography never fully shipped
Code-verified: `pubspec.yaml` bundles Inter 400/500/600/700 **only**; `jeeb_text_styles.dart:217`
hard-pins `Inter` on every ramp entry; no `fontFamilyFallback` exists in `lib/`.
Consequences:
1. **No Arabic brand face** (real, all screens with Arabic: 01, 02, 20, 21): the board's
   `--font-arabic` (Baloo Bhaijaan 2) never renders; Arabic falls to platform naskh. The
   bilingual tagline, the عربي toggle segment and the Arabic quick-reply all lose the
   board's weight/character. *Severity of the capture evidence is harness-tainted (subset
   golden font), but the missing face is a fact.*
2. **No w800 face** (14): `FontWeight.w800` resolves to Bold, so the cash-amount emphasis
   is literally zero — combined with the missing size step at
   `delivery_receipt_screen.dart:507`.
3. **Ramp runs one step under the board** (01, 03, 06, 08, 14, 17): h1 is 24 where boards
   draw 25–27; body 13.5 vs 14.5–15; and the boards' negative tracking (−0.5/−0.6) is
   nowhere in the ramp (`_h1`, `jeeb_text_styles.dart:237`). Individually cosmetic;
   collectively the whole app sets tighter and smaller than the board.
4. **Emoji fallback undeclared** — see triage: probably fine on device, unverified.
**Action:** bundle the Arabic face + Inter-ExtraBold, add `fontFamilyFallback` (Arabic face,
platform emoji) to the ramp, and make one ruling on h1/body sizes + tracking — then every
affected screen moves at once.

### Pattern D — UI added for frozen test identifiers / seams, not for users
A recurring shape: a Maestro/semantics identifier or product seam is frozen, so a visible
control the board never drew is shipped to host it: 03's Verify pill
(`phone_otp_verify_cta`), 19's "See all" link (`earnings_activity_link`), 04's inline
Accept (`replies_accept_cta`), 13's "Rate your Jeeber" primary, 16's Ignore button and
Replies chip, 21's expand chevron. The 19 auditor named it: *the tail wagging the dog*.
**Action:** rule once that frozen identifiers may be re-homed onto board-drawn elements or
zero-size semantics nodes; then delete the added chrome in one sweep.

### Pattern E — Shared-kit metrics one size class off the board
`jeeb_select_chip.dart` roles (`filter` 11/20@14.5, `inlineAction` 9/18@13) are larger than
the boards' measured 9/18@13 and 8/15@12 — inflating chips/pills on **04, 06, 11, 15, 24**.
`JeebListRow` default 16/14 padding vs 14/11 (19). 48dp *layout* min-heights instead of
hit-test expansion pull identity blocks apart (11 name/meta at `offer_card.dart:613`) and
float links (23 fee link, `jeeb_cta_button.dart:170`). `OmdsSettingsSwitchRow` inherits the
56px ListTile minimum (20). **Action:** fix in the kit with per-board verification, not per
screen.

### Pattern F — Copy drift against board literals (~25 strings)
Same voice failure repeating: corporate register where the board is neighbourly
("Voice-first deliveries", "ETA", "En route", "Searching for Jeebers…", "Choose a Jeeber",
"Track order", "Total cash earned"), Title Case where the DS mandates sentence case
("Active Delivery", "In Transit", "At Door", "Pin Location", "Current Location"), and
weaker trust claims (01 body, 22 encryption clause, 23 "included"). **Action:** a single
ARB pass against the board strings — cheapest large win in the whole audit. (Fee wording is
excluded — see §5.)

### Pattern G — The audit's own blind spots (harness + fixture coverage)
The capture set cannot prove several of the board's most distinctive elements: 10's entire
ticket (crash), 09's map surface (no capture of `/capture-location`), 13's orange arrival
banner, 17's populated money math + CTA restatement, 10's voice replay band (no fixture
with audio), 11's amber stars (harness lacks the token provider), every emoji, every soft
shadow, 12's live map. **Action:** fix the two harness bugs (10's `standInRouter`, star
token provider), add the missing fixtures, and re-capture — otherwise the next audit
repeats these holes. Also triage the 09 saved-addresses ErrorWidget with the exception
visible: if it is not DI-bootstrap-only, it is a live crash on `/settings/addresses`.

### Pattern H — Surfaces the redesign never reached (or reached wrongly)
07 mounts 08's component; 09's production route never gets a map builder; the
pre-redesign `/location` picker is still a live named route; 05's transcript band is
absent. These four are why the app can look "redesigned" in a demo and then drop the user
into 2025-era UI mid-flow.

---

## 3. Ranked defects (survivors only, by user impact)

### P0 — the redesign is visibly not shipped here (every create-flow or core-loop user hits these)

1. **09: no map anywhere in the shipped location flow.** Production route builds
   `CaptureLocationScreen` with no `mapBuilder`/controller → grey placeholder; recentre
   disc gated off. `app_router.dart:147`. Fix: wire the same builder
   `GoogleMapPickerLauncher` already uses (`google_map_picker_launcher.dart:32-52`) once
   the Maps key (B-23/D-09b) lands. Until then screen 09 does not exist as designed.
2. **09: pre-redesign picker still routable at `/location`.** Old Material app bar, peach
   banner, GPS button. `app_router.dart:966-971`. Fix: delete the route + orphan subtree
   (`location_picker_screen.dart:129-211`) and its catalog entry
   (`batch_06_entries.dart:158`), or migrate it. This is the audit's textbook failure case.
3. **07: wrong component — renders 08's catalog row, not 07's compact radio row.**
   `request_type_screen.dart:269` → `tier_catalog_section.dart:100` uses
   `JeebTierRow.catalog`; the spec-exact `JeebTierRow.compact` exists at
   `jeeb_tier_row.dart:53`. One-line-ish fix cascades: restores radio indicators, tinted
   badge, one-line summaries; also drop the added subtitle + info-note bands
   (`tier_catalog_section.dart:52-55,66-72`) and render the five board summary sentences.
4. **07/08: "Most picked" badge on Flash (most expensive) instead of Standard.**
   `tier_repository.dart:64` (`recommended: id == TierId.flash`) and `:133`. Design frame
   verified: badge on Standard. Fix both mapper and fallback catalog. Pre-select the
   recommended tier while there (`tier_selection_cubit.dart:33`) — board loads selected.
5. **05: the LIVE TRANSCRIPT band — the screen's upper half — is missing entirely.**
   `voice_recording_screen.dart:189`. Documented as blocked on streaming STT; the board
   still specifies the band. Minimum: render the designed card in an awaiting state; real
   fix needs a partial-transcript source (Pattern A adjacent).
6. **04: hero subtitle promises the wrong gesture** ("Tap the mic…" vs board's "Hold to
   talk · or tap to type") — the redesign's signature interaction, on the highest-traffic
   screen. `app_en.arb:4793`, rationale at `client_home_request_hero.dart:28-31`. Fix:
   auto-start seam on VoiceRecordingScreen, then restore the string.
7. **04: replies card splits the single "View offers" action into Accept + "Check
   Offers".** `replies_card.dart:207-238`. Fix: one navy "View offers" pill; accept lives
   on the offer list; re-home `replies_accept_cta` (Pattern D).
8. **10: make the screen auditable and crash-proof.** (a) `standInRouter: true` in
   `batch_10_entries.dart:40-45` + re-capture; (b) harden `request_ticket.dart:95` to
   `GoRouter.maybeOf(context)?.canPop() ?? false`. Also fix the real ARB bug found by
   code-read: `'{count} photo(s) attached'` → ICU plural (`app_en.arb:1858`).
9. **09-adjacent: saved-addresses catalog states all crash** — triage with exception
   visible (`saved_locations_screen.dart:57`, catalog `batch_06_entries.dart:158-181`);
   production mounts the same widget at `/settings/addresses`.

### P1 — majors a user will notice in the first session

*Client loop*
- 04 pending copy "Searching for Jeebers…" → "Broadcasting" (`app_en.arb:3298`); waveform +
  reach + chip placement (Pattern A; `pending_requests_tab.dart:221,252,287`).
- 06 low-confidence orange underline absent — the screen's purpose
  (`transcription_text_panel.dart:134`; needs word-confidence offsets — Pattern A). Restore
  hint string with it (`app_en.arb:4805`).
- 06 injected waveform eats ~⅓ of the replay scrubber (`transcription_audio_card.dart:37-38`)
  — remove from the card row.
- 11 title "Choose a Jeeber" → "Offers" (`app_en.arb:2871`); ETA register "12 min ETA" →
  "in 40 mins" + hour rollover (`app_en.arb:2055`); vehicle shown where distance belongs
  (Pattern A); price column steals half the row so names ellipsize at the board's own
  canvas — drop the `Flexible` wrapper (`offer_card.dart:227`).
- 12 header meta: five runs, no middots, wraps to three lines — drop name+ETA runs to
  zero-size semantics, restore "·" in LTR (`order_summary_pinned_header.dart:203`).
  Courier card missing ★ + call circle (Pattern A / policy decision —
  `tracking_courier_card.dart:67`).
- 13 added filled "Rate your Jeeber" outweighs the dispute exit — demote to text action
  (`otp_handover_screen.dart:484`, Pattern D).
- 14 money emphasis flat — size-step the amount span (`delivery_receipt_screen.dart:507`)
  + bundle w800 (Pattern C).
- 15 counterpart name never plumbed → personalised headline, initial avatar and the
  specified blind-reveal sentence are dead code on all real paths. Fix at the three route
  builders (`otp_handover_screen.dart:271`, `chat_detail_screen.dart:70`,
  `delivery_detail_screen.dart:497`) or read it in `MutualRatingCubit`. Interim: reword
  `mutualRatingSubtitle` to state simultaneous reveal (`app_en.arb:703`; spec string
  unused at `:4951`).
- 21 green "Offer accepted!" banner band replaces the board's quiet timeline chip and
  introduces an off-palette green (`chat_screen.dart:759`, `offer_accepted_banner.dart:45`)
  — keep banner on the jeeber leg only. Pinned strip: item name + "cash" qualifier instead
  of `ORD-ref · $35.00` (`order_chat_pinned_summary.dart:476,512`). Header trailing action
  is dispute, board draws call (`chat_screen.dart:493` — needs phone on summary, Pattern A).
- 24 all four row facts (title, name+rating, ETA, Re-broadcast) — Pattern A; code points:
  `order_history_card.dart:162,292,314,349`.

*Jeeber loop*
- 16 availability strip: no countdown, no zone, no Extend — the screen's headline feature
  (`availability_card.dart:135,172`). Rating pill missing
  (`jeeber_home_greeting.dart:63`). Ignore button squeezes "Make offer" to "Make of…"
  (`jeeber_feed_card.dart:509`, width cap `:278`). Extra tier-filter band
  (`jeeber_feed_tab_view.dart:277`). Cash due on pinned card
  (`active_deliveries_banner.dart:318`, Pattern A).
- 17 ETA row: 4 pills incl. "Other" vs board's 3 (`offer_submission_screen.dart:398`);
  no default ETA selected (`:179`); header subtitle drops items + tier chip (`:294`,
  wiring WR-6); hardcoded English validation strings
  (`offer_submission_cubit.dart:127-132`).
- 18 "Costs" pill dead — wire `onEnterGoodsCost` in `app_router.dart:1514-1552` or get the
  two-pill board ratified (escalation was opened and never resolved). Fee/goods split
  (Pattern A). Stepper 5 segments vs board's 4 — and fix the in-code comment that misreads
  the frame (`jeeber_delivery_status.dart:12`, `delivery_status_stepper.dart:15`).
- 19 hero stat #3 join-date instead of ★ rating (`earnings_dashboard_screen.dart:429`,
  Pattern A); rows tier-less (Pattern A).
- 20 MORE band destroys the board's empty band and slices a row at the fold at rest —
  restructure per the fix in the audit (`settings_screen.dart:201`,
  `settings_more_card.dart:18`); "Offers"→"New offers" (`app_en.arb:442`, undocumented
  drift); "Security codes" vs "Door codes" — force the CF4 owner call (`app_en.arb:452`).
- 22 ID band splits the checklist and pushes the selfie below the fold — contract-required
  content, so relocate (compact row after selfie) + update the board
  (`kyc_identity_step.dart:334`); encryption clause pending legal (`app_en.arb:5069`) —
  resolve the hold, don't let it rot.
- 23 reserved-now line missing the count clause (Pattern A, `wallet_hub_l10n.dart:86`);
  "included" dropped from starter-credit pill (`:79`).

*Auth funnel*
- 02 social pills render "Continue with" twice with the provider clipped — pass short
  labels for the two-up variant (`social_sign_in_button.dart:100,143`); box-in-a-box phone
  field — neutralise theme's injected enabledBorder/fill
  (`registration_screen.dart:679-688`).
- 01 slide-1 headline + body are different, weaker copy (`app_en.arb:578,582`) — retrans-
  late AR off the fixed strings.
- 03 delete the Verify pill (or re-home the frozen id) — `otp_verification_screen.dart:266-286`.

### P2 — minors (real, lower stakes) — grouped

- **Ink/AA family (Pattern B):** 01 Skip/body swap (`onboarding_screen.dart:986,1079`),
  02 helper/"or" (`registration_screen.dart:727,528`), 03 four runs (`:340,353,413,423`),
  06 subtitle/times/hint (`transcription_screen.dart:226`), 12 door-code label (`:609`),
  13 subtitle+SMS prompt (`:422,452`), 21 incoming timestamp (`jeeb_chat_bubble.dart:345`)
  — all resolve with the darkened-periwinkle token.
- **Kit metrics (Pattern E):** 24 filter chips + inline pills (`jeeb_select_chip.dart:376,405`),
  19 row pitch (`earnings_dashboard_screen.dart:654`), 20 switch-row 57px pitch + switch
  size (`settings_notifications_card.dart:111`), 20 footer spacing (`settings_footer.dart:84`),
  11 name/meta gap (`offer_card.dart:613`), 23 fee-link float (`jeeb_cta_button.dart:170`),
  17 note-block height (`offer_submission_screen.dart:703`), 22 checkbox row ink/gutter
  (`kyc_identity_step.dart:613`).
- **Copy (Pattern F):** 04 "Pending" chip (`app_en.arb:45`); 12 "min"→"mins"
  (`live_tracking_l10n.dart:76`); 16 "Ahlan," (`app_en.arb:2830`); 16 lexicon words vs
  glyphs — 🌿"Light"/🚀"Bulk" (`jeeber_feed_card.dart:414`); 18 Title Case trio
  (`app_en.arb:3956,4000,4004`); 19 eyebrow "Cash collected"
  (`earnings_dashboard_l10n.dart:55`); 21 "Track" (`app_en.arb:4376` — fork a chat key);
  22 "Capture" (`app_en.arb:1511`); 24 "In transit" (`app_en.arb:2906` — update pinned
  tests); 24 "no offers" in the amount slot (`order_history_card.dart:180`); 17 "(cash)"
  qualifier + reserve-note shape (`offer_composer_l10n.dart:157,176`); 07/09 Title Case
  fallbacks.
- **State/structure:** 04 avatar stack all-"?" — pass initials (`replies_card.dart:270`);
  04 unread dot (`client_home_greeting.dart:78`); 04/16 extra summary line density; 08
  vehicle glyph keyed on a different table than its label
  (`tier_catalog_lexicon.dart:64` vs `:74` — single-source it); 09 saved-pills not in the
  sheet (`capture_picker_sheet.dart:78` — reuse `SavedAddressPillRow`); 12 extra distance
  strip (D-12-3 — fold into pill/card); 15 hollow vs filled inactive stars
  (`mutual_rating_screen.dart:256`); 15 tag order (`:369` — fix order, correct the wrong
  rationale comment); 16 Replies-0 chip (`jeeber_feed_tab_view.dart:581`); 20 delete-red
  token vs board red (`app_theme.dart:43` — pick one, record it); 23 success-note +
  pill tint values (`jeeb_color_roles.dart:59`, `wallet_hub_screen.dart:545`); 22
  "Scroll for selfie" pill + terms CTA (both fall out of / need board rulings with the ID
  band); 06 hint glyph info→error (`transcription_text_panel.dart:179`).

### P3 — cosmetics (fix opportunistically, or record as accepted deltas)

01 sheet radius 32→36; 01 meta "3 km"→"3km"; 02 hero gutter 24→28 + CTA 56 vs 58;
03 12px w600 hint vs 12.5 w500; 06 transcript 20→22, subtitle 13.5→14.5, quick-add pill
padding; 08 gap 8 vs 9 (declared, accept); 09 sheet radius 24 vs 28; 10 glyph
`wifi_tethering`→`sensors`, ticket ramp deltas (decide ramp-vs-frame once); 11 countdown
zero-pad (`countdown_format.dart:12`), footer period, card tint→white; 14 card metrics,
h1 25/−0.5 ruling; 12/14 money shape "$8" vs "9.00 USD"/"$9.00" — needs ONE product
ruling on money formatting (board itself is inconsistent: "$8" vs ledgers' "$8.00");
17 section-label 12.5 vs 13; 18 `Icons.map`→`Icons.directions`, pin #E02020 map-pin token
(also 07's pin — add the role once); 19 fee word order, "Month" chip, hero height;
20 phone grouping (`settings_identity_card.dart:94` — reuse the entry formatter);
23 hero height; 24 expired-row recede (dim outline/glyph, keep ink — respects the AA
refusal).

---

## 4. Genuinely ambiguous or unimplementable as drawn

These need a **designer/product ruling**, not code:

1. **Periwinkle on white fails AA** (Pattern B). The board specifies a contrast failure.
   The design must re-cut the muted token; the code's brown swap is a stopgap either way.
2. **09 step chips / "Confirm drop-off" / "Drop-off here"**: the board draws a two-leg
   pickup→drop-off flow; the shipped product writes one confirmed coordinate to both legs
   (C1/C2, D-09a open). Board and product disagree at the flow level — redraw the frame
   for a single-point leg or change the product. Coupled: CTA copy, callout copy, chips.
3. **05 live transcript**: no streaming STT source exists. The band as drawn is
   unimplementable today; decide the awaiting-state design.
4. **08 has no route** (documented dead-duplicate deletion): its title "Delivery tiers",
   CTA "Confirm tier" and "Recommended" badge word ship nowhere. Merge the two frames
   formally; also fixes the hardcoded "five speeds" subtitle vs data-driven row count.
5. **11 third-card dimming vs "every offer must stay acceptable"** (plan §7.2-C4): product
   rule contradicts the frame. Frame amendment or rule change.
6. **03 auto-verify vs manual Verify**: the board's only submit affordance is automatic;
   the test plan mandates a manual fallback. Decide whether the fallback may be invisible
   (semantics-only) — the current compromise is the worst of both.
7. **Money formatting**: the board mixes "$8", "$6.50" and ledger "$8.00"; `MoneyFormat`'s
   always-2-decimals rule was itself a deliberate consistency fix. One product ruling,
   applied everywhere (12, 14, 21, 24).
8. **13 post-handover forward path**: the board draws no way forward after verification;
   the added rating CTA answers a real gap with an unspecified element. Needs a drawn
   answer (demoted text action suggested).
9. **21 presence dot / call button**: honest rendering requires presence + phone signals
   that don't exist. Land the signals or amend the frame — the refusal reasoning is sound;
   the undecided state guarantees repeat audit failures.
10. **24 expired-row 0.65 opacity vs AA on the meta line**: designer sign-off needed
    either way.
11. **16 tier vocabulary**: the app's real tiers (light/bulk) don't map 1:1 onto the
    board's five-name lexicon; the current emoji/word mismatches are a symptom. Product
    owns the mapping table.

---

## 5. Documented refusals — NOT defects (do not relitigate)

Recorded decisions with reasons; listed so no one re-files them:

- **B-04**: no mic in the chat composer (21) — guarded by `chat_composer_no_mic_b04_test`.
  The frame still draws a mic; reconcile the *frame*, not the code.
- **D56 / D52 / D20** — stand as recorded.
- **Fee wording** ("Platform fee", 17 & 19) — recorded copy-policy ruling
  (per-screen-revised/19-earnings.md §2). The audits' "Jeeb fee" findings are noted for the
  designer's awareness only.
- **The two unwired Lottie files** (05 waveform substitution + mic-ring film) — recorded
  motion decisions; the geometry deltas flagged by the 05 audit go to the motion owner,
  not the defect list.
- **12 D-12-1/D-12-2** identifier pins and **D-12-3** deadline strip — shipped for locked
  requirements; fold-in suggestions in P2 are optional refinements.
- **20 CF2/CF3/CF5** (MORE band routes, rating-reminders row, error-token red) — real
  refusals with reasons; P1's 20-entry asks only for *restructuring* (the sliced row at
  the fold), not removal of the routes.
- **08 C7** (vehicle glyph on all rows) — an in-code override of the frame; either ratify
  it on the board or revert, but it is a recorded decision, not an accident.
- **11 §7.2-C4** (all offers acceptable) — see ambiguity #5.
- **02/03/06/13/21 AA brown-ink comments + contrast test** — deliberate and guarded;
  Pattern B proposes the reconciliation, not a revert.
- **24 no-dormant-state** AA refusal — see ambiguity #10.
- **Honest-omission TODOs** (`omitted, not faked`) across Pattern A — the *policy* is
  correct and should be kept; the gap is the gateway's.

---

## 6. Bottom line

- **The visual system shipped.** Tokens, cards, pills, navy/orange budget, band structure:
  ~19/24 screens are recognisably the board, mostly within a few px.
- **Three screens are not the board** (07 wrong component, 09 no map + live legacy route,
  05 missing top band), **one is unproven** (10), and the legacy `/location` route can drop
  users into pre-redesign UI mid-flow today.
- **The board's information layer largely did not ship.** Nearly every designer-named
  "enhancement" is missing, honestly TODO'd, and blocked on ~13 gateway fields (Pattern A).
  Fixing pixels will not close this; the contract request will.
- **Two systemic decisions** (brown-for-periwinkle, Inter-only ramp) make the whole app
  read warmer and tighter than the board; both are one-token/one-ruling fixes.
- **The audit itself has holes** (Pattern G): emoji, shadows, the map, 10's ticket, 13's
  arrival banner and 17's money math are all unverified by the current capture set. Fix
  the harness before trusting the next sweep — and before claiming *anything* about screen 10.
