# 04 · Client home — REVISED instruction set (authoritative)

Screen id: `04-client-home` · Feature dir: `lib/features/home_client/` · Wave 3
Verdict: **rebuild** (top third new structure; list rows become outlined cards).

Reviewer status: every `file:line` in the original proposal was opened and checked. The proposal
was unusually accurate — of ~60 citations, only trivial off-by-ones were wrong. What follows is
the proposal **minus six scope cuts, plus four corrections**, ordered into an executable task
list. Where this document and the original proposal disagree, THIS document wins.

---

## 0. Rulings that unblock the lane

1. **Build the mic hero (proposal C1 → resolved: proceed).** The July directive (`3d6afae7`,
   "single create entry point") is superseded by the newer owner-commissioned board + approved
   migration plan, both of which spec 04's hero explicitly (00-MIGRATION-PLAN.md:468, designer
   note verbatim: "the buried '+' becomes a mic-first create hero"). The board still ships exactly
   one create *surface*, satisfying the directive's intent. The two negative test pins stay
   green because we do NOT revive the retired id: coin `client_home_mic_cta`; never emit
   `client_home_voice_request` and never touch `client_home_screen_test.dart:191/219` or
   `home_tab_create_request_fab_test.dart:129/135`. Record the supersession note in the wiring
   file (§7 preamble) so the owner sees it.
2. **Ship BOTH replies CTAs (C3 refusal — confirmed).** `replies_accept_cta` is load-bearing
   (`client_home_screen_test.dart:434`, `semantics_identifier_surfacing_test.dart:229/316-318`,
   `offer_accept_double_accept_b01_test.dart:440`, jm-027). The card is one row taller than the
   board; accepted.
