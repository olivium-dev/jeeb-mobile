# 04 · Client home — change proposal

Screen id: `04-client-home` · Feature dir: `lib/features/home_client/` · Wave 3
Verdict: **rebuild** (top third is new structure + a new interaction; the two list cards are
restyled from flat divider rows into outlined cards).

Sources read: `screens/04-client-home.png` (image), `screens/04-client-home.html` (all 96 lines),
`screens/04-client-home.note.md`, `00-MIGRATION-PLAN.md`, `02-PLAN-ENHANCED.md`, and every Dart
file + test listed in §1.

---

## 0. Executive summary — the five things that decide this screen

1. **The `+` is deleted and the mic hero replaces it.** That is not a restyle: it reverses an
   explicit **owner directive** from 2026-07-22 (`3d6afae7` — *"FAB and 'Record a request' voice CTA
   removed; only entry points are the top plus and the empty-state CTA"*), and two test files pin the
   absence of a voice CTA on this exact screen. **§9-C1 — owner decision, do not build until confirmed.**
2. **`orders_create_request_button` must survive on the hero.** Three Maestro taps
   (`jm-024` ×3, `jm-023` ×1) route it to `request_type_continue_cta`. Re-home the id onto the hero's
   body tap target; the mic gets a *new* id (`client_home_mic_cta`).
3. **The board's periwinkle-on-white meta text re-opens a fixed a11y defect.**
   `active_request_card.dart:293-298` documents UX-AUDIT §T3 — periwinkle on white is 3.76:1 and was
   deliberately moved onto `onSurfaceVariant` (7.5:1). The board puts `12 Jeebers reached`,
   `3 offers · from $8` and the greeting eyebrow back on periwinkle. **Refused on white; kept on
   navy** (periwinkle-on-navy measures 4.55:1 and passes). §9-C4.
4. **Two of the board's three "new data" items are real gaps; the third is half-buildable.**
   `12 Jeebers reached` has no source anywhere (§7.6/C6) → omit. The card waveform + `0:07` needs a
   "this was a voice request" flag + duration that no payload carries → omit. `from $8` **is**
   derivable at zero extra network cost, but only on rows the existing offer probe already fired for
   (§6.3).
5. **The shell already owns this screen's header-right and its 5-tab bar.**
   `shell_screen.dart:300-325` overlays `ShellHeaderActions` (wallet chip + bell) on top of the body,
   and the shell tab set is already `Requests · Delivery · Dashboard · Earnings · Profile` — the
   board's exact bar. So `JeebProfileHeader.trailing` must be **empty** on this screen (or the bell
   doubles), and the bottom-bar restyle is the shell lane's, not mine. §11 wiring requests.

---

## 1. What actually renders today (verified, not assumed)

| File | LOC | Role |
|---|---|---|
| `lib/features/home_client/presentation/client_home_screen.dart` | 514 | root, 3 load layouts, chip bar |
| `.../presentation/widgets/client_home_greeting.dart` | 199 | avatar + "Hello, X" + `+` button |
| `.../presentation/widgets/client_home_empty_view.dart` | 82 | pending-empty illustration + CTA |
| `.../presentation/tabs/pending_requests_tab.dart` | 437 | Pending list + card (**in the raw-color gate**) |
| `.../presentation/tabs/replies_tab.dart` | 247 | Replies list + nav |
| `.../presentation/widgets/replies_card.dart` | 289 | Replies row + avatar stack + 2 CTAs |
| `.../presentation/widgets/active_request_card.dart` | 450 | In-Progress card + `ClientHomeTierBadge` |
| `.../presentation/widgets/pending_request_card.dart` | 116 | **dead** — `PendingCountdownCard` is what the tab builds |
| `.../presentation/tabs/in_progress_tab.dart` | 247 | dev-seam-only surface (chip removed by JEBV4-298) |

Two structural facts the render hides:

- `ClientHomeScreen` is **not** a route. It is the `requests` shell tab, wrapped by
  `_HeaderedTab(idPrefix: 'orders_home')` (`shell_screen.dart:300-325`) which `Stack`s
  `ShellHeaderActions` (wallet chip + bell → `/notifications`) at `PositionedDirectional(top: 0,
  end: Spacing.xSmall)`. **The board's bell already exists and is not mine to build.**
- The body is a single `ListView` (`client_home_screen.dart:326-336`), so R1's "spacer is real
  emptiness" is already satisfied structurally — content just ends. Do not add a `Spacer`.

`pending_requests_tab.dart` is listed in `test/core/theme/no_raw_semantic_colors_test.dart:24`.
In that file `.tertiary*`, `Color(0x`, and `Colors.<palette>` are hard-banned, and the test asserts
the file exists at that path — **do not move or rename it**. Orange there comes only from
`context.jeebRoles.accent`.

---

## 2. Semantics inventory — the freeze list

Every one of these must still be emitted after the change. Grepped from
`lib/features/home_client/` (§7.5 of the plan):

| Identifier | File:line today | Where it lives after |
|---|---|---|
| `client_home_root` | `client_home_screen.dart:197` | unchanged |
| `orders_create_request_button` | `client_home_greeting.dart:186` | **moves** to `ClientHomeRequestHero` body tap |
| `orders_filter_pendingRequests` / `orders_filter_replies` | `client_home_screen.dart:484` | `JeebSelectChip` wrapper |
| `orders_home_replies_tab` | `client_home_screen.dart:506` | unchanged (outer wrapper) |
| `_request_empty_state_root` | `client_home_empty_view.dart:20` | unchanged |
| `_request_empty_state_new_order_button` | `client_home_empty_view.dart:73` | unchanged |
| `_request_empty_state_avatar` | `client_home_greeting.dart:172` | `JeebProfileHeader` avatar slot |
| `orders_home_request_row_$i` | `pending_requests_tab.dart:128` | unchanged (wraps the card) |
| `pending_requests_item_${id}` | `pending_requests_tab.dart:160` | unchanged |
| `replies_check_offers_cta` | `replies_card.dart:174` | the navy `View offers` pill |
| `replies_accept_cta` | `replies_card.dart:160` | outline pill, kept — §9-C3 |
| `orders_replies_avatar_stack_$id` | `replies_card.dart:212` | `JeebAvatarStack` wrapper |
| `orders_active_card_$id` / `orders_open_chat_button_$id` / `orders_track_order_button_$id` | `active_request_card.dart:44/399/439` | unchanged (dev-seam surface) |

