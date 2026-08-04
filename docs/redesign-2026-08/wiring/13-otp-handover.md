# Wiring requests — 13 · OTP handover

> Written at implementation time, 2026-08-03, from §F of
> `per-screen-revised/13-otp-handover.md`.
>
> **Kit requests: NONE.** §A cut 1 of the instruction set is confirmed against the shipped
> source — `JeebAvatarFill.onAccent` (`jeeb_avatar.dart:30-31`, `:401-406`),
> `JeebCodeCells.display` + the public `inputBoxWidth = 68` / `inputBoxHeight = 74` /
> `inputCellGap = 12` consts (`jeeb_code_cells.dart:106-118`, `:146-158`) and
> `JeebCtaButton.isLoading` (`jeeb_cta_button.dart:100`, `:292-300`) all exist. The kit is
> consumed, never modified.
>
> **Two OPEN requests: `l10n` and `route`.**
>
> Implementation note on the l10n batch: the nine NEW keys are served today by a
> feature-local stopgap resolver, `lib/features/otp_handover/presentation/otp_handover_l10n.dart`
> (the `LiveTrackingL10n` precedent from screen 12's lane). It delegates every key that already
> exists to `AppLocalizations` and supplies only the missing nine from a bilingual EN/AR map, so
> the feature compiles and its widget tests run **now** with 0 analyze errors. When the integrator
> lands the block below, each stopgap getter becomes a one-line delegation and the file is
> deleted. The three **re-valued** keys are already read through `AppLocalizations` — they need
> no stopgap, only the ARB re-value.

---

### l10n

file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart

need: three re-valued and nine new strings for the redesigned OTP-handover client surface, plus
hand-rolled getters (this repo's AppLocalizations does not parse ICU).

exact change:

app_en.arb — re-value in place (keys exist):
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

app_localizations.dart (house `_get` + `replaceFirst` pattern):
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

after landing: replace the nine bodies in
`lib/features/otp_handover/presentation/otp_handover_l10n.dart` with delegations to the getters
above, then delete the file and inline `AppLocalizations.of(context)` at its four call sites
(`otp_handover_screen.dart`, `widgets/handover_arrival_banner.dart`). The class doc carries the
same checklist.

why: the board's re-authored client copy (title, instruction, safety line), the arrival banner,
the code-surface SMS affordance and the dispute exit are all user-visible bilingual strings; the
three re-values are consumed only by this screen (grep-verified) and their EN test assertions were
rewritten in this lane to read the getter rather than a literal, so they survive the re-value
without a second edit.

---

### route

file: lib/core/router/app_router.dart

need: hand the already-registered `LiveTrackingRepository` to `OtpHandoverCubit` so the client leg
can render the arrival banner (best-effort read of `GET /v1/deliveries/{id}`).

exact change: in the `otp-handover` builder (`:1406-1426`), add one argument to the existing
constructor call (the `live_tracking` domain import already exists; no DI change —
`injection_container.dart` already registers `LiveTrackingRepository`):
```dart
              create: (_) => OtpHandoverCubit(
                repository: sl<OtpHandoverRepository>(),
                deliveryId: deliveryId,
                isClient: isClient,
                // 13: best-effort arrival banner (name/vehicle/cash/stage).
                // Optional — every other call site renders no banner.
                deliveryInfo: sl<LiveTrackingRepository>(),
                // G4: local-first code sourcing — the accept-time persisted
                // code renders instantly (and restart-safe) without hitting
                // the SMS-trigger endpoint.
                codeStore: sl.isRegistered<HandoverCodeStore>()
                    ? sl<HandoverCodeStore>()
                    : null,
              ),
```

why: the banner needs courier name/vehicle/cash/stage, all already parsed by
`DeliveryTrackingInfo` from an endpoint the app already calls. The parameter is optional, so every
other call site (tests, devtool catalog `batch_08_entries.dart`) compiles unchanged and simply
renders no banner. No new endpoint, no new field, no DI registration.

---

### Not requested (verified unnecessary)

| candidate | verdict |
|---|---|
| kit change of any kind | already shipped — see the header note |
| new route for the dispute exit | `'/orders/:id/escalate'` exists (`app_router.dart:1467`, name `escalate`, `backFallbacks:495`) |
| DI registration for `LiveTrackingRepository` | already registered |
| theme token | Wave 0 covers every ink/shadow this screen paints |
| `otpArrivalSubtitleNoCash` | cut (§A-4): with no price the banner renders `arrival.vehicleLabel` verbatim — server copy, nothing to translate |
