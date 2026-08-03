# Apply report — gap lane: screen 16's feed cards + active-deliveries banner

Screen 16 shipped half-done. `jeeber_home/` (header, availability strip, chip row, search collapse,
empty states) was redesigned in the 24-screen wave; the two card families it *renders* were filed as
cross-lane wiring requests **W-2** and **W-3** in `wiring/16-jeeber-home.md` and never applied. Those
cards are most of what a jeeber actually looks at all day, so the screen still read pre-redesign on
the device. This lane applies W-2 and W-3.

Instruction sets: `per-screen-revised/16-jeeber-home.md` §1 (CUT/CORRECTED), `wiring/16-jeeber-home.md`
W-2/W-3, `03-WAVE1-KIT.md` §2 (which wins where they disagree).
New wiring filed: `wiring/gap-jeeber-feed.md`.

Status: **applied.** Both card families are on-board. Two board strings (`Make offer`, `2 min ago`)
still render their pre-redesign equivalents because four l10n keys from the W-1 batch were never
applied — filed, with the exact two-line swap-in, rather than faked or hand-rolled outside
`AppLocalizations`.

---

## 1. What changed

| Surface | Before | After |
|---|---|---|
| Feed card, row 1 | Ø46 client avatar + client name + ★ rating cluster + a wall-clock stamp | optional `JeebWaveform.cardMark` · the request CONTENT as a one-line `cardTitle` headline · the stamp |
| Feed card, row 2 | a `Wrap` of a per-tier tinted `OmdsChip` and the actions, which wrapped to a second line and let the accepted pill go full-width | one Row: `JeebTierChip` (one treatment, all tiers) · `3 km · Hamra` · the ONE action, flush to the end gutter |
| Feed card summary | a 2-line muted body line UNDER the identity block | promoted to the headline (it is what the jeeber prices) |
| Feed card CTA | one navy `OmdsPrimaryButton` per row, `Ignore` in **error red** | freshest row = accent-filled pill + accent glow; every older row = the same pill outlined; `Ignore` demoted to `onSurfaceVariant` text rank |
| Feed card shell | hand-rolled `DecoratedBox` + `GestureDetector` | `JeebOutlinedCard` (r16, 1.5px `outline`, no shadow), 24 page gutter |
| Active delivery | `OMDSGlassCard` + status chip + TWO stacked full-width icon buttons (~180dp/card), and at ONE delivery nothing but a `View all (1)` row | `JeebAccentFrameCard`: 2px orange frame, Ø38 accent scooter disc, `Active: {order} → {dropoff}`, status subtitle, one navy `Manage` pill (~72dp) |
| Active delivery disclosure | disclosure at any count — one won job showed as a link, not a card | pinned card at 1; the `View all (n)` / `Show less` disclosure stays from 2 up |

Kit widgets consumed: `JeebOutlinedCard`, `JeebTierChip`, `JeebWaveform.cardMark`, `JeebCtaButton`
(`primary` / `outline` / `text`), `JeebAccentFrameCard`. `JeebShadows.accentBanner`,
`jeebRoles.accent/.onAccent`, `JeebSemanticColors.mutedText`, `context.jeebText`. No kit file was
edited and no private copy of a kit widget was made.

Deleted: `_ClientAvatar`, `_ClientName`, `_RatingCluster`, `_IdentityBlock`, `_SummaryLine`,
`_DistanceLine`, `_CardColumn`/`_CardRow`/`_CardInfo`, the `JeebTierColors` per-tier tint import,
`_ActiveDeliveryCardActions`, `_ButtonLabel`, `_StatusChip`, `OMDSGlassCard`.

## 2. Deviations from the instruction sets, each with its reason

1. **The offer pill and the Manage pill are `JeebCtaButton`s, not `JeebSelectChip(role:
   inlineAction)`.** The kit table nominates the chip for "a pill that reads as a button inside a
   card", and lane 16's own fallback banner already uses it — but the chip's label is a rigid `Text`
   in a `mainAxisSize.min` Row, so it cannot ellipsize. With it, `Manage delivery` overflowed the
   active card by **129px** at 360dp and the feed row overflowed by 42px. `JeebCtaButton`'s label
   ellipsizes under a bounded width. Filed as a kit request. Both pills use the same height/padding
   constants so the screen keeps ONE pill language.
2. **The freshest CTA's orange comes from a local `Theme` that re-points `colorScheme.primary`/
   `onPrimary` at `jeebRoles.accent`/`onAccent`.** The kit has no accent-filled pill variant
   (`primary` navy · `outline` · `text` · `accentText`), and forking or hand-rolling one is
   forbidden. Filed as a kit request. Consequence: the pill still carries the kit's hardcoded
   `JeebShadows.ctaNavy` beneath the `JeebShadows.accentBanner` glow this lane paints around it, and
   `accentBanner` measures `0 10 24 @.35` where the board draws `0 6 14 @.35`.
3. **The `·` separator is a Ø3 dot shape, not a `'·'` character.** Verbatim the call 24's
   `order_history_card.dart:49` documents: no l10n key to translate, no bidi hazard where an Arabic
   neighbourhood meets a latin-numeric distance. The distance itself renders in an LTR isolate.
4. **The distance uses the existing `requestFeedDistance` ("{distance} km"), not
   `jeeberFeedDistanceAway` ("3km away from you").** The board's meta line is a fragment, not a
   sentence, and the old key hardcodes the unit against the number.
5. **The headline falls back to the client's name when `itemsSummary` is null** — W-2's "existing
   fallback chain" is exactly `senderName ?? jeeberFeedAnonymousClient`. A description-less request
   is still a job; the row never blanks.