Shell-owned, untouched but present on this screen: `orders_home_wallet_chip`, `orders_home_bell`,
`shell_tab_requests`.

**New identifiers proposed** (convention `<screen>_<element>`):

| New id | Element | Action |
|---|---|---|
| `client_home_hero` | the navy hero card (container node) | `container: true, explicitChildNodes: true` — required or it swallows the two children (`active_request_card.dart:37-42` is the canonical idiom) |
| `client_home_mic_cta` | Ø56 orange mic circle | `pushNamed('voice-request')` |
| `client_home_request_card_${request.id}` | the outlined Replies card shell | replaces nothing; additive |

**Deliberately NOT used:** `client_home_voice_request`. That literal is pinned *absent* by
`client_home_screen_test.dart:191` and `home_tab_create_request_fab_test.dart:129`. Coining a new id
rather than flipping a pinned negative assertion keeps the retired-feature guard honest.

---

## 3. Layout & structure

### 3.1 `client_home_screen.dart:338-358` — `_ReadyLayout._scrollChildren()`

Today: `[greeting, SizedBox(large), tabBar, SizedBox(large), content]`.
Becomes (HTML tpl 158 → 214):

```
JeebProfileHeader           // pad 16/24/0, gap 14
SizedBox(Spacing.medium)    // 18px design → medium(16)
ClientHomeRequestHero       // NEW, margin 18/24/0
SizedBox(Spacing.large)     // 20px design → large(20)
_ClientHomeTabBar           // pad 0/24, gap 10
SizedBox(Spacing.medium)    // 18px design → medium(16)
_ReadyContent               // pad 0/24, card gap 12
```

Gutter changes from `Spacing.medium` (16) to `Spacing.xLarge` (24) on **every** child — the design's
`--screen-gutter` is 24 and today's screen is at 16. This is the single most visible density change
(R1/R12) and it must be applied to the tab bar, the hero, the list, and the card padding together or
the columns will not align.

### 3.2 `client_home_greeting.dart` — rewrite as `JeebProfileHeader` consumer

Delete `_AddRequestButton` (`:176-199`), `_GreetingLine` (`:81-119`), `_GreetingText` (`:121-139`),
`_GreetingAvatar` (`:141-174`). Keep `ClientHomeGreeting` as the thin adapter that reads
`GreetingProfileCubit` (`:72-78`) and the `displayNameOrNull` synthetic-handle suppression (`:45`) —
that logic is load-bearing (`client_home_greeting_test.dart:131-165`) and has nothing to do with
layout.

```dart
JeebProfileHeader(
  avatar: JeebAvatar.header(              // Ø46, initial 17/w800
    initial: firstName,
    imageUrl: avatarUrl,
    identifier: avatarSemanticsIdentifier, // '_request_empty_state_avatar'
  ),
  eyebrow: l10n.homeGreetingEyebrow(...),  // NEW key, §6.1
  title: greeting,                          // existing homeGreetingNamed / homeGreetingFallback
  trailing: null,                           // the SHELL paints the bell — §11-W1
)
```

`_GreetingText`'s `textTheme.titleLarge.copyWith(fontWeight: w400)` (`:131-134`) becomes
`context.jeebText.h2.copyWith(color: cs.primary)` — 20/w700. The board specs 19/w700; `h2` at 20 is
the nearest ramp entry and §4.2 forbids `fontSize:` literals in `lib/features`. Do not add a ramp
entry for 19.

**Reserve trailing space.** Because the shell overlays two Ø48 `IconButton`s at the top-end, the
header's title must not run under them: give `JeebProfileHeader` a `trailingReserve` of
`Spacing.fourXLarge * 2` on this screen, or the name ellipsizes into the wallet glyph at long names /
200% text.

### 3.3 NEW `.../presentation/widgets/client_home_request_hero.dart`

The signature element. HTML tpl 166–181.

```dart
JeebNavySurfaceCard(
  radius: JeebRadius.xLarge,        // 24 (kit-local const; features may not write 24)
  shadow: JeebSurfaceShadow.none,   // 04's hero has NO shadow — R6(b), plan §5 #4
  decorativeRing: JeebAccentRing.large, // Ø140, 1.5px accentRing, top-END, off-canvas, ClipRRect'd
  padding: Spacing.medium + 2,      // 18 → use kit const; feature passes a role, not px
  child: Row(children: [
    JeebMicHero.small(              // Ø56 + the measured two-shadow glow
      identifier: 'client_home_mic_cta',
      onTap: () => GoRouter.of(context).pushNamed('voice-request'),
      semanticLabel: l10n.homeMicLabel,          // existing 'Hold to speak'
    ),
    const SizedBox(width: Spacing.small + 2),    // 14
    Expanded(child: Column(
      Text(l10n.homeEmptyTitle, style: jeebText.titleProminent.copyWith(color: cs.onPrimary)),
      Text(l10n.homeHeroSubtitle, style: jeebText.bodySmall.copyWith(color: mutedText)),
    )),
    const JeebWaveform.onNavy(),     // 5 bars, w3/gap3, h 9/17/11/20/10, container h24
  ]),
)
```

