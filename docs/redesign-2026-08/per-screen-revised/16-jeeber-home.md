# 16 · Jeeber home — REVISED instruction set (authoritative)

Verdict: **rebuild of the in-lane bands; the two card families the board redraws are cross-lane
and ship as wiring requests.** Cubits, routing, and the screen's state machine are untouched.

Produced by independently re-reading the render, the HTML (`screens/16-jeeber-home.html`), the
note, both plans, `jeeber_home_screen.dart`, all 9 widgets under
`jeeber_home/presentation/widgets/`, `jeeber_feed_card.dart`, `active_deliveries_banner.dart`,
the models, the gateway, `greeting_profile_cubit.dart`, `shell_screen.dart`, seven test files,
both gate tests, and the Maestro flows. The original proposal was largely accurate — every HTML
measurement and almost every `file:line` checked out — but it violated the lane-ownership rule on
two whole files, specced an inline CTA that cannot carry its frozen identifier, shipped subtitle
copy that breaks two pinned test assertions, and missed a hard Maestro breakage. The deltas below
are binding.

---

## 1. Revision deltas vs the original proposal

### CUT (do not do in this lane)

- **Direct edits to `lib/features/jeeber_request_feed/**` and
  `lib/features/jeeber_active_deliveries/**`** (proposal §1.5, §1.7, §2 rows for those files).
  Ownership is `lib/features/jeeber_home/**` only (plan §7.4: "a screen lane owns only its
  `lib/features/<name>/` tree"). Verified: `jeeber_feed_card.dart`'s only production importer is
  this screen's `jeeber_feed_tab_view.dart`, and `active_deliveries_banner.dart`'s only production
  importer is `shell/tabs/dashboard_tab.dart` (which renders it *on this screen*) — so the specs
  are correct and ready, but they ship as **cross-feature wiring requests W-2/W-3**
  (`wiring/16-jeeber-home.md`), not as edits here.
- **The shell wiring request** (proposal §10.3: `_JeebBottomBar` restyle + the
  `_HeaderedTab('delivery_tab')` overlay decision). `shell_screen.dart` is explicitly named by
  `screen-repo-map.md` ("the 46 surfaces… not in scope and must not be silently expanded into")
  and the bottom bar is plan §9-Q1, an open owner question. Dropped. Consequence: the header's
  trailing slot ships `null` (see next item) and the footer keeps today's styling.
- **The `★ 4.8` rating pill** (proposal §4.2) and with it the **`lib/core/session/`
  wiring request** (proposal §10.2). Verified blockers: `GreetingProfileState` carries only
  `name`/`avatarUrl` (`greeting_profile_cubit.dart:18–37`), and the shell overlays
  `delivery_tab_wallet_chip`/`delivery_tab_bell` on the exact top-end corner
  (`shell_screen.dart:227–231`, `PositionedDirectional` at `:312`). Both fixes are out-of-lane and
  one is an owner decision. Ship `trailing: null` +
  `// TODO(redesign-24): rating pill blocked on shell header overlay + GreetingProfileState.rating`.
  `jeeber_home_rating_pill` is NOT coined now.
- **The `_LoadErrorContent` restyle** (proposal §1.6/§1.8 tail). The load-error state is not drawn
  anywhere on the board. Leave `jeeber_home_screen.dart:540–603` byte-untouched — this also keeps
  `loadErrorRetryKey` and `jeeber_home_load_error_retry_cta` trivially safe.
- **`availabilityAutoOfflineHint` as the settled online/offline subtitle** (proposal §1.4/§4.1).
  It breaks two pinned assertions: `availability_card_test.dart:160` (offline: hint
  `findsNothing`) and `:192` (online settled: hint `findsNothing`) — the proposal itself listed
  those tests as "must stay green". It would also advertise an 8-h idle rule that is inert in
  production (gateway refuses `lastActivityAt`, `dio_availability_gateway.dart:155–161`).
  Corrected rendering rule in Task 5.
- **l10n key `jeeberActiveManage`** — reuse `jeeberActiveDeliveriesManage` ("Manage delivery",
  `app_en.arb:4555`), as the proposal itself concluded.

### CORRECTED

1. **The inline `Extend` cannot be a `TextSpan`** (proposal §1.4 "inline TextSpan … Move all three
   frozen handles onto the new elements"). A `TextSpan` is not a widget: it cannot carry
   `Key('availability-inactivity-banner-cta')`, cannot be wrapped in
   `Semantics(identifier: 'availability_inactivity_extend_cta')`, and a trailing span inside an
   ellipsizing subtitle would be truncated away on narrow widths — an invisible, untappable CTA.
   Corrected form (Task 6): the subtitle is a `Row` — `Flexible(Text(warning, ellipsis))` +
   a real tappable `Extend` widget as the row's last child. Also: the existing
   `availabilityInactivityWarningBody` says *"Tap **below** to keep receiving requests"* — wrong
   once the CTA is inline, and far too long for one strip line. Two new l10n keys
   (`availabilityInactivityInlineWarning`, `availabilityExtendAction`) are in the W-1 batch.
2. **`availability_card_test.dart` breaks in five places, not three.** Besides the three
   `OMDSSectionCard` assertions (`:157`, `:193–197`, `:285–289`) the proposal listed, the test
   *casts* the toggle to the OMDS type — `tester.widget<OmdsSwitchTile>(find.byKey(toggleKey))` at
   `:153–156` (offline) and `:178–188` (online, the pinned `activeColor == roles.success`).
   Replacing the tile with a bare switch makes those casts throw. Fix in Task 10: retarget the
   casts to `Switch`, assert `value` and `activeTrackColor == roles.success` — the *semantics* of
   the pinned assertion (success role drives the on-track) are preserved exactly.
3. **No hand-rolled 52×30 switch.** `tool/check_design_tokens.sh` bans
   `SizedBox(width|height: N)` in `lib/features`, there is no kit switch in plan §5, and Wave 0
   already landed a `switchTheme` (`app_theme.dart:238–245`) whose comment explicitly anticipates
   "OmdsSwitchTile's green online toggle (jeeber availability)" keeping widget-level colors. Use a
   plain Material `Switch` (M3 track ≈ 52×32 — within 2px of the mock) with
   `activeTrackColor: context.jeebRoles.success`,
   `inactiveTrackColor: colorScheme.onPrimary.withValues(alpha: 0.18)`,
   `trackOutlineColor: WidgetStatePropertyAll(Colors.transparent)` (the documented exemption).
   The white thumb comes from the Wave-0 theme.
4. **No Ø10 presence dot with raw px.** Same gate. Build it tokenized: `Container` Ø
   `Sizes.small` (12) with `BoxShadow(color: <dotColor>.withValues(alpha: .25), spreadRadius:
   Sizes.twoXSmall)` — 2px off the mock at render scale, gate-clean, direction-free.
5. **The search collapse breaks two Maestro flows the proposal never checked.**
   `.maestro/flows/24-delivery-screen-delivery-man.yaml:51` and
   `25-iphone-16-17-pro-max-9-dm-request-pending.yaml:50,58` `assertVisible`/`tapOn`
   `jeeber_feed_search_field` at rest, with no toggle tap. Collapsed-by-default fails both.
   The identifier freeze holds (nothing renamed), but the flows need one added
   `tapOn: jeeber_feed_search_toggle` step each — filed as wiring W-4 with exact YAML.
6. **Board green ≠ role green, and the role wins.** The HTML dot/track is `rgb(59,178,115)`
   (#3BB273); `jeebRoles.success` is `#1B7A3D`. The palette-frozen decision (plan §4) plus the
   pinned success-role assertion decide it: paint from `context.jeebRoles.success`, never the hex.
7. **Strip shadow: the HTML wins over both plan docs.** `tpl 907` measures
   `0 10 24 rgba(11,19,81,.28)` — byte-identical to `JeebShadows.ctaNavy`
   (`jeeb_shadows.dart:64`). 02-PLAN-ENHANCED R6c's "`0 8 20 .25` (21 pinned, 16 availability)"
   and plan §5 #4's same grouping are wrong *for 16*. Use `JeebShadows.ctaNavy`. (Recorded so the
   kit lane doesn't "correct" it back.)
8. **`AvailabilityCard` needs a new callback the proposal implied but never declared.** The strip
   hosts the Extend affordance, so the card gains
   `this.onExtendActivity` (**optional**, `VoidCallback?` — the six existing test hosts construct
   `AvailabilityCard(view:, onToggle:)` and must keep compiling). Callers:
   `jeeber_no_requests_view.dart:85` threads its existing `onExtendActivity`;
   `jeeber_feed_tab_view.dart:206–211` adds
   `onExtendActivity: () => context.read<AvailabilityCubit>().extendActivity()`.
9. **In-flight frame: do not render `AvailabilityStatusBlock` at all.** The proposal said "render
   only `_StatusHeadline` inside the strip" — but mounting the block while toggling *from online*
   would also render its active-deliveries + idle-hint lines (`availability_status_block.dart:
   32–37`). Instead the strip computes its own title (`availabilityTransitioning` when
   `isToggleInFlight` — renders the pinned "Updating…", `app_en.arb:299`). Keep
   `availability_status_block.dart` in the tree untouched (jeeber_home_screen_test imports its
   Keys and asserts `findsNothing`); just drop its import from `availability_card.dart`.
10. **02-PLAN-ENHANCED §5 is wrong that 16's "per-card distance + neighbourhood" is gapped.**
    `DeliveryRequest.distanceFromYouKm` (nullable) and `pickup.label` (required) both exist
    (`request_feed_models.dart`). The meta line is buildable; falls back to whichever half is
    present. (Belongs to the W-2 card spec.)
11. Minor citation fixes: `activeColor` bindings are `availability_card.dart:72` and `:129`;
    `GreetingProfileState` is `greeting_profile_cubit.dart:18–37`; the shell's Dashboard
    `_HeaderedTab` wrap is `shell_screen.dart:227–231`. Everything else cited by the proposal was
    verified accurate.

### VERIFIED AND KEPT (spot-checked, binding)

- All HTML measurements in proposal §0 — header `tpl 901–906`, strip `907–914`, active card
  `915–922`, filters `923–929` (Ø38 magnifier circle — plan §481's "Ø46" is wrong, HTML wins),
  feed `930–952` (3-bar waveform mark w2.5 h7/12/9 gap2 container h14, all full-accent — the kit
  #14 `cardMark` 4-bar spec is wrong for 16; flagged to the kit lane in W-5), footer `954+`.
- The two `Make offer` treatments: freshest = solid `jeebRoles.accent` pill +
  `0 6 14 rgba(215,59,0,.35)`; older = 1.5px outline, navy ink (R5's "orange fills the one action
  that decays"). Reuse `firstIncomingIndex` (`jeeber_feed_tab_view.dart:629–633`) for both the
  `exposeMakeOfferId` AND the visual emphasis — one computation, no new state.
- **C-16.1 REFUSED stands: keep three tabs.** `jeeber_feed_replies_tab` is frozen and the
  accepted-card branch (`jeeber_feed_tab_view.dart:651–657`) is the jeeber's post-accept entry to
  `chat-detail`. The board's mock simply had no accepted rows.
- **C-16.2 REFUSED stands: keep Ignore** (`jeeber_feed_request_ignore_<id>` frozen,
  `cubit.decline()` real at `:658`). Demoted to a text-rank action — in the W-2 card spec.
- **Keep the tier strip** — `jeeber_feed_tier_chip_0..3` frozen;
  `jeeber_feed_tier_filter_test.dart:110/309` pins presence on Requests / absence elsewhere; the
  hit-target loop (`:156–199`, `>= UIConstants.buttonHeight`) means **`MinTapTarget` + the
  `Semantics`/`ExcludeSemantics` idiom stay** around every chip.
- **C-16.3/4/5 stand**: no live countdown (gateway deliberately nulls the anchor; do NOT stamp
  `lastActivityAt` in `AvailabilityCubit.toggle()` — that flips on an auto-offline currently inert
  in production; owner decision), no cash figure (`ActiveDeliverySummary` has no amount field —
  verified), no zone name (`_onlinePayload` sends `'zone': 'default'` up and parses none back).
- **C8 stands: build the search collapse; it is not the deleted search feature.**
- Counts are buildable client-side (§4.4 verified against `_visibleRequests` and
  `SubmittedOffersCubit`); no waveform source flag exists (§4.5 verified — `DeliveryRequest` has
  no `isVoice`/`audioUrl`; mark suppressed behind a `bool` param, never guessed).
- No new routes (all five destinations verified live), no DI change, no theme change.
- `decision_violations_test.dart` has zero screen-16 surface (verified: D56/D52/D20/D41-D44 only).
  No money figure remains on this screen once C-16.4 is honoured.
- Gate note: `inactivity_warning_banner.dart` and `jeeber_feed_tab_view.dart` are on the
  `no_raw_semantic_colors_test.dart` list (`:27–28`) — no `.tertiary*`, no `Color(0x…)`, no
  `Colors.red|green|orange|…` in those files; orange only via `context.jeebRoles.accent`.
- Kit consumption per proposal §3 with the Ø44-vs-46 rule: **take kit defaults, never fork.**

---

## 2. Blocking preconditions

1. **The kit does not exist yet** (`lib/core/widgets/jeeb/` absent as of this revision). In-lane
   tasks 4–8 need only: `JeebProfileHeader` (#23, + `JeebAvatar` #9 internally),
   `JeebNavySurfaceCard` (#4), `JeebSelectChip` role `filter` (#6), and optionally `JeebInfoNote`
   (#22). Do not start Task 4+ until those are importable. (The heavy consumers — #3, #5, #7,
   #14, #2 — belong to the W-2/W-3 cross-feature specs, not this lane.)
2. **The W-1 l10n batch** must be applied by the integrator before the lane compiles. Write code
   as if granted.
3. **Task 8's `isFreshest`/`isVoice` pass-through compiles only after W-2 lands** (the card gains
   the params there). Keep that sub-step behind the rest of Task 8 or land it with a follow-up
   edit once W-2 is applied.

## 3. Frozen inventory — must survive byte-identical

Identifiers emitted from lane-owned files (verified by grep):
`jeeber_home_root` · `jeeber_home_load_error_retry_cta` · `jeeber_home_avatar` ·
`availability_card` · `availability_switch` (exactly one live node in every state) ·
`availability_inactivity_extend_cta` · `jeeber_feed_search_field` · `jeeber_feed_requests_tab` ·
`jeeber_feed_pending_tab` · `jeeber_feed_replies_tab` · `jeeber_feed_tier_chip_$index` (0..3) ·
`pending_offers_back` · `jeeber_home_accept_orders_switch` · `jeeber_unregistered_root` ·
`jeeber_unregistered_register_button` · `jeeber_active_deliveries_section` ·
`jeeber_active_delivery_card_<routeId>` · `jeeber_active_delivery_open_chat_<routeId>`.

Cross-lane, rendered by this screen (owned by W-2/W-3 specs): `jeeber_active_deliveries` ·
`jeeber_active_deliveries_view_all` · `jeeber_active_delivery_row_<id>` ·
`jeeber_active_delivery_open_chat_<id>` · `jeeber_active_delivery_manage_<id>` ·
`jeeber_feed_request_card_<id>` · `jeeber_feed_request_ignore_<id>` ·
`jeeber_feed_request_offer_<id>` · `feed_make_offer_cta` · `jeeber_feed_request_expired_<id>` ·
`jeeber_feed_request_action_<id>` · `pending_offer_*` family.

Shell-owned, never touch: `jeeber_feed_root` · `delivery_register_prompt` ·
`delivery_register_now_cta` · `delivery_tab_wallet_chip` · `delivery_tab_bell` ·
`shell_tab_dashboard`.

**New identifier (one):** `jeeber_feed_search_toggle` on the magnifier circle. Explicit
`Semantics(identifier: …)` wrapper, never an OMDS `identifier:` param (§7.5).

Keys that must keep their literal values and stay findable:
`JeeberHomeScreen.scaffoldKey/loadErrorRetryKey` · `JeeberHomeGreeting.rootKey` ·
`AvailabilityCard.rootKey/toggleKey/spinnerKey` ·
`InactivityWarningBanner.rootKey/ctaKey` · `AvailabilityStatusBlock.rootKey/activeDeliveriesKey`
(file untouched) · `JeeberNoRequestsView.rootKey` · `_NoRequestsEmpty` `Key('jeeber-no-requests-
empty-state')` · `JeeberFeedTabView.rootKey/searchBarKey/tabStripKey/tierStripKey/listKey/
pendingListKey/offlineBannerKey`.

Pinned copy that must keep rendering verbatim (EN + the AR checked strings):
"You're offline" · "You're online — receiving requests" · "أنت متصل — تستقبل الطلبات" ·
"Updating…" (`availabilityTransitioning`). Pinned copy that must stay ABSENT in settled states:
"Auto-offline after 8 h idle" (offline `:160`, online `:192`), "2 active deliveries".

---

## 4. Task list (dependency-ordered)

**Task 1 — Write `wiring/16-jeeber-home.md`** exactly as specced in §7 / the wiring file. Do this
first; all in-lane code is written as if granted.

**Task 2 — Freeze the inventory.** `grep -rn "identifier: '" lib/features/jeeber_home` and diff
against §3 before and after every task. Also snapshot the Key constants.

**Task 3 — Profile header** (`jeeber_home_greeting.dart`). Keep the class name
`JeeberHomeGreeting`, `rootKey` (3 call sites), the `GreetingProfileCubit` read and the
`displayNameOrNull` suppression (`:36–45`) and the first-name split + `homeGreetingNamed`/
`homeGreetingFallback` resolution (`:131–138`). Replace `_GreetingRow`/`_GreetingAvatar`/
`_GreetingLine` (`:69–139`) with kit #23 inside
`Padding(EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0),
key: rootKey)`:
- `eyebrow: l10n.jeeberDashboardEyebrow` (kit styles it 13/w600 mutedText),
- `name:` the resolved greeting (kit: 19/w700 primary, `maxLines: 1` ellipsis),
- avatar **unconditional** — the initial disc is the `avatarUrl == null` case. This fixes the
  latent gap where `jeeber_home_avatar` was only emitted when an URL existed (`:77`); the id must
  wrap the avatar in every case (kit `avatarIdentifier` slot, W-5 contract),
- `trailing: null` + the TODO from §1-CUT.
The `fontWeight: FontWeight.w400` at `:124` dies with `_GreetingLine`. Delete the now-unused
imports (`omds` stays for `Spacing`).

**Task 4 — Navy status strip** (`availability_card.dart`). One shape for every state:
- Root: keep `Semantics(key: rootKey, identifier: 'availability_card', container: true,
  explicitChildNodes: true)`. Inside: `Padding(EdgeInsetsDirectional.fromSTEB(Spacing.xLarge,
  Spacing.medium, Spacing.xLarge, 0))` → `JeebNavySurfaceCard(radius 16, shadow:
  JeebShadows.ctaNavy, padding: symmetric(h Spacing.medium, v Spacing.small))` → `Row(gap
  Spacing.small)`: tokenized presence dot (§1-C4; `jeebRoles.success` when online,
  `colorScheme.onPrimary.withValues(alpha: .35)` when offline/auto-offline/in-flight) ·
  `Expanded(Column)` title+subtitle · trailing control.
- Title: `jeebText.cardTitle` on `colorScheme.onPrimary`; text = `availabilityTransitioning` when
  `view.isToggleInFlight`, else the existing 3-way status switch (reuses the l10n keys at
  `:136–140`). Keep `DefaultTextStyle.merge(maxLines: _kCompactOnlineTitleMaxLines, overflow:
  ellipsis)` around the title — `availability_card_test.dart:115–136` measures that budget.
- Subtitle rules (**corrected**): settled online + `!view.warningVisible` → **no subtitle**;
  settled offline → **no subtitle**; `autoOffline` → `availabilityAutoOfflineHint`
  (`jeebText.bodySmall`, ink `Theme.of(context).extension<JeebSemanticColors>()!.mutedText`);
  `view.warningVisible` → the Task-6 inline warning row.
- Trailing control: settled → one `Semantics(identifier: 'availability_switch', container: true,
  toggled: isOnline, label: <the 3 availabilityIndicatorSemantic* keys>)` wrapping
  `Switch(key: AvailabilityCard.toggleKey, value: isOnline, onChanged: (_) => onToggle(), …)` with
  the §1-C3 colors. In-flight → the spinner block keeping `AvailabilityCard.spinnerKey`
  (`OmdsLoadingState`), `toggleKey` absent.
- Add `this.onExtendActivity` (optional named, after `onToggle` — mind `sort_constructors_first`
  is about constructor placement, keep the existing field ordering style).
- Delete `_CompactOnlineAvailability`, `_FullAvailabilitySection`, `_AvailabilitySwitchRow`,
  `_AvailabilityProgress`'s `AvailabilityStatusBlock` usage and the `OMDSSectionCard` (all of
  `:52–175` collapses); drop the `availability_status_block.dart` import. Do not edit
  `availability_status_block.dart` itself.
- Height budget: the settled strip must stay ≤ `Sizes.sevenXLarge` (72dp) — pinned at `:198–203`
  and `:221–224`. The one-line form is ~48dp; verify at AR + 200% scale.

**Task 5 — `jeeber_no_requests_view.dart`.**
- `:85` → `AvailabilityCard(view: view, onToggle: onToggle, onExtendActivity: onExtendActivity)`.
- Delete the `if (view.warningVisible) …` block (`:87–90`) and the
  `inactivity_warning_banner.dart` import. Keep `onExtendActivity` in the constructor —
  `_NoRequestsScope` (`jeeber_home_screen.dart:485`) and the test hosts must compile unchanged.
- `_NoRequestsEmpty` (`:98–113`): replace `OmdsEmptyState` with a top-aligned block that keeps
  `Key('jeeber-no-requests-empty-state')` — `Padding(gutter Spacing.xLarge, top Spacing.xLarge)` →
  `Column(crossAxisAlignment: start)`: `Text(l10n.requestFeedEmptyTitle,
  jeebText.titleProminent, primary)` + gap `Spacing.xSmall` + `Text(l10n.requestFeedEmptySubtitle,
  jeebText.bodySmall, mutedText)`. The rest of the column stays white (R1). The block stays inside
  the existing `SingleChildScrollView(AlwaysScrollableScrollPhysics)` — pull-to-refresh
  (`jeeber_feed_empty_ptr_test.dart`) depends on it.

**Task 6 — Inline Extend fragment** (`inactivity_warning_banner.dart`). Rebuild the file: same
class name `InactivityWarningBanner`, same `rootKey`/`ctaKey` statics, same `onExtend`
constructor param — but the build is now the strip's warning subtitle row (rendered BY
`AvailabilityCard` when `view.warningVisible`):
- `Row(key: rootKey)`: `Flexible(Text(l10n.availabilityInactivityInlineWarning,
  jeebText.bodySmall, mutedText, maxLines 1, ellipsis))` · gap `Spacing.twoXSmall` ·
  `Semantics(identifier: 'availability_inactivity_extend_cta', container: true, button: true,
  child: InkWell(key: ctaKey, onTap: onExtend, child: Padding(Spacing.twoXSmall,
  Text(l10n.availabilityExtendAction, jeebText.bodySmall w700, colorScheme.onPrimary))))`.
- The `Extend` word is the row's LAST child (never `Positioned`), so it survives RTL and can
  never be ellipsized away.
- All three frozen handles keep IDENTICAL values; `jeeber_home_screen_test.dart:173–178` finds by
  Key and keeps passing with zero edits (the ticker test's warning → tap → cleared cycle works
  because `_NoRequestsScope:485` already threads `cubit.extendActivity`).
- Gate: this file is on the raw-colors list — inks used above are all role/token-sourced. Delete
  the `warningContainer` container, `Icons.access_time`, and the `OmdsPrimaryButton` (old
  `:24–122`).

**Task 7 — Chip row + search collapse** (`jeeber_feed_tab_view.dart`).
- `_feedControls()` (`:237–248`) becomes:
  `Padding(STEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0))` → `Row`:
  `Expanded(SingleChildScrollView(horizontal, key: tabStripKey, Row(gap Spacing.xSmall,
  [3 chips])))` · gap `Spacing.xSmall` · `_SearchToggle`; then
  `if (_searchExpanded) _FeedSearchBar(...)` (unchanged widget, its `searchBarKey` +
  `jeeber_feed_search_field` id intact); then `if (_activeTab == requests) _TierFilterStrip(...)`.
- The 3 chips: `JeebSelectChip(role: filter)` with **counts inline in the label** (what the board
  draws): `l10n.jeeberFeedNearbyCount(nearby)` / `jeeberFeedPendingCount(pending)` /
  `jeeberFeedRepliesCount(replies)`. Keep the exact `Semantics(identifier:, button:, selected:,
  label:, onTap:)` + `ExcludeSemantics` + `MinTapTarget` idiom from `:537–559` — the
  hit-target test loops over all seven ids.
- Counts (all derived, no new state): nearby = `state.requests.where((r) => r.requestIsOpen &&
  r.feedStatus == incoming && !state.expiredIds.contains(r.id)).length` (the `_visibleRequests`
  predicate minus query/tier); replies = same with `accepted`; pending =
  `widget.submittedOffersCubit` non-null ? a `BlocBuilder(bloc: widget.submittedOffersCubit)`
  over `state.offers.length` : the feed-derived `pendingResponse` count. Wrap the chip row in the
  builders already available in the tree.
- `_SearchToggle`: Ø `Sizes.threeXLarge` (40; mock 38 — token quantization) circle,
  `colorScheme.surfaceContainerHigh` fill, `Icon(Icons.search, size: Sizes.medium,
  color: colorScheme.primary)`; wrapped `Semantics(identifier: 'jeeber_feed_search_toggle',
  button: true, label: l10n.jeeberFeedSearchToggleLabel)` + `ExcludeSemantics` + `MinTapTarget`.
- State: `bool _searchExpanded = false;` on `_JeeberFeedTabViewState`. `_searchController` /
  `_searchFocusNode` stay `late final` (`:113–114`) — `jeeber_feed_search_input_test.dart:135–138`
  asserts controller/focusNode identity across rebuilds. On expand: `setState` + 
  `_searchFocusNode.requestFocus()`. On collapse: `setState(() { _searchExpanded = false;
  _query = ''; _searchController.clear(); })`.
- `_TierFilterStrip` (`:388–458`): restyle chips only — `OmdsChip` → `JeebSelectChip(role:
  filter)`; identifiers, `tierStripKey`, `MinTapTarget`, scroll container all unchanged.
- `_OfflineBanner` (`:309–324`): re-shape to `JeebInfoNote(tone: muted)` inset at gutter
  `Spacing.xLarge`, keeping the same two l10n strings, the warning-role inks
  (`jeebRoles.warningContainer`/`onWarningContainer` — offline IS a warning state and this file is
  raw-colors-gated) and `offlineBannerKey`. If `JeebInfoNote` is not yet importable, SKIP —
  ship the banner untouched rather than hand-rolling a lookalike.
- Gutters `Spacing.medium` → `Spacing.xLarge` at `:398–400`, `:473–475`, `:510–512`. Leave the
  SliverPadding vertical (`:635`) and pending list (`:779`) alone.
- `AvailabilityCard` call (`:206–211`): add the `onExtendActivity` thread (§1-C8).
- `_EmptyTabState` (`:712–733`): swap `OmdsEmptyState` for the same top-aligned two-line block as
  Task 5 (keys `jeeberFeedEmptyTitle`/`jeeberFeedEmptySubtitle`), KEEPING the
  `LayoutBuilder`+`SingleChildScrollView(AlwaysScrollableScrollPhysics)`+`ConstrainedBox` shell —
  PTR depends on it.
- Do NOT touch: `_PendingOffersList`/`_PendingOffersBackBar` (`pending_offers_back` frozen; the
  pending sub-tab is not drawn on the board), the accepted-row `chat-detail` push, the KYC-gate
  make-offer routing, the JEBV4-284 CustomScrollView structure.

**Task 8 — Freshest-card + waveform pass-through** (`jeeber_feed_tab_view.dart`, AFTER W-2 lands).
In `_FeedRequestSliverBody.itemBuilder` add `isFreshest: index == firstIncomingIndex` (reusing
`:629–633`) and `isVoice: false /* TODO(redesign-24): no hasAudio flag on the feed item */` to the
`JeeberFeedCard` call. Nothing else.

**Task 9 — Lane-local fallback banner** (`jeeber_active_deliveries_banner.dart`). Apply the SAME
visual spec as W-3 (accent-framed compact card) so the `??` fallback
(`jeeber_home_screen.dart:482–483`, never hit by the shell) does not diverge. Its three
identifiers (`jeeber_active_deliveries_section`, `jeeber_active_delivery_card_<routeId>`,
`jeeber_active_delivery_open_chat_<routeId>`) survive verbatim. If kit #5 is not yet importable,
defer this task with the banner untouched — it is invisible on the live path.

**Task 10 — Lane-owned tests.**
- `test/features/jeeber_home/availability_card_test.dart`: retarget the two `OmdsSwitchTile`
  casts to `Switch` (assert `.value`; assert `.activeTrackColor == roles.success` with the same
  reason string); replace the three `OMDSSectionCard` assertions with
  `find.byType(JeebNavySurfaceCard)` presence in ALL states (one shape now); everything else —
  copy strings, hint-absent (`:160`, `:192`), heights, two-line budget, AR copy, TalkBack node,
  in-flight spinner/`Updating…`, §SW-23 feed persistence — stays as-is and must pass.
- `test/jeeber_feed_search_input_test.dart`: in the `_host` helper, after the feed settles, add
  `await tester.tap(find.bySemanticsIdentifier('jeeber_feed_search_toggle'));
  await tester.pumpAndSettle();` before returning the `EditableText` finder. No assertion
  weakened, no identifier renamed.
- Verify green UNCHANGED: `test/jeeber_home_screen_test.dart` (6),
  `test/jeeber_feed_tier_filter_test.dart` (6 — re-run the hit-target loop after the chip
  restyle), `test/jeeber_feed_make_offer_test.dart`, `test/jeeber_feed_empty_ptr_test.dart`,
  `test/jebv4_284_keyboard_repro_test.dart`, `test/jeeber_feed_empty_view_test.dart`,
  `dashboard_tab_*` suites, `test/features/shell/jeeber_dashboard_overflow_test.dart`.
- Do NOT edit `test/jeeber_feed_card_test.dart` or
  `test/features/shell/jeeber_active_card_push_render_test.dart` — their rewrites belong to
  W-2/W-3.

**Task 11 — RTL + scale sweep.** Checklist in §5. Run the AR locale variants of the touched
tests, plus a manual `Directionality(rtl)` smoke of the strip and chip row.

**Task 12 — Gates.** `flutter analyze` (bar: no NEW issues over the 11/6 baseline);
`tool/check_design_tokens.sh`; the two gate tests (`no_raw_semantic_colors_test.dart`,
`color_role_contrast_test.dart` untouched); the targeted test files above; re-grep the §3
inventory one last time.

---

## 5. RTL checklist (binding)

1. Strip row (`dot → text → switch`): plain `Row` + `EdgeInsetsDirectional`; the dot ring is
   `BoxShadow(spreadRadius:)` (direction-free); never `Positioned(right:)` anywhere (the HTML's
   `right: 3px` is mock geometry — the Material `Switch` handles its own knob).
2. The `Extend` word is the subtitle Row's last child — auto-mirrors.
3. Chip row: chips scroll region first, toggle circle last child of the Row — auto-mirrors.
4. Counts inside chip labels come from l10n placeholders (`{count}`), never string-concatenation,
   so Arabic digit/word order is the translator's call.
5. Keep the existing directional idioms at `jeeber_feed_tab_view.dart:398–400/473–475/510–512/
   808–809`.
6. The `Active: {title} → {dropoff}` arrow and the `1.2 km ·` LTR-isolate rules apply to W-2/W-3
   (recorded there).

## 6. Stop conditions

**Done means:** Tasks 1–7 + 9–12 complete (8 gated on W-2); the §3 inventory greps identical
(plus exactly one new id `jeeber_feed_search_toggle`); `jeeber_home_screen_test` passes with ZERO
edits; the availability + search test edits are exactly the ones in Task 10; analyze shows no new
issues; `check_design_tokens.sh` clean; the wiring file contains W-1…W-5 verbatim.

**Never touch:** `app_router.dart` · `injection_container.dart` · `lib/core/theme/*` ·
`lib/l10n/*` · `pubspec.yaml` · `lib/core/session/*` · `lib/features/shell/**` ·
`lib/features/jeeber_request_feed/**` · `lib/features/jeeber_active_deliveries/**` ·
`../omds-flutter` · `.maestro/**` (W-4 covers it) · `availability_status_block.dart` ·
`jeeber_unregistered_view.dart` · `jeeber_feed_empty_view.dart` (dev-seam only,
`dashboard_tab.dart:490`) · `pending_offer_row.dart` · `_LoadErrorView`/`_LoadErrorContent` ·
`AvailabilityCubit`/gateway (no `lastActivityAt` stamping) · any test gate.

**Never render:** a zone name, a live countdown, a cash amount, a client identity on feed cards
(W-2), or any string not through `AppLocalizations`.

## 7. Wiring requests

Full text in `docs/redesign-2026-08/wiring/16-jeeber-home.md`: **W-1** l10n batch (9 keys, EN+AR),
**W-2** cross-feature `jeeber_feed_card.dart` rebuild + its test rewrite, **W-3** cross-feature
`active_deliveries_banner.dart` rebuild + shell push-render test update, **W-4** Maestro flows
24/25 search-toggle step, **W-5** kit-contract corrections (3-bar `cardMark` for 16,
`JeebProfileHeader.avatarIdentifier`, `JeebSelectChip` inline-count labels, ctaNavy shadow for
16's strip).

Deferred owner decisions (NOT wiring): the rating pill vs the shell header overlay; the bottom-bar
restyle (plan §9-Q1); adopting an activity anchor to make the countdown/auto-offline real.
