# Wiring requests — lane `motion-home-onboarding` (screens 01, 04)

**No shared-file code change is requested.** This lane touched only
`lib/features/home_client/**` and its own tests. `pubspec.yaml` already registers
`assets/animations/`, no new l10n keys were needed, and neither the router, the DI container, the
theme nor the frozen kit was modified.

Two items below are for other owners. Full reasoning:
`docs/redesign-2026-08/apply-reports/w3-motion-home-onboarding.md`.

---

## 1. Motion-spec owner — a cards-free `onboarding-say-it` variant (blocks screen 01)

`onboarding-say-it.json` cannot be wired as authored. It composes screen 01 panel 1's entire
tableau (mic + 2 rings + transcript card + offer bubble), and that tableau already ships in Dart
with **real localized copy** — `_MarketplacePreview` renders `onboardingPreviewVoiceTranscript`
("جيب لي دوا من الفرماشية"), `onboardingPreviewRequestTitle`, `onboardingPreviewOfferQuote` and
`onboardingPreviewOfferMeta`, each with an Arabic translation, exactly as `screens/01-onboarding.png`
draws them. Adding the file duplicates every element; swapping for it turns the Arabic transcript
into a grey placeholder bar, because the Lottie contract is shape-layers-only with **no fonts**
(motion spec §1). It also breaks `test/onboarding_screen_test.dart:218/410/415` and contradicts
`00-MIGRATION-PLAN.md` §6 row 01.

**Requested:** a variant carrying **only** L6 `mic-button`, L5 `ring-1` and L2 `ring-2` — no
transcript card, no offer bubble — one-shot, transparent canvas, mic anchor centred so the file can
be sized to sit behind the kit's `JeebMicHero.decorative()` on the navy stage. That composition
layers behind the localized collage without duplicating anything, and screen 01 gets its motion
with the Arabic transcript intact.

Alternatively: an explicit owner ruling that the localized collage may be dropped. That is a
product call about `01-onboarding.png`, so this lane did not make it.

## 2. Motion-spec owner — `mic-listening.json` §2.1 screen list should drop 04

§2.1's premise ("plays while the user is holding to talk (04 hero card…)") does not hold in this
app. `ClientHomeRequestHero` documents that `VoiceRecordingScreen` exposes no auto-start seam, so a
hold on 04 cannot begin a recording; both the tap and the long-press simply
`pushNamed('voice-request')`. A looping sonar there would claim the app is listening when it is
not — a decorative loop, which binding rule 3 forbids. The file stays correct for **screen 05**,
whose lane should wire it.

## 3. Integration sweep — orphaned asset (FYI, no action taken here)

`assets/illustrations/empty_orders.png` is replaced on screen 04 by `empty-say-it.json`. Combined
with a concurrent lane's edit to `jeeber_feed_empty_view.dart`, the PNG now has **zero references
in `lib/`**. Its `pubspec.yaml` registration was deliberately left alone (no pubspec edits in this
lane, and the second reference belongs to another lane); flagging it so the sweep can decide.
