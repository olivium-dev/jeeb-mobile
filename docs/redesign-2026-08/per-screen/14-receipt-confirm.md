# 14 · Receipt confirm — change proposal

**Screen id:** `14-receipt-confirm`
**Verdict:** `rebuild` (app bar deleted; `ListView` → column + real `flex:1` spacer + docked footer; the cash line changes color family from peach `primaryContainer` to the navy hero of the screen; one net-new modal surface)
**Target file:** `lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart` (382 LOC — only `_DeliveryReceiptView.build` and `_LoadedBody` are rewritten; the class shells, the repository seam and the two `_*ErrorCopy` helpers stay)
**Confirmed reachable from `lib/main.dart`:** yes — `app_router.dart:830-836` `GoRoute('/orders/:id/receipt', name: 'delivered-receipt')` → `DeliveryReceiptScreen`. `screen-repo-map.md:63` agrees with the prompt; no path correction needed.
**Wave:** 2 (self-contained). **Blocked on:** Wave 1 kit (`lib/core/widgets/jeeb/` does not exist yet).

---

## 0. What I read

- Render `screens/14-receipt-confirm.png`, HTML `screens/14-receipt-confirm.html` (41 lines, `dc-tpl 827-850`), note `screens/14-receipt-confirm.note.md`.
- The whole feature: `delivery_receipt_screen.dart`, `application/delivery_receipt_cubit.dart`, `application/delivery_receipt_state.dart`, `domain/delivery_receipt.dart`, `domain/delivery_receipt_repository.dart`, `data/dio_delivery_receipt_repository.dart`, `data/fake_delivery_receipt_repository.dart`.
- Producers: `live_tracking_screen.dart:104-110` (auto-advance on `Delivered`), `notifications_list_screen.dart:280-286` (`confirm_receipt` push), `delivery_detail_screen.dart:372`, `dev_seam_config.dart:105`. All three arrive by `goNamed` as a **stack root**, which is why `app_router.dart:468` puts `'delivered-receipt': '/'` in `backFallbacks`.
- Wave-0 theme: `jeeb_text_styles.dart` (16 fields, `context.jeebText`), `jeeb_shadows.dart` (11 consts), `jeeb_color_roles.dart` (`context.jeebRoles`), `jeeb_semantic_colors.dart`, `app_theme.dart:128-175`.
- Tests: `test/core/router/w1_routes_resolve_test.dart:198-214`, `test/core/router/back_nav_all_routes_test.dart:96-118`, `test/features/delivery_receipt/dio_delivery_receipt_repository{,_amount,_routes,_terminal}_test.dart`, `test/decision_violations_test.dart`, `test/core/theme/no_raw_semantic_colors_test.dart`, `tool/check_design_tokens.sh`, `qa/t-mob-fix-002/l10n_parity_check.sh`.
- Maestro: `.maestro/flows/jm-033-confirm-receipt.yaml` (the whole flow is this screen), `jm-032-order-tracking.yaml:81`, `jm-034-rating.yaml:47,51,141,145`.
- Devtool: `lib/devtool/catalog/entries/batch_03_entries.dart:213-256` (3 catalog states over the `repository` seam).

### Four facts that shape everything below

1. **There is no widget test for this screen.** The only test that mounts it is the route-resolution pin (`w1_routes_resolve_test.dart:198`), which asserts `find.byType(DeliveryReceiptScreen)` after two bare `pump()`s. Everything else in `test/features/delivery_receipt/` is repository-level. **The behavioural contract lives entirely in Maestro `jm-033`, which is not in CI** — so the six identifiers below are the only thing standing between a restyle and silent E2E rot.
2. **Today's cash line is peach, not navy.** `delivery_receipt_screen.dart:266` uses `colorScheme.primaryContainer`, and `app_theme.dart:135-136` binds that to `_jeebOrangeContainer #FFDBD1` / `_jeebOnOrangeContainer #3A0B01`. So the single most important line on the screen currently renders as a soft orange panel with dark-brown ink. The board (`dc-tpl 838`) makes it `--jeeb-navy` with white ink, a periwinkle sub-line and the screen's only `0 10 24 rgba(11,19,81,.28)` card shadow. This is a real color-family change, not a token rename — and it also removes an unsanctioned orange container from a customer surface (R5: orange marks what decays; a settled cash amount does not decay).
3. **The proof-photo timestamp does not exist.** `DioDeliveryReceiptRepository._parseReceipt` (`:132-154`) reads `id`, `jeeberName`, `jeeberId`, `amount`, `currency`, `status`, `proofPhotoUrl|evidenceUrl` — no capture time — and `DeliveryReceipt` has no field for one. The board's `Proof of delivery · 9:38` is therefore **half-buildable**; §7.6 already lists "proof-photo timestamp (14)" as a genuine gap. Ship the badge without the time (§4.2).
4. **Nothing in this proposal touches the cubit, the state or the domain entity.** Every pixel the board asks for is already in `DeliveryReceipt` except the timestamp. That is unusual for this board and worth stating plainly: the only new "state" is a modal route on the local `Navigator`.

