# l10n queue — M3-21 kyc-rejected (JM-043)

One key. The call site ships on the nearest existing key today, tagged
`TODO(midnight): l10n-queued`, so nothing renders blank and nothing is faked.
Verified against `lib/l10n/app_en.arb` / `app_ar.arb` on 2026-08-04.

Call site: `lib/features/kyc_rejected/presentation/kyc_rejected_screen.dart`
(`_RejectionReasonNotice._label`, the `KycRejectionReason.other` branch).

## 1. `kycRejectedReasonOtherFinal` — this is a **D52 copy violation**, not a polish item

`KycRejectionReason.other` renders `kycRejectionReasonOther`:

> **EN** "Please review your details and resubmit."
> **AR** "يرجى مراجعة بياناتك وإعادة الإرسال."

That string is shared with `KycStatusView`, where resubmit IS the next step. On
**kyc-rejected it is forbidden**: D52/D87 make this screen FINAL and
`65_W2_TEST_PLAN` §2 JM-043 asserts `kyc_rejected_resubmit_cta` is absent. The
screen therefore tells the user to do the one thing it refuses to let them do.

Proof it renders: capture
`docs/redesign-midnight/captures/M3-21/kyc-rejected__kycrejectedscreen__3-reason-other-generic.png`.

`test/decision_violations_test.dart` already asserts
`find.textContaining('resubmit')` finds nothing on this screen — it passes today
only because its fixture (`FakeKycGateway()`) returns a *non-rejected*
submission, so the note never mounts. Seed it with
`KycRejectedScreenFixtures.other()` and the existing gate goes red.

Interim: `kycRejectionReasonOther` (status quo — a wrong sentence beats an
invented one, and the fix is a copy decision, not a restyle).

```
file: lib/l10n/app_en.arb
  "kycRejectedReasonOtherFinal": "The details submitted didn't meet our verification requirements.",
  "@kycRejectedReasonOtherFinal": {"description": "JM-043 kyc-rejected, KycRejectionReason.other. MUST NOT mention resubmitting: D52/D87 make this screen FINAL and kyc_rejected_resubmit_cta is asserted absent. kycRejectionReasonOther says 'and resubmit' because KycStatusView, which shares it, DOES offer resubmit."},

file: lib/l10n/app_ar.arb
  "kycRejectedReasonOtherFinal": "البيانات المُرسلة لم تستوفِ متطلبات التوثيق لدينا.",

file: lib/l10n/app_localizations.dart
  String get kycRejectedReasonOtherFinal => _get('kycRejectedReasonOtherFinal');
```

## Deliberately NOT queued

- `kycRejectedTitle` / `kycRejectedHeadline` / `kycRejectedBody` /
  `kycRejectedAppealCta` / `kycRejectedBackCta` — present in EN **and** AR, all
  still correct, and `kycRejectedBody` is exactly the empty-family body line the
  restyle needs ("This decision is final… appeal through support").
- `kycRejectionReasonIdUnreadable` / `SelfieMismatch` / `Expired` — all three
  describe the cause without prescribing a next step, so they are true on both
  the resubmit surface and the final one.
- No key for the loading / fetch-error / no-structured-reason phases: all three
  render the FINAL block unchanged (byte-identical captures 4, 5 and 6), which is
  a designed silence, not a missing sentence. An "we couldn't load the reason"
  line would add copy about an *optional enrichment* to a screen whose decision
  is not in doubt.

## After the key lands

Swap the one call site and drop its `TODO(midnight): l10n-queued` tag. Then seed
`test/decision_violations_test.dart`'s D52 case with
`KycRejectedScreenFixtures.other()` so the gate actually exercises the branch —
without that it will keep passing on a fixture that never mounts the note.
