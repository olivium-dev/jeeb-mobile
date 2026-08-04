# Wiring requests — lane `motion-confirm` (14 / 22 / 23, success-check + kyc-review)

Nothing in this lane needed a shared file to be edited. **No `pubspec.yaml`, no `lib/l10n/*`, no
`lib/core/theme/*`, no `app_router.dart`, no `injection_container.dart`, and no touch of the frozen
kit** (`lib/core/widgets/jeeb/`). Everything below is a *proposal for a later owner*, not a blocker.

## 1. (Optional, kit owner) Lift a shared `JeebLottieMark` into the kit

**Why.** Three feature-local widgets now hold the same ~40 lines of one-shot Lottie plumbing:

| File | Composition |
|---|---|
| `lib/features/delivery_receipt/presentation/widgets/receipt_confirmed_overlay.dart` | `success-check.json` |
| `lib/features/wallet/presentation/widgets/wallet_topup_confirmed_mark.dart` | `success-check.json` |
| `lib/features/kyc/presentation/widgets/kyc_status_marks.dart` (`KycApprovedMark`) | `success-check.json` |

They are duplicated **on purpose** — the lane rule is "edit only your own feature directory", and
the kit is frozen — but `success-check.json` is by design THE shared terminal mark (08-MOTION-SPEC
§2.5: "a delivered order, a top-up and an approval must all feel identical"). One widget in the kit
would make that literal instead of conventional.

Paste-ready shape, if the kit owner wants it:

```dart
/// One-shot Lottie mark. Plays forward exactly once via its own controller and
/// holds the settled frame; under `MediaQuery.disableAnimations` it jumps
/// straight to that frame instead. Decorative — excluded from semantics.
class JeebLottieMark extends StatefulWidget {
  const JeebLottieMark.oneShot({super.key, required this.asset, this.size = 100});
  const JeebLottieMark.looping({super.key, required this.asset, this.size = 100});
  final String asset;
  final double size;
  ...
}
```

Callers would then be `const JeebLottieMark.oneShot(asset: JeebMotion.successCheck)` and the three
feature widgets above delete. **Not done here** — a new file under `lib/core/widgets/` would race
the other motion lanes and edit shared ground this lane does not own.

## 2. (Optional, l10n owner) A live-region string for the confirmation marks

The three marks are wrapped in `ExcludeSemantics` because the copy around them already states the
outcome (screen 22's "Under review" / "You're approved"; screen 14 hands straight off to the rating
screen, which announces itself; screen 23's balance is its own announcement). If the a11y owner
wants an explicit announcement on the wordless moments (14's beat, 23's landed top-up), it needs
**three** consistent edits — `app_en.arb`, `app_ar.arb` and the hand-written
`lib/l10n/app_localizations.dart` — so it is filed rather than done:

| Key | EN | AR |
|---|---|---|
| `motionConfirmedAnnouncement` | `Confirmed` | `تم التأكيد` |

No other l10n change is needed: this lane added **zero** user-visible strings.

## 3. Nothing else

- `assets/animations/` was already registered in `pubspec.yaml` (lines 289–298) before this lane
  started — 09-MOTION-VALIDATION §11's outstanding item is closed.
- `lottie: 3.3.1` untouched (the pin is deliberate).