Wrapped in `Semantics(identifier: 'client_home_hero', container: true, explicitChildNodes: true)`,
and the **body** (title + subtitle + waveform column, not the mic) wrapped in
`Semantics(identifier: 'orders_create_request_button', button: true, label: l10n.homeEmptyCta)` over
a `GestureDetector(onTap: onCreateRequest)` — that preserves the frozen id and the jm-023/jm-024
route contract.

Render the hero in **all three** layouts (`_LoadingLayout:259`, `_FailedLayout:280`, `_ReadyLayout`).
Today the `+` renders in all three, and `client_home_429_tolerant_test.dart:196` asserts
`orders_create_request_button` is reachable on a degraded load. Dropping it from loading/failed would
be a regression.

`JeebWaveform.onNavy` must be `Visibility`-gated below ~360dp logical width or at
`textScaler.scale(13) > 20` so the 200%-text case does not overflow the row.

### 3.4 `client_home_screen.dart:408-514` — the chip bar

`_ClientHomeTabChip` (`:461-514`) currently builds an `OmdsChip` with
`borderRadius: OmdsBorderRadius.xSmall` (8px) — the exact "8px chips next to pill buttons"
inconsistency §2 of the plan names. Replace the body with `JeebSelectChip(role: JeebChipRole.filter)`
(pad `11/20`, 14.5/w600) and **keep both `Semantics` wrappers verbatim** (`:483-511`), including the
`extraIdentifier` nesting for `orders_home_replies_tab`.

Add the count (HTML tpl 183/185): pass `count: state.pending.length` / `state.replies.length`.
The board renders the count two ways and `JeebSelectChip` must honour both: **selected** → inline
white text in the same 14.5/w600 (`Pending 1`); **unselected** → the Ø18 solid-orange badge, white
11/w800, pad `0/4` (`Replies ③`). Do not render an orange badge on the navy chip — the board doesn't,
and R8 says internals re-tone to `rgba(255,255,255,.14)` on navy.

`_ClientHomeTabBar` (`:429-430`) padding `Spacing.medium` → `Spacing.xLarge`; gap
`Spacing.xSmall` (8) → 10 via `JeebChipRow`'s own gap.

### 3.5 `pending_requests_tab.dart` — flat rows become outlined cards

- `_PendingList` (`:109-139`): `Column` gains `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)`
  and a 12px gap between rows (`Spacing.small`). Keep the `orders_home_request_row_$i` wrapper
  exactly as written.
- `_PendingCardBody` (`:176-203`): **delete the `Divider`** (`:194-197`) and wrap the column in
  `JeebOutlinedCard(radius: 16, padding: 16)` — white, `1.5px colorScheme.outline`, **no shadow**
  (R7). The `Padding(horizontal: medium, vertical: small)` becomes the card's own padding.
- `_PendingCardHeader` (`:244-274`): title style `textTheme.titleLarge.copyWith(w400)` →
  `context.jeebText.cardTitle` (15.5/w700) with `color: cs.onSurface`. The trailing
  `ClientHomeTierBadge` becomes `JeebTierChip` (§4, §5).
- `_PendingServerStatus` (`:296-322`): the `Icons.search_rounded` + `labelMedium` line becomes the
  board's live-state pair — a Ø7 `context.jeebRoles.accent` dot + the same string at
  `jeebText.bodySmall.copyWith(fontWeight: w700, color: jeebRoles.accent)`.
  **Keep `Key('pending-server-status')` and `l10n.pendingTabSearchingLabel`** (§9-C5).
- `_PendingCreatedAge` (`:356-373`) stays; restyle to `jeebText.caption` + `cs.onSurfaceVariant`.
  The design has no age line, but this is a truthful past-fact the board simply didn't draw — keeping
  it is cheaper than losing it. Place it as the row-2 trailing item where the board puts
  `12 Jeebers reached`.
- `_PendingOffersBadge` (`:328-350`): leave the `OmdsChip` type intact —
  `pending_requests_tab_test.dart:330` reads `tester.widget<OmdsChip>(...).isSelected`. The Wave-0
  `chipTheme.shape → StadiumBorder()` already pills it.

Resulting card = HTML tpl 187: header row (title + tier chip), `margin-top 12`, meta row
(`● Searching for Jeebers…` + spacer + age line).

### 3.6 `replies_card.dart` — same card shell, board's action row

- `RepliesCard.build` (`:37-75`): drop the `Divider` (`:66-69`), wrap in `JeebOutlinedCard`.
  **Keep `Semantics(explicitChildNodes: true)` at `:52`** — the comment there explains it is what
  stops the avatar-stack id from swallowing the two CTA ids, and
  `semantics_identifier_surfacing_test.dart:188-233` pins exactly that.
  Add `identifier: 'client_home_request_card_${request.id}'` on the outer node.
- `_RepliesHeader` (`:78-109`): today it puts the avatar stack in the header. The board puts the
  **tier chip** there and moves the stack to row 2. Swap: header = `Expanded(title, cardTitle)` +
  `JeebTierChip`. Title color `secondaryContainer` (`:93`) → `cs.onSurface` — a container role used
  as ink is the exact pattern `no_raw_semantic_colors_test`'s fourth regex bans, and
  `pending_requests_tab.dart:258-260` already carries the fix comment for the same bug.
- `_RepliesSummary` (`:111-129`): the board's card has no summary line. **Keep it** — it is the
  customer's own request text (`summaryLine`, G1) and deleting it makes the card unidentifiable when
  `displayId` is present. Demote to `jeebText.bodySmall` + `cs.onSurfaceVariant`, `maxLines: 1`.
