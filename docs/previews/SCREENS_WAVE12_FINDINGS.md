# Screens wave 12 — findings (final wave)

`SupportTicketScreen`, `TierSelectionScreen`, `TranscriptionScreen`.
3/4 written, 25 previews. `VoiceRequestScreen` was refused and excluded —
it is `build => VoiceRecordingScreen(onSent: onSent)` and nothing else, and
`VoiceRecordingScreen` already carries 9 previews, so a preview here would be
a second copy of those states under a different name.

29 findings. Nothing here was fixed.

Pixel figures were measured with the real fonts loaded. See
FINDINGS_TRIAGE.md §6.

## SupportTicketScreen

1. The details field cannot show the text the ticket is submitted with.
   `_BodyField` builds an `OmdsTextField` with an `onChanged` and no
   `controller`, and `OmdsTextField` has no `initialValue` (it forwards
   `controller` straight to `TextField`), so nothing can seed it. The Screen
   Catalog's own 'Form — ready to submit' state therefore renders an EMPTY
   details box above a live Submit button. Pinned by
   `supportTicketScreenReadyToSubmit`.

2. The same gap eats real user input on the error path. `retryFromError()` only
   flips the phase to `inputting`; the `BlocBuilder` swaps `_ErrorView` for a
   FRESH `_SupportForm`, so `_OrderLinkField` (a StatefulWidget seeded from
   `state.orderRef`) comes back with its value and `_BodyField` comes back
   empty — while `SupportState.body` still holds the text, `canSubmit` is still
   true and the next tap re-sends copy the user can no longer read or correct.
   Two fields on one form, two different contracts. Pinned end-to-end by the
   retry test on `supportTicketScreenSessionExpired`.

3. The one required field is labelled '(optional)'. `canSubmit` is `category !=
   null && body.trim().isNotEmpty`, but `_BodyField` uses
   `escalateCommentLabel` — 'Additional details (optional)'. The disabled
   Submit gives no reason and nothing else on the form names the missing input.

4. A selected category can be invisible while Submit stays enabled.
   `_CategoryField._visibleCategories` filters `payment` and `kycAppeal` out
   for anyone without the `jeeber` role, but `SupportCubit` holds whatever it
   was given — including from a deep link, a restored draft, or the catalog's
   own 'Error — network failure' state, which seeds `payment`. Result: no radio
   filled, live CTA. Pinned by `supportTicketScreenHiddenCategory`.

