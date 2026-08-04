# 13 · OTP handover — change proposal

Lane: Wave 2 (self-contained). Feature dir: `lib/features/otp_handover/`.
Spec: `screens/13-otp-handover.{png,html,note.md}` · plan `00-MIGRATION-PLAN.md` §4–§7 · `02-PLAN-ENHANCED.md` R1–R14.

**Verdict: rebuild** (of the client `ready` surface). The other four view modes (`loading`, `error`,
`success`, SMS fallback) are restyles. The screen gains one genuinely new element — the orange
arrival banner — which needs data the cubit does not fetch today; §5 shows it is buildable from an
existing endpoint with an existing parser, no invention.

---

## 0. What the board actually draws (measured from the HTML)

| Block | HTML | Today |
|---|---|---|
| status row `9:41` | tpl 790 | mock chrome — **not built** |
| top bar: Ø40 `surface-high` circle + 20px navy back glyph, gap 14, title `Handoff` 20/w700 navy, pad `14/24/0` | tpl 794–798 | `OMDSAppBar` (Material app bar, title "Your OTP Code") |
| orange arrival banner: margin `18/24/0`, pad `14/16`, r16, `--jeeb-orange` fill, shadow `0 10 24 rgba(215,59,0,.35)`, Ø42 white-20% disc + `K` 15/w800 white, title 15.5/w700 white, sub 12.5/w600 white-80%, trailing Ø10 white dot | tpl 799–804 | **does not exist** |
| instruction block, centered, pad `34/24/0`: `Say it or show it` 16/w700 navy + `Karim types this code to prove the handoff.` 13.5/w500 periwinkle, gap 5 | tpl 805–807 | one line, `titleMedium`, "Share this code with your Jeeber" |
| **4 code tiles**: 74×92, r20, navy fill, 42/w800 white, gap 13, shadow `0 12 28 rgba(11,19,81,.3)`, pad `24/24/0` | tpl 808–812 | ONE `primaryContainer` pill containing the whole string `1234` at `displayLarge` |
| safety note: margin `20/24/0`, pad `13/16`, r16, `--jeeb-surface-high`, gap 12, 19px periwinkle shield, text 13/w500 lh19 periwinkle | tpl 813–816 | a bare `bodySmall` line, "Do not share until you receive your items" |
| `flex:1` spacer — the bottom **~40 %** of the render is plain white | tpl 817 | content is vertically `Center`ed |
| footer, pad `0/24/32`: `Didn't get it? ` 13/w600 periwinkle + `Send by SMS` w700 orange; margin-top 14; outline pill h52 r999 `1.5px --jeeb-brown-outline`, `Problem? Open a dispute` 15/w600 navy | tpl 818–821 | nothing — no SMS affordance on the code surface, no dispute exit |

**The board is the CLIENT leg only.** The jeeber entry leg (`isClient == false`), the SMS fallback,
the error body and the success body are not drawn anywhere on the 24-screen board. They are restyled
to the same grammar; nothing about them is invented from the render.

---

## 1. Layout & structure

### 1.1 Page scaffold — `otp_handover_screen.dart:38-55`

Delete the `OMDSAppBar`. The board's top bar is **in-body** (pad `14/24/0`, no Material elevation,
no divider) — plan §5 #1.

```dart
Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        JeebTopBar(                                   // kit §5 #1
          leading: JeebTopBarLeading.back,
          title: isClient ? l10n.otpHandoverClientTitle : l10n.otpHandoverJeeberTitle,
          identifier: 'otp_handover_back',
          onLeadingTap: () => _back(context),
        ),
        Expanded(child: BlocConsumer<OtpHandoverCubit, OtpHandoverState>(…)),
      ],
    ),
  ),
)
```

`_back` must mirror the route's own root-aware contract (`backFallbacks['otp-handover'] = '/'`,
`app_router.dart:494`) because `JeebTopBar` has no `maybePop` default to inherit:

```dart
void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/');
```

Keep the `Semantics(identifier: 'otp_handover_root', container: true, explicitChildNodes: true)`
root exactly where it is (line 32-37) — it wraps the `Scaffold`, and `explicitChildNodes` is what
stops it swallowing the ids below it.

### 1.2 The body is top-aligned with one real spacer (R1)

Every body today is `Center(child: Column(mainAxisAlignment: center))` — lines 131, 171, 268, 332,
432. **All five stop centring.** R1: "22 of 24 screens are `column → content → flex:1 → footer`; the
spacer is real emptiness — never vertically centre."