- Row 2 (new): `JeebAvatarStack` + `Expanded(offers-summary text)`.
- Row 3: `_RepliesActions` (`:140-187`) end-aligned — `Accept` as `JeebSelectChip(role: inlineAction)`
  outline, then `View offers` (= `homeRepliesCheckOffersCta`) as the navy `inlineAction` pill,
  pad `9/16`, 13/w600. Both keep their `IntrinsicWidth` ancestor: `client_home_screen_test.dart:651`
  and `:675` assert `find.ancestor(..., IntrinsicWidth)`.

The board draws **one** pill; we ship two on separate rows. §9-C3 explains why.

- `_OfferAvatarStack` (`:193-226`) / `_OverlappingAvatars` (`:228-253`): replace the `Stack` +
  `PositionedDirectional` with `JeebAvatarStack` (Ø30, `2px` white ring, **−9px** overlap via
  `EdgeInsetsDirectional`, initial 11/w800, fill rotation `[primary, mutedText, jeebRoles.accent]`).
  Keep the `orders_replies_avatar_stack_$id` `Semantics` (`:211-213`) and the `+N` overflow
  (`_OfferOverflowCount:255-271`) — `replies_tab_test.dart:84/100` and
  `client_home_screen_test.dart:419` pin `+2` / `+6`.
  **Do not fabricate the board's `K N R` initials** — no offerer name reaches this state (§6.3).
  `_OfferAvatar` (`:273-289`) hardcodes `initial: 'J'`; render `JeebAvatar` in its
  `surfaceContainerHighest` + periwinkle **dormant** treatment (R11) when there is no url and no
  name, which is the honest "unknown person" mark the plan already defines.

### 3.7 `client_home_empty_view.dart` — de-duplicate the headline

With the hero on screen, `OmdsEmptyState(title: l10n.homeEmptyTitle)` (`:32`) prints
"What do you need?" **twice**. Delete the `title:` argument; keep the illustration, the
`homePendingEmpty` subtitle, and the CTA. `_NewOrderButton` (`:64-82`) →
`JeebCtaButton.outline` (the hero now owns the one primary create action;
`OmdsBorderRadius.uiSmall` at `:77` → pill). Both `Semantics` wrappers unchanged.

### 3.8 Not touched

`in_progress_tab.dart` and `active_request_card.dart` beyond the `ClientHomeTierBadge` swap — the
In-Progress chip was removed by JEBV4-298 and the surface is dev-seam-only. `pending_request_card.dart`
is dead code (`PendingCountdownCard` in the tab is what renders); leave it, do not "clean it up" —
`sort_constructors_first`-clean dead code is not this lane's diff.

---

## 4. Token bridge — every literal that must become a token

