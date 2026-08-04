# 04 · Client home — apply report

**Status: APPLIED**, with one external blocker that is by design: five new l10n keys are wiring
requests, not lane edits, so `dart analyze lib/features/home_client` currently reports **5
undefined-getter errors and nothing else**. They clear the moment the serialized integrator applies
`wiring/04-client-home.md`.

Tasks 1–10 of `per-screen-revised/04-client-home.md` are done. Tasks 4–9 were unblocked (Wave 1 has
landed; the instruction set's §8.1 "the kit is empty" is stale — every kit widget it lists exists
and is imported, none hand-rolled).

---

## What changed

### Created
| File | Why |
|---|---|
| `lib/features/home_client/presentation/widgets/client_home_request_hero.dart` | Task 4 — the navy r24 mic hero. `JeebNavySurfaceCard(rings: [heroTopEnd], shadow: noShadow)` + `JeebMicHero(sizeCompact)` + `JeebWaveform.onNavy()`. |
| `lib/features/home_client/presentation/widgets/client_home_tier_chip.dart` | Task 7/8 — the 3-line `ClientRequestTier → JeebTier` + localized-label adapter the kit asks every feature to supply. `unknown` renders `SizedBox.shrink()`. |
| `test/features/home_client/client_home_request_hero_test.dart` | Task 10.6/10.7 — both hero ids on ready/loading/failed, the two negative pins, exactly-one-create-surface, RTL smoke. |
| `test/features/home_client/client_request_tier_test.dart` | Task 10.8 — five-tier parse table incl. the three On-the-Way spellings, plus the kit-mapping pin. |
| `docs/redesign-2026-08/wiring/04-client-home.md` | Task 1 — §7 verbatim + the verified status of each request. |

### Modified (lib)
- `client_home_screen.dart` — hero mounted in all three load layouts; `_ClientHomeTabBar` gains
  `pendingCount`/`repliesCount` and becomes a `JeebChipRow` at gutter 24; `_ClientHomeTabChip`'s
  `OmdsChip` → `JeebSelectChip(role: filter, count:)` with **both** `Semantics` wrappers and the
  `client-home-tab-$suffix` key byte-identical.
- `widgets/client_home_greeting.dart` — now a pure adapter over `JeebProfileHeader`; `_GreetingLine`
  / `_GreetingText` / `_GreetingAvatar` / `_AddRequestButton` deleted. Keeps the `GreetingProfileCubit`
  read, `displayNameOrNull` suppression and `_firstName`. Loses `onAddPressed`.
- `widgets/replies_card.dart` — `JeebOutlinedCard` + kit `JeebAvatarStack`; new offers/floor row;
  `_RepliesActions` byte-identical; `_OfferOverflowCount` byte-identical; divider gone.
- `widgets/client_home_empty_view.dart` — title dropped (the hero owns it), CTA radius
  `uiSmall → pill`, gutter `medium → xLarge`.
- `widgets/active_request_card.dart` — Task 2 only: two switch arms for `onTheWay`/`eco`.
- `tabs/pending_requests_tab.dart` — `JeebOutlinedCard`, gutter 24 / gap 12, divider deleted,
  title → `jeebText.cardTitle`, tier → `ClientHomeTierChip`, `_PendingServerStatus` icon → Ø8
  `jeebRoles.accent` dot with a w700 accent label, `_PendingCreatedAge` relocated to the meta row's
  end edge as `jeebText.caption`/`onSurfaceVariant`.
- `tabs/replies_tab.dart` — 12px gap between cards (they used to be separated by their own vertical
  padding + a divider, both now gone).
- `domain/client_home_request.dart` — `ClientRequestTier` widened to five; `lowestOfferFee` +
  `offerCurrency` added to ctor / fields / `props` / `copyWith` (sentinel pattern).
- `data/dio_client_home_repository.dart` — `_fetchLiveOfferCount` now returns
  `_OfferProbe = ({int count, double? minFee, String? currency})`, computing the floor over the
  **same** parsed items. **Zero new requests and the `if (counts[i].count > 0) continue;` probe-skip
  at the old :409 is intact** — verified by a test that asserts `offerRequestIds` stays empty for a
  payload-count row.

### Modified (test)
- `client_home_screen_test.dart` — the `client-home-greeting-add` key assertion became
  "`orders_create_request_button` exists **and has a tap action**" plus a `client_home_mic_cta`
  presence pin; the top-plus fill-role test was rewritten against the hero (navy card fill from
  `colorScheme.primary`, mic disc from `jeebRoles.accent`) so the disabled-gray defect it guarded is
  still guarded; the Check-Offers end-alignment budget went 24 → 42 (screen gutter 24 + card pad 16
  + stroke 1.5 — a centered CTA still lands ~300px out, which is what the case actually catches).
  `:191`/`:219` negative pins and `:199` untouched.
