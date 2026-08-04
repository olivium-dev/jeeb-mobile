# w3 — Lottie wiring, lane `motion-home-onboarding`

Screens 01 (onboarding) and 04 (client home).
Assigned files: `onboarding-say-it.json`, `empty-say-it.json`, `mic-listening.json`, `loading-dots.json`.
Branch `feat/redesign-24-migration` — no branch/commit/push performed.

**Outcome: 2 of 4 files wired and rendering; 2 refused with evidence.** The two refusals are not
"ran out of time" — each would have made the app worse than it is today, and both are recorded
below with the specific artefact that blocks them.

---

## 1. Wired

### 1.1 `empty-say-it.json` → screen 04's pending empty state

`lib/features/home_client/presentation/widgets/client_home_empty_view.dart`

The empty state's illustration was `assets/illustrations/empty_orders.png` — a 200dp shop drawing
that predates the redesign. Motion spec §2.6 rules that the client's "no requests yet" and "no
orders yet" states share one CTA (make your first request), so **the empty-state mark is the mic**.
`empty-say-it` is exactly that: the navy inversion of the hero's orange mic, one invite ring, then
stillness. It now sits where the PNG was, directly beneath the hero mic it rhymes with.

- One-shot (`repeat: false`) — an empty list is a still state, and the brand forbids decorative
  loops. Plays once and **holds the final frame**; never rewound.
- White surface only, which is where it lives (measured 9.0–11.6% ink on white vs 2.1–4.6% on navy).
- No RTL mirror — radially symmetric (`09-MOTION-VALIDATION.md` §8).
- **The PNG file and its `pubspec.yaml` registration are untouched** (no pubspec edits in this
  lane). Note for the integration sweep: with this change *and* a concurrent lane's edit to
  `jeeber_feed_empty_view.dart`, `assets/illustrations/empty_orders.png` now has **zero references
  in `lib/`** and is a candidate for de-registration. Flagged, not acted on — the second reference
  belongs to another lane and the sweep owns `pubspec.yaml`.

### 1.2 `loading-dots.json` → screen 04's four wait surfaces

`client_home_screen.dart` (`_LoadingLayout`) · `tabs/pending_requests_tab.dart` ·
`tabs/replies_tab.dart` · `tabs/in_progress_tab.dart`

All four rendered `OmdsLoadingState`, which is a Material `CircularProgressIndicator`. They now
render the brand's own inline wait. All four were changed together on purpose: they are one screen,
and shipping two different wait marks on it would be the defect.

- Loop is legitimate — it depicts an ongoing state, the only thing the brand lets loop.
- **RTL mirrored** via `Transform.flip`: the opacity peak travels left→right (f30/f45/f60), so
  Arabic must read right→left.
- Ticker cost is unchanged: the spinner it replaces was already an infinite ticker, so no
  `pumpAndSettle` behaviour anywhere in the suite changed.
- `Key('pending-loading')` / `Key('replies-loading')` / `Key('in-progress-loading')` preserved.

### 1.3 The wrapper — `presentation/widgets/client_home_motion.dart`

`ClientHomeEmptyMark` and `ClientHomeLoadingDots`. Both marks go through it so all three
non-negotiables are inherited rather than re-typed at four call sites:

1. **Explicit size**, so nothing consumes unbounded space while the composition decodes.
2. **Reduce motion.** `MediaQuery.disableAnimationsOf` leaves a *still frame*, and the two files
   need **different** still frames. The loop parks on frame 0 (all three dots are drawn at f0). The
   one-shot parks on its **final** frame via `kAlwaysCompleteAnimation` — `empty-say-it`'s frame 0
   is deliberately blank (pre-entrance), so the obvious "park at 0" would have left an empty box
   where the empty-state illustration belongs. This is asserted by a test.
3. **Graceful decode failure** — `errorBuilder` degrades to the reserved box, matching the
   `placeholderBuilder` contract the app's `SvgPicture.asset` sites already carry.

Both are decorative, so both carry `ExcludeSemantics` inside the wrapper; the surrounding localized
copy is what a screen reader announces. No `Semantics(identifier:)` was added, changed or removed
anywhere in this lane.

### 1.4 One deliberate deviation from the validation doc

`09-MOTION-VALIDATION.md` §11 suggests rendering `empty-say-it` at ~120dp. **Shipped at 160dp**,
with the reason recorded in the code. At 120dp its mic renders Ø44 — *smaller* than the Ø56 hero
mic immediately above it, which inverts the reading (the empty-state illustration should be the
calm big sibling of the button, not a shrunken copy). 160dp puts it at Ø59 and still well inside
the Ø200 footprint the PNG reserved. Cost: the invite ring's w3 stroke lands at 2.0dp instead of
the authored 1.5dp — still a thin ring, so the orange stays rationed. Verified in rendered pixels.

---