6. **`_MetaRow` sheds its tier chip above 1.5 text scale** and caps the action area at 55% of the
   row (`maxActionFraction`). Both are anti-overflow, and the shed threshold is 24's, quoted.
7. **`JeebSemanticColors` is read with a `?? JeebSemanticColors.light()` fallback, not `!`.** Bare
   widget hosts theme with `ThemeData.light()`; a `!` there throws before a single assertion runs
   (it did — that is how this was found). Matches how `context.jeebText`/`context.jeebRoles`
   already degrade.
8. **`isVoice` is wired to a literal `false`.** `DeliveryRequest` has no `hasAudio`/`audioUrl`; the
   waveform mark is built, tested and unreachable rather than guessed. `TODO(redesign-24)` at the
   call site.
9. **No cash figure on the active card.** `ActiveDeliverySummary` has no amount field and the
   gateway sends none (C-16.4). `TODO` in place; nothing faked.
10. **Files outside the two directories the lane was told it owns were edited:**
    `lib/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart` and two shell
    test files. Reason: W-3 is the authoritative spec for that file, screen 16 is its only rendering
    surface, the owner's report named it, and W-3's own "exact change" prescribes the
    `jeeber_active_card_push_render_test` update. Recorded in `wiring/gap-jeeber-feed.md` in case a
    shell lane is editing those tests concurrently.

## 3. Frozen inventory — verified identical

`grep -o "identifier: '…'"` over both feature trees, before vs after:
`jeeber_feed_request_card_<id>` · `_ignore_<id>` · `_offer_<id>` · `_expired_<id>` · `_action_<id>` ·
`feed_make_offer_cta` · `jeeber_active_deliveries` · `jeeber_active_deliveries_view_all` ·
`jeeber_active_delivery_row_<id>` · `jeeber_active_delivery_open_chat_<id>` ·
`jeeber_active_delivery_manage_<id>` — **all present, all byte-identical, none added.**
`explicitChildNodes: true` still guards both card roots (now via the kit cards' own wrappers).

Keys kept findable: `jeeber-feed-card-<id>`, `-content`, `-summary`, `-timestamp`, `-footer`,
`jeeber-feed-ignore-<id>`, `jeeber-feed-offer-<id>`, `jeeber-feed-action-<id>`,
`jeeber-feed-expired-status-<id>`, `jeeber-feed-pending-status`. Dropped with the widgets they
labelled: `jeeber-feed-card-avatar`, `-client-name`, `-identity` (the identity band is gone).

Untouched: `pending_offer_row.dart`, `request_feed_screen.dart`, `request_card.dart`, the cubits,
repositories, models, router, DI, theme, `.arb`, `pubspec.yaml`, `lib/core/widgets/jeeb/**`,
`.maestro/**`.

## 4. Gates

- `dart analyze lib/features/jeeber_request_feed lib/features/jeeber_home
  lib/features/jeeber_active_deliveries` → **No issues found.**
- `dart analyze test/jeeber_feed_card_test.dart` → **No issues found.** `dart format` clean.
- `tool/check_design_tokens.sh` → 6 pre-existing violations repo-wide, **none in any file this lane
  touched** (settlement ×3, location, wallet, reviews).
- `test/core/theme/no_raw_semantic_colors_test.dart`, `test/decision_violations_test.dart`,
  `test/semantics_identifier_surfacing_test.dart`, `test/core/session/jeeber_kyc_status_gate_test.dart`
  → **45/45 pass.**
- Screen tests: `jeeber_feed_card` · `jeeber_feed_empty_ptr` · `jeeber_feed_empty_view` ·
  `jeeber_feed_make_offer` · `jeeber_feed_search_input` · `jeeber_feed_tier_filter` ·
  `jeeber_home_screen` · `jebv4_284_keyboard_repro` · `test/features/jeeber_home/` ·
  `test/features/shell/` → **84/84 pass.**

### The pre-existing `jeeber_feed_card_test` failure is now GREEN — deliberately, and here is why

`accepted-action pill is end-aligned (right-flush in LTR)` was red on `main` at **538.8** against a
`< 40` bound: inside the old `Wrap` the accepted pill was full-width, so its right edge sat a whole
card away from the gutter. The two-row `Row` (meta `Expanded`, action last) is what actually pins
it; it now measures **41.5** — the real inset the redesign introduced (24 page gutter + 16 kit-card
padding + the 1.5 stroke). The assertion's *intent* is unchanged; only the constant moved, from a
16-gutter-era `Spacing.threeXLarge` to the gutter the board specifies. This is a fix, not an
absorption, and it is the only place the failure mode changed.

Test file rewritten per W-2: identity-led assertions dropped (`Sami Fawaz`, avatar/client-name Keys,
`OmdsStarRatingDisplay`, the avatar-vs-content geometry proof, the 2-line summary contract,
`3km away from you`); expiry group, `IntrinsicWidth` hugging proof, RTL (`فلاش`) and the SW-03
device-local test kept; new coverage added for the two-row structure, the R5 freshest/older pill
split, the outlined-card shell and the voice mark. 15 tests → 21.

## 5. Still open (see `wiring/gap-jeeber-feed.md`)

- `Make offer` and `2 min ago` — four ungranted l10n keys; the swap-in is two lines, written out.
- An accent-filled `JeebCtaButton` variant, and a `Flexible` label inside `JeebSelectChip`.
- The waveform mark has no data source, so it never renders in production.
- `JeebWaveform.cardMark` is the kit's 4-bar profile; 16's board draws 3 (already flagged as W-5).
- The active card's "· $8 cash on arrival" needs a cash-due field on `GET /v1/deliveries?role=jeeber`.
