# 04 · Wiring integration report

Serialized integrator pass over the 24 `docs/redesign-2026-08/wiring/<screen-id>.md` request files.
Applied on branch `feat/redesign-24-migration`. Nothing was committed, branched or pushed.

**Headline: `flutter analyze` → 0 errors** (was 119 errors before this pass). 9 issues remain, all
pre-existing test-file lint in other lanes' diffs — see §6.

---

## 0. The one structural fact every request depended on

`lib/l10n/app_localizations.dart` is **hand-authored**, not `flutter gen-l10n` output, and the repo
carries **no `l10n.yaml`**. `flutter gen-l10n` is therefore a no-op here and was NOT run — the
instruction to run it does not apply to this codebase. Every ARB key added below has a
hand-written `_get('<key>')` getter in the same pass, which is what the CI gate actually checks.

The gate (`qa/t-mob-fix-002/l10n_parity_check.sh`) is **strict in both directions**:
`S2(getters) == S3(EN keys) == S4(AR keys)`. An ARB key without a getter fails it just as hard as a
getter without a key. Orphan *getters* (declared, unused) are warn-only. This shaped several
reconciliations below.

Gate results after the pass:

| gate | result |
|---|---|
| `l10n_parity_check.sh` | **PASS** — S1 1062 / S2 1716 / S3 1716 / S4 1716; all five strict checks 0 |
| `ar_plurals_check.sh` | **PASS** — 11 plural sets, 0 missing AR CLDR forms |

---

## 1. l10n — applied

**182 new keys** in both `app_en.arb` and `app_ar.arb`, **182 new getters/methods** in
`app_localizations.dart`, plus **20 in-place value changes** (EN) / **18** (AR).

| screen | new keys | value changes |
|---|---|---|
| 01 onboarding | 9 | — |
| 02 registration | 4 | `registrationWelcome` |
| 03 otp-verify | 6 | — |
| 04 client-home | 5 | — |
| 05 voice-recording | 4 | — |
| 06 transcription-review | 12 | `transcriptionHeader` `transcriptionSubtitle` `transcriptionSubmit` `transcriptionEdit` |
| 07 request-type | 2 | `requestTypeLocationHeading` → "Deliver to" |
| 08 tier-catalog | 14 | — |
| 09 location-picker | 2 | — |
| 10 request-summary | 6 | `requestSummaryTitle` → "Review & send" (EN only; AR already read «مراجعة وإرسال») |
| 11 offers | 3 + 6 plural branches | — |
| 12 live-tracking | 7 | — |
| 13 otp-handover | 9 | `otpHandoverClientTitle` `otpClientShareInstruction` `otpClientDoNotShare` |
| 14 receipt-confirm | 4 | `receiptConfirmCta` (EN) · `receiptNotYetCta` (EN+AR) |
| 15 mutual-rating | 10 | `mutualRatingTagsLabel` `ratingCommentHint` |
| 16 jeeber-home | 8 | — |
| 17 offer-composer | 14 | — |
| 18 active-delivery-jeeber | 9 | `activeDeliveryOtpSubmit` → "Verify code & complete" |
| 19 earnings | 6 | — |
| 20 settings | 6 | — |
| 21 order-chat | 7 | — |
| 22 become-a-jeeber | 10 | `kycWizardTitle` `kycIdFrontLabel` `kycIdBackLabel` `kycSelfieStepTitle` |
| 23 wallet | 14 | `walletAvailableBalanceLabel` → "Available to bid" |
| 24 order-history | 5 | — |

Every parameterized getter's **signature was read off the real call site**, not off the request
sketch, because several requests proposed a shape the lane code did not use. Verified call sites:
`homeRepliesOffersFloor(String, String)`, `jeeberFeed{Nearby,Pending,Replies}Count(int)`,
`kycWizardProgressStepLabel({current, total, stepName})`, `kycWizardNextStepHint({stepName})`,
`kycTosAgreeLine({percent})`, `offersWindowStrip(int, String)`,
`onboardingPageIndicator(int, int)`, `orderHistoryFilterRange(String, String)`,
`settingsIdentitySubtitle({phone, action})`, `settingsVersionFooter(String)`,
`tierCatalogCardSemanticLabel({name, sla, meta, price})`, `transcriptionLanguageDetected(String)`,
`clientLocationGpsAccuracy(int)`, `mutualRatingStarsA11yLabel(int)`.

