# l10n queue — M3-19/20 · Offer-KYC gate + delivery-register prompt

Two keys are **required** by this row (M3-19 gives the status slot a loading and
a failed-read form it never had). Three more are **reported, not required**
(M3-20 renders the gate's strings verbatim on a screen that does something
else); they change copy, not layout, so they are an owner call.

Verified against `lib/l10n/app_en.arb` / `app_ar.arb` on 2026-08-04.

| Key | EN | AR | Status |
|---|---|---|---|
| `offerKycGateStatusChecking` | `Checking your verification status…` | `جارٍ التحقق من حالة التوثيق…` | REQUIRED |
| `offerKycGateStatusUnavailable` | `We couldn't check your verification status right now.` | `تعذّر التحقق من حالة التوثيق الآن.` | REQUIRED |
| `deliveryRegisterPromptHeadline` | `Register as a Jeeber to start delivering` | `سجّل كجيبر لتبدأ التوصيل` | OWNER CALL |
| `deliveryRegisterPromptBody` | `Set up your delivery profile first. Verification comes next, and it only takes a few minutes.` | `أنشئ ملف التوصيل أولاً. يأتي التوثيق بعده ولا يستغرق سوى بضع دقائق.` | OWNER CALL |
| `deliveryRegisterPromptCta` | `Register now` | `سجّل الآن` | OWNER CALL |

## 1. `offerKycGateStatusChecking` (REQUIRED)

Call site: `OfferKycGatePhase.loading` in `_GateStatusLine`
(`offer_kyc_gate_screen.dart`), keyed `gate-status-loading`.

Until MIDNIGHT the loading phase rendered `SizedBox.shrink()`, so the catalog's
`Loading` state was pixel-identical to `Not Submitted` and the status panel
popped in under the body copy once the read landed.

**Nearest existing key in use meanwhile:** `kycStatusPlaceholder` — *"Your
verification status will appear here."* It is the only string in either catalog
that describes an **empty** status slot rather than a status, so it is literally
true while the read is in flight; the queued key only sharpens it from "will
appear" to "checking". Rejected: `deliveryStatusLoading` ("Loading delivery…")
and the `*LoadingHeadline` family — all name another surface's noun.

## 2. `offerKycGateStatusUnavailable` (REQUIRED)

Call site: `OfferKycGatePhase.error` in the same widget, keyed
`gate-status-unavailable`.

**Nearest existing key in use meanwhile:** `requestSummaryErrorGeneric` —
*"Something went wrong. Please try again."* Same choice, for the same reason,
that M3-07 made: it is the catalog's only noun-free error string, so it cannot
say anything false on a surface it was not written for. `kycErrorUnavailable`
was rejected outright — it reads "Couldn't open the camera", which on this
screen is not placeholder copy but wrong copy.

Note the stand-in's "Please try again" implies a retry affordance the gate does
not draw. That is the cost of the stand-in and the reason the key is queued; the
gate deliberately offers no retry, because re-entering it re-reads the status
and the three exits were never blocked on it (R-F).

## 3–5. The M3-20 trio (OWNER CALL — a copy defect this row only reports)

`DeliveryRegisterPromptScreen` renders `offerKycGateTitle` /
`offerKycGateHeadline` / `offerKycGateBody` / `gateStartKycCta` — i.e. it tells a
jeeber *"Get approved to start sending offers"* and labels its button *"Start
verification"*, then navigates to `jeeber-onboarding`, which is **registration,
not verification**. Verification is the *next* screen after it.

This predates MIDNIGHT (pass-1 shipped the reuse under an explicit "no copy
changed" rule) and it is a product-copy decision, not a restyle one, so this row
does **not** change it. The three call sites carry
`TODO(midnight): l10n-queued` and keep the current strings. Filed for the owner
alongside the row's questions.

`offerKycGateTitle` ("Verification required") in the top bar has the same
problem but is deliberately NOT queued: the prompt is reached from the gate and
the shared bar title is what makes the two read as one funnel. Renaming it needs
the headline decision first.

## Deliberately NOT queued

- **No "retry" string for the gate.** There is no retry affordance to name — see
  §2.
- **No empty-state copy.** Neither screen mounts a `JeebEmptyState`: the gate's
  content is always complete (R-F) and the prompt is static. See the row report.