| Where (file:line) | Today | Becomes |
|---|---|---|
| `client_home_greeting.dart:48-53` | `EdgeInsets.fromLTRB(medium, medium, medium, xSmall)` | `EdgeInsetsDirectional.fromSTEB(xLarge, medium, xLarge, 0)` |
| `client_home_greeting.dart:131-134` | `titleLarge.copyWith(w400)` | `context.jeebText.h2` + `cs.primary` |
| `client_home_greeting.dart:167-168` | `surfaceContainerHigh` / `primary` on Ø `Sizes.large` avatar | `JeebAvatar.header` (Ø46) — same roles, kit-owned px |
| `client_home_greeting.dart:194-195` | `Icon(Icons.add)` + `OmdsButtonStyles.iconButtonFilled` | **deleted** |
| `client_home_screen.dart:430` | `EdgeInsets.symmetric(horizontal: Spacing.medium)` | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` |
| `client_home_screen.dart:493-500` | `OmdsChip(... borderRadius: OmdsBorderRadius.xSmall)` | `JeebSelectChip(role: filter)` — pill |
| `client_home_screen.dart:349/351` | `SizedBox(height: Spacing.large)` ×2 | `medium` / `large` per §3.1 |
| `pending_requests_tab.dart:185-187` | `symmetric(horizontal: medium, vertical: small)` | card padding inside `JeebOutlinedCard` |
| `pending_requests_tab.dart:194-197` | `Divider(outlineVariant)` | **deleted** — the outline is the separator now (R7) |
| `pending_requests_tab.dart:261-263` | `titleLarge.copyWith(w400)`, `onSurface` | `context.jeebText.cardTitle` |
| `pending_requests_tab.dart:287-288` | `bodySmall`, `onSurfaceVariant` | `context.jeebText.bodySmall`, `cs.onSurfaceVariant` |
| `pending_requests_tab.dart:306-318` | `Icons.search_rounded` + `cs.primary` + `labelMedium` | Ø7 dot `context.jeebRoles.accent` + `jeebText.bodySmall` w700 accent |
| `pending_requests_tab.dart:368-370` | `labelSmall`, `onSurfaceVariant` | `context.jeebText.caption`, `cs.onSurfaceVariant` |
| `replies_card.dart:42-45` | `symmetric(horizontal: medium, vertical: small)` | `JeebOutlinedCard` padding |
| `replies_card.dart:67-68` | `Divider(height: 1, outlineVariant)` | **deleted** |
| `replies_card.dart:92-94` | `titleLarge.copyWith(w400)` + `secondaryContainer` **as ink** | `context.jeebText.cardTitle` + `cs.onSurface` (role-misuse fix) |
| `replies_card.dart:121-123` | `bodySmall` + `onSurfaceVariant` + `letterSpacing: 0.4` | `context.jeebText.bodySmall`, drop the tracking |
| `replies_card.dart:166/180` | `OMDSBorderRadius.pill` / `OmdsBorderRadius.pill` | kept — already pill |
| `replies_card.dart:235-238` | `Sizes.medium` overlap on `Sizes.large` avatars | `JeebAvatarStack` (Ø30, −9) |
| `replies_card.dart:265-267` | `titleMedium.copyWith(w500)` | `context.jeebText.badge` |
| `replies_card.dart:284-287` | `initial: 'J'` hardcoded | dormant `JeebAvatar` — §6.3 |
| `active_request_card.dart:244-251` | `Text` in `labelSmall` tinted by `JeebTierColors` | `JeebTierChip` (pill `surfaceContainerHigh`, emoji + navy w700) |
| `active_request_card.dart:242` | `?? theme.colorScheme.tertiary` fallback | drop — the chip ink is navy for all tiers |
| `client_home_empty_view.dart:77` | `OmdsBorderRadius.uiSmall` | `JeebCtaButton.outline` (pill) |

Colors that do **not** change: `colorScheme.primary` (navy), `outline` (#916F66 — this *is* the
1.5px card border), `surfaceContainerHigh` (chips, avatar fills), `onSurfaceVariant`. The palette is
byte-identical to the redesign tokens (plan §1); nothing here is a hex swap.

Orange enters this screen at exactly four places, all `context.jeebRoles.accent`, all "happening
now" (R5): the mic fill, the mic glow, the live dot on a broadcasting request, and the chip count
badge. Plus one decorative `JeebSemanticColors.accentRing` on the hero. `accentTint` is **not** used
here (its only board-wide consumer is 07).

---

## 5. Shared components consumed

| Kit widget (plan §5) | Used for | Notes for the kit owner |
|---|---|---|
| **#23 `JeebProfileHeader`** | the greeting row | needs `trailing: null` + a `trailingReserve` so the shell overlay doesn't collide |
| **#4 `JeebNavySurfaceCard`** | the hero | **must support `shadow: none`** and the off-canvas Ø140 ring — 04 is the reason that param exists |
| **#15 `JeebMicHero`** (Ø56) | the mic | the two-shadow glow `0 0 0 6 rgba(215,59,0,.22)` + `0 10 22 rgba(215,59,0,.45)` is measured from *this* screen |
| **#14 `JeebWaveform`** | `.onNavy` in the hero; `.cardMark` **not used** (§6.2) | 04 is the only consumer of `.onNavy` |
| **#6 `JeebSelectChip` / `JeebChipRow`** | filter chips (`role: filter`), `Accept` + `View offers` (`role: inlineAction`) | needs the two count-rendering modes in §3.4 |
| **#7 `JeebTierChip`** | the tier meta chip on both cards | **emoji and label must be two `Text` children**, not one string — `find.text('Flash')` / `find.text('سريع')` / `find.text('إكسبرس')` are asserted in 3 tests |
| **#3 `JeebOutlinedCard`** | both list cards | r16, `1.5px outline`, pad 16, **no shadow** |
| **#9 `JeebAvatar` / `JeebAvatarStack`** | header Ø46 (+ unread dot), replies Ø30 stack | needs the *dormant* fill (`surfaceContainerHighest` + periwinkle initial) — 04 has no offerer names |
| **#2 `JeebCtaButton`** (`outline`) | the empty-state CTA | |

Not consumed: `JeebTopBar` (04 has no top bar — plan §5 #1 says so explicitly), `JeebInfoNote`,
`JeebMoneyBreakdown`, `JeebStepper`.

**Ordering dependency:** this lane is blocked on kit steps 1, 3, 4, 5, 6 and 8 of §5.1. It cannot
start before `JeebOutlinedCard` + `JeebNavySurfaceCard`, `JeebProfileHeader`, `JeebSelectChip`,
`JeebAvatarStack`, `JeebWaveform` and `JeebMicHero` exist, because every design-exact px on this
screen (46, 56, 24, 30, −9, 1.5, 999) is banned in `lib/features` by `tool/check_design_tokens.sh`
and legal only inside `lib/core/widgets/jeeb/`.

---

## 6. New functionality, and what it needs from the data layer

### 6.1 Hero — voice + type, two targets, one card (BUILDABLE, pending §9-C1)

- Mic tap → `GoRouter.of(context).pushNamed('voice-request')`. The route exists
  (`app_router.dart:1059-1060`, `backFallbacks['voice-request'] = '/'` at `:481`). No new route.
- Body tap → the existing `onCreateRequest` → `/request-type`. Unchanged contract.
- **"Hold to talk" is refused as written.** `VoiceRecordingScreen`
  (`voice_recording_screen.dart:60-61`) has no auto-start seam, so a press-and-hold on *this* screen
  cannot begin a recording — the hold would end before the recorder mounts. Ship the honest subtitle
  and a real `onLongPress` that simply routes (same target as tap), so the muscle memory works even
  though the copy is truthful.
  New l10n key `homeHeroSubtitle` — EN `"Tap the mic to talk · or type instead"`,
  AR `"اضغط الميكروفون للتحدث · أو اكتب بدلاً من ذلك"`.
  If the owner wants literal hold-to-talk, it needs an `autoStartRecording` seam on
  `VoiceRecordingScreen` — that file belongs to the 05 lane (§11-W3).
- Eyebrow: new plural-free keys `homeGreetingEyebrowMorning` / `...Afternoon` / `...Evening`,
  selected from `DateTime.now().hour` **on device**. This is a client-side derivation of the device
  clock, not server data — no §7.6 issue. If the owner would rather not add three strings, drop the
  eyebrow; the name line alone still matches R3.

### 6.2 Card waveform + `0:07` — DATA GAP, omit

The note says "voice requests show their waveform on the card". That needs (a) a
`wasVoiceRequest` flag and (b) an audio duration. Neither exists: `ClientHomeRequest`
(`client_home_request.dart:62-209`) has no audio field, and `_parseRequest`
(`dio_client_home_repository.dart:609-655`) reads no audio key from the gateway row. `ttlSeconds`
(`:185`) is explicitly documented as a legacy field the UI must not repurpose.

```dart
// TODO(redesign-24): board draws a voice waveform + clip duration on the card;
// needs gateway `isVoiceRequest` + `audioDurationSeconds` — omitted, not faked.
```

### 6.3 `3 offers · from $8` — HALF BUILDABLE at zero extra reads

The plan (§7.6) says the floor "IS derivable from offers already in state". Verified more precisely:
`ClientHomeState` carries **no** price, but `_fetchLiveOfferCount`
(`dio_client_home_repository.dart:443-480`) already `GET`s `/v1/offers?requestId=…` and **throws away
every field except the count** (`:466-470`). `Offer` (`client_offers/domain/offer.dart:32-39`) shows
that response carries `fee`, `currency`, `jeeberName`, `avatarUrl`.

So the floor is free **on the rows the probe fired for**. It is *not* free on rows the probe
deliberately skips: `:409` `if (counts[i] > 0) continue;` — a row whose payload already declares
`offersCount > 0` is never probed (the F3 read-economics work). Probing them all would re-add the
fan-out that PR #178–#197 deleted.

**Recommendation — no new network:**

1. `client_home_request.dart`: add `final double? lowestOfferFee;` + `final String? offerCurrency;`
   (nullable, `_sentinel` pattern in `copyWith`, added to `props`).
2. `dio_client_home_repository.dart:443-480`: change `_fetchLiveOfferCount` to return a small
   `({int count, double? minFee, String? currency})` record computed over the same already-parsed
   `items`, and thread it into `_parseRequest`'s `offerCountOverride` sibling.
3. `replies_card.dart`: render `l10n.homeRepliesOffersSummary(count, formattedAmount)` when
   `lowestOfferFee != null`, else fall back to the existing `l10n.pendingCardOffersBadge(count)`
   ("3 offers"). No placeholder, no `--`.

New l10n key `homeRepliesOffersSummary` — ICU
`"{count, plural, =1{1 offer} other{{count} offers}} · from {amount}"`, AR mirrored with the real
plural categories (`ar_plurals_check.sh` gate). `amount` is pre-formatted by the caller and must be
wrapped in an LTR isolate (§8).

### 6.4 `12 Jeebers reached` — DATA GAP, omit (plan C6)

No broadcast-reach field exists on any client surface, and this is the one number on the spine the
plan itself names as sourceless.

```dart
// TODO(redesign-24): board shows broadcast reach ("12 Jeebers reached");
// needs a gateway reach/fan-out count — omitted, not faked.
```

The row-2 trailing slot is filled instead by the existing, truthful `_PendingCreatedAge` line.

### 6.5 The 5-tier lexicon — BUILDABLE, and the board requires it

The board's second card is `🤝 On-the-Way`. `ClientRequestTier`
(`client_home_request.dart:37-51`) parses only `flash|express|standard` and drops everything else to
`unknown`, which `ClientHomeTierBadge._labelFor` (`active_request_card.dart:276-278`) renders as the
**empty string** — the On-the-Way and Eco chips are silently blank today.

Both the l10n (`tierSelectionTierOnTheWay`, `tierSelectionTierEco`) and the colors
(`JeebTierColors.onTheWay`, `.eco`) already exist. Extend the enum + `parse` to five and map the
emoji lexicon ⚡🚀🟦🤝🌿 inside `JeebTierChip` (never per-screen — plan risk 7). Keep `unknown` as the
render-nothing branch so an unseen server tier still cannot crash the card.

### 6.6 Chip counts

`state.pending.length` / `state.replies.length` are already in `ClientHomeState:36-38`. No cubit
change.

**Net cubit/state work:** two nullable fields on `ClientHomeRequest`, one return-shape change in the
repository probe, one enum widened. No new endpoint, no new call, no new state class.

---

## 7. New routes

**None.** Every destination this screen reaches is registered:
`voice-request` (`app_router.dart:1059`), `request-type` (`:1095`), `waiting-no-coverage` (`:819`),
`offer-review` (`:807`), `notifications` (`:1690`, shell-owned bell).
`backFallbacks` already covers `voice-request` (`:481`) and `request-type` (`:482`) — no
`app_router.dart` edit at all, so this lane never touches the integrator's serialized file.

---

## 8. RTL

| Risk | Fix |
|---|---|
| Hero decorative ring at `right:-40` | `PositionedDirectional(top: -40, end: -40)` inside a `ClipRRect` — kit-owned, but assert it in the screen's RTL smoke test |
| Mic at the row start | plain `Row` — mirrors correctly; **do not** `Positioned` it |
| Avatar-stack `margin-left: -9` | `EdgeInsetsDirectional.only(start: -9)`; the current code already uses `PositionedDirectional` (`replies_card.dart:245-247`) — do not regress it |
| Unread dot `right:-1 top:-1` on the header avatar | top-**END** (R11); `PositionedDirectional(top: -1, end: -1)` |
| `0:07`, `$8`, `+6`, `3` badge | wrap digit/money runs in `Directionality(textDirection: TextDirection.ltr)` or `⁦…⁩` isolates so `$8` does not render as `8$` in AR |
| `·` separator in `"3 offers · from $8"` | comes from the ARB string, not string concatenation in Dart — the AR ARB owns its own separator |
| Chip row, action row | plain `Row`s — auto-mirror |
| Shell overlay at `end: Spacing.xSmall` | already directional (`shell_screen.dart:313`) — the header's `trailingReserve` must therefore be applied on the **end** side, not `right` |

`_ClientHomeTabBar` and both card rows must keep `EdgeInsetsDirectional`; the one `EdgeInsets.fromLTRB`
in the tree (`client_home_greeting.dart:48`) is replaced in §4.

---

## 9. Conflicts, refusals, and owner decisions

### C1 — The mic hero reverses an explicit owner directive. **OWNER DECISION — blocking.**

Commit `3d6afae7` (2026-07-22, *"uiux(customer): single create entry point … search removed"*,
owner wave-3 directive) removed the "Record a request" voice CTA from this screen and **pinned its
absence**:

- `client_home_screen_test.dart:191` — `find.bySemanticsIdentifier('client_home_voice_request')` findsNothing
- `client_home_screen_test.dart:219` — `find.byKey(Key('client-home-voice-cta'))` findsNothing
- `home_tab_create_request_fab_test.dart:129/135` — the same two, ×3 dev-seam variants

The board makes voice the *primary* create affordance. My reading of the intent — and it is a
reading, not a fact — is that the directive's rule was **"one create entry point"**, not "no voice":
the board still ships exactly one create surface, it is just mic-shaped. On that reading the change
is compatible, and I propose to satisfy the letter of the guards by coining `client_home_mic_cta`
rather than reviving the retired `client_home_voice_request` id.

I am not treating that as settled. **Do not merge the hero until the owner confirms**, because the
alternative reading ("no voice CTA on the Requests screen, full stop") is equally consistent with the
commit message and would kill the entire top third of this screen. Everything else in this document
stands either way.

### C2 — Deleting the `+` breaks two style tests. Legitimate, but call it out.

`home_tab_create_request_fab_test.dart:106` does `tester.widget<IconButton>(find.byKey(Key(
'client-home-greeting-add')))` and `client_home_screen_test.dart:700` resolves that `IconButton`'s
`style.backgroundColor`. Both throw once the `IconButton` is gone. The defect they guard (a
*disabled* create button painting gray, because the shell passed a null callback) is real and must
keep a guard — rewrite both to assert the **hero** carries `orders_create_request_button` **and** has
a non-null tap handler. Do not delete the tests, and do not weaken them to `findsAny`.

### C3 — The board's single `View offers` would delete a pinned CTA. **Refused.**

`replies_accept_cta` is asserted in `client_home_screen_test.dart:434`,
`semantics_identifier_surfacing_test.dart:229/323`, tapped in
`offer_accept_double_accept_b01_test.dart:440`, and driven by `.maestro/flows/jm-027` (AC2). It is
also the entry point to the JM-029 accept-confirm sheet and the B-01 double-accept guard
(`replies_tab.dart:52-58`). Ship **both** pills, on their own end-aligned row under the offers meta
line. The card is one row taller than the board; that is the price of not deleting a live contract.

### C4 — Periwinkle body text on white. **Refused on white, kept on navy.**

The board paints `Good morning` (13/w600), `12 Jeebers reached` (12.5/w600) and
`3 offers · from $8` (13/w600) in `--jeeb-periwinkle` on white. Measured 3.76:1 — below AA for text
under 18.66px. This is not a new opinion: `active_request_card.dart:293-298` and
`:362-365` carry explicit "UX-AUDIT §T3" comments recording that these exact labels were moved **off**
periwinkle onto `onSurfaceVariant` (7.5:1), and `color_role_contrast_test.dart` keeps a
periwinkle-fails-on-white guard alive. Re-applying the board here would silently undo a shipped
accessibility fix.

**Resolution:** every meta line on a white card uses `colorScheme.onSurfaceVariant` (#5C4038 brown —
R4's third ink, visually adjacent). Periwinkle survives exactly where the board puts it on navy:
the hero subtitle (`#777FC0` on `#0B1351` = 4.55:1, passes). The Ø46 avatar's periwinkle initial on
`surfaceContainerHigh` (3.07:1) is decorative — it sits beside the same name in navy — so keep it and
`ExcludeSemantics` the glyph.