**Keys carrying Arabic in BOTH locales (deliberate, recorded):** `onboardingTagline`,
`onboardingPreviewVoiceTranscript` (01 — the brand eyebrow and the decorative transcript are Arabic
by design, like the wordmark) and `chatQuickReplyThanks` (21 — the board draws the Arabic pill
inside the English thread; lane 21 flagged this as a **product choice pending owner confirmation**.
If refused, change the EN *value* to "Thanks"; the call site does not move).

---

## 2. Non-l10n changes applied

| file | request | what landed |
|---|---|---|
| `lib/core/widgets/directional_icons.dart` | 01 | `static IconData forward(BuildContext)` — RTL-mirrored advance arrow |
| `lib/core/formatting/money_format.dart` | 19 §A | `format(..., bool signed = false)`; the `+` is emitted INSIDE the LTR isolate. Default keeps every existing call site byte-identical. |
| `lib/features/auth/social/social_sign_in_section.dart` | 02 | `axis` param (default `Axis.vertical`). Horizontal renders `Row[Expanded(google), gap, Expanded(apple?)]`, degrading to full-width Google when Apple is unavailable. Keys + identifiers unchanged. |
| `lib/features/auth/social/social_sign_in_button.dart` | 02 | Apple-glyph visibility fix — **applied with a corrected patch, see §4.1** |
| `lib/features/location/presentation/widgets/delivery_create_layout.dart` | 09 | `pagePadding` start/end `Spacing.large` (20) → `Spacing.xLarge` (24) |
| `lib/core/router/app_router.dart` | 05 ×2 | `onSwitchToTyping` on `/voice-request` (push blank-clip transcription) and `/compose-dictation` (pop) |
| `lib/core/router/app_router.dart` | 10 W1 | `/voice-request/transcription` `onConfirm` now threads `audioLocalPath: clip.localAudioPath` + `audioDurationMs: clip.durationMs` onto the `RequestDraft` |
| `lib/core/router/app_router.dart` | 13 | `otp-handover` builder passes `deliveryInfo: sl<LiveTrackingRepository>()` to `OtpHandoverCubit` (already-registered repo, optional param, no new endpoint) |
| `lib/core/router/app_router.dart` | 15 | `mutual-rating` builder forwards `rateeName: state.uri.queryParameters['name'] ?? ''` |
| `lib/features/delivery_receipt/presentation/delivery_receipt_l10n.dart` | 14 | **deleted** (explicit integrator instruction) + its `STOPGAP import` line removed from `delivery_receipt_screen.dart`. Required, not optional: with the real getters present the extension's import would have become an unused-import warning. |
| `.maestro/flows/jm-009-phone-otp.yaml` | 03 | six stale `phone_otp_input_N` + `inputText` pairs → four `phone_otp_keypad_N` taps (identifiers verified present at `otp_verification_screen.dart:290`). The conditional `phone_otp_verify_cta` fallback and every `phone_otp_input` visibility assert are untouched. |
| `.maestro/jeeb/devices/R5CT71TVVAJ/flows/pages/voice-request.yaml` | 05 | `longPressOn: point: "41.7%,54.9%"` → `longPressOn: id: "voice_request_mic_button"` |
| `.maestro/flows/24-…yaml`, `.maestro/flows/25-…yaml` | 16 | `jeeber_feed_search_toggle` tap + `waitForAnimationToEnd` inserted before the first `jeeber_feed_search_field` reference. No identifier renamed, no assertion weakened. |
| `test/features/shell/home_tab_create_request_fab_test.dart` | 04 | rewritten — see §4.2 |

---

## 3. Requests REFUSED

### 3.1 Every kit change — refused, kit is frozen

