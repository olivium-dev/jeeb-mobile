# 13 · OTP handover — REVISED instruction set (authoritative)

**Target files (this lane owns):** `lib/features/otp_handover/**` (screen 589 LOC, cubit 192,
state 73, `widgets/handover_code_display.dart` 74) + this screen's tests
(`test/otp_handover_screen_test.dart`, `test/otp_handover_cubit_test.dart`,
`test/otp_handover_loop_nav_test.dart`).
**Verdict: rebuild of the client `ready` surface; restyle of done / SMS-fallback / jeeber-entry;
loading and error bodies untouched.** Reviewed against `screens/13-otp-handover.{png,html,note.md}`,
the full live source, all 7 test files that touch this feature, the kit **source** in
`lib/core/widgets/jeeb/` (not just `03-WAVE1-KIT.md`), the OMDS clone, `_BASELINE.md`, and both
plan documents. Every `file:line` below was re-checked on 2026-08-03. Where this document differs
from the Opus proposal, **this document wins**.

**Wave 0 + Wave 1 are SHIPPED.** This lane imports, never re-creates:
`JeebTopBar`, `JeebAccentFrameCard.filled`, `JeebAvatar` (fill `onAccent` — already in the enum,
`jeeb_avatar.dart:31`), `JeebCodeCells.display` (+ its public `inputBoxWidth = 68` /
`inputBoxHeight = 74` / `inputCellGap = 12` consts — the kit doc says verbatim they are *"public
so 13's jeeber leg can size its own OmdsOtpInput"*), `JeebInfoNote`, `JeebCtaButton`
(`isLoading` exists), `JeebCtaFooter.single`. Import via
`import '../../../core/widgets/jeeb/<file>.dart';`.

---

## A. Deltas from the Opus proposal (audit trail — implementer follows THIS doc)

**Cut / overruled:**
1. **The entire kit wiring request (§11.3 of the proposal) — VOID.** All three asks already
   shipped: `JeebAvatarFill.onAccent` (`jeeb_avatar.dart:13-31`, built for this exact banner),
   `JeebCodeCells.display` + public `inputBoxWidth/inputBoxHeight/inputCellGap` consts
   (`jeeb_code_cells.dart:106-118,146-158`), `JeebCtaButton.isLoading`
   (`jeeb_cta_button.dart`, kit §2.2). The kit is frozen and needs **zero changes** for this
   screen. Only two wiring requests survive: l10n and the one-line router arg (§F).
2. **Restyling the `_ErrorBody` / loading bodies — CUT.** The proposal's "all five stop centring"
   over-reads R1. The board does not draw error or loading; `OmdsErrorState`/`OmdsLoadingState`
   centred is the app-wide idiom and 11-revised kept it. Only the four content bodies
   (`_ClientOtpDisplay:332`, `_ClientSmsFallback:268`, `_DoneBody:171`, `_JeeberOtpEntry:432`)
   go top-aligned.
3. **The proposal's §2 token table for `handover_code_display.dart` — SUPERSEDED.** Do not restyle
   the non-compact `Container` (fill/radius/shadow/letter-spacing rows): the branch **delegates to
   `JeebCodeCells.display`**, which owns all of that (74×92 r20 navy, `statDisplay`, `heroNavy`,
   LTR isolate, `FittedBox(scaleDown)`). The file keeps only the semantics wrapper + the frozen
   compact branch.
4. **`otpArrivalSubtitleNoCash` l10n key — CUT.** A `{vehicle}`-only string translates nothing.
   When `cashAmount == null`, render `arrival.vehicleLabel` directly (server copy, no l10n wrap).
5. **Reusing `otp_sms_resend` for the new code-surface SMS link — OVERRULED.** Hard constraint 1:
   NEW interactive widgets get `<screen>_<element>` ids. The new link is
   **`otp_handover_send_sms`**; `otp_sms_resend` + `Key('otpHandover.resendSms')` stay exclusively
   on the fallback surface's resend button (the G4 test contract,
   `otp_handover_screen_test.dart:100,122`).
6. **Dispute pill at h52 — normalized to the kit's outline scale.** `JeebCtaButton.outline`
   default (`outlineHeight = 50`, 1.5px `colorScheme.outline`, 13.5/w600 primary ink). The HTML's
   52/15px is a 2px/1.5px delta; per `03-WAVE1-KIT.md` header, the kit wins over per-screen pixel
   readings. No `height:`/`labelStyle:` overrides.