Scale-safe page shell (DoD requires 200 % text without an overflow crash, and `Spacer` inside a
plain `Column` overflows there):

```dart
LayoutBuilder(
  builder: (context, c) => SingleChildScrollView(
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: c.maxHeight),
      child: IntrinsicHeight(
        child: Column(children: [ …content…, const Spacer(), footer ]),
      ),
    ),
  ),
)
```

At 1× this renders the board's empty lower half; at 2× it scrolls instead of asserting.

### 1.3 `_ClientOtpDisplay` (`:322-355`) — rebuilt

```
[arrival banner]        ← new, conditional (§5)
[instruction headline + subtitle]
[JeebCodeCells.display via HandoverCodeDisplay]
[JeebInfoNote.muted — the safety line]
Spacer()
[footer: SMS line · Rate-now pill · dispute outline pill]
```

Gutter: `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` (24) on every block.
Vertical rhythm mapped through §4.3: banner top 18 → `Spacing.large` (20); instruction top 34 →
`Spacing.twoXLarge` (32); headline↔sub gap 5 → `Spacing.twoXSmall` (4); tiles top 24 →
`Spacing.xLarge`; note top 20 → `Spacing.large`; footer bottom 32 → `Spacing.twoXLarge`.
Never a raw number — `tool/check_design_tokens.sh` bans literal `EdgeInsets`/`SizedBox` numbers in
`lib/features`.

### 1.4 Footer — three rows, not the board's two

The board's footer is `[SMS line] + [outline dispute pill]`. It **deletes the client's only forward
path**. That deletion is refused (§9 C-13.1), so the realized footer is:

```
Didn't get it? Send by SMS          (jeebText.bodySmall, centered, mixed ink)
  gap Spacing.small
[ Rate now ]                        JeebCtaButton.primary  h56 navy pill + JeebShadows.ctaNavy
  gap Spacing.small
[ Problem? Open a dispute ]         JeebCtaButton.outline  h52 pill, 1.5px colorScheme.outline
```

This is still `JeebCtaFooter` grammar (one dock, primary above secondary) and it keeps
`client_otp_rate_now` + `Key('otpHandover.clientRateNow')` alive and prominent.

### 1.5 `_ClientSmsFallback` (`:259-313`) — restyle only

Top-aligned; the 56px `Icons.sms_outlined` + two centred `Text`s collapse into a
`JeebInfoNote.muted` with a 17px `sms_outlined` leading glyph carrying `otpClientSmsSentTitle` as its
title and `otpClientSmsSentBody` as its body; `Spacer()`; docked `JeebCtaButton.primary` resend.
`otp_sms_fallback`, `otp_sms_resend`, `Key('otpHandover.resendSms')` and both strings survive
verbatim. **No entry grid** — G4 is untouched.

### 1.6 `_DoneBody` (`:161-213`) — restyle only

`Icons.check_circle_outline` at `Sizes.fiveXLarge` + two `Text`s → `JeebInfoNote.success`
(`jeebRoles.successContainer`, Ø30 check, navy w700 title = `otpDoneTitle`, muted sub =
`otpDoneBody`), top-aligned, `Spacer()`, docked `JeebCtaButton.primary` = `otpRateNowCta` keeping
`otp_done_rate_now`. Strings unchanged (`'Delivery Complete!'` / `'Rate your Jeeber'` are asserted in
two test files).

### 1.7 Jeeber leg (`_JeeberOtpEntry`, `:381-462`) — restyle, no re-plumb

The board does not draw it. Apply the same chrome only: `JeebTopBar`, 24 gutters, top-aligned,
`Spacer()`, docked submit. **Keep `OmdsOtpInput`** — it is what emits the frozen per-cell ids
`otp_handover_input_0..3` (RC-7, `:524`) and `Key('otpHandover.input')`. It already exposes every
hook the kit's `input74` spec needs, so restyle it in place rather than swapping in `JeebCodeCells`:

```dart
OmdsOtpInput(
  key: const Key('otpHandover.input'),
  length: 4,
  identifier: 'otp_handover_input',
  boxWidth: JeebCodeCells.inputBoxWidth,      // kit const (see §11 wiring)
  boxHeight: JeebCodeCells.inputBoxHeight,    // 74
  spacing: Spacing.small,
  fillColor: cs.surfaceContainerHigh,
  focusedBorderColor: context.jeebRoles.accent,
  errorBorderColor: cs.error,
  hasError: state.errorMessage == 'invalid_otp',   // NEW — see §4.3
  textStyle: context.jeebText.codeInput.copyWith(color: cs.onSurface),
  onChanged: …, onCompleted: …,
)
```

Keep the shake controller (`:390-422`) verbatim — AC3 and `shakeKey` are unrelated to the redesign.

---

## 2. Tokens

The file is already literal-free; the work is moving off stock `TextTheme`/`ColorScheme` guesses onto
the Wave-0 symbols (all live — §4.6).

| Where | Today | Becomes |
|---|---|---|
| `handover_code_display.dart:41-42` `displayLarge` | stock 57/w400 | `context.jeebText.statDisplay` (42/w800) |
| `handover_code_display.dart:56` `colorScheme.primaryContainer` fill | pale lilac slab | `colorScheme.primary` (`#0B1351`) tile fill, ink `colorScheme.onPrimary` |
| `handover_code_display.dart:56` `OmdsBorderRadius.medium` | r16 | `OmdsBorderRadius.large` (20) per §4.4 |
| `handover_code_display.dart` — no shadow | flat | `JeebShadows.heroNavy` (`0 12 28 rgba(11,19,81,.30)`) — §4.5 names 13's tiles as this const's second consumer |
| `handover_code_display.dart:67` `letterSpacing: Spacing.small` | a **spacing** token used as letter-spacing (12 px tracking) | delete — per-digit tiles make tracking meaningless |
| `:337` `titleMedium` instruction | stock 16/w500 | `context.jeebText.cardTitle` (15.5/w700), ink `colorScheme.onSurface` |
| new instruction subtitle | — | `context.jeebText.body` (13.5/w500), ink **`colorScheme.onSurfaceVariant`** — see §9 C-13.4 |
| `:346` `bodySmall` safety line | stock 12/w400 | inside `JeebInfoNote.muted`: `jeebText.body` on `surfaceContainerHigh`, ink `JeebSemanticColors.mutedText` |
| `:478` `titleMedium` jeeber instruction | stock | `context.jeebText.cardTitle` |
| `:550` `bodySmall` attempt hint | stock | `context.jeebText.caption` + `colorScheme.error` |
| `:180`, `:278` `Sizes.fiveXLarge` icons | 56px glyph | absorbed into `JeebInfoNote` leading glyph (Ø30 success check / 17px muted glyph) |
| banner fill / shadow | — | `context.jeebRoles.accent` + `JeebShadows.accentBanner` (§4.5 names it "the at-door arrival banner (13)") |
| banner ink | — | `context.jeebRoles.onAccent` (never faded — 4.65:1, AA by 0.15); the sub line at `onAccent.withValues(alpha: .8)` matches the HTML's `rgba(255,255,255,.8)` |
| `Send by SMS` word | — | `context.jeebRoles.accent` (#D73B00 on white = 4.66:1 ✓) |
| dispute pill border | — | `colorScheme.outline` (`#916F66` = `--jeeb-brown-outline`) at 1.5px, no shadow (R7) |

`otp_handover/` is **not** in `no_raw_semantic_colors_test.dart`'s file list, but use
`jeebRoles.accent` anyway — the plan makes it the only sanctioned orange accessor and it costs
nothing.

---

## 3. Shared components consumed

| Kit widget (plan §5) | Replaces | Notes |
|---|---|---|
| **#1 `JeebTopBar`** (`leading: back`) | `OMDSAppBar` at `:39-44` | title `h2`; needs `onLeadingTap` (§1.1) |
| **#5 `JeebAccentFrameCard.filled`** | — (new arrival banner) | accent fill + `JeebShadows.accentBanner`, r16, pad `14/16` — this is the variant the plan created *for this screen* |
| **#9 `JeebAvatar`** Ø42 | — | initial disc inside the banner; needs an on-accent tone (§11 wiring) |
| **#12 `JeebCodeCells.display`** | the single-pill body of `HandoverCodeDisplay` | 74×92 r20 navy tiles, `statDisplay`, `heroNavy`, digits in an LTR isolate |
| **#22 `JeebInfoNote`** | `:344-348` safety text, `:283-295` fallback copy, `:177-193` done body | tones `muted` / `success` |
| **#2 `JeebCtaButton` + `JeebCtaFooter`** | `OmdsPrimaryButton` `:371`, `OmdsLoadingButton` `:201`/`:300` | `primary` h56 navy + `ctaNavy`; `outline` h52; `accentText` for the SMS word |

`HandoverCodeDisplay` is **not deleted** — it stays as the semantics/a11y wrapper (identifier,
`liveRegion`, `handoverCodeA11yLabel`, spaced `value`) and delegates its rendering:

* `compact: false` → `JeebCodeCells.display(code)` — **new**;
* `compact: true` → **unchanged**, because `live_tracking/.../otp_at_door_card.dart:83` is its other
  consumer and `test/live_tracking_handover_code_test.dart:142,190,255` asserts `find.text('1234')`
  as one string. Migrating the compact branch to `JeebCodeCells.strip` belongs to screen 12's Wave-4
  lane, not this one.

Add `excludeSemantics: true` to that wrapper so the four tiles do not each announce a bare digit;
the wrapper's `label` + `value` ("Handover code" / "2 1 4 4") already read the code correctly once.

---

## 4. New functionality

### 4.1 The arrival banner (the note's headline change)

> "at-door moment made unmissable — orange arrival banner with cash due"

Needs: courier display name, vehicle label, cash amount, and whether they have actually arrived.
The cubit holds only `deliveryId` + `isClient`.

**All four exist today, from one already-registered repository — no new endpoint, no new field.**
`LiveTrackingRepository.fetchDeliveryStatus` (`GET /v1/deliveries/{id}`, DI
`injection_container.dart:379`) parses into `DeliveryTrackingInfo.fromDeliveryJson`, which yields:

* `jeeber.displayName` + `jeeber.vehicleLabel` — `delivery_tracking_info.dart:426-437`, both required
  and non-empty or the whole `JeeberSummary` is null;
* `price` + `currency` — `:306-307`; the same field
  `order_summary_pinned_header.dart:41,81` already renders as the cash figure beside
  "Pay cash on delivery";
* `currentStage` — gates the headline so the copy is never a lie.

State/cubit changes:

* NEW `lib/features/otp_handover/domain/handover_arrival.dart`:
  `class HandoverArrival { final String name; final String vehicleLabel; final double? cashAmount;
  final String? currency; final bool atDoor; }` — plain value object, `Equatable`.
* `OtpHandoverState` gains `final HandoverArrival? arrival;` (+ `props`, + `copyWith`).
* `OtpHandoverCubit` gains an **optional** named ctor param
  `LiveTrackingRepository? deliveryInfo` (optional so all 8 existing test files keep compiling and
  simply render no banner). When `isClient && deliveryInfo != null`, fire the read **in parallel**
  with `_loadHandoverCode()`, swallow every failure, and emit only `arrival:` — it must never move
  `mode` to `loading` or `error`. The code is the reason the screen exists; the banner is garnish.
* Render only when `isClient && state.arrival != null`. Headline:
  `atDoor ? l10n.otpArrivalAtDoor(name) : l10n.otpArrivalOnTheWay(name)`. Subtitle: vehicle, plus
  ` · {amount} cash ready` **only when `cashAmount != null`** — clause dropped, never faked.

Refusals inside the banner (§7.2 "Tracking privacy"): no `★`, no call button, no avatar image. The
parser keeps `avatarUrl` on the delivery-detail slice, but the board draws a plain initial disc and a
terminal at-door screen should not open a CDN fetch — render the initial only.

### 4.2 "Send by SMS" on the code surface, without destroying the code

The action already exists (`OtpHandoverCubit.resendSms()`, `:101-106`) but it emits
`mode: loading` → `_OtpBody` (`:102`) swaps the whole screen for a spinner and the displayed code
vanishes; on failure `_fetchFromGateway` emits `mode: error` and the code is gone for good.

Required state change (small, contained):

* `OtpHandoverState` gains `final bool resending;` and `final bool resendFailed;`.
* `resendSms()` emits `resending: true` **without touching `mode`**, calls the same gateway path, and
  emits `resending: false` (+ `resendFailed: true` on `OtpHandoverException`) — the
  `mode: loading`/`mode: error` transitions stay owned by the initial load only.
* Both surfaces read `state.resending` for their busy state (`_ClientSmsFallback`'s button included).
* `resendFailed` surfaces as an inline muted line under the SMS row; clear it on the next tap.

Copy is honest as drawn: `GET /otp` triggers an SMS to the delivery's recipient phone — exactly what
"Send by SMS" claims (`otp_handover_cubit.dart:18-23`).

### 4.3 Wrong-code border (free, from an existing flag)

`OmdsOtpInput.hasError` is unused today; wire it to `state.errorMessage == 'invalid_otp'` so the
jeeber's cells turn red alongside the existing shake + inline error. No new state.

### 4.4 REFUSED — "screen auto-brightens"

The note asks the screen to raise display brightness. There is **no brightness capability in the
app** (`grep` for `screen_brightness` / `setBrightness` / `wakelock` → zero hits; nothing in
`pubspec.yaml`). Delivering it needs a new package, which hard constraint 3 forbids. Not built, not
faked. Recorded here as an owner/follow-up item; the plan's Wave-2 red flag already pre-agreed this
("auto-brighten = existing capability only").

---

## 5. Data gaps

| Wanted | Verdict |
|---|---|
| courier name, vehicle | **available** — `JeeberSummary.displayName` / `.vehicleLabel` |
| cash due | **available** — `DeliveryTrackingInfo.price` / `.currency`, via `MoneyFormat.format` |
| "is at your door" truth | **available** — `currentStage == TrackingStage.atDoor` |
| courier avatar photo | available but **deliberately not rendered** (initial disc, per board + no CDN fetch on a terminal screen) |
| courier rating / phone | **blocked by the privacy guard** (`_parseJeeber` never sets them; `test/delivery_tracking_jeeber_parse_test.dart:44-64`) — the board does not ask for them here, so nothing to refuse |
| screen brightness | **no capability** — §4.4 |

Nothing on this screen requires a `TODO(redesign-24)` for a missing gateway field.

---

## 6. New routes

**None.** The dispute CTA targets `/orders/:id/escalate` (`app_router.dart:1467`, name `escalate`,
already in `backFallbacks` at `:495`). Use `context.push` from the footer pill so BACK returns to the
handover screen; leave the 3-wrong-attempts dialog's existing `context.go` at `:81` alone.

---

## 7. Semantics identifiers

### Must survive (full inventory — `grep -rn "identifier:" lib/features/otp_handover/`)

| id | Site today | After |
|---|---|---|
| `otp_handover_root` | `:33` | unchanged, still `container` + `explicitChildNodes` |
| `otp_handover_code_display` | `handover_code_display.dart:44` (default param) | unchanged — now wraps the tile row |
| `client_otp_rate_now` | `:370` | unchanged — moved into the docked footer |
| `otp_done_rate_now` | `:198` | unchanged |
| `otp_sms_fallback` | `:271` | unchanged |
| `otp_sms_resend` | `:298` | unchanged, **plus** the new code-surface SMS link (the two surfaces are mutually exclusive branches of `_ReadyBody:247-250`, so `findsOneWidget` still holds) |
| `otp_handover_input` | `:508` container + `:524` per-cell base → `otp_handover_input_0..3` | unchanged |
| `otp_handover_submit` | `:578` | unchanged |
| `tracking_at_door_code` | passed in by `otp_at_door_card.dart:86` | unchanged |

Widget keys that must survive: `otpHandover.codeDisplay`, `otpHandover.resendSms`,
`otpHandover.clientRateNow`, `otpHandover.input`, `otpHandover.submit`, `tracking.atDoorCode`.

### New

| id | Element |
|---|---|
| `otp_handover_back` | `JeebTopBar` back circle (§7.5 `<screen>_back` convention) |
| `otp_handover_arrival` | the arrival banner container (`container: true`, non-live — the code display owns the one `liveRegion` on this screen) |
| `otp_handover_dispute` | footer outline pill → `/orders/:id/escalate` |

The white Ø10 live dot is decorative → `ExcludeSemantics`.

---

## 8. RTL

* **Digit order must not mirror.** Today one `Directionality(ltr)` wraps the single `Text`
  (`handover_code_display.dart:60`). With four tiles the **row** needs the isolate, not the glyph —
  `JeebCodeCells` owns that ("digits always in an LTR isolate", §5 #12). Verify in the AR smoke test
  that tile 0 reads `2`, not `4`.
* **Cash**: `MoneyFormat.format(price, currency: currency ?? 'USD')` already wraps in U+2066/U+2069
  (`money_format.dart:11-23`). Never concatenate a bare `'$'` into the banner string.
* **Banner**: plain `Row` + `EdgeInsetsDirectional` — avatar at start, dot at end, both mirror.
* **Top bar**: `DirectionalIcons.back(context)` (`lib/core/widgets/directional_icons.dart:16`) — kit
  `JeebTopBar` must use it.
* **Info note**: leading glyph via a `Row` (auto-mirrors); no `EdgeInsets.only(left:)`.
* **Footer SMS line**: `Text.rich` with two spans, `textAlign: TextAlign.center` — mirrors natively;
  do not force `TextDirection.ltr` on it.
* `vehicleLabel` arrives from the gateway in English ("Scooter") and will sit inside an Arabic
  sentence. That is server copy, not a layout bug — do not "translate" it client-side.
* 200 % text: §1.2's scroll shell.

---

## 9. Conflicts & refusals

**C-13.1 — The board deletes the client's only forward path. REFUSED.**
The render's footer has no "Rate now". `test/otp_handover_loop_nav_test.dart:154-222` (F2) asserts
`Key('otpHandover.clientRateNow')` exists on the code surface, that it navigates to
`/orders/:id/mutual-rate`, and that its identifier is `client_otp_rate_now`. The comment at
`otp_handover_screen.dart:357-359` records why: there is no status polling on this screen, so
removing the CTA parks the customer forever. Keep it (§1.4). If the owner wants the board literally,
that is a product decision that must amend F2 first.

**C-13.2 — "screen auto-brightens". REFUSED** — needs a new dependency (§4.4).

**C-13.3 — Periwinkle body text on white. DEVIATION, deliberate.**
The HTML paints the instruction subtitle (tpl 807) and the footer's "Didn't get it?" (tpl 819) in
`--jeeb-periwinkle` on white. §4.1 forbids exactly that ("NEVER body text on white — a contrast test
asserts it fails AA"), and `test/core/theme/color_role_contrast_test.dart:129-138` documents the
pairing as failing. Both render in `colorScheme.onSurfaceVariant` (`#5C4038`) instead. Periwinkle is
kept only where the plan itself sanctions it — as `mutedText` **inside** the `surfaceContainerHigh`
info note (§5 #22 `muted` tone).

**C-13.4 — No conflict with the tracking-privacy guard.** Worth stating because the banner looks
like screen 12's blocked courier card: it carries **name + vehicle only**. `_parseJeeber`
(`delivery_tracking_info.dart:423-440`) never populates `rating` or `phoneE164`, and the banner asks
for neither. No star, no call button.

**C-13.5 — No D41/D44 exposure.** "cash ready" is a cash-due statement, not a fee statement; there is
no commission/platform-fee line on this screen and none is added.

---

## 10. Test impact

**Legitimately broken (the design genuinely changed) — 3 assertions in 2 files:**

| File:line | Assertion | Why | Fix |
|---|---|---|---|
| `test/otp_handover_screen_test.dart:50` | `find.text('1234')` | the code is now four `Text` widgets, one digit each | assert `Key('otpHandover.codeDisplay')` + `find.text('1')…find.text('4')` each `findsOneWidget` |
| `test/otp_handover_screen_test.dart:70,72` | `'Share this code with your Jeeber'`, `'Do not share until you receive your items'` | both strings are re-authored to the board's copy | update to the new EN values |
| `test/otp_handover_loop_nav_test.dart:173` | `find.text('1234')` | same tile split | same fix |

**Must keep passing unchanged** (if any of these break, the proposal is wrong, not the test):

* `test/qa_keys_batch_test.dart:117-193` — all four ids + keys.
* `test/otp_handover_loop_nav_test.dart` F1 + F2 — `otpHandover.clientRateNow`,
  `client_otp_rate_now`, `'Delivery Complete!'`, `'Rate your Jeeber'`, both mutual-rate URIs.
* `test/otp_handover_screen_test.dart` G4 fallback pair — `"We've sent your code by SMS"`,
  `otpHandover.resendSms`, and **`otpHandover.input` / `otpHandover.submit` finding nothing** on the
  client leg.
* `test/otp_handover_screen_test.dart` jeeber group + AR test — `'Verify OTP'`,
  `'Enter the OTP from the Client'`, `'Incorrect code — please try again'`, `'2 attempt'`, `'التحقق'`.
* `test/live_tracking_handover_code_test.dart` — untouched **only because the `compact` branch of
  `HandoverCodeDisplay` is frozen**. This is the single cross-lane tripwire on this screen.
* `test/otp_handover_cubit_test.dart`, `handover_code_persistence_test.dart`,
  `offer_accept_handover_code_test.dart`, `delivery_otp_handover_path_test.dart` — no repository or
  path change, so all four are inert.

**To add:** banner absent when `arrival == null`; banner renders name/vehicle/cash when present and
drops the cash clause when `price` is null; `otp_handover_dispute` pushes `/orders/:id/escalate`;
`resendSms()` keeps `handoverCode` and never emits `mode: error`; AR/RTL smoke asserting tile order.

---

## 11. Wiring requests (not this lane's files)

1. **l10n batch** (`app_en.arb` + `app_ar.arb` + getters), 4-edit recipe each:
   | key | EN | AR |
   |---|---|---|
   | `otpHandoverClientTitle` *(re-value)* | `Handoff` | `التسليم` |
   | `otpClientShareInstruction` *(re-value)* | `Say it or show it` | `قلها أو اعرضها` |
   | `otpClientShareSubtitle` *(new)* | `Your Jeeber types this code to prove the handoff.` | `يُدخل جيبرك هذا الرمز لإثبات التسليم.` |
   | `otpClientShareSubtitleNamed` *(new, `{name}`)* | `{name} types this code to prove the handoff.` | `يُدخل {name} هذا الرمز لإثبات التسليم.` |
   | `otpClientDoNotShare` *(re-value)* | `Your proof it's really yours. Share only at the door — never by phone.` | `هذا إثبات أن الطلب لك. شاركه عند الباب فقط — أبدًا عبر الهاتف.` |
   | `otpArrivalAtDoor` *(new, `{name}`)* | `{name} is at your door` | `{name} عند بابك` |
   | `otpArrivalOnTheWay` *(new, `{name}`)* | `{name} is on the way` | `{name} في الطريق` |
   | `otpArrivalSubtitle` *(new, `{vehicle}`, `{amount}`)* | `{vehicle} · {amount} cash ready` | `{vehicle} · {amount} نقدًا جاهز` |
   | `otpArrivalSubtitleNoCash` *(new, `{vehicle}`)* | `{vehicle}` | `{vehicle}` |
   | `otpClientResendSmsPrompt` *(new)* | `Didn't get it? ` | `لم يصلك؟ ` |
   | `otpClientResendSmsAction` *(new)* | `Send by SMS` | `أرسله برسالة نصية` |
   | `otpDisputeCta` *(new)* | `Problem? Open a dispute` | `مشكلة؟ افتح نزاعًا` |
   | `otpResendFailed` *(new)* | `Couldn't send the SMS. Try again.` | `تعذّر إرسال الرسالة. حاول مرة أخرى.` |
2. **Router** (`app_router.dart:1408-1418`): add `deliveryInfo: sl<LiveTrackingRepository>(),` to the
   `OtpHandoverCubit` constructor. `LiveTrackingRepository` is already registered
   (`injection_container.dart:379`) — **no DI edit needed**.
3. **Kit (Wave 1)**: `JeebAvatar` needs an on-accent tone (fill `onAccent` @ 20 % α, ink `onAccent`)
   for the banner disc; `JeebCodeCells` must expose the `display` variant plus public
   `inputBoxWidth` / `inputBoxHeight` consts so the jeeber leg can style `OmdsOtpInput` without
   literal px in `lib/features`; `JeebCtaButton` needs an `isLoading` flag (fallback: keep
   `OmdsLoadingButton` on the jeeber submit).

---

## 12. Risks

1. `HandoverCodeDisplay` is shared with screen 12. Only the `compact: false` branch changes; touching
   the compact branch red-lights `live_tracking_handover_code_test.dart` for another lane.
2. The arrival read adds a second network call to a terminal surface. Best-effort only — it must
   never gate, delay, or error the code.
3. `resending`/`resendFailed` change the fallback surface's busy affordance as a side effect; the two
   existing fallback tests must stay green.
4. Density (risk #13 in the plan): the bottom ~40 % of this render is empty. Do not let the footer
   float up or the content re-centre.
5. w800 currently renders as w700 (no `Inter-ExtraBold.ttf`, §4.6). The 42 px tiles are the most
   visible casualty on this screen; expected, not a defect.
6. Five kit widgets must land before this lane can compile.
