# W3 apply report — `delivery-detail` (the `/orders/:id` order hub)

File: `lib/features/deep_link_targets/delivery_detail_screen.dart` (the only file changed).
No render exists for this screen — it is one of the 46 the board never drew, so the reference was
the neighbour it sits between in the journey: **12 Live tracking** (and, for header/gutter rhythm,
24 Order history + the wallet hub).

## What the neighbour does, and what this screen did instead

| 12 Live tracking (redesigned) | delivery-detail (before) |
|---|---|
| In-body `JeebTopBar.back` — Ø40 tonal circle, navy title, no elevation | Material `OMDSAppBar` with an elevated surface-tint bar |
| 24px side gutters, blocks separated by rhythm | 16px `EdgeInsets.symmetric` gutters (non-directional) |
| One outlined r16 card, 1.5px stroke, **no shadow** | Flat, uncarded `OmdsSettingsRow` stack straight on the surface |
| `JeebInfoNote` strip/stacked forms for status + door code | Hand-rolled `Container` + `BoxDecoration` + `Spacing.small` (12px) radius banner |
| Pill CTAs (r999): `JeebCtaButton.text` + `.outline` in a `JeebCtaFooter.split` | `OmdsPrimaryButton(variant: outlined)` |
| Orange appears once (the active step node) | No orange at all — but also no navy hierarchy |
| Type from `context.jeebText` | `theme.textTheme.titleMedium/bodyMedium` with `copyWith` colours |

## Changes applied

1. **Header** — `OMDSAppBar` → `JeebTopBar.back(identifier: 'order_detail_back')` mounted as the
   first child of a `SafeArea > Column`, the same shape/pattern as `_TrackingBackBar` on 12. Its
   `onLeadingPressed` mirrors the surrounding `RootAwareBackScope` (`canPop ? pop : go('/')`), so the
   circle is never dead when the hub is the stack root (push / deep link). New identifier follows
   `<screen>_<element>`.
2. **Gutters/rhythm** — `_kBandPadding` = `EdgeInsetsDirectional.fromSTEB(24, 16, 24, 32)` on the
   list; `_kBlockGap` = 28 between blocks. Replaces the 16px symmetric non-directional padding and
   the per-bucket leading `SizedBox`.
3. **Action rows** — `OmdsSettingsRow` (+ outer `Semantics`) → `JeebListRow` collected in a single
   `JeebOutlinedCard.grouped` (kit draws the 1px inset dividers). `JeebListRow` owns its own
   Semantics node, so the outer wrapper was dropped rather than doubling the button node. Icons
   moved to filled glyphs per kit rule R10.
4. **Status banners** — bespoke `Container`/`BoxDecoration` + `_StatusBannerTone` enum → `JeebInfoNote`
   stacked form with `JeebInfoNoteTone.success` / `.error`. The local tone enum and the
   `secondaryContainer`/`errorContainer` colour-pair computation are gone; the kit's status tones
   keep their role colours on any surface.
5. **Cancel** — `OmdsPrimaryButton(outlined)` → `JeebCtaButton.outline` inside a
   `JeebCtaFooter.single` with a top-only 28 inset (the 24 gutter would double inside the padded
   list). Renamed `_CancelButton` → `_CancelFooter`.
6. **Rating summary sheet** — `theme.textTheme.*` → `context.jeebText.h2` / `.body`, directional
   padding, `OmdsPrimaryButton` → `JeebCtaButton`. The hero star stays **navy**
   (`colorScheme.primary`), matching §4.1's rationing rule — a read-only summary is not a
   do-it-now moment.

## What was deliberately NOT done

- **No flow change.** Same buckets, same rows in the same order, same routes, same copy. No row
  added, removed or reordered; `_StatusBucket`, the single-flight status read, the push/resume
  triggers and the JEBV4-308 rating-status branch are untouched.
- **No new strings.** This repo has no gen-l10n and the parity gate spans three files, so no section
  label / eyebrow / subtitle was invented just to look more like the board.
- **No invented data.** 12's identity header ("Medicine — Pharmacie du Musée · Flash · $8 cash") and
  its 4-step stepper are not reproduced: this hub reads only `statusId` off `fetchSummary`, which
  gives a bucket, not a step index or an order title. Rendering either would be fabricated.
- **No orange.** Nothing on this screen is a do-it-now moment; the accent stays rationed.

## Semantics contract

Byte-identical, all still emitted: `order-detail-root`, `order-detail-track`, `order-detail-chat`,
`order-detail-otp`, `order-detail-rate`, `order-detail-receipt`, `order-detail-escalate`,
`order-detail-cancel`, `order-detail-status-delivered`, `order-detail-status-cancelled`,
`delivery-rating-summary`, `delivery-rating-summary-done`. All widget `Key`s preserved
(`delivery-detail-list` + one per id) — the state-aware suite finds rows by key.
One new id: `order_detail_back` (the top-bar leading circle).

## Verification

- `dart analyze lib/features/deep_link_targets` → **No issues found**.
- `flutter test test/features/deep_link_targets/ test/core/router/back_nav_system_back_test.dart
  test/core/deep_link/deep_link_resolution_router_test.dart` → **79/79 pass**.
- `flutter test test/delivery_status_screen_test.dart
  test/core/notifications/push_refresh_topic_routing_test.dart
  test/core/router/back_nav_all_routes_test.dart test/decision_violations_test.dart` → **75/75 pass**.
- No shared-file edits, so no wiring request was needed.

## Remaining inconsistencies vs 12 (for a later sweep)

1. No progress stepper band — needs a step index the hub does not fetch.
2. No order-identity line under the title — needs an order title/tier/price contract check on
   `OrderChatSummary`.
3. No trailing Ø40 circle action in the top bar (12 has the chat circle); the Contact row already
   owns that navigation and duplicating it would be a flow change.
4. Cancel is in-flow, not docked: it exists in only 2 of the 4 buckets, so docking would give the
   screen two different layouts.
5. Title uses the `standard` scale (h2 20); 12 uses `compact` (17) because it carries a subtitle.
6. The rating sheet still uses the framework's default modal shape/drag handle — no kit sheet
   widget exists and the sheet shape is theme-owned.