**Corrected (factually off in the proposal):**
1. `JeebTopBar` has **no `onLeadingTap`** — the parameter is **`onLeadingPressed`**
   (`jeeb_top_bar.dart:112`). And the claim "no maybePop default to inherit" is wrong: the kit
   defaults to `Navigator.maybeOf(context)?.maybePop()` (`jeeb_top_bar.dart:85-86`). The explicit
   handler is still required, for the right reason: `maybePop` is a silent no-op when this screen
   is the stack root (deep link / `context.go` entry), and `RootAwareBackScope`
   (`root_aware_back_scope.dart:47-57`) intercepts only the **system** back gesture, never the
   in-app circle. So pass `onLeadingPressed: () => context.canPop() ? context.pop() :
   context.go('/')` — mirroring `backFallbacks['otp-handover'] = '/'` (`app_router.dart:494`).
   Do not pass `leadingTooltip` — the kit already falls back to the localized
   `MaterialLocalizations.backButtonTooltip` (`jeeb_top_bar.dart:375-376`).
2. `JeebCodeCells.inputBoxWidth` is **68**, not 74 (`jeeb_code_cells.dart:155`); only the height
   is 74.
3. `JeebInfoNote`'s body parameter is **`text:`**, never `body:` (kit §3 delta list). The "Ø30
   success check" the proposal describes does not exist in the kit API — the stacked form renders
   a 19px glyph in the tone's role colour; accept that.
4. The safety note's measured pad `13/16` / gap 12 / glyph 19 are the kit's **stacked**-form
   numbers; a title-less note renders the strip form (pad 12/16, gap 10, glyph 17). Use the strip
   form with defaults — do not chase the 1px with `padding:` overrides.
5. "cubit tests are inert" — imprecise. `otp_handover_cubit_test.dart:114-131` exercises
   `resendSms()`; it keeps passing under the new semantics **because** it asserts only the end
   state (`mode == ready`, repo hit twice) — both preserved. Verify it green, don't edit it.
6. Minor line drift, none load-bearing: `_parseJeeber` spans
   `delivery_tracking_info.dart:423-440`; the fill/radius are `handover_code_display.dart:55-56`;
   DI registration `injection_container.dart:378-380`.

**Hardened:**
1. **Never use `Theme.of(context).extension<JeebSemanticColors>()!` in this feature.**
   `wrapForTest` and the loop-nav harness build on `ThemeData.light()`
   (`test/support/sync_app_localizations.dart:42`, `otp_handover_loop_nav_test.dart:55`) where the
   bang crashes. Nothing on this screen needs it — `context.jeebText` / `context.jeebRoles` both
   fall back safely (`jeeb_text_styles.dart:211`, `jeeb_color_roles.dart:264`), and the info-note
   inks are kit-internal.
2. **Banner honesty gate:** build no `HandoverArrival` when `currentStage ==
   TrackingStage.delivered` — "at your door"/"on the way" would both be lies post-handover.
3. The frozen-id Semantics wrappers (`client_otp_rate_now`, `otp_done_rate_now`,
   `otp_sms_resend`, `otp_handover_submit`, `otp_handover_input`) **stay in screen code exactly
   where they are**; kit buttons go *inside* them with `identifier: null`. Do not migrate a frozen
   id onto a kit `identifier:` param — `tester.getSemantics(find.byKey(…))` in
   `otp_handover_loop_nav_test.dart:217-220` resolves the nearest ancestor node and must keep
   finding the wrapper.

**Confirmed kept (verified true):**
- **C-13.1 — the board deletes the client's only forward path: REFUSED.** The render's footer has
  no "Rate now", but `otp_handover_loop_nav_test.dart:154-222` (F2) pins
  `Key('otpHandover.clientRateNow')` + id `client_otp_rate_now` + navigation to
  `/orders/:id/mutual-rate`, and the comment at `otp_handover_screen.dart:357-359` records why
  (no status polling → removing it parks the customer forever). The realized footer is three
  rows (§C).
- **C-13.2 — "screen auto-brightens": REFUSED.** No brightness/wakelock capability exists
  (grep of `pubspec.yaml` + lib: zero hits); a new package violates hard constraint 2. Pre-agreed:
  `00-MIGRATION-PLAN.md:478` — *"auto-brighten = existing capability only"*. Owner follow-up item.