The Wave-1 kit (`lib/core/widgets/jeeb/`, 476 tests) is frozen; modifying it is outside this pass.
Recorded here so the kit owner has one list:

| # | from | ask | verdict |
|---|---|---|---|
| K1 | 05 | new `jeeb_circle_action.dart` (Ø40/46 circular icon action) | REFUSED (new kit file). 05 ships the documented `_CircleSatellite` fallback at `Sizes.fourXLarge`; one-for-one swap later. |
| K2 | 06 | `JeebChipRole.meta` (static non-interactive pill) | REFUSED. 06 ships `transcription_language_chip.dart` with its `// TODO(redesign-24)` marker; 08's SLA chip wants the same role. |
| K3 | 07 W-7 | wrap `_CompactBody`'s `_Badge` in `Flexible` (`RenderFlex overflowed by 64px` @ 360dp / 2.0 scale) | REFUSED — **but corroborated**, see §5.1 |
| K4 | 08 | `_CatalogBody` price-meter + badge overflow (5 overflows @ 360×640 / 2.0) | REFUSED — same family as K3 |
| K5 | 10 W4 | 7-bar `JeebWaveform` preset | REFUSED. 10 keeps `JeebWaveform.cardMark()` (4 bars) as an accepted divergence; no fork was made. |
| K6 | 16 | `cardMark` 3-bar profile for 16; `JeebProfileHeader.avatarIdentifier`; label-only `filter` chip; `JeebNavySurfaceCard` shadow = `ctaNavy` | REFUSED (kit contract corrections — plan-vs-HTML calls for the kit owner) |
| K7 | 15 D | new `jeeb_star_input.dart` + the jm-034 coordinate-tap retirement it enables | REFUSED (new kit file). 15 ships the sanctioned `OmdsStarRating` fallback; **`.maestro/flows/jm-034-rating.yaml` was NOT edited**, because its two `point:` taps can only be replaced once `mutual_rating_star_<n>` identifiers exist. Editing it now would point at ids that do not exist. |
| K8 | 17 WR-1 | `git mv` the screen-local `JeebMoneyField` into the kit and restore design-exact `fontSize:` | REFUSED (adds a kit file). The 2–3px type divergence stands, documented in the lane. |

Already-satisfied kit asks in 04, 06, 07 (W-1/W-2/W-3), 09, 11, 12, 13, 14, 17 (WR-2/3/4), 18, 20,
22, 23 were verified against the shipped kit and need no action — they are recorded in the lane
files, not repeated here.

### 3.2 Other refusals

| from | ask | why refused |
|---|---|---|
| 08 | **W-R1: a `/tier-catalog` route** | Withdrawn by the lane itself and contradicted by the 🛑 STOP block: `tier_selection_screen.dart` is dead code, the live picker is a section of `/request-type`. Adding it would resurrect a deliberately deleted surface. |
| 07 | `tier_repository.dart` flip `recommended` Flash → Standard | The request is explicitly marked **"OWNER DECISION — do not apply until resolved"**. Not wiring. The code renders `tier.recommended` and hardcodes no tier, so this is a one-constant change whenever product answers. |
| 16 | ICU plural keys `jeeberFeedMinutesAgo` / `HoursAgo` / `DaysAgo` (`{count, plural, …}`) | **Structurally impossible here.** `AppLocalizations._get` returns the raw ARB string; there is no ICU engine, so an ICU body would render literally on screen. The repo's convention is one key per CLDR branch (as used for `offersWindowStrip*`). Also moot: the feed-card rebuild that would consume them was not applied (§3.3), so there is no call site. |
| 16 | `jeeberFeedMakeOfferAction` | No consumer — depends on the same unapplied feed-card rebuild. Adding it would have been a pure orphan. |
| 07 / 08 | `tierFlashSummary` · `tierExpressSummary` · `tierStandardSummary` · `tierOnTheWaySummary` · `tierEcoSummary` · `requestTypeTierSummarySemanticLabel` | Reconciled away — see §4.3. |
| 05 | "add the four keys to `test/support/sync_app_localizations.dart`'s fixture map" | No-op: that harness reads the real `lib/l10n/app_*.arb` off disk (`File(...).readAsStringSync()`); it carries no fixture map. |
| all | any pubspec dependency | None was requested. None added. |
| all | any invented backend endpoint/field | None was requested; every data gap in the lane files is marked TODO/omitted rather than faked. Verified: nothing in this pass touches a request/response contract. |
| — | anything contradicting `test/decision_violations_test.dart` | Checked: no new key name collides with the D20 banned set (`kycWizardStepVehicleLabel`, `kycVehicleStepTitle`, `kycVehicleRegistrationLabel`, `kycStatusResubmitCta`, …); D56/D52 surfaces untouched; every fee string added uses **"Platform fee"**, never "Commission", with `{percent}`/`{rate}` interpolated from `kJeebCommissionPercent` at the call site. `decision_violations_test.dart` is **green**. |

