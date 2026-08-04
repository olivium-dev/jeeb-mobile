# l10n queue — M3-04 · Cancellation (tile-less, derived from R9)

Three keys. All three have a live call site **today** rendering the nearest
existing key with a `TODO(midnight): l10n-queued` marker, so wiring them is a
one-line swap per site — no gate, no blocked wire data.

| Key | EN | AR |
|---|---|---|
| `cancellationTooLateHeadline` | `Too late to cancel` | `فات الأوان على الإلغاء` |
| `cancellationTooLateBody` | `Your Jeeber is already on the way.` | `السائق في الطريق إليك.` |
| `cancellationErrorNote` | `Couldn't cancel — please try again.` | `تعذّر الإلغاء — يُرجى المحاولة مرة أخرى.` |

## Why the split

`cancellationTooLate` is one sentence with an em-dash:
`Too late to cancel — your Jeeber is already on the way.` /
`فات الأوان على الإلغاء — السائق في الطريق.`

M3-04 promotes the 409 lane from a vanishing snackbar to the screen's **empty
family instance** — a `JeebEmptyState(variant: street)`. That widget takes a
`headline` (`h1`, 26/w700) and an optional `body` (`body`, 14.5/w500 muted), so
the one sentence has to split across the two ink rungs or it renders as a
three-line 26px headline. The two new keys are the *same copy*, cut on the
existing em-dash — no new product statement.

Interim: `headline: l10n.cancellationTooLate`, `body: null`, tagged
`TODO(midnight): l10n-queued` in
`lib/features/cancellation/presentation/cancellation_screen.dart`.

## Why `cancellationErrorNote`

The 5xx lane was also a snackbar and is now a persistent `JeebInfoNote.error`
strip above the CTA. `cancellationGenericError` (`An unexpected error
occurred.`) is a *dialog-era* string: it names no subject and offers no
recovery, which is exactly what a docked strip the user is staring at needs.
The new key states the subject and the recovery.

Interim: the strip renders `cancellationGenericError`, tagged
`TODO(midnight): l10n-queued` at the same call site.

## Not queued (deliberate)

No destructive-consequence panel copy is requested. `deliveryCancelDialogBody`
("Your Jeeber will be notified. Cancellation fees may apply…") exists and reads
well, but this screen serves **both** roles and that sentence is client-shaped —
a Jeeber cancelling is not told "your Jeeber will be notified". Inventing a
role-neutral twin on a screen the board never drew would be design invention,
so the screen ships without the panel. Raised as an owner question instead.