3. **Periwinkle stays off white (C4 refusal — confirmed).** `active_request_card.dart:293-298`
   documents UX-AUDIT §T3: meta text on white uses `onSurfaceVariant` (9.35:1 per the in-code
   comment — the proposal's 7.5:1 figure was wrong, the ruling is the same). Periwinkle
   (`JeebSemanticColors.mutedText`) is legal only on the navy hero (4.55:1).
4. **Copy divergences kept (C5 — confirmed).** `pendingTabSearchingLabel` ("Searching for
   Jeebers…", 5 pins) and `homeRepliesCheckOffersCta` ("Check Offers") keep their strings; only
   the visual treatment changes. `Broadcasting` and `View offers` are NOT adopted as copy.
5. **Data gaps (verified against domain + repo):** `12 Jeebers reached` — no source, omit with
   TODO. Card waveform + `0:07` — no `isVoiceRequest`/duration in `ClientHomeRequest` or
   `_parseRequest`, omit with TODO. Offer floor (`from $8`) — half-buildable at zero network
   cost, build per Task 3. All three verified true in
   `client_home_request.dart` / `dio_client_home_repository.dart`.

## 0.1 Scope cuts (things in the original proposal you must NOT do)

| Cut | Why |
|---|---|
| **Unread orange dot on the header avatar** | The proposal never named a data source and there is none on this surface (`NotificationsListState.unreadCount` lives behind the notifications route). The shell bell is the notification affordance. Omit; one short TODO in the greeting adapter. |
| **`client_home_request_card_${id}` identifier on the replies card** | The card body is not interactive; no test or flow needs it. The freeze list + `client_home_mic_cta` is the complete id delta. |
| **`JeebCtaButton.outline` swap in `client_home_empty_view.dart`** | The empty state is not on the board. Keep `OmdsPrimaryButton`; change only `borderRadius:` `uiSmall` → `pill` (no test asserts type or radius — verified). |
| **Restyle of `_RepliesActions` (Accept / Check Offers) to `JeebSelectChip(inlineAction)`** | Both buttons are ALREADY navy/outline pills end-aligned with pinned keys, ids, and `IntrinsicWidth` ancestors (`client_home_screen_test.dart:613-654/675`). The visual delta vs the board is padding-level; the regression risk is not. Leave `_RepliesActions` byte-identical. |
| **Restyle of `_OfferOverflowCount` (+N) and `_PendingOffersBadge`** | `+2`/`+6` text pins (`replies_tab_test.dart:84/100`) and the `OmdsChip.isSelected` cast (`pending_requests_tab_test.dart:329-347`) pin them. Leave both byte-identical. |
| **W1 shell bottom-bar/header request** | The shell already overlays `ShellHeaderActions` (verified `shell_screen.dart:301-325`) and owns its own restyle lane. This screen needs nothing from it. No request. |
| **Deleting `_PendingCardSummary`** | The proposal's §3.5 "resulting card" silently dropped it. Keep it unchanged: it is the customer's own request text (G1) and the fallback several fixtures rely on. The board folds content into the title; our `displayId ?? title` can be an opaque `ORD-…`, so the summary is what identifies the card. |
| **Six-key ICU plural `homeRepliesOffersSummary`** | The repo's l10n is hand-rolled (`_get` + `replaceFirst`, see `app_localizations.dart:1852-1866`), not gen_l10n ICU. Compose the existing, already-pluralized `pendingCardOffersBadge(count)` with ONE new key `homeRepliesOffersFloor` (§7). |

## 0.2 Corrections of record

- `home_tab_create_request_fab_test.dart` key assertion is at **:107** (not :106); the top-plus
  finder recurs at :151.
- `client_home_greeting_test.dart` `_avatar()` cast is at **:75-78**.
- Surfacing pins for the replies CTAs: **:216/:222/:229** and **:311/:316-318**.
- `MoneyFormat.format` (`lib/core/formatting/money_format.dart`) already wraps amounts in LTR
  isolates — use it for the offer floor; do NOT hand-roll `Directionality`/isolate wrapping for
  money.
- Feature code may not write `7` for the status dot: use `Sizes.xSmall` (8) — imperceptible vs
  the board's Ø7 and passes `tool/check_design_tokens.sh`.
- Wave 0 has landed: `context.jeebText` (all ramp entries used below exist), `JeebSemanticColors`
  (`mutedText`, `accentRing` — access via `Theme.of(context).extension<JeebSemanticColors>()!`),
  `context.jeebRoles.accent`. **`lib/core/widgets/jeeb/` does NOT exist yet** — Tasks 4–9 are
  blocked on the kit lane shipping #3 `JeebOutlinedCard`, #4 `JeebNavySurfaceCard`,
  #6 `JeebSelectChip`/`JeebChipRow`, #7 `JeebTierChip`, #9 `JeebAvatar`/`JeebAvatarStack`,
  #14 `JeebWaveform`, #15 `JeebMicHero`, #23 `JeebProfileHeader`. Tasks 1–3 are not blocked.

---

## 1. Semantics freeze list (verified at source — every one must survive verbatim)

| Identifier | Verified today | After |
|---|---|---|
| `client_home_root` | `client_home_screen.dart:197` | unchanged |
| `orders_create_request_button` | `client_home_greeting.dart:186` | **moves** to the hero's body tap target (Task 4). Tapped by jm-023:154, jm-024:45/96, flows 08/13/14/15; asserted reachable on degraded load by `client_home_429_tolerant_test.dart:196` |
| `orders_filter_pendingRequests` / `orders_filter_replies` | `client_home_screen.dart:484` (`orders_filter_$keySuffix`) | wrapper kept verbatim around the new chip |
| `orders_home_replies_tab` | `client_home_screen.dart:503-511` (extraIdentifier wrapper) | kept verbatim |
| `_request_empty_state_root` | `client_home_empty_view.dart:20` | unchanged |
| `_request_empty_state_new_order_button` | `client_home_empty_view.dart:73` | unchanged |
| `_request_empty_state_avatar` | passed into `client_home_greeting.dart:172` | flows through `JeebProfileHeader`'s avatar slot |
| `orders_home_request_row_$i` | `pending_requests_tab.dart:128` | unchanged (wraps the card) |
| `pending_requests_item_${id}` | `pending_requests_tab.dart:160` | unchanged |
| `replies_accept_cta` / `replies_check_offers_cta` | `replies_card.dart:160/174` | unchanged (action row untouched) |
| `orders_replies_avatar_stack_$id` | `replies_card.dart:212` | kept on the `JeebAvatarStack` wrapper, `label: '$totalCount'` kept |
| `orders_active_card_$id` etc. | `active_request_card.dart` | untouched |

Keys that are load-bearing and must survive: `Key('client-home-tab-$keySuffix')` (moves onto the
new chip), `Key('pending-server-status')`, `Key('pending-offers-badge')`,
`Key('pending-created-age')`, `Key('replies-card-${id}')` (stays on the card's outermost widget),
`Key('replies-accept-${id}')`, `Key('replies-check-offers-${id}')`, `Key('pending-empty')`,
`Key('client-home-greeting-avatar')` (kit `JeebAvatar` must accept and forward it — §7 kit
request), `Key('pending-countdown-card-${id}')`, `Key('pending-requests-tab-list')`.

**New identifiers — exactly one:** `client_home_mic_cta` (the Ø56 mic). Do NOT emit
`client_home_voice_request` (pinned absent) and do NOT add a hero container id beyond what Task 4
specifies.

The `Semantics(explicitChildNodes: true)` at `replies_card.dart:52` and its why-comment must
survive the card swap — `semantics_identifier_surfacing_test.dart:188-233` pins the un-merged
nodes.

---

## 2. Ordered task list

### Task 1 — Append the wiring requests (no code)
Append §7 of this document verbatim to
`docs/redesign-2026-08/wiring/04-client-home.md`. Then write all screen code as if granted.

### Task 2 — Widen the tier lexicon to five (in-lane, unblocked)
Files: `lib/features/home_client/domain/client_home_request.dart:37-51`,
`lib/features/home_client/presentation/widgets/active_request_card.dart:254-279`.
- Add `onTheWay, eco` to `ClientRequestTier` (before `unknown`); extend `parse` to map
  `'ontheway'|'on-the-way'|'on_the_way'` and `'eco'` (match the existing lowercase-compare style).
  Keep `unknown` as the render-nothing fallback.
- `ClientRequestTier` is referenced ONLY inside `home_client` (verified) — update the two
  exhaustive switches in `ClientHomeTierBadge`: `_colorFor` → `tokens.onTheWay` / `tokens.eco`
  (both exist in `JeebTierColors`, verified :14-15); `_labelFor` → `l10n.tierSelectionTierOnTheWay`
  / `l10n.tierSelectionTierEco` (both exist in `app_en.arb:1212-1213`, verified). Check
  `dev_client_home_fixtures.dart` and the repo for any other switch the compiler flags.
- Unit test the new `parse` cases in `test/features/home_client/` (new file or the closest
  existing domain test).
- The ⚡🚀🟦🤝🌿 emoji live in `JeebTierChip` (kit-owned, plan :666) — never in this feature.

### Task 3 — Offer floor plumbing (in-lane, unblocked)
Files: `client_home_request.dart`, `dio_client_home_repository.dart`.
- `ClientHomeRequest`: add `final double? lowestOfferFee;` and `final String? offerCurrency;` —
  nullable, in `props`, `copyWith` via the file's existing `_sentinel` pattern.
- `_fetchLiveOfferCount` (`dio_client_home_repository.dart:~446-495`): return
  `({int count, double? minFee, String? currency})` computed over the SAME parsed `items` —
  read `o['fee']` as `num?` only (do not replicate `client_offers`' `amount`/`price` money-map
  parsing; a missing fee simply yields a null floor), currency from `o['currency'] as String?`.
  Null-fee offers don't contribute to the min. Thread the record through the existing
  `offerCountOverride` path into `_parseRequest`. **Do not touch the `if (counts[i] > 0) continue;`
  probe-skip at :409** — payload-declared Replies rows legitimately get no floor (F3 read
  economics; PR #178–#197). No new endpoint, no new call.
- Extend `dio_client_home_repository_offer_discovery_test.dart` (or sibling) to cover: floor set
  on probed rows, floor null on payload-count rows, null-fee offers ignored.
- TODO comments (short, why-focused) for the two real gaps, in `pending_requests_tab.dart` where
  the board draws them:
  `// TODO(redesign-24): board shows broadcast reach + voice waveform/duration; no gateway field — omitted, not faked.`

### Task 4 — `ClientHomeRequestHero` (blocked on kit #4, #14, #15)
NEW `lib/features/home_client/presentation/widgets/client_home_request_hero.dart`.
Design source HTML tpl 166-181 (verified): navy r24 pad 18 `overflow:hidden`; off-canvas Ø140
ring `1.5px rgba(215,59,0,.30)` at top-END; Ø56 orange mic, glow `0 0 0 6 rgba(215,59,0,.22)` +
`0 10 22 rgba(215,59,0,.45)`; title 17/w700 white; sub 13/w500 periwinkle; 5-bar waveform h24.

```dart
class ClientHomeRequestHero extends StatelessWidget {
  const ClientHomeRequestHero({super.key, this.onCreateRequest});

  final VoidCallback? onCreateRequest;
  // build: JeebNavySurfaceCard(radius: 24-role param, shadow: none,
  //   decorativeRing: accentRing Ø140 top-END (kit-owned, ClipRRect'd))
  //   child Row[
  //     JeebMicHero (Ø56 variant) wrapped in
  //       Semantics(identifier: 'client_home_mic_cta', button: true,
  //                 label: l10n.homeMicLabel),          // existing key, verified app_en.arb:152
  //       onTap + onLongPress both -> GoRouter.of(context).pushNamed('voice-request'),
  //     SizedBox(width: Spacing.small),                  // 14px design -> small(12)
  //     Expanded(
  //       GestureDetector(onTap: onCreateRequest, behavior: opaque) wrapped in
  //       Semantics(identifier: 'orders_create_request_button', button: true,
  //                 label: l10n.homeEmptyCta),
  //       child: Column[
  //         Text(l10n.homeEmptyTitle,                    // "What do you need?" — exact board copy
  //              style: context.jeebText.titleProminent.copyWith(color: cs.onPrimary)),
  //         Text(l10n.homeHeroSubtitle,                  // NEW key, §7
  //              style: context.jeebText.bodySmall.copyWith(
  //                color: Theme.of(context).extension<JeebSemanticColors>()!.mutedText)),
  //       ]),
  //     ExcludeSemantics(JeebWaveform onNavy mode),      // decorative
  //   ])
}
```
- `voice-request` route exists (`app_router.dart:1059-1060`; `backFallbacks:481`) — verified,
  **zero router edits**.
- Hide the waveform when `MediaQuery.textScalerOf(context).scale(13) > 20` so 200% text cannot
  overflow the row; the mic never hides.
- No hero container `Semantics` id — the two child ids above are the whole contract. Keep the
  mic and body as sibling semantic nodes (the Row's default is fine; do not merge).
- The subtitle copy is the honest "tap" phrasing, NOT the board's "Hold to talk" —
  `VoiceRecordingScreen` has no auto-start seam (verified constructor: `{cubit, onSent}` only),
  so a hold on this screen cannot start a recording. `onLongPress` still routes, so the gesture
  works. Owner note in §7.

### Task 5 — Mount the hero; greeting becomes `JeebProfileHeader` (blocked on kit #9, #23)
File: `client_home_screen.dart`, `client_home_greeting.dart`.
- `_scrollChildren()` (:338-358) becomes:
  `[ClientHomeGreeting(...), SizedBox(Spacing.medium), ClientHomeRequestHero(onCreateRequest:…),
  SizedBox(Spacing.large), _ClientHomeTabBar(...), SizedBox(Spacing.medium), _ReadyContent(...)]`.
- Add the hero to `_LoadingLayout` (:266-277) and `_FailedLayout` (:289-305) right after the
  greeting — `client_home_429_tolerant_test.dart:196` requires `orders_create_request_button`
  on a degraded load (verified). The greeting loses its `onAddPressed` parameter; the layouts
  pass `onCreateRequest` to the hero instead.
- `client_home_greeting.dart`: delete `_AddRequestButton` (:176-199), `_GreetingLine`,
  `_GreetingText`, `_GreetingAvatar`. KEEP `ClientHomeGreeting` as the adapter — the
  `GreetingProfileCubit` read (:72-78), `displayNameOrNull` suppression (:45), and `_firstName`
  are load-bearing (`client_home_greeting_test.dart`). It now builds:
  `JeebProfileHeader(avatar: <kit Ø46, forwarding Key('client-home-greeting-avatar') and the
  nullable avatarSemanticsIdentifier>, eyebrow: <time-of-day string>, title: greeting,
  trailing: null, trailingReserve: Spacing.fourXLarge * 2)`.
  - `trailing` MUST be null: the shell already overlays wallet chip + bell
    (`shell_screen.dart:301-325`, `PositionedDirectional(top: 0, end: Spacing.xSmall)` —
    verified). `trailingReserve` (§7 kit request) stops long names running under the overlay.
  - Eyebrow selection in the adapter from `DateTime.now().hour`: `<12` morning, `<17` afternoon,
    else evening → the three new keys (§7). Device-clock derivation, not server data.
  - Text styles live in the kit header (eyebrow 13/w600 mutedText, name 19/w700 navy) — pass
    strings, no `copyWith` here.
  - One short TODO: board draws an unread dot on the avatar; no unread source on this surface —
    omitted (shell bell is the affordance).
- Outer padding `EdgeInsets.fromLTRB(medium, medium, medium, xSmall)` (:48-53) →
  `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0)` (HTML tpl
  158: `16px 24px 0`).

### Task 6 — Filter chips → `JeebSelectChip(role: filter)` with counts (blocked on kit #6)
File: `client_home_screen.dart:408-514`.
- `_ClientHomeTabBar` gains `pendingCount`/`repliesCount` (from `state.pending.length` /
  `state.replies.length` in `_ReadyLayout` — already in `ClientHomeState`, verified; no cubit
  change). Bar padding `Spacing.medium` → `Spacing.xLarge` and make it
  `EdgeInsetsDirectional`; inter-chip gap via `JeebChipRow` (design 10; `Spacing.xSmall`=8 if the
  kit row takes a token).
- `_ClientHomeTabChip`: keep BOTH `Semantics` wrappers byte-identical (:483-487 and :503-511).
  Replace only the `OmdsChip` (:488-501) with
  `JeebSelectChip(key: Key('client-home-tab-$keySuffix'), role: filter, label:, isSelected:,
  onTap:, count:)`. Count rendering (selected = inline text, unselected = Ø18 orange badge as a
  SEPARATE Text node) is kit-owned — §7 kit request. Chip labels keep the existing l10n strings.

### Task 7 — Pending list → outlined cards (blocked on kit #3, #7)
File: `pending_requests_tab.dart`.
- `_PendingList` (:116-138): wrap the column children in
  `Padding(EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge))` and insert
  `SizedBox(height: Spacing.small)` between rows (board gap 12, 02-PLAN R12). The
  `orders_home_request_row_$i` wrapper and its comment stay verbatim.
- `_PendingCardBody` (:176-203): delete the `Divider` (:192-198); replace the outer `Padding`
  with `JeebOutlinedCard` (r16, 1.5px `colorScheme.outline`, pad 16, no shadow — the kit owns
  those numbers).
- `_PendingCardHeader` (:244-274): title style → `context.jeebText.cardTitle` +
  `colorScheme.onSurface` (keep the existing role-fix comment); trailing
  `ClientHomeTierBadge` → `JeebTierChip(tier:)`.
- `_PendingCardSummary`: **unchanged** (see cuts).
- `_PendingServerStatus` (:296-322): keep `Key('pending-server-status')` and
  `l10n.pendingTabSearchingLabel`. Replace the `Icons.search_rounded` icon with a
  `Sizes.xSmall` circle `Container` filled `context.jeebRoles.accent`
  (this file is in the raw-color gate, `no_raw_semantic_colors_test.dart` — verified;
  `jeebRoles.accent` is the only legal orange). Label style →
  `context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700, color: context.jeebRoles.accent)`.
  Orange is correct here: a broadcasting request is R5's "happening now".
- `_PendingCreatedAge` (:356-373): keep the widget, key, and `pendingCreatedAgeLabel` logic;
  move its render slot into the meta `Row` (trailing, after a `Spacer`) where the board puts
  the reach count; style → `context.jeebText.caption` + `onSurfaceVariant`.
- `_PendingOffersBadge`: untouched (see cuts).
- Do not move or rename this file — the raw-color gate asserts its path.

### Task 8 — Replies card → outlined card, board structure (blocked on kit #3, #7, #9)
File: `replies_card.dart`.
- `build` (:37-74): keep `Key('replies-card-${request.id}')` on the OUTERMOST widget (the
  hugging test measures it — verified :622-646); keep the `Semantics(explicitChildNodes: true)`
  wrapper AND its comment; delete the `Divider` (:66-69); exterior padding → horizontal
  `Spacing.xLarge`; body wrapped in `JeebOutlinedCard`.
- `_RepliesHeader` (:78-109): becomes `Expanded(title)` + `JeebTierChip(tier: request.tier)`.
  Title style `titleLarge.copyWith(w400)` + `secondaryContainer`-as-ink (:92-94) →
  `context.jeebText.cardTitle` + `colorScheme.onSurface` (container-role-as-ink is the exact
  defect class the gate's fourth regex bans; same fix already commented in
  `pending_requests_tab.dart:258-260`). The avatar stack moves out of the header.
- `_RepliesSummary` (:111-129): keep; drop `letterSpacing: 0.4`; `maxLines: 1`.
- NEW row 2 (between summary and actions): `Row[ JeebAvatarStack(...), SizedBox(xSmall),
  Expanded(Text(<floor or fallback>)) ]` where the stack keeps the
  `orders_replies_avatar_stack_$id` Semantics + `label: '$totalCount'` + the `+N` overflow
  (`_OfferOverflowCount` reused byte-identical — `+2`/`+6` pins). Kit stack: Ø30, 2px white
  ring, −9 start-overlap via `EdgeInsetsDirectional` (kit-owned px). `_OfferAvatar`'s hardcoded
  `initial: 'J'` → the kit's dormant treatment (`surfaceContainerHighest` + periwinkle) when
  there is no URL — no offerer name reaches this state (verified), do NOT fabricate `K N R`.
  Floor text: `request.lowestOfferFee != null`
  → `l10n.homeRepliesOffersFloor(l10n.pendingCardOffersBadge(request.offerCount),
     MoneyFormat.format(request.lowestOfferFee!, currency: request.offerCurrency ?? 'USD'))`
  else `l10n.pendingCardOffersBadge(request.offerCount)`. Style
  `context.jeebText.bodySmall` + `onSurfaceVariant` (NOT periwinkle — ruling 3). `MoneyFormat`
  handles the RTL isolate (verified).
- `_RepliesActions` (:140-187): **byte-identical** (see cuts).
- `_OverlappingAvatars` (:228-253) is replaced by the kit stack; delete it and `_OfferAvatar`
  only if nothing else uses them.

### Task 9 — Empty view de-duplication (unblocked once Task 4 merges)
File: `client_home_empty_view.dart`.
- Remove the `title:` argument at :32 (the hero owns "What do you need?"); keep illustration,
  `homePendingEmpty` subtitle, both Semantics wrappers.
- `_NewOrderButton` :77: `OmdsBorderRadius.uiSmall` → `OmdsBorderRadius.pill`. Nothing else.

### Task 10 — Test updates (with their tasks, listed here for the full picture)
Edit (in-lane):
1. `test/client_home_screen_test.dart` — :165 (greeting-add findsOneWidget) → assert
   `orders_create_request_button` present with a non-null tap handler; :687-713 (top-plus fill
   roles) → rewrite against the hero: mic fill = `jeebRoles.accent`, card fill =
   `colorScheme.primary` (the defect guarded — a create surface rendering disabled-gray — keeps
   a guard; do not delete, do not weaken to findsAny). :199 stays and now doubles as the
   exactly-once duplication guard. :191/:219 untouched.
2. `test/client_home_empty_view_test.dart` — :80 title assertion → assert the title is ABSENT
   and the subtitle + CTA present.
3. `test/features/home_client/pending_requests_tab_test.dart` — :174 ('What do you need?' in the
   tab-only harness) → retarget to `homePendingEmpty`/CTA. :114/130/161/217/301 must pass
   unchanged (copy + key preserved).
4. `test/features/home_client/replies_tab_test.dart` — expected green; run and fix only if the
   stack swap moved a finder.
5. `test/client_home_greeting_test.dart` — stays green IF the kit `JeebAvatar` composes
   `OmdsProfileAvatar` and forwards the key (§7 kit request). If the kit shipped otherwise,
   update `_avatar()` (:75-78) to the kit type — do not weaken the 7 behavioral cases.
Add (in-lane, `test/features/home_client/` or `test/`):
6. Hero renders in all three load layouts (loading/failed/ready): both ids findable.
7. RTL smoke: pump ready state under `Locale('ar')`, expect no overflow errors and the mic at
   the start edge.
8. Task 2/3 unit tests as described.
Cross-feature (wiring §7, do NOT edit yourself): `test/features/shell/home_tab_create_request_fab_test.dart`.

### Task 11 — Verify
- `flutter analyze` — bar: no NEW issues over the 11-issue/6-error pre-existing baseline.
- `bash tool/check_design_tokens.sh` — clean for `home_client`.
- Targeted: the 8 test files above + `test/semantics_identifier_surfacing_test.dart` +
  `test/features/client_offers/offer_accept_double_accept_b01_test.dart` +
  `test/decision_violations_test.dart` (must pass untouched).
- Visual: compare against `screens/04-client-home.png` at scale — the gutter (16→24), card
  outlines, and gap-12 rhythm ARE the redesign; a Dart diff cannot show them.
- Maestro flows 08/13/14/15/jm-023/jm-024/jm-027 are not in CI — smoke jm-024 on the S22 per the
  real-flow standard before calling the screen done.

---

## 3. Stop conditions — "done" means exactly this

DONE =
- All 24 frozen identifiers + listed Keys emitted verbatim; `client_home_mic_cta` added;
  `client_home_voice_request` still absent.
- Screen matches the PNG's structure: profile header, navy mic hero, counted pill chips,
  outlined flat cards at gutter 24 / gap 12 — with the recorded divergences (both reply CTAs,
  "Searching for Jeebers…" copy, `onSurfaceVariant` meta ink, no reach count, no card waveform,
  no avatar dot, honest tap-to-talk subtitle).
- Tier chips render all five tiers; unknown renders nothing.
- Offer floor renders on probed rows, falls back to the plain count elsewhere; zero new network.
- Tests in Task 10 green; analyze/token-gate/l10n-parity clean; RTL smoke green.

MUST NOT TOUCH:
- `lib/core/router/app_router.dart` (zero route needs — verified), `lib/core/di/*`,
  `lib/core/theme/*`, `lib/l10n/*` (wiring only), `pubspec.yaml`, `lib/core/widgets/jeeb/*`
  (kit lane's), `lib/features/shell/*`, `lib/features/voice_request/*`,
  `lib/features/client_offers/*` (read-only reference).
- `in_progress_tab.dart`, `pending_request_card.dart` (dead — leave dead),
  `active_request_card.dart` beyond the Task 2 switch cases.
- The negative pins (:191/:219/:129/:135), the probe-skip at repo :409, the
  `explicitChildNodes` wrappers, `_RepliesActions`, `_PendingOffersBadge`,
  `_OfferOverflowCount`, `_PendingCardSummary`.
- No new dependency, no invented gateway field (the ONLY payload keys you may newly read are
  `fee`/`currency` on the offers response — already served, verified in
  `client_offers/data/dio_offers_repository.dart:250-260`).

---

## 7. Wiring requests — append VERBATIM to `docs/redesign-2026-08/wiring/04-client-home.md`

> Preamble note for the integrator/owner: 04 builds the board's mic hero, which supersedes the
> 2026-07-22 "single create entry point" directive's plus-button implementation while preserving
> its intent (one create surface). The retired `client_home_voice_request` id is NOT revived;
> negative pins stay green. Deliberate copy divergences: hero subtitle says "tap" not "hold"
> (no auto-start seam in `VoiceRecordingScreen`; if literal hold-to-talk is wanted, the 05 lane
> must expose an `autoStartRecording` seam), "Searching for Jeebers…" kept over "Broadcasting",
> "Check Offers" kept over "View offers".

```
### l10n
file: lib/l10n/app_en.arb
need: five new keys for the 04 hero subtitle, greeting eyebrow, and replies offer floor.
exact change:
  "homeGreetingEyebrowMorning": "Good morning",
  "@homeGreetingEyebrowMorning": { "description": "Greeting eyebrow above the name on the client home header, device-local hour < 12." },
  "homeGreetingEyebrowAfternoon": "Good afternoon",
  "@homeGreetingEyebrowAfternoon": { "description": "Greeting eyebrow, device-local hour 12–16." },
  "homeGreetingEyebrowEvening": "Good evening",
  "@homeGreetingEyebrowEvening": { "description": "Greeting eyebrow, device-local hour >= 17." },
  "homeHeroSubtitle": "Tap the mic to talk · or type instead",
  "@homeHeroSubtitle": { "description": "Subtitle inside the client-home mic hero. Deliberately says 'tap', not the board's 'hold' — no auto-start recording seam exists." },
  "homeRepliesOffersFloor": "{offers} · from {amount}",
  "@homeRepliesOffersFloor": {
    "description": "Replies-card meta line combining the pluralized offers count with the lowest quoted fee. {offers} is the pre-pluralized pendingCardOffersBadge string; {amount} is pre-formatted by MoneyFormat (LTR-isolated).",
    "placeholders": { "offers": { "type": "String", "example": "3 offers" }, "amount": { "type": "String", "example": "$8.00" } }
  },
why: the 04 hero and replies card render these; l10n parity gate requires EN+AR together.

### l10n
file: lib/l10n/app_ar.arb
need: Arabic values for the same five keys.
exact change:
  "homeGreetingEyebrowMorning": "صباح الخير",
  "homeGreetingEyebrowAfternoon": "مساء الخير",
  "homeGreetingEyebrowEvening": "مساء الخير",
  "homeHeroSubtitle": "اضغط الميكروفون للتحدث · أو اكتب بدلاً من ذلك",
  "homeRepliesOffersFloor": "{offers} · ابتداءً من {amount}",
why: AR/EN parity; the ARB owns its own separator/order so the Dart caller never concatenates.

### l10n
file: lib/l10n/app_localizations.dart
need: getters for the five keys, matching the hand-rolled _get pattern (cf. :1492, :1852).
exact change:
  String get homeGreetingEyebrowMorning => _get('homeGreetingEyebrowMorning');
  String get homeGreetingEyebrowAfternoon => _get('homeGreetingEyebrowAfternoon');
  String get homeGreetingEyebrowEvening => _get('homeGreetingEyebrowEvening');
  String get homeHeroSubtitle => _get('homeHeroSubtitle');
  String homeRepliesOffersFloor(String offers, String amount) =>
      _get('homeRepliesOffersFloor')
          .replaceFirst('{offers}', offers)
          .replaceFirst('{amount}', amount);
why: feature code reads these through AppLocalizations; there is no gen_l10n step.

### cross-feature
file: lib/core/widgets/jeeb/ (kit lane)
need: six kit behaviors 04 depends on, all consistent with plan §5 rows #3/#4/#6/#7/#9/#23.
exact change: (constraints, not code — kit lane implements)
  1. JeebNavySurfaceCard: shadow:none variant + off-canvas Ø140 accentRing at top-END,
     ClipRRect'd (04 hero is the consumer the plan names for both).
  2. JeebSelectChip: optional `count`; selected renders it as inline text, unselected as the
     Ø18 solid-orange badge (white 11/w800, pad 0/4) — and in BOTH modes the count is a
     SEPARATE Text widget from the label, so find.text label pins survive.
  3. JeebTierChip: emoji and label are two Text children, never one string —
     find.text('سريع')/('إكسبرس') are pinned (client_home_screen_test.dart:577-607); must
     accept the five-tier enum via a per-feature mapper or generic label/emoji params.
  4. JeebAvatar: compose OmdsProfileAvatar internally and forward a caller-supplied Key —
     Key('client-home-greeting-avatar') keeps 7 greeting tests green
     (client_home_greeting_test.dart:75-78 casts tester.widget<OmdsProfileAvatar>).
  5. JeebAvatarStack: caller-composable trailing (+N stays the caller's Text) and the dormant
     fill (surfaceContainerHighest + periwinkle initial) when no URL/name.
  6. JeebProfileHeader: `trailing` nullable + a `trailingReserve` (end-side width) param — 04
     must reserve Spacing.fourXLarge*2 under the shell's overlaid ShellHeaderActions.
why: every design-exact px on 04 (46/56/24/30/−9/1.5/999) is banned in lib/features by
tool/check_design_tokens.sh and legal only inside the kit.

### cross-feature
file: test/features/shell/home_tab_create_request_fab_test.dart
need: rewrite the four top-plus cases for the hero without weakening the disabled-create guard.
exact change: replace find.byKey(Key('client-home-greeting-add')) (:107, :151) with
find.bySemanticsIdentifier('orders_create_request_button'); assert the node exists AND has a tap
action (non-null handler) in all dev-seam variants; keep :121 as-is; keep the negative pins
:129 (client_home_voice_request absent) and :135 (Key('client-home-voice-cta') absent) VERBATIM.
why: the guarded defect (create surface rendering with a null callback from the shell) outlives
the + button; the file lives in the shell's test tree, so the serialized integrator applies it.
```

---

## 8. Residual risks (carried forward, trimmed)

1. **Kit timing** — Tasks 4–9 cannot start before kit #3/#4/#6/#7/#9/#14/#15/#23 exist
   (`lib/core/widgets/jeeb/` is empty as of this review). Do Tasks 1–3 first.
2. **Floor inconsistency by construction** — probed rows show `from $X`, payload-count rows
   don't. Accepted; better than fan-out or fake.
3. **Density is invisible in a diff** — review against the PNG, not the Dart.
4. **Card A/B mapping** — board's two stacked cards are the Pending and Replies TABS' cards.
   If the owner wants one merged list, that retires `orders_filter_*` and is out of scope.