### 3.3 Deferred — feature rebuilds requested of the integrator (NOT wiring)

Two requests in `16-jeeber-home.md` ask for full widget rewrites in other lanes' feature
directories, each several hundred lines with its own test rewrite:

* `lib/features/jeeber_request_feed/presentation/jeeber_feed_card.dart` (+ `test/jeeber_feed_card_test.dart`)
* `lib/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart` (+ `test/features/shell/jeeber_active_card_push_render_test.dart`)

**Not applied.** These are screen rebuilds, not wiring, and lane 16 shipped without them: it built
its own `lib/features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart`
instead, which makes the second request at least partly superseded. Recorded for a follow-up lane.

Same class, also deferred:

* **06 cross-feature — parse `TranscribeResponse.language`** into `TranscriptionResult`,
  `VoiceRecordingState` and the `VoiceSentCallback` typedef (`lib/features/voice_request/**`), plus
  the two `extra: VoiceClip(` router sites that would thread it. Lane 05 owns that directory and
  did not widen the typedef; verified `VoiceSentCallback` still has no `language` parameter and
  `voice_recording_repository.dart` does not parse the field. **The router half was therefore also
  not applied** — threading a parameter that does not exist would not compile. Non-blocking by the
  lane's own design: `VoiceClip.language` already exists and 06's chip renders nothing until it is
  fed, which is the no-fabrication behaviour, not a bug.
* **17 WR-6 (marked OPTIONAL)** — passing `DeliveryRequest` as `extra` on
  `pushNamed('jeeber-offer-submission')`. Requires an additive ctor param on the composer plus edits
  at two call sites in two other lanes' directories. The screen is correct and shippable without it,
  by the lane's own statement.

---

## 4. Reconciliations

### 4.1 02 · The Apple-glyph fix — right diagnosis, wrong patch

The request asked to invert the ternary to `isDark ? _appleBrandWhite : _appleBrandBlack`. Reading
the resolved OMDS source (`../omds-flutter/omds_library/lib/src/buttons/omds_social_button.dart`,
`_branded`) shows `OmdsSocialButtons.apple` paints `backgroundColor: Colors.white`
**unconditionally and ignores `isDark` entirely** — the comment there says so explicitly. So the
requested inversion fixes light mode and breaks dark mode symmetrically.

**Applied instead:** the glyph is unconditionally `_appleBrandBlack`, and the now-unreachable
`_appleBrandWhite` constant was removed (leaving it would have produced a new unused-element
warning). Apple's HIG black-on-light / white-on-dark rule only binds while the *button* flips, which
under OMDS's brand-neutral skin it no longer does. Rationale is in the code comment at the call
site.

### 4.2 04 · The shell create-request test

Applied as requested for the three dev-seam variants: `find.byKey(Key('client-home-greeting-add'))`
→ `find.bySemanticsIdentifier('orders_create_request_button')`, asserting the node exists **and**
its `SemanticsData.hasAction(SemanticsAction.tap)` — the guarded defect (a null `onCreateRequest`
from the shell rendering the create surface inert) is preserved exactly. All four negative pins are
verbatim: `orders_home_new_order_fab`, `client_home_voice_request`, `orders_search_bar`,
`FloatingActionButton`, `Key('client-home-voice-cta')`, `Key('client-home-search-bar')`.

