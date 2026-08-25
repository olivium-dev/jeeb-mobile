# Verified lessons

Lessons enter this file only after evidence, scope, and reproduction or
independent review are recorded.

## LSN-001 — preserve state with ephemeral semantic slices

No checked-in Maestro flow is safe as a whole against this authenticated
release-state device. Existing flows either clear app state, depend on debug-only
seams, use the older live/coordinate harness, or perform a write. The approved
shape is a temporary semantic-only R0 slice with no `clearState`.

## LSN-002 — the current physical release lane is not automatable yet

Maestro 2.0.5 rejected the ADB-online physical serial, and one bounded
UiAutomator lookup exposed no expected shell semantic resource. This is a
testability blocker, not evidence that the product screen failed.

The later visible coordinate-based wave is valid exploratory evidence, but it
does not resolve this repeatability/accessibility blocker and must not be called
automated release coverage.

## LSN-003 — package hash, signer hash, and source provenance are separate

The installed APK exactly matches the known `clarityqa` release artifact, but it
uses an Android debug certificate and cannot be tied to a clean source commit.
Those facts support functional identity only, not release sign-off.

## LSN-004 — evidence cannot be merged across artifacts

Earlier delivery/chat coverage used a different package/hash. It is useful
supporting context but cannot produce a PASS for this run. Earlier same-hash
Clarity QA evidence supports only the exact screens and states it recorded.

## LSN-005 — summary telemetry must be reconciled against retained raw samples

Several earlier memory summaries disagree with their retained raw files, and a
signer hash was mislabeled as an APK hash. Future reports must generate summary
rows mechanically from timestamped raw evidence.

## LSN-006 — a blocked harness and a blocked physical run are different states

The automated phase ended with zero UI actions, but the authorized A33 remained
available for visible, bounded, non-mutating exploratory navigation. Reports
must state these phases separately so “automation blocked” is never mistaken
for “the phone was tested” or “the phone could not be tested”.

## LSN-007 — terminal deep links require authoritative state gates

Rendering a terminal KYC screen directly from a route can create a false account
decision even if the screen later fetches optional details. The route must first
validate the current state and redirect or recover before any terminal copy is
shown.

## LSN-008 — screenshot conclusions require coordinator visual verification

An independent analysis incorrectly described the five-tab shell as collapsing
to two tabs. Coordinator review of the original checkpoint showed all five tabs
present. Multi-agent observations are inputs to shared memory, not final truth;
the coordinator must verify decisive visual claims against the source artifact.

## LSN-009 — one status vocabulary is not enough without one status source

Delivery detail and Chat can share labels yet still disagree if they resolve
lifecycle state from different records or gate actions from conversation phase
alone. Physical regression must compare the same delivery across dashboard,
detail, chat, tracking, and the paired actor before and after every transition.

## LSN-010 — release UI does not prove release authentication provenance

Installing a release-flavor APK in place can preserve package data and an
authenticated session created earlier by a debug-only launcher. The absence of
Super Login Plus from the currently installed binary therefore does not prove
that the run used normal authentication.

Every physical run must record the complete authentication chain: clean install
or data reset, exact artifact, login entry point, fixture identity alias, OTP
method, selected role, and authoritative role/KYC read-back. A shortcut-seeded
session is reach evidence only and cannot sign off authentication, role, KYC, or
an end-to-end happy path.
