# 16 · Jeeber home — change proposal

Design source: `screens/16-jeeber-home.{png,html,note.md}`
Target files (lane-owned): `lib/features/jeeber_home/**`
Cross-lane files this screen is the only consumer of: `lib/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart`, `lib/features/jeeber_request_feed/presentation/jeeber_feed_card.dart`
Verdict: **rebuild** (four of the five bands above the fold change shape and content model; the cubits are untouched).

---

## 0. What the board actually draws (measured from the HTML, 440×956 = dp 1:1)

| Band | HTML | Today |
|---|---|---|
| Profile header | `tpl 901–906`: pad `14/24/0`, gap 12 · Ø44 navy avatar, initial 16/w800 white · eyebrow "Jeeber dashboard" 12.5/w600 periwinkle · name "Ahlan, Omar" 18/w700 navy · trailing `★ 4.8` pill pad `6/12` r999 `surface-high`, 12/w700 navy | `JeeberHomeGreeting` — one `titleLarge` **w400** navy line, avatar only when `avatarUrl != null`, no eyebrow, no trailing |
| Availability | `tpl 907–914`: margin `16/24/0`, pad `14/16`, r16, **navy fill**, shadow `0 10 24 rgba(11,19,81,.28)` · Ø10 green dot + 4px `.25` ring · title 15/w700 **white** · sub 12/w600 periwinkle with a white `Extend` word · 52×30 green switch, Ø24 white knob inset 3 | `AvailabilityCard` — a bare `OmdsSwitchTile` on white (online) / `OMDSSectionCard` (offline); the extend affordance is a separate full-width `InactivityWarningBanner` in `warningContainer` |
| Active delivery | `tpl 915–922`: margin `12/24/0`, pad `13/16`, r16, **2px orange border**, gap 12 · Ø38 orange disc + 19px white scooter glyph · title 14/w700 navy 1-line · sub 12/w600 periwinkle · `Manage` pill pad `8/14` r999 navy, white 12.5/w600 | `ActiveDeliveriesBanner` — a collapsed disclosure row ("Your active deliveries" + "View all (1)") that expands into `OMDSGlassCard`s with **two stacked full-width** icon buttons (~180dp each) |
| Filters | `tpl 923–929`: pad `16/24/0`, gap 8 · selected pad `9/16` r999 navy fill white 13/w600 · unselected pad `9/16` `1.5px #916F66` ink `#5C4038` 13/w600 · flex spacer · **Ø38 `surface-high` magnifier**, glyph 17px navy | full-width `OmdsSearchBar` **above** a 3-chip tab strip, then a 4-chip tier strip |
| Feed | `tpl 930–952`: pad `14/24/0`, **column gap 11** · card `1.5px #916F66` r16 pad `14/16`, no shadow · row1 gap 9 = waveform mark + title 15/w700 navy 1-line + `2 min ago` 11.5/w600 periwinkle · row2 `margin-top 11` gap 8 = tier chip pad `4/10` r999 `surface-high` 11.5/w700 + `1.2 km · Achrafieh` 12/w600 periwinkle + spacer + CTA | avatar-led card: Ø56 avatar, client **name** as the title, HH:mm timestamp, 2-line summary, `{d}km away from you`, then a `Wrap` footer of tier chip + `Ignore` text button + `Offer` pill |
| Footer | 5-tab bar, `1px outlineVariant` top border, pad `12/8/26`; selected tab = 52×30 `surface-high` pill + navy glyph + 12/w700 | `_JeebBottomBar` in `shell_screen.dart` — **already the same 5 tabs for a jeeber** (`requests/delivery/dashboard/earnings/profile`), different styling |

Two `Make offer` CTAs, deliberately different: the **freshest** card gets a solid `jeebRoles.accent` pill with `0 6 14 rgba(215,59,0,.35)`; the older card gets the `1.5px outline` variant with navy ink. This is R5's "orange fills the one action that decays".

Below the second card the screen is **plain white for ~45% of its height**. That is the single biggest visual delta (R1) and nothing in the note says it.

---

## 1. Layout & structure

### 1.1 `jeeber_home_screen.dart` — no structural change
`JeeberHomeScreen` (44–185) is a state router. Its five branches (`_RootBody` → `_RegisteredBody` → `_RegisteredViewSwitch` → `_AvailableBody` → `_NoRequestsScope`/`_FeedTabBody`) and the `_autoActivateJeeber` self-heal all stay exactly as they are. **Nothing in `jeeber_home_screen.dart:1–539` is touched** except `_LoadErrorContent` (§1.6). All the change is in `presentation/widgets/`.

### 1.2 ADD `JeeberDashboardHeader` — replaces `JeeberHomeGreeting`'s row
`jeeber_home_greeting.dart:69–139` (`_GreetingRow`/`_GreetingAvatar`/`_GreetingLine`).

Keep the class name `JeeberHomeGreeting` and `rootKey` (two call sites: `jeeber_no_requests_view.dart:84`, `jeeber_feed_tab_view.dart:198`, plus `jeeber_feed_empty_view.dart:79`), keep the `GreetingProfileCubit` read and the `displayNameOrNull` hash-suppression (`jeeber_home_greeting.dart:37–45` — that is an audit fix, not styling). Replace only the body:

```dart
// jeeber_home_greeting.dart — build()
Padding(
  padding: const EdgeInsetsDirectional.fromSTEB(
    Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0),  // 24/16/24/0
  child: JeebProfileHeader(                               // kit #23
    initial: initialOf(resolvedName),
    avatarUrl: resolvedAvatar,
    eyebrow: l10n.jeeberDashboardEyebrow,                 // NEW key
    name: greeting,                                       // existing homeGreetingNamed/Fallback
    avatarIdentifier: 'jeeber_home_avatar',
    trailing: rating == null ? null : JeebRatingPill(...),// §4.2 — gated
  ),
)
```