**Beyond the request:** the file's *second* case resolved `IconButton.style.backgroundColor` on
`Key('client-home-greeting-add')` to assert the navy fill. That IconButton no longer exists, so the
case is unsalvageable as written; the request did not cover it. It is **retired with an in-file
comment** pointing at its replacement coverage — `client_home_screen_test.dart`'s
*"create-request hero uses primary card fill + accent mic"*, which lane 04 owns and which asserts
the same paint on the new surface. The file is green (3/3).

### 4.3 07 vs 08 · Tier copy — one canonical definition

Both lanes edit the same screen. Reconciled as follows:

* **Badge wording.** 07 asked for `requestTypeMostPickedBadge` ("Most picked"); 08's board says
  "Recommended" and 08 explicitly deferred to 07's shipped decision. **Added once, as
  `requestTypeMostPickedBadge`.** The existing `tierSelectionRecommendedBadge` is left untouched.
  If product prefers "Recommended", change the ARB **value**, not the call site — recorded in the
  key's `@description`.
* **Tier summaries.** 07's `tier{Flash,Express,Standard,OnTheWay,Eco}Summary` and
  `requestTypeTierSummarySemanticLabel` have **no call site** after 08 decomposed the one-line
  summary into SLA chip + meta line + price caption. 08 offered "drop them or keep them,
  integrator's call". **Dropped.** Under the strict parity gate every ARB key must carry a getter,
  so keeping six unused keys means six permanent orphan getters for zero benefit.
* **SLA vocabulary.** `tierCatalogSlaFlexible` ("Flexible") is additive; the engineer-facing
  `tierSelectionSlaNone` ("No SLA") is left in place for any other consumer, and the numeric bands
  keep rendering through `tierSelectionSlaHours/Minutes`.
* **`requestTypeLocationHeading` → "Deliver to"** applied; `test/delivery_create_screens_test.dart:103`
  already pins the new string, so this was load-bearing, not cosmetic.

### 4.4 12 vs 13 · Two dispute CTAs — not a duplicate