- **C-13.3 — periwinkle body text on white: deliberate deviation.** The HTML inks the instruction
  subtitle (tpl 807), safety text and the SMS prompt (tpl 819) `--jeeb-periwinkle` on white;
  `test/core/theme/color_role_contrast_test.dart:129-140` documents that pairing as below AA.
  On white, body ink is `colorScheme.onSurfaceVariant` (#5C4038). Muted ink survives only inside
  the kit's `surfaceContainerHigh` info note (kit-owned) and on the navy/orange surfaces.
- **C-13.4 — no tracking-privacy conflict.** The banner carries name + vehicle only.
  `_parseJeeber` never populates `rating`/`phoneE164`
  (`delivery_tracking_info.dart:423-440`; pinned by
  `test/delivery_tracking_jeeber_parse_test.dart:44-64`). No star, no call button, and no avatar
  photo — plain initial disc (a terminal screen opens no CDN fetch).
- **C-13.5 — no D41/D44 exposure.** "cash ready" is the cash-due amount the customer already sees
  beside "Pay cash on delivery" (`order_summary_pinned_header.dart:41,81`); no fee/commission
  wording appears anywhere on this screen.
- The arrival data needs **no new endpoint or field**: `LiveTrackingRepository.fetchDeliveryStatus`
  (`GET /v1/deliveries/{id}`, registered `injection_container.dart:378-380`) →
  `DeliveryTrackingInfo` already parses `jeeber.displayName`/`.vehicleLabel`, `price`/`currency`
  (`delivery_tracking_info.dart:306-307`) and `currentStage`. Cross-feature domain imports are
  established precedent (`chat/data/dio_chat_gateway.dart:12` imports otp_handover's domain).

---

## B. Semantics inventory — FROZEN (re-verified against source 2026-08-03)

Must survive byte-identically, in their existing wrapper shapes:

| Identifier | Site today | After |
|---|---|---|
| `otp_handover_root` | `otp_handover_screen.dart:33` (`container` + `explicitChildNodes`) | unchanged, still wraps the `Scaffold` |
| `otp_handover_code_display` | `handover_code_display.dart:16,44` (default param) | unchanged — wrapper now delegates to `JeebCodeCells.display` |
| `client_otp_rate_now` | `:370` | unchanged — wrapper moves into the docked footer |
| `otp_done_rate_now` | `:198` (`container` + `button`) | unchanged |
| `otp_sms_fallback` | `:271` (`container`) | unchanged |
| `otp_sms_resend` | `:298` (`container`) | unchanged — fallback surface ONLY (§A cut 5) |
| `otp_handover_input` | `:508` (`container`) + per-cell `otp_handover_input_0..3` via `:524` (RC-7) | unchanged |
| `otp_handover_submit` | `:578` (`container`) | unchanged |
| `tracking_at_door_code` | passed by `otp_at_door_card.dart:86` into the frozen compact branch | unchanged |

Frozen `Key`s: `otpHandover.codeDisplay`, `otpHandover.resendSms`, `otpHandover.clientRateNow`,
`otpHandover.input`, `otpHandover.submit`, `tracking.atDoorCode`.
Shared contract file **not to edit**: `test/qa_keys_batch_test.dart:118-193` (B-4 group) must pass
unchanged.

New identifiers (`<screen>_<element>`):

| New id | Element | How |
|---|---|---|
| `otp_handover_back` | top-bar back circle | `JeebTopBar(identifier: …)` — kit lands it on the circle |
| `otp_handover_arrival` | arrival banner container | `JeebAccentFrameCard.filled(identifier: …)` — kit wrapper is `container` + `explicitChildNodes`; non-live (the code display owns this screen's one `liveRegion`) |
| `otp_handover_send_sms` | code-surface "Send by SMS" link | `JeebCtaButton.accentText(identifier: …)` |
| `otp_handover_dispute` | footer outline pill → escalate | `JeebCtaButton.outline(identifier: …)` |

The banner's white Ø10 dot is decorative → `ExcludeSemantics`.

---

## C. Deliberate divergences from the board (note them in the PR)

| Board | Ship | Why |
|---|---|---|
| footer = SMS line + dispute only | SMS line + **Rate now** + dispute | C-13.1: F2 test contract + no-polling dead end |
| `Karim types this code…` | `otpClientShareSubtitleNamed(name)` when arrival known, else generic `otpClientShareSubtitle` | arrival is best-effort; never render a placeholder name |
| `$8 cash ready` | `MoneyFormat.format(price, currency: currency ?? 'USD')` → `⁦$8.00⁩` | one money rule app-wide; LTR-isolated (`money_format.dart:33-38`); never concatenate a bare `$` |
| periwinkle body/prompt text on white | `colorScheme.onSurfaceVariant` | C-13.3, AA guard test |
| dispute pill 52px / 15px label | kit `outline` default (50 / 13.5 w600) | kit wins (§A cut 6) |
| banner sub 12.5px | `jeebText.bodySmall` (12/w600) | nearest token; no `fontSize:` literals in `lib/features` (`tool/check_design_tokens.sh`) |
| Ø10 white dot | `Sizes.xSmall` (8) disc | no 10px token; decorative |
| 42/w800 tile digits render w700 | expected | no `Inter-ExtraBold.ttf` (plan §4.6); not a defect |

The board draws the **client leg only**. Jeeber entry, SMS fallback, error and success bodies are
restyled to the same grammar — nothing about them is invented from the render.

---

## D. Task list — execute top to bottom

**Task 1 — Write the wiring file.** Create `docs/redesign-2026-08/wiring/13-otp-handover.md` with
the exact blocks from §F. From here on, code as if both are granted (the l10n getters won't exist
until the integrator lands them — expected; say so in your report).

**Task 2 — `domain/handover_arrival.dart` (NEW, pure Dart).**
```dart
class HandoverArrival extends Equatable {
  const HandoverArrival({
    required this.name,
    required this.vehicleLabel,
    required this.atDoor,
    this.cashAmount,
    this.currency,
  });
  final String name;          // JeeberSummary.displayName (already display-ready)
  final String vehicleLabel;  // server copy — never "translated" client-side
  final bool atDoor;          // currentStage == TrackingStage.atDoor
  final double? cashAmount;   // DeliveryTrackingInfo.price
  final String? currency;
  // props: all five
}
```

**Task 3 — `application/otp_handover_state.dart` (additive only).**
Add `final HandoverArrival? arrival;`, `final bool resending;`, `final bool resendFailed;`
(defaults `null`/`false`/`false`) + `copyWith` + `props`. Existing positional/named uses all keep
compiling (defaults).

**Task 4 — `application/otp_handover_cubit.dart`.**
- Ctor gains **optional** `LiveTrackingRepository? deliveryInfo` (import
  `../../live_tracking/domain/live_tracking_repository.dart` +
  `.../delivery_tracking_info.dart` — precedent §A). All 20+ existing constructor call sites
  (tests, `batch_08_entries.dart:301`, router) keep compiling untouched.
- When `isClient && deliveryInfo != null`, fire `_loadArrival()` **in parallel** with
  `_loadHandoverCode()` (fire-and-forget, `unawaited`). It: fetches, maps to `HandoverArrival`
  only when `info.jeeber != null && info.currentStage != TrackingStage.delivered`, guards
  `isClosed`, emits **only** `arrival:` — and swallows every failure. It must never touch `mode`;
  the code is the reason the screen exists, the banner is garnish.
- **Rework `resendSms()` (`:101-106`)** — today it emits `mode: loading`, which blanks the whole
  screen (`_OtpBody:102-103`) and on failure lands `mode: error`, destroying a displayed code:
  ```dart
  Future<void> resendSms() async {
    if (!isClient || state.resending) return;
    emit(state.copyWith(resending: true, resendFailed: false));
    try {
      final result = await _repository.fetchHandoverCode(deliveryId: deliveryId);
      if (isClosed) return;
      final code = result.code;
      emit(state.copyWith(
        resending: false,
        handoverCode: (code != null && code.isNotEmpty) ? code : null, // null → keep existing
        smsSent: true,
      ));
    } on OtpHandoverException {
      if (isClosed) return;
      emit(state.copyWith(resending: false, resendFailed: true));
    }
  }
  ```
  `mode` transitions stay owned by the initial load only. (`copyWith`'s null-keeps semantics
  already preserve `handoverCode`.) The existing cubit test (`:114-131`) must stay green
  unedited — it asserts end-state `ready` + two repo hits, both preserved.

**Task 5 — screen scaffold (`otp_handover_screen.dart:30-56`).**
Keep the root `Semantics` (`:32-37`) byte-identical. Delete `OMDSAppBar` (`:39-44`); the board's
top bar is in-body:
```dart
Scaffold(
  body: SafeArea(
    child: Column(children: [
      JeebTopBar(
        title: isClient ? l10n.otpHandoverClientTitle : l10n.otpHandoverJeeberTitle,
        identifier: 'otp_handover_back',
        onLeadingPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      Expanded(child: BlocConsumer<…>(…)),   // listener/_showEscalateDialog untouched
    ]),
  ),
)
```
Leave the escalate dialog and its `context.go('/orders/$deliveryId/escalate')` (`:81`) alone.

**Task 6 — scale-safe page shell (used by every top-aligned body).**
`Spacer` in a bare `Column` asserts at 200% text. Per body-with-footer:
```dart
LayoutBuilder(builder: (context, c) => SingleChildScrollView(
  child: ConstrainedBox(
    constraints: BoxConstraints(minHeight: c.maxHeight),
    child: IntrinsicHeight(
      child: Column(children: [ …content…, const Spacer(), footer ]),
    ))));
```
At 1× this renders the board's empty lower ~40% (R1 — real emptiness, never re-centre, never let
the footer float up); at 2× it scrolls.

**Task 7 — `_ClientOtpDisplay` (`:322-355`) rebuild.** Structure top-to-bottom (horizontal gutter
`Spacing.xLarge` per block; rhythm per plan §4.3: banner top 18→`Spacing.large`, instruction top
34→`Spacing.twoXLarge`, headline↔sub gap 5→`Spacing.twoXSmall`, tiles top 24→`Spacing.xLarge`,
note top 20→`Spacing.large`):
1. **Arrival banner** — only when `state.arrival != null`:
   `JeebAccentFrameCard.filled(identifier: 'otp_handover_arrival', child: Row(...))` (accent fill
   + `JeebShadows.accentBanner` + pad 14/16 are kit-owned). Row: `JeebAvatar(initial:
   arrival.name, fill: JeebAvatarFill.onAccent)` (Ø42 default) · gap `Spacing.small` ·
   `Expanded(Column)`: headline `arrival.atDoor ? l10n.otpArrivalAtDoor(name) :
   l10n.otpArrivalOnTheWay(name)` in `jeebText.cardTitle` + `jeebRoles.onAccent`; sub
   `cashAmount != null ? l10n.otpArrivalSubtitle(vehicleLabel, MoneyFormat.format(cashAmount!,
   currency: currency ?? 'USD')) : vehicleLabel` in `jeebText.bodySmall` +
   `onAccent.withValues(alpha: .8)` · trailing `ExcludeSemantics` Ø`Sizes.xSmall` `onAccent` disc.
   No star, no call button, no avatar image (C-13.4).
2. **Instruction block**, centred: `l10n.otpClientShareInstruction` in `jeebText.cardTitle` +
   `colorScheme.onSurface`; subtitle `arrival != null ?
   l10n.otpClientShareSubtitleNamed(arrival.name) : l10n.otpClientShareSubtitle` in
   `jeebText.body` + `colorScheme.onSurfaceVariant` (C-13.3).
3. **`HandoverCodeDisplay(code: code)`** — now rendering tiles (Task 8).
4. **Safety note**: `JeebInfoNote.muted(icon: Icons.shield, text: l10n.otpClientDoNotShare)` —
   strip form, defaults, filled glyph (R10).
5. `Spacer()`.
6. **Footer** (`JeebCtaFooter` grammar, one dock):
   ```dart
   JeebCtaFooter.single(
     below: JeebCtaButton.outline(
       label: l10n.otpDisputeCta,
       identifier: 'otp_handover_dispute',
       onTap: () => context.push('/orders/$deliveryId/escalate'),
     ),
     child: Column(mainAxisSize: MainAxisSize.min, children: [
       Row(mainAxisAlignment: MainAxisAlignment.center, children: [
         Flexible(child: Text(l10n.otpClientResendSmsPrompt,
           style: context.jeebText.bodySmall
               .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
         JeebCtaButton.accentText(
           label: l10n.otpClientResendSmsAction,
           identifier: 'otp_handover_send_sms',
           isEnabled: !state.resending,
           onTap: () => context.read<OtpHandoverCubit>().resendSms(),
         ),
       ]),
       if (state.resendFailed)
         Semantics(liveRegion: true, child: Text(l10n.otpResendFailed,
           style: context.jeebText.caption
               .copyWith(color: Theme.of(context).colorScheme.error))),
       SizedBox(height: Spacing.small),
       /* existing Semantics(identifier: 'client_otp_rate_now') wrapper VERBATIM (:368-377),
          inner button swapped to: */
       JeebCtaButton.primary(
         key: const Key('otpHandover.clientRateNow'),
         label: l10n.otpRateNowCta,
         onTap: () => context.go(_mutualRateRoute(deliveryId, true)),
       ),
     ]),
   )
   ```
   The dispute pill uses `context.push` so BACK returns here; the route exists
   (`app_router.dart:1467-1468`, name `escalate`, already in `backFallbacks:495`). **No new
   routes.** The SMS row mirrors natively — no forced text direction.

**Task 8 — `widgets/handover_code_display.dart`: delegate, don't restyle.**
- `compact: false` branch: replace the `Container`+`Text` (`:48-71`) with
  `KeyedSubtree(key: displayKey, child: JeebCodeCells.display(code))`. Drop that branch's own
  `Directionality(ltr)` (kit-internal isolate) and the `letterSpacing: Spacing.small` misuse
  (dies with the single-Text rendering).
- Keep the outer `Semantics` (identifier / `liveRegion` / `handoverCodeA11yLabel` / spaced
  `value`, `:43-47`) and add `excludeSemantics: true` so four tiles don't each announce a bare
  digit — the wrapper already reads "Handover code / 2 1 4 4" once.
- **`compact: true` branch: FROZEN.** `otp_at_door_card.dart:83-88` consumes it and
  `test/live_tracking_handover_code_test.dart:142,190,255` asserts `find.text('1234')` as one
  string. Migrating it to `JeebCodeCells.strip` belongs to screen 12's lane. This is the one
  cross-lane tripwire on this screen.

**Task 9 — `_ClientSmsFallback` (`:259-313`) restyle.** Top-aligned + Task-6 shell. The 56px icon
+ two centred `Text`s (`:276-295`) collapse into `Semantics(liveRegion: true, child:
JeebInfoNote.muted(icon: Icons.sms, title: l10n.otpClientSmsSentTitle, text:
l10n.otpClientSmsSentBody))` (stacked form; `find.text` on both strings keeps resolving).
`Spacer()`, then `JeebCtaFooter.single(child: …)` hosting the existing
`Semantics(identifier: 'otp_sms_resend')` wrapper verbatim with the inner button swapped to
`JeebCtaButton.primary(key: const Key('otpHandover.resendSms'), label: l10n.otpClientResendSms,
isLoading: state.resending, isEnabled: !state.resending, onTap: … resendSms())`. Busy state now
reads `state.resending` (the old `mode == loading` read dies with Task 4). **No entry grid — G4
untouched** (`otpHandover.input`/`otpHandover.submit` must keep finding nothing on the client leg,
`otp_handover_screen_test.dart:102-103`).

**Task 10 — `_DoneBody` (`:161-213`) restyle.** Top-aligned + Task-6 shell:
`JeebInfoNote.success(icon: Icons.check_circle, title: l10n.otpDoneTitle, text: l10n.otpDoneBody)`
(strings unchanged — `'Delivery Complete!'` / `'Rate your Jeeber'` are asserted in
`otp_handover_loop_nav_test.dart:98,140` and `otp_handover_screen_test.dart:167-168`), `Spacer()`,
`JeebCtaFooter.single` hosting the existing `otp_done_rate_now` Semantics wrapper (`:195-207`)
verbatim, inner button → `JeebCtaButton.primary(label: l10n.otpRateNowCta, onTap:
context.go(_mutualRateRoute(deliveryId, isClient)))`. The `?mode=jeeber` threading (`:217-218`)
is untouched.

**Task 11 — `_JeeberOtpEntry` (`:381-462`) — chrome restyle only, no re-plumb.** Not on the
board; same grammar only: top-aligned + Task-6 shell, `Spacing.xLarge` gutters, `Spacer()`,
docked submit. Keep the shake controller (`:390-428`) and `shakeKey` handling verbatim (AC3).
**Keep `OmdsOtpInput`** — it emits the frozen per-cell ids (RC-7, `:524`). Restyle it in place
with kit consts (all params verified in `omds_otp_input.dart:22-35`):
```dart
OmdsOtpInput(
  key: const Key('otpHandover.input'),
  length: 4,
  identifier: 'otp_handover_input',            // per-cell _0.._3 — unchanged
  boxWidth: JeebCodeCells.inputBoxWidth,       // 68
  boxHeight: JeebCodeCells.inputBoxHeight,     // 74
  spacing: JeebCodeCells.inputCellGap,         // 12
  fillColor: cs.surfaceContainerHigh,
  focusedBorderColor: context.jeebRoles.accent,
  errorBorderColor: cs.error,
  hasError: widget.state.errorMessage == 'invalid_otp',  // NEW — free, existing flag
  textStyle: context.jeebText.codeInput.copyWith(color: cs.onSurface),
  onChanged: …, onCompleted: …,                // unchanged
)
```
Do **not** pass `autoFocus` (OMDS default `true` is today's behaviour — keep it).
`_OtpInstruction` → `jeebText.cardTitle` (error branch keeps `colorScheme.error` +
`liveRegion`); `_AttemptHint` → `jeebText.caption` + `colorScheme.error`. `_SubmitButton`: keep
the `otp_handover_submit` wrapper verbatim (`:574-588`), inner → `JeebCtaButton.primary(key:
const Key('otpHandover.submit'), label: l10n.otpVerifyButton, isLoading: isSubmitting, isEnabled:
code.length == 4 && !isSubmitting, onTap: onSubmit)`. Strings `otpHandoverJeeberTitle`,
`otpJeeberInstruction`, `otpWrongCode`, `otpAttemptsRemaining`, `otpVerifyButton` (AR `التحقق`)
are test-pinned — unchanged.

**Task 12 — Test updates (lane-owned files only).**
Legitimately broken by the redesign — exactly these:
| File:line | Today | Fix |
|---|---|---|
| `otp_handover_screen_test.dart:50` | `find.text('1234')` | `find.byKey(Key('otpHandover.codeDisplay'))` + `find.text('1')`/`'2'`/`'3'`/`'4'` each `findsOneWidget` |
| `otp_handover_screen_test.dart:70,72` | old EN copy | new values of `otpClientShareInstruction` / `otpClientDoNotShare` (the sync delegate reads the real ARBs) |
| `otp_handover_loop_nav_test.dart:173` | `find.text('1234')` | `find.byKey(Key('otpHandover.codeDisplay'))` — the test only needs "display is up" |

Add (same three files): banner absent when `arrival == null`; banner shows name/vehicle/formatted
cash and **drops the cash clause when `price` is null**; arrival-fetch failure still shows the
code (mode stays `ready`); `otp_handover_dispute` pushes `/orders/:id/escalate` (loop-nav-style
router harness with a stub route); cubit: `resendSms()` failure keeps `handoverCode` and never
emits `mode: error`, sets/clears `resendFailed`; AR smoke: pump `ar`, assert the first tile digit
is the code's first digit (LTR isolate) and the banner row mirrors.
Must keep passing **unchanged**: `qa_keys_batch_test.dart` B-4 group, loop-nav F1+F2, the G4
fallback pair, the jeeber group + AR test, `live_tracking_handover_code_test.dart` (frozen compact
branch), `handover_code_persistence_test.dart` / `offer_accept_handover_code_test.dart` /
`delivery_otp_handover_path_test.dart` (data-layer only — no screen pump; verified).

**Task 13 — Gates.** `flutter analyze --no-pub` (bar: the same 5 baseline infos, 0 errors,
nothing new); `flutter test test/otp_handover_screen_test.dart test/otp_handover_cubit_test.dart
test/otp_handover_loop_nav_test.dart test/qa_keys_batch_test.dart
test/live_tracking_handover_code_test.dart test/handover_code_persistence_test.dart
test/decision_violations_test.dart`; `bash tool/check_design_tokens.sh`;
`grep -rn "identifier:" lib/features/otp_handover/` diffed against §B. Report which steps were
blocked on the l10n wiring batch.

---

## E. Stop conditions

**Done means:** the feature dir matches §D; every §B identifier/key greps identically; Task-13
suites green (modulo the l10n compile dependency, reported); 0 new analyze issues; token script
clean; the four `_BASELINE.md` failures (`client_offers_screen_test`,
`mutual_rating_tag_chips_l10n_test`, `jeeber_feed_card_test`, `gesture_log_test`) untouched and
uncounted.

**Do NOT touch:** `lib/core/router/app_router.dart` · `lib/core/di/injection_container.dart` ·
`lib/core/theme/*` · `lib/core/widgets/jeeb/*` (frozen — consume) · `lib/l10n/*` ·
`pubspec.yaml` · `lib/features/live_tracking/**` (read its domain via import only; the compact
code branch and `otp_at_door_card.dart` belong to screen 12's lane) · `lib/devtool/**`
(`batch_08_entries.dart:301` keeps compiling because the ctor param is optional) ·
`test/support/*` · `test/qa_keys_batch_test.dart` · `test/live_tracking_handover_code_test.dart` ·
`test/delivery_tracking_jeeber_parse_test.dart`. Do not add polling, a brightness dependency, an
avatar image fetch, a rating/phone surface, or any endpoint/field the wire does not carry. Do not
re-centre any content body or let the footer float into the spacer.

## Out of scope (cut from the proposal)

- Kit modifications of any kind (§A cut 1 — everything needed already shipped).
- `_ErrorBody`/loading restructure (§A cut 2).
- Migrating the compact `HandoverCodeDisplay` branch to `JeebCodeCells.strip` (screen 12's lane).
- Screen auto-brightening (C-13.2; owner follow-up).
- Retiring the now-unused parts of old copy from the ARBs — integrator's call.

---

## F. Wiring requests — final text for `docs/redesign-2026-08/wiring/13-otp-handover.md`

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: three re-valued and eight new strings for the redesigned OTP-handover client surface, plus
hand-rolled getters (this repo's AppLocalizations does not parse ICU).
exact change:
app_en.arb — re-value in place (keys exist at :3575, :3583, :3587):
```json
  "otpHandoverClientTitle": "Handoff",
  "otpClientShareInstruction": "Say it or show it",
  "otpClientDoNotShare": "Your proof it's really yours. Share only at the door — never by phone.",
```
app_en.arb — add:
```json
  "otpClientShareSubtitle": "Your Jeeber types this code to prove the handoff.",
  "@otpClientShareSubtitle": { "description": "Generic instruction subtitle on the client OTP display, used when the courier's name is not loaded." },
  "otpClientShareSubtitleNamed": "{name} types this code to prove the handoff.",
  "@otpClientShareSubtitleNamed": { "description": "Named instruction subtitle on the client OTP display.", "placeholders": { "name": { "type": "String", "example": "Karim" } } },
  "otpArrivalAtDoor": "{name} is at your door",
  "@otpArrivalAtDoor": { "description": "Arrival-banner headline (otp_handover_arrival) when tracking stage is at-door.", "placeholders": { "name": { "type": "String", "example": "Karim" } } },
  "otpArrivalOnTheWay": "{name} is on the way",
  "@otpArrivalOnTheWay": { "description": "Arrival-banner headline before the at-door stage.", "placeholders": { "name": { "type": "String", "example": "Karim" } } },
  "otpArrivalSubtitle": "{vehicle} · {amount} cash ready",
  "@otpArrivalSubtitle": { "description": "Arrival-banner subtitle; {amount} is MoneyFormat output. Omitted entirely (vehicle only) when the delivery carries no price.", "placeholders": { "vehicle": { "type": "String", "example": "Scooter" }, "amount": { "type": "String", "example": "$8.00" } } },
  "otpClientResendSmsPrompt": "Didn't get it? ",
  "@otpClientResendSmsPrompt": { "description": "Muted lead-in of the code-surface SMS line, followed inline by otpClientResendSmsAction." },
  "otpClientResendSmsAction": "Send by SMS",
  "@otpClientResendSmsAction": { "description": "Accent-text action (otp_handover_send_sms) that re-triggers the recipient SMS via the existing GET /otp path." },
  "otpDisputeCta": "Problem? Open a dispute",
  "@otpDisputeCta": { "description": "Outline footer pill (otp_handover_dispute) pushing /orders/:id/escalate." },
  "otpResendFailed": "Couldn't send the SMS. Try again.",
  "@otpResendFailed": { "description": "Inline failure line under the SMS row when the resend call throws; cleared on the next tap." },
```
app_ar.arb — re-value in place:
```json
  "otpHandoverClientTitle": "التسليم",
  "otpClientShareInstruction": "قلها أو اعرضها",
  "otpClientDoNotShare": "هذا إثبات أن الطلب لك. شاركه عند الباب فقط — أبدًا عبر الهاتف.",
```
app_ar.arb — add:
```json
  "otpClientShareSubtitle": "يُدخل جيبرك هذا الرمز لإثبات التسليم.",
  "otpClientShareSubtitleNamed": "يُدخل {name} هذا الرمز لإثبات التسليم.",
  "otpArrivalAtDoor": "{name} عند بابك",
  "otpArrivalOnTheWay": "{name} في الطريق",
  "otpArrivalSubtitle": "{vehicle} · {amount} نقدًا جاهز",
  "otpClientResendSmsPrompt": "لم يصلك الرمز؟ ",
  "otpClientResendSmsAction": "أرسله برسالة نصية",
  "otpDisputeCta": "مشكلة؟ افتح نزاعًا",
  "otpResendFailed": "تعذّر إرسال الرسالة النصية. حاول مرة أخرى.",
```
app_localizations.dart (house `_get` + `replaceFirst` pattern, e.g. `:118`):
```dart
  String get otpClientShareSubtitle => _get('otpClientShareSubtitle');
  String otpClientShareSubtitleNamed(String name) =>
      _get('otpClientShareSubtitleNamed').replaceFirst('{name}', name);
  String otpArrivalAtDoor(String name) =>
      _get('otpArrivalAtDoor').replaceFirst('{name}', name);
  String otpArrivalOnTheWay(String name) =>
      _get('otpArrivalOnTheWay').replaceFirst('{name}', name);
  String otpArrivalSubtitle(String vehicle, String amount) => _get('otpArrivalSubtitle')
      .replaceFirst('{vehicle}', vehicle)
      .replaceFirst('{amount}', amount);
  String get otpClientResendSmsPrompt => _get('otpClientResendSmsPrompt');
  String get otpClientResendSmsAction => _get('otpClientResendSmsAction');
  String get otpDisputeCta => _get('otpDisputeCta');
  String get otpResendFailed => _get('otpResendFailed');
```
why: the board's re-authored client copy (title, instruction, safety line), the arrival banner,
the code-surface SMS affordance and the dispute exit are all user-visible bilingual strings; the
three re-values are consumed only by this screen (grep-verified) and their two changed EN test
assertions are updated in this lane.

### route
file: lib/core/router/app_router.dart
need: hand the already-registered LiveTrackingRepository to OtpHandoverCubit so the client leg can
render the arrival banner (best-effort read of GET /v1/deliveries/{id}).
exact change: in the `otp-handover` builder (`:1410`), add one argument to the existing
constructor call (the `live_tracking` domain import already exists at `:70`; no DI change —
`injection_container.dart:378-380` already registers it):
```dart
              create: (_) => OtpHandoverCubit(
                repository: sl<OtpHandoverRepository>(),
                deliveryId: deliveryId,
                isClient: isClient,
                deliveryInfo: sl<LiveTrackingRepository>(),   // ← NEW
                codeStore: sl.isRegistered<HandoverCodeStore>()
                    ? sl<HandoverCodeStore>()
                    : null,
              ),
```
why: the banner needs courier name/vehicle/cash/stage, all already parsed by
DeliveryTrackingInfo; the param is optional, so every other call site (tests, devtool catalog)
compiles unchanged and simply renders no banner.

---

## G. Risks

1. `HandoverCodeDisplay` is shared with screen 12 — only the `compact: false` branch changes;
   touching the compact branch red-lights `live_tracking_handover_code_test.dart` for another lane.
2. The arrival read adds a second network call to a terminal surface — best-effort only; it must
   never gate, delay, or error the code display.
3. `resending` changes the fallback surface's busy affordance as a side effect — the two G4
   fallback tests and the cubit resend test must stay green without edits.
4. Density (plan risk 13): the bottom ~40% of this render is empty — Task 6's shell is what keeps
   it empty at 1× and scrollable at 2×.
5. Kit-button swaps sit inside frozen-id Semantics wrappers; if `tester.getSemantics` stops
   resolving `client_otp_rate_now` (loop-nav `:217-220`), the wrapper was moved — put it back;
   the fix is never to edit the test.
