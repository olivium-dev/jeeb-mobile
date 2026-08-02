# Wave 15 (settings + transcription + auth) — defects surfaced

8/8 written, 43 previews. Includes NEGATIVE findings (explicit 'no RTL defect
found', 'no hardcoded English') — absence of a defect, reported as a result.
Recorded, not fixed.

## F01

LogoutDeleteConfirmSheet: `both` mode spins BOTH confirm CTAs for ONE action. `_confirmCta` (logout_delete_confirm_sheet.dart:275-302) passes `isLoading: _inFlight` to every CTA it builds, so tapping `logout_confirm_cta` starts a spinner on `delete_confirm_cta` as well — on the one sheet whose second action is irreversible, the surface reports that the act the user did not choose is also running. Pinned by a passing assertion in the test (2 CircularProgressIndicators, one of them inside Key('delete-confirm-cta')).

## F02

LogoutDeleteConfirmSheet: While clearing, NOTHING on screen names which act is in flight. `OmdsLoadingButton` renders the spinner *instead of* `text`, so 'Sign out' and 'Delete account' both disappear; the title above is still the generic sign-out title. Confirmed: find.text('Sign out') and find.text('Delete account') both findsNothing in the in-flight state.

## F03

LogoutDeleteConfirmSheet: `LogoutDeleteMode.both` offers the delete button with NO delete warning. In `both` mode the title/body are `signOutDialogTitle` / `signOutDialogBody` (isDelete==false, lines 169-175), so a user reaching `delete_confirm_cta` from the JM-062 profile-row entry never sees the E20 purge copy — no 30-day grace window, no 'active orders must be completed first', no sign-in-again reversal. The comprehension copy for the irreversible act is absent from the surface that offers it.

## F04

LogoutDeleteConfirmSheet: Delete mode overflows at 200% text and the CTAs are what is lost. Measured under flutter test at 390 pt wide: delete is 512 pt at 100% but 1168 pt at 200% (EN) / 928 (AR); at 320 pt it reaches 1416 pt. The body is a Column with mainAxisSize.min and no scroll fallback, and showModalBottomSheet(isScrollControlled: true) grants height, not scrolling — so against an 844 pt phone ~324 pt is below the fold, and that region holds `delete_confirm_cta` and `logout_delete_cancel_cta`. (Test font is wider than production Inter; treat as the pessimistic bound — the 320 pt figures are far past any font slack.)

## F05

LogoutDeleteConfirmSheet: CTA labels are clamped by a fixed 48 pt pill. `OmdsLoadingButton` is `height: Sizes.fourXLarge` (48) at every text scale with the label in a `Center`, no ellipsis and no growth. At 200% 'Delete account' measures 342x48 at 390 pt wide and 272x48 at 320 pt (AR 'تسجيل الخروج' likewise) — i.e. two lines exactly filling the pill edge to edge; one more line paints over the pill rather than wrapping it.

## F06

LogoutDeleteConfirmSheet: `_inFlight` is latched and never reset, and the cancel CTA is disabled while it is set. Both production entries go through `show()`, which pops in `onCompleted`, but `onCompleted` is an OPTIONAL constructor param — any host that omits it (or fails to dismiss) leaves a permanently spinning sheet with no way out. Visible in the canvas: tapping a confirm CTA in any preview leaves it spinning until hot restart.

## F07

BecomeJeeberCard: 200% TEXT WIPES THE CARD'S CONTENT: at 390 pt with textScaler 2.0 the CTA label grows to ~253 pt and the avatar+gutter take ~72 pt, driving the Expanded text column to ZERO width — 'Become a Jeeber' and 'Earn money delivering with Jeeb' render at 0 px wide (invisible, not merely clipped) — and the Row still overflows by 15 px (85 px at 320 pt; 14/84 px in Arabic). Measured, not inferred; pinned by a guard test in the preview test file.

## F08

BecomeJeeberCard: The card never achieves its ~80 pt design on a phone. Measured at 1x text, EN: 700 pt wide → text column 242 pt, title 1 line, card 96 pt tall; 390 pt → column 111 pt, title 3 lines, card 204 pt tall; 320 pt → column 41 pt, title SEVEN lines, card 412 pt tall (taller than it is wide). Same copy at all three widths, so this is a layout defect, not a copy-length one.

## F09

BecomeJeeberCard: Root cause is in _CardContent: one unwrapped Row of CircleAvatar + Expanded(text) + OmdsPrimaryButton. The avatar is fixed-size and OmdsPrimaryButton is built with `width: null` inside an AnimatedContainer, so it sizes to its label and, being a non-flex Row child, gets unbounded main-axis constraints — its label never wraps and it never shrinks. Every pixel lost comes out of the Expanded text. There is no Wrap/Column fallback and no maxLines/ellipsis on either Text, so the failure mode is silent shredding rather than truncation.

## F10

BecomeJeeberCard: No RTL defect found: the card uses only EdgeInsets.symmetric and a direction-aware Row, and the AR rendering is structurally identical (AR title is in fact shorter — 2 lines at 390 vs 3 in EN, card 164 pt vs 204 pt). The AR 200% case fails the same way as EN, for the same width reason, not a mirroring one.

## F11

BecomeJeeberCard: No hardcoded English in the widget: title, subtitle, CTA and the AC4 semantic label all come from ARB keys present in both app_en.arb and app_ar.arb.

## F12

ProfileAvatar: lib/features/settings/presentation/widgets/profile_avatar.dart:44 — the `Image.file` branch is given an `errorBuilder` but no `frameBuilder`/loading placeholder, while the `OmdsCachedImage` branch two lines below IS handed `placeholder: (_, _) => placeholder`. So a locally-picked avatar (the ONLY way photoUrl is ever set — JEBV4-13) paints a blank 96 dp hole until the read resolves, where a remote one shows the initial. Pinned: with a plain pump the local-path preview has zero Text widgets and only resolves to the 'K' bubble after real IO is allowed to run.

## F13

ProfileAvatar: lib/features/settings/presentation/widgets/profile_avatar.dart:62 — `_initial` takes `name` raw, with none of the `displayNameOrNull` suppression `ClientHomeGreeting` applies to the same string. A phone-only account carrying a synthetic `jeeb-<hash>` handle therefore renders a confident 'J' instead of the '?' the fallback exists for — an avatar that asserts a name for a user whose name is unknown. Same defect class already recorded on the sibling FeedbackAvatar. Pinned as a tripwire test.

## F14

ProfileAvatar: lib/features/settings/presentation/widgets/profile_avatar.dart:91 — `_InitialBubble` renders the letter at `displaySmall`, a flat 36 dp (44 dp line box) that ignores `diameter` entirely, so the public `diameter` knob shrinks the circle and nothing else: any caller passing under ~44 dp gets a glyph taller than its bubble. No shipping call site overrides the default 96 dp today, so this is latent, not live. Measured and pinned rather than previewed.

## F15

ProfileAvatar: Same fixed-vs-fluid mismatch at the accessibility ceiling: the initial scales with the text scaler (36x44 -> 72x88 dp measured) while the 96 dp circle does not, leaving 4 dp of clearance top and bottom, and `Container` sets no `clipBehavior`. It survives 200% text today by arithmetic (96 > 2x44), not by design — one step up the type ramp and the letter paints onto the page background.

## F16

TranscriptionStatusBanner: RTL/layout overflow (live): the Arabic Retry label overflows OMDSOutlinedButton's inner `Row(mainAxisSize: MainAxisSize.min)`, whose `Text` is not wrapped in a Flexible, so it cannot wrap or ellipsize. `إعادة المحاولة` is far wider than `Retry`, so only AR trips it: 320pt overflows from 1.15x (17px) and is 184px over at 2.0x; 360pt from 1.3x (6.8px), 144px over at 2.0x; 390pt from 1.5x (16px), 114px over at 2.0x. English is clean at every width/scale probed (320/360/390 x 1.0–2.0). The same banner MINUS the button is clean at 320pt/2.0x in Arabic, which isolates the defect to `_RetryButton` -> OMDSOutlinedButton, not to the title/body column. Pinned as a failing-when-fixed tripwire in the test.

## F17

TranscriptionStatusBanner: a11y (double announcement): `_BannerSurface` wraps the card in `Semantics(container: true, label: '$title. $body')` while leaving both `Text` children to contribute their own labels and without `excludeSemantics`. The merged node's label is literally 'Transcription unavailable. We couldn't reach the server. Type your request below or retry.\nTranscription unavailable\nWe couldn't reach the server. Type your request below or retry.' — TalkBack/VoiceOver read the whole banner twice. Fix is `excludeSemantics: true` or dropping the explicit label.

## F18

TranscriptionStatusBanner: Copy promises an affordance that never renders: `TranscriptionScreen` builds `TranscriptionStatusBanner(state: state)` with no `onRetry` (transcription_screen.dart:141), and `build` gates the button on `isFailed && onRetry != null`. So in the shipped flow the failed banner shows 'Something went wrong. Type your request below or retry.' / 'We couldn't reach the server. … or retry.' with nothing to tap. Either the screen should wire `onRetry` or the copy should stop saying 'or retry'.

## F19

TranscriptionTextPanel: Label row has no give and hard-overflows before the 200% ceiling. `_TranscriptionLabelRow` (lib/features/transcription/presentation/widgets/transcription_text_panel.dart:54-62) is a `Row` whose leading `Text(l10n.transcriptionFieldLabel)` is unconstrained (no Flexible/Expanded, no `overflow`) and whose trailing `TextButton.icon` label also cannot shrink. On the real screen the content width is 358 logical px (390pt phone, the screen's `ListView` padding of 16). Measuring the two children in that 358px box: 366px at 1.0x, 451px at 1.3x, 650px at 2.0x — i.e. a RenderFlex overflow stripe rather than an ellipsis, which is exactly what the matrix's `EN 200% text` rendering shows. Absolute numbers are inflated by flutter_test's fixed-width test font, but the structural defect (neither child can flex) is font-independent, and Arabic is no better (350 / 431 / 620). Nothing caught this because the existing `test/transcription_screen_test.dart` and the preview render tests both run on the 800x600 test surface, where the row fits with 400px to spare.

## F20

TranscriptionTextPanel: The transcript body ignores content direction, which is the app's main case. `_TranscriptionTextCard` renders a plain `Text`, so paragraph direction comes from the ambient `Directionality` (the UI locale), not the string. Lebanese users dictate Arabic with the app in English every day — the `Arabic transcript · English UI` preview shows that transcript laid out LTR-first, and a realistic mixed run ('كيلو بندورة من Spinneys') would have its segments reordered and its trailing punctuation flipped. The codebase already ships the fix and uses it for chat bubbles: `AutoDirectionText` in lib/features/chat/presentation/widgets/auto_direction_text.dart. The class doc's claim that 'an Arabic transcription renders right-aligned automatically' holds only when the UI locale is already Arabic.

## F21

TranscriptionTextPanel: The Edit icon does not scale with text. `Icons.edit_outlined, size: Sizes.large` is a fixed 20px at every text scale (measured constant at 1.0x, 1.3x and 2.0x) while its 'Edit text' label doubles, so at the accessibility ceiling the affordance is a doubled word next to an unchanged, comparatively tiny glyph.

## F22

TranscriptionAudioCard: LAYOUT — the card does not shrink-wrap; it fills whatever height it is given. `_PlaybackProgress` builds its Column at the default `MainAxisSize.max` (lib/features/transcription/presentation/widgets/transcription_audio_card.dart:73), so the card's height is its incoming `maxHeight`, not its content height. Measured at 390 pt wide on a 400 pt slot: 390x400 with the progress bar stranded at y=16 while the Row centres the 64 pt icon at y=168 — 150 pt of empty card between the two halves of one control, with no exception and no overflow stripe. It only looks correct in production because its single call site (`_TranscriptionBody`'s ListView) hands it an unbounded main axis, where it settles at 390x96 (bar y=32, icon y=16). Pinned by the 'in a height-bounded slot the card stretches' test; `transcriptionAudioCardBoundedSlot` shows it in the canvas.

## F23

TranscriptionAudioCard: CONTRAST — at 0% progress the scrubber is effectively invisible. The track is `colorScheme.outline` at 20% alpha over `surfaceContainerHigh` (transcription_audio_card.dart:81), which resolves to 1.24:1 in AppTheme.light() and 1.36:1 in AppTheme.dark() — well under the 3:1 WCAG 2.2 §1.4.11 asks of a meaningful graphic. The filled portion is fine (11.23:1 light / 6.25:1 dark against the track), so this is specifically 'the empty part of the bar cannot be seen'. That makes the idle state — the one every user meets first, where progress is exactly 0.0 — a card whose 8 pt scrubber renders as blank surface. Pinned numerically by the WCAG test in the suite.

## F24

TranscriptionAudioCard: RTL — the mirroring is half-done. `LinearProgressIndicator` flips its fill in RTL (SDK `_LinearProgressIndicatorPainter.drawBar`), and the unpinned `'${position} / ${total}'` string bidi-reorders in step with it (measured in AR: elapsed at x 220.5–278.0, total at 128.5–186.0, against 0.3–57.8 / 92.3–149.8 in EN) — both correct. But `Icons.play_circle_filled` / `Icons.pause_circle_filled` carry no `matchTextDirection` (transcription_audio_card.dart:53), so no flipping Transform is inserted and the play triangle keeps pointing right while the playhead it controls now travels leftwards. The two halves of one control disagree about which direction 'forward' is in Arabic.

## F25

TranscriptionAudioCard: STATE — the toggle is never disabled and the card has no 'unplayable audio' treatment. `IconButton.filled`'s `onPressed` is unconditionally non-null (transcription_audio_card.dart:51), so the control looks live even when `state.playbackPath` is a bare gateway audioId with no `localAudioPath` (JEBV4-13, the cold-deep-link / rehydrated-clip case). `TranscriptionCubit.togglePlayback` catches the failure and resets `isPlaying`, so the user gets a fully-styled filled button whose tap does nothing and says nothing. This also contradicts `NoopTranscriptAudioPlayer`'s own doc comment in transcript_audio_player.dart, which claims 'the screen degrades to a disabled control'.

## F26

TranscriptionAudioCard: STATE — `hasAudio && audioDuration == Duration.zero` is reachable and renders as an empty recording. `VoiceRecordingScreen`'s listener forwards `duration: state.clip?.duration ?? Duration.zero` alongside a valid upload id (lib/features/voice_request/presentation/voice_recording_screen.dart:144), so a released recorder clip produces audio-on-file with an unknown length. The card then shows `00:00 / 00:00` over a determinate empty bar — pixel for pixel what a zero-length recording looks like. There is no indeterminate or 'length unknown' treatment; the `total.inMilliseconds == 0` branch is only a divide-by-zero guard, not a UI decision.

## F27

TranscriptionAudioCard: A11Y — the progress bar announces a bare number. No `semanticsLabel` is passed to `LinearProgressIndicator`, so the semantics tree carries `role: progressBar, value: "40", label: ""` with no indication of what is at 40%. The read-out below it is a separate unlabelled node reading the raw `00:17 / 00:42`. The play/pause button itself is correct — localized label (`Play original` / `Pause` / `إيقاف مؤقت`) and a stable `voice_transcript_audio_toggle` identifier.

## F28

SocialSignInSection: Apple glyph is invisible in the default light rendering. lib/features/auth/social/social_sign_in_button.dart:138 passes `color: isDark ? _appleBrandBlack : _appleBrandWhite` — inverted relative to its own comment two lines above ('black glyph on the light button') — and OMDS no longer ships a black Apple slab: `OmdsSocialButtons._branded` (omds_library/lib/src/buttons/omds_social_button.dart) hardcodes `backgroundColor: Colors.white` and ignores `isDark`. Measured in the light preview: glyph #FFFFFFFF on a #FFFFFFFF pill. Only the AR-RTL-dark rendering shows an Apple mark at all (black on white).

## F29

SocialSignInSection: At 200% text the button label paints outside its pill and over the neighbouring one. `OmdsSocialButton` hardcodes `height: Sizes.fourXLarge` (48dp), so at textScaler 2.0 the pill stays exactly 48dp while the label's min intrinsic height at its 310dp width is 80dp; the paragraph is laid out at 310x22, there is no ClipRRect between paragraph and pill, and RenderParagraph raises no overflow error — so nothing (goldens, tests, CI) catches it, and the two pills sit only 12dp apart. This is precisely what the harness's `EN 200% text` rendering is for.

## F30

SocialSignInSection: The blocked second provider has no visual disabled state. The section passes `isEnabled: !state.isBusy`, but `SocialSignInButton` only forwards that to `Semantics(enabled:)` and to a no-op `onTap`; `OmdsSocialButtons.google/apple` never receive `isEnabled`, so during an in-flight sign-in the other pill renders at full contrast with a live-feeling (but dead) tap target. Screen-reader users are told it is disabled; sighted users get no feedback at all. Verified in the 'Google in flight' preview and pinned by the semantics test.

## F31

SocialSignInSection: The busy label is a bare '…' with a stale semantics label. `isBusy ? '…' : l10n.registrationContinueWith…` replaces the whole visible label — no spinner, no localized 'Signing in…' — while the `Semantics(label:)` still reads 'Continue with Google'. A voice-control user who says the label they were given targets a control whose visible text no longer exists and which is disabled.

## F32

SocialSignInSection: The Apple/non-Apple split is not previewable and its web branch is dead code. `SocialSignInButton.isAppleAvailable()` reads `dart:io`'s `Platform` statically with no injectable seam, so the Android rendering (Google alone, no Apple pill, no 12dp gap) cannot be rendered in the canvas or pinned in a test — every preview here shows the iOS/macOS two-pill layout. The same file's top-level `import 'dart:io'` also means the file can never compile for web, so its own `if (kIsWeb) return false;` guard is unreachable, and the widget cannot load in the Chrome-hosted canvas lib/previews/README.md describes. I did not add the seam.

## F33

SocialSignInButton: Apple mark is invisible in the light theme (contrast 1:1). `build` paints the glyph `isDark ? black : white`, but since OMDS P0-X02 `OmdsSocialButtons.apple` ignores `isDark` and always renders the white brand-neutral pill — so light theme = white glyph on white pill, dark theme = the only readable one. The source comment at social_sign_in_button.dart:134-136 describes the opposite of what the code does. Pinned in the test's `brand skin` group (light: glyph #FFFFFF == pill #FFFFFF; dark: glyph #000000).

## F34

SocialSignInButton: `isEnabled: false` has almost no visual. `OmdsSocialButtons._branded` never forwards `isEnabled` to `OmdsSocialButton`, so the OMDS disabled skin (60% alpha pill, 38% alpha label) is unreachable: disabled and idle paint an identical pill/border/radius/label — only the Google/Facebook glyph disc turns grey, and the Apple button has no disabled treatment at all. Worse, `effectiveOnTap = () {}` is non-null, so the GestureDetector still consumes the tap: the user gets no dimming, no press feedback and no explanation.

## F35

SocialSignInButton: At 200% text the label is silently clipped, not enlarged. The pill is a hard 48 dp (`Sizes.fourXLarge`) and `OmdsSocialButton` spends 26 of it on `Spacing.small` vertical padding + the 1 dp border, leaving the label a 22 dp box at every text scale. Measured: at 2.0x the paragraph's intrinsic height is 120 dp and it is laid out into 22 dp — ~80% of the label is cut off. `Text` defaults to `TextOverflow.clip`, so nothing throws and no overflow stripe appears; this is invisible to the existing golden/analyzer checks.

## F36

SocialSignInButton: Busy state is not communicated. The label is replaced by a hardcoded `'…'` literal (not localized, not a spinner/`OmdsLoadingButton`), the pill does not dim, and the accessibility announcement still leads with 'Continue with Google' — only the `isEnabled` flag changes. A screen-reader user gets no signal that the native sheet opened.

## F37

SocialSignInButton: The decorative brand glyph is announced as content. `Semantics(label: …)` is set without `excludeSemantics: true`, so it merges its children instead of replacing them: the real semantics label is 'Continue with Google\nG\n…' (i.e. TalkBack reads 'Continue with Google, G, …'). The `_GoogleGlyph`/`_FacebookGlyph` `Text` widgets need an `ExcludeSemantics` (or the wrapper needs `excludeSemantics: true`).

## F38

SocialSignInButton: The Facebook button never names its provider — visible label and semantics label are both the generic `actionContinue` ('Continue' / 'متابعة'), so a screen reader announces 'Continue, button' with no provider, and sighted users have only the small 'f' disc. Already flagged in the source comment (no `socialContinueWithFacebook` key exists), confirmed here.