`trackingDisputeCta` = "Open dispute" (12's footer, an equal-weight action pair) and `otpDisputeCta`
= "Problem? Open a dispute" (13's outline footer pill). Different board copy on different surfaces;
both kept, cross-referenced in `trackingDisputeCta`'s `@description`.

### 4.5 Screen-scoped generic words

`receiptProofViewerCloseLabel` ("Close") and `walletBackLabel` ("Back") look like duplicates of a
shared token. Checked: the repo has no shared `commonClose`/`actionBack` — the existing equivalents
are `feedbackCloseLabel`, `deliveryManProfileCloseLabel`, `kycWizardBack`, i.e. **screen-scoped by
house convention**. Both added as requested.

### 4.6 11 · The plural strip

The request's `offersWindowStrip` method body was applied essentially verbatim (reformatted for the
`prefer_final_locals` lint). All six CLDR branch keys exist in both locales, so
`ar_plurals_check.sh` sees a complete set; the six `_get()` calls inside the one method are what
keeps the parity gate's `S2` in sync.

### 4.7 17 · Arabic values sourced from the lane's own resolver

`17-offer-composer.md` supplied EN only and said "the AR values are already in
`offer_composer_l10n.dart`". They were copied from there verbatim
(`_pick(en, ar)` pairs), so the ARB layer and the interim resolver agree string-for-string.

### 4.8 Stopgap resolvers left in place (except 14)

Lanes 12, 13, 17, 18, 19, 21 and 23 ship feature-local `*_l10n.dart` resolvers and asked for the ARB
keys so those resolvers can later collapse to one-line delegations. **All the keys and getters
landed**; the resolver swaps themselves are left to the owning lanes, because each is a feature-dir
edit with its own tests. They are separate classes, so nothing breaks and no warning appears — the
new getters are simply orphans until the swap.

**14 is the exception and was completed here**, because its stopgap is an `extension on
AppLocalizations`: once the real instance getters win, its import in `delivery_receipt_screen.dart`
becomes unused and would have added a warning above baseline. File deleted, import removed, no call
site changed (spellings were already `l10n.receiptCashNote` etc.).

---

## 5. Notes handed to other owners (no action taken here)

### 5.1 Kit row overflow — now corroborated by three independent sources

07 (W-7) and 08 both reported `RenderFlex` overflows inside `jeeb_tier_row.dart` at large text
scale. Running the suite after integration reproduces the same defect *class* in two more kit files
on default-scale viewports:

* `lib/core/widgets/jeeb/jeeb_select_chip.dart:288` — `A RenderFlex overflowed by 35 pixels`
  (surfaced by `test/client_home_screen_test.dart`)
* `lib/core/widgets/jeeb/jeeb_tier_chip.dart:171` — `A RenderFlex overflowed by 59 pixels`
  (surfaced by `test/order_history_screen_test.dart`)

Neither is fixable from a feature directory — the features only pass strings in. **Kit owner item.**

### 5.2 `w1_routes_resolve_test` — a real crash in screen 14 under a bare theme

`lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart:375` does
`Theme.of(context).extension<JeebSemanticColors>()!` and throws
*"Null check operator used on a null value"* when the host uses `ThemeData.light()` instead of
`AppTheme.light()`. Production always installs the extension, so this is a harness/robustness gap,
not a shipped crash — but it is the reason that route test fails. **Lane 14 item.** (Compare
`jeeb_surface_tone.dart:158-160`, which resolves the extension null-safely.)

### 5.3 Screen-18 goldens are stale

`test/features/active_delivery_jeeber/goldens/*.png` are dated **2026-08-02**, one day before lane
18 rebuilt the screen. Diffs are 16.6% / 18.0% / 24.3% — a whole-surface redesign, not a label
change. This pass's one contribution is `activeDeliveryOtpSubmit` → "Verify code & complete", which
cannot account for that magnitude. **Not regenerated**: re-baselining goldens would rubber-stamp an
unreviewed visual target. **Lane 18 item.**

### 5.4 Other lane items surfaced by unblocking compilation

Before this pass, 119 analyze errors meant most of these test files could not even load. They now
run and fail on their own lanes' behaviour:

* `test/features/rating/mutual_rating_redesign_test.dart` (3) — the star verdict word does not
  render after `cubit.setStars(n)` + `pump()`. **The ARB values match the test's pins
  byte-for-byte** (`Poor` `Fair` `Okay` `Great` `Excellent` / `سيئ` `مقبول` `جيد` `رائع` `ممتاز`),
  so this is screen/cubit behaviour, not copy. **Lane 15.**
* `test/features/order_history/order_history_card_test.dart` (5) — *"A SemanticsHandle was active at
  the end of the test"*: undisposed `ensureSemantics()` handles. **Lane 24.**
* `test/client_home_screen_test.dart` (4) and `test/order_history_screen_test.dart` (5) — kit
  overflows (§5.1) plus lane paint assertions. **Lanes 04 / 24 + kit.**
* `test/mb1/mb1_doc_residual_receipts_test.dart` (1) — the entire Wave-0/Wave-1 kit
  (`lib/core/widgets/jeeb/`, `jeeb_text_styles.dart`, `jeeb_shadows.dart`) is **untracked in git**,
  so the "tracked file" lens finds nothing. Resolves the moment the kit is `git add`ed.
* `.maestro/flows/09-request-type-client.yaml` asserts pre-rename ids
  (`request_type_tier_flash`, `_tier_onTheWay`) and was broken **before** this redesign — flagged by
  lane 07, still unowned. Not touched.
* Four chat flows (`02`, `03`, `04`, `07`) still assert `chat_detail_voice_button`, absent since
  B-04. Advisory only per lane 21; the Dart guard
  (`chat_composer_no_mic_b04_test.dart`) wins and the redesigned composer enforces no-mic
  structurally. Not touched — resurrecting the mic would be the wrong "fix".
* `lib/features/shell/tabs/home_tab.dart:199-204` — the doc comment on `_openRequestType` still
  describes the retired `IconButton.filled` top plus. Cosmetic, lane 04's file, left alone.

### 5.5 `check_design_tokens.sh` — 6 pre-existing violations

`BorderRadius.circular` ×3 in `settlement_*`, a raw `TextField` in `client_location_screen.dart`,
`RefreshIndicator` ×2 in `wallet_activity_list_screen.dart` / `reviews_list_screen.dart`. None are
in this pass's diff; all pre-date it.

### 5.6 Open owner questions carried forward (verbatim from the lane files)

1. **07/08** — the `recommended` flag sits on Flash (`tier_repository.dart:100`/`:189`); the board
   draws the badge on Standard.
2. **21** — is `chatQuickReplyThanks` Arabic in the English thread a shipped product choice?
3. **23** — is `WalletBalance.giftCredit` *included in* or *additive to* `availableBalance`? Until
   answered the pill ships the neutral "{amount} starter credit"; the word "included" is absent.
4. **17** — `offerComposerKeepRowLabel` changes `offer_composer_net_line` from "You earn (cash):
   full price" to "You keep: price − platform fee". Flagged by the lane, adopted, one-line revert.
5. **20** — `/settings` route builds `LiveSettingsScreen` while `profile_tab.dart:88` pushes the
   redesigned `SettingsScreen` via a local `MaterialPageRoute`. One of the two hosts should be
   retired; owner call, no code change made.
6. **18** — the "Costs" footer pill implies a `/jeeber/deliveries/:id/goods-cost` route over a
   verified-orphan screen with a broken endpoint. Pill stays callback-conditional; wiring the route
   is an owner call.

---

## 6. Verification

```
flutter analyze  →  9 issues found, 0 ERRORS      (before this pass: 128 issues, 119 errors)
```

Remaining 9, none in `lib/`, none introduced here — all were present verbatim in the pre-pass run:

| count | issue | files |
|---|---|---|
| 8 | `info · 'containsSemantics' is deprecated` | `test/chat_dm_header_parity_test.dart`, `test/chat_dm_states_test.dart`, `test/chat_screen_test.dart` ×2, `test/client_home_screen_test.dart` ×2, `test/features/chat/order_chat_strip_redesign_test.dart`, `test/features/shell/shell_dual_role_landing_test.dart` |
| 1 | `warning · Unused import: chat_gateway.dart` | `test/features/chat/chat_quick_reply_bar_test.dart:13` |

**Honest reading of the stated baseline.** `_BASELINE.md` says *5 issues / 0 errors*. This pass ends
at **9 issues / 0 errors**. The 4-issue gap is **not wiring**: all 9 are lint in test files that
screen lanes edited during Wave 3, and all 9 appear identically in the analyze snapshot taken
*before* the first integrator edit. The wiring delta on non-error issues is **0**, and the wiring
delta on errors is **−119**. Both are attributable and neither was papered over: the one unused
import belongs to lane 21's test file and is theirs to remove.

**Test suite:** `4579 passed · 61 skipped · 24 failed` (9 files).
**0 failures attributable to wiring.** The `home_tab_create_request_fab_test.dart` failure this pass
introduced was found and fixed (§4.2); the file is 3/3 green. Two of the four failures named as
pre-existing in the brief — `client_offers_screen_test` and `mutual_rating_tag_chips_l10n_test` —
are now **green**, fixed by the l10n batch. The other two — `jeeber_feed_card_test` and
`gesture_log_test` — still fail, as documented. The remaining seven files are itemised in §5.2–§5.4.

Gates re-run and green: `l10n_parity_check.sh` (PASS, all five strict checks 0),
`ar_plurals_check.sh` (PASS), `decision_violations_test.dart` (PASS),
`test/l10n/runtime_parity_test.dart` (PASS).