5. Four of the six category labels are borrowed from unrelated screens.
   `_CategoryTile._label` maps `account` → `customerProfileSectionSupport`
   ('Support', the same string as the section heading directly above the list),
   `payment` → `navEarnings` ('Earnings', a jeeber nav label), `delivery` →
   `navDelivery`, `dispute` → `disputeStatusSupportCta` ('Contact support' —
   this screen's own app-bar title). A client sees 'Contact support' over a
   heading 'Support' over an option 'Support', and describes a problem by
   choosing between 'Earnings' and 'Delivery'. The test asserts
   findsNWidgets(2) for both duplicated strings.

6. The order-reference input is labelled 'Your Orders' (`ordersTitle`, the
   order-HISTORY screen title). Nothing says what to type or where to find it.

7. Every attachment chip claims to be the whole count. `_AttachSection` labels
   chip i with `escalatePhotoAttached(i + 1)` — the plural '{count} of 5
   attached' — so five photos read '1 of 5 attached' … '5 of 5 attached' side
   by side. At the cap the 'Add photo' button also disappears silently (`if
   (paths.length < 5)`) with no message anywhere saying the limit is why.

8. The confirmation never shows the ticket reference. `SupportCubit` stores
   `ticketId` from the created `SupportTicket`; `_ConfirmationView` renders the
   escalation flow's fixed copy ('Report submitted', 'Our team will review your
   case…') plus a Done button, so a support ticket confirms itself as a report
   and the user leaves with nothing to quote.

9. The error page's CTA says 'Submit' and does not submit. `_ErrorView` labels
   its button `supportSubmitCta` with a refresh icon and wires it to
   `retryFromError()`, which only returns to the form. The draft is intact in
   the cubit and one call away.

10. A 401 is indistinguishable from 'something went wrong'.
   `_ErrorView._message` folds `SupportFailure.unauthorized` in with `unknown`
   and `null`, so an expired session reads "Couldn't submit. Please try again."
   over a button that cannot recover a session; the card is pixel-identical to
   an unclassified failure.

11. The offline copy promises an automatic retry that does not exist.
   `escalateErrorNetwork` reads 'No internet connection. Your report will be
   retried automatically.' Nothing in `SupportCubit` queues, persists or re-
   sends the draft — the phase goes to `error` and stays there.

12. 'Open a dispute instead' routes to a literal underscore. `_DisputeLink`
   substitutes `'_'` when the order field is empty and pushes
   `/orders/_/escalate`, so the most common case (no reference typed) deep-
   links the escalation flow to an order id that cannot exist. The link is
   offered unconditionally on every form card.

## TierSelectionScreen

1. lib/features/tier_selection/presentation/tier_selection_screen.dart:39 —
   `static const Key retryButtonKey = Key('tier-selection-retry')` is published
   and attached to NOTHING. `_Body` hands `onRetry` to `OmdsErrorState`, which
   builds its own unkeyed `FilledButton.icon`, so
   `find.byKey(TierSelectionScreen.retryButtonKey)` finds nothing on the error
   state. test/tier_selection_screen_test.dart:158 already works around it in a
   comment ('match the FilledButton supertype'). Pinned by the new render test.

2. lib/features/tier_selection/presentation/tier_selection_screen.dart:141 —
   `_CachedBanner` is unreachable dead UI. It renders when
   `state.usingCachedFallback` is true; `TierSelectionCubit` writes
   `usingCachedFallback: false` on all three of its emits (cubit lines 20, 43,
   55) and `true` on none, so neither the widget nor its live ARB string
   `tierSelectionCachedBanner` ('Showing cached options — prices may differ',
   EN+AR) can ever appear in the app. Residue of JEBV4-300, which removed the
   cached-catalog fallback. The preview has to SEED the state to draw it; the
   test asserts no cubit-driven path can raise it.

3. lib/features/tier_selection/presentation/tier_selection_screen.dart:118 —
   `_Body` ignores `state.failure` and always renders
   `l10n.requestSummaryErrorNetwork` ("Couldn't reach Jeeb. Check your
   connection and try again."). A `TierLoadFailure.server` — a 5xx, or a body
   `DioTierRepository._parseResponse` cannot recognise — therefore tells the
   customer to check a working connection and retry an operation that will fail
   identically. The test pumps both failures and asserts the rendered copy
   lists are equal, word for word. The sentence is also borrowed from the
   request_summary feature, so it names a submit problem on a screen that has
   not submitted anything.

4. A `200 OK` with zero tiers is a silent dead end. It lands in
   `TierSelectionStatus.loaded`, so the screen renders the subtitle 'Price
   varies by Jeeber' over an empty `ListView` with a Confirm button that can
   never enable — no message, no retry, no way forward (screen lines 141-183).
   Not hypothetical: `DioTierRepository._tierIdFromLabel` silently drops every
   tier whose `name` this client cannot map, so a server-side tier rename
   empties the screen through the SUCCESS path, one tier at a time.

5. lib/features/tier_selection/presentation/tier_selection_screen.dart:175 —
   the Confirm CTA never announces an enabled/disabled state.
   `Semantics(identifier: 'tier_selection_confirm_cta', container: true,
   button: true)` carries no `enabled:`, and `OmdsPrimaryButton` is a bare
   `GestureDetector` underneath, so with nothing selected the node is
   `isButton: true` / `isEnabled: Tristate.none` — a screen reader reads an
   ordinary button that silently does nothing. Pinned in the render test at the
   served-catalogue and empty states.

6. Confirming the SAME tier twice fires `onConfirmed` once.
   `TierSelectionCubit.confirm()` (cubit:71) re-emits a state that is `==` to
   the current one, `Cubit.emit` drops it, and the `BlocConsumer.listenWhen` at
   screen:87 never runs — so an enabled CTA does nothing on its second press
   unless the customer changes tier first. The preview host records every
   callback into `tierSelectionScreenConfirmations`; the test presses Confirm
   twice and finds one entry.

7. `TierSelectionScreen` is not mounted by any route. Outside its own file and
   `lib/devtool/` (the Screen Catalog), nothing in `lib/` references it —
   `lib/core/router/app_router.dart:1105` serves `RequestTypeScreen` for the
   tier step instead. The screen, its cubit, its 6-test suite and its catalog
   entry are all live, but no customer can reach this UI; the two screens now
   carry two divergent tier-picking implementations (this one shows real
   gateway prices/SLAs, RequestTypeScreen discards everything but `tier.id`).

## TranscriptionScreen

1. DEAD END — the queued/empty state asks the user to type and gives them
   nowhere to type. `_TranscriptionLabelRow` (lib/features/transcription/presen
   tation/widgets/transcription_text_panel.dart) gates the 'Edit text' action
   on `showEdit: state.text.trim().isNotEmpty`, and
   `TranscriptionCubit.startEditing()` has no other caller — so the editor is
   unreachable exactly when the transcript is EMPTY, which is the only time the
   user must write the request by hand. The queued banner says 'You can type
   your request now to keep moving', the panel shows the 'Type your request
   here' placeholder, and that placeholder is a plain `Container`, not a field.
   Send is disabled (`canConfirm` is false on empty text), so Re-record is the
   only live control left. Reachable from the shipped flow in one step:
   `test/transcription_screen_test.dart` already drives edit → clear → Done and
   asserts the queued banner comes back — that user has locked themselves out
   of the field they were just using.

2. Every `Failed` state carries the same dead end, where it costs more:
   `transcriptionFailedNetwork` reads 'We couldn't reach the server. Type your
   request below or retry.' and there is neither a field to type in nor a Retry
   button. `_TranscriptionBody` builds `TranscriptionStatusBanner(state:
   state)` with NO `onRetry` (transcription_screen.dart), and the banner gates
   its button on `isFailed && onRetry != null` — so the copy's 'or retry'
   points at nothing on the shipped screen.

3. `_ReRecordButton` (transcription_screen.dart) hardcodes `textColor:
   Theme.of(context).colorScheme.onPrimary` onto an `OMDSOutlinedButton`, whose
   background is `colorScheme.secondaryContainer`. In the light theme that
   pairing is a deliberate workaround and it works — #FFFFFF on #0B1351,
   17.13:1. In DARK it becomes #252B61 on #444559 = 1.40:1, against the 4.5:1
   WCAG 2.2 §1.4.3 asks of body text: the Re-record label is effectively
   invisible. `onPrimary` is the wrong role for a `secondaryContainer` surface,
   and the truncated comment above the line points at the queued banner in
   transcription_status_banner.dart, which fixed the same problem by moving to
   a semantic role pair instead. Measured through `withGoldenTestFonts` with
   the real theme; pinned in the test.

4. `_TranscriptionLabelRow` overflows at 200% text. It is a
   `MainAxisAlignment.spaceBetween` Row whose two children — the
   'Transcription' label and the 'Edit text' `TextButton.icon` — are neither
   `Flexible` nor ellipsized, so both are laid out at full intrinsic width.
   With real fonts on a 320 pt device (288 pt usable after `Spacing.medium`
   either side): EN wants 178.4 + 141.9 = 320.3 (32 px over), AR wants 177.7 +
   162.0 = 339.7 (52 px over). AR starts breaking at 1.75x; EN clears at 360
   pt, AR needs 390 pt. It only bites the states that HAVE a transcript, which
   is why the two states a reviewer opens first to check the error copy
   (queued, failed) cannot reproduce it.

5. Entering edit mode removes both bottom actions and offers no discard path.
   `_TranscriptionActions` returns `SizedBox.shrink()` when `state.isEditing`,
   so Send and Re-record both vanish and 'Done' is the only control;
   `confirmEdit` commits the field verbatim, so there is no Cancel and no way
   to abandon an edit — including the cleared-field case, which drops the user
   into the unreachable-editor queued state above.

6. The no-audio case (`hasAudio == false`) drops `TranscriptionAudioCard`
   silently — nothing on the screen says the recording did not survive — and
   Send stays enabled, firing `onConfirm(text, state.audioPath ?? '')` with an
   EMPTY audio path.

## VoiceRequestScreen

1. voice_request_screen.dart:26 — VoiceRequestScreen adds ZERO behaviour over
   its delegate. `build => VoiceRecordingScreen(onSent: onSent)` forwards its
   only parameter and nothing else; it does not even choose the collaborators,
   because VoiceRecordingScreen already falls back to `_buildProductionCubit()`
   when `cubit == null`. The class is a pure alias, and both routes that mount
   it (app_router.dart:1070 `/voice-request`, :1184 `/compose-dictation`) would
   behave identically pointed straight at VoiceRecordingScreen.

2. voice_recording_screen.dart:108-111 — the cold-DI fallback silently
   constructs a LIVE repository and renders without throwing. With nothing
   registered in `sl`, `_buildProductionCubit()` builds
   `HttpVoiceRecordingRepository(dio: resolveGatewayDio())`, and
   `resolveGatewayDio()` (injection_container.dart:134-137) returns
   `MockGatewayClient.createDio()` — which despite the name is a real Dio
   pinned to `http://192.168.2.39:10090`, the live MSI gateway
   (mock_gateway_client.dart:21-23). I pumped `VoiceRequestScreen` under
   `jeebPreviewHost` with an empty GetIt: no exception, all four idle strings
   render. So a dev surface hosting this screen looks completely correct while
   holding a live-gateway uploader plus a real `record`-plugin
   `RecordVoiceRecorder` and a real `AudioPlayersVoicePlayer`; the only thing
   standing between a mic press and `POST` at the live gateway
   (voice_recording_repository.dart:55) is CatalogNetworkGuard's non-GET
   rejection — the net, doing the plan's job.

3. Neither dev surface renders the class the router actually mounts. The Screen
   Catalog entry (batch_11_entries.dart:432-459) and all nine previews build
   `VoiceRecordingScreen(cubit: …)` directly, so the 5 designer states and the
   9 engineer states all bypass `VoiceRequestScreen` — the same shape as
   docs/previews/FINDING_location_picker_placeholder.md, where the router
   served one class and the dev surfaces drew another. Here the pixels happen
   to match, but the one code path unique to the mounted class (collaborator
   selection, i.e. the defect above) is the one path no dev surface exercises.

4. tool/preview_exclusions.txt already excludes `CaptureLocationRoute` for `#
   /capture-location route host; renders CaptureLocationScreen verbatim`.
   `VoiceRequestScreen` fits that rule word-for-word and is the stronger case
   (it does not even carry the route's pop behaviour), yet it sits in the
   uncovered queue where it costs an agent a full investigation. If the team
   does not intend to add the `cubit:` seam, the honest resolution is deletion
   or exclusion, not a preview.