### C5 — `Broadcasting` vs `Searching for Jeebers…`. **Copy kept, visual adopted.**

The board's live-state word is `Broadcasting`. The app's canonical, already-translated word for the
identical server state is `pendingTabSearchingLabel` = "Searching for Jeebers…", pinned by five
assertions (`pending_requests_tab_test.dart:114/130/161/217/301`) plus the AR ARB. Changing it is
pure churn with no product gain — the state, the color and the dot all change as designed; only the
noun stays. Recorded as a deliberate divergence, not an oversight.

Same call for `View offers` → keeps `homeRepliesCheckOffersCta` ("Check Offers", AR "عرض العروض",
pinned at `client_home_screen_test.dart:420` and `replies_tab_test.dart:174`).

### C6 — `find.text('What do you need?')` will move.

`homeEmptyTitle` is currently the empty-state title; the hero now says it. Rendering it twice is
worse than either. §3.7 removes it from the empty view — which breaks
`client_home_empty_view_test.dart:80` (EN), its AR sibling, and
`pending_requests_tab_test.dart:174`. Legitimate: the string did not disappear, it was promoted.
Update those three assertions to target the surrounding harness, and add a screen-level assertion
that the string appears **exactly once**.

### C7 — Not conflicts (checked so a later reviewer doesn't re-litigate)