- The avatar becomes **unconditional** (`JeebProfileHeader` always draws the Ø46 disc; the initial disc is the `avatarUrl == null` case). Today `_GreetingRow:77` drops the avatar entirely when `avatarUrl` is null, which is why `jeeber_home_avatar` is not emitted on the live path — a latent identifier gap this fixes.
- `_GreetingLine`'s `fontWeight: FontWeight.w400` (line 124) is **the single most anti-spec line on the screen** (R3: 400 never appears on the board). It becomes the header's `name` slot → 19/w700 navy inside the kit widget.
- Two lines (eyebrow + name), not one. `maxLines: 1` + ellipsis stays on the name.

### 1.3 REBUILD `AvailabilityCard` as the navy status strip
`availability_card.dart:38–104`.

Collapse `_CompactOnlineAvailability` and `_FullAvailabilitySection` into one `JeebNavySurfaceCard` (kit #4) with a **screen-local** green switch, keeping the state branch only for the in-flight frame:

```
JeebNavySurfaceCard(radius: 16, shadow: JeebShadows.ctaNavy,
  padding: 14/16, child: Row(gap 12):
    _PresenceDot(online)              // Ø10 jeebRoles.success + 4px .25 ring; grey when offline
    Expanded(Column crossAxisAlignment.start:
      Text(title,  style: jeebText.cardTitle.copyWith(color: onPrimary))   // 15/w700 white
      Text.rich(sub, style: jeebText.bodySmall.copyWith(color: mutedText)) // 12/w600 periwinkle
    )
    _AvailabilitySwitch(value, onChanged)   // 52×30 track, Ø24 knob
)
```

- **Delete `OMDSSectionCard`** from this widget (`availability_card.dart:94`). A white M3 section card with a heading is the opposite of R6/R7 — the board has one navy status strip in every availability state, not two different containers.
- Delete the `_CompactOnlineAvailability` / `_FullAvailabilitySection` split (lines 52–104). The strip is the same shape online and offline; only the fill of the presence dot, the copy and the switch value change. `_kCompactOnlineTitleMaxLines = 2` (line 11) and the `DefaultTextStyle.merge(maxLines: 2, overflow: ellipsis)` wrapper stay — `availability_card_test.dart:115–136` measures that budget at 320dp and at 200% scale.
- In-flight (`view.isToggleInFlight`) keeps `_AvailabilityProgress` but inside the navy strip: switch slot → `OmdsLoadingState` with `AvailabilityCard.spinnerKey`, title → `availabilityTransitioning`. `availability_card_test.dart:267–289` asserts the spinner replaces the switch **and** finds `OMDSSectionCard` — that last assertion legitimately dies (§8).
- `AvailabilityStatusBlock` (`availability_status_block.dart`, 109 LOC) is only reachable from `_AvailabilityProgress:159`. Its `_StatusHeadline` duplicates the strip's title and its `_ActiveDeliveriesLine`/`_IdleHintLine` are already asserted **absent** from settled states. Keep the file and both Keys (the test asserts `findsNothing` on them) but render only `_StatusHeadline` inside the strip.

### 1.4 The `Extend` affordance moves inline — `InactivityWarningBanner` is re-homed, not deleted
`inactivity_warning_banner.dart` (whole file) + `jeeber_no_requests_view.dart:87–90`.

The board puts the extend action in the strip's subtitle line (`Achrafieh zone · **Extend**`), not in a separate warning slab. Rebuild `InactivityWarningBanner` as an **inline subtitle fragment** rendered *inside* `AvailabilityCard`'s subtitle row, and keep all three frozen handles at the same values:

- `InactivityWarningBanner.rootKey` (`Key('availability-inactivity-banner-root')`) → the subtitle `Row`.
- `InactivityWarningBanner.ctaKey` (`Key('availability-inactivity-banner-cta')`) → the inline `Extend` word.
- `Semantics(identifier: 'availability_inactivity_extend_cta')` → same, unchanged.

Because `jeeber_home_screen_test.dart:173–178` finds by **Key**, not by widget type or position, re-homing keeps that test green with zero edits. Drop the `warningContainer` fill, the `Icons.access_time` header and the `OmdsPrimaryButton` (lines 24–122) — inside a navy strip they are three competing surfaces.

Rendering rule (honest, see §4.1):
- online, not warning → sub = `l10n.availabilityAutoOfflineHint` ("Auto-offline after 8 h idle"), periwinkle, **no** Extend word.
- `view.warningVisible` → sub = `availabilityInactivityWarningBody` + ` · ` + white w700 `Extend`.
- offline / auto-offline → sub = `availabilityAutoOfflineHint` or `availabilityStatusAutoOffline` supporting copy.

`jeeber_no_requests_view.dart:87–90` loses its `if (view.warningVisible) …` block (the banner now lives inside the card); `onExtendActivity` threads into `AvailabilityCard` instead — `JeeberNoRequestsView` keeps its constructor parameter so `_NoRequestsScope:485` and every test host compile unchanged.

### 1.5 REBUILD the active-delivery card (2px orange frame, one row)
`active_deliveries_banner.dart:98–270` (`_ActiveDeliveriesCardList`, `_ActiveDeliveriesSummaryRow`, `_ActiveDeliveryCard`, `_ActiveDeliveryCardActions`).

```
JeebAccentFrameCard(radius: 16, borderWidth: 2, padding: 13/16, gap 12):   // kit #5
  Ø38 jeebRoles.accent disc + 19px white Icons.two_wheeler (onAccent)
  Expanded(Column:
    Text('${l10n.jeeberActiveLabel}: $title', jeebText.body.w700 navy, 1 line, ellipsis)
    Text(statusLabel, jeebText.bodySmall, mutedText)                       // §4.3 on cash
  )
  JeebCtaButton.pill(navy, 'Manage', 12.5/w600)  → onManageDelivery
```

- **One delivery → always expanded** (the note: "the just-won delivery is pinned above the feed"). **Two or more → keep today's disclosure**, with the compact card as the expanded row. This preserves the reason `_ActiveDeliveriesCardList` was collapsed in the first place (line 77–79: "keeps active work to one summary row at rest so it cannot bury the incoming request feed") — the board's card is ~64dp, today's expanded card is ~180dp, so a single one no longer buries anything.
- Delete `_ActiveDeliveryCardActions` (lines 291–368) and `_ButtonLabel` (376–406) — the whole `LayoutBuilder` + `Flexible` label machinery exists to stop two full-width icon buttons overflowing. The board has **one** pill, so the overflow class of bug disappears with it. Card tap keeps opening chat (`onOpenChat`, line 212); the pill is `onManageDelivery`.
- Delete `_StatusChip` (408–445) as a chip: the status becomes the subtitle's first token (`In transit · …`), reading through the same `activeDeliveryStatus*` getters.
- `OMDSGlassCard` (line 200) → `JeebAccentFrameCard`. A glass card is a shadowed white surface; R7 says that shape does not exist on this board.
- Identifiers preserved verbatim: `jeeber_active_deliveries`, `jeeber_active_deliveries_view_all` (≥2 only), `jeeber_active_delivery_row_<id>`, `jeeber_active_delivery_open_chat_<id>`, `jeeber_active_delivery_manage_<id>`.
- The lane-local fallback `jeeber_active_deliveries_banner.dart` (the `??` at `jeeber_home_screen.dart:483`, never hit by the shell) gets the same treatment so the two do not diverge; its three identifiers are preserved.

### 1.6 The filter row + search collapse
`jeeber_feed_tab_view.dart:237–248` (`_feedControls`), `460–489` (`_FeedSearchBar`), `498–560` (`_FeedTabStrip`), `388–458` (`_TierFilterStrip`).

New `_feedControls()` order:

```
Row(pad 16/24/0, gap 8):
  JeebSelectChip.filter('Nearby ${incomingCount}',  selected: tab == requests)  // kit #6, role: filter
  JeebSelectChip.filter('Pending ${pendingCount}',  selected: tab == pendingResponse)
  JeebSelectChip.filter('Replies ${acceptedCount}', selected: tab == replies)
  Spacer()
  _SearchToggle()   // Ø38 surfaceContainerHigh circle, 17px navy magnifier
if (searchExpanded) _FeedSearchBar(...)      // unchanged widget, r999 pill
if (tab == requests) _TierFilterStrip(...)   // unchanged chips, restyled to JeebSelectChip.filter
```

- **Keep three tabs.** The board draws two because its mock has two; `jeeber_feed_replies_tab` is a frozen identifier and the accepted-row branch (`jeeber_feed_tab_view.dart:651–654`) is the jeeber's post-accept entry into `chat-detail`. Deleting it would strand a real flow.
- **Keep the tier strip.** `jeeber_feed_tier_chip_$index` ×4 are frozen; `jeeber_feed_tier_filter_test.dart:110/309` asserts `tierStripKey` present on Requests and absent elsewhere. Restyle the chips only.
- The counts are a pure client-side derivation of state already in the tree (§4.4).
- `OmdsChip` + `MinTapTarget` + `ExcludeSemantics` wrapper (lines 422–437, 543–558) → `JeebSelectChip` keeping the identical `Semantics(identifier:, button:, selected:, label:, onTap:)` + `ExcludeSemantics` idiom. `jeeber_feed_tier_filter_test.dart:156–198` measures the tokenized minimum hit target — `JeebSelectChip`'s `filter` role is pad `11/20` on a 13–14.5px label ≈ 40dp, above the 48dp floor only with `MinTapTarget`, so **keep `MinTapTarget`** around the chip.

### 1.7 REBUILD `JeeberFeedCard`
`jeeber_request_feed/presentation/jeeber_feed_card.dart:76–757`.

```
JeebOutlinedCard(radius: 16, padding: 14/16):            // kit #3
  Row(gap 9):
    if (isVoice) JeebWaveform.cardMark()                 // kit #14 — §4.5
    Expanded(Text(itemsSummary ?? fallback, jeebText.cardTitle navy, maxLines 1, ellipsis))
    Text(relativeTime(receivedAt), jeebText.caption, mutedText)
  SizedBox(11)
  Row(gap 8):
    JeebTierChip(tier)                                   // kit #7
    Flexible(Text('$distance · ${pickup.label}', jeebText.bodySmall, mutedText, 1 line))
    Spacer()
    _ActionArea(...)
```

Deletions and why:
- `_ClientAvatar` (203–221, Ø56) and `_ClientName` (298–317) — the board leads with **what the job is**, not who filed it. The identity moves off the card entirely (it is on the request detail).
- `_RatingCluster` (319–342) — the client's star rating is not on the board's card, and it is the file's only `colorScheme.tertiary` use.
- `_SummaryLine` (393–412) as a separate 2-line block — the summary **is** the title now, 1 line, ellipsised.
- `_DistanceLine` (414–438) as a separate row — folds into the meta line.
- `_CardFooter`'s `Wrap` (467–494) → a fixed `Row`; the wrap-to-two-lines behaviour was a symptom of three competing footer elements.
- `_IgnoreButton` (567–588): the board has no Ignore. **Keep it** — `jeeber_feed_request_ignore_<id>` is frozen and `cubit.decline()` is a real flow (`jeeber_feed_tab_view.dart:658`). Demote to `JeebCtaButton.text` in `onSurfaceVariant` placed before the offer pill, matching R4's brown-secondary-word rank. Do **not** delete an affordance the board merely omitted.

**Freshest-card emphasis.** `_FeedRequestSliverBody:629–632` already computes `firstIncomingIndex` (the first non-expired incoming row) and threads `exposeMakeOfferId: index == firstIncomingIndex`. Reuse that exact index for the visual emphasis — pass `isFreshest: index == firstIncomingIndex` and let `_OfferButton` pick `accent` (solid orange + `0 6 14 rgba(215,59,0,.35)`) vs `outline`. One computation, two consumers, no new state.

### 1.8 The empty / no-requests states must stay top-aligned
`jeeber_no_requests_view.dart:98–113`, `jeeber_feed_tab_view.dart:712–733`.

`OmdsEmptyState` centres an icon + two lines in the remaining viewport. Under R1 the lower 45% is *supposed* to be empty — a centred inbox glyph fills exactly the space the design leaves blank. Replace both with a top-aligned two-line block directly under the last control (title `jeebText.titleProminent` navy, subtitle `jeebText.bodySmall` `mutedText`, gutter 24), and let the rest of the column be white. Keep `_NoRequestsEmpty.rootKey` (`Key('jeeber-no-requests-empty-state')`) on the new block — `jeeber_feed_empty_ptr_test.dart:107` finds `JeeberNoRequestsView.rootKey` and the pull-to-refresh wrapper (`jeeber_home_screen.dart:424–431`) must keep working, so the block stays inside the scrollable with `AlwaysScrollableScrollPhysics`.

`_LoadErrorContent` (`jeeber_home_screen.dart:561–603`) keeps its `Center` — an error is the one legitimate vertically-centred state — but `Icons.signal_wifi_off` at `Sizes.threeXLarge` becomes 24px `mutedText` and `titleMedium` becomes `jeebText.titleProminent`.

### 1.9 Not built
The 440×956 frame, the 40px frame radius, `scale(0.55)`, and the `9:41` status row (`tpl 897–900`) are mock chrome.

---

## 2. Tokens — every literal that changes

| Where | Today | Becomes |
|---|---|---|
| `jeeber_home_greeting.dart:122–124` | `titleLarge.copyWith(color: primary, fontWeight: w400)` | kit `JeebProfileHeader` name slot → `jeebText` 19/w700 `colorScheme.primary` |
| `jeeber_home_greeting.dart:104–105` | `size: Sizes.twoXLarge`, `backgroundColor: surfaceContainerHigh`, `initialColor: primary` | `JeebAvatar` Ø46, navy fill + white initial (unknown → `surfaceContainerHighest` + periwinkle, R11) |
| `jeeber_home_greeting.dart:48–53` | `EdgeInsetsDirectional.fromSTEB(medium, medium, medium, twoXSmall)` = 16 gutter | `Spacing.xLarge` (24) gutter — every band on this screen |
| `availability_card.dart:94–103` | `OMDSSectionCard(title:, horizontalPadding: medium, spacing: twoXSmall)` | `JeebNavySurfaceCard`: `colorScheme.primary` fill, r16, `JeebShadows.ctaNavy`, pad `14/16` |
| `availability_card.dart:71–77` | `OmdsSwitchTile(contentPadding: symmetric(medium, xSmall))` | screen-local 52×30 switch: track `jeebRoles.success` / `Colors.white24`-equivalent via `onPrimary.withValues(alpha: .18)`, knob `colorScheme.onPrimary` |
| `availability_card.dart:71,129` | `activeColor: context.jeebRoles.success` | **keep** — `availability_card_test.dart:182–188` pins it |
| status title / subtitle | `textTheme.bodyMedium.w600` / `bodySmall` | `jeebText.cardTitle` on `colorScheme.onPrimary` / `jeebText.bodySmall` on `JeebSemanticColors.mutedText` |
| `inactivity_warning_banner.dart:28–32` | `roles.warningContainer` fill + `Border.all(roles.warning)` + `OmdsBorderRadius.medium` | no container — inline `TextSpan`, `colorScheme.onPrimary` w700 |
| `inactivity_warning_banner.dart:26–27` | `EdgeInsets.symmetric(horizontal: medium)` + `EdgeInsets.all(medium)` | gone |
| `active_deliveries_banner.dart:200–207` | `OMDSGlassCard(surfaceContainerLow, OMDSBorderRadius.lg, Border.all(outlineVariant, dividerWidth))` | `JeebAccentFrameCard`: white, `2px context.jeebRoles.accent`, r16, **no shadow** |
| `active_deliveries_banner.dart:236–239` | `Icons.location_on_outlined`, `Sizes.small`, `onSurfaceVariant` | Ø38 `jeebRoles.accent` disc + 19px `jeebRoles.onAccent` `Icons.two_wheeler` |
| `active_deliveries_banner.dart:417–422` | `OmdsChip(selectedColor: primaryContainer)` | subtitle text token, `jeebText.bodySmall` `mutedText` |
| `active_deliveries_banner.dart:224,244,310` | `titleSmall`, `bodySmall`, `labelLarge.w600` | `jeebText.body` w700 navy / `jeebText.bodySmall` `mutedText` / `jeebText.bodySmall` w600 `onPrimary` |
| `jeeber_feed_card.dart:95–101` | `surfaceContainerLow` fill + `Border.all(outlineVariant, dividerWidth)` + `OmdsBorderRadius.medium` | `JeebOutlinedCard`: `colorScheme.surface` + `1.5px colorScheme.outline` (`#916F66`) + r16 |
| `jeeber_feed_card.dart:337` | `activeColor: colorScheme.tertiary` | **deleted with `_RatingCluster`** — this is the file's only `.tertiary` |
| `jeeber_feed_card.dart:359–361,381–384` | `color.withValues(alpha: opacityPrimaryLight)` tier tint + `scheme.tertiary` fallbacks | `JeebTierChip`: `surfaceContainerHigh` fill, emoji + 11.5/w700 navy — one treatment for all five tiers (R2 meta chip) |
| `jeeber_feed_card.dart:309,404,425,658,679,751` | `titleMedium.w600`, `bodyMedium.w500`, `labelSmall`, `labelMedium` italic | `jeebText.cardTitle` / `jeebText.bodySmall` / `jeebText.caption` / `jeebText.label` |
| `jeeber_feed_card.dart:87` | `UIConstants.opacityDisabled` on expiry | keep (R9 dimming is legitimate here — the row is genuinely dead) |
| `jeeber_feed_card.dart:89–93` | `symmetric(horizontal: medium, vertical: xSmall)` | list gap 11 → `Spacing.small` (12) between cards, gutter `Spacing.xLarge` |
| `_OfferButton:612–617` | `OmdsPrimaryButton(borderRadius: pill)` | `JeebCtaButton` — `accent` (fresh) / `outline` (rest), pad `8/16`, `jeebText.caption` w700 |
| `jeeber_feed_tab_view.dart:316,333` | `jeebRoles.warningContainer` / `onWarningContainer` offline banner | keep the role (offline **is** a warning state) but re-shape to `JeebInfoNote(tone: muted)` at gutter 24, r16 — not an edge-to-edge coloured band |
| `jeeber_feed_tab_view.dart:399,474,510,635,779` | `Spacing.medium` (16) horizontals | `Spacing.xLarge` (24) |

**Gate note:** `inactivity_warning_banner.dart` and `jeeber_feed_tab_view.dart` are both on the `no_raw_semantic_colors_test.dart` list (lines 27–28). Any orange in those two files must come from `context.jeebRoles.accent` — `.tertiary*`, `Color(0x…)` and `Colors.*` all fail. `jeeber_feed_card.dart` is not on the list but must follow the same rule.

**Design-exact px** (2px border, 52×30 switch, Ø38 disc, 11px list gap, 999 radii) live **inside `lib/core/widgets/jeeb/`**. `tool/check_design_tokens.sh` bans `fontSize:`, `EdgeInsets.<x>(N)`, `SizedBox(width|height: N)` and `BorderRadius.circular(N)` anywhere under `lib/features` — so feature files pass `Spacing.*` / `Sizes.*` / `OmdsBorderRadius.*` and a kit `role`, never a number.

---

## 3. Shared components to consume

| Kit widget | Replaces | Notes |
|---|---|---|
| #23 `JeebProfileHeader` | `_GreetingRow`/`_GreetingAvatar`/`_GreetingLine` | 16 uses this, **not** `JeebTopBar`. HTML says Ø44 / eyebrow 12.5 / name 18; the kit spec (from 04) says Ø46 / 13 / 19. **Do not fork** — take the kit defaults; the delta is sub-pixel at render scale. |
| #4 `JeebNavySurfaceCard` | `OMDSSectionCard` + `OmdsSwitchTile` chrome | shadow param must be `JeebShadows.ctaNavy` (R6c: the one-line status strip is the *shadowed* navy form). |
| #5 `JeebAccentFrameCard` | `OMDSGlassCard` in the active-delivery card | `borderWidth: 2`, unfilled variant. |
| #3 `JeebOutlinedCard` | the feed card's `DecoratedBox` | radius 16, `1.5px outline`, **no shadow**. |
| #6 `JeebSelectChip(role: filter)` | `_FeedTabStrip`'s and `_TierFilterStrip`'s `OmdsChip`s | needs the **count badge** slot (min-w 18, h18, orange fill, 11/w800 white) — or render the count inline in the label ("Nearby 12"), which is what the board actually draws. Use the inline form. |
| #7 `JeebTierChip` | `_TierChip` | emoji + 11.5/w700 navy on `surfaceContainerHigh` for **all five** tiers. Kills the per-tier tinted-chip treatment. |
| #9 `JeebAvatar` | `OmdsProfileAvatar` in the greeting + `_ClientAvatar` | Ø46 header size; the feed card loses its avatar entirely. |
| #14 `JeebWaveform.cardMark` | nothing (net-new) | see §4.5 — **the kit spec is wrong for 16** (3 bars here, 4 on 04). |
| #2 `JeebCtaButton` | `OmdsPrimaryButton` in `_OfferButton`/`_IgnoreButton`, the Manage pill, the retry CTA | variants `accent` / `outline` / `text` / navy pill. |
| #22 `JeebInfoNote(tone: muted)` | `_OfflineBanner` (`jeeber_feed_tab_view.dart:309–324`) | inset note, not a full-bleed band. |

Not consumed: `JeebTopBar` (this screen has no top bar), `JeebMoneyBreakdown`, `JeebStepper`, `JeebCodeCells`.

**Bottom bar:** out of this lane. `_JeebBottomBar` lives in `shell_screen.dart:356–387` and — good news — the jeeber tab set (`shell_screen.dart:194–256`) is **already exactly the board's five tabs**: Requests / Delivery / Dashboard / Earnings / Profile. §9-Q1's unification worry does not apply to screen 16; only the styling differs.

---

## 4. New functionality, and what it needs

### 4.1 "goes offline in 1h 40m" — **REFUSED as drawn; ship the honest form**
The plan (§7.6) says the state exposes a bool. Measured, it is worse than that: `AvailabilityStatus.lastActivityAt` **does** exist (`availability_status.dart:46`), but `DioAvailabilityGateway._parse` (`dio_availability_gateway.dart:155–161`) *deliberately refuses* to populate it — an explicit comment explains that carrying the server's months-old `lastPingAt` would make the first idle tick flip the jeeber auto-offline and hide the feed. Neither `fetch()` nor `toggle()` sets it. So today:

- `lastActivityAt` is `null` on every live path → `_onIdleTick` (`availability_cubit.dart:104–105`) returns immediately → **the 8h auto-offline is inert in production**, and `warningVisible` never becomes true outside tests.
- A countdown rendered from `policy.autoOfflineAfter - (now - lastActivityAt)` would print a constant `8:00` or nothing at all.

Ship: title `availabilityStatusOnline`, subtitle `availabilityAutoOfflineHint`, `Extend` only when `warningVisible`.
`// TODO(redesign-24): live "goes offline in {t}" needs an activity anchor — the gateway's lastPingAt is deliberately not adopted (dio_availability_gateway.dart:155). Omitted, not faked.`

**Owner decision (do not take it in this lane):** stamping `lastActivityAt: DateTime.now()` on a successful go-online inside `AvailabilityCubit.toggle()` would be a legal client-side derivation *and* would make both the countdown and the warning real — but it also **activates an 8h auto-offline that currently never fires**. That is a behaviour change on the jeeber's earning surface, not a restyle.

### 4.2 `★ 4.8` header pill — data is available, but the slot is occupied
`GreetingProfileCubit` already fetches the full `CustomerProfileViewData` via `CustomerProfileRepository.fetchProfile()`, and that DTO carries `rating`, `ratingCount` and `hasRating` (`customer_profile_view_data.dart:17–52`, sourced from `GET /users/me`). `GreetingProfileState` (`greeting_profile_cubit.dart:18–35`) simply drops them on the floor. Adding `rating`/`ratingCount` to that state is rendering an existing field, not inventing one — **but `lib/core/session/` is not this lane's tree** (§7.4), so it is a wiring request.

**Blocking conflict:** `shell_screen.dart:216–232` wraps `DashboardTab` in `_HeaderedTab(idPrefix: 'delivery_tab')`, which `PositionedDirectional(top: 0, end: Spacing.xSmall)`s two 48dp `IconButton`s (`delivery_tab_wallet_chip`, `delivery_tab_bell`) over the top-end corner — precisely where the board draws the rating pill. It works today only because `JeeberHomeGreeting` puts nothing on the right. **Default for this lane: build the trailing slot, leave it null, TODO it.** Wiring it needs either the shell to drop the overlay on this tab or the owner to accept the wallet/bell instead of the rating pill.

Star colour, if it ever ships: R4.1 says 16's ★ is an **unstyled glyph inheriting navy** — do *not* apply `context.omdsColorTokens.starRatingColor` here.

### 4.3 `$8 cash on arrival` — **no source, omit**
`ActiveDeliverySummary` (`active_delivery_summary.dart:17–93`) carries `id, status, conversationId, title, pickupAddress, dropoffAddress`. There is no amount, no currency, no COD field, and `fromJson` reads none. Render `Active: {title} → {dropoff}` / `{statusLabel}` and:
`// TODO(redesign-24): needs a cash-due field on GET /v1/deliveries?role=jeeber — omitted, not faked.`

### 4.4 `Nearby 12` / `Pending 2` counts — **buildable today**
- Nearby = `state.requests.where((r) => r.requestIsOpen && r.feedStatus == incoming && !state.expiredIds.contains(r.id)).length` — the same predicate `_visibleRequests` (`jeeber_feed_tab_view.dart:670–684`) already runs, minus the query/tier filters.
- Pending = `submittedOffersCubit.state.offers.length` when the cubit is wired (`jeeber_home_screen.dart:134–157`), else the feed-derived `pendingResponse` count.
- Replies = the `accepted` count.
Derive them in `_JeeberFeedTabViewState` from the two `BlocBuilder`s already in the tree. No new cubit, no new field.

### 4.5 The waveform mark — needs a source flag the app does not have
`DeliveryRequest` (`request_feed_models.dart:60–155`) has no `isVoice` / `audioUrl` / `hasRecording`. The mark cannot be driven.
`// TODO(redesign-24): voice-request mark needs a hasAudio flag on the jeeber feed item — mark suppressed, not guessed.`
Build `JeebWaveform.cardMark` into the row behind a `bool isVoice = false` parameter so wiring it later is a one-line change.

**Kit correction, report upstream:** the plan (§5 #14) specs `cardMark` as *"4 bars w3 r9 gap 2, h 8/14/10/15, accent with the last at .4, container h16 (04 16)"*. Screen 16's HTML (`tpl 933–936`) draws **3 bars, w2.5, h 7/12/9, gap 2, container h14, all three at full accent opacity**. Either `cardMark` takes a `bars`/`heights` profile or 16 is off-spec. It is a one-line fix if caught in Wave 1 and a fork if not.

### 4.6 Search collapse (C8 — do **not** refuse this)
`jeeber_feed_tab_view.dart:62` already ships a live search bar; the board collapses it to a Ø38 circle. Build `_SearchToggle` as a `StatefulWidget`-owned `bool _searchExpanded`, defaulting **false**, expanding the existing `_FeedSearchBar` beneath the chip row. `_searchController` / `_searchFocusNode` stay `late final` on the state (lines 113–114) so the controller identity survives expand/collapse — `jeeber_feed_search_input_test.dart:136` asserts exactly that. Clearing the query on collapse (`setState(() { _query = ''; _searchController.clear(); })`) keeps the feed honest.

---

## 5. New routes

**None.** Every destination this screen reaches already exists:
`jeeber-offer-submission` / `offer-kyc-gate` (`jeeber_feed_tab_view.dart:159–172`), `chat-detail` (line 652), `jeeber-request-detail` (`dashboard_tab.dart:294–300`), `/jeeber/deliveries/:id/active` (line 288), `jeeber-onboarding` (line 293). No `backFallbacks` entry, no `_wrapRootAware` append.

---

## 6. Semantics identifiers

### Must survive (frozen)
Lane-owned (`lib/features/jeeber_home/`):
`jeeber_home_root` · `jeeber_home_load_error_retry_cta` · `jeeber_home_avatar` · `availability_card` · `availability_switch` (emitted from whichever branch is live) · `availability_inactivity_extend_cta` · `jeeber_feed_search_field` · `jeeber_feed_requests_tab` · `jeeber_feed_pending_tab` · `jeeber_feed_replies_tab` · `jeeber_feed_tier_chip_0..3` · `pending_offers_back` · `jeeber_home_accept_orders_switch` (dev-seam empty view) · `jeeber_unregistered_root` · `jeeber_unregistered_register_button` · `jeeber_active_deliveries_section` · `jeeber_active_delivery_card_<routeId>` · `jeeber_active_delivery_open_chat_<routeId>`

Cross-lane, rendered by this screen:
`jeeber_active_deliveries` · `jeeber_active_deliveries_view_all` · `jeeber_active_delivery_row_<id>` · `jeeber_active_delivery_open_chat_<id>` · `jeeber_active_delivery_manage_<id>` · `jeeber_feed_request_card_<id>` · `jeeber_feed_request_ignore_<id>` · `jeeber_feed_request_offer_<id>` · `feed_make_offer_cta` · `jeeber_feed_request_expired_<id>` · `jeeber_feed_request_action_<id>` · `pending_offer_<i>` (+ `_price` / `_eta` / `_status` / `_withdraw_cta`) · `pending_offer_awaiting_label`

Shell-owned, do not touch: `jeeber_feed_root` · `delivery_register_prompt` · `delivery_register_now_cta` · `delivery_tab_wallet_chip` · `delivery_tab_bell` · `shell_tab_dashboard`.

`jeeber_home_avatar` deserves a callout: it is emitted **only when `avatarUrl != null`** today (`jeeber_home_greeting.dart:77`). Making the avatar unconditional makes an already-frozen id reliably queryable — an additive fix.

### New
| Identifier | Element |
|---|---|
| `jeeber_feed_search_toggle` | the Ø38 magnifier circle |
| `jeeber_home_rating_pill` | header trailing rating pill (only if §4.2 is wired) |
| `jeeber_home_availability_extend` | *not needed* — reuse `availability_inactivity_extend_cta` |

Every wrapper is an explicit `Semantics(identifier: …)`, never an OMDS `identifier:` param (§7.5, stale local clone). The strip and the active card keep `container: true` + `explicitChildNodes: true` so the nested switch / Manage ids stay independently queryable.

---

## 7. RTL

1. **The status strip's dot → text → switch row** must be `Row` + `EdgeInsetsDirectional`; the presence dot's 4px glow ring is `BoxShadow(spreadRadius:)` (direction-free). The switch knob is drawn with `AlignmentDirectional.centerEnd` when on / `centerStart` when off — a raw `Positioned(right: 3)` (the HTML's literal `right: 3px`) mirrors wrong.
2. **`Active: {title} → {dropoff}`.** The `→` in the board is a literal glyph inside a bidi-neutral run; under `ar` it must point the other way. Do **not** hardcode `→` — build the line as two `TextSpan`s separated by a localized connector, or use `DirectionalIcons` for the arrow. This is the single easiest RTL bug on this screen.
3. **`1.2 km · Achrafieh`.** The distance is already formatted through `NumberFormat.decimalPattern(locale)` (`jeeber_feed_card.dart:433–437`); keep that and wrap the numeric run in an LTR isolate so `1.2 km` does not reorder next to an Arabic neighbourhood name.
4. **`2 min ago`** must come from an l10n plural, not string interpolation (`قبل ٢ د` word order differs).
5. **Chip row + magnifier**: the `Spacer()` between the chips and the circle is directional-safe; the circle must be the row's last child, not `Positioned(right:)`.
6. **Card row 1** (`waveform · title · time`): plain `Row` → auto-mirrors; the waveform bars are symmetric so no per-bar mirroring is needed.
7. **`JeeberFeedCard` already has an RTL test** (`jeeber_feed_card_test.dart:354–369`) asserting `TextDirection.rtl` and the Arabic tier label `فلاش` — keep it passing.
8. Existing directional idioms to preserve: `EdgeInsetsDirectional` at `jeeber_feed_tab_view.dart:399/474/510/635/779`, `AlignmentDirectional.centerStart` at `:808`, `IntrinsicWidth` + `Align` at `jeeber_feed_card.dart:712`.

---

## 8. Test impact

Baseline note: `jeeber_feed_card_test` is already **red on `main` in CI** (00-MIGRATION-PLAN §2). Do not count its pre-existing failure as damage — but this proposal rewrites it anyway.

| Test | Effect | Legitimate? |
|---|---|---|
| `test/jeeber_home_screen_test.dart` (6 tests) | **Green unchanged** if the re-homing in §1.4 keeps `InactivityWarningBanner.rootKey`/`.ctaKey` and `AvailabilityCard.toggleKey` as literal `Key` values, and the copy strings (`You're offline`, `You're online — receiving requests`, `Updating…`) stay. Verify `AvailabilityStatusBlock.rootKey`/`activeDeliveriesKey` still resolve to `findsNothing` in settled states. | — |
| `test/features/jeeber_home/availability_card_test.dart` | **3 assertions break by design**: `find.byType(OMDSSectionCard) findsOneWidget` (offline, line 157), `findsNothing` (online, 194–198) and `findsOneWidget` (in-flight, 285–289). The section card no longer exists in any state. Replace with a `JeebNavySurfaceCard` presence assertion. The success-role assertion (182–188), the two-line budget checks (227–248) and the Arabic copy check (205–225) must all stay green. | Yes — the strip is one shape in all states now |
| `test/jeeber_feed_card_test.dart` (~14 tests) | **Largest breakage.** `Sami Fawaz` / `jeeber-feed-card-client-name` / `jeeber-feed-card-avatar` / `OmdsStarRatingDisplay` / `Customer` fallback / the `contentRect.left > avatarRect.right` geometry proof (90–146) / `3km away from you` / the 2-line summary contract (150–190) all assume the identity-led card. Rewrite around the new row model; **keep** the expiry group (371–425), the `IntrinsicWidth` hugging + end-alignment proofs (270–339, still valid for the accepted pill), the RTL test and the SW-03 device-local timestamp test (427–450, retargeted at the relative-time formatter). | Yes — the card's information model genuinely changed |
| `test/features/shell/jeeber_active_card_push_render_test.dart` | `find.text('View all (1)') findsOneWidget` and `find.text('Flash delivery request') findsNothing` (193–195) break: with **one** delivery the card is now expanded. The push-reaction assertions (`repo.calls >= 2`, banner present within two frames, feed row not displaced) must stay. | Yes — the note explicitly pins the just-won delivery |
| `test/features/shell/jeeber_feed_banner_hides_requests_test.dart` | Should stay green and get *safer* — the compact card is ~64dp vs ~180dp, so both feed rows lay out more easily at 360×800. | — |
| `test/jeeber_feed_search_input_test.dart` (3 tests) | Breaks: the field is not mounted until the magnifier is tapped. Fix in the `_host` helper (line 92) — one `await tester.tap(find.bySemanticsIdentifier('jeeber_feed_search_toggle'))` before returning the finder. No identifier renamed, no assertion weakened. | Yes — C8 sanctions the collapse |
| `test/jeeber_feed_tier_filter_test.dart` (6 tests) | Should stay green: `tierStripKey`, `listKey`, the per-chip ids and the hit-target measurement all survive if `MinTapTarget` is kept. Re-verify the tokenized hit target (156–198) after the chip padding changes to `11/20`. | — |
| `test/jeeber_feed_make_offer_test.dart` | Green — `feed_make_offer_cta` and the pending-offer ids are untouched. | — |
| `test/jeeber_feed_empty_ptr_test.dart`, `test/jebv4_284_keyboard_repro_test.dart`, `test/features/shell/jeeber_dashboard_overflow_test.dart`, `dashboard_tab_*_test.dart` | Green expected — they assert scroll/overflow/provider behaviour, all preserved. The overflow tests get *more* headroom. | — |
| `test/jeeber_feed_empty_view_test.dart` | Green if `JeeberFeedEmptyView` is left alone (dev-seam-only path, `dashboard_tab.dart:490`). Restyling it is optional and out of the board's scope. | — |
| `test/semantics_identifier_surfacing_test.dart:511,516` | Green — `jeeber_feed_request_card_<id>` and `jeeber_feed_request_action_<id>` are preserved. | — |
| Gates | `no_raw_semantic_colors_test.dart` (27–28) and `check_design_tokens.sh` must be re-run; no golden PNGs exist for this screen. | — |

---

## 9. Conflicts — what the board loses

**C-16.1 — The board's two-chip filter row deletes a live flow. REFUSED.** `Nearby` + `Pending` only would drop `jeeber_feed_replies_tab` (frozen id) and with it the accepted-card branch that routes a jeeber into `chat-detail` after a customer accepts (`jeeber_feed_tab_view.dart:651–654`). Ship three chips. The board's mock simply had no accepted rows.

**C-16.2 — The board deletes `Ignore`. REFUSED.** `jeeber_feed_request_ignore_<id>` is frozen and `RequestFeedCubit.decline()` is real. Demote it to a text button; do not remove it.

**C-16.3 — "goes offline in 1h 40m" is unbuildable and half-refused.** §4.1. Not a gateway gap — a deliberate client decision at `dio_availability_gateway.dart:155–161`. Reversing it is an owner call because it turns on an auto-offline that is currently inert.

**C-16.4 — "$8 cash on arrival" has no field.** §4.3. Omit with a TODO; do not derive it from the jeeber's own offer (the offer amount is not on this DTO and inferring it would be fabrication of the JEBV4-176 kind).

**C-16.5 — "Achrafieh zone" has no field.** `AvailabilityStatus` has no zone; `DioAvailabilityGateway._onlinePayload` sends a hardcoded `'zone': 'default'` **up** and the response parse reads no zone back (`dio_availability_gateway.dart:107–118, 146–162`). Do not print a zone name. The subtitle carries the auto-offline hint instead.

**C-16.6 — "1.2 km · Achrafieh" per card is half-available.** `distanceFromYouKm` exists (nullable) and `pickup.label` is a real human label — render `'{distance} · {pickup.label}'` and fall back to whichever half is present. Do not invent a neighbourhood when `pickup.label` is a street address; it is user-facing gateway text, so rendering it verbatim is honest.

**C-16.7 — the ★ 4.8 pill collides with shell chrome.** §4.2. Not a design refusal; an ownership/overlap conflict that needs the shell lane or the owner.

**C-16.8 — the magnifier is NOT the deleted search.** Recorded so a lane grepping "search" does not refuse it: `jeeber_feed_tab_view.dart:62` already ships a live search bar and the deleted feature was elsewhere (00-MIGRATION-PLAN §7.2). Build the collapse.

**No locked-decision violations.** `decision_violations_test.dart` covers D56 (rating), D52 (KYC), D20 (vehicle) and the earnings framing — none of them touch this screen. There is no money figure on 16 once C-16.4 is honoured, so D41/D44 and `kJeebCommissionRate` do not apply here. B04 is a chat-only rule.

---

## 10. Wiring requests (integrator / other lanes)

1. **l10n batch** (EN + real AR + getter): `jeeberDashboardEyebrow` ("Jeeber dashboard"), `jeeberFeedNearbyCount` / `jeeberFeedPendingCount` / `jeeberFeedRepliesCount` (`{count}` plurals), `jeeberFeedMakeOfferAction` ("Make offer" — the board's wording; today's key is `jeeberFeedOfferAction` = "Offer"), `jeeberActiveLabel` ("Active"), `jeeberActiveManage` ("Manage" — `jeeberActiveDeliveriesManage` exists, reuse it), `jeeberFeedReceivedAgo` (`{minutes}m ago` / `{hours}h ago` / `{days}d ago` plurals — see the `notifications_l10n.dart:130–143` precedent), `jeeberFeedSearchToggleLabel`. Reuse without new keys: `availabilityStatusOnline`, `availabilityStatusOffline`, `availabilityStatusAutoOffline`, `availabilityAutoOfflineHint`, `availabilityTransitioning`, `availabilityInactivityWarningCta`, `homeGreetingNamed`, `homeGreetingFallback`.
2. **`lib/core/session/greeting_profile_cubit.dart`**: carry `rating` + `ratingCount` from the already-fetched `CustomerProfileViewData` into `GreetingProfileState` (§4.2). Additive, no new call.
3. **`lib/features/shell/shell_screen.dart`**: (a) restyle `_JeebBottomBar` per §5 of the plan — selected tab = 52×30 `surfaceContainerHigh` pill; (b) decide the `_HeaderedTab(idPrefix: 'delivery_tab')` overlay vs the rating pill (§4.2).
4. **Wave 1 kit**: `JeebProfileHeader`, `JeebNavySurfaceCard`, `JeebAccentFrameCard`, `JeebOutlinedCard`, `JeebSelectChip(filter)`, `JeebTierChip`, `JeebAvatar`, `JeebCtaButton`, `JeebInfoNote`, `JeebWaveform.cardMark` — with the 3-vs-4-bar correction in §4.5.
5. **Ownership call**: `lib/features/jeeber_active_deliveries/` has no lane in `screen-repo-map.md` and renders **only** on screen 16. This proposal claims it; confirm before two lanes edit it.