---

## 1. Layout & structure

### Deleted

| What | Where | Why |
|---|---|---|
| `Scaffold.appBar: OMDSAppBar(title: l10n.receiptTitle, showBackButton: false, centerTitle: false)` | `:99-105` | The board has **no top bar at all** (`dc-tpl 827` goes status row → heading block). The heading *is* the title, centered, and there is nothing else in the top 100px. Removing it also removes the "Confirm receipt" / "Did you receive your order?" double-title the screen ships today. |
| `Icon(Icons.local_shipping_outlined, size: Sizes.fiveXLarge, color: primary)` + its `SizedBox` | `:216-221` | Not in the render. The board's hero is the proof photo — a decorative 56px truck above it is exactly the high-density habit R1/risk-13 says to strip. |
| `ListView(padding: fromSTEB(medium, large, medium, xLarge))` as the body root | `:208-214` | The board is `column → content → flex:1 → footer` (`dc-tpl 845` is a bare `flex:1` div). A `ListView` lets content grow into the ~35% of white the design deliberately leaves under the cash card, and it puts the two CTAs below the fold instead of docked. Gutter also changes 16 → 24. |
| `SizedBox(height: Spacing.twoXLarge)` before the CTA | `:306` | Replaced by the real `Expanded` spacer. |
| `ClipRRect(borderRadius: OmdsBorderRadius.medium)` around the photo | `:237-238` | Radius 16 → 20 (`dc-tpl 834`), and the clip moves onto the hero `Container` so the two overlay pills clip with it. |

### Added / moved

```
DeliveryReceiptScreen                         (:48-90 UNCHANGED — repository seam intact)
└ Scaffold
  └ SafeArea
    └ Semantics(identifier:'receipt_prompt', explicitChildNodes:true)   ← value + flags unchanged
      └ BlocConsumer                                                    (listener :109-128 UNCHANGED)
         ├ initial/loading → OmdsLoadingState        (now inside the SafeArea, no app bar above it)
         ├ failed          → OmdsErrorState          (unchanged, key 'receipt-load-error' kept)
         └ loaded          → Column
             ├ _PromptHeading            pad 22/28/0, centered, jeebText.h1
             ├ _ProofHero                margin 20/24/0, h230, r20            ← rebuilt
             ├ _CashStatement            margin 16/24/0, r16, navy           ← recolored + restructured
             ├ Expanded(SizedBox.shrink())          ← the real flex:1 spacer (dc-tpl 845)
             └ _ReceiptFooter            pad 0/24/32                          ← new docked block
```

**Scroll posture.** Wrap the three content blocks in `Expanded(child: SingleChildScrollView(...))` and keep `_ReceiptFooter` outside it. That reproduces the render exactly at default text scale (content ends at ~55% of the viewport, the rest is plain white, both CTAs docked) **and** satisfies the DoD's "text scale 200% does not overflow-crash" — a bare `Column` would. The `Expanded(SizedBox.shrink())` spacer lives *inside* the scroll child so the emptiness is real, not a scroll gap; use `SingleChildScrollView(child: ConstrainedBox(minHeight: viewport) → IntrinsicHeight → Column)` **or**, simpler and what I recommend, `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)` holding the column. The latter is one widget and needs no intrinsic pass.

### `_ProofHero` (`dc-tpl 834-837`)

`Container(height: 230, decoration: BoxDecoration(color: colorScheme.surfaceContainerHigh, borderRadius: OmdsBorderRadius.large))` + `ClipRRect(OmdsBorderRadius.large)` + `Stack`:

| Layer | Spec (from HTML) | Flutter |
|---|---|---|
| photo | fills the r20 card | `Positioned.fill(child: Semantics(identifier:'receipt_proof_photo', image:true, label: l10n.receiptProofPhotoLabel, child: OmdsCachedImage(url:…, fit: BoxFit.cover)))` — **`width`/`height` params dropped**, `Positioned.fill` sizes it |
| placeholder (no photo) | same box, neutral | `ColoredBox(colorScheme.surfaceContainerHigh)` + centered `Icon(Icons.image_not_supported_outlined, size: Sizes.twoXLarge, color: onSurfaceVariant)` — **`surfaceContainerHighest` → `surfaceContainerHigh`** so the empty and loaded states share the board's `#EAE7EB` |
| badge | `left 12 top 12`, pad `5/11`, r999, `rgba(11,19,81,.85)`, white 11/w700 | `PositionedDirectional(start: Spacing.small, top: Spacing.small, child: …)`; fill `colorScheme.primary.withValues(alpha: 0.85)`, ink `colorScheme.onPrimary`, style `context.jeebText.label`, radius `OmdsBorderRadius.pill`, pad `EdgeInsetsDirectional.symmetric(horizontal: Spacing.small, vertical: Spacing.twoXSmall)` |
| zoom pill | `right 12 bottom 12`, pad `5/11`, r999, white, navy 11/w700, `0 4 12 rgba(11,19,81,.15)` | `PositionedDirectional(end: Spacing.small, bottom: Spacing.small, …)`; fill `colorScheme.surface`, ink `colorScheme.primary`, style `context.jeebText.label`, shadow **`JeebShadows.floatPill`** |