- **B04** is the *chat* composer only. It does not reach this screen.
- **D56** (no skip) is the mutual-rating screen only.
- **Deleted client-side search**: the board draws no search field on 04. Nothing to refuse.
- **Bottom-bar unification (plan risk #1)**: a non-issue here. `shell_screen.dart:191-260` already
  ships `Requests · Delivery · Dashboard · Earnings · Profile` — the board's exact five, additive for
  every user, with no role switch. Only the *styling* differs.

---

## 10. Test impact

| Test | Effect | Verdict |
|---|---|---|
| `client_home_screen_test.dart:165` (`client-home-greeting-add` findsOneWidget) | breaks | legitimate — button replaced by the hero; re-point at `orders_create_request_button` |
| `client_home_screen_test.dart:199` (`'What do you need?'` findsOneWidget) | **passes** — the hero now supplies it | keep, and add `findsOneWidget` as a duplication guard |
| `client_home_screen_test.dart:687-713` (top-plus fill roles) | breaks (`IconButton` gone) | rewrite against the hero's mic fill = `jeebRoles.accent`, hero fill = `cs.primary` |
| `client_home_screen_test.dart:191/219` (voice CTA absent) | **passes** with `client_home_mic_cta` | keep — do not touch, see C1 |
| `client_home_screen_test.dart:613-654` (Check Offers hugs + end-aligned) | passes if `IntrinsicWidth` is preserved | keep verbatim |
| `client_home_screen_test.dart:577-607` (AR tier labels) | passes **only if** `JeebTierChip` keeps label and emoji as separate `Text`s | kit requirement, §5 |
| `client_home_empty_view_test.dart:80` + AR sibling | breaks (title removed) | legitimate, C6 |
| `pending_requests_tab_test.dart:174` | breaks (title removed) | legitimate, C6 |
| `pending_requests_tab_test.dart:114/130/161/217/301` (searching label + key) | passes — copy and key preserved | C5 is what makes this true |
| `pending_requests_tab_test.dart:299-349` (`pending-offers-badge`, `OmdsChip.isSelected`) | passes if the `OmdsChip` type stays | keep the widget, restyle via theme only |
| `replies_tab_test.dart:84/100` (`+2`, `+6`) | passes if `JeebAvatarStack` keeps the `+N` overflow | kit requirement |
| `replies_tab_test.dart:134` / `semantics_identifier_surfacing_test.dart:216/311` (avatar-stack id) | passes if the `Semantics` wrapper survives the widget swap | explicit re-check |
| `semantics_identifier_surfacing_test.dart:188-233` (both CTA ids un-merged) | passes only with `explicitChildNodes: true` retained at `replies_card.dart:52` | do not "simplify" that wrapper |
| `home_tab_create_request_fab_test.dart` (all 4 cases) | breaks (`IconButton` gone) | legitimate, C2 — rewrite, don't delete |
| `offer_accept_double_accept_b01_test.dart:440` | passes — `replies_accept_cta` kept | this is why C3 is a refusal |
| `client_home_429_tolerant_test.dart:196` | passes **only if** the hero renders in every load layout | §3.3 |
| `client_home_greeting_test.dart` (7 cases, `OmdsProfileAvatar` by key) | breaks — `_avatar()` at `:74-77` casts to `OmdsProfileAvatar` | legitimate if `JeebAvatar` wraps something else; **cheapest fix: have `JeebAvatar` compose `OmdsProfileAvatar` internally and keep `Key('client-home-greeting-avatar')`**, which keeps all 7 green |
| Goldens | none committed for this feature (checked) | no regeneration |
| Maestro `08`, `13`, `14`, `15`, `jm-023`, `jm-024`, `jm-027`, `jm-030`, `jm-034` | untouched **iff** the freeze list in §2 holds | not in CI — silent rot risk; smoke on the S22 per the real-flow standard |

Estimated: **6 test files edited, 0 deleted, 0 gates weakened.**

---

## 11. Wiring requests to other lanes

- **W1 → shell lane / integrator (`shell_screen.dart`).** (a) Restyle `_JeebBottomBar` (`:344-390`)
  per plan §5 "Not shared" — the tab *set* already matches the board, only the visuals differ.
  (b) Confirm `_HeaderedTab`'s wallet-chip + bell overlay stays; if the owner wants the board's
  bell-only header, that is a shell change and it retires `orders_home_wallet_chip`.
- **W2 → integrator (l10n batch).** 5 new keys: `homeHeroSubtitle`,
  `homeGreetingEyebrowMorning|Afternoon|Evening`, `homeRepliesOffersSummary` (ICU plural + amount).
  EN + real AR + getters, per the 4-edit recipe.
- **W3 → screen-05 lane (`voice_recording_screen.dart`).** If literal hold-to-talk is wanted, expose
  an `autoStartRecording` constructor seam; otherwise 04 ships the honest "tap the mic" copy.
- **W4 → kit lane.** The five kit constraints that only 04 discovers: `JeebNavySurfaceCard`
  `shadow: none` + off-canvas ring; `JeebSelectChip`'s two count-render modes; `JeebTierChip`'s
  two-`Text` split; `JeebAvatarStack`'s `+N` overflow and dormant fill; `JeebAvatar` composing
  `OmdsProfileAvatar` so `Key('client-home-greeting-avatar')` survives.
- **W5 → owner.** C1 (voice CTA reversal) and, secondarily, C5/C6 copy divergences.

---

## 12. Residual risks

1. **C1 is unresolved.** ~60% of this diff is the hero. If the owner reads the July directive
   strictly, the whole top third reverts to a restyled `+`.
2. **Density is unreviewable in a diff** (plan risk 13). The gutter 16→24, the divider→outline swap
   and the card gap of 12 are the whole perceptual change; a reviewer reading Dart will not see it.
   Compare against the PNG at the same scale.
3. **`from $8` is inconsistent by construction** — present on probed rows, absent on payload-count
   rows. Two cards side by side may legitimately differ. Better than a fan-out or a fake.
4. **Two cards, one list, two designs.** The board draws card A (broadcasting) and card B (offers)
   stacked under a chip that says "Pending 1". They are two *tabs*' cards, not one list. I have
   mapped A→Pending and B→Replies; if the owner actually wants an unfiltered merged list, that is a
   product change beyond this migration and it retires `orders_filter_*`.
5. **`JeebAvatar` swap risk.** Seven greeting tests cast by key to `OmdsProfileAvatar`. If the kit
   builds `JeebAvatar` from scratch, those go red for a reason unrelated to this screen.
6. **200% text on the hero row** — Ø56 mic + two lines + a 5-bar waveform in 392dp. The waveform must
   drop out, not overflow.
