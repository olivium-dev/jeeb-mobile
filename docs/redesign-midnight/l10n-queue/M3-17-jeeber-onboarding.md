# l10n queue — M3-17 · delivery-man onboarding wizard (`dm_onboarding_screen`)

New keys the Midnight restyle needs. **Not written to `lib/l10n/*.arb`** (the l10n
lane owns it). Each site still renders the nearest existing string and carries
`TODO(midnight): l10n-queued`.

The cause is structural. R23 — the nearest tile and the very next step of this
funnel — splits the two jobs: the **top bar holds the constant flow name**
("Become a Jeeber") on every step, and the **progress caption holds the step
identity** ("Step 1 of 2 — Your ID" · "then Selfie"). This wizard does the
opposite: the bar title swaps per step and the caption is a bare "Step 2 of 3",
so the flow is never named anywhere and step 1's bar reads the single word
"Image". Closing the gap needs three keys that do not exist.

| Key | EN | AR | Site |
|---|---|---|---|
| `dmOnboardingWizardTitle` | `Become a Jeeber` | `كن جيبر` | `dm_onboarding_screen.dart` `_OnboardingTopBar._titleFor` — the bar should hold this on all three steps. Today it swaps between `dmOnboardingPhotoStepTitle` ("Image"), `dmOnboardingPersonalDetailsTitle` and `dmOnboardingServiceAreaTitle`. |
| `dmOnboardingStepProgressLabelNamed(current, total, stepName)` | `Step {current} of {total} — {stepName}` | `الخطوة {current} من {total} — {stepName}` | `dm_onboarding_progress_header.dart` — today renders `dmOnboardingStepProgressLabel(current, total)`, which has no `stepName` placeholder. The three step names already exist as the keys the bar is currently misusing, so no fourth string is needed. |
| `dmOnboardingNextStepHint(stepName)` | `then {stepName}` | `ثم {stepName}` | `dm_onboarding_progress_header.dart`, end-aligned on the caption row — R23's `kycWizardNextStepHint` twin. Absent entirely today; the row has no trailing slot. |

`kycWizardNextStepHint` is the exact shape to copy (same funnel, same band); it
was not reused because its ARB description is scoped to the KYC step names.

## Not queued, deliberately

Nothing else on this screen needs copy. The photo drop zone, the four address
fields, the map placeholder, the location row and the docked Continue all render
keys that are already in the ARB (`dmOnboardingPhotoUpload*` ×5,
`dmOnboardingAddress*` ×8, `dmOnboardingServiceArea*` ×5,
`dmOnboardingContinue`, `dmOnboardingCoverageCheckFailed`,
`dmOnboardingPhotoPickFailed`).

The board's R23 review-and-privacy note (`JeebInfoNote.muted`) has **no
counterpart on this screen and none was invented** — there is no review promise
to make before KYC is submitted, so the slot stays absent rather than filled with
copy the product has not made.
