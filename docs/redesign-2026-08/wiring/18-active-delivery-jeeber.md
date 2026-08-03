# Wiring requests — 18 Active delivery (Jeeber)

### l10n
file: lib/l10n/app_en.arb (+ app_ar.arb — AR values below are drafts for reviewer sign-off)
need: nine new keys for the redesigned handoff surface, plus one value change.
exact change:
```json
"activeDeliveryHandoffTitle": "Complete the handoff",
"@activeDeliveryHandoffTitle": { "description": "Heading of the 18 handoff action card (inTransit + atDoor)." },
"activeDeliveryProofPhotoTile": "Proof photo",
"@activeDeliveryProofPhotoTile": { "description": "Label on the h86 proof-photo tile; the check is an icon, not text." },
"activeDeliveryDoorCodePrompt": "Ask the customer for their 4-digit door code:",
"@activeDeliveryDoorCodePrompt": { "description": "Single prompt line above the door-code cells; replaces title+instruction." },
"activeDeliveryCollectCash": "Collect {amount} cash on delivery",
"@activeDeliveryCollectCash": { "placeholders": { "amount": {} } },
"activeDeliveryCollectCashNoAmount": "Collect the order amount in cash on delivery",
"@activeDeliveryCollectCashNoAmount": { "description": "Run-22 P1-A degraded variant - never fabricate $0.00." },
"activeDeliveryDirectionsCta": "Directions",
"@activeDeliveryDirectionsCta": { "description": "A11y label for the drop-off card's directions circle." },
"activeDeliveryQuickActionMaps": "Maps",
"@activeDeliveryQuickActionMaps": { "description": "Footer pill; long form stays the Semantics label." },
"activeDeliveryQuickActionChat": "Chat",
"@activeDeliveryQuickActionChat": { "description": "Footer pill; long form stays the Semantics label." },
"activeDeliveryQuickActionCosts": "Costs",
"@activeDeliveryQuickActionCosts": { "description": "Footer pill; long form stays the Semantics label." }
```
VALUE CHANGE (verified: single consumer mark_delivered_panel.dart:191, no test/Maestro pin):
`"activeDeliveryOtpSubmit": "Complete Delivery"` → `"Verify code & complete"`.
AR drafts: handoff "أكمل التسليم"; proof "صورة الإثبات"; prompt "اطلب من العميل رمز الباب المكوَّن من 4 أرقام:";
collect "حصّل {amount} نقدًا عند التسليم"; collectNoAmount "حصّل قيمة الطلب نقدًا عند التسليم";
directions "الاتجاهات"; maps "الخرائط"; chat "الدردشة"; costs "التكاليف"; otpSubmit "تحقق من الرمز وأكمل".
NOTE: `activeDeliveryOtpTitle` / `activeDeliveryOtpInstruction` lose their last consumer — keys left in place, deletion is the integrator's call.
why: the handoff card heading, tiles, prompt, collect line, directions a11y, and footer pills are all new user-visible strings; the app is AR/EN.

