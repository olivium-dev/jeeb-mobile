# Wiring requests — w4 · dispute-status

**Nothing here blocks the lane.** `dart analyze lib/features/dispute_status` is clean and all 24
widget tests pass today: the two new strings live in the feature-local
`DisputeStatusL10n._pick(en, ar)` map, which is the mechanism that file was built around ("Delete
this file … once the integrator lands the requested keys" — `dispute_status_l10n.dart` header). This
request is the *append* to that standing JM-065 batch, not a new blocker.

### l10n — 2 keys (stepper node labels)

file: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart`

why: the redesign renders the dispute lifecycle as the board's node stepper (Submitted · Under
review · Resolved). The third node reuses the already-requested `Resolved` label; the first two are
new. Both are ≤ 2 words by design — a stepper label is 10.5/w700 in a ~62px column.

`app_en.arb` — add (append-only, next to the existing `disputeStatus*` block at ~line 4557):

```json
"disputeStatusStepSubmitted": "Submitted",
"@disputeStatusStepSubmitted": { "description": "JM-065 dispute lifecycle stepper, node 1 (dispute_status_step_submitted) — always complete." },
"disputeStatusStepUnderReview": "Under review",
"@disputeStatusStepUnderReview": { "description": "JM-065 dispute lifecycle stepper, node 2 (dispute_status_step_review) — active while the dispute is open. Short form of disputeStatusOpenLabel." }
```

`app_ar.arb` — add:

```json
"disputeStatusStepSubmitted": "تم الإرسال",
"disputeStatusStepUnderReview": "قيد المراجعة"
```

`app_localizations.dart` — add the two getters beside `disputeStatusOpenLabel` (hand-authored
runtime parser; **no `flutter gen-l10n`**):

```dart
String get disputeStatusStepSubmitted => _s('disputeStatusStepSubmitted');
String get disputeStatusStepUnderReview => _s('disputeStatusStepUnderReview');
```
(use whatever the file's own lookup helper is named — match the neighbouring `disputeStatus*`
getters verbatim.)

**On grant**, point the resolver at them — one-line edits inside this lane's own file
`lib/features/dispute_status/presentation/dispute_status_l10n.dart`:

```dart
String get stepSubmittedLabel => _l10n.disputeStatusStepSubmitted;
String get stepUnderReviewLabel => _l10n.disputeStatusStepUnderReview;
```

No other shared file is needed: no route, no DI, no theme, no kit, no pubspec change.
