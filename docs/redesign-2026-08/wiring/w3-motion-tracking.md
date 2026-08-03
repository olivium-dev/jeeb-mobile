# Wiring request — lane `w3-motion-tracking`

Nothing here is blocking: the lane shipped against the state described below and
its tests are green. These are the two items that touch ground outside
`lib/features/{live_tracking,no_offer_timeout,client_offers}` and therefore need
an integrator's eye.

---

## 1. NEW shared file — `lib/core/widgets/motion/jeeb_lottie_mark.dart`

**Status: written by this lane (new directory, new file — nothing existing was
edited).** The frozen kit (`lib/core/widgets/jeeb/`) was not touched.

Three feature directories in this lane play Lottie compositions, and all three
need the identical three behaviours around `Lottie.asset`, so the player is one
widget rather than three copies:

```dart
JeebLottieMark(
  asset: 'assets/animations/broadcasting.json',
  width: 140,
  height: 140,
  // cycles: 6            — bounded loop, then rests on the final frame
  // mirrorInRtl: false   — true ONLY for courier-in-transit / loading-dots /
  //                        onboarding-say-it
)
```

* explicitly sized (canvases are ~2× display size, motion spec §4);
* reduce-motion (`MediaQuery.disableAnimationsOf`) pins it to the static first
  frame and schedules **no** frames;
* the loop is **bounded** (see §2), which is what keeps `pumpAndSettle` alive;
* `ExcludeSemantics` — the mark is decorative, the copy beside it is the label.

Tests: `test/core/widgets/motion/jeeb_lottie_mark_test.dart` (5 cases).

**ASK — dedupe check (verified, no collision).** The other motion lanes all went
feature-local — `voice_request/.../recording_waveform.dart`,
`home_client/.../client_home_motion.dart`,
`delivery_receipt/.../receipt_confirmed_overlay.dart`,
`kyc/.../widgets/kyc_status_marks.dart`,
`wallet/.../wallet_topup_confirmed_mark.dart`. `lib/core/widgets/motion/` is
this lane's alone, so nothing was overwritten.

Worth a follow-up all the same: five lanes each re-solved *reduce-motion +
bounded loop + RTL flip* privately. If the integrator wants one player, this is
the one that is already tested and documented — promoting it and deleting the
four private copies is a mechanical change.

---

## 2. Policy question — bounded loops

`Lottie.asset(..., repeat: true)` schedules frames forever, so **every**
`WidgetTester.pumpAndSettle` on a screen that mounts one times out. Measured, on
this branch:

```
loops: does pumpAndSettle hang?   ->  "pumpAndSettle timed out"
animate:false                     ->  settles
disableAnimations in tests        ->  false (so reduce-motion does not save us)
```

Screens in this lane that would have broken:
`waiting_resume_backstop_test.dart`, `client_offers_resume_backstop_test.dart`,
`offer_accept_*`, `offer_card_overflow_test.dart`.

`JeebLottieMark` therefore plays `cycles` times (default **6** ≈ 24 s on the 4 s
sonar canvases) and then rests. Every looping composition is authored seamless
(frame `op` ≡ frame 0), so the resting pose is the loop's own starting state —
not a freeze mid-gesture. This is the pattern the frozen kit already chose:
`JeebStepper`'s active-node glow is a bounded 3-breath pulse for exactly this
reason.

**ASK — is 6 the number?** A customer can sit on the waiting screen for minutes;
after ~24 s the sonar rests. Raising `defaultCycles` is a one-line change and
stays test-safe up to roughly 100 cycles (pumpAndSettle's ceiling is 10 minutes
of simulated time), but a larger bound advances more simulated time inside every
`pumpAndSettle`, which can disturb timer-sensitive tests. Owner's call.

---

## 3. Not requested, for the record

* **No pubspec edit.** `assets/animations/` and `lottie: 3.3.1` were already
  registered by the asset commit; nothing was needed.
* **No l10n edit.** No new user-visible string was introduced — the marks are
  decorative and replaced icons, not copy.
* **No kit edit.** No kit animation was replaced or duplicated.