- `client_home_empty_view_test.dart` — title assertions inverted to `findsNothing` (EN + AR).
- `features/home_client/pending_requests_tab_test.dart` — `:174` retargeted from the title to the
  `homePendingEmpty` subtitle; every other case untouched.
- `client_home_greeting_test.dart` — `onAddPressed` dropped from the harness; all 7 behavioural
  cases unchanged.
- `features/home_client/dio_client_home_repository_offer_discovery_test.dart` — +4 floor cases.

---

## Verification

| Gate | Result |
|---|---|
| `dart analyze lib/features/home_client` + the 5 touched test files | **5 errors, all the pending l10n getters. 0 warnings. 2 infos, both pre-existing** (`containsSemantics` deprecations already in `client_home_screen_test.dart`, untouched by me). |
| `bash tool/check_design_tokens.sh` | **0 violations in `home_client`** (the 8 it reports are in other features). |
| `flutter test test/core/theme/no_raw_semantic_colors_test.dart` | **+17, all passed** — `pending_requests_tab.dart` stays clean under the raw-color gate with its new orange. |
| `flutter test .../client_request_tier_test.dart .../dio_client_home_repository_offer_discovery_test.dart` | **+15, all passed** (6 new tier, 4 new floor, 5 pre-existing discovery). |
| Widget tests | **NOT RUN — could not compile.** See below. |

### Why the widget tests could not be run

Every widget test that pumps this screen imports `lib/`, which does not compile until the l10n
wiring lands. The obvious workaround — patch `lib/l10n/*` locally, run, revert — was **deliberately
not taken**: `git status` showed `app_en.arb`, `app_ar.arb` and `app_localizations.dart` *actively
modified* by a concurrent sibling lane (screen 10's `patch_l10n.py` is in the shared scratchpad),
and restoring my own snapshot over their live edit would have destroyed another agent's work. The
correct order is: integrator applies the l10n block → the widget suites run.

**The next agent should run, in this order:**
```
flutter test test/client_home_screen_test.dart test/client_home_greeting_test.dart \
             test/client_home_empty_view_test.dart \
             test/features/home_client/ test/semantics_identifier_surfacing_test.dart \
             test/features/client_offers/offer_accept_double_accept_b01_test.dart \
             test/decision_violations_test.dart
```

### Known, deliberate breakage outside my ownership

`test/features/shell/home_tab_create_request_fab_test.dart` asserts
`find.byKey(Key('client-home-greeting-add'))` at :107 and :151. That button no longer exists. The
rewrite is the last block of `wiring/04-client-home.md` and preserves the guarded defect (a create
surface with a null handler) by targeting `orders_create_request_button`'s tap action instead. I did
not edit it — it lives in the shell's tree.

---

## Divergences from the render, and why

1. **Tier chip sits in the card header on the Pending card**, where the board puts it in the meta
   row (`tpl 197`). The instruction set specifies the header for both cards; keeping them consistent
   also reads better given the Pending card carries a summary line the board does not have.
2. **The Replies card is one row taller than the board.** The board draws a single `View offers`
   pill; `replies_accept_cta` is load-bearing (jm-027, the double-accept suite, three surfacing
   pins) so both CTAs stay, on their own row below the offers line. Ruling 2.
3. **Copy kept:** "Searching for Jeebers…" (not `Broadcasting`), "Check Offers" (not `View offers`),
   "Pending Requests"/"Replies" (not `Pending`/`Replies`) — all pinned strings, ruling 4.
4. **Hero subtitle says "tap", not "Hold to talk"** — `VoiceRecordingScreen` has no auto-start seam,
   so the board's promise would be a lie. The long-press still routes.
5. **Three board elements omitted for want of data**, each with a short TODO at the render site:
   `12 Jeebers reached`, the card waveform + `0:07`, and the unread dot on the header avatar. No
   field exists for any of them; none is faked.
6. **Meta ink is `onSurfaceVariant`, not the board's periwinkle**, on every white surface —
   periwinkle is 3.76:1 there and legal only on the navy hero (ruling 3, UX-AUDIT §T3).
7. **Avatar-stack discs are the kit's dormant grey when an offerer has no photo.** The board's
   `K N R` initials are mock data; no offerer name reaches this surface, so inventing them was not
   an option.
8. **Design px landed on the nearest token** where the two disagree: hero padding 18 → `Spacing.medium`
   (16, which lands the card on the render's measured ~88px height), status dot Ø7 → `Sizes.xSmall`
   (8), inter-chip gap 10 → `Spacing.xSmall` (8), hero row gap 14 → `Spacing.small` (12). The
   design-exact 24/56/46/30/−9/1.5/999 all come from the kit, where they are legal.