INTEGRATOR NOTE (added by the lane, 2026-08-03): until this batch lands, the ten strings are served
by the feature-local stopgap `lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_l10n.dart`
(the `live_tracking_l10n.dart` precedent). Every consumer reads them through that one resolver, so
landing the ARB keys is a one-file swap with **zero call-site changes** — replace each `_pick(...)`
body with the matching `_l10n.<key>` getter, then delete the file. This is what keeps the lane at
`dart analyze` = 0 issues while `lib/l10n/*` stays untouched.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_stepper.dart (kit item §5 #11)
need: a `bars` named constructor — 18's stepper has no nodes; §5 #11's 26px-node spec is screen 12 only.
exact change: `JeebStepper.bars({required int stepCount, required int currentIndex, List<Key>? segmentKeys})` — Row of `Expanded` segments h5, `OmdsBorderRadius.xSmall`, gap 6; passed `colorScheme.primary`, active `jeebRoles.accent` + kit-local `BoxShadow(color: Color.fromRGBO(215, 59, 0, 0.18), spreadRadius: 3)` (NOT `JeebShadows.stepGlow`, whose spread 5 is sized for 12's Ø26 node; NOT `focusRing`, wrong color), pending `colorScheme.surfaceContainerHighest`; `segmentKeys[i]` applied to segment i; bars wrapped in `ExcludeSemantics` (labels/semantics stay feature-side). Plain Row → RTL mirrors free.
why: 18 re-homes the frozen `ValueKey('active_delivery_stage_<name>_<state>')`s onto the segments; without `segmentKeys` the stepper test's byKey family breaks.

STATUS 2026-08-03: **already shipped** by the Wave-1 kit lane (`jeeb_stepper.dart`, `JeebStepper.bars`,
`barGlow`/`barHeight`/`barRadius`/`barGap` consts). No integrator action needed — kept here as the record.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_code_cells.dart (kit item §5 #12)
need: `input52` must WRAP `OmdsOtpInput`, not re-implement it — the per-cell ids `<identifier>_0.._3` (omds_otp_input.dart:289-296) exist for Maestro RC-7 and must keep coming from OMDS.
exact change: `JeebCodeCells.input52({Key? key, required String identifier, bool hasError, ValueChanged<String>? onChanged, ValueChanged<String>? onCompleted})` internally: `Directionality(textDirection: TextDirection.ltr)` isolate; `TextSelectionTheme(cursorColor: jeebRoles.accent)`; `OmdsColorTokensProvider(tokens: context.omdsColorTokens.copyWith(inputBorderColor: colorScheme.surfaceContainerHigh))` to kill the resting hairline; `LayoutBuilder` → `OmdsOtpInput(length: 4, boxHeight: 52, boxWidth: (maxWidth - 3*9)/4, spacing: 9, fillColor: colorScheme.surfaceContainerHigh, focusedBorderColor: jeebRoles.accent, textStyle: <kit-local 22/w800/onSurface const — jeebText.codeInput is 29, sized for 03>, hasError, identifier, onChanged, onCompleted)`. Accepted divergences: OS caret (tinted accent) instead of the drawn 2×22 bar.
why: 18's door-code entry consumes this; re-implementing cells is pure identifier risk (RC-7) for zero gain.

STATUS 2026-08-03: **already shipped**. One API delta the lane consumed: the per-cell base is the
kit's `cellIdentifier` param (its `identifier` param is the row-level wrapper, which the panel
already owns at `mark_delivered_panel.dart:164`). So 18 calls
`JeebCodeCells.input52(cellIdentifier: 'mark_delivered_otp_input', …)` inside its existing
`Semantics(identifier: 'mark_delivered_otp_input', container: true)` wrapper — the `_0.._3` leaves
still come from OMDS and the row id is still emitted exactly once. No integrator action needed.

### cross-feature
file: docs/redesign-2026-08/00-MIGRATION-PLAN.md (plan owner)
need: two consumer-list corrections. §5 #13 `JeebNumericKeypad` consumers "03 18" → "03" (18's render has no keypad; the lower 40% is the R1 spacer + footer). §5 #11 gains the `bars` form above (12 keeps nodes). §5 #2: 18 builds its 3-pill row screen-local; no `actionRow` footer form needed in the kit.
exact change: edit the two consumer cells + one sentence in #11's spec.
why: prevents the kit lane building a keypad for 18 and a one-consumer footer variant.

### owner-decision (NOT a request — do not action)
The board's third footer pill ("Costs") implies a `/jeeber/deliveries/:id/goods-cost` route, but `GoodsCostScreen` is a verified ORPHAN with a broken endpoint (goods_cost_screen.dart:25, JEBV4-227) and `app_router.dart:1482-1529` never passes `onEnterGoodsCost`. 18 keeps the pill conditional on the callback (renders in devtool/tests, hidden in production). Wiring a route is an owner call — the JEBV4-176 lesson says don't ship a redesigned pill over a guaranteed-failing flow.