## 2. Refused, with the blocking artefact

### 2.1 `onboarding-say-it.json` — would regress screen 01 to untranslated placeholder text

The file composes screen 01 panel 1's whole tableau: mic + two rings + a **transcript card** (mini
waveform bars and two grey "text" lines) + an **offer bubble** (two white lines and an avatar dot).
That tableau already ships, in Dart, with **real localized copy** — `_MarketplacePreview`'s three
cards render `onboardingPreviewVoiceTranscript` ("جيب لي دوا من الفرماشية"),
`onboardingPreviewRequestTitle`, `onboardingPreviewOfferQuote`, `onboardingPreviewOfferMeta`, each
with an Arabic translation. `screens/01-onboarding.png` shows that text, in the cards, as the
emotional core of the slide.

The overlap is total, so wiring the file means one of two things, and both are worse:

- **Add it** → two mics and two sets of story cards on one 360dp stage.
- **Swap for it** → the transcript becomes a grey bar. The Lottie technical contract is
  **shape layers only, no fonts** (motion spec §1), so the animator *could not* put text in the
  file; the grey bars are a format limitation, not a design preference. Shipping them would move
  the screen further from its own render, not closer.

It also breaks three assertions: `test/onboarding_screen_test.dart:218/410/415` pin
`Key('onboarding.preview')` present on slide 1 and absent on slide 2, and
`00-MIGRATION-PLAN.md` §6 row 01 freezes the collage as "static/decorative".

**Nothing was changed in `lib/features/onboarding/`.** Screen 01 ships this wave with no Lottie.
The constructive path is in §3.

### 2.2 `mic-listening.json` — screen 04 has no listening state to depict

Spec §2.1: "Plays while the user is holding to talk (04 hero card, 05 recording screen)." That
premise does not hold for this app on 04. `ClientHomeRequestHero` documents it directly:

> The subtitle deliberately says "tap", not the board's "Hold to talk": `VoiceRecordingScreen`
> exposes no auto-start seam, so a hold on THIS screen cannot begin a recording.

Both the tap and the long-press just `pushNamed('voice-request')`. A looping sonar on that mic
would claim the app is listening when it is not — a decorative loop, which binding rule 3 forbids,
on a screen whose whole job is trust. `JeebMicHero`'s glow stack is also measured per diameter and
is frozen kit; a Lottie disc behind it would fight it.

The file's real home is **screen 05**, which owns the actual recording state. Handing it to that
lane, unwired here.

---

## 3. Requests to the motion-spec owner

1. **A cards-free `onboarding-say-it` variant** (mic + the two orange rings only, one-shot, ~140dp,
   transparent canvas). That composition layers *behind* the existing localized collage and the
   kit's `JeebMicHero.decorative()` without duplicating a single element, and screen 01 gets its
   motion with the Arabic transcript intact. This is the single change that unblocks 2.1.
2. Failing that, an explicit owner decision that the localized collage may be dropped — that is a
   product call about `01-onboarding.png`, not an implementation detail, so it is not made here.
3. Spec §2.1's screen list should drop **04** (or the 04 hero must gain a real hold-to-record seam
   first). The file stays correct for 05.

---

## 4. Verification

- `dart analyze lib/features/home_client lib/features/onboarding` → **No issues found.**
  Including the touched test files adds only two pre-existing `containsSemantics` deprecation
  infos on lines untouched by this lane. **0 errors.**
- `flutter test` over `test/features/home_client`, `client_home_screen_test`,
  `client_home_empty_view_test`, `client_home_greeting_test`, `onboarding_screen_test`,
  `dm_onboarding_screen_test`, `semantics_identifier_surfacing_test`, `test/features/shell`,
  `cancel_refresh_integration_test`, `n234_idle_window_test`, `e24_tab_semantics_split_test`,
  `app_resume_signals_test`, `push_refresh_topic_routing_test` → **all pass, 0 new failures.**
- **Rendered pixels, not just JSON.** A throwaway golden harness rendered `ClientHomeEmptyView` at
  390×844 across the composition's timeline and the frames were viewed directly: the mic enters,
  the orange invite ring expands and fades around t≈600–1000 ms, and the mark settles to the navy
  mic. The harness and its output were deleted; nothing temporary remains in the repo.

Three test assertions were updated from the retired PNG to the new mark (they pinned
`assets/illustrations/empty_orders.png`), and two new assertions were added for the reduce-motion
contract and the one-shot flag:
`test/client_home_empty_view_test.dart`, `test/client_home_screen_test.dart`,
`test/features/home_client/pending_requests_tab_test.dart`.

**No shared file was touched** — no `pubspec.yaml` (the animations were already registered), no
`lib/l10n/*`, no `app_router.dart`, no `injection_container.dart`, no `lib/core/theme/*`, and
nothing in the frozen kit. No new user-visible strings were needed, so no l10n wiring request.
