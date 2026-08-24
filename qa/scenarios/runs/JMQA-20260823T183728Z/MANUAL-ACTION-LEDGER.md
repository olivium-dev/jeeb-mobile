# Physical A33 action ledger

> Run: JMQA-20260823T183728Z
>
> Device: Samsung Galaxy A33 (`SM-A336B`), Android 16 / API 36
>
> Package: `app.jeeb.mobile.clarityqa`
>
> Visible execution: 2026-08-23 19:03:48–19:10:57 UTC
>
> Control method: bounded manual exploratory navigation on the physical device
>
> Mutation result: **none**

> Authentication provenance: **the pre-existing session was created earlier
> through debug-only Super Login Plus and preserved by an in-place release-flavor
> update. Super Login Plus was not opened during this visible wave, but the wave
> depended on its session. This ledger is not valid authentication, role, or KYC
> sign-off.**

This is the sanitized action-by-action record of the corrective physical run.
The installed release-flavor Flutter UI did not export usable native semantics,
so visible coordinate taps were used only for known navigation controls. The
exact tap coordinates are deliberately not retained. No write, toggle, text
entry, upload, external handoff, delivery transition, or destructive action was
invoked.

The session provenance and its evidence impact are recorded in
[AUTH-PROVENANCE.md](AUTH-PROVENANCE.md).

The 21 rows are evidence checkpoints, not a claim that every intermediate
Android Back or tab-navigation tap was individually logged. Raw screenshots are
private because they include synthetic names, message content, precise location
data, or entity identifiers.

| # | UTC | Action preceding checkpoint | Observed physical result | Classification | Mutation |
|---:|---|---|---|---|---|
| 01 | 19:03:48 | Selected **Deliveries** from the five-tab shell. | Active delivery list rendered with one existing active card and Track action. | Reach evidence | None |
| 02 | 19:04:06 | Selected the **Completed** delivery segment. | Four existing completed cards rendered. | Reach evidence | None |
| 03 | 19:04:24 | Selected the **Cancelled** delivery segment. | One cancelled row rendered; Re-broadcast was visible and deliberately not pressed. | Reach evidence | None |
| 04 | 19:04:42 | Selected **Profile** from the shell. | Profile and its settings/security/notification/language/support rows rendered. | Reach evidence | None |
| 05 | 19:04:58 | Opened **Settings** from Profile. | Language and notification controls rendered; the Privacy & analytics heading had no analytics/consent control underneath it. | Reach + blocker | None |
| 06 | 19:05:20 | Returned through Profile and opened notification preferences. | Offers, order-status, wallet, rating-reminder, and security categories rendered. No switch was touched. | Reach evidence | None |
| 07 | 19:05:41 | Returned through Profile and opened Language. | English and Arabic choices rendered. Locale was not changed. | Reach evidence | None |
| 08 | 19:06:00 | Returned to the shell and selected **Earnings**. | Cash-collected, direct-payment, fee/accounting, wallet, and export surfaces rendered. | Reach evidence | None |
| 09 | 19:06:21 | Selected the Jeeber **Requests** dashboard. | The same screen said both “You're offline” and “you're online”; an existing At-door delivery was visible. | Finding DEF-004 | None |
| 10 | 19:06:35 | Selected **My Requests**. | Customer request surface rendered; all five additive shell tabs remained present. No request was created. | Reach evidence | None |
| 11 | 19:07:00 | Opened **Manage delivery** for the existing active item. | Active-delivery detail rendered at **At door**, with direct cash collection, proof/note, completion, Maps, and Chat controls. | Reach evidence | None |
| 12 | 19:07:19 | Opened **Chat** from that active delivery. | Chat rendered **In transit** and **Start delivery** for the same current delivery shown as At door immediately before. Nothing was typed or sent. | Finding DEF-001 | None |
| 13 | 19:07:41 | Delivered `jeeb://account-status` while Chat was foreground. | Intent was delivered but the app stayed on Chat. This route is account restriction/status, not the KYC status route. | Diagnostic | None |
| 14 | 19:08:01 | Returned to the shell and retried `jeeb://account-status`. | App remained/returned on the Requests dashboard. No KYC conclusion is drawn from this route. | Diagnostic | None |
| 15 | 19:08:40 | Navigated to Deliveries → Completed and opened one existing completed item. | Status was **Done** with “Delivered successfully”, but the page title remained **Active delivery**. | Finding DEF-005 | None |
| 16 | 19:08:54 | Opened **Chat** from that completed delivery. | Chat showed **Delivered** while still exposing **Offer accepted** and **Start delivery**; composer also remained visible. Nothing was typed or sent. | Finding DEF-002 | None |
| 17 | 19:09:15 | Returned to the shell and opened the notification inbox from the bell. | Seeded notification rows rendered. No row was opened or marked read. | Reach evidence | None |
| 18 | 19:09:31 | Returned and attempted a profile/detail navigation. | The resulting checkpoint was the Jeeber dashboard rather than profile detail. Because the path used manual coordinates and was not reproduced, this remains inconclusive. | Needs reproduction | None |
| 19 | 19:10:07 | Delivered the correct KYC URI, `jeeb://profile/kyc`. | Approved status rendered with feed, wallet, and top-up entry points. | Reach + policy review | None |
| 20 | 19:10:28 | Delivered the crafted terminal URI, `jeeb://kyc/rejected`, on the same unchanged shortcut-seeded session. | Final rejection and support-appeal UI rendered seconds after the canonical route displayed Approved; authoritative KYC state was not proven. | Finding DEF-003 | None |
| 21 | 19:10:57 | Pressed Android Back. | App returned to the Jeeber Requests dashboard in a safe, non-mutating state. | Safe final state | None |

## Safety and integrity checks

- The app process remained PID `5444`; the package was not restarted during the
  visible wave.
- The bounded log contained zero fatal exceptions, ANRs, `FlutterError` lines,
  or unhandled exceptions.
- Package exit history contained zero crash or ANR records for the wave.
- Text scans of the retained log and exit record found zero JWT-like strings,
  authorization headers, email-like strings, forbidden-host strings, or
  payment-gateway markers.
- Raw screenshots and logs remain private and expire on 2026-08-30 after review.

## What this run did not do

- No new request, offer, delivery, cancellation, re-broadcast, proof, OTP, COD
  completion, rating, or support ticket.
- No chat send or receiver-side delivery assertion.
- No KYC form submission, upload, resubmission, or appeal.
- No wallet/top-up action or payment-related network call.
- No preference, language, availability, notification, or analytics-consent
  change.
- No Maps, external provider, push-delivery, or Clarity-dashboard correlation.