Two notes. (a) The render's inset floating illustration is mock art — a real proof photo must fill the frame, so `BoxFit.cover`, not the HTML's `width:190px`. The `surfaceContainerHigh` fill stays as the loading/placeholder ground, which is what the HTML actually tokenizes. (b) `JeebShadows.floatPill` (`0 6 16 rgba(11,19,81,.18)`) not `JeebShadows.card`: R7's "no white card has a shadow" is about *resting* cards; this is the same floating-chip-over-imagery case the token was cut for on 12's map ETA pill. `card` is too weak to read over a photo.

### `_CashStatement` (`dc-tpl 838-844`)

`Container` with `padding: EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: Spacing.medium)` (16/16 vs the HTML's `16px 18px` — a 2px horizontal divergence, invisible, and it keeps the token gate clean), `decoration: BoxDecoration(color: colorScheme.primary, borderRadius: OmdsBorderRadius.medium, boxShadow: JeebShadows.ctaNavy)`, `Row(children: [glyph, SizedBox(width: Spacing.small), Expanded(column)])`:

- glyph: `Icon(Icons.payments, size: Sizes.xLarge, color: colorScheme.onPrimary)` — **filled**, not `_outlined` (R10: no outline variants anywhere on the board). 22px → `Sizes.xLarge` (24) is the nearest token; 24 is fine at this weight.
- line 1: the existing `cashText`, `context.jeebText.titleProminent` (17/w700 ≈ HTML 16.5/w700), ink `colorScheme.onPrimary`, with the **money token emphasized** — see §4.3.
- line 2 (**new**): `l10n.receiptCashNote`, `context.jeebText.bodySmall` (12/w600 ≈ HTML 12.5/w600), ink `JeebSemanticColors.mutedText` (#777FC0). Periwinkle on navy is 4.55:1 — AA-clean, and it is the sanctioned muted voice (R4). Gap `Spacing.threeXSmall` (2px, HTML `margin-top:2`).

The `Semantics(identifier: 'receipt_cash_to_jeeber_label')` wrapper at `:261-262` keeps wrapping this whole card, unchanged.

### `_ReceiptFooter` (`dc-tpl 846-850`)

`Padding(EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge))` = `0/24/32`, `Column`:

1. the confirm-error line (see §6), only when `state.confirmStatus == failed`, then `SizedBox(height: Spacing.small)`;
2. `JeebCtaButton.primary` — h58 navy pill, `OmdsBorderRadius.pill`, `JeebShadows.ctaNavy`, leading `Icon(Icons.check, size: Sizes.large, color: onPrimary)` (19px → `Sizes.large` 20), gap 10, label `context.jeebText.button` (17/w600) white, `isLoading: confirming`;
3. `SizedBox(height: Spacing.small)` (12px, HTML `margin-top:12`);
4. `JeebCtaButton.outline` — h54 pill, `1.5px colorScheme.outline` (`#916F66`), label `context.jeebText.cardTitle.copyWith(fontWeight: FontWeight.w600)` (15.5/w600 — the ramp has the size at w700 only; overriding the weight beats writing a `fontSize:` literal, which the gate bans), ink `colorScheme.primary`, no shadow.

---

## 2. Tokens — every hardcode/mis-token in the current file

| Current | `file:line` | Becomes | Evidence |
|---|---|---|---|
| `theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)` | `:226-228` | `context.jeebText.h1` (24/w700) | HTML 25/w700/ls −0.5. Optional `.copyWith(letterSpacing: -0.5)`; plain `h1` is preferred (R3 — do not drift the ramp for 1px). |
| `theme.textTheme.titleMedium?.copyWith(color: onPrimaryContainer, fontWeight: w600)` | `:279-282` | `context.jeebText.titleProminent` + `color: colorScheme.onPrimary` | `dc-tpl 842`: 16.5/w700 white. |
| `theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)` | `:300-302` | `context.jeebText.bodySmall.copyWith(color: colorScheme.error)` | Not drawn on the board; keep the role, move it to the ramp. |
| `theme.colorScheme.primaryContainer` (= `#FFDBD1` peach) | `:266` | `colorScheme.primary` | `dc-tpl 838` `background: var(--jeeb-navy)`. Fact 2 above. |
| `theme.colorScheme.onPrimaryContainer` (= `#3A0B01`) ×2 | `:272, :280` | `colorScheme.onPrimary` | same. |
| `theme.colorScheme.surfaceContainerHighest` (placeholder ground) | `:249` | `colorScheme.surfaceContainerHigh` | `dc-tpl 834` `background: var(--jeeb-surface-high)` = `#EAE7EB`. |
| `OmdsBorderRadius.medium` on the photo clip | `:238` | `OmdsBorderRadius.large` (20) | `dc-tpl 834` `border-radius: 20px`. |
| `OmdsBorderRadius.medium` on the cash card | `:267` | keep `.medium` (16) | `dc-tpl 838` `border-radius: 16px` ✓ already correct. |
| `height: 200` (image + placeholder) | `:242, :247` | 230 via a private `const _kProofHeroHeight = 230.0` | `dc-tpl 834` `height: 230px`. No `Sizes` token lands on 230; a named private const passes `check_design_tokens.sh` (it only bans `SizedBox(height: <literal>)`), and 230 is a one-screen dimension so it does not belong in the kit. |
| `Icons.payments_outlined` | `:271` | `Icons.payments` | R10 — the board has no outline icon variants. |
| `EdgeInsets.all(Spacing.medium)` on the cash card | `:264` | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: Spacing.medium)` | RTL: `EdgeInsets.all` is fine mirrored but the file should be uniformly directional. |
| body gutter `Spacing.medium` (16) | `:210, :212` | `Spacing.xLarge` (24) | §4.3 `--screen-gutter: 24` on every redesigned body; HTML `margin: … 24px`. |
| — (new) | `_CashStatement` | `boxShadow: JeebShadows.ctaNavy` | `dc-tpl 838` `0 10 24 rgba(11,19,81,.28)` — byte-identical to the token. |
| — (new) | primary CTA | `boxShadow: JeebShadows.ctaNavy` | `dc-tpl 847`, same values. |
| — (new) | zoom pill | `boxShadow: JeebShadows.floatPill` | `dc-tpl 837` `0 4 12 rgba(11,19,81,.15)`; `floatPill` is the nearest token and the semantically correct one. |

**Not used on this screen, deliberately:** `jeebRoles.accent` (there is no orange anywhere in this render — the one screen on the spine with none), `JeebSemanticColors.accentTint` / `.accentRing` / `.readTick`, `context.omdsColorTokens.starRatingColor`, `JeebTierColors`. This file is not in `no_raw_semantic_colors_test.dart`'s 18-file list, but it must still keep zero `Color(0x…)` and zero `fontSize:` for `tool/check_design_tokens.sh`.

---

## 3. Shared components

| Plan § | Component | Use here | Notes |
|---|---|---|---|
| §5 #2 | **`JeebCtaButton` + `JeebCtaFooter`** | **yes — both CTAs** | Needs two things the §5 spec does not currently list: (a) an **`isLoading`** state on `primary` (today's `OmdsLoadingButton` at `:320-327` is the only reason the confirm CTA can't double-fire visually); (b) a **`stack`** footer form — this screen is a *vertical* pair (pill + 12px + outline pill), which is neither `single`, `split` (a row) nor `textStack`. Both are wiring requests (§10). Fallback if the kit owner declines: compose locally in the footer `Column` and keep `OmdsLoadingButton` for #1 with a `DecoratedBox(JeebShadows.ctaNavy)` wrapper — but then the leading ✓ glyph is unbuildable (`OmdsLoadingButton` has no icon slot), so the kit param is the right answer. |
| §5 #1 | `JeebTopBar` | **no** | This screen has no top bar at all. It joins 04/16 as a "no chrome" surface — but unlike them it has no `JeebProfileHeader` either. |
| §5 #22 | `JeebInfoNote` | **no** | Tempting for the cash card, but wrong: `JeebInfoNote`'s tones are `muted`/`success`/`accent`, all *quiet* surfaces. The board makes the cash line the loudest thing on the screen (navy fill + the screen's only card shadow). Building it as an info note would flatten the one statement the screen exists to make. |
| §5 #24 | `JeebMoneyBreakdown` | **REFUSED — see §9** | The plan (§5 #24 and 02-PLAN-ENHANCED §3.2) lists **14** as a consumer. It must not be. |
| §5 #3/#4 | `JeebOutlinedCard` / `JeebNavySurfaceCard` | **`JeebNavySurfaceCard` optional** | The cash card is exactly `JeebNavySurfaceCard(radius: 16, shadow: ctaNavy)`. Use it if the kit lands first; a local `Container` with the same three tokens is equivalent and is what I'd ship if 14 runs ahead of Wave 1. `JeebOutlinedCard` has no consumer here (the proof hero is a filled surface, not an outlined card). |

Everything else in `_ProofHero` (the two overlay pills, the hero itself) is one-screen composition and stays local to the feature — the plan has no badge/overlay primitive and inventing one for a single consumer is not worth a kit file.

---

## 4. New functionality

### 4.1 Tap-to-zoom proof viewer — NEW, and the only genuinely new interaction

`dc-tpl 837` renders a `Tap to zoom` pill. Nothing in the app opens an image full-screen today (`grep -rn "InteractiveViewer\|PhotoView" lib/` → zero hits).

Build it as a **modal on the local `Navigator`, not a route** (§5 below): `showGeneralDialog<void>` (or `Navigator.of(context).push(DialogRoute(...))`) with an opaque black barrier hosting

```
Semantics(identifier:'receipt_proof_viewer_root', explicitChildNodes:true)
└ Stack
  ├ Positioned.fill(InteractiveViewer(minScale: 1, maxScale: 4,
  │     child: Center(OmdsCachedImage(url:…, fit: BoxFit.contain))))
  └ PositionedDirectional(top: SafeArea inset + Spacing.small, end: Spacing.medium,
        child: Semantics(identifier:'receipt_proof_viewer_close', button:true,
                         label: l10n.receiptProofViewerCloseLabel, …))
```

`InteractiveViewer` is core Flutter — **no new dependency** (constraint 3). Reuse `OmdsCachedImage` so the already-cached bytes are shared with the hero and the viewer opens instantly offline.

**Cubit/state needs: none.** The viewer takes `receipt.proofPhotoUrl!` as an argument; the dialog owns its own lifetime. Guard the open on `receipt.hasProofPhoto` — no photo ⇒ the zoom pill is not rendered at all (the placeholder branch has nothing to zoom).

`use_build_context_synchronously`: the open is a fire-and-forget `unawaited(showGeneralDialog(...))` inside an `onTap`, with no `await` before a `context` use — clean.

### 4.2 Proof badge — half-buildable, and the honest half is the copy

`Proof of delivery · 9:38`. The `· 9:38` **cannot be built**: `_parseReceipt` (`dio_delivery_receipt_repository.dart:132-154`) never reads a capture time and `DeliveryReceipt` has no field for one (§7.6 already lists this). Do not substitute `DateTime.now()`, the delivery's `Done` transition time, or anything else — that is the JEBV4-176 lesson.

Ship `l10n.receiptProofBadge` = `"Proof of delivery"` and leave, on the badge widget:

```dart
// TODO(redesign-24): needs gateway proof-photo capture time — omitted, not faked.
```

If the owner wants the timestamp, it is a gateway field on `GET /v1/deliveries/{id}` plus one nullable `DateTime? proofCapturedAt` on the entity and one line in the parser. **Do not open that here.**

### 4.3 Emphasized money inside the sentence

`dc-tpl 842-843` renders `Pay ` + `<span 19/w800>$8</span>` + ` cash to Karim` — one sentence, one word heavier. Keep the existing l10n template (`receiptCashToJeeber(amount, jeeber)`, which already ships in EN + AR) and split on the formatted token:

```dart
final amountText = receipt.hasKnownAmount
    ? MoneyFormat.format(receipt.cashAmount!, currency: receipt.currency)
    : null;
final cashText = amountText != null
    ? l10n.receiptCashToJeeber(amountText, jeeberLabel)
    : l10n.receiptCashToJeeberNoAmount(jeeberLabel);
```

then, in `_CashStatement`, `final int i = amountText == null ? -1 : cashText.indexOf(amountText);` — when `i >= 0` build a `Text.rich` of three spans with the middle one at `FontWeight.w800`; otherwise render the plain `Text`. This is locale-proof (it finds the token wherever the AR template puts it), degrade-proof (the amount-unknown branch has no token and falls straight through), and **RTL-proof for free**: `MoneyFormat.format` already wraps its result in U+2066…U+2069, so the emphasized span stays LTR inside an Arabic paragraph.

Size: the ramp has no 19/w800 entry (`price` is 21, `titleProminent` is 17). Use `titleProminent.copyWith(fontWeight: FontWeight.w800)` — 17/w800. **Documented divergence: −2px on the amount.** Do not reopen `jeeb_text_styles.dart` for it (§4.6 — Wave 0 is closed), and do not use `price` (21) inline: at +4px over the sentence it breaks the line box. Note also that `Inter-ExtraBold.ttf` is deferred, so w800 renders as w700 today and the emphasis currently reads as size-only. That is the expected graceful degradation, not a bug to work around.

### 4.4 Copy changes (both CTAs + one new line)

| Key | Today | Board | Action |
|---|---|---|---|
| `receiptConfirmCta` | `Yes, I received it` / `نعم، استلمته` | `Yes, I got it` | **EN value change only.** The AR already reads exactly this. |
| `receiptNotYetCta` | `Not yet` / `ليس بعد` | `Not yet — something's wrong` | **Both locales change.** AR: `ليس بعد — هناك مشكلة`. The board's point is that the second CTA must telegraph the dispute fork, not read as a snooze. |
| `receiptCashNote` | — | `At the door. That's it — no card, no fees.` | **NEW.** AR: `عند الباب. هذا كل شيء — لا بطاقة ولا رسوم.` |
| `receiptProofBadge` | — | `Proof of delivery` | **NEW.** AR: `إثبات التسليم`. |
| `receiptProofZoomCta` | — | `Tap to zoom` | **NEW.** AR: `اضغط للتكبير`. |
| `receiptProofViewerCloseLabel` | — | (not drawn — a11y/close affordance for the new viewer) | **NEW.** EN `Close`, AR `إغلاق`. No generic close key exists (`feedbackCloseLabel`, `deliveryManProfileCloseLabel` are both feature-scoped). |

All six go through the integrator's serialized 4-edit batch (`app_en.arb` key + `@key` → real `app_ar.arb` value → `app_localizations.dart` getter → call site). The parity gate fails both directions, so none of them may land half-way.

`receiptTitle` ("Confirm receipt" / "تأكيد الاستلام") loses its only consumer when the app bar goes. It becomes an **orphan getter**, which `l10n_parity_check.sh:221` reports as `WARN`, not a failure. Leave the key: removing it is a 4-edit integrator churn that buys one warning line, and a future sheet/notification title may want it back.

---

## 5. New routes

**None.** The proof viewer is a modal over the receipt screen, not a destination:

- it has no deep link, no push target and no share URL;
- a real route would have to be added to `backFallbacks` (or explicitly justified out of it) and would widen `back_nav_all_routes_test.dart`'s surface for zero product gain;
- `app_router.dart` is integrator-owned and serialized (§7.4) — a Wave-2 lane adding a route for a lightbox is exactly the churn that ownership rule exists to prevent.

For the record, if the owner later wants it addressable the pattern would be
`GoRoute(path: '/orders/:id/receipt/proof', name: 'receipt-proof-viewer', builder: … ProofPhotoViewerScreen(url: state.uri.queryParameters['url'] ?? ''))` inside the same `_wrapRootAware([...])` band, with `backFallbacks['receipt-proof-viewer'] = '/'`. **I am not proposing it.**

---

## 6. Semantics identifiers

### Must survive (inventory — `grep -rn "identifier:" lib/features/delivery_receipt/`)

| Identifier | `file:line` today | Asserted by | After |
|---|---|---|---|
| `receipt_prompt` | `:107` | `jm-033:43` (`extendedWaitUntil`), `jm-032:81` | root, unchanged — still `explicitChildNodes: true`, now directly under `SafeArea` |
| `receipt_cash_to_jeeber_label` | `:262` | `jm-033:48` | wraps the navy `_CashStatement`, unchanged |
| `receipt_proof_photo` | `:234` | `jm-033:51` | wraps the image **and** the placeholder, unchanged (`image: true` + `label:` kept) |
| `receipt_confirm_cta` | `:311` | `jm-033:54,67`, `jm-034:47,51,141,145` | wraps `JeebCtaButton.primary`, unchanged (keep the `Semantics(container/button/enabled/label/onTap) + ExcludeSemantics(child:)` idiom at `:310-329` verbatim) |
| `receipt_not_yet_cta` | `:334` | `jm-033:57,88,94` | wraps `JeebCtaButton.outline`, unchanged |
| `receipt_confirm_error` | `:296` | nothing (frozen by §7.1.2 anyway) | moves into the footer above the primary CTA so a failed confirm is visible without scrolling; **value unchanged** |
| `receipt_no_commission_line` | **never emitted** | `jm-033:60-61` `assertNotVisible` | **stays never emitted.** This is a negative assertion — see §9. |

Widget `Key`s to keep too (they are cheap and something may key on them): `Key('receipt-load-error')` `:136`, `Key('receipt-confirm-cta')` `:321`, `Key('receipt-not-yet-cta')` `:342`. Pass them through to the kit buttons' `key:`.

### New

| Identifier | On | Notes |
|---|---|---|
| `receipt_proof_zoom_cta` | the `Tap to zoom` pill | `button: true`, `label: l10n.receiptProofZoomCta`, `onTap:` opens the viewer. Rendered only when `receipt.hasProofPhoto`. |
| `receipt_proof_viewer_root` | the modal's root | the new surface's single `<screen>_root` (§7.5). |
| `receipt_proof_viewer_close` | the modal's ✕ | `button: true`. |

The hero `Stack` gets a `GestureDetector` so tapping anywhere on the photo opens the viewer (that is what "Tap to zoom" promises), but the **addressable** affordance is the pill — the gesture detector adds no identifier and must not swallow `receipt_proof_photo`, so wrap the stack in `Semantics(container: true, explicitChildNodes: true, child: GestureDetector(...))` per the `active_request_card.dart` idiom.

---

## 7. RTL

| Risk | Mitigation |
|---|---|
| Both overlay pills are corner-anchored (`left/top`, `right/bottom`) | `PositionedDirectional(start:/top:)` and `PositionedDirectional(end:/bottom:)`. A `Positioned(left:)` here would put the "Proof of delivery" badge on the wrong side in `ar` and is the single easiest mistake on this screen. |
| Cash card glyph leads the text | plain `Row` — auto-mirrors. Gap via `SizedBox(width: Spacing.small)`, which is direction-neutral. |
| Primary CTA is `✓ + label` | centered `Row(mainAxisAlignment: .center)` — the glyph moves to the trailing side under `ar`, which is correct. |
| Money inside a sentence | already handled: `MoneyFormat.format` emits U+2066…U+2069 (`money_format.dart:11-23`). The `Text.rich` split preserves the isolate because it splits *on* the isolate-wrapped token, keeping both marks inside the emphasized span. |
| All paddings | `EdgeInsetsDirectional` throughout, including the footer's `fromSTEB(24, 0, 24, 32)`. |
| New AR strings contain `—` and mixed punctuation | require real translations from the integrator batch, not transliterations. `— هناك مشكلة` reads correctly RTL; the dash is direction-neutral. |
| Viewer close button | `PositionedDirectional(end:)`, not `Positioned(right:)`. |

---

## 8. Test impact

| Test | Effect | Legitimate? |
|---|---|---|
| `test/core/router/w1_routes_resolve_test.dart:198-214` | **Should stay green.** It asserts `find.byType(DeliveryReceiptScreen)` after two bare `pump()`s. `OmdsCachedImage` is retained, so the comment at `:203-208` (never-completing HTTP fetch ⇒ don't `pumpAndSettle`) still holds. The `SliverFillRemaining` layout renders fine on the 800×600 default surface. | n/a — no change expected. If it goes red, my layout is wrong (probably an unbounded-height sliver), not the test. |
| `test/features/delivery_receipt/dio_*_test.dart` ×4 | untouched — repository-level, no widget import. | n/a |
| `test/core/router/back_nav_all_routes_test.dart:96-118` | untouched — `'delivered-receipt'` stays in `backFallbacks`; removing the `OMDSAppBar` does not touch route wrapping (the app bar already had `showBackButton: false`). | n/a |
| `test/decision_violations_test.dart` | untouched. Nothing in it pins this screen; the earnings-framing group (`:176-206`) is `settlement_detail`. My proposal adds **no** fee/commission string to this file. | n/a |
| `tool/check_design_tokens.sh` | must stay clean: no `fontSize:`, no `Color(0x`, no `Colors.<name>`, no `BorderRadius.circular(N)`, no `SizedBox(height: <literal>)`, no `EdgeInsets.<x>(<number>)`. The 230px hero height goes through a named private const, which the script does not match. | n/a |
| `qa/t-mob-fix-002/l10n_parity_check.sh` | 4 new keys × 2 locales + 2 EN value edits + 1 AR value edit, all via the integrator batch. `receiptTitle` becomes an orphan getter → `WARN` only (`:221`). | expected |
| `lib/devtool/catalog/entries/batch_03_entries.dart:213-256` | all three catalog states still compile — the `DeliveryReceiptScreen({deliveryId, repository})` constructor is untouched (§7.4: never delete a constructor seam). State 2 ("amount unknown") now exercises the no-emphasis branch of §4.3 and state 2's `proofPhotoUrl: null` exercises the placeholder + suppressed zoom pill. Both are *better* coverage than before. | improvement |
| Maestro `jm-033` / `jm-032` / `jm-034` | all assertions are `id:`-based; every id survives. The two CTA **text** changes are invisible to Maestro. Not in CI — re-run on the S22 per the real-flow standard before calling this done. | expected |
| **New tests I recommend adding** (the screen has none) | `test/features/delivery_receipt/delivery_receipt_screen_test.dart`: (1) all six identifiers emitted on the loaded body; (2) `receipt_no_commission_line` **findsNothing** and no `find.textContaining('%')` / `'Commission'` / `'Platform fee'` anywhere — pin AC4 in CI instead of only in an out-of-CI Maestro flow; (3) `hasProofPhoto == false` ⇒ `receipt_proof_zoom_cta` findsNothing; (4) tapping `receipt_proof_zoom_cta` pushes `receipt_proof_viewer_root`; (5) an `ar` pump for RTL smoke. Additive only — no existing assertion is weakened. | strongly recommended |

Nothing in the existing suite has to be edited. That is the tell that the restyle is well-scoped.

---

## 9. Conflicts

**K1 — `JeebMoneyBreakdown` must NOT be used on this screen. Refused.**
Plan §5 #24 lists this widget's consumers as "14 17 19", and 02-PLAN-ENHANCED §3.2 repeats "17 (+14, 19)". That is wrong for 14 and it is the one place where following the plan literally would break a locked contract:
- the render contains **no breakdown at all** — one navy statement line, nothing itemized;
- the note says it in words: *"Deliberately no commission line — platform economics never show on customer surfaces"*;
- `jm-033-confirm-receipt.yaml:59-61` is an `assertNotVisible: id: receipt_no_commission_line` (AC4), and JM-033 AC4 / D11 are cited in three separate doc comments in the current file (`:29-32`, `:47`, `:289-292`);
- `JeebMoneyBreakdown` is explicitly *"the single enforcement point for D41/D44 wording and `kJeebCommissionRate`"* — i.e. it exists to render a platform-fee row. Mounting it here would put the fee on the customer's screen by construction.

**Resolution: 14 is not a `JeebMoneyBreakdown` consumer.** The plan's consumer list should read "17, 19". The `receipt_no_commission_line` identifier stays a negative assertion — nothing emits it, ever.

**K2 — the proof-photo timestamp is a data gap, not a design decision.** `· 9:38` is refused as drawn and shipped as `Proof of delivery` + a `TODO(redesign-24)` (§4.2). No endpoint, no field, no `DateTime.now()` stand-in.

**K3 — the HTML's inset floating illustration is refused as a rule.** `dc-tpl 835` renders a 190px-wide 3D asset floating on the `#EAE7EB` ground with a drop shadow. That is mock art for a mock; a real courier's proof photo must fill the r20 frame (`BoxFit.cover`). Rendering real photos "floating at 190px" would look broken for every non-square photo. The `#EAE7EB` ground is kept — it is what shows through while loading and in the no-photo state, which is what the token actually tokenizes.

**K4 — R7 ("no white card carries a shadow") vs. the white zoom pill.** `dc-tpl 837` gives a white pill a `0 4 12 rgba(11,19,81,.15)` shadow. This is not a violation: R7 is about resting cards in a list. A chip floating over photographic content needs separation, and the board does the same on 12's map ETA pill — which is exactly what `JeebShadows.floatPill` was cut for. Using `floatPill` here keeps one token per pattern.

**K5 — no other conflicts.** `test/decision_violations_test.dart`, `no_raw_semantic_colors_test.dart` (this file is not listed), `color_role_contrast_test.dart`, D56, D52, D20, B04, the accept-sheet tense pin and the pinned-chat-summary pin are all untouched by this screen. The board and the shipped contract agree on everything else, including — notably — the fork itself: confirm → `mutual-rating` (D56 terminal, stack replaced), not-yet → `escalate` (JM-060). Those two navigations at `:113-128` and `:359-364` are **not** to be touched.

---

## 10. Wiring requests (integrator / Wave-1 kit owner)

1. **l10n batch** — 4 new keys (`receiptCashNote`, `receiptProofBadge`, `receiptProofZoomCta`, `receiptProofViewerCloseLabel`) + 2 EN value edits (`receiptConfirmCta`, `receiptNotYetCta`) + 1 AR value edit (`receiptNotYetCta`). Values in §4.4.
2. **`JeebCtaButton` needs `isLoading`** (spinner replaces glyph+label, taps suppressed) — without it the confirm CTA loses the in-flight state it ships today, which is a functional regression, not a restyle.
3. **`JeebCtaFooter` needs a `stack` form** — primary pill + `Spacing.small` + outline pill, pad `0/24/32`. This is a fourth realized footer shape (14 is the only spine screen with a vertical CTA pair) and it should be named in the kit rather than hand-rolled here.
4. **Plan correction** — remove `14` from `JeebMoneyBreakdown`'s consumer list in `00-MIGRATION-PLAN.md` §5 #24 and `02-PLAN-ENHANCED.md` §3.2 (§9 K1).
5. **No router change, no DI change, no `pubspec.yaml` change.**
